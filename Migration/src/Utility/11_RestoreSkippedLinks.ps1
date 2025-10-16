# 11_RestoreSkippedLinks.ps1 - Find and restore cross-project links after migration
#
# PURPOSE: Search for issues with documented skipped links and help restore them
# after the target projects have been migrated
#
# USAGE:
#   # List all issues with skipped links
#   .\11_RestoreSkippedLinks.ps1 -ListOnly
#
#   # Restore links for specific issues
#   .\11_RestoreSkippedLinks.ps1 -IssueKeys "LAS1-123","LAS1-456"
#
#   # Restore all documented links (if target issues now exist)
#   .\11_RestoreSkippedLinks.ps1 -RestoreAll
#
param(
    [Parameter()][string[]] $IssueKeys,
    [Parameter()][switch] $ListOnly,
    [Parameter()][switch] $RestoreAll,
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
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host "=== RESTORE CROSS-PROJECT LINKS ===" -ForegroundColor Cyan
Write-Host "Target Project: $tgtKey"
Write-Host "Target Base URL: $tgtBase"
Write-Host ""

# Search for issues with the documentation keyword
Write-Host "🔍 Searching for issues with documented skipped links..."
$jql = "project = $tgtKey AND comment ~ migrationLinksSkipped"
$searchUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/search?jql=" + [Uri]::EscapeDataString($jql) + "&maxResults=1000&fields=key,summary"

try {
    $searchResult = Invoke-JiraWithRetry -Method GET -Uri $searchUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
    
    if (-not $searchResult.issues -or $searchResult.issues.Count -eq 0) {
        Write-Host "✅ No issues found with documented skipped links" -ForegroundColor Green
        Write-Host ""
        Write-Host "This means either:"
        Write-Host "  1. No cross-project links were skipped during migration"
        Write-Host "  2. The -DocumentSkippedLinks flag was not used during link migration"
        Write-Host "  3. All links have already been restored and comments removed"
        exit 0
    }
    
    Write-Host "✅ Found $($searchResult.issues.Count) issues with documented skipped links" -ForegroundColor Green
    Write-Host ""
    
    if ($ListOnly) {
        Write-Host "Issues with skipped links:" -ForegroundColor Yellow
        foreach ($issue in $searchResult.issues) {
            Write-Host "  - $($issue.key): $($issue.fields.summary)"
        }
        Write-Host ""
        Write-Host "💡 To restore links for specific issues:" -ForegroundColor Cyan
        Write-Host "   .\11_RestoreSkippedLinks.ps1 -IssueKeys 'LAS1-123','LAS1-456'"
        Write-Host ""
        Write-Host "💡 To restore all links (if target projects are now available):" -ForegroundColor Cyan
        Write-Host "   .\11_RestoreSkippedLinks.ps1 -RestoreAll"
        exit 0
    }
    
    # Get issues to process
    $issuesToProcess = if ($IssueKeys) {
        $searchResult.issues | Where-Object { $IssueKeys -contains $_.key }
    } elseif ($RestoreAll) {
        $searchResult.issues
    } else {
        Write-Host "❌ No action specified. Use -ListOnly, -IssueKeys, or -RestoreAll" -ForegroundColor Red
        exit 1
    }
    
    if ($issuesToProcess.Count -eq 0) {
        Write-Host "❌ No matching issues found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "📋 Processing $($issuesToProcess.Count) issues..." -ForegroundColor Yellow
    Write-Host ""
    
    $linksRestored = 0
    $linksStillMissing = 0
    $commentsParsed = 0
    
    foreach ($issue in $issuesToProcess) {
        Write-Host "Processing $($issue.key)..." -ForegroundColor Cyan
        
        # Get issue details with comments
        $issueUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$($issue.key)?expand=comment"
        $issueDetails = Invoke-JiraWithRetry -Method GET -Uri $issueUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
        
        # Find the migration documentation comment
        $migrationComment = $null
        foreach ($comment in $issueDetails.fields.comment.comments) {
            $commentBody = $comment.body
            
            # Check if this is the migration documentation comment
            $commentJson = $commentBody | ConvertTo-Json -Depth 20 -Compress
            if ($commentJson -like "*migrationLinksSkipped*") {
                $migrationComment = $comment
                break
            }
        }
        
        if (-not $migrationComment) {
            Write-Host "  ⚠️  No migration documentation comment found" -ForegroundColor Yellow
            continue
        }
        
        $commentsParsed++
        
        # Parse the comment to extract issue keys
        # The comment contains links in the format [ISSUE-KEY|url]
        $commentText = $migrationComment.body | ConvertTo-Json -Depth 20
        $linkedIssuePattern = '\b([A-Z][A-Z0-9]+-\d+)\b'
        $matches = [regex]::Matches($commentText, $linkedIssuePattern)
        
        $linkedIssueKeys = $matches | ForEach-Object { $_.Value } | Select-Object -Unique | Where-Object { $_ -ne $issue.key }
        
        if ($linkedIssueKeys.Count -eq 0) {
            Write-Host "  ℹ️  No issue keys found in documentation comment" -ForegroundColor Gray
            continue
        }
        
        Write-Host "  Found $($linkedIssueKeys.Count) documented link(s)" -ForegroundColor Gray
        
        # Check if linked issues now exist and create links
        foreach ($linkedKey in $linkedIssueKeys) {
            try {
                # Check if target issue exists
                $linkedIssueUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$linkedKey"
                $linkedIssue = Invoke-JiraWithRetry -Method GET -Uri $linkedIssueUri -Headers $tgtHdr -MaxRetries 2 -TimeoutSec 15
                
                # Issue exists! Create the link
                # Note: We'll use "Relates" as default since we may not know the original link type
                $linkPayload = @{
                    type = @{ name = "Relates" }
                    inwardIssue = @{ key = $issue.key }
                    outwardIssue = @{ key = $linkedKey }
                }
                
                $createLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issueLink"
                $linkJson = $linkPayload | ConvertTo-Json -Depth 5
                Invoke-JiraWithRetry -Method POST -Uri $createLinkUri -Headers $tgtHdr -Body $linkJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 | Out-Null
                
                Write-Host "    ✅ Linked to $linkedKey" -ForegroundColor Green
                $linksRestored++
                
            } catch {
                if ($_.Exception.Message -like "*404*") {
                    Write-Host "    ⏭️  $linkedKey not yet migrated" -ForegroundColor Gray
                    $linksStillMissing++
                } elseif ($_.Exception.Message -like "*duplicate*" -or $_.Exception.Message -like "*already exists*") {
                    Write-Host "    ℹ️  Link to $linkedKey already exists" -ForegroundColor Gray
                } else {
                    Write-Host "    ⚠️  Failed to link to $linkedKey : $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }
        }
        
        # If all links were restored, offer to delete the documentation comment
        if ($linksStillMissing -eq 0 -and $linksRestored -gt 0) {
            Write-Host "  💡 All links restored. Comment can be deleted manually if desired." -ForegroundColor Cyan
        }
        
        Write-Host ""
    }
    
    Write-Host "=== RESTORATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "✅ Links restored: $linksRestored"
    Write-Host "⏭️  Links still missing: $linksStillMissing"
    Write-Host "📋 Comments processed: $commentsParsed"
    Write-Host ""
    
    if ($linksStillMissing -gt 0) {
        Write-Host "💡 Some linked issues are not yet available." -ForegroundColor Yellow
        Write-Host "   Run this script again after migrating the other projects." -ForegroundColor Yellow
    }
    
    if ($linksRestored -gt 0) {
        Write-Host "✅ Successfully restored $linksRestored link(s)!" -ForegroundColor Green
        Write-Host ""
        Write-Host "💡 Note: Restored links use 'Relates' relationship type." -ForegroundColor Cyan
        Write-Host "   You may need to manually adjust link types if specific relationships are needed." -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

