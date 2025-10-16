# Fix Missing Question Marks in URLs
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing missing question marks in URLs..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix URLs where ?maxResults is outside the quotes
        if ($content -match '\$BaseUrl/rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '(\$BaseUrl/rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed missing ? in URL" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs where ?maxResults is outside the quotes
        if ($content -match '"https://[^"]*rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed missing ? in hardcoded URL" -ForegroundColor Green
        }
        
        # More specific fix for the exact pattern we're seeing
        if ($content -match 'rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '(rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed specific URL pattern" -ForegroundColor Green
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
