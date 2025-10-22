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
# NEXT STEP: Run 02_Project.ps1 to actually create the target project
#
param([string] $ParametersPath, [switch] $DryRun)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
. (Join-Path $here "_terminal_logging.ps1")
$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent $here) "migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Set up step-specific output directory
$outDir = $p.OutputSettings.OutputDirectory
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = ".\out" }

# Ensure the base output directory exists
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output directory: $outDir" -ForegroundColor Green
}

# Clean up ONLY files from previous failed attempts of THIS step (targeted cleanup)
$projectKey = $p.ProjectKey
$projectExportDir = Join-Path ".\projects" $projectKey
if (Test-Path $projectExportDir) {
    $projectOutDir = Join-Path $projectExportDir "out"
    if (Test-Path $projectOutDir) {
        # Only clean up the exports01 folder if it exists from a previous run
        $exports01Dir = Join-Path $projectOutDir "exports01"
        if (Test-Path $exports01Dir) {
            Write-Host "Cleaning up previous step 01 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports01Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports01 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder (exports01 for step 01)
$stepExportsDir = Join-Path $outDir "exports01"
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Set step start time
$script:StepStartTime = Get-Date

# Start terminal logging
$terminalLogPath = Start-TerminalLog -StepName "01_Preflight" -OutDir $outDir -ProjectKey $p.ProjectKey

# Set up error handling to ensure logging stops on errors
$ErrorActionPreference = "Stop"
trap {
    $errorMessage = "Step 01 (Preflight Validation) failed"
    if ($_.Exception.Message) {
        $errorMessage += ": $($_.Exception.Message)"
    }
    if ($_.Exception.InnerException) {
        $errorMessage += " (Inner: $($_.Exception.InnerException.Message))"
    }
    Write-Host "❌ $errorMessage" -ForegroundColor Red
    Stop-TerminalLogOnError -ErrorMessage $errorMessage
    throw
}

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

# Add parameter validation results in specific order
$parameterOrder = @(
    @{ Key = "ProjectKey"; DisplayName = "SourceProjectKey" },
    @{ Key = "TargetEnvironment.ProjectKey"; DisplayName = "TargetProjectKey" },
    @{ Key = "SourceEnvironment.BaseUrl"; DisplayName = "SourceBaseUrl" },
    @{ Key = "TargetEnvironment.BaseUrl"; DisplayName = "TargetBaseUrl" },
    @{ Key = "SourceEnvironment.Username"; DisplayName = "SourceUsername" },
    @{ Key = "TargetEnvironment.Username"; DisplayName = "TargetUsername" },
    @{ Key = "SourceProjectName"; DisplayName = "SourceProjectName"; UseProjectData = $true },
    @{ Key = "TargetEnvironment.ProjectName"; DisplayName = "TargetProjectName" }
)

foreach ($param in $parameterOrder) {
    $req = $param.Key
    $displayName = $param.DisplayName
    
    # Skip API tokens for security
    if ($req -match "ApiToken") {
        continue
    }
    
    # Handle special case for SourceProjectName
    if ($req -eq "SourceProjectName") {
        $validationResults += [PSCustomObject]@{
            Variable = $displayName
            Value = $srcProject.name
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        continue
    }
    
    $parts = $req -split '\.'
    $cur = $p
    $exists = $true
    $actualValue = $null
    
    foreach ($part in $parts) {
        if ($cur.PSObject.Properties.Name -contains $part) { 
            $cur = $cur.$part 
        } else { 
            $exists = $false
            break 
        }
    }
    
    if ($exists) {
        $actualValue = $cur
    }
    
    $validationResults += [PSCustomObject]@{
        Variable = $displayName
        Value = if ($exists) { $actualValue } else { "MISSING" }
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# SourceEnvironment.ProjectName is already included in the parameter order above

# Add project validation results
$validationResults += [PSCustomObject]@{
    Variable = "Source Project Exists"
    Value = "Source project '$($p.ProjectKey)' found: $($srcProject.name)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add project IDs
$validationResults += [PSCustomObject]@{
    Variable = "SourceProjectId"
    Value = $srcProject.id
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
    Variable = "Target Project Status"
    Value = $targetDetails
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add target project ID if it exists
if ($tgtProject) {
    $validationResults += [PSCustomObject]@{
        Variable = "TargetProjectId"
        Value = $tgtProject.id
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add step timing information to validation results
$validationResults += [PSCustomObject]@{
    Variable = "Step Start Time"
    Value = "Step execution started at $($stepStartTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Capture step end time
$stepEndTime = Get-Date

$validationResults += [PSCustomObject]@{
    Variable = "Step End Time"
    Value = "Step execution completed at $($stepEndTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Calculate step total time
$stepDuration = $stepEndTime - $stepStartTime
$totalSeconds = [Math]::Round($stepDuration.TotalSeconds, 0)
$totalHours = [Math]::Floor($totalSeconds / 3600)
$totalMinutes = [Math]::Floor(($totalSeconds % 3600) / 60)
$remainingSeconds = $totalSeconds % 60
$durationFormatted = "{0:00}h : {1:00}m : {2:00}s" -f $totalHours, $totalMinutes, $remainingSeconds

# Debug output
Write-Host "DEBUG: Step duration = $($stepDuration.TotalSeconds) seconds" -ForegroundColor Cyan
Write-Host "DEBUG: Formatted duration = $durationFormatted" -ForegroundColor Cyan

# Add step total time calculation
$validationResults += [PSCustomObject]@{
    Variable = "Step Total Time"
    Value = $durationFormatted
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export validation results to CSV (in step-specific exports folder)
$csvPath = Join-Path $stepExportsDir "01_Preflight_Report.csv"
$validationResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Validation report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total validations: $($validationResults.Count)" -ForegroundColor Cyan

Write-StageReceipt -OutDir $stepExportsDir -Stage "01_Preflight" -Data @{
  Ok = $true
  TimeUtc = (Get-Date).ToUniversalTime().ToString("o")
  SourceProjectKey = $p.ProjectKey
  SourceProjectName = if ($p.ProjectName) { $p.ProjectName } else { $srcProject.name }
  SourceProjectId = $srcProject.id
  TargetProjectKey = $p.TargetEnvironment.ProjectKey
  TargetProjectName = $p.TargetEnvironment.ProjectName
  TargetProjectId = if ($tgtProject) { $tgtProject.id } else { $null }
}

# Stop terminal logging
Stop-TerminalLog -Success:$true -Summary "Preflight validation completed successfully"

exit 0
