# =============================================================================
# ENDPOINT: Project Types - GET Project Type Accessible
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-types/
#
# DESCRIPTION: Returns accessible project types using basic authentication.
# This endpoint provides access to project types that the user can access.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Load the data
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
$Endpoint = "/rest/api/3/project/type/accessible"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching accessible project types..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.error -eq $null) {
        # Transform each accessible project type into a separate row
        foreach ($projectType in $Response) {
            $ProjectTypeData = [PSCustomObject]@{
                Key = $projectType.key
                FormattedKey = $projectType.formattedKey
                DescriptionI18nKey = $projectType.descriptionI18nKey
                Color = $projectType.color
                HasIcon = if ($projectType.icon) { "Yes" } else { "No" }
                IsAccessible = "Yes"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ProjectTypeData
        }
    } else {
        # Handle error response
        $ErrorData = [PSCustomObject]@{
            Error = if ($Response.error) { $Response.error } else { "Unknown error" }
            ErrorDescription = if ($Response.error_description) { $Response.error_description } else { "" }
            Key = ""
            FormattedKey = ""
            DescriptionI18nKey = ""
            Color = ""
            HasIcon = ""
            IsAccessible = "No"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ErrorData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Project Types - GET Project Type Accessible - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve accessible project types data: $($_.Exception.Message)"
    exit 1
}

