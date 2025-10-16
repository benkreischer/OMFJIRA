# =============================================================================
# ENDPOINT: Issues - GET Issue Changelog
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-changelog-get
#
# DESCRIPTION: Returns the changelog for an issue.
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

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey/changelog"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get -Body @{
        startAt = $StartAt
        maxResults = $MaxResults
    }
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process changelog entries
    if ($Response.values -and $Response.values.Count -gt 0) {
        foreach ($change in $Response.values) {
            $ChangeData = [PSCustomObject]@{
                Id = $change.id
                Author = if ($change.author) { $change.author.displayName } else { "" }
                Created = $change.created
                Items = if ($change.items) { ($change.items | ForEach-Object { "$($_.field): '$($_.fromString)' -> '$($_.toString)'" }) -join "; " } else { "" }
                HistoryMetadata = if ($change.historyMetadata) { "$($change.historyMetadata.type): $($change.historyMetadata.description)" } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ChangeData
        }
    } else {
        # If no changelog entries, create a single record with empty data
        $ChangeData = [PSCustomObject]@{
            Id = ""
            Author = ""
            Created = ""
            Items = ""
            HistoryMetadata = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ChangeData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issues - GET Issue Changelog - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue changelog data: $($_.Exception.Message)"
    exit 1
}

