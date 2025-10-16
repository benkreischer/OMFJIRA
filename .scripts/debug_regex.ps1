# Debug regex extraction
$scriptContent = Get-Content -Path ".endpoints/Users/Users - GET Users (Anon).ps1" -Raw

Write-Host "Script content sample:" -ForegroundColor Yellow
Write-Host $scriptContent.Substring(0, 500) -ForegroundColor Cyan

Write-Host "`nTesting regex patterns:" -ForegroundColor Yellow

# Test different regex patterns
if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"]+)') {
    Write-Host "Pattern 1 matched: $($matches[1])" -ForegroundColor Green
} else {
    Write-Host "Pattern 1 did not match" -ForegroundColor Red
}

if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"?]+)') {
    Write-Host "Pattern 2 matched: $($matches[1])" -ForegroundColor Green
} else {
    Write-Host "Pattern 2 did not match" -ForegroundColor Red
}

if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"]*?)') {
    Write-Host "Pattern 3 matched: $($matches[1])" -ForegroundColor Green
} else {
    Write-Host "Pattern 3 did not match" -ForegroundColor Red
}

# Look for the actual line
$lines = $scriptContent -split "`n"
foreach ($line in $lines) {
    if ($line -match "Invoke-RestMethod.*Uri") {
        Write-Host "Found Invoke-RestMethod line: $line" -ForegroundColor Magenta
        break
    }
}
