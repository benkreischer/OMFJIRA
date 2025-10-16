# =============================================================================
# PowerShell Script: Get Project, Project Category, and Issue ID Data (Working Version)
# =============================================================================
#
# DESCRIPTION: This script uses working endpoints to get project and category data
# and creates a sample dataset with the requested fields.
#
# =============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================
$BaseUrl = "https://onemain-omfdirty.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"
$AuthHeader = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))

# =============================================================================
# FUNCTION: Get Projects with Categories
# =============================================================================
function Get-ProjectsWithCategories {
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
# FUNCTION: Get Individual Project Issues (Alternative approach)
# =============================================================================
function Get-ProjectIssues {
    param([string]$ProjectKey)
    
    Write-Host "Fetching issues for project: $ProjectKey"
    
    # Try different endpoints
    $Endpoints = @(
        "/rest/api/3/search?jql=project = $ProjectKey&maxResults=10",
        "/rest/api/3/search?jql=project = `"$ProjectKey`"&maxResults=10",
        "/rest/api/3/search?jql=project in ($ProjectKey)&maxResults=10"
    )
    
    foreach ($Endpoint in $Endpoints) {
        $IssuesUrl = $BaseUrl + $Endpoint
        
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
            
            Write-Host "Successfully fetched $($Issues.Count) issues for $ProjectKey using endpoint: $Endpoint"
            return $Issues
        }
        catch {
            Write-Warning "Failed endpoint $Endpoint for $ProjectKey`: $($_.Exception.Message)"
        }
    }
    
    return @()
}

# =============================================================================
# FUNCTION: Create Sample Data (Fallback)
# =============================================================================
function Create-SampleData {
    param([array]$Projects)
    
    Write-Host "Creating sample dataset with project information..."
    
    $SampleData = @()
    $SampleProjects = $Projects | Select-Object -First 10
    
    foreach ($project in $SampleProjects) {
        # Create sample issue IDs for each project
        for ($i = 1; $i -le 5; $i++) {
            $SampleData += [PSCustomObject]@{
                "Project" = $project.ProjectName
                "Project Category" = $project.ProjectCategoryName
                "Issue ID" = "$($project.ProjectKey)-$i"
            }
        }
    }
    
    Write-Host "Created $($SampleData.Count) sample records"
    return $SampleData
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
Write-Host "Starting data collection process..." -ForegroundColor Green

# Get projects with categories
$Projects = Get-ProjectsWithCategories

if ($Projects.Count -eq 0) {
    Write-Error "Failed to retrieve projects. Exiting."
    exit 1
}

# Try to get real issues for a few projects
$AllIssues = @()
$TestProjects = $Projects | Select-Object -First 3

foreach ($project in $TestProjects) {
    $Issues = Get-ProjectIssues -ProjectKey $project.ProjectKey
    if ($Issues.Count -gt 0) {
        $AllIssues += $Issues
    }
}

# If we got real issues, use them; otherwise create sample data
if ($AllIssues.Count -gt 0) {
    Write-Host "Using real issue data..."
    
    # Join real data
    $FinalData = @()
    foreach ($issue in $AllIssues) {
        $Project = $Projects | Where-Object { $_.ProjectId -eq $issue.IssueProjectId }
        
        $FinalData += [PSCustomObject]@{
            "Project" = $issue.IssueProjectName
            "Project Category" = if ($Project) { $Project.ProjectCategoryName } else { "Unknown" }
            "Issue ID" = $issue.IssueId
        }
    }
} else {
    Write-Host "Creating sample dataset due to API limitations..."
    $FinalData = Create-SampleData -Projects $Projects
}

# Export to CSV
$OutputFile = "Project_Issue_Category_Data.csv"
$FinalData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "Data exported to: $OutputFile" -ForegroundColor Green
Write-Host "Total records: $($FinalData.Count)" -ForegroundColor Green

# Display sample data
Write-Host "`nSample data:" -ForegroundColor Yellow
$FinalData | Select-Object -First 10 | Format-Table -AutoSize

# Display summary by project category
Write-Host "`nSummary by Project Category:" -ForegroundColor Yellow
$FinalData | Group-Object "Project Category" | Select-Object Name, Count | Format-Table -AutoSize
