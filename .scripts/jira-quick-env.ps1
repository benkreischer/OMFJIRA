# Quick Jira API Call Script using Environment Variables
# Secure approach - no credentials stored in the script

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint
)

# Get credentials from environment variables
$username = $env:JIRA_USERNAME
$apiToken = $env:JIRA_API_TOKEN
$baseUrl = if ($env:JIRA_BASE_URL) { $env:JIRA_BASE_URL } else { "https://onemain.atlassian.net/rest/api/3" }

# Validate environment variables
if (-not $username) {
    Write-Error "JIRA_USERNAME environment variable not set"
    Write-Host "Set it with: `$env:JIRA_USERNAME = 'your-email@domain.com'" -ForegroundColor Yellow
    exit 1
}

if (-not $apiToken) {
    Write-Error "JIRA_API_TOKEN environment variable not set"
    Write-Host "Set it with: `$env:JIRA_API_TOKEN = 'your-api-token'" -ForegroundColor Yellow
    Write-Host "Get your token from: https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Yellow
    exit 1
}

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $apiToken)))
$headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

# Make the call
$fullUrl = "$baseUrl/$Endpoint"
Write-Host "Calling: $fullUrl" -ForegroundColor Green
Write-Host "Using username: $username" -ForegroundColor Gray

try {
    $result = Invoke-RestMethod -Uri $fullUrl -Method GET -Headers $headers
    $result | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Failed: $($_.Exception.Message)"
}
