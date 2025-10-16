# Remove All Limiters from Endpoint Files
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Removing all limiters from endpoint files..." -ForegroundColor Green

$pqFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.pq"

foreach ($file in $pqFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $changesMade = $false
        
        Write-Host "Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Remove maxResults parameters
        if ($content -match 'maxResults\s*=\s*[^,\n]+') {
            $content = $content -replace 'maxResults\s*=\s*[^,\n]+', 'maxResults = 2147483647'
            $changesMade = $true
        }
        
        # Remove limit parameters
        if ($content -match 'limit\s*=\s*[^,\n]+') {
            $content = $content -replace 'limit\s*=\s*[^,\n]+', 'limit = 2147483647'
            $changesMade = $true
        }
        
        # Remove startAt parameters
        if ($content -match 'startAt\s*=\s*[^,\n]+') {
            $content = $content -replace 'startAt\s*=\s*[^,\n]+', 'startAt = 0'
            $changesMade = $true
        }
        
        # Remove MaxResults parameters
        if ($content -match 'MaxResults\s*=\s*[^,\n]+') {
            $content = $content -replace 'MaxResults\s*=\s*[^,\n]+', 'MaxResults = 2147483647'
            $changesMade = $true
        }
        
        # Remove Limit parameters
        if ($content -match 'Limit\s*=\s*[^,\n]+') {
            $content = $content -replace 'Limit\s*=\s*[^,\n]+', 'Limit = 2147483647'
            $changesMade = $true
        }
        
        # Remove StartAt parameters
        if ($content -match 'StartAt\s*=\s*[^,\n]+') {
            $content = $content -replace 'StartAt\s*=\s*[^,\n]+', 'StartAt = 0'
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

Write-Host "Files processed: $($pqFiles.Count)" -ForegroundColor Green
Write-Host "Files updated: $fixedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
