# =============================================================================
# Run All GET Endpoints (Keep Existing CSV Files)
# =============================================================================
# This script will run all GET endpoint PowerShell scripts to generate/update data
# without deleting existing CSV files
# =============================================================================

$endpointsDir = ".endpoints"
$successCount = 0
$errorCount = 0
$totalEndpoints = 0

Write-Host "🚀 RUNNING ALL GET ENDPOINTS" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Magenta

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

$totalEndpoints = $getScripts.Count
Write-Host "📋 Found $totalEndpoints GET endpoint scripts to execute" -ForegroundColor Cyan

# Sort scripts by category for better organization
$sortedScripts = $getScripts | Sort-Object { $_.Directory.Name }, { $_.Name }

$currentCategory = ""
$categoryCount = 0

foreach ($script in $sortedScripts) {
    $category = $script.Directory.Name
    
    # Show category header when it changes
    if ($category -ne $currentCategory) {
        if ($currentCategory -ne "") {
            Write-Host "📊 Category '$currentCategory' completed: $categoryCount scripts" -ForegroundColor Blue
        }
        $currentCategory = $category
        $categoryCount = 0
        Write-Host "`n📁 Processing category: $category" -ForegroundColor Magenta
    }
    
    $categoryCount++
    
    try {
        Write-Host "  🔄 Running: $($script.Name)" -ForegroundColor White
        
        # Run the script and capture output
        $output = & $script.FullName 2>&1
        
        # Check if the script completed successfully
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host "  ✅ Success: $($script.Name)" -ForegroundColor Green
            
            # Try to extract record count from output
            if ($output -match "Total records found: (\d+)") {
                $recordCount = $matches[1]
                Write-Host "    📊 Records: $recordCount" -ForegroundColor Cyan
            }
        } else {
            $errorCount++
            Write-Host "  ❌ Failed: $($script.Name) (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        }
        
    } catch {
        $errorCount++
        Write-Host "  ❌ Error running $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Add a small delay to avoid overwhelming the API
    Start-Sleep -Milliseconds 100
}

# Show final category summary
if ($currentCategory -ne "") {
    Write-Host "📊 Category '$currentCategory' completed: $categoryCount scripts" -ForegroundColor Blue
}

# =============================================================================
# Final Summary
# =============================================================================
Write-Host "`n📈 EXECUTION SUMMARY" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Magenta

Write-Host "🚀 Results:" -ForegroundColor Yellow
Write-Host "  • Total GET endpoints found: $totalEndpoints" -ForegroundColor Cyan
Write-Host "  • Successfully executed: $successCount" -ForegroundColor Green
Write-Host "  • Failed executions: $errorCount" -ForegroundColor Red
Write-Host "  • Success rate: $([math]::Round(($successCount / $totalEndpoints) * 100, 1))%" -ForegroundColor Cyan

if ($errorCount -gt 0) {
    Write-Host "`n⚠️  Some endpoints failed. Check the output above for details." -ForegroundColor Yellow
}

Write-Host "`n🎉 GET ENDPOINTS EXECUTION COMPLETE!" -ForegroundColor Green
