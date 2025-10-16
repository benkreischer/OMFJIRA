# Remove All Limiters from PowerShell Files
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Removing all limiters from PowerShell files..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Remove any hardcoded limits in PowerShell files
        if ($content -match 'maxResults\s*=\s*[^,\n]+') {
            $content = $content -replace 'maxResults\s*=\s*[^,\n]+', 'maxResults = 2147483647'
            $changesMade = $true
        }
        
        if ($content -match 'limit\s*=\s*[^,\n]+') {
            $content = $content -replace 'limit\s*=\s*[^,\n]+', 'limit = 2147483647'
            $changesMade = $true
        }
        
        if ($content -match 'startAt\s*=\s*[^,\n]+') {
            $content = $content -replace 'startAt\s*=\s*[^,\n]+', 'startAt = 0'
            $changesMade = $true
        }
        
        # Remove any hardcoded page sizes
        if ($content -match '50\s*<\s*Total') {
            $content = $content -replace '50\s*<\s*Total', 'IsLast = false'
            $changesMade = $true
        }
        
        if ($changesMade) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
            $fixedCount++
            Write-Host "  Updated successfully" -ForegroundColor Green
        }
        
    } catch {
        $errorCount++
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "PowerShell files processed: $($ps1Files.Count)" -ForegroundColor Green
Write-Host "PowerShell files updated: $fixedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
