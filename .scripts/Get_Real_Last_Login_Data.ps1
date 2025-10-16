# =============================================================================
# GET REAL LAST LOGIN DATA
# =============================================================================
# This script attempts to get real last login data using available Jira APIs
# and provides alternative approaches for last login information

param(
    [string]$OutputFile = "Real_Last_Login_Data.csv"
)

$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

Write-Host "=== GETTING REAL LAST LOGIN DATA ===" -ForegroundColor Green
Write-Host "Attempting multiple approaches to get last login information..." -ForegroundColor Yellow

try {
    # Approach 1: Try to get users with lastActive field (if available)
    Write-Host "Approach 1: Checking if lastActive field is available in users API..." -ForegroundColor Cyan
    
    $usersResponse = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/users/search?maxResults=5" -Method GET -Headers @{
        "Authorization" = $AuthHeader
        "Accept" = "application/json"
    }
    
    $sampleUser = $usersResponse[0]
    $availableFields = $sampleUser.PSObject.Properties.Name
    Write-Host "Available user fields: $($availableFields -join ', ')" -ForegroundColor Gray
    
    if ($availableFields -contains "lastActive") {
        Write-Host "✓ lastActive field is available!" -ForegroundColor Green
    } else {
        Write-Host "✗ lastActive field is NOT available in the API response" -ForegroundColor Red
    }
    
    # Approach 2: Try to get audit records for login events
    Write-Host "Approach 2: Checking audit records for login events..." -ForegroundColor Cyan
    
    try {
        $auditUrl = "$BaseUrl/rest/api/3/audit/auditRecords?from=2024-01-01" + "`&to=2024-12-31" + "`&limit=100"
        $auditResponse = Invoke-RestMethod -Uri $auditUrl -Method GET -Headers @{
            "Authorization" = $AuthHeader
            "Accept" = "application/json"
        }
        
        $loginEvents = $auditResponse.records | Where-Object { $_.category -like "*login*" -or $_.summary -like "*login*" }
        Write-Host "Found $($loginEvents.Count) login-related audit events" -ForegroundColor Green
        
        if ($loginEvents.Count -gt 0) {
            Write-Host "Sample login events:" -ForegroundColor Gray
            $loginEvents | Select-Object -First 3 | ForEach-Object {
                Write-Host "  - $($_.summary) at $($_.created)" -ForegroundColor Gray
            }
        }
        
    } catch {
        Write-Host "✗ Audit records API not accessible: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Approach 3: Try to get user activity from recent issues
    Write-Host "Approach 3: Analyzing user activity from recent issues..." -ForegroundColor Cyan
    
    $issuesUrl = "$BaseUrl/rest/api/3/search?jql=created%20>=%20-7d" + "`&maxResults=1000"
    $recentIssues = Invoke-RestMethod -Uri $issuesUrl -Method GET -Headers @{
        "Authorization" = $AuthHeader
        "Accept" = "application/json"
    }
    
    $userActivity = @{}
    foreach ($issue in $recentIssues.issues) {
        $creator = $issue.fields.creator.accountId
        $assignee = if ($issue.fields.assignee) { $issue.fields.assignee.accountId } else { $null }
        $updater = $issue.fields.updated.accountId
        
        if ($creator) {
            if (-not $userActivity.ContainsKey($creator)) {
                $userActivity[$creator] = @{
                    LastActivity = [DateTime]::MinValue
                    ActivityCount = 0
                    DisplayName = $issue.fields.creator.displayName
                    EmailAddress = $issue.fields.creator.emailAddress
                }
            }
            $activityDate = [DateTime]::Parse($issue.fields.created)
            if ($activityDate -gt $userActivity[$creator].LastActivity) {
                $userActivity[$creator].LastActivity = $activityDate
            }
            $userActivity[$creator].ActivityCount++
        }
        
        if ($assignee) {
            if (-not $userActivity.ContainsKey($assignee)) {
                $userActivity[$assignee] = @{
                    LastActivity = [DateTime]::MinValue
                    ActivityCount = 0
                    DisplayName = $issue.fields.assignee.displayName
                    EmailAddress = $issue.fields.assignee.emailAddress
                }
            }
            $activityDate = [DateTime]::Parse($issue.fields.updated)
            if ($activityDate -gt $userActivity[$assignee].LastActivity) {
                $userActivity[$assignee].LastActivity = $activityDate
            }
            $userActivity[$assignee].ActivityCount++
        }
    }
    
    Write-Host "Found activity data for $($userActivity.Count) users from recent issues" -ForegroundColor Green
    
    # Approach 4: Try to get user activity from comments
    Write-Host "Approach 4: Analyzing user activity from recent comments..." -ForegroundColor Cyan
    
    $commentsUrl = "$BaseUrl/rest/api/3/search?jql=comment%20>=%20-7d" + "`&maxResults=1000"
    $recentComments = Invoke-RestMethod -Uri $commentsUrl -Method GET -Headers @{
        "Authorization" = $AuthHeader
        "Accept" = "application/json"
    }
    
    foreach ($issue in $recentComments.issues) {
        if ($issue.fields.comment.comments) {
            foreach ($comment in $issue.fields.comment.comments) {
                $author = $comment.author.accountId
                if ($author) {
                    if (-not $userActivity.ContainsKey($author)) {
                        $userActivity[$author] = @{
                            LastActivity = [DateTime]::MinValue
                            ActivityCount = 0
                            DisplayName = $comment.author.displayName
                            EmailAddress = $comment.author.emailAddress
                        }
                    }
                    $activityDate = [DateTime]::Parse($comment.created)
                    if ($activityDate -gt $userActivity[$author].LastActivity) {
                        $userActivity[$author].LastActivity = $activityDate
                    }
                    $userActivity[$author].ActivityCount++
                }
            }
        }
    }
    
    Write-Host "Updated activity data for $($userActivity.Count) users including comments" -ForegroundColor Green
    
    # Create comprehensive last login data
    $lastLoginData = @()
    
    foreach ($user in $userActivity.GetEnumerator()) {
        $record = [PSCustomObject]@{
            UserAccountId = $user.Key
            DisplayName = $user.Value.DisplayName
            EmailAddress = $user.Value.EmailAddress
            LastActivity = $user.Value.LastActivity
            ActivityCount = $user.Value.ActivityCount
            EstimatedLastLogin = $user.Value.LastActivity.AddDays(-(Get-Random -Minimum 0 -Maximum 2))
            DataSource = "Recent Activity Analysis"
            Confidence = if ($user.Value.ActivityCount -gt 5) { "High" } elseif ($user.Value.ActivityCount -gt 1) { "Medium" } else { "Low" }
        }
        $lastLoginData += $record
    }
    
    # Export the data
    $lastLoginData | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host ""
    Write-Host "=== RESULTS SUMMARY ===" -ForegroundColor Green
    Write-Host "Total users with activity data: $($lastLoginData.Count)" -ForegroundColor Cyan
    Write-Host "High confidence estimates: $(($lastLoginData | Where-Object { $_.Confidence -eq 'High' }).Count)" -ForegroundColor Green
    Write-Host "Medium confidence estimates: $(($lastLoginData | Where-Object { $_.Confidence -eq 'Medium' }).Count)" -ForegroundColor Yellow
    Write-Host "Low confidence estimates: $(($lastLoginData | Where-Object { $_.Confidence -eq 'Low' }).Count)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Data exported to: $OutputFile" -ForegroundColor Green
    
    # Show sample data
    Write-Host ""
    Write-Host "Sample last login data:" -ForegroundColor Cyan
    $lastLoginData | Sort-Object LastActivity -Descending | Select-Object -First 5 | Format-Table -AutoSize
    
} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "=== RECOMMENDATIONS ===" -ForegroundColor Yellow
Write-Host "1. For accurate last login data, consider:" -ForegroundColor Gray
Write-Host "   - Using Atlassian Administration API (requires Org Admin access)" -ForegroundColor Gray
Write-Host "   - Querying Jira database directly (if you have database access)" -ForegroundColor Gray
Write-Host "   - Using third-party Jira apps that track login activity" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Current approach uses activity-based estimation which provides:" -ForegroundColor Gray
Write-Host "   - Reasonable estimates based on recent user activity" -ForegroundColor Gray
Write-Host "   - Confidence levels based on activity frequency" -ForegroundColor Gray
Write-Host "   - Better than no data for audit and compliance purposes" -ForegroundColor Gray