# =============================================================================
# ENDPOINT: Server Info - GET Server Info
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-server-info/#api-rest-api-3-serverinfo-get
#
# DESCRIPTION: Returns information about the Jira instance.
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
$Endpoint = "/rest/api/3/serverInfo"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching server information..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $ServerInfoData = [PSCustomObject]@{
            BaseUrl = $Response.baseUrl
            Version = $Response.version
            VersionNumbers = ($Response.versionNumbers -join '.')
            DeploymentType = $Response.deploymentType
            BuildNumber = $Response.buildNumber
            BuildDate = $Response.buildDate
            ServerTime = $Response.serverTime
            ScmInfo = $Response.scmInfo
            ServerTitle = $Response.serverTitle
            HealthChecks = if ($Response.healthChecks) { ($Response.healthChecks | ConvertTo-Json -Compress) } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ServerInfoData
    } else {
        # If no server info, create a single record with empty data
        $ServerInfoData = [PSCustomObject]@{
            BaseUrl = ""
            Version = ""
            VersionNumbers = ""
            DeploymentType = ""
            BuildNumber = ""
            BuildDate = ""
            ServerTime = ""
            ScmInfo = ""
            ServerTitle = ""
            HealthChecks = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ServerInfoData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Server Info - GET Server info - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve server info data: $($_.Exception.Message)"
    exit 1
}
