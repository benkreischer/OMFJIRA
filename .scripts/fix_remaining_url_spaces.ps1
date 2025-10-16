# Fix Remaining URL Spaces in PowerShell Files
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing remaining URL spaces in PowerShell files..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix any remaining spaces before ?maxResults in Write-Host statements
        if ($content -match 'Write-Host.*\$BaseUrl.*rest/api/3/[^"]*"\s+\?maxResults') {
            $content = $content -replace '(Write-Host.*\$BaseUrl.*rest/api/3/[^"]*")\s+\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Write-Host URL space" -ForegroundColor Green
        }
        
        # Fix any remaining spaces before ?maxResults in Invoke-RestMethod statements
        if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*"\s+\?maxResults') {
            $content = $content -replace '(Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*")\s+\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Invoke-RestMethod URL space" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with spaces before ?maxResults in Write-Host statements
        if ($content -match 'Write-Host.*"https://[^"]*rest/api/3/[^"]*"\s+\?maxResults') {
            $content = $content -replace '(Write-Host.*"https://[^"]*rest/api/3/[^"]*")\s+\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Write-Host hardcoded URL space" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with spaces before ?maxResults in Invoke-RestMethod statements
        if ($content -match 'Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*"\s+\?maxResults') {
            $content = $content -replace '(Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*")\s+\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed Invoke-RestMethod hardcoded URL space" -ForegroundColor Green
        }
        
        # More aggressive fix - any space before ?maxResults anywhere
        if ($content -match '"\s+\?maxResults') {
            $content = $content -replace '("\s+)(\?maxResults)', '$1$2'
            $content = $content -replace '("\s+)(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed general URL space" -ForegroundColor Green
        }
        
        # Even more aggressive - fix any space before ? in URLs
        if ($content -match 'rest/api/3/[^"]*"\s+\?') {
            $content = $content -replace '(rest/api/3/[^"]*")\s+(\?)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed general URL parameter space" -ForegroundColor Green
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
