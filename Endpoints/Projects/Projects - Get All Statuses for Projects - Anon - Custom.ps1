# =============================================================================
# PROJECTS - GET ALL STATUSES FOR ALL PROJECTS
# =============================================================================
# This script calls the Jira REST API to get all statuses for all projects
# API Endpoints: GET /rest/api/3/project/search (paginated) + GET /rest/api/3/project/{projectIdOrKey}/statuses
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

Write-Host "=== PROJECTS - GET ALL STATUSES FOR ALL PROJECTS ===" -ForegroundColor Green

try {
    Write-Host "Step 1: Fetching all projects..." -ForegroundColor Yellow
    
    # Get all projects using pagination
    $allProjects = @()
    $startAt = 0
    $MaxResults = $Params.MaxResults
    
    do {
        $projectUrl = "$BaseUrl/rest/api/3/project/search?startAt=$startAt&maxResults=$maxResults"
        Write-Host "Fetching projects: startAt=$startAt, maxResults=$maxResults" -ForegroundColor Cyan
        
        $projectResponse = Invoke-RestMethod -Uri $projectUrl -Method GET -Headers @{
            "Authorization" = $AuthHeader
            "Accept" = "application/json"
        }
        
        $allProjects += $projectResponse.values
        $startAt += $maxResults
        
        Write-Host "Retrieved $($projectResponse.values.Count) projects (Total so far: $($allProjects.Count))" -ForegroundColor Gray
        
    } while ($projectResponse.values.Count -eq $maxResults -and $projectResponse.isLast -ne $true)
    
    Write-Host "Total projects found: $($allProjects.Count)" -ForegroundColor Green
    
    Write-Host "Step 2: Fetching statuses for each project..." -ForegroundColor Yellow
    
    # Get statuses for each project
    $allStatuses = @()
    $projectCount = 0
    
    foreach ($project in $allProjects) {
        $projectCount++
        $projectKey = $project.key
        $projectId = $project.id
        $projectName = $project.name
        
        Write-Host "Processing project $projectCount/$($allProjects.Count): $projectKey ($projectName)" -ForegroundColor Cyan
        
        try {
            # Get statuses for this project
            $statusUrl = "$BaseUrl/rest/api/3/project/$projectKey/statuses"
            $statusResponse = Invoke-RestMethod -Uri $statusUrl -Method GET -Headers @{
                "Authorization" = $AuthHeader
                "Accept" = "application/json"
            }
            
            # Process each issue type and its statuses
            foreach ($issueType in $statusResponse) {
                $issueTypeId = $issueType.id
                $issueTypeName = $issueType.name
                $issueTypeSubtask = if ($issueType.subtask) { $issueType.subtask.ToString().ToLower() } else { "" }
                
                foreach ($status in $issueType.statuses) {
                    $statusData = [PSCustomObject]@{
                        ProjectKey = $projectKey
                        ProjectId = $projectId
                        ProjectName = $projectName
                        ProjectTypeKey = if ($project.projectTypeKey) { $project.projectTypeKey } else { "" }
                        ProjectSimplified = if ($project.simplified) { $project.simplified.ToString().ToLower() } else { "" }
                        IssueTypeId = $issueTypeId
                        IssueTypeName = $issueTypeName
                        IssueTypeSubtask = $issueTypeSubtask
                        IssueTypeSelf = if ($issueType.self) { $issueType.self } else { "" }
                        StatusId = if ($status.id) { $status.id } else { "" }
                        StatusName = if ($status.name) { $status.name } else { "" }
                        StatusDescription = if ($status.description) { $status.description } else { "" }
                        StatusIconUrl = if ($status.iconUrl) { $status.iconUrl } else { "" }
                        StatusSelf = if ($status.self) { $status.self } else { "" }
                        StatusCategoryId = if ($status.statusCategory -and $status.statusCategory.id) { $status.statusCategory.id } else { "" }
                        StatusCategoryKey = if ($status.statusCategory -and $status.statusCategory.key) { $status.statusCategory.key } else { "" }
                        StatusCategoryName = if ($status.statusCategory -and $status.statusCategory.name) { $status.statusCategory.name } else { "" }
                        StatusCategoryColorName = if ($status.statusCategory -and $status.statusCategory.colorName) { $status.statusCategory.colorName } else { "" }
                        StatusCategorySelf = if ($status.statusCategory -and $status.statusCategory.self) { $status.statusCategory.self } else { "" }
                    }
                    
                    $allStatuses += $statusData
                }
            }
            
        } catch {
            Write-Host "  Warning: Failed to get statuses for project $projectKey - $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "Step 3: Exporting data to CSV..." -ForegroundColor Yellow
    
    # Export to CSV
    $outputFile = "Projects - Get All Statuses for All Projects - BK Anon.csv"
    $allStatuses | Export-Csv -Path $outputFile -NoTypeInformation
    
    Write-Host "Data exported to: $((Get-Location).Path)\$outputFile" -ForegroundColor Green
    Write-Host "Total records found: $($allStatuses.Count)" -ForegroundColor Green
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
}

