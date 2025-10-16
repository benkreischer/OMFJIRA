# OAuth2 Setup Guide for Jira API

## Overview
This guide will help you set up OAuth2 authentication for the advanced Jira API endpoints that require OAuth2 instead of basic authentication.

## Step 1: Create OAuth2 App in Jira

### 1.1 Access Jira Administration
1. Log in to your Jira instance: `https://onemain.atlassian.net`
2. Go to **Administration** (gear icon in top right)
3. Navigate to **Applications** → **OAuth 2.0 (3LO)** → **Add application**

### 1.2 Configure OAuth2 App
Fill in the following details:

- **Application name**: `OneMain Financial API Integration`
- **Description**: `API integration for comprehensive Jira data extraction and analytics`
- **Callback URL**: `http://localhost:8080/callback`
- **Scopes**: Select the following scopes:
  - ✅ `read:jira-work` - Read access to Jira issues, projects, and work items
  - ✅ `write:jira-work` - Write access to create and update Jira issues  
  - ✅ `manage:jira-project` - Manage Jira projects, configurations, and settings
  - ✅ `read:jira-user` - Read access to user information and profiles
  - ✅ `offline_access` - Access to refresh tokens for offline use

### 1.3 Get Credentials
After creating the app, you'll receive:
- **Client ID**: Copy this value
- **Client Secret**: Copy this value (keep it secure!)

## Step 2: Update Configuration

### 2.1 Update oauth2_config.json
Edit the `oauth2_config.json` file and replace the placeholder values:

```json
{
  "oauth2": {
    "client_id": "YOUR_ACTUAL_CLIENT_ID_HERE",
    "client_secret": "YOUR_ACTUAL_CLIENT_SECRET_HERE",
    "redirect_uri": "http://localhost:8080/callback",
    "authorization_url": "https://onemain.atlassian.net/oauth/authorize",
    "token_url": "https://onemain.atlassian.net/oauth/token",
    "scopes": [
      "read:jira-work",
      "write:jira-work", 
      "manage:jira-project",
      "read:jira-user",
      "offline_access"
    ],
    "state": "random_state_string_for_csrf_protection"
  },
  "jira": {
    "base_url": "https://onemain.atlassian.net",
    "api_version": "3"
  }
}
```

## Step 3: Authorize the Application

### 3.1 Start Authorization Process
Run the OAuth2 authentication manager:

```powershell
.\OAuth2_Authentication_Manager.ps1 -Action authorize
```

This will:
1. Generate a secure authorization URL
2. Display the URL in the console
3. Save the state parameter for security

### 3.2 Complete Authorization
1. **Copy the authorization URL** from the console output
2. **Open the URL in your browser**
3. **Log in to Jira** if prompted
4. **Review and approve** the requested permissions
5. **Copy the authorization code** from the callback URL (after `code=`)

### 3.3 Complete the Authorization
Run the completion command with your authorization code:

```powershell
.\OAuth2_Authentication_Manager.ps1 -Action complete -Code "YOUR_AUTHORIZATION_CODE_HERE"
```

## Step 4: Test OAuth2 Authentication

### 4.1 Test the Token
Verify that OAuth2 authentication is working:

```powershell
.\OAuth2_Authentication_Manager.ps1 -Action test
```

You should see:
- ✅ OAuth2 token is valid!
- Authenticated as: [Your Name] ([your-email@omf.com])

### 4.2 Test with API Call
Test a simple API call using OAuth2:

```powershell
$config = Get-Content "oauth2_config.json" | ConvertFrom-Json
$headers = @{
    "Authorization" = "Bearer $($config.oauth2.access_token)"
    "Accept" = "application/json"
}
$response = Invoke-RestMethod -Uri "$($config.jira.base_url)/rest/api/3/myself" -Method GET -Headers $headers
$response | ConvertTo-Json
```

## Step 5: Update OAuth2 Endpoint Scripts

### 5.1 Automatic Update
Once OAuth2 is configured, run the script to update all OAuth2 endpoint scripts:

```powershell
.\Update_OAuth2_Endpoint_Scripts.ps1
```

This will:
- Update all 68 OAuth2 endpoint scripts
- Replace basic authentication with OAuth2 Bearer tokens
- Ensure proper token refresh handling

### 5.2 Manual Verification
Test a few OAuth2 endpoints manually to ensure they work:

```powershell
# Test Enterprise User Management
.\".endpoints\Enterprise Features (OAuth2)\Enterprise Features (OAuth2) - GET Enterprise User Management.ps1"

# Test Advanced Analytics  
.\".endpoints\Advanced Analytics (OAuth2)\Advanced Analytics (OAuth2) - GET Team Performance Analytics.ps1"
```

## Step 6: Execute All Endpoints

### 6.1 Run Complete Test Suite
Execute all endpoints (both Basic Auth and OAuth2):

```powershell
.\execute_all_get_endpoints.ps1
```

This will now execute all 276 GET endpoints:
- 208 Basic Authentication endpoints
- 68 OAuth2 endpoints

### 6.2 Monitor Results
The script will:
- Execute all endpoints in sequence
- Generate CSV files for each endpoint
- Report success/failure statistics
- Handle token refresh automatically

## Troubleshooting

### Common Issues

#### 1. "Invalid Client" Error
- **Cause**: Incorrect Client ID or Client Secret
- **Solution**: Verify credentials in `oauth2_config.json`

#### 2. "Invalid Grant" Error  
- **Cause**: Authorization code expired or already used
- **Solution**: Re-run the authorization process

#### 3. "Insufficient Scope" Error
- **Cause**: Missing required scopes in OAuth2 app
- **Solution**: Update OAuth2 app scopes in Jira Administration

#### 4. "Token Expired" Error
- **Cause**: Access token expired
- **Solution**: The script should auto-refresh, but you can manually refresh:
  ```powershell
  .\OAuth2_Authentication_Manager.ps1 -Action refresh
  ```

#### 5. "Redirect URI Mismatch" Error
- **Cause**: Callback URL doesn't match registered URI
- **Solution**: Update OAuth2 app settings with correct redirect URI

### Getting Help

If you encounter issues:
1. Check the OAuth2 app configuration in Jira Administration
2. Verify the `oauth2_config.json` file has correct values
3. Test the token manually using the test action
4. Check Jira logs for detailed error messages

## Security Best Practices

### 1. Secure Storage
- Never commit `oauth2_config.json` with real credentials to version control
- Store Client Secret securely
- Use environment variables for production deployments

### 2. Token Management
- Access tokens expire automatically (usually 1 hour)
- Refresh tokens are used to get new access tokens
- The script handles token refresh automatically

### 3. Scope Limitation
- Only request the minimum required scopes
- Review and approve scopes carefully during authorization
- Regularly audit OAuth2 app permissions

## Next Steps

After successful OAuth2 setup:
1. ✅ All 276 GET endpoints will be functional
2. ✅ Complete Jira ecosystem data extraction
3. ✅ Advanced enterprise analytics and reporting
4. ✅ Full API coverage for comprehensive business intelligence

The OAuth2 setup enables access to advanced Jira features that provide deeper insights into your organization's project management, security, compliance, and performance metrics.
