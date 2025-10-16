# =============================================================================
# ENDPOINT: Labels - GET All labels
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-labels/#api-rest-api-3-label-get
#
# DESCRIPTION: Returns a paginated list of labels.
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
$Endpoint = "/rest/api/3/label"
$FullUrl = $BaseUrl + $Endpoint
$AllLabels = @()
$StartAt = 0
$MaxResults = $Params.ApiSettings.MaxResults

try {
    do {
        Write-Output "Fetching labels starting at index $StartAt..."
        $QueryString = "startAt=" + $StartAt + "&maxResults=" + $MaxResults
        $FullUrlWithQuery = $FullUrl + "?" + $QueryString

        $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

        if ($Response -and $Response.values.Count -gt 0) {
            $AllLabels += $Response.values
            $StartAt += $Response.values.Count
            Write-Output "Retrieved $($Response.values.Count) labels (Total so far: $($AllLabels.Count))"
        } else {
            break
        }
    } while ($Response.isLast -eq $false)

    Write-Output "Pagination complete. Total labels retrieved: $($AllLabels.Count)"

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($AllLabels -and $AllLabels.Count -gt 0) {
        foreach ($label in $AllLabels) {
            $LabelData = [PSCustomObject]@{
                Label = $label
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $LabelData
        }
    } else {
        # If no labels, create a single record with empty data
        $LabelData = [PSCustomObject]@{
            Label = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $LabelData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Labels - GET All labels - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve labels data: $($_.Exception.Message)"
    exit 1
}
