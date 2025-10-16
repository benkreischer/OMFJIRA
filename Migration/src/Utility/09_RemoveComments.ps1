# 09_RemoveComments.ps1 - Clean up migrated comments from target issues
# 
# LOCATION: Migration/src/Utility/
# PURPOSE: Removes all comments from target issues to allow re-running the comment migration
# with corrected author attribution.
#
# WHAT IT DOES:
# - Loads the key mapping to identify target issues
# - Retrieves all comments from each target issue
# - Deletes comments (optionally filtered to only delete recent ones)
# - Creates a detailed log of deleted comments
#
# WARNING: This script will permanently delete comments. Use with caution!
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Target environment setup only (we're only deleting from target)
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir = $p.OutputSettings.OutputDirectory

Write-Host "=== CLEANING UP COMMENTS FROM TARGET ISSUES ===" -ForegroundColor Yellow
Write-Host "Target Project: $tgtKey"
Write-Host ""
Write-Warning "⚠️  This script will DELETE comments from target issues!"
Write-Host "Press Ctrl+C now to cancel, or any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Load key mappings from previous steps
$exportDir = Join-Path $outDir "exports"
$keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"

Write-Host ""
Write-Host "=== LOADING KEY MAPPING ==="
if (-not (Test-Path $keyMappingFile)) {
    throw "Key mapping file not found: $keyMappingFile. Please run step 08_CreateIssues_Target.ps1 first."
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
    throw "Failed to load key mapping: $($_.Exception.Message)"
}

# Get list of target issue keys
$targetKeys = $sourceToTargetKeyMap.Values | Sort-Object

Write-Host ""
Write-Host "=== RETRIEVING AND DELETING COMMENTS ==="
Write-Host "Processing $($targetKeys.Count) target issues..."

$deletedComments = @()
$failedDeletions = @()
$totalCommentsFound = 0
$totalCommentsDeleted = 0

foreach ($targetKey in $targetKeys) {
    Write-Host "  Processing $targetKey..."
    
    try {
        # Get all comments from the target issue
        $commentsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
        $response = Invoke-RestMethod -Method GET -Uri $commentsUri -Headers $tgtHdr -ErrorAction Stop
        
        if (-not $response.comments -or $response.comments.Count -eq 0) {
            Write-Host "    ℹ️  No comments found"
            continue
        }
        
        $commentCount = $response.comments.Count
        $totalCommentsFound += $commentCount
        Write-Host "    Found $commentCount comments"
        
        # Delete each comment
        foreach ($comment in $response.comments) {
            try {
                $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment/$($comment.id)"
                Invoke-RestMethod -Method DELETE -Uri $deleteUri -Headers $tgtHdr -ErrorAction Stop
                
                Write-Host "      ✅ Deleted comment $($comment.id)" -ForegroundColor Green
                $totalCommentsDeleted++
                
                $deletedComments += @{
                    IssueKey = $targetKey
                    CommentId = $comment.id
                    Author = $comment.author.displayName
                    Created = $comment.created
                    BodyPreview = if ($comment.body.Length -gt 100) { 
                        $comment.body.Substring(0, 100) + "..." 
                    } else { 
                        $comment.body 
                    }
                }
                
            } catch {
                Write-Warning "      ❌ Failed to delete comment $($comment.id): $($_.Exception.Message)"
                $failedDeletions += @{
                    IssueKey = $targetKey
                    CommentId = $comment.id
                    Error = $_.Exception.Message
                }
            }
        }
        
    } catch {
        Write-Warning "  ❌ Failed to retrieve comments for $targetKey : $($_.Exception.Message)"
    }
}

Write-Host ""
Write-Host "=== CLEANUP SUMMARY ===" -ForegroundColor Yellow
Write-Host "📊 Total comments found: $totalCommentsFound"
Write-Host "✅ Comments deleted: $totalCommentsDeleted" -ForegroundColor Green
Write-Host "❌ Deletions failed: $($failedDeletions.Count)" -ForegroundColor Red

if ($failedDeletions.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed deletions:"
    foreach ($failed in $failedDeletions) {
        Write-Host "  - $($failed.IssueKey) comment $($failed.CommentId): $($failed.Error)"
    }
}

# Save cleanup receipt
Write-Host ""
Write-Host "Saving cleanup receipt..."
Write-StageReceipt -OutDir $outDir -Stage "Utility_09_RemoveComments" -Data @{
    TargetProject = @{ key=$tgtKey }
    TotalCommentsFound = $totalCommentsFound
    TotalCommentsDeleted = $totalCommentsDeleted
    FailedDeletions = $failedDeletions.Count
    DeletedCommentDetails = $deletedComments
    FailedDeletionDetails = $failedDeletions
    CleanupDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

Write-Host ""
Write-Host "✅ Cleanup complete! You can now re-run step 09 to migrate comments." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Re-run comment migration: .\src\steps\09_Comments.ps1"
Write-Host "  2. Verify comments migrated correctly"
Write-Host ""
Write-Host "To run this script:"
Write-Host "  .\src\Utility\09_RemoveComments.ps1"
