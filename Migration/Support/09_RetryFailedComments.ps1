# 09_RetryFailedComments.ps1 - Retry failed comment migrations
#
# PURPOSE: Retry comment migration for specific issues that failed due to SSL or other transient errors
#
# USAGE: 
#   .\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154","LAS-4155"
#   or
#   .\09_RetryFailedComments.ps1 -AllFailed
#
param(
    [Parameter()][string[]] $IssueKeys,
    [Parameter()][switch] $AllFailed,
    [Parameter()][string] $ParametersPath
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $here))) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

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

Write-Host "=== RETRY FAILED COMMENT MIGRATIONS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host ""

# Load key mappings
$exportDir = Join-Path $outDir "exports"
$keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"

if (-not (Test-Path $keyMappingFile)) {
    throw "Key mapping file not found: $keyMappingFile. Please run step 08_Import.ps1 first."
}

try {
    $sourceToTargetKeyMapObj = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
    
    # Convert PSCustomObject to hashtable for proper key lookups
    $sourceToTargetKeyMap = @{}
    foreach ($prop in $sourceToTargetKeyMapObj.PSObject.Properties) {
        $sourceToTargetKeyMap[$prop.Name] = $prop.Value
    }
    
    Write-Host "✅ Loaded $($sourceToTargetKeyMap.Count) key mappings"
} catch {
    throw "Failed to load key mappings: $($_.Exception.Message)"
}

# Load failed comments from previous run (if using -AllFailed)
if ($AllFailed) {
    $receiptPattern = Join-Path $outDir "*09_Comments_receipt.json"
    $receiptFiles = Get-ChildItem -Path $receiptPattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    
    if ($receiptFiles.Count -eq 0) {
        Write-Host "❌ No comment migration receipt found. Cannot determine failed issues."
        exit 1
    }
    
    $receipt = Get-Content $receiptFiles[0].FullName -Raw | ConvertFrom-Json
    
    if ($receipt.FailedCommentDetails -and $receipt.FailedCommentDetails.Count -gt 0) {
        $IssueKeys = $receipt.FailedCommentDetails | ForEach-Object { $_.SourceKey } | Select-Object -Unique
        Write-Host "Found $($IssueKeys.Count) issues with failed comments:"
        $IssueKeys | ForEach-Object { Write-Host "  - $_" }
    } else {
        Write-Host "✅ No failed comments found in last run."
        exit 0
    }
}

if (-not $IssueKeys -or $IssueKeys.Count -eq 0) {
    Write-Host "❌ No issue keys provided. Use -IssueKeys or -AllFailed parameter."
    exit 1
}

Write-Host ""
Write-Host "=== RETRYING COMMENT MIGRATIONS ==="

# Track results
$retrySuccess = @()
$retryFailed = @()

foreach ($sourceKey in $IssueKeys) {
    # Check if this issue exists in key mapping
    if (-not $sourceToTargetKeyMap.ContainsKey($sourceKey)) {
        Write-Host "  ⏭️  Skipping $sourceKey (not created in target)"
        continue
    }
    
    $targetKey = $sourceToTargetKeyMap[$sourceKey]
    Write-Host "  Retrying comments for $sourceKey → $targetKey"
    
    try {
        # Get comments from source issue (with enhanced retry logic)
        $commentsUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey/comment"
        Write-Host "    📡 Fetching comments from source (with SSL retry)..." -ForegroundColor Cyan
        
        $sourceComments = Invoke-JiraWithRetry -Method GET -Uri $commentsUri -Headers $srcHdr -MaxRetries 5 -TimeoutSec 45
        
        if (-not $sourceComments.comments -or $sourceComments.comments.Count -eq 0) {
            Write-Host "    ℹ️  No comments found"
            continue
        }
        
        Write-Host "    ✅ Successfully retrieved $($sourceComments.comments.Count) comments" -ForegroundColor Green
        
        # Get existing comments from target
        $existingCommentsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
        $existingComments = @()
        try {
            $existingCommentsResponse = Invoke-JiraWithRetry -Method GET -Uri $existingCommentsUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
            if ($existingCommentsResponse.comments) {
                $existingComments = $existingCommentsResponse.comments
            }
        } catch {
            Write-Host "      ⚠️  Could not fetch existing comments: $($_.Exception.Message)"
        }
        
        # Process each comment
        $commentsMigrated = 0
        $commentsSkipped = 0
        
        foreach ($comment in $sourceComments.comments) {
            try {
                    # Preserve original author and timestamp in comment body
                    $originalAuthor = if ($comment.author) { $comment.author.displayName } else { "Unknown" }
                    $originalDate = if ($comment.created) { 
                        ([DateTime]$comment.created).ToString("MMMM d, yyyy \a\t h:mm tt") 
                    } else { 
                        "Unknown date" 
                    }
                
                # Check if comment already exists
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
                    $commentsSkipped++
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
                
                # Create comment in target issue
                $createCommentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                $commentJson = $commentPayload | ConvertTo-Json -Depth 20
                $response = Invoke-JiraWithRetry -Method POST -Uri $createCommentUri -Headers $tgtHdr -Body $commentJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                
                $commentsMigrated++
                
            } catch {
                Write-Warning "      ❌ Failed to create comment: $($_.Exception.Message)"
            }
        }
        
        Write-Host "    ✅ Migrated: $commentsMigrated, Skipped: $commentsSkipped" -ForegroundColor Green
        $retrySuccess += @{
            SourceKey = $sourceKey
            TargetKey = $targetKey
            CommentsMigrated = $commentsMigrated
            CommentsSkipped = $commentsSkipped
        }
        
    } catch {
        Write-Warning "  ❌ Failed to retrieve/migrate comments for $sourceKey : $($_.Exception.Message)"
        $retryFailed += @{
            SourceKey = $sourceKey
            TargetKey = $targetKey
            Error = $_.Exception.Message
        }
    }
}

Write-Host ""
Write-Host "=== RETRY SUMMARY ==="
Write-Host "✅ Successfully retried: $($retrySuccess.Count) issues"
Write-Host "❌ Failed again: $($retryFailed.Count) issues"

if ($retryFailed.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed issues:"
    foreach ($failed in $retryFailed) {
        Write-Host "  - $($failed.SourceKey): $($failed.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "💡 TROUBLESHOOTING TIPS:" -ForegroundColor Yellow
    Write-Host "   1. Check network connectivity to source Jira instance"
    Write-Host "   2. Verify API token is still valid"
    Write-Host "   3. Check if issue exists and is accessible: $srcBase/browse/$($retryFailed[0].SourceKey)"
    Write-Host "   4. Try again in a few minutes (might be temporary network issue)"
    Write-Host "   5. Run with increased verbosity: `$VerbosePreference = 'Continue'"
}

# Save receipt
if ($retrySuccess.Count -gt 0 -or $retryFailed.Count -gt 0) {
    Write-StageReceipt -OutDir $outDir -Stage "09_Comments_Retry" -Data @{
        RetryTimestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        IssuesRetried = $IssueKeys
        SuccessfulRetries = $retrySuccess
        FailedRetries = $retryFailed
    }
}

