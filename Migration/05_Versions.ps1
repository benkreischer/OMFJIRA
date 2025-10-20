# 05_Versions.ps1 - Set Up Project Versions
# 
# PURPOSE: Recreates project versions from the source project in the target project
# to ensure proper version tracking and release management.
#
# WHAT IT DOES:
# - Copies all versions from the source project to the target project
# - Preserves version names, descriptions, and release dates
# - Creates a receipt tracking version setup
#
# WHAT IT DOES NOT DO:
# - Does not migrate issues yet
# - Does not assign versions to issues
# - Does not modify existing version configurations
#
# NEXT STEP: Run 06_Boards.ps1 to set up boards
#
param(
    [string] $ParametersPath,
    [switch] $DryRun
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")

$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

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
        # Only clean up the exports05 folder (step-specific cleanup)
        $exports05Dir = Join-Path $projectOutDir "exports05"
        if (Test-Path $exports05Dir) {
            Write-Host "Cleaning up previous step 05 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports05Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports05 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder (exports05 for step 05)
$stepExportsDir = Join-Path $outDir "exports05"
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Initialize issues logging
Initialize-IssuesLog -StepName "05_Versions" -OutDir $stepExportsDir

# Set step start time
$script:StepStartTime = Get-Date

Write-Host "=== CREATING PROJECT VERSIONS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"

# Get project details
Write-Host "Retrieving project details..."
try {
    $srcProject = Invoke-Jira -Method GET -BaseUrl $srcBase -Path "rest/api/3/project/$srcKey" -Headers $srcHdr
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Source project: $($srcProject.name) (id=$($srcProject.id))"
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve project details: $($_.Exception.Message)"
}

# Get source project versions
Write-Host ""
Write-Host "=== VERSION SYNCHRONIZATION ==="
Write-Host "Retrieving source project versions..."
$srcVersions = @()
try {
    $uri = "$($srcBase.TrimEnd('/'))/rest/api/3/project/$($srcProject.id)/version"
    $response = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
    if ($response.values) {
        $srcVersions = $response.values
        Write-Host "Found $($srcVersions.Count) versions in source project"
    } else {
        Write-Host "Found 0 versions in source project"
        $srcVersions = @()
    }
} catch {
    Write-Warning "Could not retrieve source versions: $($_.Exception.Message)"
    $srcVersions = @()
}

# Get target project versions
Write-Host "Retrieving target project versions..."
$tgtVersions = @()
try {
    $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$($tgtProject.id)/version"
    $response = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
    if ($response.values) {
        $tgtVersions = $response.values
        Write-Host "Found $($tgtVersions.Count) versions in target project"
    } else {
        Write-Host "Found 0 versions in target project"
        $tgtVersions = @()
    }
} catch {
    Write-Warning "Could not retrieve target versions: $($_.Exception.Message)"
    $tgtVersions = @()
}

# --- DELETE all existing versions to ensure idempotency ---
if ($tgtVersions.Count -gt 0) {
    # Check if deletion is enabled in config
    $deleteVersions = $p.MigrationSettings.DeleteTargetVersionsBeforeImport
    if (-not $deleteVersions) {
        Write-Host ""
        Write-Host "=== SKIPPING VERSION DELETION ===" -ForegroundColor Yellow
        Write-Host "MigrationSettings.DeleteTargetVersionsBeforeImport is not enabled" -ForegroundColor Yellow
        Write-Host "Skipping deletion of $($tgtVersions.Count) existing versions" -ForegroundColor Yellow
        Write-Host "This may result in duplicate versions if re-running the migration" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "=== DELETING EXISTING VERSIONS (IDEMPOTENCY) ===" -ForegroundColor Yellow
        Write-Host "Deleting $($tgtVersions.Count) existing versions to ensure clean state..."
    
    $deletedCount = 0
    $failedDeletes = 0
    
    foreach ($version in $tgtVersions) {
        try {
            $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/version/$($version.id)"
            Invoke-JiraWithRetry -Method DELETE -Uri $deleteUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 | Out-Null
            $deletedCount++
            Write-Host "  ✓ Deleted: $($version.name)" -ForegroundColor Gray
        } catch {
            $failedDeletes++
            Write-Warning "  ✗ Failed to delete '$($version.name)': $($_.Exception.Message)"
        }
    }
    
        Write-Host "Deleted $deletedCount versions ($failedDeletes failed)" -ForegroundColor Green
        
        # Clear the versions list since we just deleted them all
        $tgtVersions = @()
    }
}

# Create all versions from source
$createdVersions = @()
$existingVersions = @()
$failedVersions = @()

foreach ($srcVersion in $srcVersions) {
    $versionName = $srcVersion.name
    Write-Host "Processing version: $versionName"
    
    # Create version in target (since we deleted all existing ones)
    $createBody = @{
        name = $versionName
        project = $tgtKey
    }
    
    if ($srcVersion.PSObject.Properties.Name -contains 'description' -and $srcVersion.description) {
        $createBody.description = $srcVersion.description
    }
    
    if ($srcVersion.PSObject.Properties.Name -contains 'released' -and $srcVersion.released) {
        $createBody.released = $srcVersion.released
    }
    
    if ($srcVersion.PSObject.Properties.Name -contains 'releaseDate' -and $srcVersion.releaseDate) {
        $createBody.releaseDate = $srcVersion.releaseDate
    }
    
    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/version"
        $newVersion = Invoke-JiraWithRetry -Method POST -Uri $uri -Headers $tgtHdr -Body ($createBody | ConvertTo-Json -Depth 3) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        Write-Host "  Created in target (id=$($newVersion.id))"
        $createdVersions += @{
            SourceId = $srcVersion.id
            TargetId = $newVersion.id
            Name = $versionName
            Description = if ($srcVersion.PSObject.Properties.Name -contains 'description') { $srcVersion.description } else { $null }
        }
    } catch {
        Write-Warning "  Failed to create version: $($_.Exception.Message)"
        $failedVersions += @{
            SourceVersion = $srcVersion
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "=== SYNCHRONIZATION SUMMARY ==="
Write-Host "Versions created: $($createdVersions.Count)"
Write-Host "Versions failed: $($failedVersions.Count)"

if ($failedVersions.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed versions:"
    foreach ($failed in $failedVersions) {
        Write-Host "  - $($failed.SourceVersion.name): $($failed.Error)"
    }
}

# Create versions report for CSV export
$versionsReport = @()

# Add summary statistics
$versionsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Source Versions"
    Value = $srcVersions.Count
    Details = "Versions found in source project"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$versionsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Versions Created"
    Value = $createdVersions.Count
    Details = "New versions created in target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$versionsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Existing Versions"
    Value = $existingVersions.Count
    Details = "Versions that already existed"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$versionsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Failed Versions"
    Value = $failedVersions.Count
    Details = "Versions that failed to create"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add created versions details
foreach ($version in $createdVersions) {
    $versionsReport += [PSCustomObject]@{
        Type = "Version"
        Name = $version.Name
        Value = $version.TargetId
        Details = "Created from source version (ID: $($version.SourceId))"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add existing versions details
foreach ($version in $existingVersions) {
    $versionsReport += [PSCustomObject]@{
        Type = "Version"
        Name = $version.Name
        Value = $version.TargetId
        Details = "Already existed in target"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add failed versions details
foreach ($version in $failedVersions) {
    $versionsReport += [PSCustomObject]@{
        Type = "Version"
        Name = $version.SourceVersion.name
        Value = "FAILED"
        Details = "Failed to create: $($version.Error)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to versions report
$versionsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$versionsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export versions report to CSV
$csvPath = Join-Path $stepExportsDir "05_Versions_Report.csv"
$versionsReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Versions report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($versionsReport.Count)" -ForegroundColor Cyan

# Create receipt
$receiptData = @{
    SourceProject = @{ key=$srcKey; name=$srcProject.name; id=$srcProject.id }
    TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    TotalSourceVersions = $srcVersions.Count
    CreatedVersions = $createdVersions.Count
    ExistingVersions = $existingVersions.Count
    FailedVersions = $failedVersions.Count
    CreatedVersionDetails = $createdVersions
    ExistingVersionDetails = $existingVersions
    FailedVersionDetails = $failedVersions
    VersionMapping = ($createdVersions + $existingVersions) | ForEach-Object { @{ SourceId = $_.SourceId; TargetId = $_.TargetId; Name = $_.Name } }
}
Write-StageReceipt -OutDir $stepExportsDir -Stage "05_Versions" -Data $receiptData

# Save issues log
Save-IssuesLog -StepName "05_Versions"

exit 0