# =============================================================================
# ENDPOINT: Filters - GET Filters
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-filters/#api-rest-api-3-filter-get
#
# DESCRIPTION: Returns a paginated list of all filters.
#
# SETUP: 
# 1. Run this script to generate CSV data
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path $PSScriptRoot "Get-EndpointParameters.ps1"
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

# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# API CALL (with pagination handling)
# =============================================================================
$Endpoint = "/rest/api/3/filter/19039"
$FullUrl = $BaseUrl + $Endpoint
$AllFilters = @()
$StartAt = 0
$MaxResults = $Params.ApiSettings.MaxResults # Jira API default/max for this endpoint

try {
    do {
        Write-Output "Fetching filters starting at index $StartAt..."
        $QueryParams = @()
        $QueryParams += "startAt=" + $StartAt
        $QueryParams += "maxResults=" + $MaxResults
        $QueryParams += "expand=" + [System.Uri]::EscapeDataString("owner,jql")

        $QueryString = $QueryParams -join "&"
        $FullUrlWithQuery = $FullUrl + "?" + $QueryString

        $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

        if ($Response -and $Response.values.Count -gt 0) {
            $AllFilters += $Response.values
            $StartAt += $Response.values.Count
            Write-Output "Retrieved $($Response.values.Count) filters (Total so far: $($AllFilters.Count))"
        } else {
            break
        }
    } while ($Response.isLast -eq $false)

    Write-Output "Pagination complete. Total filters retrieved: $($AllFilters.Count)"

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($AllFilters -and $AllFilters.Count -gt 0) {
        foreach ($filter in $AllFilters) {
            $FilterData = [PSCustomObject]@{
                ID = $filter.id
                Name = $filter.name
                Description = $filter.description
                Owner_DisplayName = $filter.owner.displayName
                JQL = $filter.jql
                IsFavourite = $filter.favourite.ToString().ToLower()
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $FilterData
        }
    } else {
        # If no filters, create a single record with empty data
        $FilterData = [PSCustomObject]@{
            ID = ""
            Name = ""
            Description = ""
            Owner_DisplayName = ""
            JQL = ""
            IsFavourite = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $FilterData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Filters - GET Filters - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve filters data: $($_.Exception.Message)"
    exit 1
}
