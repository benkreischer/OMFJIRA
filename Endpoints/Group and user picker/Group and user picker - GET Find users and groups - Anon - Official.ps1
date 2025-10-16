# =============================================================================
# ENDPOINT: Group and user picker - GET Find users and groups
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-group-and-user-pickers/#api-rest-api-3-groupuserpicker-get
#
# DESCRIPTION: Returns a paginated list of users and groups matching the search criteria.
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
# PARAMETERS
# =============================================================================
$Query = "admin"  # <-- IMPORTANT: The string to search for
$ShowAvatar = $true
$FieldId = ""     # e.g., "assignee"
$ProjectId = ""   # e.g., "10000"
$IssueTypeId = "" # e.g., "10001"
$AvatarSize = "xsmall"

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/groupuserpicker"
$QueryParams = @{
    query = $Query
}

if ($ShowAvatar) { $QueryParams.showAvatar = $ShowAvatar }
if ($FieldId) { $QueryParams.fieldId = $FieldId }
if ($ProjectId) { $QueryParams.projectId = $ProjectId }
if ($IssueTypeId) { $QueryParams.issueTypeId = $IssueTypeId }
if ($AvatarSize) { $QueryParams.avatarSize = $AvatarSize }

$QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
$FullUrl = $BaseUrl + $Endpoint + "?" + $QueryString

try {
    Write-Output "Searching for users and groups with query: $Query..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Process users
        if ($Response.users -and $Response.users.Count -gt 0) {
            foreach ($user in $Response.users) {
                $UserData = [PSCustomObject]@{
                    Type = "user"
                    AccountId = $user.accountId
                    Name = $user.name
                    Key = $user.key
                    EmailAddress = $user.emailAddress
                    AvatarUrl = if ($user.avatarUrl) { $user.avatarUrl } else { "" }
                    DisplayName = $user.displayName
                    Active = $user.active
                    TimeZone = if ($user.timeZone) { $user.timeZone } else { "" }
                    Locale = if ($user.locale) { $user.locale } else { "" }
                    Groups = if ($user.groups -and $user.groups.items) { ($user.groups.items | ForEach-Object { $_.name }) -join "; " } else { "" }
                    ApplicationRoles = if ($user.applicationRoles -and $user.applicationRoles.items) { ($user.applicationRoles.items | ForEach-Object { $_.name }) -join "; " } else { "" }
                    SearchQuery = $Query
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $UserData
            }
        }

        # Process groups
        if ($Response.groups -and $Response.groups.Count -gt 0) {
            foreach ($group in $Response.groups) {
                $GroupData = [PSCustomObject]@{
                    Type = "group"
                    AccountId = ""
                    Name = $group.name
                    Key = ""
                    EmailAddress = ""
                    AvatarUrl = if ($group.avatarUrl) { $group.avatarUrl } else { "" }
                    DisplayName = $group.name
                    Active = ""
                    TimeZone = ""
                    Locale = ""
                    Groups = ""
                    ApplicationRoles = ""
                    SearchQuery = $Query
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $GroupData
            }
        }
    }

    if ($Result.Count -eq 0) {
        Write-Output "No users or groups found matching query: $Query"
        $EmptyData = [PSCustomObject]@{
            Type = ""; AccountId = ""; Name = ""; Key = ""; EmailAddress = ""; AvatarUrl = ""; 
            DisplayName = ""; Active = ""; TimeZone = ""; Locale = ""; Groups = ""; 
            ApplicationRoles = ""; SearchQuery = $Query; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $EmptyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Group and user picker - GET Find users and groups - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to search users and groups: $($_.Exception.Message)"
    $EmptyData = [PSCustomObject]@{
        Type = ""; AccountId = ""; Name = ""; Key = ""; EmailAddress = ""; AvatarUrl = ""; 
        DisplayName = ""; Active = ""; TimeZone = ""; Locale = ""; Groups = ""; 
        ApplicationRoles = ""; SearchQuery = $Query; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)
    $OutputFile = "Group and user picker - GET Find users and groups - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

