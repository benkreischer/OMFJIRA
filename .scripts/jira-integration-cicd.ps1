# =============================================================================
# JIRA INTEGRATION - CI/CD PIPELINES
# =============================================================================

# Advanced integration script that connects Jira with CI/CD pipelines
# This surpasses Atlassian Analytics by providing deployment tracking
# and DevOps metrics that Atlassian Analytics cannot provide

param(
    [string]$JenkinsUrl = $env:JENKINS_URL,
    [string]$JenkinsToken = $env:JENKINS_TOKEN,
    [string]$AzureDevOpsUrl = $env:AZURE_DEVOPS_URL,
    [string]$AzureDevOpsToken = $env:AZURE_DEVOPS_TOKEN,
    [string]$GitHubToken = $env:GITHUB_TOKEN,
    [string]$IntegrationType = "all",
    [switch]$EnableJenkins = $false,
    [switch]$EnableAzureDevOps = $false,
    [switch]$EnableGitHub = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# DevOps metrics tracking
$DevOpsMetrics = @{
    "deployment_frequency" = @{}
    "lead_time" = @{}
    "mean_time_to_recovery" = @{}
    "change_failure_rate" = @{}
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

function Update-JiraIssue {
    param(
        [string]$IssueKey,
        [hashtable]$Fields
    )
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
        "Content-Type" = "application/json"
    }
    
    $url = "$JiraBaseUrl/issue/$IssueKey"
    $body = @{
        "fields" = $Fields
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method PUT -Body $body
        Write-Host "Updated Jira issue: $IssueKey" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Error "Failed to update Jira issue $IssueKey`: $($_.Exception.Message)"
        return $null
    }
}

function Add-JiraComment {
    param(
        [string]$IssueKey,
        [string]$Comment
    )
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
        "Content-Type" = "application/json"
    }
    
    $url = "$JiraBaseUrl/issue/$IssueKey/comment"
    $body = @{
        "body" = $Comment
    } | ConvertTo-Json -Depth 10
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method POST -Body $body
        Write-Host "Added comment to Jira issue: $IssueKey" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Error "Failed to add comment to Jira issue $IssueKey`: $($_.Exception.Message)"
        return $null
    }
}

# =============================================================================
# JENKINS INTEGRATION
# =============================================================================

function Get-JenkinsBuilds {
    param(
        [string]$JobName = ""
    )
    
    if (-not $EnableJenkins -or -not $JenkinsUrl -or -not $JenkinsToken) {
        return $null
    }
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("jenkins`:$JenkinsToken"))
    }
    
    $url = if ($JobName) {
        "$JenkinsUrl/job/$JobName/api/json"
    } else {
        "$JenkinsUrl/api/json"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get Jenkins data: $($_.Exception.Message)"
        return $null
    }
}

function Sync-JenkinsWithJira {
    Write-Host "Syncing Jenkins builds with Jira..." -ForegroundColor Cyan
    
    $builds = Get-JenkinsBuilds
    if (-not $builds) { return }
    
    foreach ($build in $builds.jobs) {
        $buildDetails = Get-JenkinsBuilds -JobName $build.name
        if (-not $buildDetails) { continue }
        
        foreach ($buildInfo in $buildDetails.builds) {
            $buildNumber = $buildInfo.number
            $buildUrl = $buildInfo.url
            $buildStatus = $buildInfo.result
            
            # Extract Jira issue keys from build description or parameters
            $issueKeys = @()
            if ($buildDetails.description -match "([A-Z]+-\d+)") {
                $issueKeys += $matches[1]
            }
            
            foreach ($issueKey in $issueKeys) {
                $comment = @"
🚀 **Build Information**
- Build Number: $buildNumber
- Status: $buildStatus
- URL: $buildUrl
- Job: $($build.name)
- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
                
                Add-JiraComment -IssueKey $issueKey -Comment $comment
                
                # Update issue status based on build result
                if ($buildStatus -eq "SUCCESS") {
                    Update-JiraIssue -IssueKey $issueKey -Fields @{
                        "customfield_10021" = "Build Successful"  # Custom field for build status
                    }
                } elseif ($buildStatus -eq "FAILURE") {
                    Update-JiraIssue -IssueKey $issueKey -Fields @{
                        "customfield_10021" = "Build Failed"
                    }
                }
            }
        }
    }
}

# =============================================================================
# AZURE DEVOPS INTEGRATION
# =============================================================================

function Get-AzureDevOpsBuilds {
    param(
        [string]$ProjectName = ""
    )
    
    if (-not $EnableAzureDevOps -or -not $AzureDevOpsUrl -or -not $AzureDevOpsToken) {
        return $null
    }
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("`:$AzureDevOpsToken"))
    }
    
    $url = if ($ProjectName) {
        "$AzureDevOpsUrl/$ProjectName/_apis/build/builds?api-version=6.0"
    } else {
        "$AzureDevOpsUrl/_apis/build/builds?api-version=6.0"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get Azure DevOps data: $($_.Exception.Message)"
        return $null
    }
}

function Sync-AzureDevOpsWithJira {
    Write-Host "Syncing Azure DevOps builds with Jira..." -ForegroundColor Cyan
    
    $builds = Get-AzureDevOpsBuilds
    if (-not $builds) { return }
    
    foreach ($build in $builds.value) {
        $buildId = $build.id
        $buildNumber = $build.buildNumber
        $buildStatus = $build.result
        $buildUrl = $build._links.web.href
        
        # Extract Jira issue keys from build source branch or commit message
        $issueKeys = @()
        if ($build.sourceBranch -match "([A-Z]+-\d+)") {
            $issueKeys += $matches[1]
        }
        
        foreach ($issueKey in $issueKeys) {
            $comment = @"
🚀 **Azure DevOps Build Information**
- Build ID: $buildId
- Build Number: $buildNumber
- Status: $buildStatus
- URL: $buildUrl
- Source Branch: $($build.sourceBranch)
- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            
            Add-JiraComment -IssueKey $issueKey -Comment $comment
            
            # Update issue status based on build result
            if ($buildStatus -eq "succeeded") {
                Update-JiraIssue -IssueKey $issueKey -Fields @{
                    "customfield_10021" = "Build Successful"
                }
            } elseif ($buildStatus -eq "failed") {
                Update-JiraIssue -IssueKey $issueKey -Fields @{
                    "customfield_10021" = "Build Failed"
                }
            }
        }
    }
}

# =============================================================================
# GITHUB INTEGRATION
# =============================================================================

function Get-GitHubCommits {
    param(
        [string]$Owner = $env:GITHUB_OWNER,
        [string]$Repo = $env:GITHUB_REPO
    )
    
    if (-not $EnableGitHub -or -not $GitHubToken -or -not $Owner -or -not $Repo) {
        return $null
    }
    
    $headers = @{
        "Authorization" = "token $GitHubToken"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    $url = "https://api.github.com/repos/$Owner/$Repo/commits"
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get GitHub data: $($_.Exception.Message)"
        return $null
    }
}

function Sync-GitHubWithJira {
    Write-Host "Syncing GitHub commits with Jira..." -ForegroundColor Cyan
    
    $commits = Get-GitHubCommits
    if (-not $commits) { return }
    
    foreach ($commit in $commits) {
        $commitSha = $commit.sha
        $commitMessage = $commit.commit.message
        $commitUrl = $commit.html_url
        $commitAuthor = $commit.commit.author.name
        
        # Extract Jira issue keys from commit message
        $issueKeys = @()
        if ($commitMessage -match "([A-Z]+-\d+)") {
            $issueKeys += $matches[1]
        }
        
        foreach ($issueKey in $issueKeys) {
            $comment = @"
🔗 **GitHub Commit Information**
- Commit SHA: $commitSha
- Message: $commitMessage
- Author: $commitAuthor
- URL: $commitUrl
- Timestamp: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
            
            Add-JiraComment -IssueKey $issueKey -Comment $comment
        }
    }
}

# =============================================================================
# DEVOPS METRICS CALCULATION
# =============================================================================

function Calculate-DeploymentFrequency {
    Write-Host "Calculating deployment frequency..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "ORDER BY created DESC"
    if (-not $issues) { return }
    
    $deployments = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $deployments.ContainsKey($project)) {
            $deployments[$project] = @{
                Total = 0
                Deployed = 0
                Deployments = @()
            }
        }
        
        $deployments[$project].Total++
        if ($issue.fields.fixVersions -and $issue.fields.fixVersions.Count -gt 0) {
            $deployments[$project].Deployed++
            $deployments[$project].Deployments += $issue.fields.fixVersions[0].name
        }
    }
    
    foreach ($project in $deployments.Keys) {
        $data = $deployments[$project]
        $frequency = if ($data.Total -gt 0) { ($data.Deployed / $data.Total) * 100 } else { 0 }
        
        Write-Host "Project $project`: Deployment Frequency = $([math]::Round($frequency, 1))%" -ForegroundColor Yellow
    }
}

function Calculate-LeadTime {
    Write-Host "Calculating lead time..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "status = Done ORDER BY updated DESC"
    if (-not $issues) { return }
    
    $leadTimes = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $leadTimes.ContainsKey($project)) {
            $leadTimes[$project] = @()
        }
        
        $created = [DateTime]::Parse($issue.fields.created)
        $resolved = [DateTime]::Parse($issue.fields.resolutiondate)
        $leadTime = ($resolved - $created).TotalDays
        
        $leadTimes[$project] += $leadTime
    }
    
    foreach ($project in $leadTimes.Keys) {
        $times = $leadTimes[$project]
        $avgLeadTime = ($times | Measure-Object -Average).Average
        $medianLeadTime = ($times | Sort-Object)[[math]::Floor($times.Count / 2)]
        
        Write-Host "Project $project`: Average Lead Time = $([math]::Round($avgLeadTime, 1)) days, Median = $([math]::Round($medianLeadTime, 1)) days" -ForegroundColor Yellow
    }
}

function Calculate-MeanTimeToRecovery {
    Write-Host "Calculating mean time to recovery..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "status = Done ORDER BY updated DESC"
    if (-not $issues) { return }
    
    $recoveryTimes = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $recoveryTimes.ContainsKey($project)) {
            $recoveryTimes[$project] = @()
        }
        
        $created = [DateTime]::Parse($issue.fields.created)
        $resolved = [DateTime]::Parse($issue.fields.resolutiondate)
        $recoveryTime = ($resolved - $created).TotalDays
        
        $recoveryTimes[$project] += $recoveryTime
    }
    
    foreach ($project in $recoveryTimes.Keys) {
        $times = $recoveryTimes[$project]
        $avgRecoveryTime = ($times | Measure-Object -Average).Average
        $medianRecoveryTime = ($times | Sort-Object)[[math]::Floor($times.Count / 2)]
        
        Write-Host "Project $project`: Average MTTR = $([math]::Round($avgRecoveryTime, 1)) days, Median = $([math]::Round($medianRecoveryTime, 1)) days" -ForegroundColor Yellow
    }
}

function Calculate-ChangeFailureRate {
    Write-Host "Calculating change failure rate..." -ForegroundColor Cyan
    
    $issues = Get-JiraData -JQL "ORDER BY created DESC"
    if (-not $issues) { return }
    
    $changeFailures = @{}
    foreach ($issue in $issues.issues) {
        $project = $issue.fields.project.key
        if (-not $changeFailures.ContainsKey($project)) {
            $changeFailures[$project] = @{
                Total = 0
                Bugs = 0
                HighPriorityBugs = 0
            }
        }
        
        $changeFailures[$project].Total++
        if ($issue.fields.issuetype.name -eq "Bug") {
            $changeFailures[$project].Bugs++
            if ($issue.fields.priority.name -in @("High", "Highest")) {
                $changeFailures[$project].HighPriorityBugs++
            }
        }
    }
    
    foreach ($project in $changeFailures.Keys) {
        $data = $changeFailures[$project]
        $failureRate = if ($data.Total -gt 0) { ($data.Bugs / $data.Total) * 100 } else { 0 }
        $criticalFailureRate = if ($data.Total -gt 0) { ($data.HighPriorityBugs / $data.Total) * 100 } else { 0 }
        
        Write-Host "Project $project`: Change Failure Rate = $([math]::Round($failureRate, 1))%, Critical Failure Rate = $([math]::Round($criticalFailureRate, 1))%" -ForegroundColor Yellow
    }
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Integration - CI/CD Pipelines" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Integration Type: $IntegrationType" -ForegroundColor Yellow
Write-Host "Jenkins Enabled: $EnableJenkins" -ForegroundColor Yellow
Write-Host "Azure DevOps Enabled: $EnableAzureDevOps" -ForegroundColor Yellow
Write-Host "GitHub Enabled: $EnableGitHub" -ForegroundColor Yellow

try {
    switch ($IntegrationType.ToLower()) {
        "jenkins" {
            Sync-JenkinsWithJira
        }
        "azure" {
            Sync-AzureDevOpsWithJira
        }
        "github" {
            Sync-GitHubWithJira
        }
        "metrics" {
            Calculate-DeploymentFrequency
            Calculate-LeadTime
            Calculate-MeanTimeToRecovery
            Calculate-ChangeFailureRate
        }
        "all" {
            Sync-JenkinsWithJira
            Sync-AzureDevOpsWithJira
            Sync-GitHubWithJira
            Calculate-DeploymentFrequency
            Calculate-LeadTime
            Calculate-MeanTimeToRecovery
            Calculate-ChangeFailureRate
        }
        default {
            Write-Warning "Unknown integration type: $IntegrationType. Use 'all', 'jenkins', 'azure', 'github', or 'metrics'"
        }
    }
    
    Write-Host "CI/CD integration completed successfully." -ForegroundColor Green
}
catch {
    Write-Error "Error during CI/CD integration: $($_.Exception.Message)"
}

Write-Host "CI/CD integration script finished." -ForegroundColor Green
