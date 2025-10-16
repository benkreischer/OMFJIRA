# =============================================================================
# ENDPOINT: Issue Worklogs - GET Worklog
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklogs/#api-rest-api-3-issue-issueidorkey-worklog-worklogid-get
#
# DESCRIPTION: Returns a worklog.
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey  # <-- IMPORTANT: Replace with the ID or key of the issue
$WorklogId = "12345"  # <-- IMPORTANT: Replace with the ID of the worklog
$Expand = "properties"  # <-- OPTIONAL: Use expand to include additional information

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey # <-- IMPORTANT: Replace with valid IssueIdOrKey
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/ORL-8004/worklog"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a single record with the worklog data
    $WorklogData = [PSCustomObject]@{
        Id = $Response.id
        Self = $Response.self
        IssueId = $Response.issueId
        Author = if ($Response.author) { $Response.author.displayName } else { "" }
        AuthorKey = if ($Response.author) { $Response.author.key } else { "" }
        AuthorEmail = if ($Response.author) { $Response.author.emailAddress } else { "" }
        UpdateAuthor = if ($Response.updateAuthor) { $Response.updateAuthor.displayName } else { "" }
        UpdateAuthorKey = if ($Response.updateAuthor) { $Response.updateAuthor.key } else { "" }
        UpdateAuthorEmail = if ($Response.updateAuthor) { $Response.updateAuthor.emailAddress } else { "" }
        Comment = if ($Response.comment) { $Response.comment } else { "" }
        Created = $Response.created
        Updated = $Response.updated
        Started = $Response.started
        TimeSpent = $Response.timeSpent
        TimeSpentSeconds = $Response.timeSpentSeconds
        Properties = if ($Response.properties) { ($Response.properties | ConvertTo-Json -Compress) } else { "" }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $WorklogData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Worklogs - GET Worklog - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve worklog data: $($_.Exception.Message)"
    exit 1
}

