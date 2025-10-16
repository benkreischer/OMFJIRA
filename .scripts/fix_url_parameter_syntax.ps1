# Fix URL Parameter Syntax - Move ?maxResults inside quotes
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing URL parameter syntax..." -ForegroundColor Green

$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Fix URLs where ?maxResults is outside the quotes in Invoke-RestMethod
        if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl/rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '(\$BaseUrl/rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed Invoke-RestMethod URL parameter" -ForegroundColor Green
        }
        
        # Fix URLs where ?maxResults is outside the quotes in Write-Host
        if ($content -match 'Write-Host.*\$BaseUrl/rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '(\$BaseUrl/rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed Write-Host URL parameter" -ForegroundColor Green
        }
        
        # Fix hardcoded URLs where ?maxResults is outside the quotes
        if ($content -match '"https://[^"]*rest/api/3/[^"]*"\?maxResults') {
            $content = $content -replace '("https://[^"]*rest/api/3/[^"]*")(\?maxResults)', '$1$2'
            $changesMade = $true
            Write-Host "  Fixed hardcoded URL parameter" -ForegroundColor Green
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
