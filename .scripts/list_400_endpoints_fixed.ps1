# List 400 Bad Request Endpoints from Previous Run
Write-Host "=== 400 BAD REQUEST ENDPOINTS ===" -ForegroundColor Red
Write-Host "These endpoints need specific parameters:" -ForegroundColor Yellow

$badRequestEndpoints = @(
    @{ "Script" = "User Properties - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "API_Path" = "user" },
    @{ "Script" = "User Properties - GET User Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "API_Path" = "user" },
    @{ "Script" = "User Search - GET User Search (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "API_Path" = "user/search" },
    @{ "Script" = "User Search - GET User Search by Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "API_Path" = "user/search" },
    @{ "Script" = "User Search - GET User Search by Username (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "API_Path" = "user/search" },
    @{ "Script" = "Users - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "API_Path" = "user" }
)

foreach ($endpoint in $badRequestEndpoints) {
    Write-Host "`n📋 $($endpoint.Script)" -ForegroundColor Cyan
    Write-Host "   Endpoint: $($endpoint.Endpoint)" -ForegroundColor White
    Write-Host "   API Path: $($endpoint.API_Path)" -ForegroundColor Gray
    Write-Host "   Required Parameters:" -ForegroundColor Yellow
    Write-Host "     - username (for /rest/api/3/user)" -ForegroundColor Green
    Write-Host "     - query (for /rest/api/3/user/search)" -ForegroundColor Green
}

Write-Host "`nTotal 400 Bad Request endpoints: $($badRequestEndpoints.Count)" -ForegroundColor Red
Write-Host "`nThese endpoints require specific parameters:" -ForegroundColor Yellow
Write-Host "1. /rest/api/3/user - requires username parameter" -ForegroundColor Green
Write-Host "2. /rest/api/3/user/search - requires query parameter" -ForegroundColor Green
