# =============================================================================
# ENDPOINT: Screen Schemes - GET Screen Schemes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screen-schemes/
#
# DESCRIPTION: Returns screen schemes using basic authentication.
# This endpoint provides access to screen configuration schemes.
#
# =============================================================================

# Configuration
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

# Create authentication header
$AuthString = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${ApiToken}"))
$Headers = @{
    "Authorization" = "Basic $AuthString"
    "Accept" = "application/json"
}

# API endpoint
$Endpoint = "/rest/api/3/screenscheme"
$FullUrl = $BaseUrl + $Endpoint

try {
    # Make API call
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers
    
    # Transform response into structured format
    $Results = @()
    
    if ($Response -and $Response.values -and $Response.values.Count -gt 0) {
        foreach ($Scheme in $Response.values) {
            $Result = [PSCustomObject]@{
                Id = if ($Scheme.id) { $Scheme.id } else { "" }
                Name = if ($Scheme.name) { $Scheme.name } else { "" }
                Description = if ($Scheme.description) { $Scheme.description } else { "" }
                Screens = if ($Scheme.screens) { ($Scheme.screens | ConvertTo-Json -Compress) } else { "" }
                GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
            $Results += $Result
        }
    } else {
        # Handle case where no schemes are returned
        $Result = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            Screens = ""
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # Export to CSV
    $OutputPath = Join-Path $PSScriptRoot "Screen Schemes - GET Screen Schemes - Anon - Official.csv"
    $Results | Export-Csv -Path $OutputPath -NoTypeInformation
    
    Write-Host "Screen Schemes data exported to: $OutputPath"
    Write-Host "Total records: $($Results.Count)"
    
} catch {
    Write-Error "Failed to retrieve screen schemes: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $OutputPath = Join-Path $PSScriptRoot "Screen Schemes - GET Screen Schemes - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $OutputPath -NoTypeInformation
}

