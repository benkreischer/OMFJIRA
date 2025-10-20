# DeleteAllIssues.ps1 - Delete all issues from target project
#
# PURPOSE: Clean up all issues from target project (useful for testing/troubleshooting)
#
# USAGE:
#   .\DeleteAllIssues.ps1 -Project LAS    # Delete from LAS target
#   .\DeleteAllIssues.ps1 -ParametersPath "path\to\parameters.json"
#
param(
    [string]$Project,
    [string]$ParametersPath,
    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "║              DELETE ALL TARGET ISSUES                     ║" -ForegroundColor Red
Write-Host "║                  ⚠️  WARNING  ⚠️                          ║" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# Load common functions
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Determine parameters file
if (-not $ParametersPath -and $Project) {
    $projectsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "projects"
    $ParametersPath = Join-Path $projectsDir "$Project\parameters.json"
}

if (-not $ParametersPath) {
    Write-Host "❌ No parameters file specified" -ForegroundColor Red
    Write-Host "   Usage: .\DeleteAllIssues.ps1 -Project LAS" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $ParametersPath)) {
    Write-Host "❌ Parameters file not found: $ParametersPath" -ForegroundColor Red
    exit 1
}

Write-Host "Loading parameters from: $ParametersPath" -ForegroundColor Cyan
$p = Read-JsonFile -Path $ParametersPath

# Target environment setup
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host ""
Write-Host "Target Project: $tgtKey" -ForegroundColor Yellow
Write-Host "Target URL: $tgtBase" -ForegroundColor Yellow
Write-Host ""

# Get project details
try {
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Project Name: $($tgtProject.name)" -ForegroundColor Cyan
    Write-Host "Project ID: $($tgtProject.id)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to retrieve target project: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all issues in the project
Write-Host ""
Write-Host "Retrieving all issues..." -ForegroundColor Cyan
$allIssues = @()
$startAt = 0
$maxResults = 100

# Use the new JQL search endpoint to get all issues
$uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
$body = @{
    jql = "project = $tgtKey ORDER BY key ASC"
    maxResults = 1000
    fields = @("key", "summary")
} | ConvertTo-Json -Depth 6

try {
    Write-Host "Fetching all issues..." -ForegroundColor Gray
    $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $tgtHdr -Body $body -ContentType "application/json" -ErrorAction Stop
    if ($response.issues) {
        $allIssues = $response.issues
        Write-Host "  Found $($response.issues.Count) issues total" -ForegroundColor Gray
    }
} catch {
    Write-Host "❌ Failed to retrieve issues: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($allIssues.Count) total issues" -ForegroundColor Yellow

if ($allIssues.Count -eq 0) {
    Write-Host ""
    Write-Host "✅ No issues to delete!" -ForegroundColor Green
    exit 0
}

# List first 10 issues as preview
Write-Host ""
Write-Host "Sample issues to be deleted:" -ForegroundColor Yellow
$allIssues | Select-Object -First 10 | ForEach-Object {
    Write-Host "  - $($_.key): $($_.fields.summary)" -ForegroundColor Gray
}
if ($allIssues.Count -gt 10) {
    Write-Host "  ... and $($allIssues.Count - 10) more" -ForegroundColor Gray
}

# Preview mode or confirmation
if ($PreviewOnly) {
    Write-Host ""
    Write-Host "🔍 PREVIEW MODE - No issues will be deleted" -ForegroundColor Cyan
    Write-Host "Total issues that would be deleted: $($allIssues.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "All issues in ${tgtKey}:" -ForegroundColor Yellow
    $allIssues | ForEach-Object {
        Write-Host "  - $($_.key): $($_.fields.summary)" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "To actually delete these issues, run without -PreviewOnly" -ForegroundColor Cyan
    exit 0
}

# Confirmation
Write-Host ""
Write-Host "⚠️  This will DELETE ALL $($allIssues.Count) ISSUES from $tgtKey ⚠️" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'DELETE ALL ISSUES' to confirm (or anything else to cancel)"

if ($confirm -ne "DELETE ALL ISSUES") {
    Write-Host ""
    Write-Host "❌ Cancelled - no issues were deleted" -ForegroundColor Yellow
    exit 0
}

# Delete issues in batches
Write-Host ""
Write-Host "=== DELETING ISSUES ===" -ForegroundColor Red
$deleted = 0
$failed = 0
$errors = @()
$batchSize = 50

for ($i = 0; $i -lt $allIssues.Count; $i += $batchSize) {
    $batch = $allIssues | Select-Object -Skip $i -First $batchSize
    $issueKeys = $batch | ForEach-Object { $_.key }
    
    Write-Host "Deleting batch $([math]::Floor($i / $batchSize) + 1) ($($batch.Count) issues)..." -ForegroundColor Yellow
    
    try {
        # Use bulk delete endpoint if available, otherwise delete individually
        $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/bulk"
        $deletePayload = @{
            issueKeysOrIds = $issueKeys
            deleteSubtasks = $true
        } | ConvertTo-Json -Depth 10
        
        try {
            $deleteResponse = Invoke-RestMethod -Method DELETE -Uri $deleteUri -Headers $tgtHdr -Body $deletePayload -ContentType "application/json" -ErrorAction Stop
            Write-Host "  ✅ Deleted batch: $($issueKeys -join ', ')" -ForegroundColor Green
            $deleted += $batch.Count
        } catch {
            # Fallback to individual deletion
            Write-Host "  Bulk delete failed, trying individual deletion..." -ForegroundColor Yellow
            foreach ($issue in $batch) {
                try {
                    $individualUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$($issue.key)?deleteSubtasks=true"
                    Invoke-RestMethod -Method DELETE -Uri $individualUri -Headers $tgtHdr -ErrorAction Stop | Out-Null
                    Write-Host "    ✅ Deleted: $($issue.key)" -ForegroundColor Green
                    $deleted++
                } catch {
                    Write-Host "    ❌ Failed: $($issue.key) - $($_.Exception.Message)" -ForegroundColor Red
                    $failed++
                    $errors += @{
                        Key = $issue.key
                        Error = $_.Exception.Message
                    }
                }
            }
        }
    } catch {
        Write-Host "  ❌ Batch deletion failed: $($_.Exception.Message)" -ForegroundColor Red
        $failed += $batch.Count
        $errors += @{
            Batch = $issueKeys -join ', '
            Error = $_.Exception.Message
        }
    }
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total issues: $($allIssues.Count)"
Write-Host "Deleted: $deleted" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors:" -ForegroundColor Red
    foreach ($err in $errors) {
        if ($err.PSObject.Properties.Name -contains 'Key') {
            Write-Host "  - $($err.Key): $($err.Error)"
        } else {
            Write-Host "  - Batch $($err.Batch): $($err.Error)"
        }
    }
}

Write-Host ""
if ($deleted -eq $allIssues.Count) {
    Write-Host "✅ All issues deleted successfully!" -ForegroundColor Green
} elseif ($deleted -gt 0) {
    Write-Host "⚠️  Partial success - some issues could not be deleted" -ForegroundColor Yellow
} else {
    Write-Host "❌ No issues were deleted" -ForegroundColor Red
}

exit $(if ($failed -eq 0) { 0 } else { 1 })
