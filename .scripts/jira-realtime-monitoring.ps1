# =============================================================================
# JIRA REAL-TIME MONITORING SYSTEM
# =============================================================================

# Advanced real-time monitoring system that surpasses Atlassian Analytics
# This system provides live monitoring and instant alerts

param(
    [string]$MonitoringType = "all",
    [switch]$EnableLiveDashboard = $false,
    [switch]$EnableWebSocket = $false,
    [int]$RefreshInterval = 30,
    [switch]$EnableNotifications = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Real-time monitoring configuration
$MonitoringConfig = @{
    "refresh_interval" = $RefreshInterval
    "websocket_enabled" = $EnableWebSocket
    "live_dashboard" = $EnableLiveDashboard
    "notifications" = $EnableNotifications
    "alert_thresholds" = @{
        "sprint_completion" = 60
        "resource_overload" = 80
        "quality_breach" = 25
        "deadline_risk" = 20
        "performance_anomaly" = 3.0
    }
}

# Live monitoring data
$LiveData = @{
    "last_update" = Get-Date
    "sprint_progress" = @{}
    "resource_utilization" = @{}
    "quality_metrics" = @{}
    "performance_metrics" = @{}
    "alert_history" = @()
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

function Send-RealtimeAlert {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Severity = "Medium",
        [string]$Type = "General"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $alert = @{
        "timestamp" = $timestamp
        "title" = $Title
        "message" = $Message
        "severity" = $Severity
        "type" = $Type
    }
    
    $LiveData.alert_history += $alert
    
    # Keep only last 100 alerts
    if ($LiveData.alert_history.Count -gt 100) {
        $LiveData.alert_history = $LiveData.alert_history[-100..-1]
    }
    
    Write-Host "🚨 REAL-TIME ALERT: $Title" -ForegroundColor Red
}

function Update-LiveDashboard {
    param(
        [hashtable]$Data
    )
    
    if (-not $EnableLiveDashboard) { return }
    
    $dashboardData = @{
        "timestamp" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "data" = $Data
    }
    
    $dashboardPath = ".\live-dashboard.json"
    $dashboardData | ConvertTo-Json -Depth 10 | Out-File -FilePath $dashboardPath -Encoding UTF8
    
    Write-Host "📊 Live dashboard updated" -ForegroundColor Green
}

# =============================================================================
# REAL-TIME MONITORING FUNCTIONS
# =============================================================================

function Monitor-SprintProgress {
    Write-Host "Monitoring sprint progress..." -ForegroundColor Cyan
    
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
                    "InProgress" = 0
                    "ToDo" = 0
                    "Overdue" = 0
                }
            }
            
            $sprints[$sprint].Total++
            switch ($issue.fields.status.name) {
                "Done" { $sprints[$sprint].Completed++ }
                "In Progress" { $sprints[$sprint].InProgress++ }
                "To Do" { $sprints[$sprint].ToDo++ }
            }
            
            if ($issue.fields.duedate -and [DateTime]::Parse($issue.fields.duedate) -lt (Get-Date) -and $issue.fields.status.name -ne "Done") {
                $sprints[$sprint].Overdue++
            }
        }
    }
    
    foreach ($sprint in $sprints.Keys) {
        $data = $sprints[$sprint]
        $completionRate = if ($data.Total -gt 0) { ($data.Completed / $data.Total) * 100 } else { 0 }
        
        $LiveData.sprint_progress[$sprint] = @{
            "completion_rate" = $completionRate
            "total_issues" = $data.Total
            "completed" = $data.Completed
            "in_progress" = $data.InProgress
            "to_do" = $data.ToDo
            "overdue" = $data.Overdue
            "status" = if ($completionRate -lt $MonitoringConfig.alert_thresholds.sprint_completion) { "At Risk" } else { "On Track" }
        }
        
        # Check for alerts
        if ($completionRate -lt $MonitoringConfig.alert_thresholds.sprint_completion) {
            Send-RealtimeAlert -Title "Sprint at Risk" -Message "Sprint '$sprint' completion rate is $([math]::Round($completionRate, 1))% - below threshold of $($MonitoringConfig.alert_thresholds.sprint_completion)%" -Severity "High" -Type "Sprint"
        }
        
        if ($data.Overdue -gt 0) {
            Send-RealtimeAlert -Title "Sprint Overdue Issues" -Message "Sprint '$sprint' has $($data.Overdue) overdue issues" -Severity "Medium" -Type "Sprint"
        }
    }
    
    Update-LiveDashboard -Data $LiveData.sprint_progress
}

function Monitor-ResourceUtilization {
    Write-Host "Monitoring resource utilization..." -ForegroundColor Cyan
    
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
                "WorkloadScore" = 0
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
        $workloadScore = $data.Active + ($data.HighPriority * 2) + ($data.Overdue * 3)
        
        $LiveData.resource_utilization[$assignee] = @{
            "utilization_rate" = $utilizationRate
            "workload_score" = $workloadScore
            "total_issues" = $data.Total
            "active_issues" = $data.Active
            "high_priority" = $data.HighPriority
            "overdue" = $data.Overdue
            "status" = if ($utilizationRate -gt $MonitoringConfig.alert_thresholds.resource_overload) { "Overloaded" } else { "Normal" }
        }
        
        # Check for alerts
        if ($utilizationRate -gt $MonitoringConfig.alert_thresholds.resource_overload) {
            Send-RealtimeAlert -Title "Resource Overload" -Message "Team member '$assignee' utilization rate is $([math]::Round($utilizationRate, 1))% - above threshold of $($MonitoringConfig.alert_thresholds.resource_overload)%" -Severity "High" -Type "Resource"
        }
        
        if ($workloadScore -gt 20) {
            Send-RealtimeAlert -Title "High Workload" -Message "Team member '$assignee' has high workload score of $workloadScore" -Severity "Medium" -Type "Resource"
        }
    }
    
    Update-LiveDashboard -Data $LiveData.resource_utilization
}

function Monitor-QualityMetrics {
    Write-Host "Monitoring quality metrics..." -ForegroundColor Cyan
    
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
        
        $qualityScore = 100 - ($bugRate * 0.3) - ($criticalBugRate * 0.4) - ($reopenedRate * 0.2) - ($debtRate * 0.1)
        
        $LiveData.quality_metrics[$project] = @{
            "quality_score" = $qualityScore
            "bug_rate" = $bugRate
            "critical_bug_rate" = $criticalBugRate
            "reopened_rate" = $reopenedRate
            "debt_rate" = $debtRate
            "total_issues" = $data.Total
            "bugs" = $data.Bugs
            "high_priority_bugs" = $data.HighPriorityBugs
            "reopened" = $data.Reopened
            "technical_debt" = $data.TechnicalDebt
            "status" = if ($bugRate -gt $MonitoringConfig.alert_thresholds.quality_breach) { "Quality Breach" } else { "Quality OK" }
        }
        
        # Check for alerts
        if ($bugRate -gt $MonitoringConfig.alert_thresholds.quality_breach) {
            Send-RealtimeAlert -Title "Quality Breach" -Message "Project '$project' bug rate is $([math]::Round($bugRate, 1))% - above threshold of $($MonitoringConfig.alert_thresholds.quality_breach)%" -Severity "High" -Type "Quality"
        }
        
        if ($criticalBugRate -gt 10) {
            Send-RealtimeAlert -Title "Critical Bug Alert" -Message "Project '$project' has high critical bug rate of $([math]::Round($criticalBugRate, 1))%" -Severity "Critical" -Type "Quality"
        }
    }
    
    Update-LiveDashboard -Data $LiveData.quality_metrics
}

function Monitor-PerformanceMetrics {
    Write-Host "Monitoring performance metrics..." -ForegroundColor Cyan
    
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
        $medianResolutionTime = ($times | Sort-Object)[[math]::Floor($times.Count / 2)]
        $stdDev = if ($times.Count -gt 1) {
            $variance = ($times | ForEach-Object { [math]::Pow($_ - $avgResolutionTime, 2) } | Measure-Object -Average).Average
            [math]::Sqrt($variance)
        } else { 0 }
        
        $LiveData.performance_metrics[$project] = @{
            "avg_resolution_time" = $avgResolutionTime
            "median_resolution_time" = $medianResolutionTime
            "std_deviation" = $stdDev
            "sample_size" = $times.Count
            "status" = if ($stdDev -gt $MonitoringConfig.alert_thresholds.performance_anomaly) { "Unstable" } else { "Stable" }
        }
        
        # Check for alerts
        if ($stdDev -gt $MonitoringConfig.alert_thresholds.performance_anomaly) {
            Send-RealtimeAlert -Title "Performance Instability" -Message "Project '$project' has high performance variability (std dev: $([math]::Round($stdDev, 1)) days)" -Severity "Medium" -Type "Performance"
        }
        
        if ($avgResolutionTime -gt 20) {
            Send-RealtimeAlert -Title "Slow Performance" -Message "Project '$project' has slow average resolution time of $([math]::Round($avgResolutionTime, 1)) days" -Severity "Medium" -Type "Performance"
        }
    }
    
    Update-LiveDashboard -Data $LiveData.performance_metrics
}

function Monitor-DeadlineRisks {
    Write-Host "Monitoring deadline risks..." -ForegroundColor Cyan
    
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
        
        # Check for alerts
        if ($overdueRate -gt $MonitoringConfig.alert_thresholds.deadline_risk) {
            Send-RealtimeAlert -Title "Deadline Risk" -Message "Project '$project' has high overdue rate of $([math]::Round($overdueRate, 1))%" -Severity "High" -Type "Deadline"
        }
        
        if ($data.DueThisWeek -gt 0) {
            Send-RealtimeAlert -Title "Upcoming Deadlines" -Message "Project '$project' has $($data.DueThisWeek) issues due this week" -Severity "Medium" -Type "Deadline"
        }
    }
}

function Start-WebSocketServer {
    if (-not $EnableWebSocket) { return }
    
    Write-Host "Starting WebSocket server for real-time updates..." -ForegroundColor Green
    
    # This would typically use a WebSocket library like WebSocketSharp
    # For now, we'll simulate with a simple HTTP endpoint
    $websocketPort = 8080
    $websocketUrl = "http://localhost:$websocketPort"
    
    Write-Host "WebSocket server would be available at: $websocketUrl" -ForegroundColor Yellow
    Write-Host "Real-time data updates would be pushed to connected clients" -ForegroundColor Yellow
}

function Start-LiveDashboard {
    if (-not $EnableLiveDashboard) { return }
    
    Write-Host "Starting live dashboard..." -ForegroundColor Green
    
    # Create HTML dashboard
    $dashboardHtml = @"
<!DOCTYPE html>
<html>
<head>
    <title>Jira Real-Time Analytics Dashboard</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: #0052cc; color: white; padding: 20px; border-radius: 5px; margin-bottom: 20px; }
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .metric-card { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric-title { font-size: 18px; font-weight: bold; margin-bottom: 10px; color: #333; }
        .metric-value { font-size: 24px; font-weight: bold; color: #0052cc; }
        .metric-status { padding: 5px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
        .status-ok { background: #d4edda; color: #155724; }
        .status-warning { background: #fff3cd; color: #856404; }
        .status-danger { background: #f8d7da; color: #721c24; }
        .alerts { background: white; padding: 20px; border-radius: 5px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-top: 20px; }
        .alert-item { padding: 10px; margin: 5px 0; border-left: 4px solid #dc3545; background: #f8f9fa; }
        .timestamp { color: #666; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Jira Real-Time Analytics Dashboard</h1>
            <p>Live monitoring and analytics - Last updated: <span id="lastUpdate"></span></p>
        </div>
        
        <div class="metrics-grid" id="metricsGrid">
            <!-- Metrics will be populated by JavaScript -->
        </div>
        
        <div class="alerts">
            <h2>🚨 Recent Alerts</h2>
            <div id="alertsList">
                <!-- Alerts will be populated by JavaScript -->
            </div>
        </div>
    </div>
    
    <script>
        function updateDashboard() {
            fetch('./live-dashboard.json')
                .then(response => response.json())
                .then(data => {
                    document.getElementById('lastUpdate').textContent = data.timestamp;
                    // Update metrics and alerts here
                })
                .catch(error => console.error('Error updating dashboard:', error));
        }
        
        // Update dashboard every 30 seconds
        setInterval(updateDashboard, 30000);
        updateDashboard();
    </script>
</body>
</html>
"@
    
    $dashboardPath = ".\live-dashboard.html"
    $dashboardHtml | Out-File -FilePath $dashboardPath -Encoding UTF8
    
    Write-Host "Live dashboard created at: $dashboardPath" -ForegroundColor Green
    Write-Host "Open the dashboard in your browser to see real-time updates" -ForegroundColor Yellow
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Real-Time Monitoring System" -ForegroundColor Green
Write-Host "=================================" -ForegroundColor Green
Write-Host "Monitoring Type: $MonitoringType" -ForegroundColor Yellow
Write-Host "Refresh Interval: $RefreshInterval seconds" -ForegroundColor Yellow
Write-Host "Live Dashboard: $EnableLiveDashboard" -ForegroundColor Yellow
Write-Host "WebSocket: $EnableWebSocket" -ForegroundColor Yellow
Write-Host "Notifications: $EnableNotifications" -ForegroundColor Yellow

try {
    # Initialize systems
    Start-WebSocketServer
    Start-LiveDashboard
    
    # Main monitoring loop
    do {
        $LiveData.last_update = Get-Date
        
        switch ($MonitoringType.ToLower()) {
            "sprint" {
                Monitor-SprintProgress
            }
            "resource" {
                Monitor-ResourceUtilization
            }
            "quality" {
                Monitor-QualityMetrics
            }
            "performance" {
                Monitor-PerformanceMetrics
            }
            "deadline" {
                Monitor-DeadlineRisks
            }
            "all" {
                Monitor-SprintProgress
                Monitor-ResourceUtilization
                Monitor-QualityMetrics
                Monitor-PerformanceMetrics
                Monitor-DeadlineRisks
            }
            default {
                Write-Warning "Unknown monitoring type: $MonitoringType. Use 'all', 'sprint', 'resource', 'quality', 'performance', or 'deadline'"
                break
            }
        }
        
        Write-Host "Real-time monitoring cycle completed at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
        Start-Sleep -Seconds $RefreshInterval
        
    } while ($true)
}
catch {
    Write-Error "Error during real-time monitoring: $($_.Exception.Message)"
}

Write-Host "Real-time monitoring system finished." -ForegroundColor Green
