# 12_Worklogs.ps1 - Migrate Time Tracking Worklogs
# 
# PURPOSE: Migrates all worklog entries from source issues to target issues,
# preserving time tracking data, comments, and user assignments.
#
# WHAT IT DOES:
# - Retrieves all worklog entries from source issues
# - Maps worklogs to corresponding target issues using key mappings
# - Preserves worklog authors, time spent, dates, and comments
# - Handles worklog visibility and permissions
# - Creates detailed migration logs and receipts
#
# WHAT IT DOES NOT DO:
# - Does not modify worklog time entries or dates
# - Does not migrate worklogs for issues that failed to create
# - Does not adjust worklog timestamps for time zone differences
#
# NEXT STEP: Run 13_Sprints.ps1 to recreate closed sprints
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

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey  # Source project key is at root level in config
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir = $p.OutputSettings.OutputDirectory
$batchSize = $p.AnalysisSettings.BatchSize

# Initialize issues logging
Initialize-IssuesLog -StepName "12_Worklogs" -OutDir $outDir

Write-Host "=== MIGRATING TIME TRACKING WORKLOGS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host "Batch Size: $batchSize"

# Load exported data and key mappings from previous steps
$exportDir = Join-Path $outDir "exports"
$exportFile = Join-Path $exportDir "source_issues_export.json"
$keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"

Write-Host ""
Write-Host "=== LOADING DATA FROM PREVIOUS STEPS ==="
if (-not (Test-Path $exportFile)) {
    throw "Export file not found: $exportFile. Please run step 07_ExportIssues_Source.ps1 first."
}
if (-not (Test-Path $keyMappingFile)) {
    Write-Host "⚠️ Key mapping file not found: $keyMappingFile" -ForegroundColor Yellow
    Write-Host "This usually means no issues were migrated in Step 8" -ForegroundColor Yellow
    Write-Host "✅ Step 12 completed successfully with no issues to process" -ForegroundColor Green
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "12_Worklogs" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        WorklogsMigrated = 0
        WorklogsSkipped = 0
        WorklogsFailed = 0
        TotalWorklogsProcessed = 0
        Status = "Completed - No Issues to Process"
        Notes = @("No issues were migrated in Step 8", "Worklogs migration completed successfully")
        StartTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        EndTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    }
    
    exit 0
}

try {
    $exportedIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
    $sourceToTargetKeyMapObj = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
    
    # Convert PSCustomObject to hashtable for proper key lookups
    $sourceToTargetKeyMap = @{}
    foreach ($prop in $sourceToTargetKeyMapObj.PSObject.Properties) {
        $sourceToTargetKeyMap[$prop.Name] = $prop.Value
    }
    
    Write-Host "✅ Loaded $($exportedIssues.Count) exported issues"
    Write-Host "✅ Loaded $($sourceToTargetKeyMap.Count) key mappings"
} catch {
    throw "Failed to load data from previous steps: $($_.Exception.Message)"
}

# Get target project details
Write-Host "Retrieving target project details..."
try {
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve target project: $($_.Exception.Message)"
}

# Worklog migration tracking
$migratedWorklogs = @()
$failedWorklogs = @()
$skippedWorklogs = 0
$totalWorklogsProcessed = 0
$totalTimeSpent = 0

Write-Host ""
Write-Host "=== MIGRATING WORKLOGS ==="

# Process issues in batches
for ($i = 0; $i -lt $exportedIssues.Count; $i += $batchSize) {
    $batch = $exportedIssues | Select-Object -Skip $i -First $batchSize
    $batchNum = [math]::Floor($i / $batchSize) + 1
    $totalBatches = [math]::Ceiling($exportedIssues.Count / $batchSize)
    
    Write-Host "Processing batch $batchNum of $totalBatches (issues $($i + 1) to $([math]::Min($i + $batchSize, $exportedIssues.Count)))..."
    
    foreach ($sourceIssue in $batch) {
        $sourceKey = $sourceIssue.key
        
        # Check if this issue was successfully created in target
        if (-not $sourceToTargetKeyMap.ContainsKey($sourceKey)) {
            Write-Host "  ⏭️  Skipping $sourceKey (not created in target)"
            continue
        }
        
        $targetKey = $sourceToTargetKeyMap[$sourceKey]
        Write-Host "  Migrating worklogs for $sourceKey → $targetKey"
        
        try {
            # Get worklogs from source issue (with unified retry logic)
            $worklogsUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey/worklog"
            $sourceWorklogs = Invoke-JiraWithRetry -Method GET -Uri $worklogsUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
            
            if (-not $sourceWorklogs.worklogs -or $sourceWorklogs.worklogs.Count -eq 0) {
                Write-Host "    ℹ️  No worklogs found"
                continue
            }
            
            Write-Host "    Found $($sourceWorklogs.worklogs.Count) worklogs"
            
            # ========== IDEMPOTENCY: Get existing worklogs from target ==========
            $existingWorklogsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/worklog"
            $existingWorklogs = @()
            try {
                $existingWorklogsResponse = Invoke-JiraWithRetry -Method GET -Uri $existingWorklogsUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
                if ($existingWorklogsResponse.worklogs) {
                    $existingWorklogs = $existingWorklogsResponse.worklogs
                }
            } catch {
                Write-Host "      ⚠️  Could not fetch existing worklogs: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Process each worklog
            $worklogIndex = 0
            foreach ($worklog in $sourceWorklogs.worklogs) {
                $totalWorklogsProcessed++
                $worklogIndex++
                Write-Host "    Processing worklog $worklogIndex of $($sourceWorklogs.worklogs.Count)..." -ForegroundColor DarkGray
                
                try {
                    # Get original author and date for attribution
                    $originalAuthor = if ($worklog.PSObject.Properties['author'] -and $worklog.author -and $worklog.author.PSObject.Properties['displayName']) {
                        $worklog.author.displayName
                    } else {
                        "Unknown"
                    }
                    
                    $originalDate = if ($worklog.started) {
                        ([DateTime]$worklog.started).ToString("MMMM d, yyyy \a\t h:mm tt")
                    } else {
                        "Unknown date"
                    }
                    
                    # ========== IDEMPOTENCY CHECK ==========
                    # Check if worklog with same attribution already exists
                    $attributionText = "Originally logged $($worklog.timeSpent) by $originalAuthor on $originalDate"
                    $worklogExists = $false
                    
                    foreach ($existingWorklog in $existingWorklogs) {
                        # Check if comment property exists before accessing it
                        if (-not ($existingWorklog.PSObject.Properties['comment'])) {
                            continue
                        }
                        
                        $existingComment = $existingWorklog.comment
                        
                        # Skip if comment is null
                        if (-not $existingComment) {
                            continue
                        }
                        
                        # Check in both ADF and plain text formats
                        if ($existingComment -is [PSCustomObject] -and $existingComment.type -eq "doc") {
                            # ADF format - check content
                            $existingCommentJson = $existingComment | ConvertTo-Json -Depth 20 -Compress
                            if ($existingCommentJson -like "*$attributionText*") {
                                $worklogExists = $true
                                break
                            }
                        } elseif ($existingComment -is [string] -and $existingComment -like "*$attributionText*") {
                            # Plain text format
                            $worklogExists = $true
                            break
                        }
                    }
                    
                    if ($worklogExists) {
                        Write-Host "      ⏭️  Worklog already exists (skipped): $($worklog.timeSpent)" -ForegroundColor Yellow
                        $skippedWorklogs++
                        continue
                    }
                    
                
                    # Build worklog payload
                    # Convert started date to UTC with +0000 format (Jira API requirement)
                    $startedDate = [DateTime]::Parse($worklog.started)
                    $startedUtc = $startedDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fff+0000")
                    
                    $worklogPayload = @{
                        timeSpent = $worklog.timeSpent
                        started = $startedUtc
                    }
                    
                    # Build comment with attribution
                    # Note: Jira API doesn't support setting worklog author, so we prepend this info to the comment
                    # Check if comment property exists before accessing it
                    $worklogComment = $null
                    if ($worklog.PSObject.Properties['comment'] -and $worklog.comment) {
                        $worklogComment = $worklog.comment
                    }
                    
                    if ($worklogComment -is [PSCustomObject] -and $worklogComment.type -eq "doc") {
                        # ADF format - prepend attribution paragraph
                        $attributionParagraph = @{
                            type = "paragraph"
                            content = @(
                                @{
                                    type = "text"
                                    text = "Originally logged $($worklog.timeSpent) by $originalAuthor on $originalDate"
                                    marks = @(
                                        @{ type = "em" }
                                    )
                                }
                            )
                        }
                        
                        # Insert attribution at the beginning of content array
                        $newContent = @($attributionParagraph) + $worklogComment.content
                        $worklogPayload.comment = @{
                            type = "doc"
                            version = 1
                            content = $newContent
                        }
                    } elseif ($worklogComment) {
                        # Plain text format (or string) - prepend attribution
                        $worklogPayload.comment = "*Originally logged $($worklog.timeSpent) by $originalAuthor on $originalDate*`n`n$worklogComment"
                    } else {
                        # No existing comment - create one with just attribution in ADF format
                        $worklogPayload.comment = @{
                            type = "doc"
                            version = 1
                            content = @(
                                @{
                                    type = "paragraph"
                                    content = @(
                                        @{
                                            type = "text"
                                            text = "Originally logged $($worklog.timeSpent) by $originalAuthor on $originalDate"
                                            marks = @(
                                                @{ type = "em" }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    }
                    
                    # Note: Cannot set author via API - worklogs are created by authenticated user
                    # The updateAuthor parameter would require special permissions
                    
                    # Add visibility if specified (skip 'group' type as it may not exist in target)
                    # Check if visibility property exists and is valid
                    if ($worklog.PSObject.Properties['visibility'] -and 
                        $worklog.visibility -and 
                        $worklog.visibility.PSObject.Properties['type'] -and 
                        $worklog.visibility.type -ne 'group') {
                        $worklogPayload.visibility = $worklog.visibility
                    }
                    
                    # Create worklog in target issue (with unified retry logic)
                    $createWorklogUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/worklog"
                    $worklogJson = $worklogPayload | ConvertTo-Json -Depth 20
                    $response = Invoke-JiraWithRetry -Method POST -Uri $createWorklogUri -Headers $tgtHdr -Body $worklogJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                    
                    # Parse time spent for tracking
                    $timeSpentSeconds = 0
                    if ($worklog.timeSpentSeconds) {
                        $timeSpentSeconds = $worklog.timeSpentSeconds
                        $totalTimeSpent += $timeSpentSeconds
                    }
                    
                    Write-Host "      ✅ Worklog created (id=$($response.id)) - $($worklog.timeSpent)"
                    $migratedWorklogs += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceWorklogId = $worklog.id
                        TargetWorklogId = $response.id
                        Author = if ($worklog.PSObject.Properties['author'] -and $worklog.author -and $worklog.author.PSObject.Properties['displayName']) { $worklog.author.displayName } else { "Unknown" }
                        TimeSpent = $worklog.timeSpent
                        TimeSpentSeconds = $timeSpentSeconds
                        Started = $worklog.started
                        Comment = if ($worklog.PSObject.Properties['comment'] -and $worklog.comment) { "Present" } else { "None" }  # Comment is ADF object, just track if present
                    }
                    
                } catch {
                    Write-Warning "      ❌ Failed to create worklog: $($_.Exception.Message)"
                    $failedWorklogs += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceWorklogId = $worklog.id
                        Author = if ($worklog.PSObject.Properties['author'] -and $worklog.author -and $worklog.author.PSObject.Properties['displayName']) { $worklog.author.displayName } else { "Unknown" }
                        TimeSpent = $worklog.timeSpent
                        Started = $worklog.started
                        Comment = if ($worklog.PSObject.Properties['comment'] -and $worklog.comment) { "Present" } else { "None" }  # Comment is ADF object, just track if present
                        Error = $_.Exception.Message
                    }
                }
            }
            
        } catch {
            Write-Warning "  ❌ Failed to retrieve worklogs for $sourceKey : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== MIGRATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Worklogs migrated: $($migratedWorklogs.Count)" -ForegroundColor Green
Write-Host "⏭️  Worklogs skipped: $skippedWorklogs (already existed - idempotency)" -ForegroundColor Yellow
Write-Host "❌ Worklogs failed: $($failedWorklogs.Count)" -ForegroundColor Red
Write-Host "📊 Total worklogs processed: $totalWorklogsProcessed" -ForegroundColor Blue
Write-Host "⏱️  Total time migrated: $([math]::Round($totalTimeSpent / 3600, 2)) hours" -ForegroundColor Magenta

# Analyze worklog statistics
$worklogsByAuthor = @{}
$worklogsByIssue = @{}
$totalTimeByAuthor = @{}

if ($migratedWorklogs.Count -gt 0) {
    
    foreach ($worklog in $migratedWorklogs) {
        # Count by author
        if ($worklogsByAuthor.ContainsKey($worklog.Author)) {
            $worklogsByAuthor[$worklog.Author]++
        } else {
            $worklogsByAuthor[$worklog.Author] = 1
        }
        
        # Count by issue
        if ($worklogsByIssue.ContainsKey($worklog.TargetKey)) {
            $worklogsByIssue[$worklog.TargetKey]++
        } else {
            $worklogsByIssue[$worklog.TargetKey] = 1
        }
        
        # Time by author
        if ($totalTimeByAuthor.ContainsKey($worklog.Author)) {
            $totalTimeByAuthor[$worklog.Author] += $worklog.TimeSpentSeconds
        } else {
            $totalTimeByAuthor[$worklog.Author] = $worklog.TimeSpentSeconds
        }
    }
    
    Write-Host ""
    Write-Host "Top worklog contributors:"
    $topAuthors = $worklogsByAuthor.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    foreach ($author in $topAuthors) {
        $hours = [math]::Round($totalTimeByAuthor[$author.Key] / 3600, 2)
        Write-Host "  - $($author.Key): $($author.Value) worklogs ($hours hours)"
    }
    
    Write-Host ""
    Write-Host "Issues with most worklogs:"
    $topIssues = $worklogsByIssue.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    foreach ($issue in $topIssues) {
        Write-Host "  - $($issue.Key): $($issue.Value) worklogs"
    }
    
    Write-Host ""
    Write-Host "Time distribution by author:"
    $topTimeAuthors = $totalTimeByAuthor.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    foreach ($author in $topTimeAuthors) {
        $hours = [math]::Round($author.Value / 3600, 2)
        Write-Host "  - $($author.Key): $hours hours"
    }
}

if ($failedWorklogs.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed worklogs:"
    foreach ($failed in $failedWorklogs) {
        Write-Host "  - $($failed.SourceKey) → $($failed.TargetKey): $($failed.TimeSpent) by $($failed.Author) - $($failed.Error)"
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 12
$step12SummaryReport = @()

# Add step timing information
$step12SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step12SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Add summary statistics
$step12SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Worklogs Processed"
    Value = $totalWorklogsProcessed
    Details = "Total worklogs processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step12SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Worklogs Migrated"
    Value = $migratedWorklogs.Count
    Details = "Worklogs successfully migrated to target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step12SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Worklogs Skipped"
    Value = $skippedWorklogs
    Details = "Worklogs skipped (already exist or no target issue)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step12SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Worklogs Failed"
    Value = $failedWorklogs.Count
    Details = "Worklogs that failed to migrate"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step12SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Time Migrated (Hours)"
    Value = [math]::Round($totalTimeSpent / 3600, 2)
    Details = "Total time migrated in hours"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step12SummaryCsvPath = Join-Path $outDir "12_Worklogs_SummaryReport.csv"
$step12SummaryReport | Export-Csv -Path $step12SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 12 summary report saved: $step12SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step12SummaryReport.Count)" -ForegroundColor Cyan

# Generate CSV report for failed worklogs (if any)
if ($failedWorklogs.Count -gt 0) {
    $failedCsvFileName = "12_FailedWorklogs.csv"
    $failedCsvFilePath = Join-Path $outDir $failedCsvFileName
    
    try {
        $failedCsvData = @()
        foreach ($worklog in $failedWorklogs) {
            $failedCsvData += [PSCustomObject]@{
                "Source Issue Key" = $worklog.SourceKey
                "Target Issue Key" = $worklog.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($worklog.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($worklog.TargetKey)"
                "Worklog Author" = $worklog.Author
                "Time Spent" = $worklog.TimeSpent
                "Started" = $worklog.Started
                "Comment" = if ($worklog.Comment -and $worklog.Comment.Length -gt 200) { $worklog.Comment.Substring(0, 200) + "..." } else { $worklog.Comment }
                "Error Message" = $worklog.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "❌ Failed worklogs report saved: $failedCsvFileName" -ForegroundColor Red
        Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Failed worklogs: $($failedWorklogs.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save failed worklogs report: $($_.Exception.Message)"
    }
}

# Create detailed receipt
Write-StageReceipt -OutDir $outDir -Stage "12_Worklogs" -Data @{
    TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    TotalWorklogsProcessed = $totalWorklogsProcessed
    MigratedWorklogs = $migratedWorklogs.Count
    SkippedWorklogs = $skippedWorklogs
    FailedWorklogs = $failedWorklogs.Count
    TotalTimeMigratedSeconds = $totalTimeSpent
    TotalTimeMigratedHours = [math]::Round($totalTimeSpent / 3600, 2)
    MigratedWorklogDetails = $migratedWorklogs
    FailedWorklogDetails = $failedWorklogs
    WorklogsByAuthor = $worklogsByAuthor
    WorklogsByIssue = $worklogsByIssue
    TimeByAuthor = $totalTimeByAuthor
    IdempotencyEnabled = $true
}

# Save issues log
Save-IssuesLog -StepName "12_Worklogs"

exit 0
