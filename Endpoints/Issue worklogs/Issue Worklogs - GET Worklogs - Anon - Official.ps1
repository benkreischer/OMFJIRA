# =============================================================================
# ENDPOINT: Issue Worklogs - GET Worklogs
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklogs/#api-rest-api-3-issue-issueidorkey-worklog-get
#
# DESCRIPTION: Returns worklogs for an issue, starting from the oldest worklog or from the worklog started on or after a date and time.
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
$StartAt = 0  # <-- OPTIONAL: The index of the first item to return (default: 0)
$MaxResults = $Params.ApiSettings.MaxResults  # <-- OPTIONAL: The maximum number of items to return (default: 100)
$StartedAfter = ""  # <-- OPTIONAL: The worklog start date and time (ISO 8601 format)
$StartedBefore = ""  # <-- OPTIONAL: The worklog start date and time (ISO 8601 format)
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
    # Build query string manually
    $QueryParams = @()
    $QueryParams += "startAt=" + $StartAt
    $QueryParams += "maxResults=" + $MaxResults
    if ($StartedAfter) { $QueryParams += "startedAfter=" + [System.Uri]::EscapeDataString($StartedAfter) }
    if ($StartedBefore) { $QueryParams += "startedBefore=" + [System.Uri]::EscapeDataString($StartedBefore) }
    $QueryParams += "expand=" + [System.Uri]::EscapeDataString($Expand)
    
    $QueryString = $QueryParams -join "&"
    $FullUrlWithQuery = $FullUrl + "?" + $QueryString
    
    $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process worklogs
    if ($Response.worklogs -and $Response.worklogs.Count -gt 0) {
        foreach ($worklog in $Response.worklogs) {
            $WorklogData = [PSCustomObject]@{
                Id = $worklog.id
                Self = $worklog.self
                IssueId = $worklog.issueId
                Author = if ($worklog.author) { $worklog.author.displayName } else { "" }
                AuthorKey = if ($worklog.author) { $worklog.author.key } else { "" }
                AuthorEmail = if ($worklog.author) { $worklog.author.emailAddress } else { "" }
                UpdateAuthor = if ($worklog.updateAuthor) { $worklog.updateAuthor.displayName } else { "" }
                UpdateAuthorKey = if ($worklog.updateAuthor) { $worklog.updateAuthor.key } else { "" }
                UpdateAuthorEmail = if ($worklog.updateAuthor) { $worklog.updateAuthor.emailAddress } else { "" }
                Comment = if ($worklog.comment) { $worklog.comment } else { "" }
                Created = $worklog.created
                Updated = $worklog.updated
                Started = $worklog.started
                TimeSpent = $worklog.timeSpent
                TimeSpentSeconds = $worklog.timeSpentSeconds
                Properties = if ($worklog.properties) { ($worklog.properties | ConvertTo-Json -Compress) } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $WorklogData
        }
    } else {
        # If no worklogs, create a single record with empty data
        $WorklogData = [PSCustomObject]@{
            Id = ""
            Self = ""
            IssueId = ""
            Author = ""
            AuthorKey = ""
            AuthorEmail = ""
            UpdateAuthor = ""
            UpdateAuthorKey = ""
            UpdateAuthorEmail = ""
            Comment = ""
            Created = ""
            Updated = ""
            Started = ""
            TimeSpent = ""
            TimeSpentSeconds = ""
            Properties = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $WorklogData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Worklogs - GET Worklogs - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve worklogs data: $($_.Exception.Message)"
    exit 1
}

