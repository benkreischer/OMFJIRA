# =============================================================================
# ENDPOINT: Issue navigator settings - GET Issue navigator columns
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-navigator-settings/#api-rest-api-3-settings-columns-get
#
# DESCRIPTION: Returns the default issue navigator columns for the user.
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
$Endpoint = "/rest/api/3/settings/columns"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching issue navigator columns..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.Count -gt 0) {
        foreach ($column in $Response) {
            $ColumnData = [PSCustomObject]@{
                Label = $column.label
                Value = $column.value
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ColumnData
        }
    } else {
        Write-Output "No issue navigator columns found"
        $ColumnData = [PSCustomObject]@{ Label = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        $Result += $ColumnData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue navigator settings - GET Issue navigator columns - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve issue navigator columns: $($_.Exception.Message)"
    $ColumnData = [PSCustomObject]@{ Label = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    $Result = @($ColumnData)
    $OutputFile = "Issue navigator settings - GET Issue navigator columns - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

