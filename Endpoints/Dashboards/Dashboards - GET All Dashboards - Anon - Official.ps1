# =============================================================================
# ENDPOINT: Dashboards - GET All Dashboards
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-get
#
# DESCRIPTION: Returns a paginated list of dashboards.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Optionally, adjust the 'Filter' parameter. Valid values are "my", "favourite".
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
# PARAMETER (Optional)
# =============================================================================
$Filter = "" # "my", "favourite", or "" (for all)

# =============================================================================
# API CALL (with pagination handling)
# =============================================================================
$Endpoint = "/rest/api/3/dashboard"
$FullUrl = $BaseUrl + $Endpoint
$AllDashboards = @()
$StartAt = 0
$MaxResults = $Params.MaxResults

try {
    do {
        Write-Output "Fetching dashboards starting at index $StartAt..."
        $QueryParams = @()
        if ($Filter) { $QueryParams += "filter=" + [System.Web.HttpUtility]::UrlEncode($Filter) }
        $QueryParams += "startAt=" + $StartAt
        $QueryParams += "maxResults=" + $MaxResults
        
        $QueryString = $QueryParams -join "&"
        $FullUrlWithQuery = $FullUrl + "?" + $QueryString

        $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $Headers -Method Get

        if ($Response -and $Response.dashboards.Count -gt 0) {
            $AllDashboards += $Response.dashboards
            $StartAt += $Response.dashboards.Count
            Write-Output "Retrieved $($Response.dashboards.Count) dashboards (Total so far: $($AllDashboards.Count))"
        } else {
            break
        }
    } while ($Response.isLast -eq $false)

    Write-Output "Pagination complete. Total dashboards retrieved: $($AllDashboards.Count)"

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($AllDashboards -and $AllDashboards.Count -gt 0) {
        foreach ($dashboard in $AllDashboards) {
            $DashboardData = [PSCustomObject]@{
                ID = $dashboard.id
                Name = $dashboard.name
                Owner_DisplayName = if ($dashboard.owner -and $dashboard.owner.displayName) { $dashboard.owner.displayName } else { "" }
                SharePermissions = if ($dashboard.sharePermissions) { ($dashboard.sharePermissions | ForEach-Object { "$($_.type): $($_.id)" } | Sort-Object) -join "; " } else { "" }
                EditPermissions = if ($dashboard.editPermissions) { ($dashboard.editPermissions | ForEach-Object { "$($_.type): $($_.id)" } | Sort-Object) -join "; " } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $DashboardData
        }
    } else {
        # If no dashboards, create a single record with empty data
        $DashboardData = [PSCustomObject]@{
            ID = ""
            Name = ""
            Owner_DisplayName = ""
            SharePermissions = ""
            EditPermissions = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $DashboardData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Dashboards - GET All Dashboards - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve dashboards data: $($_.Exception.Message)"
    exit 1
}

