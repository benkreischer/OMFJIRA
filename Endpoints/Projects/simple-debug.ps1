# Simple Debug Script
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
. $HelperPath

$Params = Get-EndpointParameters
$BaseUrl = $Params.BaseUrl
$Headers = Get-RequestHeaders -Parameters $Params
$MaxResults = $Params.MaxResults

Write-Host "MaxResults: $MaxResults"

# Test first page
$url1 = "$BaseUrl/rest/api/3/project/search?startAt=0&maxResults=$MaxResults"
$resp1 = Invoke-RestMethod -Uri $url1 -Headers $Headers -Method Get

Write-Host "Page 1 - Count: $($resp1.values.Count), Total: $($resp1.total), IsLast: $($resp1.isLast)"
Write-Host "Should continue? $($resp1.values.Count -eq $MaxResults -and $resp1.isLast -ne `$true)"

# Test second page
$url2 = "$BaseUrl/rest/api/3/project/search?startAt=100&maxResults=$MaxResults"
$resp2 = Invoke-RestMethod -Uri $url2 -Headers $Headers -Method Get

Write-Host "Page 2 - Count: $($resp2.values.Count), Total: $($resp2.total), IsLast: $($resp2.isLast)"
Write-Host "Should continue? $($resp2.values.Count -eq $MaxResults -and $resp2.isLast -ne `$true)"
