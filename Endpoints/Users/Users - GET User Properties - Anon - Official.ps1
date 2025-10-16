# =============================================================================
# ENDPOINT: Users - GET User Properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-properties-get
#
# DESCRIPTION: Returns the keys of all properties for a user.
#
# =============================================================================

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
$AccountId = "5b10a2844c20165700ede21g"  # <-- IMPORTANT: Replace with the account ID of the user

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $UserId = $Params.CommonParameters.UserId # <-- IMPORTANT: Replace with valid UserId
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/user/properties?accountId=712020:27226219-226e-4bf3-9d13-545a6e6c9f8c"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process user properties
    if ($Response.keys -and $Response.keys.Count -gt 0) {
        foreach ($key in $Response.keys) {
            $PropertyData = [PSCustomObject]@{
                Key = $key
                Self = if ($Response.self) { $Response.self } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        # If no properties, create a single record with empty data
        $PropertyData = [PSCustomObject]@{
            Key = ""
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Users - GET User Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve user properties data: $($_.Exception.Message)"
    exit 1
}

