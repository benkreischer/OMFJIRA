# =============================================================================
# JIRA MIGRATION TOOLKIT - STEP 14: HISTORY MIGRATION
# =============================================================================
#
# PURPOSE:
# - Migrates issue history/changelog from source to target issues
# - Preserves original users, timestamps, and field changes
# - Creates user-friendly activity entries matching Jira's native style
# - Shows "Originally changed [field] by [user] on [date]" format
#
# DEPENDENCIES:
# - Requires completed Step 07 (Export Issues) with changelog data
# - Requires completed Step 08 (Create Issues) with key mapping
#
# INPUTS:
# - Source issues export with changelog data
# - Target project with created issues
#
# OUTPUTS:
# - Historical activity entries in target issues
# - Migration receipt with statistics
#
# NEXT STEP: Run 15_ReviewMigration.ps1 for final review and deliverables
#
param(
    [string] $ParametersPath
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

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

# Capture step start time
$stepStartTime = Get-Date

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
$exportFile = Join-Path (Split-Path -Parent $here) "..\projects\$srcKey\out\exports\source_issues_export.json"
if (-not (Test-Path $exportFile)) {
    Write-Error "❌ Source issues export not found: $exportFile"
    Write-Host "   Run Step 07 (Export Issues) first!" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Loading source issues export..."
$export = Get-Content $exportFile -Raw | ConvertFrom-Json

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
        Details = "Step execution started"
        Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Step"
        Name = "Step End Time"
        Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
        Details = "Step execution completed"
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add summary statistics for no issues scenario
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Issues Processed"
        Value = 0
        Details = "No issues found in export"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Processed"
        Value = 0
        Details = "No history entries to process"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Migrated"
        Value = 0
        Details = "No history entries migrated"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "History Entries Failed"
        Value = 0
        Details = "No history entries failed"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $step14SummaryReport += [PSCustomObject]@{
        Type = "Summary"
        Name = "Success Rate (%)"
        Value = 100
        Details = "No issues to process - considered successful"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Export main summary report to CSV
    $step14SummaryCsvPath = Join-Path $outDir "14_HistoryMigration_SummaryReport.csv"
    $step14SummaryReport | Export-Csv -Path $step14SummaryCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Step 14 summary report saved: $step14SummaryCsvPath" -ForegroundColor Green
    Write-Host "   Total items: $($step14SummaryReport.Count)" -ForegroundColor Cyan
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "14_HistoryMigration" -Data @{
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
    
    exit 0
}

Write-Host "✅ Loaded $($export.Count) issues from export"

# Load key mapping from Step 08
$keyMappingFile = Join-Path (Split-Path -Parent $here) "..\projects\$srcKey\out\08_CreateIssues_Target_receipt.json"
if (-not (Test-Path $keyMappingFile)) {
    Write-Error "❌ Key mapping not found: $keyMappingFile"
    Write-Host "   Run Step 08 (Create Issues) first!" -ForegroundColor Yellow
    exit 1
}

Write-Host "📁 Loading key mapping..."
$keyMapping = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
$sourceToTargetKeyMap = @{}
foreach ($key in $keyMapping.SourceToTargetKeyMapping.PSObject.Properties.Name) {
    $sourceToTargetKeyMap[$key] = $keyMapping.SourceToTargetKeyMapping.$key
}
Write-Host "✅ Loaded mapping for $($sourceToTargetKeyMap.Count) issues"

# Filter issues that have changelog data
$issuesWithHistory = $export | Where-Object { $_.changelog -and $_.changelog.values -and $_.changelog.values.Count -gt 0 }
Write-Host ""
Write-Host "📊 History Analysis:"
Write-Host "   Total issues: $($export.Count)"
Write-Host "   Issues with history: $($issuesWithHistory.Count)"
Write-Host "   Issues with target mapping: $($issuesWithHistory | Where-Object { $sourceToTargetKeyMap.ContainsKey($_.key) }).Count"

if ($issuesWithHistory.Count -eq 0) {
    Write-Host ""
    Write-Host "⚠️  No issues with history data found!" -ForegroundColor Yellow
    Write-Host "   This might be because:" -ForegroundColor Yellow
    Write-Host "   - Issues were created recently (no changes yet)" -ForegroundColor Yellow
    Write-Host "   - Export didn't include changelog data" -ForegroundColor Yellow
    Write-Host "   - History is disabled in source project" -ForegroundColor Yellow
    exit 0
}

# Migration statistics
$script:HistoryEntriesProcessed = 0
$script:HistoryEntriesMigrated = 0
$script:HistoryEntriesFailed = 0
$script:IssuesProcessed = 0
$script:IssuesSkipped = 0

Write-Host ""
Write-Host "=== MIGRATING ISSUE HISTORY ==="

foreach ($sourceIssue in $issuesWithHistory) {
    $sourceKey = $sourceIssue.key
    $targetKey = $sourceToTargetKeyMap[$sourceKey]
    
    if (-not $targetKey) {
        Write-Host "  ⏭️  Skipping $sourceKey (not created in target)" -ForegroundColor Yellow
        $script:IssuesSkipped++
        continue
    }
    
    $script:IssuesProcessed++
    Write-Host "  📝 Migrating history for $sourceKey → $targetKey"
    
    $histories = $sourceIssue.changelog.values
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
                
                # ========== IDEMPOTENCY CHECK ==========
                # Check if this history entry already exists by matching the attribution text
                $historyExists = $false
                
                # Get existing comments to check for duplicates (with unified retry logic)
                try {
                    $existingCommentsUri = "$tgtBase/rest/api/3/issue/$targetKey/comment"
                    $existingComments = Invoke-JiraWithRetry -Method GET -Uri $existingCommentsUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
                    
                    foreach ($existingComment in $existingComments.comments) {
                        if ($existingComment.body.content -and $existingComment.body.content.Count -gt 0) {
                            foreach ($content in $existingComment.body.content) {
                                if ($content.content -and $content.content.Count -gt 0) {
                                    foreach ($textContent in $content.content) {
                                        if ($textContent.text -and $textContent.text.Contains($attributionText)) {
                                            $historyExists = $true
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    # If we can't check existing comments, continue anyway
                }
                
                if ($historyExists) {
                    Write-Host "      ⏭️  History entry already exists, skipping"
                    continue
                }
                
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
                $response = Invoke-JiraWithRetry -Method POST -Uri $commentUri -Headers $tgtHdr -Body ($commentPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                
                Write-Host "      ✅ Logged: $displayFieldName change by $author"
                $script:HistoryEntriesMigrated++
            }
            
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
$step14SummaryReport = @()

# Add step timing information
$step14SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Add summary statistics
$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Processed"
    Value = $totalIssuesProcessed
    Details = "Total issues processed for history migration"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Processed"
    Value = $totalHistoryEntries
    Details = "Total history entries processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Migrated"
    Value = $totalHistoryMigrated
    Details = "History entries successfully migrated to target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "History Entries Failed"
    Value = $totalHistoryFailed
    Details = "History entries that failed to migrate"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step14SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Success Rate (%)"
    Value = if ($totalHistoryEntries -gt 0) { [math]::Round(($totalHistoryMigrated / $totalHistoryEntries) * 100, 1) } else { 0 }
    Details = "Percentage of history entries successfully migrated"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step14SummaryCsvPath = Join-Path $outDir "14_HistoryMigration_SummaryReport.csv"
$step14SummaryReport | Export-Csv -Path $step14SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 14 summary report saved: $step14SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step14SummaryReport.Count)" -ForegroundColor Cyan

# Create receipt
$outDir = Join-Path (Split-Path -Parent $here) "..\projects\$srcKey\out"
$receiptFile = Join-Path $outDir "14_HistoryMigration_receipt.json"

$receipt = @{
    StepNumber = "14"
    StepName = "History Migration"
    TimeUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    SourceProject = $srcKey
    TargetProject = $tgtKey
    IssuesProcessed = $script:IssuesProcessed
    IssuesSkipped = $script:IssuesSkipped
    HistoryEntriesProcessed = $script:HistoryEntriesProcessed
    HistoryEntriesMigrated = $script:HistoryEntriesMigrated
    HistoryEntriesFailed = $script:HistoryEntriesFailed
    SuccessRate = if ($script:HistoryEntriesProcessed -gt 0) { [math]::Round(($script:HistoryEntriesMigrated / $script:HistoryEntriesProcessed) * 100, 1) } else { 0 }
}

$receipt | ConvertTo-Json -Depth 10 | Out-File -FilePath $receiptFile -Encoding UTF8
Write-Host ""
Write-Host "✅ Receipt saved: $receiptFile"

# Update reference receipt
$refReceiptFile = Join-Path $outDir "14_HistoryMigration_receipt.json"
if ($receiptFile -ne $refReceiptFile) {
    Copy-Item -Path $receiptFile -Destination $refReceiptFile -Force
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
