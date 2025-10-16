# Performance Monitoring Script for Jira API Endpoints
# This script monitors execution times and performance metrics

$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"

Write-Host "=== JIRA API ENDPOINTS PERFORMANCE MONITOR ===" -ForegroundColor Green
Write-Host "Monitoring execution times and performance metrics..." -ForegroundColor Yellow
Write-Host ""

$scriptPath = $PSScriptRoot
$performanceData = @()

# Test endpoints with performance monitoring
$testEndpoints = @(
    @{ Name = "Projects Paginated"; Script = ".endpoints\Projects\Projects - GET Projects Paginated (Anon).ps1"; ExpectedRecords = 50 },
    @{ Name = "Issue Fields"; Script = ".endpoints\Issue Fields\Issue Fields - GET All Fields (Anon).ps1"; ExpectedRecords = 450 },
    @{ Name = "Custom Fields"; Script = ".endpoints\Custom Fields\Custom Fields - GET Fields (Anon).ps1"; ExpectedRecords = 420 },
    @{ Name = "Status"; Script = ".endpoints\Status\Status - GET Statuses (Anon).ps1"; ExpectedRecords = 110 },
    @{ Name = "Issue Types"; Script = ".endpoints\Issue Types\Issue Types - GET All issue types (Anon).ps1"; ExpectedRecords = 60 },
    @{ Name = "Users"; Script = ".endpoints\Users\Users - GET Users (Anon).ps1"; ExpectedRecords = 50 },
    @{ Name = "Dashboards"; Script = ".endpoints\Dashboards\Dashboards - GET All Dashboards (Anon).ps1"; ExpectedRecords = 50 },
    @{ Name = "Comments"; Script = ".endpoints\Comments\Comments - GET Comments (Anon).ps1"; ExpectedRecords = 10 },
    @{ Name = "Workflows"; Script = ".endpoints\Workflows\Workflows - GET Workflow schemes (Anon).ps1"; ExpectedRecords = 50 },
    @{ Name = "Issue Priorities"; Script = ".endpoints\Issue Priorities\Issue Priorities - GET Priorities (Anon).ps1"; ExpectedRecords = 5 }
)

Write-Host "Testing $($testEndpoints.Count) endpoints for performance analysis..." -ForegroundColor Cyan
Write-Host ""

foreach ($endpoint in $testEndpoints) {
    Write-Host "Testing: $($endpoint.Name)" -ForegroundColor Yellow
    
    $scriptFullPath = Join-Path $scriptPath $endpoint.Script
    
    if (Test-Path $scriptFullPath) {
        # Measure execution time
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            # Execute the script
            $output = & $scriptFullPath 2>&1
            $stopwatch.Stop()
            
            $executionTime = $stopwatch.ElapsedMilliseconds
            $success = ($LASTEXITCODE -eq 0)
            
            # Try to count records in generated CSV
            $csvPath = $scriptFullPath -replace "\.ps1$", ".csv"
            $recordCount = 0
            
            if (Test-Path $csvPath) {
                try {
                    $csvContent = Import-Csv $csvPath -ErrorAction SilentlyContinue
                    $recordCount = $csvContent.Count
                } catch {
                    $recordCount = 0
                }
            }
            
            $performanceData += @{
                Name = $endpoint.Name
                ExecutionTime = $executionTime
                Success = $success
                RecordCount = $recordCount
                ExpectedRecords = $endpoint.ExpectedRecords
                RecordsPerSecond = if ($executionTime -gt 0) { [math]::Round($recordCount / ($executionTime / 1000), 2) } else { 0 }
                Efficiency = if ($endpoint.ExpectedRecords -gt 0) { [math]::Round(($recordCount / $endpoint.ExpectedRecords) * 100, 2) } else { 0 }
                Status = if ($success) { "✅ SUCCESS" } else { "❌ FAILED" }
            }
            
            Write-Host "  Time: $executionTime ms | Records: $recordCount | Status: $(if ($success) { 'SUCCESS' } else { 'FAILED' })" -ForegroundColor $(if ($success) { 'Green' } else { 'Red' })
            
        } catch {
            $stopwatch.Stop()
            $executionTime = $stopwatch.ElapsedMilliseconds
            
            $performanceData += @{
                Name = $endpoint.Name
                ExecutionTime = $executionTime
                Success = $false
                RecordCount = 0
                ExpectedRecords = $endpoint.ExpectedRecords
                RecordsPerSecond = 0
                Efficiency = 0
                Status = "❌ EXCEPTION"
                Error = $_.Exception.Message
            }
            
            Write-Host "  Time: $executionTime ms | Status: EXCEPTION" -ForegroundColor Red
        }
        
    } else {
        Write-Host "  ❌ SCRIPT NOT FOUND" -ForegroundColor Red
        
        $performanceData += @{
            Name = $endpoint.Name
            ExecutionTime = 0
            Success = $false
            RecordCount = 0
            ExpectedRecords = $endpoint.ExpectedRecords
            RecordsPerSecond = 0
            Efficiency = 0
            Status = "❌ NOT FOUND"
            Error = "Script file not found"
        }
    }
    
    Write-Host ""
    
    # Add delay to avoid overwhelming the API
    Start-Sleep -Milliseconds 1000
}

# Display performance summary
Write-Host "=== PERFORMANCE ANALYSIS SUMMARY ===" -ForegroundColor Green
Write-Host ""

$successfulEndpoints = $performanceData | Where-Object { $_.Success -eq $true }
$failedEndpoints = $performanceData | Where-Object { $_.Success -eq $false }

Write-Host "Overall Statistics:" -ForegroundColor Cyan
Write-Host "  Total endpoints tested: $($performanceData.Count)" -ForegroundColor White
Write-Host "  Successful: $($successfulEndpoints.Count)" -ForegroundColor Green
Write-Host "  Failed: $($failedEndpoints.Count)" -ForegroundColor Red

if ($successfulEndpoints.Count -gt 0) {
    $avgExecutionTime = [math]::Round(($successfulEndpoints | Measure-Object -Property ExecutionTime -Average).Average, 2)
    $totalExecutionTime = ($successfulEndpoints | Measure-Object -Property ExecutionTime -Sum).Sum
    $totalRecords = ($successfulEndpoints | Measure-Object -Property RecordCount -Sum).Sum
    $avgRecordsPerSecond = [math]::Round($totalRecords / ($totalExecutionTime / 1000), 2)
    
    Write-Host ""
    Write-Host "Performance Metrics:" -ForegroundColor Cyan
    Write-Host "  Average execution time: $avgExecutionTime ms" -ForegroundColor White
    Write-Host "  Total execution time: $totalExecutionTime ms" -ForegroundColor White
    Write-Host "  Total records retrieved: $totalRecords" -ForegroundColor White
    Write-Host "  Average records per second: $avgRecordsPerSecond" -ForegroundColor White
}

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Cyan
Write-Host ""

# Sort by execution time (fastest first)
$sortedData = $performanceData | Sort-Object ExecutionTime

foreach ($data in $sortedData) {
    $color = if ($data.Success) { 'Green' } else { 'Red' }
    $timeColor = if ($data.ExecutionTime -lt 2000) { 'Green' } elseif ($data.ExecutionTime -lt 5000) { 'Yellow' } else { 'Red' }
    
    Write-Host "$($data.Status) $($data.Name)" -ForegroundColor $color
    Write-Host "  Execution Time: $($data.ExecutionTime) ms" -ForegroundColor $timeColor
    Write-Host "  Records: $($data.RecordCount) (Expected: $($data.ExpectedRecords), Efficiency: $($data.Efficiency)%)" -ForegroundColor White
    Write-Host "  Records/sec: $($data.RecordsPerSecond)" -ForegroundColor White
    
    if ($data.Error) {
        Write-Host "  Error: $($data.Error)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Performance recommendations
Write-Host "=== PERFORMANCE RECOMMENDATIONS ===" -ForegroundColor Green
Write-Host ""

$slowEndpoints = $successfulEndpoints | Where-Object { $_.ExecutionTime -gt 5000 }
$fastEndpoints = $successfulEndpoints | Where-Object { $_.ExecutionTime -lt 2000 }

if ($slowEndpoints.Count -gt 0) {
    Write-Host "⚠️  Slow Endpoints (>5 seconds):" -ForegroundColor Yellow
    foreach ($endpoint in $slowEndpoints) {
        Write-Host "  - $($endpoint.Name): $($endpoint.ExecutionTime) ms" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($fastEndpoints.Count -gt 0) {
    Write-Host "✅ Fast Endpoints (<2 seconds):" -ForegroundColor Green
    foreach ($endpoint in $fastEndpoints) {
        Write-Host "  - $($endpoint.Name): $($endpoint.ExecutionTime) ms" -ForegroundColor Green
    }
    Write-Host ""
}

Write-Host "💡 Optimization Tips:" -ForegroundColor Cyan
Write-Host "  1. Use pagination for large datasets" -ForegroundColor White
Write-Host "  2. Implement parallel execution for independent endpoints" -ForegroundColor White
Write-Host "  3. Add retry logic for failed requests" -ForegroundColor White
Write-Host "  4. Cache frequently accessed data" -ForegroundColor White
Write-Host "  5. Monitor API rate limits" -ForegroundColor White

Write-Host ""
Write-Host "Performance monitoring complete!" -ForegroundColor Green
