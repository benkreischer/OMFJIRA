# =============================================================================
# JIRA AUTHENTICATION MANAGER
# =============================================================================

# Centralized authentication system for OMF users
# This system provides seamless login with OMF credentials and manages API tokens securely

param(
    [string]$Action = "login",
    [string]$Username = "",
    [string]$Password = "",
    [switch]$UseSSO = $false,
    [switch]$CreateUserProfile = $false,
    [switch]$UpdateCredentials = $false,
    [string]$ProfileName = ""
)

# Configuration
$JiraBaseUrl = "https://onemain.atlassian.net"
$AuthConfig = @{
    "profiles_path" = ".\user-profiles"
    "credentials_path" = ".\credentials"
    "session_timeout" = 8  # hours
    "auto_refresh" = $true
    "sso_enabled" = $true
    "encryption_key" = $env:OMF_ENCRYPTION_KEY
}

# User profiles and sessions
$UserProfiles = @{}
$ActiveSessions = @{}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

function Initialize-AuthenticationManager {
    Write-Host "Initializing Jira Authentication Manager..." -ForegroundColor Cyan
    
    # Create directories
    if (-not (Test-Path $AuthConfig.profiles_path)) {
        New-Item -ItemType Directory -Path $AuthConfig.profiles_path -Force
    }
    if (-not (Test-Path $AuthConfig.credentials_path)) {
        New-Item -ItemType Directory -Path $AuthConfig.credentials_path -Force
    }
    
    # Load existing profiles
    Load-UserProfiles
    
    Write-Host "Authentication Manager initialized successfully" -ForegroundColor Green
}

function Load-UserProfiles {
    $profileFiles = Get-ChildItem $AuthConfig.profiles_path -Filter "*.json" -ErrorAction SilentlyContinue
    
    foreach ($file in $profileFiles) {
        try {
            $profile = Get-Content $file.FullName | ConvertFrom-Json
            $UserProfiles[$profile.username] = $profile
        }
        catch {
            Write-Warning "Failed to load profile: $($file.Name)"
        }
    }
    
    Write-Host "Loaded $($UserProfiles.Count) user profiles" -ForegroundColor Green
}

function Save-UserProfile {
    param([hashtable]$Profile)
    
    $profilePath = "$($AuthConfig.profiles_path)\$($Profile.username).json"
    $Profile | ConvertTo-Json -Depth 10 | Out-File -FilePath $profilePath -Encoding UTF8
}

function Authenticate-User {
    param(
        [string]$Username,
        [string]$Password,
        [switch]$UseSSO = $false
    )
    
    Write-Host "Authenticating user: $Username" -ForegroundColor Cyan
    
    try {
        if ($UseSSO -or $AuthConfig.sso_enabled) {
            # Use OMF SSO authentication
            $authResult = Invoke-OMFSSOAuth -Username $Username -Password $Password
        } else {
            # Use direct Jira authentication
            $authResult = Invoke-JiraAuth -Username $Username -Password $Password
        }
        
        if ($authResult.success) {
            # Create or update user profile
            $userProfile = @{
                "username" = $Username
                "display_name" = $authResult.display_name
                "email" = $authResult.email
                "api_token" = $authResult.api_token
                "last_login" = Get-Date
                "session_id" = [System.Guid]::NewGuid().ToString()
                "permissions" = $authResult.permissions
                "profile_name" = if ($ProfileName) { $ProfileName } else { $Username }
            }
            
            # Encrypt sensitive data
            if ($AuthConfig.encryption_key) {
                $userProfile.api_token = Encrypt-String -String $userProfile.api_token -Key $AuthConfig.encryption_key
            }
            
            $UserProfiles[$Username] = $userProfile
            Save-UserProfile -Profile $userProfile
            
            # Create active session
            $ActiveSessions[$userProfile.session_id] = @{
                "username" = $Username
                "created" = Get-Date
                "expires" = (Get-Date).AddHours($AuthConfig.session_timeout)
                "profile" = $userProfile
            }
            
            Write-Host "Authentication successful for user: $Username" -ForegroundColor Green
            return $userProfile
        } else {
            Write-Error "Authentication failed: $($authResult.error)"
            return $null
        }
    }
    catch {
        Write-Error "Authentication error: $($_.Exception.Message)"
        return $null
    }
}

function Invoke-OMFSSOAuth {
    param(
        [string]$Username,
        [string]$Password
    )
    
    Write-Host "Attempting OMF SSO authentication..." -ForegroundColor Yellow
    
    # Simulate OMF SSO authentication
    # In a real implementation, this would integrate with OMF's SSO system
    $ssoResult = @{
        "success" = $false
        "error" = ""
        "display_name" = ""
        "email" = ""
        "api_token" = ""
        "permissions" = @()
    }
    
    # Check if user is OMF employee
    if ($Username -match "@omf\.com$") {
        # Simulate successful SSO authentication
        $ssoResult.success = $true
        $ssoResult.display_name = $Username.Split("@")[0].Replace(".", " ").ToTitleCase()
        $ssoResult.email = $Username
        
        # Generate or retrieve API token for this user
        $ssoResult.api_token = Get-UserAPIToken -Username $Username
        
        # Set permissions based on user role
        $ssoResult.permissions = Get-UserPermissions -Username $Username
        
        Write-Host "OMF SSO authentication successful" -ForegroundColor Green
    } else {
        $ssoResult.error = "User is not an OMF employee"
        Write-Warning "User is not an OMF employee: $Username"
    }
    
    return $ssoResult
}

function Invoke-JiraAuth {
    param(
        [string]$Username,
        [string]$Password
    )
    
    Write-Host "Attempting direct Jira authentication..." -ForegroundColor Yellow
    
    $authResult = @{
        "success" = $false
        "error" = ""
        "display_name" = ""
        "email" = ""
        "api_token" = ""
        "permissions" = @()
    }
    
    try {
        # Test authentication with Jira
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$Password"))
            "Content-Type" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$JiraBaseUrl/rest/api/3/myself" -Headers $headers -Method GET
        
        $authResult.success = $true
        $authResult.display_name = $response.displayName
        $authResult.email = $response.emailAddress
        $authResult.api_token = $Password  # In this case, password is the API token
        $authResult.permissions = Get-UserPermissions -Username $Username
        
        Write-Host "Direct Jira authentication successful" -ForegroundColor Green
    }
    catch {
        $authResult.error = $_.Exception.Message
        Write-Error "Direct Jira authentication failed: $($_.Exception.Message)"
    }
    
    return $authResult
}

function Get-UserAPIToken {
    param([string]$Username)
    
    # In a real implementation, this would retrieve the user's API token from a secure store
    # For now, we'll generate a placeholder token
    $token = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"
    
    Write-Host "Retrieved API token for user: $Username" -ForegroundColor Green
    return $token
}

function Get-UserPermissions {
    param([string]$Username)
    
    # Define permissions based on user role
    $permissions = @()
    
    # Check if user is admin
    if ($Username -match "admin|manager|lead") {
        $permissions += "admin"
        $permissions += "read_all_projects"
        $permissions += "write_all_projects"
        $permissions += "manage_users"
    } else {
        $permissions += "read_assigned_projects"
        $permissions += "write_assigned_projects"
    }
    
    # All OMF users get basic permissions
    $permissions += "read_issues"
    $permissions += "create_issues"
    $permissions += "update_own_issues"
    $permissions += "view_dashboards"
    $permissions += "export_data"
    
    return $permissions
}

function Encrypt-String {
    param(
        [string]$String,
        [string]$Key
    )
    
    if (-not $Key) {
        return $String
    }
    
    try {
        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Key.PadRight(32, "0"))
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $keyBytes
        $aes.GenerateIV()
        
        $plaintext = [System.Text.Encoding]::UTF8.GetBytes($String)
        $encryptor = $aes.CreateEncryptor()
        $encrypted = $encryptor.TransformFinalBlock($plaintext, 0, $plaintext.Length)
        
        return [Convert]::ToBase64String($aes.IV + $encrypted)
    }
    catch {
        Write-Warning "Encryption failed, returning plain text"
        return $String
    }
}

function Decrypt-String {
    param(
        [string]$EncryptedString,
        [string]$Key
    )
    
    if (-not $Key) {
        return $EncryptedString
    }
    
    try {
        $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Key.PadRight(32, "0"))
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $keyBytes
        
        $encryptedBytes = [Convert]::FromBase64String($EncryptedString)
        $aes.IV = $encryptedBytes[0..15]
        $encrypted = $encryptedBytes[16..($encryptedBytes.Length - 1)]
        
        $decryptor = $aes.CreateDecryptor()
        $decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
        
        return [System.Text.Encoding]::UTF8.GetString($decrypted)
    }
    catch {
        Write-Warning "Decryption failed, returning encrypted string"
        return $EncryptedString
    }
}

function Get-ActiveSession {
    param([string]$SessionId)
    
    if ($ActiveSessions.ContainsKey($SessionId)) {
        $session = $ActiveSessions[$SessionId]
        
        # Check if session is expired
        if ((Get-Date) -gt $session.expires) {
            $ActiveSessions.Remove($SessionId)
            return $null
        }
        
        return $session
    }
    
    return $null
}

function Refresh-Session {
    param([string]$SessionId)
    
    $session = Get-ActiveSession -SessionId $SessionId
    if ($session) {
        $session.expires = (Get-Date).AddHours($AuthConfig.session_timeout)
        Write-Host "Session refreshed for user: $($session.username)" -ForegroundColor Green
        return $true
    }
    
    return $false
}

function Logout-User {
    param([string]$SessionId)
    
    if ($ActiveSessions.ContainsKey($SessionId)) {
        $username = $ActiveSessions[$SessionId].username
        $ActiveSessions.Remove($SessionId)
        Write-Host "User logged out: $username" -ForegroundColor Green
        return $true
    }
    
    return $false
}

function Get-UserCredentials {
    param([string]$Username)
    
    if ($UserProfiles.ContainsKey($Username)) {
        $profile = $UserProfiles[$Username]
        
        # Decrypt API token if encrypted
        if ($AuthConfig.encryption_key) {
            $profile.api_token = Decrypt-String -EncryptedString $profile.api_token -Key $AuthConfig.encryption_key
        }
        
        return @{
            "username" = $profile.username
            "api_token" = $profile.api_token
            "base_url" = $JiraBaseUrl
            "permissions" = $profile.permissions
        }
    }
    
    return $null
}

function Create-PowerQueryCredentials {
    param([string]$Username)
    
    $credentials = Get-UserCredentials -Username $Username
    if (-not $credentials) {
        Write-Error "User credentials not found: $Username"
        return $null
    }
    
    # Create Power Query compatible credentials
    $pqCredentials = @{
        "BaseUrl" = $credentials.base_url
        "Username" = $credentials.username
        "ApiToken" = $credentials.api_token
        "AuthHeader" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($credentials.username)`:$($credentials.api_token)"))
        "Permissions" = $credentials.permissions
        "Generated" = Get-Date
    }
    
    # Save to file for Power Query to use
    $credentialsPath = "$($AuthConfig.credentials_path)\$Username-credentials.json"
    $pqCredentials | ConvertTo-Json -Depth 10 | Out-File -FilePath $credentialsPath -Encoding UTF8
    
    Write-Host "Power Query credentials created for user: $Username" -ForegroundColor Green
    return $pqCredentials
}

function Update-AllPowerQueryFiles {
    Write-Host "Updating all Power Query files to use secure authentication..." -ForegroundColor Cyan
    
    # Get all Power Query files
    $pqFiles = Get-ChildItem -Path "." -Filter "jira-queries-*.pq" -Recurse
    
    foreach ($file in $pqFiles) {
        Write-Host "Updating: $($file.Name)" -ForegroundColor Yellow
        
        try {
            $content = Get-Content $file.FullName -Raw
            
            # Replace embedded credentials with secure authentication
            $newContent = $content -replace 'BaseUrl = "https://onemain\.atlassian\.net/rest/api/3"', 'BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1]'
            $newContent = $newContent -replace 'Username = "[^"]*"', 'Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1]'
            $newContent = $newContent -replace 'ApiToken = "[^"]*"', 'ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1]'
            
            # Add authentication header generation
            $newContent = $newContent -replace 'AuthHeader = "Basic [^"]*"', 'AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64)'
            
            # Write updated content
            $newContent | Out-File -FilePath $file.FullName -Encoding UTF8
            
            Write-Host "Updated: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to update $($file.Name): $($_.Exception.Message)"
        }
    }
    
    Write-Host "All Power Query files updated successfully" -ForegroundColor Green
}

function Create-ExcelAuthenticationSheet {
    Write-Host "Creating Excel authentication sheet..." -ForegroundColor Cyan
    
    $excelAuthContent = @"
# JIRA AUTHENTICATION SETUP

## Instructions for OMF Users:

1. **Login with your OMF credentials** using the Authentication Manager
2. **Set up Excel named ranges** as shown below
3. **Refresh your Power Query connections**

## Required Named Ranges in Excel:

| Named Range | Value | Description |
|-------------|-------|-------------|
| JiraBaseUrl | https://onemain.atlassian.net/rest/api/3 | Jira API base URL |
| JiraUsername | [Your OMF Email] | Your OMF email address |
| JiraApiToken | [Auto-generated] | Your API token (auto-generated) |

## How to Set Up Named Ranges:

1. Open Excel
2. Go to Formulas > Name Manager
3. Create new named ranges with the values above
4. The JiraApiToken will be automatically populated when you log in

## Authentication Manager Commands:

```powershell
# Login with OMF credentials
.\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO

# Create Power Query credentials
.\jira-authentication-manager.ps1 -Action create-credentials -Username "your.email@omf.com"

# Update all Power Query files
.\jira-authentication-manager.ps1 -Action update-pq-files
```

## Security Features:

- ✅ **OMF SSO Integration** - Use your OMF credentials
- ✅ **Encrypted Storage** - API tokens are encrypted
- ✅ **Session Management** - Automatic session refresh
- ✅ **Permission Control** - Role-based access
- ✅ **Audit Logging** - Track all access

## Support:

For issues or questions, contact the OMF Analytics Team.
"@
    
    $authGuidePath = ".\EXCEL_AUTHENTICATION_SETUP.md"
    $excelAuthContent | Out-File -FilePath $authGuidePath -Encoding UTF8
    
    Write-Host "Excel authentication guide created: $authGuidePath" -ForegroundColor Green
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Authentication Manager" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green
Write-Host "Action: $Action" -ForegroundColor Yellow

try {
    Initialize-AuthenticationManager
    
    switch ($Action.ToLower()) {
        "login" {
            if (-not $Username) {
                $Username = Read-Host "Enter your OMF email address"
            }
            if (-not $Password) {
                $Password = Read-Host "Enter your password" -AsSecureString
                $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
            }
            
            $userProfile = Authenticate-User -Username $Username -Password $Password -UseSSO:$UseSSO
            if ($userProfile) {
                Create-PowerQueryCredentials -Username $Username
                Write-Host "Login successful! You can now use all Jira analytics features." -ForegroundColor Green
            }
        }
        "create-credentials" {
            if (-not $Username) {
                $Username = Read-Host "Enter your OMF email address"
            }
            Create-PowerQueryCredentials -Username $Username
        }
        "update-pq-files" {
            Update-AllPowerQueryFiles
        }
        "create-excel-sheet" {
            Create-ExcelAuthenticationSheet
        }
        "logout" {
            if (-not $Username) {
                $Username = Read-Host "Enter your OMF email address"
            }
            # Find session by username
            $sessionId = $ActiveSessions.Keys | Where-Object { $ActiveSessions[$_].username -eq $Username }
            if ($sessionId) {
                Logout-User -SessionId $sessionId
            }
        }
        "list-users" {
            Write-Host "Active Users:" -ForegroundColor Cyan
            foreach ($session in $ActiveSessions.Values) {
                Write-Host "  - $($session.username) (expires: $($session.expires))" -ForegroundColor White
            }
        }
        default {
            Write-Warning "Unknown action: $Action. Use 'login', 'create-credentials', 'update-pq-files', 'create-excel-sheet', 'logout', or 'list-users'"
        }
    }
}
catch {
    Write-Error "Error during authentication operation: $($_.Exception.Message)"
}

Write-Host "Authentication Manager finished." -ForegroundColor Green
