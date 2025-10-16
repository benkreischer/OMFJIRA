# Check issue count using project API
. ".\src\_common.ps1"

# Load parameters
$p = Read-JsonFile -Path ".\projects\DEP\parameters.json"

# Setup target environment
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok
$tgtKey = $p.TargetEnvironment.ProjectKey

Write-Host "Checking project info for: $tgtKey"

# Try to get project info which should include issue count
$projectUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey"

try {
    $project = Invoke-RestMethod -Method GET -Uri $projectUrl -Headers $tgtHdr -ErrorAction Stop
    Write-Host "✅ Project found: $($project.name)" -ForegroundColor Green
    Write-Host "Project key: $($project.key)"
    Write-Host "Project ID: $($project.id)"
    
    # Check if there's an issue count in the project info
    if ($project.PSObject.Properties.Name -contains "issueTypes") {
        Write-Host "Issue types: $($project.issueTypes.Count)"
    }
    
} catch {
    Write-Host "❌ Failed to get project info: $($_.Exception.Message)" -ForegroundColor Red
}

# Try a simple GET request to see if we can access the project at all
Write-Host ""
Write-Host "Trying to access project directly..."

try {
    $projectIssuesUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey/issues"
    $response = Invoke-RestMethod -Method GET -Uri $projectIssuesUrl -Headers $tgtHdr -ErrorAction Stop
    Write-Host "✅ Direct project access works!" -ForegroundColor Green
    Write-Host "Response: $($response | ConvertTo-Json -Depth 2)"
} catch {
    Write-Host "❌ Direct project access failed: $($_.Exception.Message)" -ForegroundColor Red
}
