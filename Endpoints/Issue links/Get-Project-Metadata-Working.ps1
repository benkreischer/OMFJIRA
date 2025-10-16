# =============================================================================
# PROJECT METADATA COLLECTION - BASED ON WORKING ISSUE SEARCH SCRIPT
# =============================================================================
# Based on the working Issue Search script to get project metadata
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$DaysBack = 90
$MinIssueCount = 100
$CutoffDate = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")

Write-Output "Starting Project Metadata Collection..."
Write-Output "Filtering criteria: Projects updated since $CutoffDate OR with $MinIssueCount+ issues"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Format-JiraDate {
    param([string]$DateString)
    
    if ([string]::IsNullOrEmpty($DateString)) {
        return ""
    }
    
    try {
        # Parse the Jira date string (ISO 8601 format)
        $Date = [DateTime]::Parse($DateString)
        # Format as Excel-friendly date (MM/dd/yyyy HH:mm:ss)
        return $Date.ToString("MM/dd/yyyy HH:mm:ss")
    } catch {
        # If parsing fails, return original string
        return $DateString
    }
}

# =============================================================================
# PHASE 1: GET ALL PROJECTS
# =============================================================================
Write-Output "PHASE 1: Getting all projects from Jira..."

$ProjectsUrl = "$BaseUrl/rest/api/3/project"
$AllProjects = @()
$StartAt = 0
$MaxResults = $Params.ApiSettings.MaxResults

do {
    Write-Output "  Fetching projects batch starting at $StartAt..."
    
    $ProjectsResponse = Invoke-RestMethod -Uri "${ProjectsUrl}?startAt=${StartAt}&maxResults=${MaxResults}" -Method Get -Headers $AuthHeader
    $AllProjects += $ProjectsResponse.values
    
    Write-Output "    Retrieved $($ProjectsResponse.values.Count) projects from this batch"
    Write-Output "    Total projects collected: $($AllProjects.Count)"
    
    $StartAt += $MaxResults
} while ($ProjectsResponse.values.Count -eq $MaxResults)

Write-Output "PHASE 1 COMPLETE: Found $($AllProjects.Count) total projects"

# =============================================================================
# PHASE 2: GET PROJECT METADATA USING WORKING API APPROACH
# =============================================================================
Write-Output "PHASE 2: Getting project metadata (update dates and issue counts)..."

$EnhancedSearchUrl = "$BaseUrl/rest/api/3/search/jql"
$ProjectMetadata = @()

foreach ($project in $AllProjects) {
    $projectKey = $project.key
    Write-Output "  Processing project: $projectKey"

    try {
        # Get total issue count for this project using the working approach
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

        # Parse the last updated date
        $LastUpdatedDate = if ($LastUpdated) {
            try {
                [DateTime]::Parse($LastUpdated)
            } catch {
                $null
            }
        } else {
            $null
        }

        # Determine if project should be included
        $IncludeInAnalysis = $false
        if ($LastUpdatedDate) {
            $IncludeInAnalysis = ($LastUpdatedDate -gt $CutoffDate) -or ($TotalIssues -ge $MinIssueCount)
        } else {
            # If no last updated date, include if it has enough issues
            $IncludeInAnalysis = $TotalIssues -ge $MinIssueCount
        }

        $ProjectData = [PSCustomObject]@{
            ProjectKey = $projectKey
            ProjectName = $project.name
            TotalIssues = $TotalIssues
            LastUpdatedDate = if ($LastUpdatedDate) { $LastUpdatedDate.ToString("yyyy-MM-dd HH:mm:ss") } else { "" }
            IncludeInAnalysis = $IncludeInAnalysis
        }

        $ProjectMetadata += $ProjectData

        Write-Output "    Issues: $TotalIssues, Last Updated: $(if ($LastUpdatedDate) { $LastUpdatedDate.ToString('yyyy-MM-dd') } else { 'Never' }), Include: $IncludeInAnalysis"

    } catch {
        Write-Output "    Failed to get metadata for $projectKey : $($_.Exception.Message)"
        
        # Add failed project with default values
        $ProjectData = [PSCustomObject]@{
            ProjectKey = $projectKey
            ProjectName = $project.name
            TotalIssues = 0
            LastUpdatedDate = ""
            IncludeInAnalysis = $false
        }
        $ProjectMetadata += $ProjectData
    }
}

Write-Output "PHASE 2 COMPLETE: Retrieved metadata for $($ProjectMetadata.Count) projects"

# =============================================================================
# PHASE 3: ANALYZE AND EXPORT RESULTS
# =============================================================================
Write-Output "PHASE 3: Analyzing project metadata..."

# Filter projects for analysis
$IncludedProjects = $ProjectMetadata | Where-Object { $_.IncludeInAnalysis -eq $true }
$ExcludedProjects = $ProjectMetadata | Where-Object { $_.IncludeInAnalysis -eq $false }

# Count by criteria
$UpdatedIn90Days = $ProjectMetadata | Where-Object { 
    $_.LastUpdatedDate -and 
    ([DateTime]::Parse($_.LastUpdatedDate) -gt $CutoffDate) 
} | Measure-Object | Select-Object -ExpandProperty Count

$Has100PlusIssues = $ProjectMetadata | Where-Object { $_.TotalIssues -ge $MinIssueCount } | Measure-Object | Select-Object -ExpandProperty Count

$BothCriteria = $ProjectMetadata | Where-Object { 
    ($_.LastUpdatedDate -and ([DateTime]::Parse($_.LastUpdatedDate) -gt $CutoffDate)) -and 
    ($_.TotalIssues -ge $MinIssueCount) 
} | Measure-Object | Select-Object -ExpandProperty Count

$EitherCriteria = $ProjectMetadata | Where-Object { 
    ($_.LastUpdatedDate -and ([DateTime]::Parse($_.LastUpdatedDate) -gt $CutoffDate)) -or 
    ($_.TotalIssues -ge $MinIssueCount) 
} | Measure-Object | Select-Object -ExpandProperty Count

# Export to CSV
$OutputFile = "Project_Metadata_Analysis_Working.csv"
$ProjectMetadata | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Output "SUCCESS: Generated CSV file: $OutputFile"
Write-Output ""
Write-Output "SUMMARY:"
Write-Output "  - Total projects analyzed: $($ProjectMetadata.Count)"
Write-Output "  - Projects included in analysis: $($IncludedProjects.Count)"
Write-Output "  - Projects excluded from analysis: $($ExcludedProjects.Count)"
Write-Output ""
Write-Output "BREAKDOWN BY CRITERIA:"
Write-Output "  - Projects updated in past $DaysBack days: $UpdatedIn90Days"
Write-Output "  - Projects with $MinIssueCount+ issues: $Has100PlusIssues"
Write-Output "  - Projects meeting BOTH criteria: $BothCriteria"
Write-Output "  - Projects meeting EITHER criteria: $EitherCriteria"
Write-Output ""
Write-Output "EXCLUDED PROJECTS BREAKDOWN:"
Write-Output "  - Excluded by date (not updated in $DaysBack days): $($ExcludedProjects | Where-Object { $_.LastUpdatedDate -and ([DateTime]::Parse($_.LastUpdatedDate) -le $CutoffDate) } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Output "  - Excluded by issue count (< $MinIssueCount issues): $($ExcludedProjects | Where-Object { $_.TotalIssues -lt $MinIssueCount } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Output "  - Excluded by BOTH criteria: $($ExcludedProjects | Where-Object { ($_.LastUpdatedDate -and ([DateTime]::Parse($_.LastUpdatedDate) -le $CutoffDate)) -and ($_.TotalIssues -lt $MinIssueCount) } | Measure-Object | Select-Object -ExpandProperty Count)"

# Show top projects by issue count
Write-Output ""
Write-Output "TOP 10 PROJECTS BY ISSUE COUNT:"
$ProjectMetadata | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table -AutoSize

# Show most recently updated projects
Write-Output ""
Write-Output "TOP 10 MOST RECENTLY UPDATED PROJECTS:"
$ProjectMetadata | Where-Object { $_.LastUpdatedDate } | Sort-Object LastUpdatedDate -Descending | Select-Object -First 10 | Format-Table -AutoSize

# Show included projects
if ($IncludedProjects.Count -gt 0) {
    Write-Output ""
    Write-Output "PROJECTS INCLUDED IN ANALYSIS (Top 20):"
    $IncludedProjects | Sort-Object TotalIssues -Descending | Select-Object -First 20 | Format-Table -AutoSize
} else {
    Write-Output ""
    Write-Output "NO PROJECTS MEET THE INCLUSION CRITERIA!"
}

