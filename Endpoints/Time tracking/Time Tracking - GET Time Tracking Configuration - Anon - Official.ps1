# =============================================================================
# ENDPOINT: Time Tracking - GET Time Tracking Configuration
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-time-tracking/#api-rest-api-3-configuration-timetracking-get
#
# DESCRIPTION: Returns the time tracking settings.
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
$Endpoint = "/rest/api/3/configuration/timetracking"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching time tracking configuration..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $TimeTrackingData = [PSCustomObject]@{
            WorkingHoursPerDay = $Response.workingHoursPerDay
            WorkingDaysPerWeek = $Response.workingDaysPerWeek
            TimeFormat = $Response.timeFormat
            DefaultUnit = $Response.defaultUnit
            LegacyOriginalEstimate = if ($Response.legacyOriginalEstimate) { $Response.legacyOriginalEstimate.ToString().ToLower() } else { "" }
            LegacyRemainingEstimate = if ($Response.legacyRemainingEstimate) { $Response.legacyRemainingEstimate.ToString().ToLower() } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $TimeTrackingData
    } else {
        # If no time tracking configuration, create a single record with empty data
        $TimeTrackingData = [PSCustomObject]@{
            WorkingHoursPerDay = ""
            WorkingDaysPerWeek = ""
            TimeFormat = ""
            DefaultUnit = ""
            LegacyOriginalEstimate = ""
            LegacyRemainingEstimate = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $TimeTrackingData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Time Tracking - GET Time Tracking Configuration - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve time tracking configuration data: $($_.Exception.Message)"
    exit 1
}
