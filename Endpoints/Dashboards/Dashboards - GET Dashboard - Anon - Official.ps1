# =============================================================================
# ENDPOINT: Dashboards - GET Dashboard
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-id-get
#
# DESCRIPTION: Returns a dashboard.
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


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETER - REQUIRED
# =============================================================================
$DashboardId = if ($Params.CommonParameters.DashboardId) { $Params.CommonParameters.DashboardId } else { "11058" }

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/dashboard/$DashboardId"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.id) {
        # Single dashboard response
        $DashboardData = [PSCustomObject]@{
            Id = if ($Response.id) { $Response.id } else { "" }
            Name = if ($Response.name) { $Response.name } else { "" }
            Self = if ($Response.self) { $Response.self } else { "" }
            View = if ($Response.view) { $Response.view } else { "" }
            Owner = if ($Response.owner -and $Response.owner.displayName) { $Response.owner.displayName } else { "" }
            Popularity = if ($Response.popularity) { $Response.popularity } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $DashboardData
    } else {
        # No response data
        $Result += [PSCustomObject]@{
            Id = ""
            Name = "No data returned"
            Self = ""
            View = ""
            Owner = ""
            Popularity = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Dashboards - GET Dashboard - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "CSV file generated successfully: $(Get-Location)\$OutputFile"
    Write-Output "Records exported: $($Result.Count)"

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Output "
Sample data:"
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $EmptyData = [PSCustomObject]@{
        Error = $_.Exception.Message
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "Dashboards - GET Dashboard - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

