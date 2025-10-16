#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple hardcoded script to delete all issues from LAS1 project
#>

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "║         DELETING ALL ISSUES FROM LAS1 PROJECT             ║" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# Load credentials from .env file
$envFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) ".env"
if (-not (Test-Path $envFile)) {
    throw ".env file not found at: $envFile"
}

$email = $null
$apiToken = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*USERNAME\s*=\s*(.*)$') {
        $email = $matches[1].Trim()
    }
    if ($_ -match '^\s*JIRA_API_TOKEN\s*=\s*(.*)$') {
        $apiToken = $matches[1].Trim()
    }
}

if (-not $email -or -not $apiToken) {
    throw "USERNAME or JIRA_API_TOKEN not found in .env file"
}

# Project configuration
$baseUrl = "https://onemainfinancial-sandbox-575.atlassian.net"
$projectKey = "LAS1"

# Create auth header
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${email}:${apiToken}"))
$headers = @{
    Authorization = "Basic $auth"
    "Content-Type" = "application/json"
}

# Get all issues with pagination
Write-Host "Fetching all issues from $projectKey..." -ForegroundColor Cyan
$uri = "$($baseUrl.TrimEnd('/'))/rest/api/3/search/jql"
$allIssues = @()
$maxResults = 100

try {
    # First call without startAt
    $body = @{
        jql = "project = $projectKey ORDER BY key ASC"
        maxResults = $maxResults
        fields = @("key", "summary")
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $headers -Body $body
    $allIssues += $response.issues
    Write-Host "  Fetched $($response.issues.Count) issues (Total: $($allIssues.Count))" -ForegroundColor Gray
    
    # Continue fetching if there are more issues
    while (-not $response.isLast -and $allIssues.Count -lt $response.total) {
        # For subsequent calls, we need to use the legacy /search endpoint with startAt
        $legacyUri = "$($baseUrl.TrimEnd('/'))/rest/api/3/search"
        $body = @{
            jql = "project = $projectKey ORDER BY key ASC"
            startAt = $allIssues.Count
            maxResults = $maxResults
            fields = @("key", "summary")
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Method POST -Uri $legacyUri -Headers $headers -Body $body
        if ($response.issues.Count -gt 0) {
            $allIssues += $response.issues
            Write-Host "  Fetched $($response.issues.Count) issues (Total: $($allIssues.Count))" -ForegroundColor Gray
        } else {
            break
        }
    }
    
    Write-Host ""
    Write-Host "Found $($allIssues.Count) total issues" -ForegroundColor Yellow
    Write-Host ""
} catch {
    Write-Host "❌ Failed to fetch issues: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) {
        Write-Host "Details: $($_.ErrorDetails.Message)" -ForegroundColor Red
    }
    exit 1
}

$issues = $allIssues

if ($issues.Count -eq 0) {
    Write-Host "✅ No issues to delete!" -ForegroundColor Green
    exit 0
}

# List issues
Write-Host "Issues to delete:" -ForegroundColor Yellow
foreach ($issue in $issues) {
    Write-Host "  - $($issue.key): $($issue.fields.summary)" -ForegroundColor Gray
}
Write-Host ""

# Delete issues
Write-Host ""
Write-Host "Deleting issues..." -ForegroundColor Cyan
$deleted = 0
$failed = 0

foreach ($issue in $issues) {
    try {
        $deleteUri = "$($baseUrl.TrimEnd('/'))/rest/api/3/issue/$($issue.key)"
        Invoke-RestMethod -Method DELETE -Uri $deleteUri -Headers $headers -ErrorAction Stop | Out-Null
        Write-Host "  ✅ Deleted: $($issue.key)" -ForegroundColor Green
        $deleted++
    } catch {
        Write-Host "  ❌ Failed: $($issue.key) - $($_.Exception.Message)" -ForegroundColor Red
        $failed++
    }
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    DELETION COMPLETE                      ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Deleted: $deleted" -ForegroundColor Green
Write-Host "❌ Failed:  $failed" -ForegroundColor Red
Write-Host ""
