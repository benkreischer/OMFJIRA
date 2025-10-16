# =============================================================================
# GET ALL ATTACHMENTS FOR A PROJECT FROM EXISTING DATA
# =============================================================================
#
# DESCRIPTION: Gets all attachments for a project using existing issue data
# Uses /rest/api/3/issue/{issueIdOrKey} endpoint per Jira best practices
#
# USAGE: 
#   .\Get-Project-Attachments-From-Data.ps1 -ProjectKey "ENGOPS"
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectKey
)


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# LOAD EXISTING ISSUE DATA
# =============================================================================
$DataPath = "..\..\Affinity\Complete_Cross_Project_Links_Gold_Copy.csv"

if (-not (Test-Path $DataPath)) {
    Write-Host "Error: Could not find data file at $DataPath" -ForegroundColor Red
    exit 1
}

Write-Host "Loading existing issue data..." -ForegroundColor Yellow
$AllData = Import-Csv $DataPath

# Get unique issue keys for this project
$ProjectIssues = $AllData | Where-Object { 
    ($_.SourceProject -eq $ProjectKey) -or ($_.TargetProject -eq $ProjectKey) 
} | ForEach-Object {
    if ($_.SourceProject -eq $ProjectKey) { $_.SourceIssueKey } 
    if ($_.TargetProject -eq $ProjectKey) { $_.TargetIssueKey }
} | Select-Object -Unique | Where-Object { $_ -ne "" }

Write-Host "Found $($ProjectIssues.Count) unique issues for project $ProjectKey" -ForegroundColor Green
Write-Host ""

if ($ProjectIssues.Count -eq 0) {
    Write-Host "No issues found for project $ProjectKey" -ForegroundColor Yellow
    exit 0
}

# =============================================================================
# FETCH ATTACHMENTS FOR EACH ISSUE
# =============================================================================
$AllAttachments = @()
$IssueCount = 0
$AttachmentCount = 0

foreach ($IssueKey in $ProjectIssues) {
    $IssueCount++
    Write-Host "[$IssueCount/$($ProjectIssues.Count)] Fetching $IssueKey..." -ForegroundColor Gray
    
    $IssueUrl = "$BaseUrl/rest/api/3/issue/$IssueKey"
    
    try {
        $Issue = Invoke-RestMethod -Uri $IssueUrl -Headers $AuthHeader -Method Get
        
        $IssueKey = $Issue.key
        $IssueSummary = $Issue.fields.summary
        $IssueStatus = if ($Issue.fields.status) { $Issue.fields.status.name } else { "" }
        $IssueAssignee = if ($Issue.fields.assignee) { $Issue.fields.assignee.displayName } else { "" }
        $IssueReporter = if ($Issue.fields.reporter) { $Issue.fields.reporter.displayName } else { "" }
        $IssueCreated = $Issue.fields.created
        $IssueUpdated = $Issue.fields.updated
        $IssueType = if ($Issue.fields.issuetype) { $Issue.fields.issuetype.name } else { "" }
        $IssuePriority = if ($Issue.fields.priority) { $Issue.fields.priority.name } else { "" }
        
        # Check if issue has attachments
        if ($Issue.fields.attachment -and $Issue.fields.attachment.Count -gt 0) {
            foreach ($attachment in $Issue.fields.attachment) {
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
                    AttachmentContentUrl = $attachment.content
                    AttachmentThumbnailUrl = if ($attachment.thumbnail) { $attachment.thumbnail } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $AllAttachments += $AttachmentData
                $AttachmentCount++
            }
            Write-Host "    Found $($Issue.fields.attachment.Count) attachment(s)" -ForegroundColor Green
        }
        
        # Small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
        
    } catch {
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

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
    Write-Host "Exported $($AllAttachments.Count) attachments to: $OutputFile" -ForegroundColor Green
    
    # Summary statistics
    Write-Host ""
    Write-Host "SUMMARY:" -ForegroundColor Cyan
    Write-Host "  Total Issues Checked: $IssueCount" -ForegroundColor White
    Write-Host "  Issues with Attachments: $(($AllAttachments | Select-Object -Unique IssueKey).Count)" -ForegroundColor White
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
    Write-Host "No attachments found for project $ProjectKey" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan


