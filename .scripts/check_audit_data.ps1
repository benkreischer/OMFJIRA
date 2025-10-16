# Check audit data quality
$csv = Import-Csv ".endpoints/Admin Organization/Admin Organization - GET Audit Log Analytics.csv"

Write-Host "=== AUDIT DATA ANALYSIS ===" -ForegroundColor Green
Write-Host "Total users: $($csv.Count)" -ForegroundColor Cyan

$activeUsers = $csv | Where-Object { [int]$_.ActionsPerformedLast30Days -gt 0 }
Write-Host "Users with activity: $($activeUsers.Count)" -ForegroundColor Green

if ($activeUsers.Count -gt 0) {
    Write-Host "Active users:" -ForegroundColor Yellow
    $activeUsers | Select-Object DisplayName, ActionsPerformedLast30Days, LastLogin | Format-Table -AutoSize
}

$usersWithLogins = $csv | Where-Object { [int]$_.LoginCountLast30Days -gt 0 }
Write-Host "Users with login counts: $($usersWithLogins.Count)" -ForegroundColor Cyan

if ($usersWithLogins.Count -gt 0) {
    Write-Host "Sample users with logins:" -ForegroundColor Yellow
    $usersWithLogins | Select-Object DisplayName, LoginCountLast30Days, LastLogin | Select-Object -First 10 | Format-Table -AutoSize
}

$usersWithLastLogin = $csv | Where-Object { $_.LastLogin -ne "" }
Write-Host "Users with last login dates: $($usersWithLastLogin.Count)" -ForegroundColor Green

$inactiveUsers = $csv | Where-Object { $_.LastLogin -eq "" }
Write-Host "Users without last login dates: $($inactiveUsers.Count)" -ForegroundColor Red

Write-Host "=== DATA QUALITY SUMMARY ===" -ForegroundColor Green
Write-Host "Last login coverage: $([math]::Round(($usersWithLastLogin.Count / $csv.Count) * 100, 1))%" -ForegroundColor Cyan
Write-Host "Login count coverage: $([math]::Round(($usersWithLogins.Count / $csv.Count) * 100, 1))%" -ForegroundColor Cyan
Write-Host "Activity coverage: $([math]::Round(($activeUsers.Count / $csv.Count) * 100, 1))%" -ForegroundColor Cyan
