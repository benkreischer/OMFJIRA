# =============================================================================
# ENDPOINT: Permissions - GET All permissions
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permissions/#api-rest-api-3-permissions-get
#
# DESCRIPTION: Returns all permissions, including project permissions and global permissions.
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
$Endpoint = "/rest/api/3/permissions"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching all permissions..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.permissions) {
        foreach ($key in $Response.permissions.PSObject.Properties.Name) {
            $permission = $Response.permissions.$key
            $PermissionData = [PSCustomObject]@{
                Key = $permission.key
                Name = $permission.name
                Type = $permission.type
                Description = $permission.description
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PermissionData
        }
    } else {
        # If no permissions, create a single record with empty data
        $PermissionData = [PSCustomObject]@{
            Key = ""
            Name = ""
            Type = ""
            Description = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PermissionData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Permissions - GET All permissions - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve permissions data: $($_.Exception.Message)"
    exit 1
}
