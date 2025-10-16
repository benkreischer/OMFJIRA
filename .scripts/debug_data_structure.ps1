# Debug script to check data structure
$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

Write-Host "Testing user data structure..." -ForegroundColor Yellow
$users = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/users/search?maxResults=3" -Method GET -Headers @{
    "Authorization" = $AuthHeader
    "Accept" = "application/json"
}

Write-Host "Sample user fields:" -ForegroundColor Cyan
$users[0] | Get-Member | Select-Object Name, Type | Format-Table

Write-Host "Sample user data:" -ForegroundColor Cyan
$users[0] | ConvertTo-Json -Depth 2

Write-Host "Testing issue data structure..." -ForegroundColor Yellow  
$issues = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/search?jql=created%20>=%20-7d&maxResults=3" -Method GET -Headers @{
    "Authorization" = $AuthHeader
    "Accept" = "application/json"
}

Write-Host "Sample issue fields:" -ForegroundColor Cyan
$issues.issues[0].fields | Get-Member | Select-Object Name, Type | Format-Table

Write-Host "Sample issue data:" -ForegroundColor Cyan
$issues.issues[0].fields | ConvertTo-Json -Depth 2
