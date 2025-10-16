# =============================================================================
# ENDPOINT: Issue Resolutions - GET Resolutions
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-resolutions/#api-rest-api-3-resolution-get
#
# DESCRIPTION: Returns a list of all issue resolutions.
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/resolution"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process resolutions
    if ($Response -and $Response.Count -gt 0) {
        foreach ($resolution in $Response) {
            $ResolutionData = [PSCustomObject]@{
                Id = $resolution.id
                Name = $resolution.name
                Description = $resolution.description
                Self = $resolution.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ResolutionData
        }
    } else {
        # If no resolutions, create a single record with empty data
        $ResolutionData = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ResolutionData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Resolutions - GET Resolutions - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve resolutions data: $($_.Exception.Message)"
    exit 1
}

