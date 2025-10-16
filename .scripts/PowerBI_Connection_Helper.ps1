# Power BI Connection Script
# This script helps you create Power BI connections to Jira API endpoints

Write-Host "=== POWER BI JIRA API CONNECTIONS ===" -ForegroundColor Green

# Define endpoints
$Endpoints = @(
    @{Name="Projects"; URL="/rest/api/3/project/ORL?expand=lead,description,issueTypes,url,projectKeys,permissions,insight"},
    @{Name="All Projects"; URL="/rest/api/3/project/search?expand=lead,description,issueTypes,url,projectKeys,permissions,insight"},
    @{Name="Issues"; URL="/rest/api/3/issue/ORL-8004"},
    @{Name="Issue Fields"; URL="/rest/api/3/field"},
    @{Name="Users"; URL="/rest/api/3/users/search"},
    @{Name="Statuses"; URL="/rest/api/3/status"},
    @{Name="Priorities"; URL="/rest/api/3/priority"}
)

$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "[YOUR_API_TOKEN]"

Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host "Username: $Username" -ForegroundColor Yellow
Write-Host ""
Write-Host "Power BI Connection URLs:" -ForegroundColor Cyan

foreach ($Endpoint in $Endpoints) {
    $FullUrl = $BaseUrl + $Endpoint.URL
    Write-Host "$Endpoint.Name : $FullUrl" -ForegroundColor White
}

Write-Host ""
Write-Host "Instructions:" -ForegroundColor Green
Write-Host "1. Open Power BI Desktop" -ForegroundColor White
Write-Host "2. Go to Home â†’ Get Data â†’ Web" -ForegroundColor White
Write-Host "3. Enter any of the URLs above" -ForegroundColor White
Write-Host "4. Select 'Basic' authentication" -ForegroundColor White
Write-Host "5. Enter username and API token" -ForegroundColor White
Write-Host "6. Click OK to create live connection" -ForegroundColor White
