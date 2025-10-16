# =============================================================================
# ENDPOINT: App properties - GET Application Properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-properties/
#
# DESCRIPTION: Returns application properties using basic authentication.
# This endpoint provides access to application-level configuration properties.
#
# SETUP:
# 1. Run this script to generate CSV data
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
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$PropertyKey = ""  # <-- OPTIONAL: Property key to retrieve

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/application-properties"
$QueryString = if ($PropertyKey) { "?key=" + $PropertyKey } else { "" }
$FullUrl = $BaseUrl + $Endpoint + $QueryString

try {
    Write-Output "Fetching application properties..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.Count -gt 0) {
        foreach ($property in $Response) {
            $PropertyData = [PSCustomObject]@{
                Id = $property.id
                Key = $property.key
                Value = $property.value
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        Write-Output "No application properties found"
        $PropertyData = [PSCustomObject]@{ Id = ""; Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        $Result += $PropertyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "App properties - GET App Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve application properties: $($_.Exception.Message)"
    $PropertyData = [PSCustomObject]@{ Id = ""; Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    $Result = @($PropertyData)
    $OutputFile = "App properties - GET App Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

