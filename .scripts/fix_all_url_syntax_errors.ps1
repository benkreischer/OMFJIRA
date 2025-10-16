# Fix All URL Syntax Errors in PowerShell Files
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing all URL syntax errors in PowerShell files..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix URLs with space before ?maxResults in Write-Host statements
        if ($content -match 'Write-Host.*\$BaseUrl.*rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '(Write-Host.*\$BaseUrl.*rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Write-Host URL syntax" -ForegroundColor Green
        }
        
        # Fix URLs with space before ?maxResults in Invoke-RestMethod statements
        if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '(Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Invoke-RestMethod URL syntax" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with space before ?maxResults in Write-Host statements
        if ($content -match 'Write-Host.*"https://[^"]*rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '(Write-Host.*"https://[^"]*rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Write-Host hardcoded URL syntax" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with space before ?maxResults in Invoke-RestMethod statements
        if ($content -match 'Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '(Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Invoke-RestMethod hardcoded URL syntax" -ForegroundColor Green
        }
        
        # Fix URLs with space before &maxResults
        if ($content -match '\$BaseUrl.*rest/api/3/[^"]*"\s*&maxResults') {
            $content = $content -replace '(\$BaseUrl.*rest/api/3/[^"]*")\s*&maxResults', '$1&maxResults'
            $changesMade = $true
            Write-Host "  Fixed &maxResults syntax" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with space before &maxResults
        if ($content -match '"https://[^"]*rest/api/3/[^"]*"\s*&maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")\s*&maxResults', '$1&maxResults'
            $changesMade = $true
            Write-Host "  Fixed hardcoded &maxResults syntax" -ForegroundColor Green
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
