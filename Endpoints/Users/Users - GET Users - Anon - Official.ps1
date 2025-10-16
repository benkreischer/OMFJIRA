# =============================================================================
# ENDPOINT: Users - GET Users
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-users-search-get
#
# DESCRIPTION: Returns a list of users matching a search term.
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
$Query = ""  # <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
$Username = ""  # <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
$AccountId = ""  # <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
$Property = ""  # <-- OPTIONAL: A query string used to search properties
$MaxResultsPerPage = 1000  # <-- Maximum results per API call (Jira limit)

# =============================================================================
# PAGINATED API CALLS
# =============================================================================
$Endpoint = "/rest/api/3/users/search"
$FullUrl = $BaseUrl + $Endpoint
$AllUsers = @()
$StartAt = 0
$TotalRetrieved = 0

try {
    do {
        Write-Output "Fetching users starting at index $StartAt..."
        
        # Build query string manually
        $QueryParams = @()
        if ($Query) { $QueryParams += "query=" + [System.Web.HttpUtility]::UrlEncode($Query) }
        if ($Username) { $QueryParams += "username=" + [System.Web.HttpUtility]::UrlEncode($Username) }
        if ($AccountId) { $QueryParams += "accountId=" + [System.Web.HttpUtility]::UrlEncode($AccountId) }
        $QueryParams += "startAt=" + $StartAt
        $QueryParams += "maxResults=" + $MaxResultsPerPage
        if ($Property) { $QueryParams += "property=" + [System.Web.HttpUtility]::UrlEncode($Property) }
        
        $QueryString = $QueryParams -join "&"
        $FullUrlWithQuery = $FullUrl + "?" + $QueryString
        
        $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $Headers -Method Get
        
        if ($Response -and $Response.Count -gt 0) {
            $AllUsers += $Response
            $TotalRetrieved += $Response.Count
            $StartAt += $MaxResultsPerPage
            Write-Output "Retrieved $($Response.Count) users (Total so far: $TotalRetrieved)"
        } else {
            break
        }
        
        # Safety check to prevent infinite loops
        if ($TotalRetrieved -gt 50000) {
            Write-Warning "Retrieved over 50,000 users. Stopping to prevent excessive API calls."
            break
        }
        
    } while ($Response.Count -eq $MaxResultsPerPage)
    
    Write-Output "Pagination complete. Total users retrieved: $TotalRetrieved"
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process all users from paginated results
    if ($AllUsers -and $AllUsers.Count -gt 0) {
        foreach ($user in $AllUsers) {
            $UserData = [PSCustomObject]@{
                Self = $user.self
                Key = $user.key
                AccountId = $user.accountId
                AccountType = $user.accountType
                Name = $user.name
                EmailAddress = $user.emailAddress
                AvatarUrls = if ($user.avatarUrls) { ($user.avatarUrls | ConvertTo-Json -Compress) } else { "" }
                DisplayName = $user.displayName
                Active = if ($user.active) { $user.active.ToString().ToLower() } else { "" }
                TimeZone = $user.timeZone
                Locale = $user.locale
                Groups = if ($user.groups) { ($user.groups | ConvertTo-Json -Compress) } else { "" }
                ApplicationRoles = if ($user.applicationRoles) { ($user.applicationRoles | ConvertTo-Json -Compress) } else { "" }
                Properties = if ($user.properties) { ($user.properties | ConvertTo-Json -Compress) } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $UserData
        }
    } else {
        # If no users, create a single record with empty data
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
    $OutputFile = "Users - GET Users - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve users data: $($_.Exception.Message)"
    exit 1
}

