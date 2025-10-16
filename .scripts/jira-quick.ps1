# Quick Jira API Call Script
# Usage: .\jira-quick.ps1 "workflow"
#        .\jira-quick.ps1 "issue/PROJ-123"

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint
)

$username = "ben.kreischer.ce@omf.com"
$baseUrl = "https://onemain.atlassian.net/rest/api/3"

# Get API token
$apiToken = Read-Host "Enter your Jira API token" -AsSecureString
$plainToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apiToken))

# Create auth header
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username, $plainToken)))
$headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}

# Make the call
$fullUrl = "$baseUrl/$Endpoint"
Write-Host "Calling: $fullUrl" -ForegroundColor Green

try {
    $result = Invoke-RestMethod -Uri $fullUrl -Method GET -Headers $headers
    $result | ConvertTo-Json -Depth 10
} catch {
    Write-Error "Failed: $($_.Exception.Message)"
}
