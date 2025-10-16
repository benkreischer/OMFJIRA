# =============================================================================
# ENDPOINT: Dashboards - GET Search for dashboards
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-search-get
#
# DESCRIPTION: Returns a paginated list of dashboards matching the search criteria.
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
# API CALL (with pagination)
# =============================================================================
$Endpoint = "/rest/api/3/dashboard/search"
$Result = @()
$StartAt = 0
$MaxResults = 50
$IsLast = $false

try {
    Write-Output "Fetching dashboards with pagination..."

    while (-not $IsLast) {
        # Build URL with pagination parameters
        $QueryParams = @{
            startAt = $StartAt
            maxResults = $MaxResults
        }
        $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        $FullUrl = $BaseUrl + $Endpoint + "?" + $QueryString

        Write-Output "Calling API (startAt=$StartAt): $FullUrl"
        $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

        # Handle paginated response
        if ($Response.values) {
            $Result += $Response.values
            Write-Output "  Retrieved $($Response.values.Count) dashboards (total so far: $($Result.Count))"
            
            # Check if we're on the last page
            if ($Response.PSObject.Properties.Name -contains 'isLast') {
                $IsLast = $Response.isLast
            } else {
                # If isLast property doesn't exist, check if we got fewer results than requested
                $IsLast = $Response.values.Count -lt $MaxResults
            }
            
            # Increment for next page
            $StartAt += $Response.values.Count
        } else {
            # No values returned, we're done
            $IsLast = $true
        }
    }

    Write-Output "API call successful. Total dashboards retrieved: $($Result.Count)"

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    if ($Result.Count -eq 0) {
        # No data returned
        $Result += [PSCustomObject]@{
            Message = "No data returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Dashboards - GET Search for dashboards - Anon - Official.csv"
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
    $OutputFile = "Dashboards - GET Search for dashboards - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

