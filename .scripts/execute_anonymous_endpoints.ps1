# =============================================================================
# EXECUTE ANONYMOUS ENDPOINTS SCRIPT
# =============================================================================
# This script executes all GET endpoints that use Anonymous (Basic Auth) authentication
# and generates CSV files with live data from the Jira API.
# =============================================================================

Write-Host "=== EXECUTING ANONYMOUS (BASIC AUTH) ENDPOINTS ===" -ForegroundColor Green
Write-Host "Starting execution of all Anonymous GET endpoints..." -ForegroundColor Yellow
Write-Host ""

# Configuration
$basePath = ".endpoints"
$totalScripts = 0
$successfulScripts = 0
$failedScripts = 0
$skippedScripts = 0

# Get all PowerShell scripts with (Anon) in the name
$anonScripts = Get-ChildItem -Path $basePath -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "\(Anon\)" -and $_.Name -match "GET"
}

Write-Host "Found $($anonScripts.Count) Anonymous GET endpoints to execute" -ForegroundColor Cyan
Write-Host ""

# Execute each script
foreach ($script in $anonScripts) {
    $totalScripts++
    $scriptName = $script.Name
    $scriptPath = $script.FullName
    $relativePath = $scriptPath.Replace((Get-Location).Path + "\", "")
    
    Write-Host "[$totalScripts/$($anonScripts.Count)] Executing: $scriptName" -ForegroundColor White
    
    try {
        # Change to the script's directory
        $scriptDir = $script.Directory.FullName
        Push-Location $scriptDir
        
        # Execute the script
        $result = & $scriptPath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ SUCCESS" -ForegroundColor Green
            $successfulScripts++
        } else {
            Write-Host "  ❌ FAILED (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            Write-Host "  Error: $result" -ForegroundColor Red
            $failedScripts++
        }
        
    } catch {
        Write-Host "  ❌ EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
        $failedScripts++
    } finally {
        # Return to original directory
        Pop-Location
    }
    
    Write-Host ""
}

# Summary
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Green
Write-Host "Total Scripts: $totalScripts" -ForegroundColor White
Write-Host "Successful: $successfulScripts" -ForegroundColor Green
Write-Host "Failed: $failedScripts" -ForegroundColor Red
Write-Host "Skipped: $skippedScripts" -ForegroundColor Yellow

$successRate = if ($totalScripts -gt 0) { [math]::Round(($successfulScripts / $totalScripts) * 100, 2) } else { 0 }
Write-Host "Success Rate: $successRate%" -ForegroundColor Cyan

Write-Host ""
Write-Host "=== NEXT STEPS ===" -ForegroundColor Green
Write-Host "1. Check CSV files in each endpoint folder for generated data" -ForegroundColor White
Write-Host "2. Review failed scripts for authentication or API issues" -ForegroundColor White
Write-Host "3. Run OAuth2 endpoints when OAuth2 setup is complete" -ForegroundColor White
