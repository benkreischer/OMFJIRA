# =============================================================================
# ENDPOINT: Issue Types - GET Issue types for project
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-types/#api-rest-api-3-issuetype-projectidorkey-get
#
# DESCRIPTION: Returns issue types for a project.
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
$ProjectIdOrKey = $Params.CommonParameters.ProjectIdOrKey  # <-- IMPORTANT: Replace with the project ID or key

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $IssueTypeId = "1" # <-- IMPORTANT: Replace with valid IssueTypeId
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issuetype/project?projectId=10292"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process issue types for project
    if ($Response -and $Response.Count -gt 0) {
        foreach ($issueType in $Response) {
            $IssueTypeData = [PSCustomObject]@{
                Id = $issueType.id
                Name = $issueType.name
                Description = $issueType.description
                IsSubtask = if ($issueType.subtask) { $issueType.subtask.ToString().ToLower() } else { "" }
                IconUrl = $issueType.iconUrl
                Self = $issueType.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $IssueTypeData
        }
    } else {
        # If no issue types, create a single record with empty data
        $IssueTypeData = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            IsSubtask = ""
            IconUrl = ""
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $IssueTypeData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Types - GET Issue types for project - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue types for project data: $($_.Exception.Message)"
    exit 1
}

