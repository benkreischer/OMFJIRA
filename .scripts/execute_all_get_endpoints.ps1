# =============================================================================
# EXECUTE ALL GET ENDPOINTS - COMPLETE COVERAGE
# =============================================================================
# This script executes ALL GET endpoints (both Basic Auth and OAuth2)
# Generates live CSV files with complete data from your Jira ecosystem

Write-Host "=== EXECUTING ALL GET ENDPOINTS - COMPLETE JIRA ECOSYSTEM COVERAGE ===" -ForegroundColor Green
Write-Host "This will execute all 276 GET endpoints and generate CSV files with complete data" -ForegroundColor Yellow

# Check OAuth2 configuration
$oauth2ConfigFile = "oauth2_config.json"
$oauth2Configured = $false

if (Test-Path $oauth2ConfigFile) {
    try {
        $oauth2Config = Get-Content $oauth2ConfigFile | ConvertFrom-Json
        if ($oauth2Config.oauth2.client_id -and $oauth2Config.oauth2.client_id -ne "YOUR_OAUTH2_CLIENT_ID") {
            if ($oauth2Config.oauth2.access_token) {
                $oauth2Configured = $true
                Write-Host "✓ OAuth2 authentication is configured and ready" -ForegroundColor Green
            } else {
                Write-Host "⚠ OAuth2 app configured but not authorized. OAuth2 endpoints will be skipped." -ForegroundColor Yellow
                Write-Host "  To enable OAuth2 endpoints, run: .\OAuth2_Authentication_Manager.ps1 -Action authorize" -ForegroundColor Gray
            }
        } else {
            Write-Host "⚠ OAuth2 not configured. OAuth2 endpoints will be skipped." -ForegroundColor Yellow
            Write-Host "  To enable OAuth2 endpoints, see: OAUTH2_SETUP_GUIDE.md" -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠ OAuth2 config file error. OAuth2 endpoints will be skipped." -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ OAuth2 config file not found. OAuth2 endpoints will be skipped." -ForegroundColor Yellow
    Write-Host "  To enable OAuth2 endpoints, see: OAUTH2_SETUP_GUIDE.md" -ForegroundColor Gray
}

# Get all GET PowerShell scripts
$allGetScripts = Get-ChildItem -Path ".endpoints" -Recurse -Filter "*GET*.ps1" | Sort-Object FullName

# Separate Basic Auth and OAuth2 scripts
$basicAuthScripts = $allGetScripts | Where-Object { 
    $_.FullName -notlike "*OAuth2*" -and 
    $_.FullName -notlike "*Enterprise Features (OAuth2)*" -and
    $_.FullName -notlike "*Audit & Compliance (OAuth2)*" -and
    $_.FullName -notlike "*Advanced Workflows (OAuth2)*" -and
    $_.FullName -notlike "*Advanced Security (OAuth2)*" -and
    $_.FullName -notlike "*Advanced Permissions (OAuth2)*" -and
    $_.FullName -notlike "*Advanced Analytics (OAuth2)*" -and
    $_.FullName -notlike "*Integration Management (OAuth2)*"
}

$oauth2Scripts = $allGetScripts | Where-Object { 
    $_.FullName -like "*OAuth2*" -or
    $_.FullName -like "*Enterprise Features (OAuth2)*" -or
    $_.FullName -like "*Audit & Compliance (OAuth2)*" -or
    $_.FullName -like "*Advanced Workflows (OAuth2)*" -or
    $_.FullName -like "*Advanced Security (OAuth2)*" -or
    $_.FullName -like "*Advanced Permissions (OAuth2)*" -or
    $_.FullName -like "*Advanced Analytics (OAuth2)*" -or
    $_.FullName -like "*Integration Management (OAuth2)*"
}

Write-Host ""
Write-Host "Found $($basicAuthScripts.Count) Basic Auth GET scripts" -ForegroundColor Cyan
Write-Host "Found $($oauth2Scripts.Count) OAuth2 GET scripts" -ForegroundColor Cyan

if ($oauth2Configured) {
    Write-Host "Total scripts to execute: $($basicAuthScripts.Count + $oauth2Scripts.Count)" -ForegroundColor Green
} else {
    Write-Host "Total scripts to execute: $($basicAuthScripts.Count) (OAuth2 skipped)" -ForegroundColor Yellow
}

$successCount = 0
$errorCount = 0
$skippedCount = 0
$totalScripts = if ($oauth2Configured) { $basicAuthScripts.Count + $oauth2Scripts.Count } else { $basicAuthScripts.Count }

# Execute Basic Auth scripts first
Write-Host ""
Write-Host "=== EXECUTING BASIC AUTHENTICATION ENDPOINTS ===" -ForegroundColor Green

foreach ($script in $basicAuthScripts) {
    $scriptName = $script.BaseName
    $scriptPath = $script.FullName
    $scriptNumber = $successCount + $errorCount + $skippedCount + 1
    
    Write-Host "[$scriptNumber/$totalScripts] Executing: $scriptName" -ForegroundColor White
    
    try {
        # Change to the script's directory to ensure CSV files are created in the right location
        $scriptDir = $script.Directory.FullName
        Push-Location $scriptDir
        
        # Execute the script
        $result = & $scriptPath 2>&1
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Host "  ✓ SUCCESS: $scriptName" -ForegroundColor Green
            
            # Check if CSV was created
            $csvFile = Join-Path $scriptDir "$scriptName.csv"
            if (Test-Path $csvFile) {
                $csvLines = (Get-Content $csvFile | Measure-Object -Line).Lines
                Write-Host "    Generated CSV with $csvLines lines" -ForegroundColor Gray
            }
            
            $successCount++
        } else {
            Write-Host "  ✗ ERROR: $scriptName (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
            $errorCount++
        }
        
    } catch {
        Write-Host "  ✗ ERROR: $scriptName - $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    } finally {
        Pop-Location
    }
}

# Execute OAuth2 scripts if configured
if ($oauth2Configured) {
    Write-Host ""
    Write-Host "=== EXECUTING OAUTH2 ENDPOINTS ===" -ForegroundColor Green
    
    foreach ($script in $oauth2Scripts) {
        $scriptName = $script.BaseName
        $scriptPath = $script.FullName
        $scriptNumber = $successCount + $errorCount + $skippedCount + 1
        
        Write-Host "[$scriptNumber/$totalScripts] Executing: $scriptName" -ForegroundColor White
        
        try {
            # Change to the script's directory to ensure CSV files are created in the right location
            $scriptDir = $script.Directory.FullName
            Push-Location $scriptDir
            
            # Execute the script
            $result = & $scriptPath 2>&1
            
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
                Write-Host "  ✓ SUCCESS: $scriptName" -ForegroundColor Green
                
                # Check if CSV was created
                $csvFile = Join-Path $scriptDir "$scriptName.csv"
                if (Test-Path $csvFile) {
                    $csvLines = (Get-Content $csvFile | Measure-Object -Line).Lines
                    Write-Host "    Generated CSV with $csvLines lines" -ForegroundColor Gray
                }
                
                $successCount++
            } else {
                Write-Host "  ✗ ERROR: $scriptName (Exit Code: $LASTEXITCODE)" -ForegroundColor Red
                $errorCount++
            }
            
        } catch {
            Write-Host "  ✗ ERROR: $scriptName - $($_.Exception.Message)" -ForegroundColor Red
            $errorCount++
        } finally {
            Pop-Location
        }
    }
} else {
    $skippedCount = $oauth2Scripts.Count
    Write-Host ""
    Write-Host "=== SKIPPING OAUTH2 ENDPOINTS ===" -ForegroundColor Yellow
    Write-Host "Skipped $($oauth2Scripts.Count) OAuth2 endpoints (OAuth2 not configured)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Green
Write-Host "Total Scripts: $totalScripts" -ForegroundColor White
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

if ($skippedCount -gt 0) {
    Write-Host ""
    Write-Host "OAuth2 endpoints were skipped because OAuth2 setup is not configured." -ForegroundColor Cyan
    Write-Host "To enable OAuth2 endpoints:" -ForegroundColor Cyan
    Write-Host "1. See: OAUTH2_SETUP_GUIDE.md" -ForegroundColor Gray
    Write-Host "2. Run: .\OAuth2_Authentication_Manager.ps1 -Action setup" -ForegroundColor Gray
    Write-Host "3. Re-run this script to execute all endpoints" -ForegroundColor Gray
}

Write-Host ""
Write-Host "=== COVERAGE ANALYSIS ===" -ForegroundColor Green
$coveragePercentage = [math]::Round(($successCount / $totalScripts) * 100, 1)
Write-Host "Success Rate: $coveragePercentage%" -ForegroundColor $(if ($coveragePercentage -ge 90) { "Green" } elseif ($coveragePercentage -ge 70) { "Yellow" } else { "Red" })

if ($oauth2Configured) {
    Write-Host "Complete Jira ecosystem coverage achieved!" -ForegroundColor Green
} else {
    Write-Host "Basic Jira coverage achieved. OAuth2 setup needed for advanced features." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Execution completed!" -ForegroundColor Green