# =============================================================================
# ENDPOINT: Issues - GET Issue
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-get
#
# DESCRIPTION: Returns the details for an issue.
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey  # <-- IMPORTANT: Replace with the ID or key of the issue to retrieve
$Fields = "*all"  # <-- OPTIONAL: Specify fields to return (default: *all)
$Expand = "renderedFields,changelog,transitions,operations,editmeta,versionedRepresentations"  # <-- OPTIONAL: Specify expand options

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get -Body @{
        fields = $Fields
        expand = $Expand
    }
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Extract key fields from the issue data for CSV readability
    $IssueData = [PSCustomObject]@{
        Id = $Response.id
        Key = $Response.key
        Self = $Response.self
        Summary = if ($Response.fields.summary) { $Response.fields.summary } else { "" }
        Description = if ($Response.fields.description) { ($Response.fields.description -replace "[\r\n]+", " ") } else { "" }
        Status = if ($Response.fields.status) { $Response.fields.status.name } else { "" }
        Priority = if ($Response.fields.priority) { $Response.fields.priority.name } else { "" }
        IssueType = if ($Response.fields.issuetype) { $Response.fields.issuetype.name } else { "" }
        Assignee = if ($Response.fields.assignee) { $Response.fields.assignee.displayName } else { "" }
        Reporter = if ($Response.fields.reporter) { $Response.fields.reporter.displayName } else { "" }
        Created = if ($Response.fields.created) { $Response.fields.created } else { "" }
        Updated = if ($Response.fields.updated) { $Response.fields.updated } else { "" }
        Project = if ($Response.fields.project) { $Response.fields.project.name } else { "" }
        FixVersions = if ($Response.fields.fixVersions) { ($Response.fields.fixVersions | ForEach-Object { $_.name }) -join "; " } else { "" }
        Components = if ($Response.fields.components) { ($Response.fields.components | ForEach-Object { $_.name }) -join "; " } else { "" }
        Labels = if ($Response.fields.labels) { ($Response.fields.labels) -join "; " } else { "" }
        TransitionsCount = if ($Response.transitions) { $Response.transitions.Count } else { 0 }
        OperationsCount = if ($Response.operations) { $Response.operations.Count } else { 0 }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $IssueData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issues - GET Issue - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue data: $($_.Exception.Message)"
    exit 1
}

