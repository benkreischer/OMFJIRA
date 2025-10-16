# =============================================================================
# ENDPOINT: Issue Security Level - GET Security Level
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-security-level/#api-rest-api-3-issuesecurityschemes-id-get
#
# DESCRIPTION: Returns an issue security scheme.
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
$SecuritySchemeId = "10000"  # <-- IMPORTANT: Replace with the ID of the security scheme

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issuesecurityschemes/$SecuritySchemeId"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a flattened object with all the security level data
    $SecurityLevelData = [PSCustomObject]@{
        Id = $Response.id
        Name = $Response.name
        Description = $Response.description
        Self = $Response.self
        Levels = if ($Response.levels) { ($Response.levels | ConvertTo-Json -Compress) } else { "" }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $SecurityLevelData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Security Level - GET Security Level - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve security level data: $($_.Exception.Message)"
    exit 1
}

