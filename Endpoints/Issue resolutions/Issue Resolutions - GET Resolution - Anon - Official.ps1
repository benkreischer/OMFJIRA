# =============================================================================
# ENDPOINT: Issue Resolutions - GET Resolution
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-resolutions/#api-rest-api-3-resolution-id-get
#
# DESCRIPTION: Returns an issue resolution.
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
$ResolutionId = "10000"  # <-- IMPORTANT: Replace with a valid Issue Resolution ID

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/resolution/$ResolutionId"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a flattened object with all the resolution data
    $ResolutionData = [PSCustomObject]@{
        Id = $Response.id
        Name = $Response.name
        Description = $Response.description
        Self = $Response.self
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $ResolutionData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Resolutions - GET Resolution - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve resolution data: $($_.Exception.Message)"
    exit 1
}

