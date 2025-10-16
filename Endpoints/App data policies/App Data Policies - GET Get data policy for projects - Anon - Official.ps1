# =============================================================================
# ENDPOINT: App Data Policies - GET Get data policy for projects
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-data-policies/#api-rest-api-3-data-policy-project-get
#
# DESCRIPTION: Returns data policies for the projects specified in the request.
#
# ⚠️  IMPORTANT: This endpoint requires JIRA ADMINISTRATOR permissions
#    Ensure your credentials have admin access to retrieve data policies
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Ensure you have admin-level permissions in Jira
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
# PARAMETER
# =============================================================================
$ProjectIds = "10372,10122,10114"  # <-- Replace with comma-separated list of project IDs

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/data-policy/project"
$QueryString = "?ids=" + $ProjectIds
$FullUrl = $BaseUrl + $Endpoint + $QueryString

try {
    Write-Output "Fetching data policies for projects: $ProjectIds..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.projectDataPolicies) {
        foreach ($projectPolicy in $Response.projectDataPolicies) {
            $ProjectData = [PSCustomObject]@{
                ProjectId = $projectPolicy.id
                AnyContentBlocked = if ($projectPolicy.dataPolicy.anyContentBlocked -ne $null) { $projectPolicy.dataPolicy.anyContentBlocked.ToString().ToLower() } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ProjectData
        }
    } else {
        Write-Output "No project data policies found or response format unexpected"
        $ProjectData = [PSCustomObject]@{ ProjectId = ""; AnyContentBlocked = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        $Result += $ProjectData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "App Data Policies - GET Get data policy for projects - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve project data policies: $($_.Exception.Message)"
    $ProjectData = [PSCustomObject]@{ ProjectId = ""; AnyContentBlocked = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    $Result = @($ProjectData)
    $OutputFile = "App Data Policies - GET Get data policy for projects - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

