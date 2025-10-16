# Master Script to Run All Working Jira API Endpoints
# This script executes all known working endpoints in sequence to generate CSV files

$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

Write-Host "=== JIRA API ENDPOINTS MASTER SCRIPT ===" -ForegroundColor Green
Write-Host "Starting execution of all working endpoints..." -ForegroundColor Yellow
Write-Host "Base URL: $BaseUrl" -ForegroundColor Cyan
Write-Host ""

$scriptPath = $PSScriptRoot
$successCount = 0
$errorCount = 0
$totalCount = 0

# Define the working endpoints to execute
$workingEndpoints = @(
    @{
        Name = "Projects - GET All Projects"
        Script = ".endpoints\Projects\Projects - GET Projects Paginated (Anon).ps1"
        Category = "Projects"
    },
    @{
        Name = "Issue Fields - GET All Fields"
        Script = ".endpoints\Issue Fields\Issue Fields - GET All Fields (Anon).ps1"
        Category = "Issue Fields"
    },
    @{
        Name = "Issues - GET Issue"
        Script = ".endpoints\Issues\Issues - GET Issue (Anon).ps1"
        Category = "Issues"
    },
    @{
        Name = "Custom Fields - GET Fields"
        Script = ".endpoints\Custom Fields\Custom Fields - GET Fields (Anon).ps1"
        Category = "Custom Fields"
    },
    @{
        Name = "Status - GET Statuses"
        Script = ".endpoints\Status\Status - GET Statuses (Anon).ps1"
        Category = "Status"
    },
    @{
        Name = "Issue Types - GET All Issue Types"
        Script = ".endpoints\Issue Types\Issue Types - GET All issue types (Anon).ps1"
        Category = "Issue Types"
    },
    @{
        Name = "Users - GET Users"
        Script = ".endpoints\Users\Users - GET Users (Anon).ps1"
        Category = "Users"
    },
    @{
        Name = "Dashboards - GET All Dashboards"
        Script = ".endpoints\Dashboards\Dashboards - GET All Dashboards (Anon).ps1"
        Category = "Dashboards"
    },
    @{
        Name = "Comments - GET Comments"
        Script = ".endpoints\Comments\Comments - GET Comments (Anon).ps1"
        Category = "Comments"
    },
    @{
        Name = "Workflows - GET Workflow Schemes"
        Script = ".endpoints\Workflows\Workflows - GET Workflow schemes (Anon).ps1"
        Category = "Workflows"
    },
    @{
        Name = "Issue Priorities - GET Priorities"
        Script = ".endpoints\Issue Priorities\Issue Priorities - GET Priorities (Anon).ps1"
        Category = "Issue Priorities"
    },
    @{
        Name = "Issue Resolutions - GET Resolutions"
        Script = ".endpoints\Issue Resolutions\Issue Resolutions - GET Resolutions (Anon).ps1"
        Category = "Issue Resolutions"
    },
    @{
        Name = "Project Versions - GET Versions"
        Script = ".endpoints\Project Versions\Project Versions - GET Versions (Anon).ps1"
        Category = "Project Versions"
    },
    @{
        Name = "Issue Search - GET Search"
        Script = ".endpoints\Issue Search\Issue Search - GET Search (Anon).ps1"
        Category = "Issue Search"
    },
    @{
        Name = "Attachments - GET Attachments"
        Script = ".endpoints\Attachments\Attachments - GET Attachments (Anon).ps1"
        Category = "Attachments"
    },
    @{
        Name = "Issue Links - GET Issue Links"
        Script = ".endpoints\Issue Links\Issue Links - GET Issue Links (Anon).ps1"
        Category = "Issue Links"
    },
    @{
        Name = "Issue Properties - GET Property Keys"
        Script = ".endpoints\Issue Properties\Issue Properties - GET Property keys (Anon).ps1"
        Category = "Issue Properties"
    },
    @{
        Name = "Jira Settings - GET Application Properties"
        Script = ".endpoints\Jira Settings\Jira Settings - GET Application Properties (Anon).ps1"
        Category = "Jira Settings"
    },
    @{
        Name = "Server Info - GET Server Info"
        Script = ".endpoints\Server Info\Server Info - GET Server Info (Anon).ps1"
        Category = "Server Info"
    },
    @{
        Name = "Project Categories - GET Categories"
        Script = ".endpoints\Project Categories\Project Categories - GET Categories (Anon).ps1"
        Category = "Project Categories"
    },
    @{
        Name = "Project Types - GET Types"
        Script = ".endpoints\Project Types\Project Types - GET Types (Anon).ps1"
        Category = "Project Types"
    },
    @{
        Name = "Issue Type Schemes - GET Schemes"
        Script = ".endpoints\Issue Type Schemes\Issue Type Schemes - GET Schemes (Anon).ps1"
        Category = "Issue Type Schemes"
    },
    @{
        Name = "Priority Schemes - GET Schemes"
        Script = ".endpoints\Priority Schemes\Priority Schemes - GET Schemes (Anon).ps1"
        Category = "Priority Schemes"
    },
    @{
        Name = "Screen Schemes - GET Schemes"
        Script = ".endpoints\Screen Schemes\Screen Schemes - GET Schemes (Anon).ps1"
        Category = "Screen Schemes"
    },
    @{
        Name = "Screens - GET Screens"
        Script = ".endpoints\Screens\Screens - GET Screens (Anon).ps1"
        Category = "Screens"
    },
    @{
        Name = "Component - GET Component"
        Script = ".endpoints\Component\Component - GET Component (Anon).ps1"
        Category = "Component"
    },
    @{
        Name = "Application Roles - GET Roles"
        Script = ".endpoints\Application Roles\Application Roles - GET Application roles (Anon).ps1"
        Category = "Application Roles"
    },
    @{
        Name = "Audit Records - GET Records"
        Script = ".endpoints\Audit Records\Audit Records - GET Audit records (Anon).ps1"
        Category = "Audit Records"
    },
    @{
        Name = "Custom Field Options - GET Options"
        Script = ".endpoints\Custom Field Options\Custom Field Options - GET Custom Field Options (Anon).ps1"
        Category = "Custom Field Options"
    },
    @{
        Name = "User Properties - GET Properties"
        Script = ".endpoints\User Properties\User Properties - GET User Properties (Anon).ps1"
        Category = "User Properties"
    }
)

$totalCount = $workingEndpoints.Count

Write-Host "Total endpoints to execute: $totalCount" -ForegroundColor Cyan
Write-Host ""

foreach ($endpoint in $workingEndpoints) {
    $totalCount++
    Write-Host "[$totalCount/$($workingEndpoints.Count)] Executing: $($endpoint.Name)" -ForegroundColor Yellow
    
    try {
        # Check if script exists
        $scriptFullPath = Join-Path $scriptPath $endpoint.Script
        if (Test-Path $scriptFullPath) {
            # Execute the script
            & $scriptFullPath
            
            if ($LASTEXITCODE -eq 0) {
                $successCount++
                Write-Host "✅ SUCCESS: $($endpoint.Name)" -ForegroundColor Green
            } else {
                $errorCount++
                Write-Host "❌ ERROR: $($endpoint.Name) - Exit code: $LASTEXITCODE" -ForegroundColor Red
            }
        } else {
            $errorCount++
            Write-Host "❌ ERROR: $($endpoint.Name) - Script not found: $scriptFullPath" -ForegroundColor Red
        }
    } catch {
        $errorCount++
        Write-Host "❌ EXCEPTION: $($endpoint.Name) - $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Add a small delay to avoid overwhelming the API
    Start-Sleep -Milliseconds 500
}

Write-Host "=== EXECUTION SUMMARY ===" -ForegroundColor Green
Write-Host "Total endpoints: $($workingEndpoints.Count)" -ForegroundColor Cyan
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Success rate: $([math]::Round(($successCount / $workingEndpoints.Count) * 100, 2))%" -ForegroundColor Yellow

if ($errorCount -eq 0) {
    Write-Host "🎉 All endpoints executed successfully!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Some endpoints failed. Check the logs above for details." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Generated CSV files are located in their respective endpoint folders." -ForegroundColor Cyan
Write-Host "Use the Excel summary file for Power BI integration." -ForegroundColor Cyan
