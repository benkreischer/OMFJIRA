# =============================================================================
# GET ALL ATTACHMENTS FOR A PROJECT
# =============================================================================
#
# DESCRIPTION: Gets all attachments for all issues in a specified project
#
# USAGE: 
#   .\Get-Project-Attachments.ps1 -ProjectKey "PAY"
#   .\Get-Project-Attachments.ps1 -ProjectKey "COR" -MaxResults 100
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectKey,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxResults = $Params.ApiSettings.MaxResults,  # Max issues to process (increase if needed)
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeResolved = $false  # Include resolved/closed issues
)

# =============================================================================
# LOAD REQUIRED ASSEMBLIES
# =============================================================================
Add-Type -AssemblyName System.Web


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# BUILD JQL QUERY
# =============================================================================
if ($IncludeResolved) {
    $JQL = "project = $ProjectKey ORDER BY created DESC"
} else {
    $JQL = "project = $ProjectKey AND status NOT IN (Done, Closed, Resolved, Cancelled) ORDER BY created DESC"
}

Write-Host "JQL Query: $JQL" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# FETCH ISSUES WITH ATTACHMENTS
# =============================================================================
$AllAttachments = @()
$StartAt = 0
$BatchSize = $Params.ApiSettings.BatchSize  # Jira API limit per request
$TotalIssuesProcessed = 0

do {
    $Endpoint = "/rest/api/3/search"
    $FullUrl = $BaseUrl + $Endpoint + "?jql=" + [System.Web.HttpUtility]::UrlEncode($JQL) + "&startAt=$StartAt&maxResults=$BatchSize&fields=key,summary,status,assignee,reporter,created,updated,attachment,issuetype,priority"
    
    try {
        Write-Host "Fetching issues $StartAt to $($StartAt + $BatchSize)..." -ForegroundColor Yellow
        $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
        
        $TotalIssues = $Response.total
        $IssuesInBatch = $Response.issues.Count
        
        Write-Host "  Found $IssuesInBatch issues (Total: $TotalIssues)" -ForegroundColor Green
        
        # Process each issue
        foreach ($issue in $Response.issues) {
            $IssueKey = $issue.key
            $IssueSummary = $issue.fields.summary
            $IssueStatus = $issue.fields.status.name
            $IssueAssignee = if ($issue.fields.assignee) { $issue.fields.assignee.displayName } else { "" }
            $IssueReporter = if ($issue.fields.reporter) { $issue.fields.reporter.displayName } else { "" }
            $IssueCreated = $issue.fields.created
            $IssueUpdated = $issue.fields.updated
            $IssueType = $issue.fields.issuetype.name
            $IssuePriority = if ($issue.fields.priority) { $issue.fields.priority.name } else { "" }
            
            # Check if issue has attachments
            if ($issue.fields.attachment -and $issue.fields.attachment.Count -gt 0) {
                foreach ($attachment in $issue.fields.attachment) {
                    $AttachmentData = [PSCustomObject]@{
                        ProjectKey = $ProjectKey
                        IssueKey = $IssueKey
                        IssueSummary = $IssueSummary
                        IssueStatus = $IssueStatus
                        IssueType = $IssueType
                        IssuePriority = $IssuePriority
                        IssueAssignee = $IssueAssignee
                        IssueReporter = $IssueReporter
                        IssueCreated = $IssueCreated
                        IssueUpdated = $IssueUpdated
                        AttachmentId = $attachment.id
                        AttachmentFilename = $attachment.filename
                        AttachmentSize = $attachment.size
                        AttachmentMimeType = $attachment.mimeType
                        AttachmentCreated = $attachment.created
                        AttachmentAuthor = if ($attachment.author) { $attachment.author.displayName } else { "" }
                        AttachmentUrl = $attachment.content
                        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $AllAttachments += $AttachmentData
                }
                Write-Host "    $IssueKey - $($issue.fields.attachment.Count) attachment(s)" -ForegroundColor Gray
            }
        }
        
        $TotalIssuesProcessed += $IssuesInBatch
        $StartAt += $BatchSize
        
        # Check if we've hit the max results limit
        if ($TotalIssuesProcessed -ge $MaxResults) {
            Write-Host "Reached MaxResults limit of $MaxResults" -ForegroundColor Yellow
            break
        }
        
        # Check if we've processed all issues
        if ($StartAt -ge $TotalIssues) {
            break
        }
        
    } catch {
        Write-Host "Error fetching issues: $($_.Exception.Message)" -ForegroundColor Red
        break
    }
    
} while ($true)

# =============================================================================
# EXPORT TO CSV
# =============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "EXPORT RESULTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$OutputFile = "Project_${ProjectKey}_Attachments.csv"

if ($AllAttachments.Count -gt 0) {
    $AllAttachments | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    Write-Host "✅ Exported $($AllAttachments.Count) attachments to: $OutputFile" -ForegroundColor Green
    
    # Summary statistics
    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Total Issues Processed: $TotalIssuesProcessed" -ForegroundColor White
    Write-Host "  Issues with Attachments: $($AllAttachments | Select-Object -Unique IssueKey | Measure-Object).Count" -ForegroundColor White
    Write-Host "  Total Attachments: $($AllAttachments.Count)" -ForegroundColor White
    
    $TotalSizeBytes = ($AllAttachments | Measure-Object -Property AttachmentSize -Sum).Sum
    $TotalSizeMB = [math]::Round($TotalSizeBytes / 1MB, 2)
    Write-Host "  Total Size: $TotalSizeMB MB" -ForegroundColor White
    
    # File type breakdown
    Write-Host ""
    Write-Host "FILE TYPE BREAKDOWN:" -ForegroundColor Cyan
    $FileTypes = $AllAttachments | Group-Object AttachmentMimeType | 
        Select-Object @{N='Type';E={$_.Name}}, @{N='Count';E={$_.Count}} |
        Sort-Object Count -Descending
    $FileTypes | Select-Object -First 10 | Format-Table -AutoSize
    
} else {
    Write-Host "⚠️  No attachments found for project $ProjectKey" -ForegroundColor Yellow
    
    # Create empty file
    $EmptyResult = @([PSCustomObject]@{
        ProjectKey = $ProjectKey
        Message = "No attachments found"
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    })
    $EmptyResult | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    Write-Host "Created empty results file: $OutputFile" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


