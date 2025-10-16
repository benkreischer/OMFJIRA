# =============================================================================
# ENDPOINT: Issue Security Level - GET Security Levels
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-security-level/#api-rest-api-3-issuesecurityschemes-get
#
# DESCRIPTION: Returns all issue security schemes.
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
$Endpoint = "/rest/api/3/issuesecurityschemes"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process security schemes
    if ($Response.issueSecuritySchemes -and $Response.issueSecuritySchemes.Count -gt 0) {
        foreach ($scheme in $Response.issueSecuritySchemes) {
            $SecurityLevelData = [PSCustomObject]@{
                Id = $scheme.id
                Name = $scheme.name
                Description = $scheme.description
                Self = $scheme.self
                Levels = if ($scheme.levels) { ($scheme.levels | ConvertTo-Json -Compress) } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $SecurityLevelData
        }
    } else {
        # If no security schemes, create a single record with empty data
        $SecurityLevelData = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            Self = ""
            Levels = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $SecurityLevelData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Security Level - GET Security Levels - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve security levels data: $($_.Exception.Message)"
    exit 1
}

