# Check current issue count in DEP1 project
. ".\src\_common.ps1"

# Load parameters
$p = Read-JsonFile -Path ".\projects\DEP\parameters.json"

# Setup target environment
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok
$tgtKey = $p.TargetEnvironment.ProjectKey

Write-Host "Checking current issue count in project: $tgtKey"

# Try different API endpoints to see which one works
$endpoints = @(
    "/rest/api/3/search",
    "/rest/api/3/search/jql"
)

foreach ($endpoint in $endpoints) {
    Write-Host ""
    Write-Host "Testing endpoint: $endpoint" -ForegroundColor Yellow
    
    $searchUrl = "$($tgtBase.TrimEnd('/'))$endpoint"
    $searchBody = @{
        jql = "project = $tgtKey"
        maxResults = 1
        fields = @("id")
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
        Write-Host "✅ SUCCESS! Total issues: $($response.total)" -ForegroundColor Green
        break
    } catch {
        Write-Host "❌ Failed: $($_.Exception.Response.StatusCode) - $($_.Exception.Message)" -ForegroundColor Red
    }
}
