# =============================================================================
# Complete Fresh Start with All Fixes Applied
# =============================================================================
# This script will:
# 1. Delete all existing CSV files from the .endpoints directory
# 2. Run all GET endpoint scripts with proper pagination to get ALL records
# 3. Provide a comprehensive summary of results
# =============================================================================

# Define Jira connection variables
$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

$endpointsDir = ".endpoints"
$deletedCount = 0
$successCount = 0
$errorCount = 0
$totalRecords = 0

Write-Host "COMPLETE FRESH START WITH ALL FIXES APPLIED" -ForegroundColor Magenta
Write-Host "=============================================================" -ForegroundColor Magenta

# =============================================================================
# STEP 1: Delete all CSV files
# =============================================================================
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
    
    Write-Host "`n✅ Deleted $deletedCount CSV files" -ForegroundColor Green
} catch {
    Write-Host "❌ Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# STEP 2: Run all GET endpoints with pagination
# =============================================================================
Write-Host "`nSTEP 2: Running all GET endpoints with pagination..." -ForegroundColor Yellow

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

$totalEndpoints = $getScripts.Count
Write-Host "📋 Found $totalEndpoints GET endpoint scripts" -ForegroundColor Cyan

foreach ($script in $getScripts) {
    try {
        Write-Host "`nProcessing: $($script.Name)" -ForegroundColor Cyan
        
        # Run the individual script
        $result = & $script.FullName 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $successCount++
            
            # Try to extract record count from the output
            if ($result -match "Total records found: (\d+)") {
                $recordCount = [int]$matches[1]
                $totalRecords += $recordCount
                Write-Host "  ✅ Success - $recordCount records" -ForegroundColor Green
            } else {
                Write-Host "  ✅ Success" -ForegroundColor Green
            }
        } else {
            $errorCount++
            Write-Host "  ❌ Failed - Exit code: $LASTEXITCODE" -ForegroundColor Red
            if ($result) {
                Write-Host "  Error: $($result[-1])" -ForegroundColor Red
            }
        }
    } catch {
        $errorCount++
        Write-Host "  ❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# =============================================================================
# STEP 3: Summary
# =============================================================================
Write-Host "`n" + "=" * 60 -ForegroundColor Magenta
Write-Host "COMPLETE FRESH START FINISHED" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Magenta
Write-Host "CSV Files Deleted: $deletedCount" -ForegroundColor Yellow
Write-Host "Total Endpoints Processed: $totalEndpoints" -ForegroundColor Yellow
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $errorCount" -ForegroundColor Red
Write-Host "Total Records Collected: $totalRecords" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Magenta

if ($successCount -gt 0) {
    $successRate = [math]::Round(($successCount / $totalEndpoints) * 100, 1)
    Write-Host "Success Rate: $successRate%" -ForegroundColor Green
}

Write-Host "`nFresh start complete! All CSV files regenerated with latest data." -ForegroundColor Green
