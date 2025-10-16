# =============================================================================
# EXECUTE OAUTH2 ENDPOINTS SCRIPT
# =============================================================================
# This script executes all GET endpoints that use OAuth2 authentication
# and generates CSV files with live data from the Jira API.
# 
# PREREQUISITE: OAuth2 must be properly configured and tokens available
# =============================================================================

Write-Host "=== EXECUTING OAUTH2 ENDPOINTS ===" -ForegroundColor Green
Write-Host "Starting execution of all OAuth2 GET endpoints..." -ForegroundColor Yellow
Write-Host ""

# Check if OAuth2 is configured
$oauth2ConfigPath = "oauth2_config.json"
if (-not (Test-Path $oauth2ConfigPath)) {
    Write-Host "❌ OAuth2 configuration not found!" -ForegroundColor Red
    Write-Host "Please run the OAuth2 setup process first:" -ForegroundColor Yellow
    Write-Host "1. Create OAuth2 app in Jira" -ForegroundColor White
    Write-Host "2. Update oauth2_config.json with credentials" -ForegroundColor White
    Write-Host "3. Run OAuth2_Authentication_Manager.ps1 to get tokens" -ForegroundColor White
    exit 1
}

# Load OAuth2 configuration
try {
    $oauth2Config = Get-Content $oauth2ConfigPath | ConvertFrom-Json
    if (-not $oauth2Config.AccessToken -or $oauth2Config.AccessToken -eq "YOUR_ACCESS_TOKEN") {
        Write-Host "❌ OAuth2 access token not configured!" -ForegroundColor Red
        Write-Host "Please run OAuth2_Authentication_Manager.ps1 to get valid tokens" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ OAuth2 configuration loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load OAuth2 configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Configuration
$basePath = ".endpoints"
$totalScripts = 0
$successfulScripts = 0
$failedScripts = 0
$skippedScripts = 0

# Get all PowerShell scripts with (OAuth2) in the name
$oauth2Scripts = Get-ChildItem -Path $basePath -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "\(OAuth2\)" -and $_.Name -match "GET"
}

Write-Host "Found $($oauth2Scripts.Count) OAuth2 GET endpoints to execute" -ForegroundColor Cyan
Write-Host ""

# Execute each script
foreach ($script in $oauth2Scripts) {
    $totalScripts++
    $scriptName = $script.Name
    $scriptPath = $script.FullName
    $relativePath = $scriptPath.Replace((Get-Location).Path + "\", "")
    
    Write-Host "[$totalScripts/$($oauth2Scripts.Count)] Executing: $scriptName" -ForegroundColor White
    
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
Write-Host "2. Review failed scripts for OAuth2 token or API issues" -ForegroundColor White
Write-Host "3. Refresh OAuth2 tokens if needed using OAuth2_Authentication_Manager.ps1" -ForegroundColor White
