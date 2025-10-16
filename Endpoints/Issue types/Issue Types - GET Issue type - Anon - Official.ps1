# =============================================================================
# ENDPOINT: Issue Types - GET Issue type
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-types/#api-rest-api-3-issuetype-id-get
#
# DESCRIPTION: Returns an issue type.
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
$IssueTypeId = "10001"  # <-- IMPORTANT: Replace with the issue type ID

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $IssueTypeId = "1" # <-- IMPORTANT: Replace with valid IssueTypeId
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issuetype/10115"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a flattened object with all the issue type data
    $IssueTypeData = [PSCustomObject]@{
        Id = $Response.id
        Name = $Response.name
        Description = $Response.description
        IsSubtask = if ($Response.subtask) { $Response.subtask.ToString().ToLower() } else { "" }
        IconUrl = $Response.iconUrl
        Self = $Response.self
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $IssueTypeData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Types - GET Issue type - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue type data: $($_.Exception.Message)"
    exit 1
}

