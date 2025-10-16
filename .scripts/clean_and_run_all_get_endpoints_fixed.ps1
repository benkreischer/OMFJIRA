# Clean and Run All GET Endpoints - Fixed Version
$endpointsDir = ".endpoints"
$deletedCount = 0
$successCount = 0
$errorCount = 0
$totalEndpoints = 0

Write-Host "CLEANING AND RUNNING ALL GET ENDPOINTS" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# STEP 1: Delete all CSV files
Write-Host "`nSTEP 1: Cleaning up existing CSV files..." -ForegroundColor Yellow

try {
    $csvFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.csv"
    $deletedCount = $csvFiles.Count
    
    foreach ($file in $csvFiles) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "  Deleted: $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to delete: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nCSV Cleanup Summary:" -ForegroundColor Cyan
    Write-Host "  CSV files deleted: $deletedCount" -ForegroundColor Green
} catch {
    Write-Host "  Error during CSV cleanup: $($_.Exception.Message)" -ForegroundColor Red
}

# STEP 2: Find and run all GET endpoint scripts
Write-Host "`nSTEP 2: Running all GET endpoint scripts..." -ForegroundColor Yellow

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

$totalEndpoints = $getScripts.Count
Write-Host "  Found $totalEndpoints GET endpoint scripts to execute" -ForegroundColor Cyan

# Sort scripts by category for better organization
$sortedScripts = $getScripts | Sort-Object { $_.Directory.Name }, { $_.Name }

$currentCategory = ""
$categoryCount = 0

foreach ($script in $sortedScripts) {
    $category = $script.Directory.Name
    
    # Show category header when it changes
    if ($category -ne $currentCategory) {
        if ($currentCategory -ne "") {
            Write-Host "  Category '$currentCategory' completed: $categoryCount scripts" -ForegroundColor Blue
        }
        $currentCategory = $category
        $categoryCount = 0
        Write-Host "`n  Processing category: $category" -ForegroundColor Magenta
    }
    
    $categoryCount++
    
    try {
        Write-Host "    Running: $($script.Name)" -ForegroundColor White
        
        # Run the script and capture output
        $output = & $script.FullName 2>&1
        
        # Check if the script completed successfully
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            Write-Host "    Success: $($script.Name)" -ForegroundColor Green
            
            # Try to extract record count from output
            if ($output -match "Total records found: (\d+)") {
                $recordCount = $matches[1]
                Write-Host "      Records: $recordCount" -ForegroundColor Cyan
            }
        } else {
            $errorCount++
            Write-Host "    Failed: $($script.Name) (Exit code: $LASTEXITCODE)" -ForegroundColor Red
        }
        
    } catch {
        $errorCount++
        Write-Host "    Error running $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Add a small delay to avoid overwhelming the API
    Start-Sleep -Milliseconds 100
}

# Show final category summary
if ($currentCategory -ne "") {
    Write-Host "  Category '$currentCategory' completed: $categoryCount scripts" -ForegroundColor Blue
}

# STEP 3: Generate comprehensive summary
Write-Host "`nFINAL SUMMARY" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

Write-Host "`nCleanup Results:" -ForegroundColor Yellow
Write-Host "  CSV files deleted: $deletedCount" -ForegroundColor Green

Write-Host "`nExecution Results:" -ForegroundColor Yellow
Write-Host "  Total GET endpoints found: $totalEndpoints" -ForegroundColor Cyan
Write-Host "  Successfully executed: $successCount" -ForegroundColor Green
Write-Host "  Failed executions: $errorCount" -ForegroundColor Red
Write-Host "  Success rate: $([math]::Round(($successCount / $totalEndpoints) * 100, 1))%" -ForegroundColor Cyan

# Count generated CSV files
$newCsvFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.csv"
Write-Host "`nGenerated Files:" -ForegroundColor Yellow
Write-Host "  New CSV files created: $($newCsvFiles.Count)" -ForegroundColor Green

if ($errorCount -gt 0) {
    Write-Host "`nNote: Some endpoints failed to execute. This may be due to:" -ForegroundColor Yellow
    Write-Host "  Authentication issues" -ForegroundColor White
    Write-Host "  API rate limiting" -ForegroundColor White
    Write-Host "  Missing permissions" -ForegroundColor White
    Write-Host "  Invalid endpoint configurations" -ForegroundColor White
}

Write-Host "`nAUDIT DATA GENERATION COMPLETE!" -ForegroundColor Green
Write-Host "Your Jira environment audit data is now ready for analysis." -ForegroundColor Cyan

# Show location of generated files
Write-Host "`nGenerated CSV files are located in:" -ForegroundColor Yellow
Write-Host "  $((Get-Item $endpointsDir).FullName)" -ForegroundColor White
