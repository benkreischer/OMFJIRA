# =============================================================================
# ENDPOINT: Issue Worklogs - GET Worklog Properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklogs/#api-rest-api-3-issue-issueidorkey-worklog-worklogid-properties-get
#
# DESCRIPTION: Returns the keys of all properties for a worklog.
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
    
    # Process worklog properties
    if ($Response.keys -and $Response.keys.Count -gt 0) {
        foreach ($key in $Response.keys) {
            $PropertyData = [PSCustomObject]@{
                Key = $key
                Self = $Response.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        # If no properties, create a single record with empty data
        $PropertyData = [PSCustomObject]@{
            Key = ""
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Worklogs - GET Worklog Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve worklog properties data: $($_.Exception.Message)"
    exit 1
}

