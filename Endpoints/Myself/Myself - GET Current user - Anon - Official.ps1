# =============================================================================
# ENDPOINT: Myself - GET Current user
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-myself/#api-rest-api-3-myself-get
#
# DESCRIPTION: Returns details for the current user.
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
$Endpoint = "/rest/api/3/myself"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching current user details..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
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
    } else {
        # If no user data, create a single record with empty data
        $UserData = [PSCustomObject]@{
            Self = ""
            Key = ""
            AccountId = ""
            AccountType = ""
            Name = ""
            EmailAddress = ""
            AvatarUrls = ""
            DisplayName = ""
            Active = ""
            TimeZone = ""
            Locale = ""
            Groups = ""
            ApplicationRoles = ""
            Properties = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $UserData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Myself - GET Current user - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve current user data: $($_.Exception.Message)"
    exit 1
}

