# =============================================================================
# ENDPOINT: Screen Schemes - GET Screen Scheme
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screen-schemes/
#
# DESCRIPTION: Returns a specific screen scheme using basic authentication.
# This endpoint provides access to a single screen configuration scheme.
#
# =============================================================================

# Configuration
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

# Parameters
$ScreenSchemeId = "10003"  # <-- Using MOB: Scrum Default Screen Scheme ID from the working data

# Create authentication header
$AuthString = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${ApiToken}"))
$Headers = @{
    "Authorization" = "Basic $AuthString"
    "Accept" = "application/json"
}

# API endpoint
$Endpoint = "/rest/api/3/screenscheme/$ScreenSchemeId"
$FullUrl = $BaseUrl + $Endpoint

try {
    # Make API call
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers
    
    # Transform response into structured format
    $Result = [PSCustomObject]@{
        Id = if ($Response.id) { $Response.id } else { "" }
        Name = if ($Response.name) { $Response.name } else { "" }
        Description = if ($Response.description) { $Response.description } else { "" }
        Screens = if ($Response.screens) { ($Response.screens | ConvertTo-Json -Compress) } else { "" }
        ScreenSchemeId = $ScreenSchemeId
        GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    # Export to CSV
    $OutputPath = Join-Path $PSScriptRoot "Screen Schemes - GET Screen Scheme - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputPath -NoTypeInformation
    
    Write-Host "Screen Scheme data exported to: $OutputPath"
    Write-Host "Screen Scheme ID: $ScreenSchemeId"
    
} catch {
    Write-Error "Failed to retrieve screen scheme: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        ScreenSchemeId = $ScreenSchemeId
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $OutputPath = Join-Path $PSScriptRoot "Screen Schemes - GET Screen Scheme - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $OutputPath -NoTypeInformation
}

