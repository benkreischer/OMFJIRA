# =============================================================================
# ENDPOINT: Project Types - GET Project Type
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-types/
#
# DESCRIPTION: Returns a specific project type using basic authentication.
# This endpoint provides access to a single project type.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Update the 'ProjectTypeKey' parameter with the desired project type key
# 3. Load the data
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
# PARAMETERS
# =============================================================================
$ProjectTypeKey = "software" # <-- IMPORTANT: Replace with the project type key you want to retrieve

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/project/type/" + $ProjectTypeKey
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching project type: $ProjectTypeKey"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.error -eq $null) {
        # Transform the response into a structured format
        $ProjectTypeData = [PSCustomObject]@{
            Key = $Response.key
            FormattedKey = $Response.formattedKey
            DescriptionI18nKey = $Response.descriptionI18nKey
            Icon = if ($Response.icon) { ($Response.icon | ConvertTo-Json -Compress) } else { "" }
            Color = $Response.color
            ProjectTypeKey = $ProjectTypeKey
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ProjectTypeData
    } else {
        # Handle error response
        $ErrorData = [PSCustomObject]@{
            Error = if ($Response.error) { $Response.error } else { "" }
            ErrorDescription = if ($Response.error_description) { $Response.error_description } else { "" }
            ProjectTypeKey = $ProjectTypeKey
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ErrorData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Project Types - GET Project Type - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve project type data: $($_.Exception.Message)"
    exit 1
}

