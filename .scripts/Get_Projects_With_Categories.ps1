# =============================================================================
# PowerShell Script: Get Projects and Their Categories
# =============================================================================
#
# DESCRIPTION: This script fetches all projects with their category information
# and exports it to a CSV file.
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
function Get-AllProjectsWithCategories {
    Write-Host "Fetching all projects with categories..."
    
    $AllProjects = @()
    $StartAt = 0
    $MaxResults = 100
    
    do {
        $ProjectsEndpoint = "/rest/api/3/project/search?startAt=$StartAt&maxResults=$MaxResults&expand=projectCategory,lead"
        $ProjectsUrl = $BaseUrl + $ProjectsEndpoint
        
        try {
            $ProjectsResponse = Invoke-RestMethod -Uri $ProjectsUrl -Headers @{
                "Authorization" = $AuthHeader
                "Content-Type" = "application/json"
            }
            
            foreach ($project in $ProjectsResponse.values) {
                $ProjectCategoryName = if ($project.projectCategory -and $project.projectCategory.name) { 
                    $project.projectCategory.name 
                } else { 
                    "No Category" 
                }
                
                $ProjectCategoryId = if ($project.projectCategory -and $project.projectCategory.id) { 
                    $project.projectCategory.id 
                } else { 
                    "" 
                }
                
                $ProjectLeadName = if ($project.lead -and $project.lead.displayName) { 
                    $project.lead.displayName 
                } else { 
                    "No Lead" 
                }
                
                $ProjectLeadEmail = if ($project.lead -and $project.lead.emailAddress) { 
                    $project.lead.emailAddress 
                } else { 
                    "" 
                }
                
                $AllProjects += [PSCustomObject]@{
                    ProjectKey = $project.key
                    ProjectName = $project.name
                    ProjectId = $project.id
                    ProjectCategoryName = $ProjectCategoryName
                    ProjectCategoryId = $ProjectCategoryId
                    ProjectLeadName = $ProjectLeadName
                    ProjectLeadEmail = $ProjectLeadEmail
                }
            }
            
            $StartAt += $MaxResults
            Write-Host "Fetched $($ProjectsResponse.values.Count) projects (Total so far: $($AllProjects.Count))"
            
        } catch {
            Write-Error "Failed to fetch projects at startAt=$StartAt`: $($_.Exception.Message)"
            break
        }
        
    } while ($ProjectsResponse.values.Count -eq $MaxResults)
    
    Write-Host "Total projects found: $($AllProjects.Count)"
    return $AllProjects
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
Write-Host "Starting project and category data collection..." -ForegroundColor Green

# Get all projects with categories
$AllProjects = Get-AllProjectsWithCategories

if ($AllProjects.Count -eq 0) {
    Write-Error "Failed to retrieve projects. Exiting."
    exit 1
}

# Create final dataset with just the essential fields
$FinalData = $AllProjects | Select-Object @{
    Name = "Project Key"
    Expression = { $_.ProjectKey }
}, @{
    Name = "Project"
    Expression = { $_.ProjectName }
}, @{
    Name = "Project Category"
    Expression = { $_.ProjectCategoryName }
}, @{
    Name = "Project Lead"
    Expression = { $_.ProjectLeadName }
}

# Export to CSV
$OutputFile = "Projects_With_Categories.csv"
$FinalData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Host "`n" -NoNewline
Write-Host "=" * 50 -ForegroundColor Green
Write-Host "EXPORT COMPLETE!" -ForegroundColor Green
Write-Host "=" * 50 -ForegroundColor Green
Write-Host "File: $OutputFile" -ForegroundColor Green
Write-Host "Total projects: $($FinalData.Count)" -ForegroundColor Green

# Display sample data
Write-Host "`nSample data:" -ForegroundColor Yellow
$FinalData | Select-Object -First 10 | Format-Table -AutoSize

# Display summary by project category
Write-Host "`nSummary by Project Category:" -ForegroundColor Yellow
$FinalData | Group-Object "Project Category" | Select-Object Name, Count | Sort-Object Count -Descending | Format-Table -AutoSize

# Display all unique categories
Write-Host "`nAll Project Categories:" -ForegroundColor Yellow
$Categories = $FinalData | Group-Object "Project Category" | Select-Object Name, Count | Sort-Object Name
$Categories | Format-Table -AutoSize
