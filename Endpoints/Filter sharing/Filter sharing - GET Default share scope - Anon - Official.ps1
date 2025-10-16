# =============================================================================
# ENDPOINT: Filter sharing - GET Default share scope
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-filter-sharing/#api-rest-api-3-filter-defaultsharescope-get
#
# DESCRIPTION: Returns the default share scope for all filters.
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
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/filter/defaultShareScope"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching default share scope for filters..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Convert the response object to key-value pairs
        $Response.PSObject.Properties | ForEach-Object {
            $ScopeData = [PSCustomObject]@{
                Key = $_.Name
                Value = $_.Value
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ScopeData
        }
    } else {
        Write-Output "No default share scope found"
        $ScopeData = [PSCustomObject]@{ Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        $Result += $ScopeData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Filter sharing - GET Default share scope - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve default share scope: $($_.Exception.Message)"
    $ScopeData = [PSCustomObject]@{ Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    $Result = @($ScopeData)
    $OutputFile = "Filter sharing - GET Default share scope - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

