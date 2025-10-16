# =============================================================================
# ENDPOINT: Issue Watchers - GET Is Watching
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-watchers/#api-rest-api-3-issue-issueidorkey-watchers-get
#
# DESCRIPTION: Returns whether the calling user is watching this issue.
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

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey/watchers"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a single record with the watching status
    $WatchingData = [PSCustomObject]@{
        IssueIdOrKey = $IssueIdOrKey
        IsWatching = if ($Response.isWatching) { $Response.isWatching.ToString().ToLower() } else { "" }
        WatchCount = if ($Response.watchCount) { $Response.watchCount } else { 0 }
        Watchers = if ($Response.watchers) { ($Response.watchers | ConvertTo-Json -Compress) } else { "" }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $WatchingData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Watchers - GET Is Watching - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve watching status data: $($_.Exception.Message)"
    exit 1
}

