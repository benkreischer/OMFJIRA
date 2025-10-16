# =============================================================================
# OAUTH2 AUTHENTICATION MANAGER
# =============================================================================
# This script manages OAuth2 authentication for Jira API endpoints
# Handles token acquisition, refresh, and management

param(
    [string]$Action = "setup",  # setup, authorize, refresh, test
    [string]$ConfigFile = "oauth2_config.json"
)

# =============================================================================
# CONFIGURATION
# =============================================================================

function Load-OAuth2Config {
    param([string]$ConfigPath)
    
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "OAuth2 config file not found: $ConfigPath"
        return $null
    }
    
    try {
        $config = Get-Content $ConfigPath | ConvertFrom-Json
        return $config
    } catch {
        Write-Error "Failed to load OAuth2 config: $($_.Exception.Message)"
        return $null
    }
}

function Save-OAuth2Config {
    param([object]$Config, [string]$ConfigPath)
    
    try {
        $Config | ConvertTo-Json -Depth 3 | Set-Content $ConfigPath
        Write-Host "OAuth2 config saved to: $ConfigPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to save OAuth2 config: $($_.Exception.Message)"
    }
}

# =============================================================================
# OAUTH2 FLOW IMPLEMENTATION
# =============================================================================

function Start-OAuth2Authorization {
    param([object]$Config)
    
    Write-Host "=== OAUTH2 AUTHORIZATION SETUP ===" -ForegroundColor Green
    
    # Generate random state for CSRF protection
    $state = [System.Guid]::NewGuid().ToString()
    $Config.oauth2.state = $state
    
    # Build authorization URL
    $authParams = @{
        client_id = $Config.oauth2.client_id
        redirect_uri = $Config.oauth2.redirect_uri
        response_type = "code"
        scope = ($Config.oauth2.scopes -join " ")
        state = $state
    }
    
    $authUrl = $Config.oauth2.authorization_url + "?" + (($authParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join "&")
    
    Write-Host "Authorization URL:" -ForegroundColor Cyan
    Write-Host $authUrl -ForegroundColor White
    Write-Host ""
    Write-Host "Please:" -ForegroundColor Yellow
    Write-Host "1. Open this URL in your browser" -ForegroundColor Gray
    Write-Host "2. Log in to Jira and authorize the application" -ForegroundColor Gray
    Write-Host "3. Copy the authorization code from the callback URL" -ForegroundColor Gray
    Write-Host "4. Run: .\OAuth2_Authentication_Manager.ps1 -Action authorize -Code 'YOUR_CODE'" -ForegroundColor Gray
    
    # Save updated config with state
    Save-OAuth2Config -Config $Config -ConfigPath $ConfigFile
    
    return $authUrl
}

function Complete-OAuth2Authorization {
    param([object]$Config, [string]$AuthorizationCode)
    
    Write-Host "=== COMPLETING OAUTH2 AUTHORIZATION ===" -ForegroundColor Green
    
    # Prepare token request
    $tokenRequest = @{
        grant_type = "authorization_code"
        client_id = $Config.oauth2.client_id
        client_secret = $Config.oauth2.client_secret
        redirect_uri = $Config.oauth2.redirect_uri
        code = $AuthorizationCode
    }
    
    try {
        # Exchange authorization code for tokens
        $response = Invoke-RestMethod -Uri $Config.oauth2.token_url -Method POST -Body $tokenRequest -ContentType "application/x-www-form-urlencoded"
        
        # Store tokens securely
        $Config.oauth2.access_token = $response.access_token
        $Config.oauth2.refresh_token = $response.refresh_token
        $Config.oauth2.token_type = $response.token_type
        $Config.oauth2.expires_in = $response.expires_in
        $Config.oauth2.expires_at = (Get-Date).AddSeconds($response.expires_in).ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        Save-OAuth2Config -Config $Config -ConfigPath $ConfigFile
        
        Write-Host "✓ OAuth2 authorization completed successfully!" -ForegroundColor Green
        Write-Host "Access token expires at: $($Config.oauth2.expires_at)" -ForegroundColor Cyan
        
        return $true
        
    } catch {
        Write-Error "Failed to complete OAuth2 authorization: $($_.Exception.Message)"
        return $false
    }
}

function Refresh-OAuth2Token {
    param([object]$Config)
    
    Write-Host "=== REFRESHING OAUTH2 TOKEN ===" -ForegroundColor Green
    
    if (-not $Config.oauth2.refresh_token) {
        Write-Error "No refresh token available. Please re-authorize."
        return $false
    }
    
    # Prepare refresh request
    $refreshRequest = @{
        grant_type = "refresh_token"
        client_id = $Config.oauth2.client_id
        client_secret = $Config.oauth2.client_secret
        refresh_token = $Config.oauth2.refresh_token
    }
    
    try {
        # Refresh the access token
        $response = Invoke-RestMethod -Uri $Config.oauth2.token_url -Method POST -Body $refreshRequest -ContentType "application/x-www-form-urlencoded"
        
        # Update tokens
        $Config.oauth2.access_token = $response.access_token
        if ($response.refresh_token) {
            $Config.oauth2.refresh_token = $response.refresh_token
        }
        $Config.oauth2.expires_in = $response.expires_in
        $Config.oauth2.expires_at = (Get-Date).AddSeconds($response.expires_in).ToString("yyyy-MM-ddTHH:mm:ssZ")
        
        Save-OAuth2Config -Config $Config -ConfigPath $ConfigFile
        
        Write-Host "✓ OAuth2 token refreshed successfully!" -ForegroundColor Green
        Write-Host "New access token expires at: $($Config.oauth2.expires_at)" -ForegroundColor Cyan
        
        return $true
        
    } catch {
        Write-Error "Failed to refresh OAuth2 token: $($_.Exception.Message)"
        return $false
    }
}

function Test-OAuth2Token {
    param([object]$Config)
    
    Write-Host "=== TESTING OAUTH2 TOKEN ===" -ForegroundColor Green
    
    if (-not $Config.oauth2.access_token) {
        Write-Error "No access token available. Please authorize first."
        return $false
    }
    
    # Check if token is expired
    $expiresAt = [DateTime]::Parse($Config.oauth2.expires_at)
    if ((Get-Date) -gt $expiresAt) {
        Write-Host "Access token is expired. Refreshing..." -ForegroundColor Yellow
        if (-not (Refresh-OAuth2Token -Config $Config)) {
            return $false
        }
    }
    
    try {
        # Test token with /myself endpoint
        $headers = @{
            "Authorization" = "Bearer $($Config.oauth2.access_token)"
            "Accept" = "application/json"
        }
        
        $response = Invoke-RestMethod -Uri "$($Config.jira.base_url)/rest/api/3/myself" -Method GET -Headers $headers
        
        Write-Host "✓ OAuth2 token is valid!" -ForegroundColor Green
        Write-Host "Authenticated as: $($response.displayName) ($($response.emailAddress))" -ForegroundColor Cyan
        
        return $true
        
    } catch {
        Write-Error "OAuth2 token test failed: $($_.Exception.Message)"
        return $false
    }
}

function Get-OAuth2Headers {
    param([object]$Config)
    
    # Check if token is expired and refresh if needed
    $expiresAt = [DateTime]::Parse($Config.oauth2.expires_at)
    if ((Get-Date) -gt $expiresAt) {
        Write-Host "Access token expired. Refreshing..." -ForegroundColor Yellow
        Refresh-OAuth2Token -Config $Config | Out-Null
    }
    
    return @{
        "Authorization" = "Bearer $($Config.oauth2.access_token)"
        "Accept" = "application/json"
        "Content-Type" = "application/json"
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

function Main {
    $config = Load-OAuth2Config -ConfigPath $ConfigFile
    
    if (-not $config) {
        Write-Error "Failed to load OAuth2 configuration"
        return
    }
    
    switch ($Action.ToLower()) {
        "setup" {
            Write-Host "=== OAUTH2 SETUP ===" -ForegroundColor Green
            Write-Host "To set up OAuth2 authentication:" -ForegroundColor Yellow
            Write-Host "1. Create an OAuth2 app in Jira Administration" -ForegroundColor Gray
            Write-Host "2. Update oauth2_config.json with your Client ID and Client Secret" -ForegroundColor Gray
            Write-Host "3. Run: .\OAuth2_Authentication_Manager.ps1 -Action authorize" -ForegroundColor Gray
        }
        
        "authorize" {
            Start-OAuth2Authorization -Config $config
        }
        
        "complete" {
            if (-not $Code) {
                Write-Error "Authorization code required. Use: -Code 'YOUR_CODE'"
                return
            }
            Complete-OAuth2Authorization -Config $config -AuthorizationCode $Code
        }
        
        "refresh" {
            Refresh-OAuth2Token -Config $config
        }
        
        "test" {
            Test-OAuth2Token -Config $config
        }
        
        default {
            Write-Host "Available actions: setup, authorize, complete, refresh, test" -ForegroundColor Yellow
        }
    }
}

# Run main function
Main
