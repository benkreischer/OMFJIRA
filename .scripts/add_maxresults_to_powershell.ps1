# Add maxResults parameter to PowerShell API calls
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Adding maxResults parameter to PowerShell API calls..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Add maxResults parameter to API calls that don't have it
        if ($content -match 'Invoke-RestMethod.*rest/api/3/[^"]*"' -and $content -notmatch 'maxResults') {
            # Find the API call and add maxResults parameter
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")', '$1?maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter" -ForegroundColor Green
        }
        
        # Also handle cases where there might already be query parameters
        if ($content -match 'Invoke-RestMethod.*rest/api/3/[^"]*\?[^"]*"' -and $content -notmatch 'maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*\?[^"]*")', '$1&maxResults=2147483647'
            $changesMade = $true
            Write-Host "  Added maxResults parameter to existing query" -ForegroundColor Green
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
