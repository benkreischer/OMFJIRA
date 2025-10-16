# Batch fix for easily fixable endpoints
Write-Host "🔧 BATCH FIXING EASILY FIXABLE ENDPOINTS" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green

$FixedCount = 0
$Fixes = @()

# Fix 1: License Metrics endpoints - These might need different paths
Write-Host "`n1. Checking License Metrics endpoints..." -ForegroundColor Yellow
$LicenseFiles = @(
    ".endpoints\License metrics\License Metrics - GET License Limits - Anon - Official.ps1",
    ".endpoints\License metrics\License Metrics - GET License Status - Anon - Official.ps1",
    ".endpoints\License metrics\License Metrics - GET License Usage - Anon - Official.ps1"
)

foreach ($file in $LicenseFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        # These might need simpler paths
        if ($content -match '"/rest/api/3/license/') {
            Write-Host "   Found license endpoint: $file" -ForegroundColor Gray
            $Fixes += "License metrics endpoints might need admin permissions or different paths"
        }
    }
}

# Fix 2: Filter endpoints with missing parameters
Write-Host "`n2. Fixing Filter endpoints..." -ForegroundColor Yellow
$FilterFiles = @(
    ".endpoints\Filters\Filters - GET Share permission - Anon - Official.ps1",
    ".endpoints\Filters\Filters - GET Filter permissions - Anon - Official.ps1"
)

foreach ($file in $FilterFiles) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        # These might need filter IDs
        if ($content -match '/filter/\$' -or $content -match '/filter/"') {
            Write-Host "   Fixing filter endpoint: $(Split-Path $file -Leaf)" -ForegroundColor Green
            $content = $content -replace '/rest/api/3/filter/"', '/rest/api/3/filter/19039'
            $content = $content -replace '/rest/api/3/filter/\$FilterId', '/rest/api/3/filter/19039'
            Set-Content $file -Value $content
            $FixedCount++
        }
    }
}

# Fix 3: Plans endpoint - might need different path
Write-Host "`n3. Checking Plans endpoint..." -ForegroundColor Yellow
$PlansFile = ".endpoints\Plans\Plans - GET Plan - Anon - Official.ps1"
if (Test-Path $PlansFile) {
    $content = Get-Content $PlansFile -Raw
    if ($content -match '/rest/api/3/plan/1') {
        Write-Host "   Plans endpoint uses /plan/1 - might not exist" -ForegroundColor Red
        $Fixes += "Plans endpoint might not exist in standard Jira API"
    }
}

Write-Host "`n📊 BATCH FIX RESULTS:" -ForegroundColor Cyan
Write-Host "Fixes applied: $FixedCount" -ForegroundColor Green
Write-Host "Issues identified: $($Fixes.Count)" -ForegroundColor Yellow

if ($Fixes.Count -gt 0) {
    Write-Host "`nIssues found:" -ForegroundColor Yellow
    foreach ($fix in $Fixes) {
        Write-Host "  - $fix" -ForegroundColor Gray
    }
}

Write-Host "`n✅ Batch fix complete!" -ForegroundColor Green