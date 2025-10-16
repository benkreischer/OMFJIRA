# Check the actual issue count in DEP1 project
. ".\src\_common.ps1"

# Load parameters
$p = Read-JsonFile -Path ".\projects\DEP\parameters.json"

# Setup target environment
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok
$tgtKey = $p.TargetEnvironment.ProjectKey

Write-Host "Checking actual issue count in project: $tgtKey"

# Search with a small limit to get the total count
$searchUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
$searchBody = @{
    jql = "project = $tgtKey"
    maxResults = 1
    fields = @("id")
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "✅ Search successful!"
    Write-Host "Response properties: $($response.PSObject.Properties.Name -join ', ')"
    
    # Check if there's a total count property
    if ($response.PSObject.Properties.Name -contains "total") {
        Write-Host "Total issues in project: $($response.total)"
    } else {
        Write-Host "No 'total' property found - need to count manually"
        
        # Count by getting all issues with pagination
        $totalCount = 0
        $nextPageToken = $null
        
        do {
            $countBody = @{
                jql = "project = $tgtKey"
                maxResults = 100
                fields = @("id")
            }
            
            if ($nextPageToken) {
                $countBody.nextPageToken = $nextPageToken
            }
            
            $countResponse = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body ($countBody | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
            $totalCount += $countResponse.issues.Count
            Write-Host "  Fetched $($countResponse.issues.Count) issues (total so far: $totalCount)"
            
            $nextPageToken = if ($countResponse.PSObject.Properties.Name -contains "nextPageToken") { $countResponse.nextPageToken } else { $null }
            
        } while ($nextPageToken)
        
        Write-Host "Actual total issues in project: $totalCount"
    }
    
} catch {
    Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
}
