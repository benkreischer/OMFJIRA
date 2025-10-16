# Quick script to delete all issues in DEP1 project
param([string] $ProjectKey = "DEP1")

# Load common functions
. ".\src\_common.ps1"

# Load parameters
$p = Read-JsonFile -Path ".\projects\DEP\parameters.json"

# Setup target environment
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host "=== DELETING ALL ISSUES IN PROJECT: $ProjectKey ===" -ForegroundColor Red

# Get all issues in the project
$allIssues = @{}
$startAt = 0
$maxResults = 1000

do {
    Write-Host "Fetching issues starting at $startAt..."
    $searchUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
    $searchBody = @{
        jql = "project = $ProjectKey"
        startAt = $startAt
        maxResults = $maxResults
        fields = @("id", "key")
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Method POST -Uri $searchUri -Headers $tgtHdr -Body $searchBody -ContentType "application/json"
    
    foreach ($issue in $response.issues) {
        $allIssues[$issue.key] = $issue
    }
    
    $startAt += $maxResults
    Write-Host "Found $($allIssues.Count) issues so far..."
    
} while ($startAt -lt $response.total)

Write-Host "Total issues found: $($allIssues.Count)"

if ($allIssues.Count -eq 0) {
    Write-Host "No issues to delete!" -ForegroundColor Green
    exit 0
}

# Delete all issues
$deletedCount = 0
$failedCount = 0

Write-Host "Starting deletion of $($allIssues.Count) issues..."

foreach ($issueKey in $allIssues.Keys) {
    try {
        $issue = $allIssues[$issueKey]
        $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$($issue.id)?deleteSubtasks=true"
        
        Write-Host "Deleting: $issueKey (ID: $($issue.id))" -NoNewline
        
        Invoke-RestMethod -Method DELETE -Uri $deleteUri -Headers $tgtHdr -ErrorAction Stop
        $deletedCount++
        Write-Host " ✅" -ForegroundColor Green
        
        # Rate limiting
        Start-Sleep -Milliseconds 200
        
    } catch {
        $failedCount++
        Write-Host " ❌ FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== DELETION SUMMARY ===" -ForegroundColor Yellow
Write-Host "Deleted: $deletedCount" -ForegroundColor Green
Write-Host "Failed: $failedCount" -ForegroundColor Red

# Verify deletion
Write-Host ""
Write-Host "Verifying deletion..."
Start-Sleep -Seconds 3

$verifyUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
$verifyBody = @{
    jql = "project = $ProjectKey"
    maxResults = 1
    fields = @("id")
} | ConvertTo-Json

try {
    $verifyResponse = Invoke-RestMethod -Method POST -Uri $verifyUri -Headers $tgtHdr -Body $verifyBody -ContentType "application/json"
    
    if ($verifyResponse.total -eq 0) {
        Write-Host "✅ VERIFICATION: All issues successfully deleted!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ VERIFICATION: $($verifyResponse.total) issues still remain" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Could not verify deletion: $($_.Exception.Message)" -ForegroundColor Red
}
