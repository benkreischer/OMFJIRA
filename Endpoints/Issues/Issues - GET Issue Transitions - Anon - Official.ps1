# =============================================================================
# ENDPOINT: Issues - GET Issue Transitions
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-transitions-get
#
# DESCRIPTION: Returns either all transitions or a transition that can be performed by the user on an issue, based on the issue's status.
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
$Expand = "transitions.fields"  # <-- OPTIONAL: Specify expand options
$TransitionId = ""  # <-- OPTIONAL: The ID of the transition (leave empty for all transitions)
$SkipRemoteOnlyCondition = "false"  # <-- OPTIONAL: Whether to skip remote-only conditions

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey/transitions"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get -Body @{
        expand = $Expand
        transitionId = $TransitionId
        skipRemoteOnlyCondition = $SkipRemoteOnlyCondition
    }
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process transitions
    if ($Response.transitions -and $Response.transitions.Count -gt 0) {
        foreach ($transition in $Response.transitions) {
            $TransitionData = [PSCustomObject]@{
                Id = $transition.id
                Name = $transition.name
                To = if ($transition.to) { "$($transition.to.name) ($($transition.to.id))" } else { "" }
                Fields = if ($transition.fields) { "$($transition.fields.PSObject.Properties.Name.Count) fields" } else { "" }
                Operations = if ($transition.operations) { ($transition.operations | ForEach-Object { $_.id }) -join "; " } else { "" }
                HasScreen = if ($transition.hasScreen) { $transition.hasScreen.ToString().ToLower() } else { "" }
                IsGlobal = if ($transition.isGlobal) { $transition.isGlobal.ToString().ToLower() } else { "" }
                IsInitial = if ($transition.isInitial) { $transition.isInitial.ToString().ToLower() } else { "" }
                IsAvailable = if ($transition.isAvailable) { $transition.isAvailable.ToString().ToLower() } else { "" }
                IsConditional = if ($transition.isConditional) { $transition.isConditional.ToString().ToLower() } else { "" }
                IsLooped = if ($transition.isLooped) { $transition.isLooped.ToString().ToLower() } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $TransitionData
        }
    } else {
        # If no transitions, create a single record with empty data
        $TransitionData = [PSCustomObject]@{
            Id = ""
            Name = ""
            To = ""
            Fields = ""
            Operations = ""
            HasScreen = ""
            IsGlobal = ""
            IsInitial = ""
            IsAvailable = ""
            IsConditional = ""
            IsLooped = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $TransitionData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issues - GET Issue Transitions - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue transitions data: $($_.Exception.Message)"
    exit 1
}

