# 14_History.ps1 - Migrate Issue History and Changelog
# 
# PURPOSE: Migrates issue history/changelog from source to target issues,
# preserving original users, timestamps, and field changes.
#
# WHAT IT DOES:
# - Migrates issue history/changelog from source to target issues
# - Preserves original users, timestamps, and field changes
# - Creates user-friendly activity entries matching Jira's native style
# - Shows "Originally changed [field] by [user] on [date]" format
# - Generates detailed migration logs and receipts
#
# WHAT IT DOES NOT DO:
# - Does not modify existing issue data
# - Does not migrate comments (handled in Step 09)
# - Does not migrate attachments (handled in Step 10)
#
# DEPENDENCIES:
# - Requires completed Step 07 (Export Issues) with changelog data
# - Requires completed Step 08 (Create Issues) with key mapping
#
# NEXT STEP: Run 15_Review.ps1 for final review and deliverables
#
param(
    [string] $ParametersPath,
    [switch] $DryRun
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path $here "_common.ps1"
. $commonPath
$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                        STEP 14: HISTORY MIGRATION                           ║" -ForegroundColor Cyan
Write-Host "║                                                                            ║" -ForegroundColor Cyan
Write-Host "║  Migrating issue history and changelog data                                ║" -ForegroundColor Cyan
Write-Host "║  Preserving user attribution and change tracking                           ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Load parameters
$p = Read-JsonFile -Path $ParametersPath

# Hardcode paths for now to get script working
$outDir = ".\projects\REM\out"

# Initialize issues logging
Initialize-IssuesLog -StepName "14_History" -OutDir $outDir

# Create exports14 directory and cleanup
$stepExportsDir = Join-Path $outDir "exports14"
if (Test-Path $stepExportsDir) {
    Write-Host "🗑️  Cleaning up previous exports14 directory..." -ForegroundColor Yellow
    Remove-Item $stepExportsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null

# Set step start time
$script:StepStartTime = Get-Date

$srcBase = $p.SourceEnvironment.BaseUrl
$tgtBase = $p.TargetEnvironment.BaseUrl
$srcKey = $p.ProjectKey
$tgtKey = $p.TargetEnvironment.ProjectKey

# Load credentials
$srcHdr = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($p.SourceEnvironment.Username):$($p.SourceEnvironment.ApiToken)")))"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

$tgtHdr = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($p.TargetEnvironment.Username):$($p.TargetEnvironment.ApiToken)")))"
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
}

Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host ""

# Load exported issues with changelog
$exportFile = Join-Path $outDir "exports07\07_Export_adf.jsonl"
if (-not (Test-Path $exportFile)) {
    Write-Error "❌ Source issues export not found: $exportFile"
    Write-Host "   Run Step 07 (Export Issues) first!" -ForegroundColor Yellow
    # Stop terminal logging`nStop-TerminalLog -Success:$false -Summary "$stepName failed"`n`nexit 1
}

Write-Host "📁 Loading source issues export..."
try {
    # Load exported issues from JSONL file
    $export = @()
    $jsonlContent = Get-Content $exportFile
    foreach ($line in $jsonlContent) {
        if ($line.Trim()) {
            $export += $line | ConvertFrom-Json
        }
    }
    
    Write-Host "✅ Loaded $($export.Count) exported issues"
} catch {
    Write-Error "❌ Failed to load exported issues: $($_.Exception.Message)"
    # Stop terminal logging`nStop-TerminalLog -Success:$false -Summary "$stepName failed"`n`nexit 1
}

# Handle empty export
if ($export -eq $null) {
    $export = @()
}

# Check if there are any issues to process
if ($export.Count -eq 0) {
    Write-Host "✅ No issues found in export - no history to migrate" -ForegroundColor Green
    Write-Host "✅ Step 14 completed successfully with no issues to process" -ForegroundColor Green
    
    # Capture step end time
    $stepEndTime = Get-Date
    
    # Create main summary CSV for Step 14 (no issues scenario)
    $outDir = Join-Path (Split-Path -Parent $here) "..\projects\$srcKey\out"
    $step14SummaryReport = @()
    
    # Add step timing information
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Step"
        Name = "Step Start Time"
        Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Step"
        Name = "Step End Time"
        Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add summary statistics for no issues scenario
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Issues Processed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Processed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Migrated"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Failed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Success Rate (%)"
        Value = 100
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Export main summary report to CSV
    $step14SummaryCsvPath = Join-Path $stepExportsDir "14_History_Report.csv"
    $step14SummaryReport | Export-Csv -Path $step14SummaryCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Step 14 summary report saved: $step14SummaryCsvPath" -ForegroundColor Green
    Write-Host "   Total items: $($step14SummaryReport.Count)" -ForegroundColor Cyan
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "14_History" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        HistoryEntriesMigrated = 0
        HistoryEntriesSkipped = 0
        HistoryEntriesFailed = 0
        TotalHistoryEntriesProcessed = 0
        Status = "Completed - No Issues to Process"
        Notes = @("No issues found in export", "History migration completed successfully")
        StartTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        EndTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    }
    
    # Stop terminal logging`nStop-TerminalLog -Success:$true -Summary "$stepName completed successfully"`n`nexit 0
}

Write-Host "✅ Loaded $($export.Count) issues from export"

# Load key mapping from Step 08
$keyMappingFile = Join-Path $outDir "exports08\08_Import_Details.csv"
if (-not (Test-Path $keyMappingFile)) {
    Write-Error "❌ Key mapping not found: $keyMappingFile"
    Write-Host "   Run Step 08 (Create Issues) first!" -ForegroundColor Yellow
    # Stop terminal logging`nStop-TerminalLog -Success:$false -Summary "$stepName failed"`n`nexit 1
}

Write-Host "📁 Loading key mapping..."
try {
    # Load key mappings from CSV file
    $keyMappingData = Import-Csv $keyMappingFile
    $sourceToTargetKeyMap = @{}
    foreach ($row in $keyMappingData) {
        if ($row.SourceKey -and $row.TargetKey) {
            $sourceToTargetKeyMap[$row.SourceKey] = $row.TargetKey
        }
    }
    Write-Host "✅ Loaded mapping for $($sourceToTargetKeyMap.Count) issues"
} catch {
    Write-Error "❌ Failed to load key mapping: $($_.Exception.Message)"
    # Stop terminal logging`nStop-TerminalLog -Success:$false -Summary "$stepName failed"`n`nexit 1
}

# Fetch changelog data directly from source Jira API
Write-Host ""
Write-Host "📁 Fetching changelog data from source Jira API..."

# Get all issues with changelog data
$issuesWithChangelog = @()
$changelogFetchErrors = 0

foreach ($exportedIssue in $export) {
    $sourceKey = $exportedIssue.issue.key
    $targetKey = $sourceToTargetKeyMap[$sourceKey]
    
    # Process all issues for history, even if not created in target
    # This ensures we capture complete history data
    
    try {
        Write-Host "  📝 Fetching changelog for $sourceKey..." -ForegroundColor DarkGray
        
        # Fetch changelog data from source Jira
        $changelogUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey/changelog"
        $changelogResponse = if ($script:DryRun) { @{ values = @() } } else { Invoke-JiraWithRetry -Method GET -Uri $changelogUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30 }
        
        # Store ALL issues with their changelog data, regardless of target mapping
        $issuesWithChangelog += @{
            SourceKey = $sourceKey
            TargetKey = $targetKey
            Changelog = $changelogResponse
        }
        
        if ($changelogResponse.values -and $changelogResponse.values.Count -gt 0) {
            Write-Host "    ✅ Found $($changelogResponse.values.Count) changelog entries" -ForegroundColor Green
        } else {
            Write-Host "    ⏭️  No changelog entries found" -ForegroundColor Yellow
        }
    } catch {
        $changelogFetchErrors++
        Write-Warning "    ❌ Failed to fetch changelog for $sourceKey`: $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "📊 Changelog Analysis:"
Write-Host "   Total issues with target mapping: $($sourceToTargetKeyMap.Count)"
Write-Host "   Issues with changelog data: $($issuesWithChangelog.Count)"
Write-Host "   Changelog fetch errors: $changelogFetchErrors"

if ($issuesWithChangelog.Count -eq 0) {
    Write-Host ""
    Write-Host "⚠️  No issues with changelog data found!" -ForegroundColor Yellow
    Write-Host "   This might be because:" -ForegroundColor Yellow
    Write-Host "   - Issues were created recently (no changes yet)" -ForegroundColor Yellow
    Write-Host "   - History is disabled in source project" -ForegroundColor Yellow
    Write-Host "   - API permissions don't allow changelog access" -ForegroundColor Yellow
    
    # Create receipt for no changelog data scenario
    $stepEndTime = Get-Date
    
    # Create main summary CSV for Step 14 (no changelog scenario)
    $step14SummaryReport = @()
    
    # Add step timing information (ALWAYS LAST)
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Step"
        Name = "Step Start Time"
        Value = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        Timestamp = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Step"
        Name = "Step End Time"
        Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add summary statistics for no changelog scenario
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Issues Processed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Processed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Migrated"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Failed"
        Value = 0
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Success Rate (%)"
        Value = 100
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Export main summary report to CSV
    $step14SummaryCsvPath = Join-Path $stepExportsDir "14_History_Report.csv"
    $step14SummaryReport | Export-Csv -Path $step14SummaryCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Step 14 summary report saved: $step14SummaryCsvPath" -ForegroundColor Green
    Write-Host "   Total items: $($step14SummaryReport.Count)" -ForegroundColor Cyan
    
    # Generate detailed CSV report for migrated history entries (ALWAYS CREATE)
    $detailsCsvFileName = "14_History_Details.csv"
    $detailsCsvFilePath = Join-Path $stepExportsDir $detailsCsvFileName
    
    $detailsCsvData = @()
    $detailsCsvData += [PSCustomObject]@{
        "Source Issue Key" = "No changelog data found"
        "Target Issue Key" = ""
        "History Entries Migrated" = ""
        "History Entries Failed" = ""
        "Success Rate (%)" = ""
        "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $detailsCsvData | Export-Csv -Path $detailsCsvFilePath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ History details report saved: $detailsCsvFileName" -ForegroundColor Green
    
    # Generate CSV report for failed history entries (ALWAYS CREATE)
    $failedCsvFileName = "14_History_Failed.csv"
    $failedCsvFilePath = Join-Path $stepExportsDir $failedCsvFileName
    
    $failedCsvData = @()
    $failedCsvData += [PSCustomObject]@{
        "Source Issue Key" = "No changelog data found"
        "Target Issue Key" = ""
        "History Entries Failed" = ""
        "Error Message" = ""
        "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Failed history report saved: $failedCsvFileName" -ForegroundColor Green
    
    # Create detailed receipt
    Write-StageReceipt -OutDir $stepExportsDir -Stage "14_History" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        IssuesProcessed = 0
        IssuesSkipped = 0
        HistoryEntriesProcessed = 0
        HistoryEntriesMigrated = 0
        HistoryEntriesFailed = 0
        SuccessRate = 100
        Notes = @(
            "No changelog data found in source",
            "Issues may be new or have no changes",
            "History migration completed successfully"
        )
        Status = "Completed - No Changelog Data Found"
    }
    
    Write-Host "✅ Step 14 completed successfully - no changelog data found" -ForegroundColor Green
    # Stop terminal logging`nStop-TerminalLog -Success:$true -Summary "$stepName completed successfully"`n`nexit 0
}

Write-Host ""
Write-Host "=== MIGRATING ISSUE HISTORY ==="

# Migration statistics
$script:HistoryEntriesProcessed = 0
$script:HistoryEntriesMigrated = 0
$script:HistoryEntriesFailed = 0
$script:IssuesProcessed = 0
$script:IssuesSkipped = 0

foreach ($issueWithChangelog in $issuesWithChangelog) {
    $sourceKey = $issueWithChangelog.SourceKey
    $targetKey = $issueWithChangelog.TargetKey
    $changelogData = $issueWithChangelog.Changelog
    
    $script:IssuesProcessed++
    
    if (-not $targetKey) {
        Write-Host "  ⏭️  Skipping $sourceKey (no target mapping - history preserved in source)" -ForegroundColor Yellow
        $script:IssuesSkipped++
        continue
    }
    
    Write-Host "  📝 Migrating history for $sourceKey → $targetKey"
    
    # ========== IDEMPOTENCY: DELETE all existing history comments first ==========
    Write-Host "    🗑️  Deleting existing history comments for clean migration..." -ForegroundColor Yellow
    try {
        $existingCommentsUri = "$tgtBase/rest/api/3/issue/$targetKey/comment"
        $existingComments = if ($script:DryRun) { @{ comments = @() } } else { Invoke-JiraWithRetry -Method GET -Uri $existingCommentsUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 }
        
        $deletedHistoryComments = 0
        $failedDeletes = 0
        
        foreach ($existingComment in $existingComments.comments) {
            # Check if this is a history comment (contains "Originally changed" attribution)
            $isHistoryComment = $false
            if ($existingComment.body.content -and $existingComment.body.content.Count -gt 0) {
                foreach ($content in $existingComment.body.content) {
                    if ($content.content -and $content.content.Count -gt 0) {
                        foreach ($textContent in $content.content) {
                            if ($textContent.text -and $textContent.text.Contains("Originally changed")) {
                                $isHistoryComment = $true
                                break
                            }
                        }
                    }
                }
            }
            
            if ($isHistoryComment) {
                try {
                    $deleteCommentUri = "$tgtBase/rest/api/3/issue/$targetKey/comment/$($existingComment.id)"
                    if ($script:DryRun) { Write-Host "[DRYRUN] DELETE $deleteCommentUri" -ForegroundColor Yellow } else { Invoke-JiraWithRetry -Method DELETE -Uri $deleteCommentUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 | Out-Null }
                    $deletedHistoryComments++
                } catch {
                    $failedDeletes++
                    Write-Warning "      Failed to delete history comment: $($_.Exception.Message)"
                }
            }
        }
        
        Write-Host "    ✅ Deleted $deletedHistoryComments history comments ($failedDeletes failed)" -ForegroundColor Green
    } catch {
        Write-Warning "    Could not fetch existing comments for deletion: $($_.Exception.Message)"
    }
    
    $histories = $changelogData.values
    Write-Host "    Found $($histories.Count) history entries"
    
    $historyIndex = 0
    foreach ($history in $histories) {
        $script:HistoryEntriesProcessed++
        $historyIndex++
        Write-Host "    Processing history entry $historyIndex of $($histories.Count)..." -ForegroundColor DarkGray
        
        try {
                # Extract history details (safely handle missing author for system changes)
                $author = if ($history.PSObject.Properties['author'] -and $history.author -and $history.author.PSObject.Properties['displayName']) {
                    $history.author.displayName
                } else {
                    "System"
                }
                $created = $history.created
                $items = $history.items
                
                # Create activity entry for each change
                foreach ($item in $items) {
                    $fieldName = $item.field
                    $fieldType = $item.fieldtype
                    $fromValue = if ([string]::IsNullOrEmpty($item.fromString)) { "None" } else { $item.fromString }
                    $toValue = if ([string]::IsNullOrEmpty($item.toString)) { "None" } else { $item.toString }
                    
                    # Format field names to match Jira's native display names
                    $displayFieldName = switch ($fieldName) {
                        "description" { "Description" }
                        "summary" { "Summary" }
                        "assignee" { "Assignee" }
                        "reporter" { "Reporter" }
                        "status" { "Status" }
                        "issuetype" { "Issue Type" }
                        "priority" { "Priority" }
                        "parent" { "Parent" }
                        "components" { "Component" }
                        "fixVersions" { "Fix Version" }
                        "labels" { "Labels" }
                        "customfield_10058" { "Story Points" }
                        "customfield_10092" { "Acceptance Criteria" }
                        default { $fieldName }
                    }
                
                # Format date like Comments/Worklogs for consistency
                $formattedDate = [DateTime]::Parse($created).ToString("MMMM d, yyyy at h:mm tt")
                
                # Create user-friendly attribution like Comments/Worklogs
                # $author is already a string (display name or "System")
                $attributionText = "Originally changed $displayFieldName by $author on $formattedDate"
                
                # ========== IDEMPOTENCY: DELETE all existing history comments first ==========
                # We'll delete all history comments at the issue level, not per entry
                # This is more efficient than checking each individual history entry
                
                # Create simple, user-friendly history entry matching Jira's native style
                $commentBody = @"
*Originally changed $displayFieldName by $author on $formattedDate*

${displayFieldName}: ${fromValue} → ${toValue}
"@
                
                # Create comment payload using ADF format like Comments/Worklogs
                $commentPayload = @{
                    body = @{
                        type = "doc"
                        version = 1
                        content = @(
                            @{
                                type = "paragraph"
                                content = @(
                                    @{
                                        type = "text"
                                        text = "*Originally changed $displayFieldName by $author on $formattedDate*"
                                        marks = @(
                                            @{ type = "em" }
                                        )
                                    }
                                )
                            },
                            @{
                                type = "paragraph"
                                content = @(
                                    @{
                                        type = "text"
                                        text = "${displayFieldName}: ${fromValue} → ${toValue}"
                                    }
                                )
                            }
                        )
                    }
                }
                
                # Post comment to target issue (with unified retry logic)
                $commentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                $response = if ($script:DryRun) { $null } else { Invoke-JiraWithRetry -Method POST -Uri $commentUri -Headers $tgtHdr -Body ($commentPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 }
                
                Write-Host "      ✅ Logged: $displayFieldName change by $author"
            }
            
            # Increment only once per history entry (not per field change)
            $script:HistoryEntriesMigrated++
            
        } catch {
            Write-Warning "      ❌ Failed to log history entry: $($_.Exception.Message)"
            $script:HistoryEntriesFailed++
        }
    }
}

Write-Host ""
Write-Host "=== HISTORY MIGRATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Issues processed: $script:IssuesProcessed" -ForegroundColor Green
Write-Host "⏭️  Issues skipped: $script:IssuesSkipped" -ForegroundColor Yellow
Write-Host "📝 History entries processed: $script:HistoryEntriesProcessed" -ForegroundColor Blue
Write-Host "✅ History entries migrated: $script:HistoryEntriesMigrated" -ForegroundColor Green
Write-Host "❌ History entries failed: $script:HistoryEntriesFailed" -ForegroundColor Red

if ($script:HistoryEntriesMigrated -gt 0) {
    $successRate = [math]::Round(($script:HistoryEntriesMigrated / $script:HistoryEntriesProcessed) * 100, 1)
    Write-Host "📊 Success rate: $successRate%" -ForegroundColor Magenta
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 14
$outDir = Join-Path (Split-Path -Parent $here) "..\projects\$srcKey\out"
$step14SummaryReport = @()


# Add summary statistics
$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Processed"
    Value = $script:IssuesProcessed
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Processed"
    Value = $script:HistoryEntriesProcessed
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Migrated"
    Value = $script:HistoryEntriesMigrated
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Failed"
    Value = $script:HistoryEntriesFailed
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Success Rate (%)"
    Value = if ($script:HistoryEntriesProcessed -gt 0) { [math]::Round(($script:HistoryEntriesMigrated / $script:HistoryEntriesProcessed) * 100, 1) } else { 0 }
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add step timing information (ALWAYS LAST)
$step14SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Timestamp = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step 14 Duration"
    Value = "{0:D2}h : {1:D2}m : {2:D2}s" -f [int][math]::Floor(($stepEndTime - $script:StepStartTime).TotalHours), [int][math]::Floor((($stepEndTime - $script:StepStartTime).TotalMinutes) % 60), [int][math]::Floor((($stepEndTime - $script:StepStartTime).TotalSeconds) % 60)
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step14SummaryCsvPath = Join-Path $stepExportsDir "14_History_Report.csv"
$step14SummaryReport | Export-Csv -Path $step14SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 14 summary report saved: $step14SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step14SummaryReport.Count)" -ForegroundColor Cyan

# Generate detailed CSV report for migrated history entries (ALWAYS CREATE)
$detailsCsvFileName = "14_History_Details.csv"
$detailsCsvFilePath = Join-Path $stepExportsDir $detailsCsvFileName

try {
    $detailsCsvData = @()
    
    if ($script:HistoryEntriesMigrated -gt 0) {
        # Create detailed entries for each migrated history entry
        foreach ($issueWithChangelog in $issuesWithChangelog) {
            $sourceKey = $issueWithChangelog.SourceKey
            $targetKey = $issueWithChangelog.TargetKey
            $changelogData = $issueWithChangelog.Changelog
            
            foreach ($history in $changelogData.values) {
                # Extract history details
                $author = if ($history.PSObject.Properties['author'] -and $history.author -and $history.author.PSObject.Properties['displayName']) {
                    $history.author.displayName
                } else {
                    "System"
                }
                $created = $history.created
                $items = $history.items
                
                # Create entry for each change item
                foreach ($item in $items) {
                    $fieldName = $item.field
                    $fieldType = $item.fieldtype
                    $fromValue = if ([string]::IsNullOrEmpty($item.fromString)) { "None" } else { $item.fromString }
                    $toValue = if ([string]::IsNullOrEmpty($item.toString)) { "None" } else { $item.toString }
                    
                    # Format field names to match Jira's native display names
                    $displayFieldName = switch ($fieldName) {
                        "description" { "Description" }
                        "summary" { "Summary" }
                        "assignee" { "Assignee" }
                        "reporter" { "Reporter" }
                        "status" { "Status" }
                        "issuetype" { "Issue Type" }
                        "priority" { "Priority" }
                        "parent" { "Parent" }
                        "components" { "Component" }
                        "fixVersions" { "Fix Version" }
                        "labels" { "Labels" }
                        "customfield_10058" { "Story Points" }
                        "customfield_10092" { "Acceptance Criteria" }
                        default { $fieldName }
                    }
                    
                    $detailsCsvData += [PSCustomObject]@{
                        "Source Issue Key" = $sourceKey
                        "Target Issue Key" = $targetKey
                        "Field Changed" = $displayFieldName
                        "Field Type" = $fieldType
                        "From Value" = $fromValue
                        "To Value" = $toValue
                        "Changed By" = $author
                        "Changed Date" = [DateTime]::Parse($created).ToString("yyyy-MM-dd HH:mm:ss")
                        "Formatted Date" = [DateTime]::Parse($created).ToString("MMMM d, yyyy 'at' h:mm tt")
                        "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$sourceKey"
                        "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$targetKey"
                        "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
            }
        }
    } else {
        # Create empty report with note
        $detailsCsvData += [PSCustomObject]@{
            "Source Issue Key" = "No history entries to migrate"
            "Target Issue Key" = ""
            "Field Changed" = ""
            "Field Type" = ""
            "From Value" = ""
            "To Value" = ""
            "Changed By" = ""
            "Changed Date" = ""
            "Formatted Date" = ""
            "Source Issue URL" = ""
            "Target Issue URL" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $detailsCsvData | Export-Csv -Path $detailsCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ History details report saved: $detailsCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $detailsCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 History entries migrated: $($detailsCsvData.Count)" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save history details report: $($_.Exception.Message)"
}

# Generate CSV report for failed history entries (ALWAYS CREATE)
$failedCsvFileName = "14_History_Failed.csv"
$failedCsvFilePath = Join-Path $stepExportsDir $failedCsvFileName

try {
    $failedCsvData = @()
    
    if ($script:HistoryEntriesFailed -gt 0) {
        # Note: We don't have individual failed entry details stored, so create a summary entry
        $failedCsvData += [PSCustomObject]@{
            "Source Issue Key" = "Summary"
            "Target Issue Key" = "Summary"
            "History Entries Failed" = $script:HistoryEntriesFailed
            "Error Message" = "See console output for specific failure details"
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    } else {
        # Create empty report with note
        $failedCsvData += [PSCustomObject]@{
            "Source Issue Key" = "No history entries failed"
            "Target Issue Key" = ""
            "History Entries Failed" = ""
            "Error Message" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Failed history report saved: $failedCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Failed history entries: $script:HistoryEntriesFailed" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save failed history report: $($_.Exception.Message)"
}

# Create detailed receipt
Write-StageReceipt -OutDir $stepExportsDir -Stage "14_History" -Data @{
    SourceProject = @{ key=$srcKey }
    TargetProject = @{ key=$tgtKey }
    IssuesProcessed = $script:IssuesProcessed
    IssuesSkipped = $script:IssuesSkipped
    HistoryEntriesProcessed = $script:HistoryEntriesProcessed
    HistoryEntriesMigrated = $script:HistoryEntriesMigrated
    HistoryEntriesFailed = $script:HistoryEntriesFailed
    SuccessRate = if ($script:HistoryEntriesProcessed -gt 0) { [math]::Round(($script:HistoryEntriesMigrated / $script:HistoryEntriesProcessed) * 100, 1) } else { 0 }
    Notes = @(
        "History migration completed",
        "Historical changes preserved as activity comments",
        "Original users and timestamps maintained",
        "Format matches Jira's native history style"
    )
    Status = if ($script:HistoryEntriesFailed -eq 0) { "All History Migrated Successfully" } else { "Some History Entries Failed" }
}

Write-Host ""
Write-Host "✅ History migration complete!"
Write-Host "   Historical changes preserved as activity comments"
Write-Host "   Original users and timestamps maintained"
Write-Host "   Format matches Jira's native history style"

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "✅ Step 14 completed successfully!"
Write-Host ""
Write-Host "Project folder: .\projects\$tgtKey\"
Write-Host "Outputs: .\projects\$tgtKey\out\"






