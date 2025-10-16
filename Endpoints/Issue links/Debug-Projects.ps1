# Debug script to see project structure
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

$AuthHeader = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

$ProjectsUrl = "$BaseUrl/rest/api/3/project"
Write-Output "Testing project API..."

try {
    $ProjectsResponse = Invoke-RestMethod -Uri "${ProjectsUrl} + "?startAt=" + $Params.QueryParameters.DefaultStartAt&maxResults=5" -Method Get -Headers $AuthHeader
    Write-Output "SUCCESS: Retrieved $($ProjectsResponse.values.Count) projects"
    
    Write-Output "First project structure:"
    $ProjectsResponse.values[0] | ConvertTo-Json -Depth 3
    
    Write-Output "Project keys:"
    foreach ($project in $ProjectsResponse.values) {
        Write-Output "  Key: '$($project.key)', Name: '$($project.name)'"
    }
} catch {
    Write-Output "ERROR: $($_.Exception.Message)"
}

