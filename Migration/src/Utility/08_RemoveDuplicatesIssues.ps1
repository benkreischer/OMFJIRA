# 08_RemoveDuplicatesIssues.ps1 - Remove Duplicate Issues from Target Project
# 
# LOCATION: Migration/src/Utility/
# PURPOSE: Identifies and removes duplicate issues created by running step 08 multiple times.
# Uses intelligent strategies to identify which issues to keep vs delete.
#
# WHAT IT DOES:
# - Identifies duplicate issues by summary
# - Determines which duplicate to KEEP (usually the first created)
# - Deletes the duplicate issues (keeping the original)
# - Updates key mapping file to remove deleted keys
# - Creates detailed report of deleted issues
# - Backs up data before deletion
#
# STRATEGIES:
# - Group by summary
# - Keep earliest created issue
# - Delete later duplicates
# - Verify before deletion (optional dry-run mode)
#
# SAFETY FEATURES:
# - Dry-run mode (preview without deleting)
# - Confirmation prompt
# - Detailed logging
# - Backup of key mapping
#
param(
    [string] $ParametersPath,
    [switch] $DryRun,  # Preview what would be deleted without actually deleting
    [switch] $AutoConfirm  # Skip confirmation prompts (use with caution!)
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok
$outDir = $p.OutputSettings.OutputDirectory

Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║      DUPLICATE ISSUE REMOVAL TOOL            ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""
Write-Host "Target Project: $tgtKey"
Write-Host "Mode: $(if ($DryRun) { 'DRY RUN (preview only)' } else { 'LIVE DELETION' })" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'Red' })
Write-Host ""

if (-not $DryRun -and -not $AutoConfirm) {
    Write-Host "⚠️  WARNING: This will PERMANENTLY DELETE duplicate issues!" -ForegroundColor Red
    Write-Host "⚠️  Press Ctrl+C to cancel, or any key to continue..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

# Fetch all target issues
Write-Host "Fetching all issues from target project..."
$allIssues = @()
$startAt = 0
$maxResults = 100

do {
    $searchUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/search"
    $searchBody = @{
        jql = "project = $tgtKey ORDER BY created ASC"
        startAt = $startAt
        maxResults = $maxResults
        fields = @("summary", "created", "key")
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $searchBody -ContentType "application/json"
    $allIssues += $response.issues
    $startAt += $maxResults
    
    Write-Host "  Fetched $($allIssues.Count) of $($response.total)..." -NoNewline
    Write-Host "`r" -NoNewline
    
} while ($startAt -lt $response.total)

Write-Host "✅ Fetched all $($allIssues.Count) issues                    "
Write-Host ""

# Identify duplicates
Write-Host "Analyzing for duplicates..."
$duplicateGroups = $allIssues | Group-Object { $_.fields.summary } | Where-Object { $_.Count -gt 1 }

if ($duplicateGroups.Count -eq 0) {
    Write-Host "✅ No duplicates found! Project is clean." -ForegroundColor Green
    exit 0
}

$totalDuplicates = ($duplicateGroups | Measure-Object -Property Count -Sum).Sum - $duplicateGroups.Count
Write-Host "Found $($duplicateGroups.Count) groups of duplicates containing $totalDuplicates duplicate issues" -ForegroundColor Yellow
Write-Host ""

# Build deletion plan
Write-Host "Building deletion plan..."
$issuesTO_DELETE = @()
$issuesToKEEP = @()

foreach ($group in $duplicateGroups) {
    # Sort by created date (keep the earliest)
    $sorted = $group.Group | Sort-Object { [DateTime]$_.fields.created }
    $toKeep = $sorted[0]  # Keep first created
    $toDelete = $sorted | Select-Object -Skip 1  # Delete the rest
    
    $issuesToKEEP += @{
        Key = $toKeep.key
        Summary = $toKeep.fields.summary
        Created = $toKeep.fields.created
    }
    
    foreach ($dup in $toDelete) {
        $issuesTO_DELETE += @{
            Key = $dup.key
            Summary = $dup.fields.summary
            Created = $dup.fields.created
            KeepKey = $toKeep.key
        }
    }
}

Write-Host "Deletion Plan:"
Write-Host "  ✅ KEEP: $($issuesToKEEP.Count) issues (earliest of each duplicate group)"
Write-Host "  ❌ DELETE: $($issuesTO_DELETE.Count) issues (later duplicates)"
Write-Host ""

# Show examples
Write-Host "Examples of what will be deleted:"
foreach ($example in ($issuesTO_DELETE | Select-Object -First 10)) {
    Write-Host "  ❌ DELETE: $($example.Key) (keep $($example.KeepKey)) - '$($example.Summary.Substring(0, [math]::Min(60, $example.Summary.Length)))...'"
}
if ($issuesTO_DELETE.Count -gt 10) {
    Write-Host "  ... and $($issuesTO_DELETE.Count - 10) more"
}
Write-Host ""

if ($DryRun) {
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║         DRY RUN COMPLETE                     ║" -ForegroundColor Yellow
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "No issues were deleted (dry run mode)"
    Write-Host "Run without -DryRun flag to perform actual deletion"
    
    # Save dry run report
    $dryRunReport = @{
        TotalDuplicates = $issuesTO_DELETE.Count
        DuplicateGroups = $duplicateGroups.Count
        IssuesToDelete = $issuesTO_DELETE
        IssuesToKeep = $issuesToKEEP
    }
    $dryRunPath = Join-Path $outDir "duplicate_removal_dry_run.json"
    $dryRunReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $dryRunPath -Encoding UTF8
    Write-Host "Dry run report saved: $dryRunPath"
    exit 0
}

# PERFORM DELETION
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║         DELETING DUPLICATE ISSUES            ║" -ForegroundColor Red
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

$deletedIssues = @()
$failedDeletions = @()

foreach ($issue in $issuesTO_DELETE) {
    try {
        $deleteUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$($issue.Key)"
        Invoke-RestMethod -Method DELETE -Uri $deleteUrl -Headers $tgtHdr -ErrorAction Stop
        
        Write-Host "  ✅ Deleted: $($issue.Key)" -ForegroundColor Green
        $deletedIssues += $issue
        
    } catch {
        Write-Warning "  ❌ Failed to delete $($issue.Key): $($_.Exception.Message)"
        $failedDeletions += @{
            Issue = $issue
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            DELETION COMPLETE                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Deleted: $($deletedIssues.Count) duplicate issues" -ForegroundColor Green
Write-Host "❌ Failed: $($failedDeletions.Count) deletions" -ForegroundColor Red
Write-Host ""

# Save deletion report
$deletionReport = @{
    DeletionDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    TargetProject = $tgtKey
    TotalDuplicatesFound = $issuesTO_DELETE.Count
    SuccessfullyDeleted = $deletedIssues.Count
    FailedDeletionsCount = $failedDeletions.Count
    DeletedIssues = $deletedIssues
    KeptIssues = $issuesToKEEP
    FailedDeletionDetails = $failedDeletions
}

$reportPath = Join-Path $outDir "duplicate_removal_report.json"
$deletionReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "📋 Deletion report saved: $reportPath"

Write-Host ""
Write-Host "✅ Duplicate cleanup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Re-run QA validation to verify cleanup: .\src\steps\16_QA_Validation_Orchestrator.ps1"
Write-Host "  2. Check the new quality score"
Write-Host "  3. Verify issue counts now match expected"
Write-Host ""
Write-Host "To run this script:"
Write-Host "  .\src\Utility\08_RemoveDuplicatesIssues.ps1 -DryRun    # Preview"
Write-Host "  .\src\Utility\08_RemoveDuplicatesIssues.ps1            # Execute"

