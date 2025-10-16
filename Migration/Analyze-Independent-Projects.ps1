# =============================================================================
# ANALYZE INDEPENDENT PROJECTS - NO CROSS-PROJECT DEPENDENCIES
# =============================================================================
#
# PURPOSE: Find projects in OneMain that have NO cross-project dependencies
# and get their resolved/unresolved issue counts.
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
$AuthHeader = Get-AuthHeader -Parameters $Params

Write-Host "=== ANALYZING INDEPENDENT PROJECTS ===" -ForegroundColor Green

try {
    # =============================================================================
    # STEP 1: Load existing data from CSV files
    # =============================================================================
    Write-Host "Loading project data from existing CSV files..." -ForegroundColor Yellow
    
    $ProjectsCsv = ".endpoints\Projects\Projects - GET Projects Paginated - Anon - Official.csv"
    $LinksCsv = ".endpoints\Issue links\Issue Links - GET Project to Project Links - Anon - Official.csv"
    
    if (-not (Test-Path $ProjectsCsv)) {
        Write-Error "Projects CSV not found: $ProjectsCsv"
        exit 1
    }
    
    if (-not (Test-Path $LinksCsv)) {
        Write-Error "Links CSV not found: $LinksCsv"
        exit 1
    }
    
    $AllProjects = Import-Csv $ProjectsCsv
    $ProjectLinks = Import-Csv $LinksCsv
    
    Write-Host "Loaded $($AllProjects.Count) projects and $($ProjectLinks.Count) link records" -ForegroundColor Green
    
    # =============================================================================
    # STEP 2: Find projects with NO cross-project dependencies
    # =============================================================================
    Write-Host "Finding projects with no cross-project dependencies..." -ForegroundColor Yellow
    
    $IndependentProjects = $ProjectLinks | Where-Object { 
        $_.LinkCount -eq "0" -or $_.LinkCount -eq 0 
    }
    
    Write-Host "Found $($IndependentProjects.Count) projects with no cross-project dependencies" -ForegroundColor Green
    
    # =============================================================================
    # STEP 3: Get issue counts for each independent project
    # =============================================================================
    Write-Host "Getting issue counts for independent projects..." -ForegroundColor Yellow
    
    $Results = @()
    $TotalProjects = $IndependentProjects.Count
    $CurrentProject = 0
    
    foreach ($project in $IndependentProjects) {
        $CurrentProject++
        $projectKey = $project.ProjectKey
        
        Write-Host "  Processing $CurrentProject/$TotalProjects : $projectKey" -ForegroundColor Cyan
        
        try {
            # Get project details
            $projectDetails = $AllProjects | Where-Object { $_.Key -eq $projectKey }
            $projectName = if ($projectDetails) { $projectDetails.Name } else { "Unknown" }
            
            # Get issue counts using JQL
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
            
            Write-Host "    ✅ ${projectKey}: $resolvedCount resolved, $unresolvedCount unresolved" -ForegroundColor Gray
            
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
    # STEP 4: Export results
    # =============================================================================
    Write-Host "Exporting results..." -ForegroundColor Yellow
    
    $OutputFile = "Independent-Projects-Analysis.csv"
    $Results | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host "Results exported to: $((Get-Location).Path)\$OutputFile" -ForegroundColor Green
    
    # =============================================================================
    # STEP 5: Display summary
    # =============================================================================
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Green
    Write-Host "Total independent projects analyzed: $($Results.Count)" -ForegroundColor White
    Write-Host "Projects with issues: $(($Results | Where-Object { $_.TotalIssues -gt 0 }).Count)" -ForegroundColor White
    Write-Host "Projects with no issues: $(($Results | Where-Object { $_.TotalIssues -eq 0 }).Count)" -ForegroundColor White
    
    $TotalResolved = ($Results | Measure-Object -Property ResolvedCount -Sum).Sum
    $TotalUnresolved = ($Results | Measure-Object -Property UnresolvedCount -Sum).Sum
    
    Write-Host "Total resolved issues: $TotalResolved" -ForegroundColor Green
    Write-Host "Total unresolved issues: $TotalUnresolved" -ForegroundColor Yellow
    
    Write-Host ""
    Write-Host "=== TOP 10 PROJECTS BY TOTAL ISSUES ===" -ForegroundColor Green
    $Results | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table -AutoSize
    
    Write-Host ""
    Write-Host "=== PROJECTS WITH NO ISSUES ===" -ForegroundColor Yellow
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
