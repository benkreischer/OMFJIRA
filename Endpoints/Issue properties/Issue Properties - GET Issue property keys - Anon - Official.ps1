# =============================================================================
# ENDPOINT: Issue Properties - GET Issue property keys
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-properties/#api-rest-api-3-issue-issueidorkey-properties-get
#
# DESCRIPTION: Returns the keys of an issue's properties.
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Update the 'IssueIdOrKey' parameter with a valid issue ID or key.
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
# PARAMETER
# =============================================================================
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey # <-- IMPORTANT: Replace with a valid Issue ID or Key

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/" + $IssueIdOrKey + "/properties"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching property keys for issue $IssueIdOrKey..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.keys.Count -gt 0) {
        foreach ($key in $Response.keys) {
            $PropertyKeyData = [PSCustomObject]@{
                PropertyKey = $key.key
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyKeyData
        }
    } else {
        # If no property keys, create a single record with empty data
        $PropertyKeyData = [PSCustomObject]@{
            PropertyKey = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyKeyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Properties - GET Issue property keys - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve issue property keys data: $($_.Exception.Message)"
    exit 1
}
