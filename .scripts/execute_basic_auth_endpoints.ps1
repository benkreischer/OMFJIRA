# Execute Basic Authentication Endpoints Only
# This script executes all GET endpoints that use Basic Authentication (API Token)
# OAuth2 endpoints are skipped since OAuth2 setup is not configured

Write-Host "=== EXECUTING BASIC AUTH ENDPOINTS - GENERATING LIVE CSV FILES ===" -ForegroundColor Green
Write-Host "This will execute all GET endpoints that use Basic Authentication" -ForegroundColor Yellow
Write-Host "OAuth2 endpoints are skipped (require OAuth2 setup)" -ForegroundColor Yellow

# Get all GET PowerShell scripts, excluding OAuth2 folders
$getScripts = Get-ChildItem -Path ".endpoints" -Recurse -Filter "*GET*.ps1" | 
    Where-Object { 
        $_.FullName -notlike "*OAuth2*" -and 
        $_.FullName -notlike "*Enterprise Features (OAuth2)*" -and
        $_.FullName -notlike "*Audit & Compliance (OAuth2)*" -and
        $_.FullName -notlike "*Advanced Workflows (OAuth2)*" -and
        $_.FullName -notlike "*Advanced Security (OAuth2)*" -and
        $_.FullName -notlike "*Advanced Permissions (OAuth2)*" -and
        $_.FullName -notlike "*Advanced Analytics (OAuth2)*" -and
        $_.FullName -notlike "*Integration Management (OAuth2)*"
    } | 
    Sort-Object FullName

Write-Host "Found $($getScripts.Count) Basic Auth GET PowerShell scripts to execute" -ForegroundColor Cyan

$successCount = 0
$errorCount = 0
$skippedCount = 0

foreach ($script in $getScripts) {
    $scriptName = $script.BaseName
    $scriptPath = $script.FullName
    $scriptNumber = $successCount + $errorCount + $skippedCount + 1
    
    Write-Host ""
    Write-Host "[$scriptNumber/$($getScripts.Count)] Executing: $scriptName" -ForegroundColor White
    
    try {
        # Change to the script's directory to ensure CSV files are created in the right location
        $scriptDir = $script.Directory.FullName
        Push-Location $scriptDir
        
        # Execute the script
        $result = & $scriptPath 2>&1
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "  SUCCESS: $scriptName" -ForegroundColor Green
            
            # Check if CSV was created
            $csvFile = Join-Path $scriptDir "$scriptName.csv"
            if (Test-Path $csvFile) {
                $csvLines = (Get-Content $csvFile | Measure-Object -Line).Lines
                Write-Host "    Generated CSV with $csvLines lines" -ForegroundColor Gray
            }
            
            $successCount++
        } else {
            Write-Host "  ERROR: $scriptName (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            $errorCount++
        }
        
    } catch {
        Write-Host "  ERROR: $scriptName - $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Green
Write-Host "Total Scripts: $($getScripts.Count)" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow

if ($errorCount -gt 0) {
    Write-Host ""
    Write-Host "Some endpoints failed. This is normal for:" -ForegroundColor Yellow
    Write-Host "- Endpoints requiring specific parameters" -ForegroundColor Gray
    Write-Host "- Endpoints not available in your Jira instance" -ForegroundColor Gray
    Write-Host "- Endpoints requiring additional permissions" -ForegroundColor Gray
}

Write-Host ""
Write-Host "OAuth2 endpoints were skipped because OAuth2 setup is not configured." -ForegroundColor Cyan
Write-Host "To use OAuth2 endpoints, you need to:" -ForegroundColor Cyan
Write-Host "1. Create an OAuth2 app in Jira Administration" -ForegroundColor Gray
Write-Host "2. Configure Client ID and Client Secret" -ForegroundColor Gray
Write-Host "3. Implement OAuth2 authorization flow" -ForegroundColor Gray
Write-Host "4. Set up token management and refresh" -ForegroundColor Gray

Write-Host ""
Write-Host "Execution completed!" -ForegroundColor Green