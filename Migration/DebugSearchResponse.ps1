# Debug the search API response to see the exact structure
. ".\src\_common.ps1"

# Load parameters
$p = Read-JsonFile -Path ".\projects\DEP\parameters.json"

# Setup target environment
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok
$tgtKey = $p.TargetEnvironment.ProjectKey

Write-Host "Debugging search API response for project: $tgtKey"

$searchUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
$searchBody = @{
    jql = "project = $tgtKey"
    maxResults = 5  # Just get a few issues to debug
    fields = @("id", "key", "summary")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "✅ API call successful!"
    Write-Host "Response properties: $($response.PSObject.Properties.Name -join ', ')"
    Write-Host "Issues returned: $($response.issues.Count)"
    
    if ($response.issues.Count -gt 0) {
        Write-Host ""
        Write-Host "First issue structure:"
        $firstIssue = $response.issues[0]
        Write-Host "Issue properties: $($firstIssue.PSObject.Properties.Name -join ', ')"
        
        if ($firstIssue.PSObject.Properties.Name -contains "fields") {
            Write-Host "Fields properties: $($firstIssue.fields.PSObject.Properties.Name -join ', ')"
        }
        
        Write-Host ""
        Write-Host "Full first issue JSON:"
        Write-Host ($firstIssue | ConvertTo-Json -Depth 3)
    }
} catch {
    Write-Host "❌ API call failed: $($_.Exception.Message)" -ForegroundColor Red
}
