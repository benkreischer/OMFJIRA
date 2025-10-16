# Fix URL syntax errors in PowerShell files
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing URL syntax errors in PowerShell files..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix URLs with space before ?maxResults
        if ($content -match '"\$BaseUrl/rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '("\$BaseUrl/rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed space before ?maxResults" -ForegroundColor Green
        }
        
        # Fix URLs with space before &maxResults
        if ($content -match '"\$BaseUrl/rest/api/3/[^"]*"\s*&maxResults') {
            $content = $content -replace '("\$BaseUrl/rest/api/3/[^"]*")\s*&maxResults', '$1&maxResults'
            $changesMade = $true
            Write-Host "  Fixed space before &maxResults" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with space before ?maxResults
        if ($content -match '"https://[^"]*rest/api/3/[^"]*"\s*\?maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")\s*\?maxResults', '$1?maxResults'
            $changesMade = $true
            Write-Host "  Fixed space before ?maxResults in hardcoded URL" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with space before &maxResults
        if ($content -match '"https://[^"]*rest/api/3/[^"]*"\s*&maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")\s*&maxResults', '$1&maxResults'
            $changesMade = $true
            Write-Host "  Fixed space before &maxResults in hardcoded URL" -ForegroundColor Green
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
