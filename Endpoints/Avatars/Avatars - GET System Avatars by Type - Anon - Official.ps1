# =============================================================================
# ENDPOINT: Avatars - GET System Avatars by Type
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-avatars/#api-rest-api-3-avatar-type-system-get
#
# DESCRIPTION: Returns a list of system avatars of a given type.
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
# PARAMETER
# =============================================================================
$AvatarType = "project"  # <-- IMPORTANT: Valid values are "project" or "user"

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/avatar/" + $AvatarType + "/system"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching system avatars for type: $AvatarType..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.system) {
        foreach ($avatar in $Response.system) {
            $AvatarData = [PSCustomObject]@{
                Id = $avatar.id
                IsSystemAvatar = $avatar.isSystemAvatar
                IsSelected = $avatar.isSelected
                IsDeletable = $avatar.isDeletable
                FileName = $avatar.fileName
                Owner = if ($avatar.owner -and $avatar.owner.displayName) { $avatar.owner.displayName } else { "" }
                OwnerAccountId = if ($avatar.owner -and $avatar.owner.accountId) { $avatar.owner.accountId } else { "" }
                Created = $avatar.created
                Updated = $avatar.updated
                Urls = if ($avatar.urls) { ($avatar.urls | ConvertTo-Json -Compress) } else { "" }
                AvatarType = $AvatarType
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $AvatarData
        }
    } else {
        Write-Output "No system avatars found for type: $AvatarType"
        $AvatarData = [PSCustomObject]@{ 
            Id = ""; IsSystemAvatar = ""; IsSelected = ""; IsDeletable = ""; FileName = ""; 
            Owner = ""; OwnerAccountId = ""; Created = ""; Updated = ""; Urls = ""; 
            AvatarType = $AvatarType; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
        }
        $Result += $AvatarData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Avatars - GET System Avatars by Type - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve system avatars: $($_.Exception.Message)"
    $AvatarData = [PSCustomObject]@{ 
        Id = ""; IsSystemAvatar = ""; IsSelected = ""; IsDeletable = ""; FileName = ""; 
        Owner = ""; OwnerAccountId = ""; Created = ""; Updated = ""; Urls = ""; 
        AvatarType = $AvatarType; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
    }
    $Result = @($AvatarData)
    $OutputFile = "Avatars - GET System Avatars by Type - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

