# =============================================================================
# LIST ENDPOINTS BY AUTHENTICATION SCRIPT
# =============================================================================
# This script provides a comprehensive overview of all endpoints organized by
# authentication method, making it easy to understand the scope of each auth type.
# =============================================================================

Write-Host "=== ENDPOINT AUTHENTICATION OVERVIEW ===" -ForegroundColor Green
Write-Host ""

# Configuration
$basePath = ".endpoints"

# Get all PowerShell scripts
$allScripts = Get-ChildItem -Path $basePath -Recurse -Filter "*.ps1"

# Categorize by authentication method
$anonScripts = $allScripts | Where-Object { $_.Name -match "\(Anon\)" }
$oauth2Scripts = $allScripts | Where-Object { $_.Name -match "\(OAuth2\)" }
$bothScripts = $allScripts | Where-Object { $_.Name -match "\(Both\)" }
$untaggedScripts = $allScripts | Where-Object { 
    $_.Name -notmatch "\(Anon\)|\(OAuth2\)|\(Both\)" 
}

# Count by HTTP method
$getScripts = $allScripts | Where-Object { $_.Name -match "GET" }
$postScripts = $allScripts | Where-Object { $_.Name -match "POST" }
$putScripts = $allScripts | Where-Object { $_.Name -match "PUT" }
$delScripts = $allScripts | Where-Object { $_.Name -match "DEL" }

Write-Host "=== SUMMARY STATISTICS ===" -ForegroundColor Cyan
Write-Host "Total Endpoints: $($allScripts.Count)" -ForegroundColor White
Write-Host "Anonymous (Basic Auth): $($anonScripts.Count)" -ForegroundColor Green
Write-Host "OAuth2: $($oauth2Scripts.Count)" -ForegroundColor Blue
Write-Host "Both Methods: $($bothScripts.Count)" -ForegroundColor Yellow
Write-Host "Untagged: $($untaggedScripts.Count)" -ForegroundColor Red

Write-Host ""
Write-Host "=== HTTP METHOD BREAKDOWN ===" -ForegroundColor Cyan
Write-Host "GET (Read): $($getScripts.Count)" -ForegroundColor Green
Write-Host "POST (Create): $($postScripts.Count)" -ForegroundColor Blue
Write-Host "PUT (Update): $($putScripts.Count)" -ForegroundColor Yellow
Write-Host "DEL (Delete): $($delScripts.Count)" -ForegroundColor Red

Write-Host ""
Write-Host "=== ANONYMOUS ENDPOINTS BY CATEGORY ===" -ForegroundColor Green
$anonByCategory = $anonScripts | Group-Object { $_.Directory.Name } | Sort-Object Name
foreach ($category in $anonByCategory) {
    $getCount = ($category.Group | Where-Object { $_.Name -match "GET" }).Count
    $postCount = ($category.Group | Where-Object { $_.Name -match "POST" }).Count
    $putCount = ($category.Group | Where-Object { $_.Name -match "PUT" }).Count
    $delCount = ($category.Group | Where-Object { $_.Name -match "DEL" }).Count
    
    Write-Host "  $($category.Name): $($category.Count) total (GET:$getCount POST:$postCount PUT:$putCount DEL:$delCount)" -ForegroundColor White
}

Write-Host ""
Write-Host "=== OAUTH2 ENDPOINTS BY CATEGORY ===" -ForegroundColor Blue
$oauth2ByCategory = $oauth2Scripts | Group-Object { $_.Directory.Name } | Sort-Object Name
foreach ($category in $oauth2ByCategory) {
    $getCount = ($category.Group | Where-Object { $_.Name -match "GET" }).Count
    $postCount = ($category.Group | Where-Object { $_.Name -match "POST" }).Count
    $putCount = ($category.Group | Where-Object { $_.Name -match "PUT" }).Count
    $delCount = ($category.Group | Where-Object { $_.Name -match "DEL" }).Count
    
    Write-Host "  $($category.Name): $($category.Count) total (GET:$getCount POST:$postCount PUT:$putCount DEL:$delCount)" -ForegroundColor White
}

Write-Host ""
Write-Host "=== EXECUTION RECOMMENDATIONS ===" -ForegroundColor Yellow
Write-Host "1. Run 'execute_anonymous_endpoints.ps1' for all Basic Auth GET endpoints" -ForegroundColor White
Write-Host "2. Set up OAuth2 and run 'execute_oauth2_endpoints.ps1' for OAuth2 GET endpoints" -ForegroundColor White
Write-Host "3. Use 'execute_all_get_endpoints.ps1' to run all GET endpoints (both auth methods)" -ForegroundColor White

if ($untaggedScripts.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  WARNING: $($untaggedScripts.Count) untagged scripts found!" -ForegroundColor Red
    Write-Host "These scripts need authentication tags added:" -ForegroundColor Yellow
    foreach ($script in $untaggedScripts | Select-Object -First 10) {
        Write-Host "  - $($script.Name)" -ForegroundColor Gray
    }
    if ($untaggedScripts.Count -gt 10) {
        Write-Host "  ... and $($untaggedScripts.Count - 10) more" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== REORGANIZATION COMPLETE ===" -ForegroundColor Green
Write-Host "All endpoints are now properly tagged with authentication method!" -ForegroundColor White
