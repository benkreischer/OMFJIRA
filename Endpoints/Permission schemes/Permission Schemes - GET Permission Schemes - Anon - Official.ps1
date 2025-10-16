# =============================================================================
# ENDPOINT: Permission Schemes - GET Permission Schemes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permission-schemes/#api-rest-api-3-permissionscheme-get
#
# DESCRIPTION: Returns all permission schemes.
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
# PARAMETERS
# =============================================================================
$Expand = "all" # <-- OPTIONAL: Use expand to include additional information

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/permissionscheme"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching permission schemes..."
    $QueryString = "expand=" + [System.Uri]::EscapeDataString($Expand)
    $FullUrlWithQuery = $FullUrl + "?" + $QueryString

    $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.PSObject.Properties.Name -contains "permissionSchemes") {
        # Handle permission schemes array
        if ($Response.permissionSchemes.Count -gt 0) {
            foreach ($scheme in $Response.permissionSchemes) {
                $SchemeData = [PSCustomObject]@{
                    Id = if ($scheme.id) { $scheme.id } else { "" }
                    Name = if ($scheme.name) { $scheme.name } else { "" }
                    Description = if ($scheme.description) { $scheme.description } else { "" }
                    Self = if ($scheme.self) { $scheme.self } else { "" }
                    Expand = if ($scheme.expand) { $scheme.expand } else { "" }
                    PermissionsCount = if ($scheme.permissions) { $scheme.permissions.Count } else { 0 }
                    HasScope = if ($scheme.scope) { "Yes" } else { "No" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $SchemeData
            }
        } else {
            # No permission schemes
            $Result += [PSCustomObject]@{
                Id = ""
                Name = "No permission schemes found"
                Description = ""
                Self = ""
                Expand = ""
                PermissionsCount = 0
                HasScope = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        # No response data
        $Result += [PSCustomObject]@{
            Id = ""
            Name = "No data returned"
            Description = ""
            Self = ""
            Expand = ""
            PermissionsCount = 0
            HasScope = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Permission Schemes - GET Permission Schemes - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve permission schemes data: $($_.Exception.Message)"
    exit 1
}

