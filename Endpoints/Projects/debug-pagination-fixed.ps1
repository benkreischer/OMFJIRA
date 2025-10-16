# Debug Pagination Script
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

$Params = Get-EndpointParameters
$BaseUrl = $Params.BaseUrl
$Headers = Get-RequestHeaders -Parameters $Params
$MaxResults = $Params.MaxResults

Write-Host "Testing pagination with MaxResults: $MaxResults"
$AllProjects = @()
$StartAt = 0

do {
    $fullUrl = "$BaseUrl/rest/api/3/project/search?startAt=$StartAt&maxResults=$MaxResults&orderBy=key&expand=lead,description,issueTypes,url,projectKeys,permissions,insight"
    
    Write-Host "`nCalling: $fullUrl"
    
    $response = Invoke-RestMethod -Uri $fullUrl -Method GET -Headers $Headers
    
    Write-Host "Response - Count: $($response.values.Count), Total: $($response.total), IsLast: $($response.isLast)"
    Write-Host "Condition check - Count eq MaxResults: $($response.values.Count -eq $MaxResults)"
    Write-Host "Condition check - IsLast ne true: $($response.isLast -ne `$true)"
    Write-Host "Combined condition: $(($response.values.Count -eq $MaxResults -and $response.isLast -ne `$true))"
    
    $AllProjects += $response.values
    $StartAt += $MaxResults
    
    Write-Host "Total projects collected so far: $($AllProjects.Count)"
    
} while ($response.values.Count -eq $MaxResults -and $response.isLast -ne `$true)

Write-Host "`nFinal result: $($AllProjects.Count) projects collected"
