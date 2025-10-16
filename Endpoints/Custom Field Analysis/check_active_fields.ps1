$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

$AuthHeader = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))
    "Accept" = "application/json"
}

# Get a sample issue to see what custom fields are actually in use
$Response = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/ORL-8004" -Headers $AuthHeader -Method Get

# Show all custom fields on this issue
Write-Host "Custom fields found on issue ORL-8004:" -ForegroundColor Cyan
$Response.fields.PSObject.Properties | Where-Object { $_.Name -match "^customfield_" } | ForEach-Object {
    Write-Host "$($_.Name): $($_.Value)" -ForegroundColor Green
}
