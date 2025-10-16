# =============================================================================
# ENDPOINT: Status - GET Statuses
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-status/#api-rest-api-3-status-get
#
# DESCRIPTION: Returns all statuses.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. No additional parameters required.
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
$Endpoint = "/rest/api/3/status"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching all statuses..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.Count -gt 0) {
        foreach ($status in $Response) {
            $StatusData = [PSCustomObject]@{
                ID = $status.id
                Name = $status.name
                StatusCategory = if ($status.statusCategory) { ($status.statusCategory | ConvertTo-Json -Compress) } else { "" }
                Description = $status.description
                IconUrl = $status.iconUrl
                Self = $status.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $StatusData
        }
    } else {
        # If no statuses, create a single record with empty data
        $StatusData = [PSCustomObject]@{
            ID = ""
            Name = ""
            StatusCategory = ""
            Description = ""
            IconUrl = ""
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $StatusData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Status - GET Statuses - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve statuses data: $($_.Exception.Message)"
    exit 1
}
