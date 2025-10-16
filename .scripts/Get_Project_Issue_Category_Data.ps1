# =============================================================================
# PowerShell Script: Get Project, Project Category, and Issue ID Data
# =============================================================================
#
# DESCRIPTION: This script fetches project, project category, and issue data
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
# FUNCTION: Get All Projects with Categories
# =============================================================================
function Get-AllProjects {
    Write-Host "Fetching projects with categories..."
    
    $ProjectsEndpoint = "/rest/api/3/project/search?startAt=0&maxResults=1000&expand=projectCategory"
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
                "" 
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
# FUNCTION: Get All Issues with Project Info
# =============================================================================
function Get-AllIssues {
    Write-Host "Fetching issues with project information..."
    
    $IssuesEndpoint = "/rest/api/3/search?jql=ORDER BY created DESC&maxResults=100&expand=names"
    $IssuesUrl = $BaseUrl + $IssuesEndpoint
    
    try {
        $IssuesResponse = Invoke-RestMethod -Uri $IssuesUrl -Headers @{
            "Authorization" = $AuthHeader
            "Content-Type" = "application/json"
        }
        
        $Issues = @()
        foreach ($issue in $IssuesResponse.issues) {
            $Issues += [PSCustomObject]@{
                IssueId = $issue.id
                IssueKey = $issue.key
                IssueProjectId = $issue.fields.project.id
                IssueProjectName = $issue.fields.project.name
            }
        }
        
        Write-Host "Found $($Issues.Count) issues"
        return $Issues
    }
    catch {
        Write-Error "Failed to fetch issues: $($_.Exception.Message)"
        return @()
    }
}

# =============================================================================
# FUNCTION: Join Projects and Issues Data
# =============================================================================
function Join-ProjectIssueData {
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
            "Project Category" = if ($Project) { $Project.ProjectCategoryName } else { "" }
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

# Get data
$Projects = Get-AllProjects
$Issues = Get-AllIssues

if ($Projects.Count -eq 0 -or $Issues.Count -eq 0) {
    Write-Error "Failed to retrieve data. Exiting."
    exit 1
}

# Join data
$FinalData = Join-ProjectIssueData -Projects $Projects -Issues $Issues

# Export to CSV
$OutputFile = "Project_Issue_Category_Data.csv"
$FinalData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Data exported to: $OutputFile" -ForegroundColor Green
Write-Host "Total records: $($FinalData.Count)" -ForegroundColor Green

# Display sample data
Write-Host "`nSample data:" -ForegroundColor Yellow
$FinalData | Select-Object -First 5 | Format-Table -AutoSize
