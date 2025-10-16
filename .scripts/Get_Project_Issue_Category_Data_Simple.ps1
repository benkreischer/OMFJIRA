# =============================================================================
# PowerShell Script: Get Project, Project Category, and Issue ID Data (Simple Version)
# =============================================================================
#
# DESCRIPTION: This script fetches a sample of project, project category, and issue data
# from Jira API and exports it to a CSV file.
#
# USAGE: 
# 1. Run this script in PowerShell
# 2. The script will create a CSV file with the results
#
# =============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================
$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"
$AuthHeader = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))

# =============================================================================
# FUNCTION: Get Projects with Categories
# =============================================================================
function Get-Projects {
    Write-Host "Fetching projects with categories..."
    
    $ProjectsEndpoint = "/rest/api/3/project/search?startAt=0&maxResults=100&expand=projectCategory"
    $ProjectsUrl = $BaseUrl + $ProjectsEndpoint
    
    try {
        $ProjectsResponse = Invoke-RestMethod -Uri $ProjectsUrl -Headers @{
            "Authorization" = $AuthHeader
            "Content-Type" = "application/json"
        }
        
        $Projects = @()
        foreach ($project in $ProjectsResponse.values) {
            $ProjectCategoryName = if ($project.projectCategory -and $project.projectCategory.name) { 
                $project.projectCategory.name 
            } else { 
                "No Category" 
            }
            
            $Projects += [PSCustomObject]@{
                ProjectId = $project.id
                ProjectKey = $project.key
                ProjectName = $project.name
                ProjectCategoryName = $ProjectCategoryName
            }
        }
        
        Write-Host "Found $($Projects.Count) projects"
        return $Projects
    }
    catch {
        Write-Error "Failed to fetch projects: $($_.Exception.Message)"
        return @()
    }
}

# =============================================================================
# FUNCTION: Get Issues for Specific Projects
# =============================================================================
function Get-IssuesForProjects {
    param([array]$Projects)
    
    Write-Host "Fetching issues for projects..."
    
    $AllIssues = @()
    $ProjectKeys = $Projects | Select-Object -First 5 | ForEach-Object { $_.ProjectKey }
    
    foreach ($ProjectKey in $ProjectKeys) {
        Write-Host "Fetching issues for project: $ProjectKey"
        
        $IssuesEndpoint = "/rest/api/3/search?jql=project = $ProjectKey ORDER BY created DESC&maxResults=50&expand=names"
        $IssuesUrl = $BaseUrl + $IssuesEndpoint
        
        try {
            $IssuesResponse = Invoke-RestMethod -Uri $IssuesUrl -Headers @{
                "Authorization" = $AuthHeader
                "Content-Type" = "application/json"
            }
            
            foreach ($issue in $IssuesResponse.issues) {
                $AllIssues += [PSCustomObject]@{
                    IssueId = $issue.id
                    IssueKey = $issue.key
                    IssueProjectId = $issue.fields.project.id
                    IssueProjectName = $issue.fields.project.name
                }
            }
            
            Write-Host "Found $($IssuesResponse.issues.Count) issues for $ProjectKey"
        }
        catch {
            Write-Warning "Failed to fetch issues for $ProjectKey`: $($_.Exception.Message)"
        }
        
        # Add a small delay to avoid rate limiting
        Start-Sleep -Milliseconds 500
    }
    
    Write-Host "Total issues found: $($AllIssues.Count)"
    return $AllIssues
}

# =============================================================================
# FUNCTION: Join Data
# =============================================================================
function Join-Data {
    param(
        [array]$Projects,
        [array]$Issues
    )
    
    Write-Host "Joining project and issue data..."
    
    $JoinedData = @()
    
    foreach ($issue in $Issues) {
        $Project = $Projects | Where-Object { $_.ProjectId -eq $issue.IssueProjectId }
        
        $JoinedData += [PSCustomObject]@{
            "Project" = $issue.IssueProjectName
            "Project Category" = if ($Project) { $Project.ProjectCategoryName } else { "Unknown" }
            "Issue ID" = $issue.IssueId
        }
    }
    
    Write-Host "Created $($JoinedData.Count) joined records"
    return $JoinedData
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
Write-Host "Starting data collection process..." -ForegroundColor Green

# Get projects
$Projects = Get-Projects

if ($Projects.Count -eq 0) {
    Write-Error "Failed to retrieve projects. Exiting."
    exit 1
}

# Get issues for a subset of projects
$Issues = Get-IssuesForProjects -Projects $Projects

if ($Issues.Count -eq 0) {
    Write-Error "Failed to retrieve issues. Exiting."
    exit 1
}

# Join data
$FinalData = Join-Data -Projects $Projects -Issues $Issues

# Export to CSV
$OutputFile = "Project_Issue_Category_Data_Simple.csv"
$FinalData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Data exported to: $OutputFile" -ForegroundColor Green
Write-Host "Total records: $($FinalData.Count)" -ForegroundColor Green

# Display sample data
Write-Host "`nSample data:" -ForegroundColor Yellow
$FinalData | Select-Object -First 10 | Format-Table -AutoSize

# Display summary by project category
Write-Host "`nSummary by Project Category:" -ForegroundColor Yellow
$FinalData | Group-Object "Project Category" | Select-Object Name, Count | Format-Table -AutoSize
