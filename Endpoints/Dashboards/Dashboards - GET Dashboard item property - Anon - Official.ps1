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
$ItemId = "item1"  # Dashboard item ID
$PropertyKey = "property1"  # Property key

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/dashboard/$DashboardId/items/$ItemId/properties/$PropertyKey"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.PSObject.Properties.Name -contains "dashboards") {
        # Handle paginated dashboards response
        if ($Response.dashboards.Count -gt 0) {
            foreach ($dashboard in $Response.dashboards) {
                $DashboardData = [PSCustomObject]@{
                    Id = if ($dashboard.id) { $dashboard.id } else { "" }
                    Name = if ($dashboard.name) { $dashboard.name } else { "" }
                    Self = if ($dashboard.self) { $dashboard.self } else { "" }
                    View = if ($dashboard.view) { $dashboard.view } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $DashboardData
            }

            # Add pagination info as a summary row
            $PaginationInfo = [PSCustomObject]@{
                Id = "PAGINATION_INFO"
                Name = "Total: $($Response.total), StartAt: $($Response.startAt), MaxResults: $($Response.maxResults)"
                Self = if ($Response.next) { $Response.next } else { "No next page" }
                View = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PaginationInfo
        } else {
            # No dashboards
            $Result += [PSCustomObject]@{
                Id = ""
                Name = "No dashboards found"
                Self = ""
                View = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        # No response data
        $Result += [PSCustomObject]@{
            Id = ""
            Name = "No data returned"
            Self = ""
            View = ""
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

