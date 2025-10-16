# Fix maxResults parameter in PowerShell API calls
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing maxResults parameter in PowerShell API calls..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix URLs that use variables like $BaseUrl
        if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*"' -and $content -notmatch 'maxResults') {
            # Add maxResults parameter to URLs with variables
            $content = $content -replace '(\$BaseUrl/rest/api/3/[^"]*")', '$1?maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter to variable URL" -ForegroundColor Green
        }
        
        # Fix URLs that already have query parameters
        if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl.*rest/api/3/[^"]*\?[^"]*"' -and $content -notmatch 'maxResults') {
            $content = $content -replace '(\$BaseUrl/rest/api/3/[^"]*\?[^"]*")', '$1&maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter to existing query" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs
        if ($content -match 'Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*"' -and $content -notmatch 'maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")', '$1?maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter to hardcoded URL" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs with existing query parameters
        if ($content -match 'Invoke-RestMethod.*Uri.*"https://[^"]*rest/api/3/[^"]*\?[^"]*"' -and $content -notmatch 'maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*\?[^"]*")', '$1&maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter to hardcoded URL with query" -ForegroundColor Green
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
