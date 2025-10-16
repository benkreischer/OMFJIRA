# =============================================================================
# JIRA ALERT SYSTEM
# =============================================================================

# Advanced alert system that provides intelligent notifications and escalation
# This system surpasses Atlassian Analytics with smart alerting

param(
    [string]$AlertType = "all",
    [switch]$EnableSlack = $false,
    [switch]$EnableTeams = $false,
    [switch]$EnableEmail = $false,
    [switch]$EnableSMS = $false,
    [switch]$EnableWebhook = $false,
    [string]$WebhookUrl = "",
    [switch]$EnableEscalation = $false,
    [int]$CheckInterval = 60
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Alert configuration
$AlertConfig = @{
    "check_interval" = $CheckInterval
    "escalation_enabled" = $EnableEscalation
    "channels" = @{
        "slack" = $EnableSlack
        "teams" = $EnableTeams
        "email" = $EnableEmail
        "sms" = $EnableSMS
        "webhook" = $EnableWebhook
    }
    "webhook_url" = $WebhookUrl
    "thresholds" = @{
        "sprint_completion" = 60
        "resource_overload" = 80
        "quality_breach" = 25
        "deadline_risk" = 20
        "performance_anomaly" = 3.0
        "bug_rate" = 15
        "reopened_rate" = 10
        "technical_debt" = 20
    }
    "escalation_rules" = @{
        "critical" = @{
            "immediate" = $true
            "channels" = @("slack", "teams", "email", "sms")
            "escalate_after" = 0
        }
        "high" = @{
            "immediate" = $true
            "channels" = @("slack", "teams", "email")
            "escalate_after" = 15
        }
        "medium" = @{
            "immediate" = $false
            "channels" = @("slack", "teams")
            "escalate_after" = 30
        }
        "low" = @{
            "immediate" = $false
            "channels" = @("slack")
            "escalate_after" = 60
        }
    }
}

# Alert history and state
$AlertState = @{
    "last_check" = Get-Date
    "alert_history" = @()
    "active_alerts" = @{}
    "escalation_timers" = @{}
    "suppression_rules" = @()
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

function Send-Alert {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Severity = "Medium",
        [string]$Type = "General",
        [string]$Project = "",
        [string]$Assignee = "",
        [hashtable]$Metadata = @{}
    )
    
    $timestamp = Get-Date
    $alertId = "$Type-$Project-$Assignee-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    $alert = @{
        "id" = $alertId
        "timestamp" = $timestamp
        "title" = $Title
        "message" = $Message
        "severity" = $Severity
        "type" = $Type
        "project" = $Project
        "assignee" = $Assignee
        "metadata" = $Metadata
        "status" = "Active"
        "escalated" = $false
        "acknowledged" = $false
        "resolved" = $false
    }
    
    # Check if alert should be suppressed
    if (Test-AlertSuppression -Alert $alert) {
        Write-Host "Alert suppressed: $Title" -ForegroundColor Yellow
        return
    }
    
    # Add to alert history
    $AlertState.alert_history += $alert
    $AlertState.active_alerts[$alertId] = $alert
    
    # Initialize escalation timer
    if ($AlertConfig.escalation_enabled) {
        $AlertState.escalation_timers[$alertId] = $timestamp
    }
    
    # Send alert through configured channels
    $escalationRule = $AlertConfig.escalation_rules[$Severity.ToLower()]
    if ($escalationRule.immediate) {
        Send-AlertToChannels -Alert $alert -Channels $escalationRule.channels
    }
    
    Write-Host "🚨 ALERT SENT: $Title ($Severity)" -ForegroundColor Red
}

function Test-AlertSuppression {
    param([hashtable]$Alert)
    
    foreach ($rule in $AlertState.suppression_rules) {
        if ($rule.type -eq $Alert.type -and 
            $rule.project -eq $Alert.project -and 
            $rule.severity -eq $Alert.severity -and
            (Get-Date) -lt $rule.until) {
            return $true
        }
    }
    return $false
}

function Send-AlertToChannels {
    param(
        [hashtable]$Alert,
        [array]$Channels
    )
    
    foreach ($channel in $Channels) {
        switch ($channel.ToLower()) {
            "slack" {
                Send-SlackAlert -Alert $Alert
            }
            "teams" {
                Send-TeamsAlert -Alert $Alert
            }
            "email" {
                Send-EmailAlert -Alert $Alert
            }
            "sms" {
                Send-SMSAlert -Alert $Alert
            }
            "webhook" {
                Send-WebhookAlert -Alert $Alert
            }
        }
    }
}

function Send-SlackAlert {
    param([hashtable]$Alert)
    
    if (-not $AlertConfig.channels.slack) { return }
    
    $slackWebhook = $env:SLACK_WEBHOOK_URL
    if (-not $slackWebhook) {
        Write-Warning "Slack webhook URL not configured"
        return
    }
    
    $color = switch ($Alert.severity.ToLower()) {
        "critical" { "danger" }
        "high" { "warning" }
        "medium" { "good" }
        "low" { "#36a64f" }
        default { "good" }
    }
    
    $payload = @{
        "text" = "🚨 Jira Alert: $($Alert.title)"
        "attachments" = @(
            @{
                "color" = $color
                "fields" = @(
                    @{
                        "title" = "Message"
                        "value" = $Alert.message
                        "short" = $false
                    },
                    @{
                        "title" = "Severity"
                        "value" = $Alert.severity.ToUpper()
                        "short" = $true
                    },
                    @{
                        "title" = "Type"
                        "value" = $Alert.type
                        "short" = $true
                    },
                    @{
                        "title" = "Project"
                        "value" = $Alert.project
                        "short" = $true
                    },
                    @{
                        "title" = "Time"
                        "value" = $Alert.timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                        "short" = $true
                    }
                )
            }
        )
    }
    
    try {
        $json = $payload | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $slackWebhook -Method POST -Body $json -ContentType "application/json"
        Write-Host "Slack alert sent: $($Alert.title)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send Slack alert: $($_.Exception.Message)"
    }
}

function Send-TeamsAlert {
    param([hashtable]$Alert)
    
    if (-not $AlertConfig.channels.teams) { return }
    
    $teamsWebhook = $env:TEAMS_WEBHOOK_URL
    if (-not $teamsWebhook) {
        Write-Warning "Teams webhook URL not configured"
        return
    }
    
    $color = switch ($Alert.severity.ToLower()) {
        "critical" { "FF0000" }
        "high" { "FFA500" }
        "medium" { "FFFF00" }
        "low" { "00FF00" }
        default { "00FF00" }
    }
    
    $payload = @{
        "@type" = "MessageCard"
        "@context" = "http://schema.org/extensions"
        "themeColor" = $color
        "summary" = "Jira Alert: $($Alert.title)"
        "sections" = @(
            @{
                "activityTitle" = "🚨 $($Alert.title)"
                "activitySubtitle" = $Alert.message
                "facts" = @(
                    @{
                        "name" = "Severity"
                        "value" = $Alert.severity.ToUpper()
                    },
                    @{
                        "name" = "Type"
                        "value" = $Alert.type
                    },
                    @{
                        "name" = "Project"
                        "value" = $Alert.project
                    },
                    @{
                        "name" = "Time"
                        "value" = $Alert.timestamp.ToString("yyyy-MM-dd HH:mm:ss")
                    }
                )
            }
        )
    }
    
    try {
        $json = $payload | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $teamsWebhook -Method POST -Body $json -ContentType "application/json"
        Write-Host "Teams alert sent: $($Alert.title)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send Teams alert: $($_.Exception.Message)"
    }
}

function Send-EmailAlert {
    param([hashtable]$Alert)
    
    if (-not $AlertConfig.channels.email) { return }
    
    $smtpServer = $env:SMTP_SERVER
    $smtpPort = $env:SMTP_PORT
    $smtpUser = $env:SMTP_USER
    $smtpPass = $env:SMTP_PASS
    $emailTo = $env:EMAIL_TO
    
    if (-not $smtpServer -or -not $emailTo) {
        Write-Warning "Email configuration not complete"
        return
    }
    
    $subject = "[$($Alert.severity.ToUpper())] Jira Alert: $($Alert.title)"
    $body = @"
Jira Alert Notification

Title: $($Alert.title)
Message: $($Alert.message)
Severity: $($Alert.severity)
Type: $($Alert.type)
Project: $($Alert.project)
Assignee: $($Alert.assignee)
Time: $($Alert.timestamp.ToString("yyyy-MM-dd HH:mm:ss"))

Metadata:
$($Alert.metadata | ConvertTo-Json -Depth 3)

---
This is an automated alert from the Jira Analytics System.
"@
    
    try {
        $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtp.EnableSsl = $true
        $smtp.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPass)
        
        $mail = New-Object System.Net.Mail.MailMessage
        $mail.From = $smtpUser
        $mail.To.Add($emailTo)
        $mail.Subject = $subject
        $mail.Body = $body
        
        $smtp.Send($mail)
        $smtp.Dispose()
        
        Write-Host "Email alert sent: $($Alert.title)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send email alert: $($_.Exception.Message)"
    }
}

function Send-SMSAlert {
    param([hashtable]$Alert)
    
    if (-not $AlertConfig.channels.sms) { return }
    
    $twilioSid = $env:TWILIO_SID
    $twilioToken = $env:TWILIO_TOKEN
    $twilioFrom = $env:TWILIO_FROM
    $twilioTo = $env:TWILIO_TO
    
    if (-not $twilioSid -or -not $twilioToken -or -not $twilioFrom -or -not $twilioTo) {
        Write-Warning "SMS configuration not complete"
        return
    }
    
    $message = "[$($Alert.severity.ToUpper())] $($Alert.title): $($Alert.message)"
    
    try {
        $uri = "https://api.twilio.com/2010-04-01/Accounts/$twilioSid/Messages.json"
        $body = @{
            "From" = $twilioFrom
            "To" = $twilioTo
            "Body" = $message
        }
        
        $cred = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$twilioSid`:$twilioToken"))
        $headers = @{ "Authorization" = "Basic $cred" }
        
        Invoke-RestMethod -Uri $uri -Method POST -Body $body -Headers $headers
        Write-Host "SMS alert sent: $($Alert.title)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send SMS alert: $($_.Exception.Message)"
    }
}

function Send-WebhookAlert {
    param([hashtable]$Alert)
    
    if (-not $AlertConfig.channels.webhook -or -not $AlertConfig.webhook_url) { return }
    
    try {
        $json = $Alert | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $AlertConfig.webhook_url -Method POST -Body $json -ContentType "application/json"
        Write-Host "Webhook alert sent: $($Alert.title)" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to send webhook alert: $($_.Exception.Message)"
    }
}

function Process-Escalation {
    if (-not $AlertConfig.escalation_enabled) { return }
    
    $now = Get-Date
    foreach ($alertId in $AlertState.escalation_timers.Keys) {
        $alert = $AlertState.active_alerts[$alertId]
        if (-not $alert -or $alert.acknowledged -or $alert.resolved) { continue }
        
        $escalationRule = $AlertConfig.escalation_rules[$alert.severity.ToLower()]
        $escalationTime = $AlertState.escalation_timers[$alertId].AddMinutes($escalationRule.escalate_after)
        
        if ($now -ge $escalationTime -and -not $alert.escalated) {
            $alert.escalated = $true
            $alert.severity = switch ($alert.severity.ToLower()) {
                "low" { "Medium" }
                "medium" { "High" }
                "high" { "Critical" }
                default { "Critical" }
            }
            
            $escalatedRule = $AlertConfig.escalation_rules[$alert.severity.ToLower()]
            Send-AlertToChannels -Alert $alert -Channels $escalatedRule.channels
            
            Write-Host "Alert escalated: $($alert.title) -> $($alert.severity)" -ForegroundColor Red
        }
    }
}

# =============================================================================
# ALERT DETECTION FUNCTIONS
# =============================================================================

function Check-SprintAlerts {
    Write-Host "Checking sprint alerts..." -ForegroundColor Cyan
    
    $sprintData = Get-JiraData -JQL "ORDER BY updated DESC"
    if (-not $sprintData) { return }
    
    $sprints = @{}
    foreach ($issue in $sprintData.issues) {
        $sprint = $issue.fields.customfield_10020
        if ($sprint) {
            if (-not $sprints.ContainsKey($sprint)) {
                $sprints[$sprint] = @{
                    "Total" = 0
                    "Completed" = 0
                    "Overdue" = 0
                    "HighPriority" = 0
                }
            }
            
            $sprints[$sprint].Total++
            if ($issue.fields.status.name -eq "Done") {
                $sprints[$sprint].Completed++
            }
            if ($issue.fields.duedate -and [DateTime]::Parse($issue.fields.duedate) -lt (Get-Date) -and $issue.fields.status.name -ne "Done") {
                $sprints[$sprint].Overdue++
            }
            if ($issue.fields.priority.name -in @("High", "Highest")) {
                $sprints[$sprint].HighPriority++
            }
        }
    }
    
    foreach ($sprint in $sprints.Keys) {
        $data = $sprints[$sprint]
        $completionRate = if ($data.Total -gt 0) { ($data.Completed / $data.Total) * 100 } else { 0 }
        
        if ($completionRate -lt $AlertConfig.thresholds.sprint_completion) {
            Send-Alert -Title "Sprint at Risk" -Message "Sprint '$sprint' completion rate is $([math]::Round($completionRate, 1))% - below threshold of $($AlertConfig.thresholds.sprint_completion)%" -Severity "High" -Type "Sprint" -Project $sprint -Metadata @{ "completion_rate" = $completionRate; "total_issues" = $data.Total; "completed" = $data.Completed }
        }
        
        if ($data.Overdue -gt 0) {
            Send-Alert -Title "Sprint Overdue Issues" -Message "Sprint '$sprint' has $($data.Overdue) overdue issues" -Severity "Medium" -Type "Sprint" -Project $sprint -Metadata @{ "overdue_count" = $data.Overdue }
        }
        
        if ($data.HighPriority -gt 5) {
            Send-Alert -Title "High Priority Sprint Issues" -Message "Sprint '$sprint' has $($data.HighPriority) high priority issues" -Severity "Medium" -Type "Sprint" -Project $sprint -Metadata @{ "high_priority_count" = $data.HighPriority }
        }
    }
}

function Check-ResourceAlerts {
    Write-Host "Checking resource alerts..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "assignee is not EMPTY ORDER BY updated DESC"
    if (-not $issues) { return }
    
    $resourceData = @{}
    foreach ($issue in $issues.issues) {
        $assignee = $issue.fields.assignee.displayName
        if (-not $resourceData.ContainsKey($assignee)) {
            $resourceData[$assignee] = @{
                "Total" = 0
                "Active" = 0
                "HighPriority" = 0
                "Overdue" = 0
            }
        }
        
        $resourceData[$assignee].Total++
        if ($issue.fields.status.name -ne "Done") {
            $resourceData[$assignee].Active++
        }
        if ($issue.fields.priority.name -in @("High", "Highest")) {
            $resourceData[$assignee].HighPriority++
        }
        if ($issue.fields.duedate -and [DateTime]::Parse($issue.fields.duedate) -lt (Get-Date) -and $issue.fields.status.name -ne "Done") {
            $resourceData[$assignee].Overdue++
        }
    }
    
    foreach ($assignee in $resourceData.Keys) {
        $data = $resourceData[$assignee]
        $utilizationRate = if ($data.Total -gt 0) { ($data.Active / $data.Total) * 100 } else { 0 }
        
        if ($utilizationRate -gt $AlertConfig.thresholds.resource_overload) {
            Send-Alert -Title "Resource Overload" -Message "Team member '$assignee' utilization rate is $([math]::Round($utilizationRate, 1))% - above threshold of $($AlertConfig.thresholds.resource_overload)%" -Severity "High" -Type "Resource" -Assignee $assignee -Metadata @{ "utilization_rate" = $utilizationRate; "active_issues" = $data.Active; "total_issues" = $data.Total }
        }
        
        if ($data.Overdue -gt 3) {
            Send-Alert -Title "Resource Overdue Issues" -Message "Team member '$assignee' has $($data.Overdue) overdue issues" -Severity "Medium" -Type "Resource" -Assignee $assignee -Metadata @{ "overdue_count" = $data.Overdue }
        }
        
        if ($data.HighPriority -gt 5) {
            Send-Alert -Title "High Priority Workload" -Message "Team member '$assignee' has $($data.HighPriority) high priority issues" -Severity "Medium" -Type "Resource" -Assignee $assignee -Metadata @{ "high_priority_count" = $data.HighPriority }
        }
    }
}

function Check-QualityAlerts {
    Write-Host "Checking quality alerts..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "ORDER BY created DESC"
    if (-not $issues) { return }
    
    $qualityData = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $qualityData.ContainsKey($project)) {
            $qualityData[$project] = @{
                "Total" = 0
                "Bugs" = 0
                "HighPriorityBugs" = 0
                "Reopened" = 0
                "TechnicalDebt" = 0
            }
        }
        
        $qualityData[$project].Total++
        if ($issue.fields.issuetype.name -eq "Bug") {
            $qualityData[$project].Bugs++
            if ($issue.fields.priority.name -in @("High", "Highest")) {
                $qualityData[$project].HighPriorityBugs++
            }
        }
        if ($issue.fields.status.name -eq "Reopened") {
            $qualityData[$project].Reopened++
        }
        if ($issue.fields.labels -and $issue.fields.labels -match "technical-debt|refactor|cleanup") {
            $qualityData[$project].TechnicalDebt++
        }
    }
    
    foreach ($project in $qualityData.Keys) {
        $data = $qualityData[$project]
        $bugRate = if ($data.Total -gt 0) { ($data.Bugs / $data.Total) * 100 } else { 0 }
        $criticalBugRate = if ($data.Total -gt 0) { ($data.HighPriorityBugs / $data.Total) * 100 } else { 0 }
        $reopenedRate = if ($data.Total -gt 0) { ($data.Reopened / $data.Total) * 100 } else { 0 }
        $debtRate = if ($data.Total -gt 0) { ($data.TechnicalDebt / $data.Total) * 100 } else { 0 }
        
        if ($bugRate -gt $AlertConfig.thresholds.bug_rate) {
            Send-Alert -Title "High Bug Rate" -Message "Project '$project' bug rate is $([math]::Round($bugRate, 1))% - above threshold of $($AlertConfig.thresholds.bug_rate)%" -Severity "High" -Type "Quality" -Project $project -Metadata @{ "bug_rate" = $bugRate; "total_bugs" = $data.Bugs; "total_issues" = $data.Total }
        }
        
        if ($criticalBugRate -gt 10) {
            Send-Alert -Title "Critical Bug Alert" -Message "Project '$project' has high critical bug rate of $([math]::Round($criticalBugRate, 1))%" -Severity "Critical" -Type "Quality" -Project $project -Metadata @{ "critical_bug_rate" = $criticalBugRate; "critical_bugs" = $data.HighPriorityBugs }
        }
        
        if ($reopenedRate -gt $AlertConfig.thresholds.reopened_rate) {
            Send-Alert -Title "High Reopened Rate" -Message "Project '$project' reopened rate is $([math]::Round($reopenedRate, 1))% - above threshold of $($AlertConfig.thresholds.reopened_rate)%" -Severity "Medium" -Type "Quality" -Project $project -Metadata @{ "reopened_rate" = $reopenedRate; "reopened_count" = $data.Reopened }
        }
        
        if ($debtRate -gt $AlertConfig.thresholds.technical_debt) {
            Send-Alert -Title "High Technical Debt" -Message "Project '$project' technical debt rate is $([math]::Round($debtRate, 1))% - above threshold of $($AlertConfig.thresholds.technical_debt)%" -Severity "Medium" -Type "Quality" -Project $project -Metadata @{ "debt_rate" = $debtRate; "debt_count" = $data.TechnicalDebt }
        }
    }
}

function Check-PerformanceAlerts {
    Write-Host "Checking performance alerts..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "status = Done ORDER BY resolutiondate DESC"
    if (-not $issues) { return }
    
    $performanceData = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $performanceData.ContainsKey($project)) {
            $performanceData[$project] = @()
        }
        
        $created = [DateTime]::Parse($issue.fields.created)
        $resolved = [DateTime]::Parse($issue.fields.resolutiondate)
        $resolutionTime = ($resolved - $created).TotalDays
        
        $performanceData[$project] += $resolutionTime
    }
    
    foreach ($project in $performanceData.Keys) {
        $times = $performanceData[$project]
        if ($times.Count -lt 5) { continue }
        
        $avgResolutionTime = ($times | Measure-Object -Average).Average
        $stdDev = if ($times.Count -gt 1) {
            $variance = ($times | ForEach-Object { [math]::Pow($_ - $avgResolutionTime, 2) } | Measure-Object -Average).Average
            [math]::Sqrt($variance)
        } else { 0 }
        
        if ($stdDev -gt $AlertConfig.thresholds.performance_anomaly) {
            Send-Alert -Title "Performance Instability" -Message "Project '$project' has high performance variability (std dev: $([math]::Round($stdDev, 1)) days)" -Severity "Medium" -Type "Performance" -Project $project -Metadata @{ "std_deviation" = $stdDev; "avg_resolution_time" = $avgResolutionTime; "sample_size" = $times.Count }
        }
        
        if ($avgResolutionTime -gt 20) {
            Send-Alert -Title "Slow Performance" -Message "Project '$project' has slow average resolution time of $([math]::Round($avgResolutionTime, 1)) days" -Severity "Medium" -Type "Performance" -Project $project -Metadata @{ "avg_resolution_time" = $avgResolutionTime; "sample_size" = $times.Count }
        }
    }
}

function Check-DeadlineAlerts {
    Write-Host "Checking deadline alerts..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "duedate is not EMPTY ORDER BY duedate ASC"
    if (-not $issues) { return }
    
    $deadlineData = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $deadlineData.ContainsKey($project)) {
            $deadlineData[$project] = @{
                "Total" = 0
                "Overdue" = 0
                "DueThisWeek" = 0
                "DueNextWeek" = 0
                "HighPriority" = 0
            }
        }
        
        $deadlineData[$project].Total++
        $dueDate = [DateTime]::Parse($issue.fields.duedate)
        $now = Get-Date
        
        if ($dueDate -lt $now -and $issue.fields.status.name -ne "Done") {
            $deadlineData[$project].Overdue++
        }
        elseif ($dueDate -ge $now -and $dueDate -le $now.AddDays(7) -and $issue.fields.status.name -ne "Done") {
            $deadlineData[$project].DueThisWeek++
        }
        elseif ($dueDate -gt $now.AddDays(7) -and $dueDate -le $now.AddDays(14) -and $issue.fields.status.name -ne "Done") {
            $deadlineData[$project].DueNextWeek++
        }
        
        if ($issue.fields.priority.name -in @("High", "Highest")) {
            $deadlineData[$project].HighPriority++
        }
    }
    
    foreach ($project in $deadlineData.Keys) {
        $data = $deadlineData[$project]
        $overdueRate = if ($data.Total -gt 0) { ($data.Overdue / $data.Total) * 100 } else { 0 }
        
        if ($overdueRate -gt $AlertConfig.thresholds.deadline_risk) {
            Send-Alert -Title "Deadline Risk" -Message "Project '$project' has high overdue rate of $([math]::Round($overdueRate, 1))%" -Severity "High" -Type "Deadline" -Project $project -Metadata @{ "overdue_rate" = $overdueRate; "overdue_count" = $data.Overdue; "total_issues" = $data.Total }
        }
        
        if ($data.DueThisWeek -gt 0) {
            Send-Alert -Title "Upcoming Deadlines" -Message "Project '$project' has $($data.DueThisWeek) issues due this week" -Severity "Medium" -Type "Deadline" -Project $project -Metadata @{ "due_this_week" = $data.DueThisWeek }
        }
        
        if ($data.DueNextWeek -gt 5) {
            Send-Alert -Title "Next Week Deadlines" -Message "Project '$project' has $($data.DueNextWeek) issues due next week" -Severity "Low" -Type "Deadline" -Project $project -Metadata @{ "due_next_week" = $data.DueNextWeek }
        }
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Alert System" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
Write-Host "Alert Type: $AlertType" -ForegroundColor Yellow
Write-Host "Check Interval: $CheckInterval seconds" -ForegroundColor Yellow
Write-Host "Escalation: $EnableEscalation" -ForegroundColor Yellow
Write-Host "Channels: $($AlertConfig.channels | ConvertTo-Json -Compress)" -ForegroundColor Yellow

try {
    # Main alert checking loop
    do {
        $AlertState.last_check = Get-Date
        
        switch ($AlertType.ToLower()) {
            "sprint" {
                Check-SprintAlerts
            }
            "resource" {
                Check-ResourceAlerts
            }
            "quality" {
                Check-QualityAlerts
            }
            "performance" {
                Check-PerformanceAlerts
            }
            "deadline" {
                Check-DeadlineAlerts
            }
            "all" {
                Check-SprintAlerts
                Check-ResourceAlerts
                Check-QualityAlerts
                Check-PerformanceAlerts
                Check-DeadlineAlerts
            }
            default {
                Write-Warning "Unknown alert type: $AlertType. Use 'all', 'sprint', 'resource', 'quality', 'performance', or 'deadline'"
                break
            }
        }
        
        # Process escalations
        Process-Escalation
        
        Write-Host "Alert check completed at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
        Start-Sleep -Seconds $CheckInterval
        
    } while ($true)
}
catch {
    Write-Error "Error during alert checking: $($_.Exception.Message)"
}

Write-Host "Alert system finished." -ForegroundColor Green
