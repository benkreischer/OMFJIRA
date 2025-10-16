# =============================================================================
# GET ALL ISSUES WITH LINKS - ENHANCED JQL API
# =============================================================================
# Based on: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/#api-group-issue-search
# Uses the Enhanced JQL API to get all issues with their linked issues and status
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$JqlQuery = "ORDER BY created DESC"
$MaxResults = $Params.ApiSettings.MaxResults  # Maximum batch size for Enhanced JQL API
$BatchSize = $Params.ApiSettings.BatchSize    # Batch size for Bulk Fetch API

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Format-JiraDate {
    param([string]$DateString)
    
    if ([string]::IsNullOrEmpty($DateString)) {
        return ""
    }
    
    try {
        # Parse the Jira date string (ISO 8601 format)
        $Date = [DateTime]::Parse($DateString)
        # Format as Excel-friendly date (MM/dd/yyyy HH:mm:ss)
        return $Date.ToString("MM/dd/yyyy HH:mm:ss")
    } catch {
        # If parsing fails, return original string
        return $DateString
    }
}

# =============================================================================
# PHASE 1: GET ALL ISSUE IDs USING ENHANCED JQL API
# =============================================================================
Write-Output "PHASE 1: Getting all issue IDs using Enhanced JQL API..."

$EnhancedSearchUrl = "$BaseUrl/rest/api/3/search/jql"
$AllIssueIds = @()
$NextPageToken = $null
$TotalPages = 0

do {
    $TotalPages++
    Write-Output "  Fetching page $TotalPages..."
    
    # Build request payload for Enhanced JQL API
    $Payload = @{
        jql = $JqlQuery
        maxResults = $MaxResults
    }
    
    if ($NextPageToken) {
        $Payload.nextPageToken = $NextPageToken
    }
    
    $JsonPayload = $Payload | ConvertTo-Json -Depth 10
    
    try {
        $Response = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $AuthHeader -Body $JsonPayload
        
        Write-Output "    Retrieved $($Response.issues.Count) issues from page $TotalPages"
        
        # Extract issue IDs (Enhanced JQL API returns minimal data for performance)
        foreach ($issue in $Response.issues) {
            $AllIssueIds += $issue.id
        }
        
        Write-Output "    Total issue IDs collected: $($AllIssueIds.Count)"
        
        # Check for next page token
        if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
            $NextPageToken = $Response.nextPageToken
            Write-Output "    Next page token found, continuing..."
        } else {
            $NextPageToken = $null
            Write-Output "    No next page token, pagination complete"
        }
        
    } catch {
        Write-Error "Failed to fetch page $TotalPages`: $($_.Exception.Message)"
        break
    }
    
} while ($NextPageToken -ne $null)

Write-Output "PHASE 1 COMPLETE: Collected $($AllIssueIds.Count) issue IDs in $TotalPages pages"

# =============================================================================
# PHASE 2: GET ISSUE DETAILS USING BULK FETCH API
# =============================================================================
Write-Output "PHASE 2: Getting issue details using Bulk Fetch API..."

$BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"

# Split issue IDs into batches
$Batches = @()
for ($i = 0; $i -lt $AllIssueIds.Count; $i += $BatchSize) {
    $Batch = $AllIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $AllIssueIds.Count - 1))]
    $Batches += ,$Batch  # Comma to create array of arrays
}

Write-Output "  Created $($Batches.Count) batches of up to $BatchSize issues each"

# Process batches and save each individually
$BatchResults = @()
foreach ($BatchIndex in 0..($Batches.Count - 1)) {
    $Batch = $Batches[$BatchIndex]
    Write-Output "  Processing batch $($BatchIndex + 1)/$($Batches.Count) with $($Batch.Count) issues..."
    
    # Build request payload for Bulk Fetch API
    $BulkPayload = @{
        fields = @("summary", "status", "priority", "assignee", "reporter", "created", "updated", "resolutiondate", "project", "issuetype", "issuelinks")
        issueIdsOrKeys = $Batch
    }
    
    $BulkJsonPayload = $BulkPayload | ConvertTo-Json -Depth 10
    
    try {
        $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $AuthHeader -Body $BulkJsonPayload
        
        Write-Output "    Retrieved $($BulkResponse.issues.Count) issue details from batch $($BatchIndex + 1)"
        
        # Transform this batch's data immediately
        $BatchResult = @()
        if ($BulkResponse.issues -and $BulkResponse.issues.Count -gt 0) {
            foreach ($issue in $BulkResponse.issues) {
                # Extract linked issues
                $LinkedIssues = @()
                $LinkedIssueStatuses = @()
                
                if ($issue.fields.issuelinks) {
                    foreach ($link in $issue.fields.issuelinks) {
                        if ($link.outwardIssue) {
                            $LinkedIssues += $link.outwardIssue.key
                            $LinkedIssueStatuses += if ($link.outwardIssue.fields.status) { $link.outwardIssue.fields.status.name } else { "Unknown" }
                        }
                        if ($link.inwardIssue) {
                            $LinkedIssues += $link.inwardIssue.key
                            $LinkedIssueStatuses += if ($link.inwardIssue.fields.status) { $link.inwardIssue.fields.status.name } else { "Unknown" }
                        }
                    }
                }
                
                $IssueData = [PSCustomObject]@{
                    Id = $issue.id
                    Key = $issue.key
                    Self = $issue.self
                    Summary = if ($issue.fields.summary) { $issue.fields.summary } else { "" }
                    Status = if ($issue.fields.status) { $issue.fields.status.name } else { "" }
                    Priority = if ($issue.fields.priority) { $issue.fields.priority.name } else { "" }
                    Assignee = if ($issue.fields.assignee) { $issue.fields.assignee.displayName } else { "" }
                    Reporter = if ($issue.fields.reporter) { $issue.fields.reporter.displayName } else { "" }
                    Created = Format-JiraDate $issue.fields.created
                    Updated = Format-JiraDate $issue.fields.updated
                    Resolved = Format-JiraDate $issue.fields.resolutiondate
                    Project = if ($issue.fields.project) { $issue.fields.project.name } else { "" }
                    ProjectKey = if ($issue.fields.project) { $issue.fields.project.key } else { "" }
                    IssueType = if ($issue.fields.issuetype) { $issue.fields.issuetype.name } else { "" }
                    LinkedIssues = ($LinkedIssues -join ";")
                    LinkedIssueStatuses = ($LinkedIssueStatuses -join ";")
                    LinkedIssueCount = $LinkedIssues.Count
                }
                $BatchResult += $IssueData
            }
        }
        
        # Save this batch to its own CSV file
        $StartRecord = ($BatchIndex * $BatchSize) + 1
        $EndRecord = [Math]::Min(($BatchIndex + 1) * $BatchSize, $AllIssueIds.Count)
        $BatchFileName = "All Issues with Links - Batch $($StartRecord.ToString('000000'))-$($EndRecord.ToString('000000')).csv"
        
        $BatchResult | Export-Csv -Path $BatchFileName -NoTypeInformation
        Write-Output "    Saved batch $($BatchIndex + 1) to $BatchFileName with $($BatchResult.Count) records"
        
        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 200
        
    } catch {
        Write-Error "Failed to fetch batch $($BatchIndex + 1): $($_.Exception.Message)"
    }
}

Write-Output "PHASE 2 COMPLETE: All batches processed and saved individually"

# =============================================================================
# SUMMARY
# =============================================================================
Write-Output ""
Write-Output "SUMMARY:"
Write-Output "  - Issue IDs collected: $($AllIssueIds.Count)"
Write-Output "  - Batches processed: $($Batches.Count)"
Write-Output "  - Individual CSV files created: $($Batches.Count)"
Write-Output "  - Each batch contains up to $BatchSize records"
Write-Output "  - Files named: All Issues with Links - Batch XXXXXX-YYYYYY.csv"
Write-Output ""
Write-Output "SUCCESS: All batches saved individually for manual merging!"

