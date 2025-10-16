# =============================================================================
# ENDPOINT: Get Project Metadata (Update Dates and Issue Counts)
# =============================================================================
#
# DESCRIPTION: Gets project metadata including last updated dates and total issue counts
# to determine which projects should be included in analysis based on:
# - Projects updated in the past 90 days
# - Projects with 100+ total issues
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


    # =============================================================================
    # PHASE 1: GET ALL PROJECTS
    # =============================================================================
    Write-Output "PHASE 1: Getting ALL projects from Jira..."

    $ProjectsUrl = "$BaseUrl/rest/api/3/project"
    $AllProjects = @()
    $ProjectStartAt = 0
    $ProjectMaxResults = 100

    do {
        Write-Output "  Fetching projects batch starting at $ProjectStartAt..."

        $ProjectUrlWithParams = "$ProjectsUrl" + "?maxResults=$ProjectMaxResults&startAt=$ProjectStartAt"

        try {
            $ProjectResponse = Invoke-RestMethod -Uri $ProjectUrlWithParams -Method Get -Headers $AuthHeader

            if ($ProjectResponse -is [array]) {
                Write-Output "    Retrieved $($ProjectResponse.Count) projects"
                $AllProjects += $ProjectResponse
                $HasMoreProjects = $ProjectResponse.Count -eq $ProjectMaxResults
            } else {
                Write-Output "    Retrieved 0 projects (unexpected response format)"
                $HasMoreProjects = $false
            }

            $ProjectStartAt += $ProjectMaxResults

        } catch {
            Write-Output "    Failed to fetch projects batch: $($_.Exception.Message)"
            break
        }

    } while ($HasMoreProjects)

    Write-Output "PHASE 1 COMPLETE: Found $($AllProjects.Count) total projects"

    # =============================================================================
    # PHASE 2: GET PROJECT METADATA (UPDATE DATES AND ISSUE COUNTS)
    # =============================================================================
    Write-Output "PHASE 2: Getting project metadata (update dates and issue counts)..."

    $ProjectMetadata = @()
    $CurrentDate = Get-Date
    $NinetyDaysAgo = $CurrentDate.AddDays(-90)

    foreach ($project in $AllProjects) {
        $projectKey = $project.key
        Write-Output "  Processing project: $projectKey"

        try {
            # Get total issue count for this project using Enhanced JQL API
            $EnhancedSearchUrl = "$BaseUrl/rest/api/3/search/jql"
            $CountPayload = @{
                jql = "project = `"$projectKey`""
                maxResults = 0
            }
            $CountPayloadJson = $CountPayload | ConvertTo-Json -Depth 10

            $CountResponse = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $AuthHeader -Body $CountPayloadJson
            $TotalIssues = $CountResponse.total

            # Get the most recent issue update date for this project
            $RecentPayload = @{
                jql = "project = `"$projectKey`" ORDER BY updated DESC"
                maxResults = 1
                fields = @("updated")
            }
            $RecentPayloadJson = $RecentPayload | ConvertTo-Json -Depth 10

            $SearchResponse = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $AuthHeader -Body $RecentPayloadJson

            $LastUpdated = if ($SearchResponse.issues -and $SearchResponse.issues.Count -gt 0) {
                $SearchResponse.issues[0].fields.updated
            } else {
                $null
            }

            $LastUpdatedDate = if ($LastUpdated) {
                [DateTime]::Parse($LastUpdated)
            } else {
                $null
            }

            $IsRecentlyUpdated = if ($LastUpdatedDate) {
                $LastUpdatedDate -gt $NinetyDaysAgo
            } else {
                $false
            }

            $HasMinimumIssues = $TotalIssues -ge 100

            $IncludeInAnalysis = $IsRecentlyUpdated -or $HasMinimumIssues

            $ProjectData = [PSCustomObject]@{
                ProjectKey = $projectKey
                ProjectName = $project.name
                ProjectStatus = if ($project.archived) { "Archived" } else { "Active" }
                TotalIssues = $TotalIssues
                LastUpdated = $LastUpdated
                LastUpdatedDate = if ($LastUpdatedDate) { $LastUpdatedDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
                IsRecentlyUpdated = $IsRecentlyUpdated
                HasMinimumIssues = $HasMinimumIssues
                IncludeInAnalysis = $IncludeInAnalysis
                DaysSinceUpdate = if ($LastUpdatedDate) { [int](($CurrentDate - $LastUpdatedDate).TotalDays) } else { $null }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }

            $ProjectMetadata += $ProjectData

            Write-Output "    ${projectKey}: $TotalIssues issues, last updated: $($LastUpdatedDate), include: $IncludeInAnalysis"

        } catch {
            Write-Output "    Failed to get metadata for ${projectKey} : $($_.Exception.Message)"
            
            # Add project with minimal data
            $ProjectData = [PSCustomObject]@{
                ProjectKey = $projectKey
                ProjectName = $project.name
                ProjectStatus = if ($project.archived) { "Archived" } else { "Active" }
                TotalIssues = 0
                LastUpdated = ""
                LastUpdatedDate = ""
                IsRecentlyUpdated = $false
                HasMinimumIssues = $false
                IncludeInAnalysis = $false
                DaysSinceUpdate = $null
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $ProjectMetadata += $ProjectData
        }

        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 200
    }

    Write-Output "PHASE 2 COMPLETE: Retrieved metadata for $($ProjectMetadata.Count) projects"

    # =============================================================================
    # PHASE 3: ANALYSIS AND SUMMARY
    # =============================================================================
    Write-Output "PHASE 3: Analyzing project metadata..."

    $IncludedProjects = $ProjectMetadata | Where-Object { $_.IncludeInAnalysis -eq $true }
    $ExcludedProjects = $ProjectMetadata | Where-Object { $_.IncludeInAnalysis -eq $false }

    $RecentlyUpdated = $ProjectMetadata | Where-Object { $_.IsRecentlyUpdated -eq $true }
    $HasMinimumIssues = $ProjectMetadata | Where-Object { $_.HasMinimumIssues -eq $true }
    $BothCriteria = $ProjectMetadata | Where-Object { $_.IsRecentlyUpdated -eq $true -and $_.HasMinimumIssues -eq $true }

    # Export to CSV
    $OutputFile = "Project_Metadata_Analysis.csv"
    $ProjectMetadata | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "SUCCESS: Generated CSV file: $(Get-Location)\$OutputFile"
    Write-Output ""
    Write-Output "SUMMARY:"
    Write-Output "  - Total projects analyzed: $($ProjectMetadata.Count)"
    Write-Output "  - Projects included in analysis: $($IncludedProjects.Count)"
    Write-Output "  - Projects excluded from analysis: $($ExcludedProjects.Count)"
    Write-Output ""
    Write-Output "BREAKDOWN BY CRITERIA:"
    Write-Output "  - Projects updated in past 90 days: $($RecentlyUpdated.Count)"
    Write-Output "  - Projects with 100+ issues: $($HasMinimumIssues.Count)"
    Write-Output "  - Projects meeting BOTH criteria: $($BothCriteria.Count)"
    Write-Output "  - Projects meeting EITHER criteria: $($IncludedProjects.Count)"

    # Show excluded projects breakdown
    $ExcludedByDate = $ExcludedProjects | Where-Object { $_.IsRecentlyUpdated -eq $false }
    $ExcludedByIssues = $ExcludedProjects | Where-Object { $_.HasMinimumIssues -eq $false }
    $ExcludedByBoth = $ExcludedProjects | Where-Object { $_.IsRecentlyUpdated -eq $false -and $_.HasMinimumIssues -eq $false }

    Write-Output ""
    Write-Output "EXCLUDED PROJECTS BREAKDOWN:"
    Write-Output "  - Excluded by date (not updated in 90 days): $($ExcludedByDate.Count)"
    Write-Output "  - Excluded by issue count (< 100 issues): $($ExcludedByIssues.Count)"
    Write-Output "  - Excluded by BOTH criteria: $($ExcludedByBoth.Count)"

    # Show top projects by issue count
    Write-Output ""
    Write-Output "TOP 10 PROJECTS BY ISSUE COUNT:"
    $ProjectMetadata | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table ProjectKey, ProjectName, TotalIssues, LastUpdatedDate, IncludeInAnalysis -AutoSize

    # Show most recently updated projects
    Write-Output ""
    Write-Output "TOP 10 MOST RECENTLY UPDATED PROJECTS:"
    $ProjectMetadata | Where-Object { $_.LastUpdatedDate -ne "" } | Sort-Object LastUpdatedDate -Descending | Select-Object -First 10 | Format-Table ProjectKey, ProjectName, LastUpdatedDate, TotalIssues, IncludeInAnalysis -AutoSize

    # Show included projects summary
    Write-Output ""
    Write-Output "PROJECTS INCLUDED IN ANALYSIS (Top 20):"
    $IncludedProjects | Sort-Object TotalIssues -Descending | Select-Object -First 20 | Format-Table ProjectKey, ProjectName, TotalIssues, LastUpdatedDate, IsRecentlyUpdated, HasMinimumIssues -AutoSize

} catch {
    Write-Output "Failed to retrieve project metadata: $($_.Exception.Message)"
    exit 1
}

