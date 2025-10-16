# =============================================================================
# GET INDEPENDENT PROJECTS - FIXED VERSION
# =============================================================================
#
# PURPOSE: Find projects in OneMain that have NO cross-project dependencies
# and get their resolved/unresolved issue counts using live API calls.
#
# OUTPUT: 4 columns - Project Key, Project Name, Resolved Count, Unresolved Count
#
# =============================================================================

# Load helper functions
$HelperPath = Join-Path $PSScriptRoot ".endpoints\Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

# Get parameters
$ParamsPath = Join-Path $PSScriptRoot ".endpoints\endpoints-parameters.json"
$Params = Get-EndpointParameters -ParametersPath $ParamsPath
$BaseUrl = $Params.BaseUrl

# Create Basic Auth Header
$AuthString = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($Params.Username):$($Params.ApiToken)"))
$AuthHeader = "Basic $AuthString"

Write-Host "=== ANALYZING INDEPENDENT PROJECTS - FIXED VERSION ===" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow

try {
    # =============================================================================
    # STEP 1: Get ALL active projects from Jira API
    # =============================================================================
    Write-Host "Getting all active projects from Jira API..." -ForegroundColor Yellow
    
    $AllProjects = @()
    $StartAt = 0
    $MaxResults = 100
    
    do {
        $ProjectsUrl = "$BaseUrl/rest/api/3/project/search?startAt=$StartAt&maxResults=$MaxResults&expand=lead,description,issueTypes"
        
        Write-Host "  Fetching projects batch starting at $StartAt..." -ForegroundColor Cyan
        
        try {
            $Response = Invoke-RestMethod -Uri $ProjectsUrl -Method GET -Headers @{
                "Authorization" = $AuthHeader
                "Accept" = "application/json"
            }
            
            $BatchProjects = $Response.values | Where-Object { -not $_.archived }
            $AllProjects += $BatchProjects
            
            Write-Host "    Retrieved $($BatchProjects.Count) active projects (Total: $($AllProjects.Count))" -ForegroundColor Gray
            
            $StartAt += $MaxResults
            
        } catch {
            Write-Warning "    Failed to fetch projects batch: $($_.Exception.Message)"
            break
        }
        
    } while ($Response.values.Count -eq $MaxResults -and $Response.isLast -ne $true)
    
    Write-Host "Found $($AllProjects.Count) active projects" -ForegroundColor Green
    
    # =============================================================================
    # STEP 2: Get cross-project links using a different approach
    # =============================================================================
    Write-Host "Analyzing cross-project dependencies..." -ForegroundColor Yellow
    
    $ProjectLinks = @{}
    $TotalProjects = $AllProjects.Count
    $CurrentProject = 0
    
    # Initialize all projects with empty links
    foreach ($project in $AllProjects) {
        $ProjectLinks[$project.key] = @()
    }
    
    # Get all issues with links across all projects
    Write-Host "  Getting all issues with links..." -ForegroundColor Cyan
    
    try {
        # Query for all issues that have links
        $JqlQuery = "issueLink IS NOT EMPTY ORDER BY project ASC, created DESC"
        $SearchUrl = "$BaseUrl/rest/api/3/search"
        
        $StartAt = 0
        $MaxResults = 1000
        
        do {
            $SearchParams = @{
                jql = $JqlQuery
                maxResults = $MaxResults
                startAt = $StartAt
                fields = "key,project,issuelinks"
            }
            
            $SearchResponse = Invoke-RestMethod -Uri $SearchUrl -Method GET -Headers @{
                "Authorization" = $AuthHeader
                "Accept" = "application/json"
            } -Body $SearchParams
            
            Write-Host "    Processing $($SearchResponse.issues.Count) issues with links..." -ForegroundColor Gray
            
            # Process issues with links to find cross-project relationships
            foreach ($issue in $SearchResponse.issues) {
                $issueProjectKey = $issue.fields.project.key
                
                if ($issue.fields.issuelinks) {
                    foreach ($link in $issue.fields.issuelinks) {
                        # Check inward links
                        if ($link.inwardIssue -and $link.inwardIssue.key) {
                            $linkedProjectKey = ($link.inwardIssue.key -split '-')[0]
                            if ($linkedProjectKey -and $linkedProjectKey -ne $issueProjectKey -and $ProjectLinks.ContainsKey($linkedProjectKey)) {
                                $ProjectLinks[$issueProjectKey] += $linkedProjectKey
                            }
                        }
                        # Check outward links
                        if ($link.outwardIssue -and $link.outwardIssue.key) {
                            $linkedProjectKey = ($link.outwardIssue.key -split '-')[0]
                            if ($linkedProjectKey -and $linkedProjectKey -ne $issueProjectKey -and $ProjectLinks.ContainsKey($linkedProjectKey)) {
                                $ProjectLinks[$issueProjectKey] += $linkedProjectKey
                            }
                        }
                    }
                }
            }
            
            $StartAt += $MaxResults
            
        } while ($SearchResponse.issues.Count -eq $MaxResults)
        
    } catch {
        Write-Warning "  Failed to analyze links: $($_.Exception.Message)"
    }
    
    # =============================================================================
    # STEP 3: Find projects with NO cross-project dependencies
    # =============================================================================
    Write-Host "Identifying projects with no cross-project dependencies..." -ForegroundColor Yellow
    
    $IndependentProjects = @()
    foreach ($projectKey in $ProjectLinks.Keys) {
        $uniqueLinkedProjects = $ProjectLinks[$projectKey] | Sort-Object -Unique | Where-Object { $_ -ne "" }
        if ($uniqueLinkedProjects.Count -eq 0) {
            $project = $AllProjects | Where-Object { $_.key -eq $projectKey }
            $IndependentProjects += $project
        }
    }
    
    Write-Host "Found $($IndependentProjects.Count) projects with no cross-project dependencies" -ForegroundColor Green
    
    # =============================================================================
    # STEP 4: Get issue counts for independent projects
    # =============================================================================
    Write-Host "Getting issue counts for independent projects..." -ForegroundColor Yellow
    
    $Results = @()
    $TotalIndependent = $IndependentProjects.Count
    $CurrentIndependent = 0
    
    foreach ($project in $IndependentProjects) {
        $CurrentIndependent++
        $projectKey = $project.key
        $projectName = $project.name
        
        Write-Host "  Processing $CurrentIndependent/$TotalIndependent : $projectKey" -ForegroundColor Cyan
        
        try {
            $resolvedCount = 0
            $unresolvedCount = 0
            
            # Query for resolved issues
            $resolvedJql = "project = `"$projectKey`" AND resolution IS NOT EMPTY"
            $resolvedUrl = "$BaseUrl/rest/api/3/search?jql=" + [System.Web.HttpUtility]::UrlEncode($resolvedJql) + "&maxResults=0"
            
            try {
                $resolvedResponse = Invoke-RestMethod -Uri $resolvedUrl -Method GET -Headers @{
                    "Authorization" = $AuthHeader
                    "Accept" = "application/json"
                }
                $resolvedCount = $resolvedResponse.total
            } catch {
                Write-Warning "    Failed to get resolved count for ${projectKey} : $($_.Exception.Message)"
            }
            
            # Query for unresolved issues
            $unresolvedJql = "project = `"$projectKey`" AND resolution IS EMPTY"
            $unresolvedUrl = "$BaseUrl/rest/api/3/search?jql=" + [System.Web.HttpUtility]::UrlEncode($unresolvedJql) + "&maxResults=0"
            
            try {
                $unresolvedResponse = Invoke-RestMethod -Uri $unresolvedUrl -Method GET -Headers @{
                    "Authorization" = $AuthHeader
                    "Accept" = "application/json"
                }
                $unresolvedCount = $unresolvedResponse.total
            } catch {
                Write-Warning "    Failed to get unresolved count for ${projectKey} : $($_.Exception.Message)"
            }
            
            # Add to results
            $Results += [PSCustomObject]@{
                ProjectKey = $projectKey
                ProjectName = $projectName
                ResolvedCount = $resolvedCount
                UnresolvedCount = $unresolvedCount
                TotalIssues = $resolvedCount + $unresolvedCount
            }
            
            Write-Host "    ✅ ${projectKey}: $resolvedCount resolved, $unresolvedCount unresolved" -ForegroundColor Green
            
            # Small delay to avoid rate limiting
            Start-Sleep -Milliseconds 200
            
        } catch {
            Write-Warning "  ❌ Failed to process $projectKey : $($_.Exception.Message)"
            
            # Add failed project to results with zero counts
            $Results += [PSCustomObject]@{
                ProjectKey = $projectKey
                ProjectName = "Error - Could not retrieve"
                ResolvedCount = 0
                UnresolvedCount = 0
                TotalIssues = 0
            }
        }
    }
    
    # =============================================================================
    # STEP 5: Export results
    # =============================================================================
    Write-Host "Exporting results..." -ForegroundColor Yellow
    
    $OutputFile = "Independent-Projects-Fixed-Analysis.csv"
    $Results | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host "Results exported to: $((Get-Location).Path)\$OutputFile" -ForegroundColor Green
    
    # =============================================================================
    # STEP 6: Display summary
    # =============================================================================
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Green
    Write-Host "Total active projects analyzed: $($AllProjects.Count)" -ForegroundColor White
    Write-Host "Projects with cross-project dependencies: $(($AllProjects.Count - $IndependentProjects.Count))" -ForegroundColor White
    Write-Host "Independent projects (no cross-project deps): $($IndependentProjects.Count)" -ForegroundColor White
    Write-Host "Independent projects with issues: $(($Results | Where-Object { $_.TotalIssues -gt 0 }).Count)" -ForegroundColor White
    Write-Host "Independent projects with no issues: $(($Results | Where-Object { $_.TotalIssues -eq 0 }).Count)" -ForegroundColor White
    
    $TotalResolved = ($Results | Measure-Object -Property ResolvedCount -Sum).Sum
    $TotalUnresolved = ($Results | Measure-Object -Property UnresolvedCount -Sum).Sum
    
    Write-Host "Total resolved issues in independent projects: $TotalResolved" -ForegroundColor Green
    Write-Host "Total unresolved issues in independent projects: $TotalUnresolved" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "=== TOP 10 INDEPENDENT PROJECTS BY TOTAL ISSUES ===" -ForegroundColor Green
    $Results | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table -AutoSize
    
    Write-Host ""
    Write-Host "=== INDEPENDENT PROJECTS WITH NO ISSUES ===" -ForegroundColor Yellow
    $NoIssuesProjects = $Results | Where-Object { $_.TotalIssues -eq 0 }
    if ($NoIssuesProjects.Count -gt 0) {
        $NoIssuesProjects | Format-Table ProjectKey, ProjectName -AutoSize
    } else {
        Write-Host "None - all independent projects have issues" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "=== COMPLETE RESULTS (4 COLUMNS) ===" -ForegroundColor Green
    $Results | Sort-Object TotalIssues -Descending | Format-Table ProjectKey, ProjectName, ResolvedCount, UnresolvedCount -AutoSize
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Full error: $($_.Exception)" -ForegroundColor Red
    exit 1
}
