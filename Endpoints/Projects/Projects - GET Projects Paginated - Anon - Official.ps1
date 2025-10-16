# =============================================================================
# ENDPOINT: Projects - GET Projects Paginated
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-search-get
#
# DESCRIPTION: Returns a paginated list of projects visible to the user.
#
# =============================================================================

# Configuration - Load parameters first
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

$Params = Get-EndpointParameters
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

# Create Basic Auth Header
$AuthString = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${ApiToken}"))
$AuthHeader = "Basic $AuthString"

Write-Host "=== PROJECTS - GET PROJECTS PAGINATED ===" -ForegroundColor Green

try {
    Write-Host "Fetching data from Projects - GET Projects Paginated endpoint..." -ForegroundColor Yellow
    
    # API Parameters
    $StartAt = 0
    $MaxResults = $Params.MaxResults
    $OrderBy = "key"
    $Expand = "lead,description,issueTypes,url,projectKeys,permissions,insight"
    
    # Implement pagination
    $AllProjects = @()
    
    do {
        # Build API URL
        $fullUrl = "$BaseUrl/rest/api/3/project/search?startAt=$StartAt&maxResults=$MaxResults&orderBy=$OrderBy&expand=$Expand"
        
        Write-Host "Calling API endpoint: $fullUrl" -ForegroundColor Cyan
        
        $response = Invoke-RestMethod -Uri $fullUrl -Method GET -Headers @{
            "Authorization" = $AuthHeader
            "Accept" = "application/json"
        }
        
        Write-Host "Retrieved $($response.values.Count) projects (Total so far: $($AllProjects.Count + $response.values.Count))" -ForegroundColor Gray
        
        $AllProjects += $response.values
        $StartAt += $MaxResults
        
    } while ($response.values.Count -eq $MaxResults -and $response.isLast -ne `$true)
    
    Write-Host "Processing response data..." -ForegroundColor Yellow
    
    # Extract and flatten the data
    $projects = @()
    
    if ($AllProjects -and $AllProjects.Count -gt 0) {
        foreach ($project in $AllProjects) {
            # Extract basic project information
            $projectData = [PSCustomObject]@{
                Id = if ($project.id) { $project.id } else { "" }
                Key = if ($project.key) { $project.key } else { "" }
                Name = if ($project.name) { $project.name } else { "" }
                ProjectTypeKey = if ($project.projectTypeKey) { $project.projectTypeKey } else { "" }
                Simplified = if ($project.simplified) { $project.simplified.ToString().ToLower() } else { "" }
                Style = if ($project.style) { $project.style } else { "" }
                IsPrivate = if ($project.isPrivate) { $project.isPrivate.ToString().ToLower() } else { "" }
                
                # Lead information (expanded)
                LeadDisplayName = if ($project.lead -and $project.lead.displayName) { $project.lead.displayName } else { "" }
                LeadAccountId = if ($project.lead -and $project.lead.accountId) { $project.lead.accountId } else { "" }
                LeadActive = if ($project.lead -and $project.lead.active) { $project.lead.active.ToString().ToLower() } else { "" }
                LeadTimeZone = if ($project.lead -and $project.lead.timeZone) { $project.lead.timeZone } else { "" }
                
                # Description (expanded)
                Description = if ($project.description) { $project.description } else { "" }
                
                # URLs (expanded)
                Url = if ($project.url) { $project.url } else { "" }
                Self = if ($project.self) { $project.self } else { "" }
                
                # Issue Types (expanded)
                IssueTypeNames = if ($project.issueTypes) { ($project.issueTypes | ForEach-Object { $_.name }) -join "; " } else { "" }
                
                # Project Keys (expanded)
                ProjectKeys = if ($project.projectKeys) { ($project.projectKeys | ForEach-Object { $_.key }) -join "; " } else { "" }
                
                # Insight (expanded)
                TotalIssueCount = if ($project.insight -and $project.insight.totalIssueCount) { $project.insight.totalIssueCount } else { 0 }
                LastIssueUpdateTime = if ($project.insight -and $project.insight.lastIssueUpdateTime) { $project.insight.lastIssueUpdateTime } else { "" }
            }
            
            $projects += $projectData
        }
    }
    
    # Export to CSV
    $outputFile = "Projects - GET Projects Paginated - Anon - Official.csv"
    $projects | Export-Csv -Path $outputFile -NoTypeInformation
    
    Write-Host "Data exported to: $((Get-Location).Path)\$outputFile" -ForegroundColor Green
    Write-Host "Total records found: $($projects.Count)" -ForegroundColor Green
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
}

