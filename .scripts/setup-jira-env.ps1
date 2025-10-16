# Setup script for Jira API environment variables
# Run this once to configure your environment

Write-Host "=== Jira API Environment Setup ===" -ForegroundColor Cyan
Write-Host ""

# Get username
$currentUsername = $env:JIRA_USERNAME
if ($currentUsername) {
    Write-Host "Current JIRA_USERNAME: $currentUsername" -ForegroundColor Green
    $changeUsername = Read-Host "Change username? (y/N)"
    if ($changeUsername -eq 'y' -or $changeUsername -eq 'Y') {
        $newUsername = Read-Host "Enter your Jira username (email)"
        $env:JIRA_USERNAME = $newUsername
        [Environment]::SetEnvironmentVariable("JIRA_USERNAME", $newUsername, "User")
        Write-Host "Username updated!" -ForegroundColor Green
    }
} else {
    $username = Read-Host "Enter your Jira username (email)"
    $env:JIRA_USERNAME = $username
    [Environment]::SetEnvironmentVariable("JIRA_USERNAME", $username, "User")
    Write-Host "Username set!" -ForegroundColor Green
}

Write-Host ""

# Get API token
$currentToken = $env:JIRA_API_TOKEN
if ($currentToken) {
    Write-Host "JIRA_API_TOKEN is already set" -ForegroundColor Green
    $changeToken = Read-Host "Change API token? (y/N)"
    if ($changeToken -eq 'y' -or $changeToken -eq 'Y') {
        $newToken = Read-Host "Enter your Jira API token" -AsSecureString
        $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($newToken))
        $env:JIRA_API_TOKEN = $plainToken
        [Environment]::SetEnvironmentVariable("JIRA_API_TOKEN", $plainToken, "User")
        Write-Host "API token updated!" -ForegroundColor Green
    }
} else {
    Write-Host "Get your API token from: https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Yellow
    $token = Read-Host "Enter your Jira API token" -AsSecureString
    $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
    $env:JIRA_API_TOKEN = $plainToken
    [Environment]::SetEnvironmentVariable("JIRA_API_TOKEN", $plainToken, "User")
    Write-Host "API token set!" -ForegroundColor Green
}

Write-Host ""

# Get base URL (optional)
$currentBaseUrl = $env:JIRA_BASE_URL
if ($currentBaseUrl) {
    Write-Host "Current JIRA_BASE_URL: $currentBaseUrl" -ForegroundColor Green
    $changeBaseUrl = Read-Host "Change base URL? (y/N)"
    if ($changeBaseUrl -eq 'y' -or $changeBaseUrl -eq 'Y') {
        $newBaseUrl = Read-Host "Enter Jira base URL (default: https://onemain.atlassian.net/rest/api/3)"
        if ($newBaseUrl) {
            $env:JIRA_BASE_URL = $newBaseUrl
            [Environment]::SetEnvironmentVariable("JIRA_BASE_URL", $newBaseUrl, "User")
            Write-Host "Base URL updated!" -ForegroundColor Green
        }
    }
} else {
    $baseUrl = Read-Host "Enter Jira base URL (default: https://onemain.atlassian.net/rest/api/3)"
    if ($baseUrl) {
        $env:JIRA_BASE_URL = $baseUrl
        [Environment]::SetEnvironmentVariable("JIRA_BASE_URL", $baseUrl, "User")
        Write-Host "Base URL set!" -ForegroundColor Green
    } else {
        Write-Host "Using default base URL: https://onemain.atlassian.net/rest/api/3" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== Setup Complete! ===" -ForegroundColor Cyan
Write-Host "Environment variables are now set for this session and permanently for your user account." -ForegroundColor Green
Write-Host ""
Write-Host "Test your setup with:" -ForegroundColor Yellow
Write-Host "  .\jira-quick-env.ps1 'workflow'" -ForegroundColor White
Write-Host "  .\jira-api-env.ps1 -Endpoint 'project'" -ForegroundColor White
