# =============================================================================
# ENDPOINT: Screens - GET Screens
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
#
# DESCRIPTION: Returns screens using basic authentication.
# This endpoint provides access to screen management.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Load the data
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
# API CALL WITH PAGINATION
# =============================================================================
$Endpoint = "/rest/api/3/screens"
$MaxResults = $Params.ApiSettings.MaxResults  # Maximum allowed per page
$StartAt = 0
$Result = @()

try {
    Write-Output "Fetching all screens with pagination..."
    
    do {
        $FullUrl = $BaseUrl + $Endpoint + "?startAt=" + $StartAt + "&maxResults=" + $MaxResults
        Write-Output "Fetching page starting at $StartAt..."
        
        $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

        # =============================================================================
        # DATA TRANSFORMATION
        # =============================================================================
        if ($Response -and $Response.error -eq $null -and $Response.values) {
            # Process each screen individually
            foreach ($screen in $Response.values) {
                $ScreenData = [PSCustomObject]@{
                    Id = $screen.id
                    Name = $screen.name
                    Description = if ($screen.description) { $screen.description } else { "" }
                    Scope = if ($screen.scope) { $screen.scope } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $ScreenData
            }
            
            Write-Output "Retrieved $($Response.values.Count) screens from this page. Total so far: $($Result.Count)"
            
            # Check if this is the last page
            if ($Response.isLast -eq $true) {
                Write-Output "Reached last page. Pagination complete."
                break
            }
            
            # Move to next page
            $StartAt += $MaxResults
            
        } else {
            # Handle error response or no data
            if ($Response.error) {
                Write-Error "API Error: $($Response.error)"
                break
            } else {
                Write-Output "No data returned from API"
                break
            }
        }
        
    } while ($true)

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Screens - GET Screens - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve screens data: $($_.Exception.Message)"
    exit 1
}

