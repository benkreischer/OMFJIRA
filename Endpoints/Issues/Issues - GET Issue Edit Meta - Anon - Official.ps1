# =============================================================================
# ENDPOINT: Issues - GET Issue Edit Meta
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-editmeta-get
#
# DESCRIPTION: Returns the edit screen fields for an issue that are visible to and editable by the user.
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
$OverrideScreenSecurity = "false"  # <-- OPTIONAL: Whether to override screen security
$OverrideEditableFlag = "false"  # <-- OPTIONAL: Whether to override editable flag

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey/editmeta"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get -Body @{
        overrideScreenSecurity = $OverrideScreenSecurity
        overrideEditableFlag = $OverrideEditableFlag
    }
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a flattened object with all the edit meta data
    $EditMetaData = [PSCustomObject]@{
        Fields = if ($Response.fields) { ($Response.fields | ConvertTo-Json -Compress) } else { "" }
        FieldsToInclude = if ($Response.fieldsToInclude) { ($Response.fieldsToInclude | ConvertTo-Json -Compress) } else { "" }
        FieldsToExclude = if ($Response.fieldsToExclude) { ($Response.fieldsToExclude | ConvertTo-Json -Compress) } else { "" }
        Links = if ($Response.links) { ($Response.links | ConvertTo-Json -Compress) } else { "" }
        Operations = if ($Response.operations) { ($Response.operations | ConvertTo-Json -Compress) } else { "" }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $EditMetaData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issues - GET Issue Edit Meta - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve issue edit meta data: $($_.Exception.Message)"
    exit 1
}

