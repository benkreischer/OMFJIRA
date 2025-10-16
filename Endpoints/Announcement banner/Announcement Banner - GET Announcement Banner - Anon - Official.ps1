# =============================================================================
# ENDPOINT: Announcement Banner - GET Announcement Banner
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-announcement-banner/#api-rest-api-3-announcementbanner-get
#
# DESCRIPTION: Returns the current announcement banner configuration using basic authentication.
# This endpoint provides access to announcement banner management.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Load the data
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

# =============================================================================
# LOAD CONFIGURATION PARAMETERS
# =============================================================================
$Params = Get-EndpointParameters
$BaseUrl = $Params.BaseUrl

# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/announcementBanner"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching announcement banner configuration..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $BannerData = [PSCustomObject]@{
            IsDismissible = if ($Response.isDismissible -ne $null) { $Response.isDismissible.ToString().ToLower() } else { "" }
            IsEnabled = if ($Response.isEnabled -ne $null) { $Response.isEnabled.ToString().ToLower() } else { "" }
            Message = if ($Response.message) { $Response.message } else { "" }
            Visibility = if ($Response.visibility) { $Response.visibility } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $BannerData
    } else {
        # If no banner data, create a single record with empty data
        $BannerData = [PSCustomObject]@{
            IsDismissible = ""
            IsEnabled = ""
            Message = ""
            Visibility = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $BannerData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Announcement Banner - GET Announcement Banner - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve announcement banner data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $BannerData = [PSCustomObject]@{
        IsDismissible = ""
        IsEnabled = ""
        Message = ""
        Visibility = ""
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($BannerData)
    
    # Export empty CSV
    $OutputFile = "Announcement Banner - GET Announcement Banner - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    
    Write-Output "Created empty $OutputFile due to endpoint error"
    exit 0
}

