# Parallel Execution Script for Jira API Endpoints
# This script runs multiple endpoints in parallel for better performance

$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"

Write-Host "=== JIRA API ENDPOINTS PARALLEL EXECUTION ===" -ForegroundColor Green
Write-Host "Starting parallel execution of endpoints..." -ForegroundColor Yellow
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host ""

$scriptPath = $PSScriptRoot
$maxConcurrency = 5  # Maximum number of parallel executions

# Define high-priority endpoints for parallel execution
$priorityEndpoints = @(
    ".endpoints\Projects\Projects - GET Projects Paginated (Anon).ps1",
    ".endpoints\Issue Fields\Issue Fields - GET All Fields (Anon).ps1",
    ".endpoints\Custom Fields\Custom Fields - GET Fields (Anon).ps1",
    ".endpoints\Status\Status - GET Statuses (Anon).ps1",
    ".endpoints\Issue Types\Issue Types - GET All issue types (Anon).ps1",
    ".endpoints\Users\Users - GET Users (Anon).ps1",
    ".endpoints\Dashboards\Dashboards - GET All Dashboards (Anon).ps1",
    ".endpoints\Comments\Comments - GET Comments (Anon).ps1",
    ".endpoints\Workflows\Workflows - GET Workflow schemes (Anon).ps1",
    ".endpoints\Issue Priorities\Issue Priorities - GET Priorities (Anon).ps1"
)

# Function to execute a single endpoint
function Execute-Endpoint {
    param(
        [string]$ScriptPath,
        [string]$EndpointName
    )
    
    try {
        Write-Host "🚀 Starting: $EndpointName" -ForegroundColor Cyan
        
        # Execute the script
        $result = & $ScriptPath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ SUCCESS: $EndpointName" -ForegroundColor Green
            return @{ Success = $true; Name = $EndpointName; Output = $result }
        } else {
            Write-Host "❌ ERROR: $EndpointName - Exit code: $LASTEXITCODE" -ForegroundColor Red
            return @{ Success = $false; Name = $EndpointName; Output = $result; Error = "Exit code: $LASTEXITCODE" }
        }
    } catch {
        Write-Host "❌ EXCEPTION: $EndpointName - $($_.Exception.Message)" -ForegroundColor Red
        return @{ Success = $false; Name = $EndpointName; Output = $null; Error = $_.Exception.Message }
    }
}

# Create jobs for parallel execution
$jobs = @()
$results = @()

Write-Host "Creating parallel execution jobs..." -ForegroundColor Yellow

foreach ($endpoint in $priorityEndpoints) {
    $scriptFullPath = Join-Path $scriptPath $endpoint
    $endpointName = Split-Path $endpoint -Leaf
    
    if (Test-Path $scriptFullPath) {
        # Create a background job
        $job = Start-Job -ScriptBlock {
            param($Path, $Name)
            & $Path
        } -ArgumentList $scriptFullPath, $endpointName
        
        $jobs += $job
        Write-Host "📋 Queued: $endpointName" -ForegroundColor Gray
        
        # Limit concurrent jobs
        if ($jobs.Count -ge $maxConcurrency) {
            # Wait for jobs to complete
            $completedJobs = $jobs | Wait-Job -Any
            foreach ($completedJob in $completedJobs) {
                $result = Receive-Job $completedJob
                $results += @{ Name = $completedJob.Name; Result = $result; Success = ($completedJob.State -eq "Completed") }
                Remove-Job $completedJob
                $jobs = $jobs | Where-Object { $_.Id -ne $completedJob.Id }
            }
        }
    } else {
        Write-Host "❌ SCRIPT NOT FOUND: $endpoint" -ForegroundColor Red
        $results += @{ Name = $endpointName; Result = $null; Success = $false; Error = "Script not found" }
    }
}

# Wait for remaining jobs to complete
Write-Host ""
Write-Host "Waiting for remaining jobs to complete..." -ForegroundColor Yellow
$remainingJobs = $jobs | Wait-Job

foreach ($job in $remainingJobs) {
    $result = Receive-Job $job
    $results += @{ Name = $job.Name; Result = $result; Success = ($job.State -eq "Completed") }
    Remove-Job $job
}

# Display results summary
Write-Host ""
Write-Host "=== PARALLEL EXECUTION SUMMARY ===" -ForegroundColor Green

$successCount = ($results | Where-Object { $_.Success -eq $true }).Count
$errorCount = ($results | Where-Object { $_.Success -eq $false }).Count
$totalCount = $results.Count

Write-Host "Total endpoints: $totalCount" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red

if ($totalCount -gt 0) {
    $successRate = [math]::Round(($successCount / $totalCount) * 100, 2)
    Write-Host "Success rate: $successRate%" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Detailed Results:" -ForegroundColor Cyan
foreach ($result in $results) {
    if ($result.Success) {
        Write-Host "✅ $($result.Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ $($result.Name)" -ForegroundColor Red
        if ($result.Error) {
            Write-Host "   Error: $($result.Error)" -ForegroundColor Red
        }
    }
}

if ($errorCount -eq 0) {
    Write-Host "🎉 All parallel executions completed successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some parallel executions failed. Check the details above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Performance Note: Parallel execution reduces total time but may hit API rate limits." -ForegroundColor Yellow
Write-Host "For production use, consider sequential execution with rate limiting." -ForegroundColor Yellow
