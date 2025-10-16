# Debug script to check accountId matching
$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

Write-Host "Checking user accountIds..." -ForegroundColor Yellow
$users = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/users/search?maxResults=5" -Method GET -Headers @{
    "Authorization" = $AuthHeader
    "Accept" = "application/json"
}

foreach ($user in $users) {
    Write-Host "User: $($user.displayName) - AccountId: $($user.accountId)" -ForegroundColor Cyan
}

Write-Host "Checking issue accountIds..." -ForegroundColor Yellow
$issues = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/search?jql=created%20>=%20-7d&maxResults=5" -Method GET -Headers @{
    "Authorization" = $AuthHeader
    "Accept" = "application/json"
}

foreach ($issue in $issues.issues) {
    Write-Host "Issue: $($issue.key) - Creator: $($issue.fields.creator.displayName) ($($issue.fields.creator.accountId))" -ForegroundColor Green
    if ($issue.fields.assignee) {
        Write-Host "  Assignee: $($issue.fields.assignee.displayName) ($($issue.fields.assignee.accountId))" -ForegroundColor Green
    }
}

Write-Host "Checking for matches..." -ForegroundColor Yellow
$userAccountIds = $users | ForEach-Object { $_.accountId }
$issueCreatorIds = $issues.issues | ForEach-Object { $_.fields.creator.accountId }
$issueAssigneeIds = $issues.issues | Where-Object { $_.fields.assignee } | ForEach-Object { $_.fields.assignee.accountId }

$matches = $userAccountIds | Where-Object { $_ -in $issueCreatorIds -or $_ -in $issueAssigneeIds }
Write-Host "Matching accountIds: $($matches.Count)" -ForegroundColor Cyan
$matches | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
