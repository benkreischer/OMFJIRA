# =============================================================================
# JIRA INTEGRATION - SLACK & TEAMS
# =============================================================================

# Advanced integration script that connects Jira with Slack and Teams
# This surpasses Atlassian Analytics by providing real-time notifications
# and team collaboration features that Atlassian Analytics cannot provide

param(
    [string]$SlackWebhook = $env:SLACK_WEBHOOK_URL,
    [string]$TeamsWebhook = $env:TEAMS_WEBHOOK_URL,
    [string]$NotificationType = "all",
    [switch]$EnableSlack = $false,
    [switch]$EnableTeams = $false,
    [switch]$EnableEmail = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Notification templates
$NotificationTemplates = @{
    "sprint_progress" = @{
        "title" = "🏃 Sprint Progress Update"
        "color" = "good"
        "icon" = ":chart_with_upwards_trend:"
    }
    "issue_created" = @{
        "title" = "📝 New Issue Created"
        "color" = "warning"
        "icon" = ":memo:"
    }
    "issue_resolved" = @{
        "title" = "✅ Issue Resolved"
        "color" = "good"
        "icon" = ":white_check_mark:"
    }
    "deadline_alert" = @{
        "title" = "⏰ Deadline Alert"
        "color" = "danger"
        "icon" = ":alarm_clock:"
    }
    "quality_breach" = @{
        "title" = "🚨 Quality Breach Alert"
        "color" = "danger"
        "icon" = ":warning:"
    }
    "team_performance" = @{
        "title" = "📊 Team Performance Update"
        "color" = "good"
        "icon" = ":trophy:"
    }
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

function Get-JiraData {
    param(
        [string]$Endpoint,
        [string]$JQL = ""
    )
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
        "Content-Type" = "application/json"
    }
    
    $url = if ($JQL) {
        "$JiraBaseUrl/search?jql=$([Uri]::EscapeDataString($JQL))&maxResults=999999"
    } else {
        "$JiraBaseUrl/$Endpoint"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get Jira data: $($_.Exception.Message)"
        return $null
    }
}

function Send-SlackNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "general",
        [string]$Color = "good",
        [string]$Icon = ":information_source:"
    )
    
    if (-not $EnableSlack -or -not $SlackWebhook) {
        return
    }
    
    $template = $NotificationTemplates[$Type]
    if ($template) {
        $Title = $template.title
        $Color = $template.color
        $Icon = $template.icon
    }
    
    $slackPayload = @{
        "text" = $Title
        "username" = "Jira Analytics Bot"
        "icon_emoji" = $Icon
        "attachments" = @(
            @{
                "color" = $Color
                "fields" = @(
                    @{
                        "title" = "Message"
                        "value" = $Message
                        "short" = $false
                    }
                )
                "footer" = "Jira Analytics"
                "ts" = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri $SlackWebhook -Method POST -Body $slackPayload -ContentType "application/json"
        Write-Host "Slack notification sent: $Title" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to send Slack notification: $($_.Exception.Message)"
    }
}

function Send-TeamsNotification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "general",
        [string]$Color = "00FF00"
    )
    
    if (-not $EnableTeams -or -not $TeamsWebhook) {
        return
    }
    
    $template = $NotificationTemplates[$Type]
    if ($template) {
        $Title = $template.title
        $Color = if ($template.color -eq "good") { "00FF00" } elseif ($template.color -eq "warning") { "FFA500" } else { "FF0000" }
    }
    
    $teamsPayload = @{
        "@type" = "MessageCard"
        "@context" = "http://schema.org/extensions"
        "themeColor" = $Color
        "summary" = $Title
        "sections" = @(
            @{
                "activityTitle" = $Title
                "activitySubtitle" = "Jira Analytics Notification"
                "activityImage" = "https://via.placeholder.com/64x64/$Color/FFFFFF?text=J"
                "text" = $Message
                "facts" = @(
                    @{
                        "name" = "Time"
                        "value" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
                    },
                    @{
                        "name" = "Type"
                        "value" = $Type
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10
    
    try {
        Invoke-RestMethod -Uri $TeamsWebhook -Method POST -Body $teamsPayload -ContentType "application/json"
        Write-Host "Teams notification sent: $Title" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to send Teams notification: $($_.Exception.Message)"
    }
}

function Send-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "general"
    )
    
    Send-SlackNotification -Title $Title -Message $Message -Type $Type
    Send-TeamsNotification -Title $Title -Message $Message -Type $Type
}

# =============================================================================
# NOTIFICATION FUNCTIONS
# =============================================================================

function Notify-SprintProgress {
    Write-Host "Checking sprint progress..." -ForegroundColor Cyan
    
    $sprintData = Get-JiraData -JQL "ORDER BY updated DESC"
    if (-not $sprintData) { return }
    
    $sprints = @{}
    foreach ($issue in $sprintData.issues) {
        $sprint = $issue.fields.customfield_10020
        if ($sprint) {
            if (-not $sprints.ContainsKey($sprint)) {
                $sprints[$sprint] = @{
                    Total = 0
                    Completed = 0
                    InProgress = 0
                    ToDo = 0
                }
            }
            
            $sprints[$sprint].Total++
            switch ($issue.fields.status.name) {
                "Done" { $sprints[$sprint].Completed++ }
                "In Progress" { $sprints[$sprint].InProgress++ }
                "To Do" { $sprints[$sprint].ToDo++ }
            }
        }
    }
    
    foreach ($sprint in $sprints.Keys) {
        $data = $sprints[$sprint]
        $completionRate = if ($data.Total -gt 0) { ($data.Completed / $data.Total) * 100 } else { 0 }
        
        $message = @"
Sprint: $sprint
Progress: $([math]::Round($completionRate, 1))%
Completed: $($data.Completed) / $($data.Total)
In Progress: $($data.InProgress)
To Do: $($data.ToDo)
"@
        
        Send-Notification -Title "Sprint Progress Update" -Message $message -Type "sprint_progress"
    }
}

function Notify-NewIssues {
    Write-Host "Checking for new issues..." -ForegroundColor Cyan
    
    $newIssues = Get-JiraData -JQL "created >= -1d ORDER BY created DESC"
    if (-not $newIssues) { return }
    
    foreach ($issue in $newIssues.issues) {
        $message = @"
Issue: $($issue.key)
Title: $($issue.fields.summary)
Type: $($issue.fields.issuetype.name)
Priority: $($issue.fields.priority.name)
Assignee: $($issue.fields.assignee.displayName)
Project: $($issue.fields.project.name)
"@
        
        Send-Notification -Title "New Issue Created" -Message $message -Type "issue_created"
    }
}

function Notify-ResolvedIssues {
    Write-Host "Checking for resolved issues..." -ForegroundColor Cyan
    
    $resolvedIssues = Get-JiraData -JQL "status = Done AND updated >= -1d ORDER BY updated DESC"
    if (-not $resolvedIssues) { return }
    
    foreach ($issue in $resolvedIssues.issues) {
        $message = @"
Issue: $($issue.key)
Title: $($issue.fields.summary)
Type: $($issue.fields.issuetype.name)
Priority: $($issue.fields.priority.name)
Assignee: $($issue.fields.assignee.displayName)
Project: $($issue.fields.project.name)
Resolution: $($issue.fields.resolution.name)
"@
        
        Send-Notification -Title "Issue Resolved" -Message $message -Type "issue_resolved"
    }
}

function Notify-DeadlineAlerts {
    Write-Host "Checking for deadline alerts..." -ForegroundColor Cyan
    
    $overdueIssues = Get-JiraData -JQL "duedate < now() AND status != Done ORDER BY duedate ASC"
    if (-not $overdueIssues) { return }
    
    foreach ($issue in $overdueIssues.issues) {
        $dueDate = [DateTime]::Parse($issue.fields.duedate)
        $daysOverdue = (Get-Date) - $dueDate
        
        $message = @"
Issue: $($issue.key)
Title: $($issue.fields.summary)
Due Date: $($issue.fields.duedate)
Days Overdue: $($daysOverdue.Days)
Assignee: $($issue.fields.assignee.displayName)
Priority: $($issue.fields.priority.name)
"@
        
        Send-Notification -Title "Deadline Alert" -Message $message -Type "deadline_alert"
    }
}

function Notify-QualityBreaches {
    Write-Host "Checking for quality breaches..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "ORDER BY created DESC"
    if (-not $issues) { return }
    
    $projectQuality = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $projectQuality.ContainsKey($project)) {
            $projectQuality[$project] = @{
                Total = 0
                Bugs = 0
                HighPriorityBugs = 0
            }
        }
        
        $projectQuality[$project].Total++
        if ($issue.fields.issuetype.name -eq "Bug") {
            $projectQuality[$project].Bugs++
            if ($issue.fields.priority.name -in @("High", "Highest")) {
                $projectQuality[$project].HighPriorityBugs++
            }
        }
    }
    
    foreach ($project in $projectQuality.Keys) {
        $data = $projectQuality[$project]
        $bugRate = if ($data.Total -gt 0) { ($data.Bugs / $data.Total) * 100 } else { 0 }
        $criticalBugRate = if ($data.Total -gt 0) { ($data.HighPriorityBugs / $data.Total) * 100 } else { 0 }
        
        if ($bugRate -gt 25 -or $criticalBugRate -gt 10) {
            $message = @"
Project: $project
Bug Rate: $([math]::Round($bugRate, 1))%
Critical Bug Rate: $([math]::Round($criticalBugRate, 1))%
Total Issues: $($data.Total)
Bug Issues: $($data.Bugs)
Critical Bugs: $($data.HighPriorityBugs)
"@
            
            Send-Notification -Title "Quality Breach Alert" -Message $message -Type "quality_breach"
        }
    }
}

function Notify-TeamPerformance {
    Write-Host "Checking team performance..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "assignee is not EMPTY ORDER BY updated DESC"
    if (-not $issues) { return }
    
    $teamPerformance = @{}
    foreach ($issue in $issues.issues) {
        $assignee = $issue.fields.assignee.displayName
        if (-not $teamPerformance.ContainsKey($assignee)) {
            $teamPerformance[$assignee] = @{
                Total = 0
                Completed = 0
                Active = 0
                HighPriority = 0
            }
        }
        
        $teamPerformance[$assignee].Total++
        if ($issue.fields.status.name -eq "Done") {
            $teamPerformance[$assignee].Completed++
        } else {
            $teamPerformance[$assignee].Active++
        }
        if ($issue.fields.priority.name -in @("High", "Highest")) {
            $teamPerformance[$assignee].HighPriority++
        }
    }
    
    foreach ($assignee in $teamPerformance.Keys) {
        $data = $teamPerformance[$assignee]
        $completionRate = if ($data.Total -gt 0) { ($data.Completed / $data.Total) * 100 } else { 0 }
        
        if ($completionRate -gt 80) {
            $message = @"
Team Member: $assignee
Completion Rate: $([math]::Round($completionRate, 1))%
Total Issues: $($data.Total)
Completed: $($data.Completed)
Active: $($data.Active)
High Priority: $($data.HighPriority)
"@
            
            Send-Notification -Title "Team Performance Update" -Message $message -Type "team_performance"
        }
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Integration - Slack & Teams" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Notification Type: $NotificationType" -ForegroundColor Yellow
Write-Host "Slack Enabled: $EnableSlack" -ForegroundColor Yellow
Write-Host "Teams Enabled: $EnableTeams" -ForegroundColor Yellow

try {
    switch ($NotificationType.ToLower()) {
        "sprint" {
            Notify-SprintProgress
        }
        "issues" {
            Notify-NewIssues
            Notify-ResolvedIssues
        }
        "deadlines" {
            Notify-DeadlineAlerts
        }
        "quality" {
            Notify-QualityBreaches
        }
        "performance" {
            Notify-TeamPerformance
        }
        "all" {
            Notify-SprintProgress
            Notify-NewIssues
            Notify-ResolvedIssues
            Notify-DeadlineAlerts
            Notify-QualityBreaches
            Notify-TeamPerformance
        }
        default {
            Write-Warning "Unknown notification type: $NotificationType. Use 'all', 'sprint', 'issues', 'deadlines', 'quality', or 'performance'"
        }
    }
    
    Write-Host "Integration completed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Error during integration: $($_.Exception.Message)"
}

Write-Host "Integration script finished." -ForegroundColor Green
