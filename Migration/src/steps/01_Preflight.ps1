# 01_Preflight.ps1 - Migration Preflight Validation
# 
# PURPOSE: This script performs preflight validation checks before starting the migration process.
# It does NOT create any projects or perform any actual migration work.
#
# WHAT IT DOES:
# - Validates that all required parameters are present in the configuration file
# - Checks that the migration-parameters.json file is properly structured
# - Ensures all source and target environment settings are configured
# - Creates a receipt file to track that preflight validation passed
#
# WHAT IT DOES NOT DO:
# - Does not create projects in the target environment
# - Does not migrate any data
# - Does not perform any actual Jira operations
#
# NEXT STEP: Run 02_CreateProject_FromSharedConfig.ps1 to actually create the target project
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

$required = @(
  "ProjectKey",
  "SourceEnvironment.BaseUrl",
  "SourceEnvironment.Username",
  "SourceEnvironment.ApiToken",
  "TargetEnvironment.BaseUrl",
  "TargetEnvironment.Username",
  "TargetEnvironment.ApiToken",
  "TargetEnvironment.ProjectKey",
  "TargetEnvironment.ProjectName"
)

$missing = @()
foreach ($r in $required) {
  $parts = $r -split '\.'
  $cur = $p
  foreach ($part in $parts) {
    if ($cur.PSObject.Properties.Name -contains $part) { $cur = $cur.$part } else { $missing += $r; break }
  }
}
if ($missing.Count -gt 0) { throw "Missing required parameters: `n - " + ($missing -join "`n - ") }

Write-Host "Preflight OK. Parameters present."
Write-Host ""

# Validate project details in Jira
Write-Host "=== VALIDATING PROJECT DETAILS FROM JIRA ==="
$srcHdr = New-BasicAuthHeader -Email $p.SourceEnvironment.Username -ApiToken $p.SourceEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $p.TargetEnvironment.Username -ApiToken $p.TargetEnvironment.ApiToken

# Validate source project exists
try {
    $srcProjectUri = "$($p.SourceEnvironment.BaseUrl.TrimEnd('/'))/rest/api/3/project/$($p.ProjectKey)"
    $srcProject = Invoke-RestMethod -Method GET -Uri $srcProjectUri -Headers $srcHdr -ErrorAction Stop
    
    Write-Host "✅ Source Project: $($srcProject.name) (Key: $($p.ProjectKey))" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -match '404') {
        Write-Host ""
        Write-Host "❌ SOURCE PROJECT NOT FOUND" -ForegroundColor Red
        Write-Host ""
        Write-Host "   Project Key: $($p.ProjectKey)" -ForegroundColor Yellow
        Write-Host "   Source URL:  $($p.SourceEnvironment.BaseUrl)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This project does not exist in the source Jira instance." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 Possible solutions:" -ForegroundColor Cyan
        Write-Host "   1. Verify the project key is correct" -ForegroundColor White
        Write-Host "   2. Check if the project exists in a different Jira instance" -ForegroundColor White
        Write-Host "   3. List available projects with:" -ForegroundColor White
        Write-Host "      GET $($p.SourceEnvironment.BaseUrl)rest/api/3/project/search" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   4. Update the SourceEnvironment.BaseUrl in:" -ForegroundColor White
        Write-Host "      projects\$($p.ProjectKey)\parameters.json" -ForegroundColor Gray
        Write-Host ""
        exit 1
    } elseif ($_.Exception.Message -match '401|403') {
        Write-Host ""
        Write-Host "❌ AUTHENTICATION FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Could not authenticate with source Jira." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "💡 Check your credentials:" -ForegroundColor Cyan
        Write-Host "   - Username: $($p.SourceEnvironment.Username)" -ForegroundColor Gray
        Write-Host "   - API Token: $(if ($p.SourceEnvironment.ApiToken) { '***' + $p.SourceEnvironment.ApiToken.Substring([Math]::Max(0, $p.SourceEnvironment.ApiToken.Length - 8)) } else { 'NOT SET' })" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   Update credentials in .env file or:" -ForegroundColor White
        Write-Host "   projects\$($p.ProjectKey)\parameters.json" -ForegroundColor Gray
        Write-Host ""
        exit 1
    } else {
        Write-Host ""
        Write-Host "❌ ERROR FETCHING SOURCE PROJECT" -ForegroundColor Red
        Write-Host ""
        Write-Host "Could not fetch source project details: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "URL: $srcProjectUri" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
}

# Check if target project exists
$tgtProject = $null  # Initialize to null in case target project doesn't exist
try {
    $tgtProjectUri = "$($p.TargetEnvironment.BaseUrl.TrimEnd('/'))/rest/api/3/project/$($p.TargetEnvironment.ProjectKey)"
    $tgtProject = Invoke-RestMethod -Method GET -Uri $tgtProjectUri -Headers $tgtHdr -ErrorAction Stop
    
    Write-Host "✅ Target Project: $($tgtProject.name) (Key: $($p.TargetEnvironment.ProjectKey))" -ForegroundColor Green
    Write-Host "   ⚠️  Target project already exists - migration will update it" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Message -match '404') {
        Write-Host "ℹ️  Target Project: Not yet created (will be created in step 02)" -ForegroundColor Cyan
    } else {
        Write-Warning "Could not check target project: $($_.Exception.Message)"
    }
}

Write-Host ""

# Debug: Check what we have in $p
Write-Host "DEBUG: ProjectKey = $($p.ProjectKey)" -ForegroundColor Cyan
Write-Host "DEBUG: ProjectName = $($p.ProjectName)" -ForegroundColor Cyan
Write-Host "DEBUG: OutputDirectory = $($p.OutputSettings.OutputDirectory)" -ForegroundColor Cyan

# Create validation results for CSV export
$validationResults = @()

# Add parameter validation results
foreach ($req in $required) {
    $parts = $req -split '\.'
    $cur = $p
    $exists = $true
    foreach ($part in $parts) {
        if ($cur.PSObject.Properties.Name -contains $part) { 
            $cur = $cur.$part 
        } else { 
            $exists = $false
            break 
        }
    }
    
    $validationResults += [PSCustomObject]@{
        ValidationType = "Parameter"
        CheckName = $req
        Status = if ($exists) { "PASS" } else { "FAIL" }
        Details = if ($exists) { "Parameter present" } else { "Missing required parameter" }
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add project validation results
$validationResults += [PSCustomObject]@{
    ValidationType = "Project"
    CheckName = "Source Project Exists"
    Status = "PASS"
    Details = "Source project '$($p.ProjectKey)' found: $($srcProject.name)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add target project validation
$targetStatus = "NOT_CREATED"
$targetDetails = "Target project will be created in step 02"
if ($tgtProject) {
    $targetStatus = "EXISTS"
    $targetDetails = "Target project '$($p.TargetEnvironment.ProjectKey)' already exists: $($tgtProject.name)"
}

$validationResults += [PSCustomObject]@{
    ValidationType = "Project"
    CheckName = "Target Project Status"
    Status = $targetStatus
    Details = $targetDetails
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to validation results
$validationResults += [PSCustomObject]@{
    ValidationType = "Step"
    CheckName = "Step Start Time"
    Status = "INFO"
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$validationResults += [PSCustomObject]@{
    ValidationType = "Step"
    CheckName = "Step End Time"
    Status = "INFO"
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export validation results to CSV
$csvPath = Join-Path $p.OutputSettings.OutputDirectory "01_Preflight_ValidationReport.csv"
$validationResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Validation report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total validations: $($validationResults.Count)" -ForegroundColor Cyan

Write-StageReceipt -OutDir $p.OutputSettings.OutputDirectory -Stage "01_Preflight" -Data @{
  Ok = $true
  TimeUtc = (Get-Date).ToUniversalTime().ToString("o")
  SourceProjectKey = $p.ProjectKey
  SourceProjectName = if ($p.ProjectName) { $p.ProjectName } else { $srcProject.name }
  TargetProjectKey = $p.TargetEnvironment.ProjectKey
  TargetProjectName = $p.TargetEnvironment.ProjectName
}

exit 0
