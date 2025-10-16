# 09_Comments.ps1 - Migrate Issue Comments
# 
# PURPOSE: Migrates all comments from source issues to their corresponding target issues,
# preserving comment history, authors, and timestamps.
#
# WHAT IT DOES:
# - Retrieves all comments from source issues
# - Maps comments to their corresponding target issues using key mappings
# - Preserves comment authors, timestamps, and content
# - Handles comment threading and visibility settings
# - Creates detailed migration logs and receipts
#
# WHAT IT DOES NOT DO:
# - Does not migrate attachments (handled separately)
# - Does not modify comment content or formatting
# - Does not migrate comments for issues that failed to create
#
# NEXT STEP: Run 10_Attachments.ps1 to migrate file attachments
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
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir = $p.OutputSettings.OutputDirectory
$batchSize = $p.AnalysisSettings.BatchSize

# Initialize issues logging
Initialize-IssuesLog -StepName "09_Comments" -OutDir $outDir

Write-Host "=== MIGRATING COMMENTS TO TARGET ISSUES ==="
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
    Write-Host "✅ Step 9 completed successfully with no issues to process" -ForegroundColor Green
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "09_Comments" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        CommentsMigrated = 0
        CommentsSkipped = 0
        CommentsFailed = 0
        TotalCommentsProcessed = 0
        Status = "Completed - No Issues to Process"
        Notes = @("No issues were migrated in Step 8", "Comments migration completed successfully")
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

# Comment migration tracking
$migratedComments = @()
$failedComments = @()
$skippedComments = 0
$totalCommentsProcessed = 0

Write-Host ""
Write-Host "=== MIGRATING COMMENTS ==="

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
        Write-Host "  Migrating comments for $sourceKey → $targetKey"
        
        try {
            # Get comments from source issue (with unified retry logic)
            $commentsUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey/comment"
            $sourceComments = Invoke-JiraWithRetry -Method GET -Uri $commentsUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
            
            if (-not $sourceComments.comments -or $sourceComments.comments.Count -eq 0) {
                Write-Host "    ℹ️  No comments found"
                continue
            }
            
            Write-Host "    Found $($sourceComments.comments.Count) comments"
            
            # ========== IDEMPOTENCY: Get existing comments from target ==========
            $existingCommentsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
            $existingComments = @()
            try {
                $existingCommentsResponse = Invoke-JiraWithRetry -Method GET -Uri $existingCommentsUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
                if ($existingCommentsResponse.comments) {
                    $existingComments = $existingCommentsResponse.comments
                }
            } catch {
                Write-Host "      ⚠️  Could not fetch existing comments: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Process each comment
            $commentIndex = 0
            foreach ($comment in $sourceComments.comments) {
                $totalCommentsProcessed++
                $commentIndex++
                Write-Host "    Processing comment $commentIndex of $($sourceComments.comments.Count)..." -ForegroundColor DarkGray
                
                try {
                    # Preserve original author and timestamp in comment body
                    # Note: Jira API doesn't support setting comment author, so we prepend this info
                    $originalAuthor = if ($comment.author) { $comment.author.displayName } else { "Unknown" }
                    $originalDate = if ($comment.created) { 
                        ([DateTime]$comment.created).ToString("MMMM d, yyyy \a\t h:mm tt") 
                    } else { 
                        "Unknown date" 
                    }
                    
                    # ========== IDEMPOTENCY CHECK ==========
                    # Check if this comment already exists by matching the attribution text
                    $attributionText = "Originally commented by $originalAuthor on $originalDate"
                    $commentExists = $false
                    
                    foreach ($existingComment in $existingComments) {
                        $existingBody = $existingComment.body
                        
                        # Check in both ADF and plain text formats
                        if ($existingBody -is [PSCustomObject] -and $existingBody.type -eq "doc") {
                            # ADF format - check content
                            $existingBodyJson = $existingBody | ConvertTo-Json -Depth 20 -Compress
                            if ($existingBodyJson -like "*$attributionText*") {
                                $commentExists = $true
                                break
                            }
                        } elseif ($existingBody -is [string] -and $existingBody -like "*$attributionText*") {
                            # Plain text format
                            $commentExists = $true
                            break
                        }
                    }
                    
                    if ($commentExists) {
                        Write-Host "      ⏭️  Comment already exists (skipped)" -ForegroundColor Yellow
                        $skippedComments++
                        continue
                    }
                    
                    # Handle ADF (Atlassian Document Format) - prepend attribution paragraph
                    $commentBody = $comment.body
                    if ($commentBody -is [PSCustomObject] -and $commentBody.type -eq "doc") {
                        # ADF format - prepend a paragraph with attribution
                        $attributionParagraph = @{
                            type = "paragraph"
                            content = @(
                                @{
                                    type = "text"
                                    text = "Originally commented by $originalAuthor on $originalDate"
                                    marks = @(
                                        @{ type = "em" }
                                    )
                                }
                            )
                        }
                        
                        # Insert attribution at the beginning of content array
                        $newContent = @($attributionParagraph) + $commentBody.content
                        $commentBody = @{
                            type = "doc"
                            version = 1
                            content = $newContent
                        }
                    } else {
                        # Plain text format (fallback)
                        $commentBody = "*Originally commented by $originalAuthor on $originalDate*`n`n$commentBody"
                    }
                    
                    # Build comment payload
                    $commentPayload = @{
                        body = $commentBody
                    }
                    
                    # Add visibility if specified
                    if ($comment.PSObject.Properties['visibility'] -and $comment.visibility.type -ne 'role') {
                        $commentPayload.visibility = $comment.visibility
                    }
                    
                    # Create comment in target issue (with unified retry logic)
                    $createCommentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                    $commentJson = $commentPayload | ConvertTo-Json -Depth 20
                    $response = Invoke-JiraWithRetry -Method POST -Uri $createCommentUri -Headers $tgtHdr -Body $commentJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                    
                    Write-Host "      ✅ Comment created (id=$($response.id))"
                    $migratedComments += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceCommentId = $comment.id
                        TargetCommentId = $response.id
                        Author = $comment.author.displayName
                        Created = $comment.created
                        BodyLength = $comment.body.Length
                    }
                    
                } catch {
                    # Check if it's an ADF formatting error
                    $isAdfError = $false
                    if ($_.Exception.Message -like "*400*") {
                        try {
                            $errorResponse = $_.ErrorDetails.Message
                            if ($errorResponse -like "*Atlassian Document*" -or $errorResponse -like "*INVALID_INPUT*" -or $errorResponse -like "*malformed*") {
                                $isAdfError = $true
                            }
                        } catch { }
                    }
                    
                    if ($isAdfError) {
                        # Try to convert ADF to plain text and retry
                        Write-Host "      ⚠️  ADF format error - converting to plain text..." -ForegroundColor Yellow
                        try {
                            # Extract plain text from ADF structure
                            function Extract-CommentText($node) {
                                $text = ""
                                if ($node -is [PSCustomObject]) {
                                    if ($node.PSObject.Properties.Name -contains 'text') {
                                        $text += $node.text
                                    }
                                    if ($node.PSObject.Properties.Name -contains 'content') {
                                        foreach ($child in $node.content) {
                                            $text += Extract-CommentText $child
                                            $text += " "
                                        }
                                    }
                                } elseif ($node -is [Array]) {
                                    foreach ($item in $node) {
                                        $text += Extract-CommentText $item
                                    }
                                }
                                return $text
                            }
                            
                            $plainText = (Extract-CommentText $comment.body).Trim()
                            
                            # Create simple ADF with just plain text
                            $simpleBody = @{
                                type = "doc"
                                version = 1
                                content = @(
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = "*Originally commented by $originalAuthor on $originalDate*"
                                                marks = @(@{ type = "em" })
                                            }
                                        )
                                    },
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = $plainText
                                            }
                                        )
                                    }
                                )
                            }
                            
                            $commentPayload.body = $simpleBody
                            $commentJson = $commentPayload | ConvertTo-Json -Depth 20
                            $response = Invoke-JiraWithRetry -Method POST -Uri $createCommentUri -Headers $tgtHdr -Body $commentJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                            
                            Write-Host "      ✅ Comment created with plain text (id=$($response.id))" -ForegroundColor Green
                            $migratedComments += @{
                                SourceKey = $sourceKey
                                TargetKey = $targetKey
                                SourceCommentId = $comment.id
                                TargetCommentId = $response.id
                                Author = $comment.author.displayName
                                Created = $comment.created
                                BodyLength = $plainText.Length
                                Converted = $true
                            }
                        } catch {
                            Write-Warning "      ❌ Still failed after converting to plain text: $($_.Exception.Message)"
                            $failedComments += @{
                                SourceKey = $sourceKey
                                TargetKey = $targetKey
                                SourceCommentId = $comment.id
                                Author = $comment.author.displayName
                                Created = $comment.created
                                Error = "ADF conversion failed: $($_.Exception.Message)"
                            }
                            
                            # Log this error
                            Write-IssueLog -Type Warning -Category "Comment ADF Conversion Failed" -IssueKey $targetKey `
                                -Message "Comment could not be migrated even after ADF conversion" `
                                -Details @{
                                    SourceIssue = $sourceKey
                                    Author = $comment.author.displayName
                                    CommentDate = $comment.created
                                }
                        }
                    } else {
                        # Non-ADF error - log and continue
                        Write-Warning "      ❌ Failed to create comment: $($_.Exception.Message)"
                        $failedComments += @{
                            SourceKey = $sourceKey
                            TargetKey = $targetKey
                            SourceCommentId = $comment.id
                            Author = $comment.author.displayName
                            Created = $comment.created
                            Error = $_.Exception.Message
                        }
                        
                        # Log this error
                        Write-IssueLog -Type Warning -Category "Comment Migration Failed" -IssueKey $targetKey `
                            -Message "Failed to create comment: $($_.Exception.Message)" `
                            -Details @{
                                SourceIssue = $sourceKey
                                Author = $comment.author.displayName
                                CommentDate = $comment.created
                            }
                    }
                }
            }
            
        } catch {
            Write-Warning "  ❌ Failed to retrieve comments for $sourceKey : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== MIGRATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Comments migrated: $($migratedComments.Count)" -ForegroundColor Green
Write-Host "⏭️  Comments skipped: $skippedComments (already existed - idempotency)" -ForegroundColor Yellow
Write-Host "❌ Comments failed: $($failedComments.Count)" -ForegroundColor Red
Write-Host "📊 Total comments processed: $totalCommentsProcessed" -ForegroundColor Blue

# Initialize comment statistics variables
$commentsByAuthor = @{}
$commentsByIssue = @{}

# Analyze comment statistics
if ($migratedComments.Count -gt 0) {
    
    foreach ($comment in $migratedComments) {
        # Count by author
        if ($commentsByAuthor.ContainsKey($comment.Author)) {
            $commentsByAuthor[$comment.Author]++
        } else {
            $commentsByAuthor[$comment.Author] = 1
        }
        
        # Count by issue
        if ($commentsByIssue.ContainsKey($comment.TargetKey)) {
            $commentsByIssue[$comment.TargetKey]++
        } else {
            $commentsByIssue[$comment.TargetKey] = 1
        }
    }
    
    Write-Host ""
    Write-Host "Top commenters:"
    $topAuthors = $commentsByAuthor.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    foreach ($author in $topAuthors) {
        Write-Host "  - $($author.Key): $($author.Value) comments"
    }
    
    Write-Host ""
    Write-Host "Issues with most comments:"
    $topIssues = $commentsByIssue.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
    foreach ($issue in $topIssues) {
        Write-Host "  - $($issue.Key): $($issue.Value) comments"
    }
}

if ($failedComments.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed comments:"
    foreach ($failed in $failedComments) {
        Write-Host "  - $($failed.SourceKey) → $($failed.TargetKey): $($failed.Error)"
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 9
$step9SummaryReport = @()

# Add step timing information
$step9SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step9SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Add summary statistics
$step9SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Comments Processed"
    Value = $totalCommentsProcessed
    Details = "Total comments processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step9SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Comments Migrated"
    Value = $migratedComments.Count
    Details = "Comments successfully migrated to target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step9SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Comments Skipped"
    Value = $skippedComments
    Details = "Comments skipped (already exist or no target issue)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step9SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Comments Failed"
    Value = $failedComments.Count
    Details = "Comments that failed to migrate"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step9SummaryCsvPath = Join-Path $outDir "09_Comments_SummaryReport.csv"
$step9SummaryReport | Export-Csv -Path $step9SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 9 summary report saved: $step9SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step9SummaryReport.Count)" -ForegroundColor Cyan

# Generate CSV report for failed comments (if any)
if ($failedComments.Count -gt 0) {
    $failedCsvFileName = "09_FailedComments.csv"
    $failedCsvFilePath = Join-Path $outDir $failedCsvFileName
    
    try {
        $failedCsvData = @()
        foreach ($comment in $failedComments) {
            $failedCsvData += [PSCustomObject]@{
                "Source Issue Key" = $comment.SourceKey
                "Target Issue Key" = $comment.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($comment.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($comment.TargetKey)"
                "Comment Author" = $comment.Author
                "Comment Created" = $comment.Created
                "Comment Body" = if ($comment.Body -and $comment.Body.Length -gt 200) { $comment.Body.Substring(0, 200) + "..." } else { $comment.Body }
                "Error Message" = $comment.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "❌ Failed comments report saved: $failedCsvFileName" -ForegroundColor Red
        Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Failed comments: $($failedComments.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save failed comments report: $($_.Exception.Message)"
    }
}

# Create detailed receipt
Write-StageReceipt -OutDir $outDir -Stage "09_Comments" -Data @{
    TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    TotalCommentsProcessed = $totalCommentsProcessed
    MigratedComments = $migratedComments.Count
    SkippedComments = $skippedComments
    FailedComments = $failedComments.Count
    MigratedCommentDetails = $migratedComments
    FailedCommentDetails = $failedComments
    CommentsByAuthor = $commentsByAuthor
    CommentsByIssue = $commentsByIssue
    IdempotencyEnabled = $true
}

# Save issues log
Save-IssuesLog -StepName "09_Comments"

exit 0
