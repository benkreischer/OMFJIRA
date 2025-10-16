# =============================================================================
# ENDPOINT: Users - GET User
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-get
#
# DESCRIPTION: Returns a user.
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
$Expand = "groups,applicationRoles"  # <-- OPTIONAL: Use expand to include additional information

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $UserId = $Params.CommonParameters.UserId # <-- IMPORTANT: Replace with valid UserId
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/user?accountId=712020:27226219-226e-4bf3-9d13-545a6e6c9f8c"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Create a flattened object with all the user data
    $UserData = [PSCustomObject]@{
        Self = $Response.self
        Key = $Response.key
        AccountId = $Response.accountId
        AccountType = $Response.accountType
        Name = $Response.name
        EmailAddress = $Response.emailAddress
        AvatarUrls = if ($Response.avatarUrls) { ($Response.avatarUrls | ConvertTo-Json -Compress) } else { "" }
        DisplayName = $Response.displayName
        Active = if ($Response.active) { $Response.active.ToString().ToLower() } else { "" }
        TimeZone = $Response.timeZone
        Locale = $Response.locale
        Groups = if ($Response.groups) { ($Response.groups | ConvertTo-Json -Compress) } else { "" }
        ApplicationRoles = if ($Response.applicationRoles) { ($Response.applicationRoles | ConvertTo-Json -Compress) } else { "" }
        Properties = if ($Response.properties) { ($Response.properties | ConvertTo-Json -Compress) } else { "" }
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $Result += $UserData
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Users - GET User - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve user data: $($_.Exception.Message)"
    exit 1
}

