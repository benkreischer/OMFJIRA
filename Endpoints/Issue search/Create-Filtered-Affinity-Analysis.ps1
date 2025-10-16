# =============================================================================
# CREATE FILTERED AFFINITY ANALYSIS
# =============================================================================
# Filters the comprehensive dataset and creates new affinity analysis
# Criteria: Unresolved issues only + Projects with activity in last 90 days
# =============================================================================

Write-Output "Starting Filtered Affinity Analysis Creation..."

# =============================================================================
# LOAD COMPREHENSIVE DATASET
# =============================================================================
Write-Output "PHASE 1: Loading comprehensive dataset..."

$DatasetFile = "All Issues with Links - Complete Dataset.csv"
if (-not (Test-Path $DatasetFile)) {
    Write-Error "Dataset file not found: $DatasetFile"
    exit
}

$AllIssues = Import-Csv $DatasetFile
Write-Output "  Loaded $($AllIssues.Count) total issues"

# =============================================================================
# APPLY FILTERING CRITERIA
# =============================================================================
Write-Output "PHASE 2: Applying filtering criteria..."

# Filter 1: Unresolved issues only
$UnresolvedStatuses = @("Open", "In Progress", "Ready for Work", "Backlog", "Refinement", "To Do", "New", "Active", "Assigned", "Reopened", "In Review", "Testing", "QA", "Staging", "Production", "Deployed", "Monitoring")

$UnresolvedIssues = $AllIssues | Where-Object { 
    $_.Status -in $UnresolvedStatuses -and $_.Status -notmatch "Done|Closed|Resolved|Complete|Finished|Cancelled|Rejected|Won't Fix"
}

Write-Output "  Unresolved issues: $($UnresolvedIssues.Count) (from $($AllIssues.Count) total)"

# Filter 2: Projects with activity in last 90 days (based on "Updated" field)
$CutoffDate = (Get-Date).AddDays(-90)

# Get projects with recent activity
$ProjectsWithRecentActivity = $UnresolvedIssues | Where-Object {
    if ([string]::IsNullOrEmpty($_.Updated)) {
        $false
    } else {
        try {
            $UpdateDate = [DateTime]::Parse($_.Updated)
            $UpdateDate -gt $CutoffDate
        } catch {
            $false
        }
    }
} | Group-Object ProjectKey | Where-Object { $_.Count -gt 0 } | Select-Object -ExpandProperty Name

Write-Output "  Projects with activity in last 90 days: $($ProjectsWithRecentActivity.Count)"

# Filter 3: Exclude ORL, TOKR, RC, EOKR, and OBSRV projects (archived/inactive)
$ExcludedProjects = @("ORL", "TOKR", "RC", "EOKR", "OBSRV")
$ProjectsWithRecentActivity = $ProjectsWithRecentActivity | Where-Object { $_ -notin $ExcludedProjects }

# Filter 4: Apply all criteria - unresolved issues from active projects (excluding ORL)
$FilteredIssues = $UnresolvedIssues | Where-Object { $_.ProjectKey -in $ProjectsWithRecentActivity }

Write-Output "  Final filtered issues: $($FilteredIssues.Count)"

# =============================================================================
# CREATE PROJECT-TO-PROJECT LINKS
# =============================================================================
Write-Output "PHASE 3: Creating project-to-project links..."

$ProjectLinks = @()

foreach ($issue in $FilteredIssues) {
    if ([string]::IsNullOrEmpty($issue.LinkedIssues)) {
        continue
    }
    
    $SourceProject = $issue.ProjectKey
    $LinkedIssueKeys = $issue.LinkedIssues -split ";"
    
    foreach ($linkedKey in $LinkedIssueKeys) {
        if ([string]::IsNullOrWhiteSpace($linkedKey)) {
            continue
        }
        
        # Extract project key from linked issue key (format: PROJECT-123)
        $TargetProject = $linkedKey -replace "-.*$", ""
        
        # Skip self-links and ensure both projects are in our filtered set
        if ($SourceProject -ne $TargetProject -and $TargetProject -in $ProjectsWithRecentActivity) {
            $ProjectLinks += [PSCustomObject]@{
                SourceProject = $SourceProject
                TargetProject = $TargetProject
                IssueKey = $issue.Key
                LinkedIssueKey = $linkedKey
                IssueStatus = $issue.Status
            }
        }
    }
}

Write-Output "  Created $($ProjectLinks.Count) project-to-project links"

# =============================================================================
# AGGREGATE PROJECT RELATIONSHIPS
# =============================================================================
Write-Output "PHASE 4: Aggregating project relationships..."

$ProjectRelationships = $ProjectLinks | Group-Object @{Expression={
        $sorted = @($_.SourceProject, $_.TargetProject) | Sort-Object
        $sorted -join " -> "
    }} | 
    ForEach-Object {
        $LinkData = $_.Group
        $Projects = $_.Name -split " -> "
        
        [PSCustomObject]@{
            ProjectKey = $Projects[0]  # First project alphabetically
            ConnectedProject = $Projects[1]  # Second project alphabetically
            LinkCount = $LinkData.Count
        }
    } | Sort-Object ProjectKey, LinkCount -Descending

# Create project summary
$ProjectSummary = $ProjectRelationships | Group-Object ProjectKey | ForEach-Object {
    $TotalLinks = ($_.Group | Measure-Object LinkCount -Sum).Sum
    
    [PSCustomObject]@{
        ProjectKey = $_.Name
        LinkCount = $TotalLinks
        ConnectedProjects = $_.Group.Count
    }
} | Sort-Object LinkCount -Descending

Write-Output "  Aggregated relationships for $($ProjectSummary.Count) projects"

# =============================================================================
# EXPORT FILTERED DATA
# =============================================================================
Write-Output "PHASE 5: Exporting filtered data..."

# Export project relationships
$RelationshipsFile = "Issue Links - GET Project to Project Links - Final Filtered - Exclude ORL TOKR RC EOKR OBSRV - Anon - Official.csv"
$ProjectRelationships | Export-Csv -Path $RelationshipsFile -NoTypeInformation

# Export project summary
$SummaryFile = "Project Summary - Final Filtered - Exclude ORL TOKR RC EOKR OBSRV - Anon - Official.csv"
$ProjectSummary | Export-Csv -Path $SummaryFile -NoTypeInformation

Write-Output "  Exported relationships to: $RelationshipsFile"
Write-Output "  Exported summary to: $SummaryFile"

# =============================================================================
# GENERATE ANALYSIS SUMMARY
# =============================================================================
Write-Output "PHASE 6: Generating analysis summary..."

Write-Output ""
Write-Output "FILTERED AFFINITY ANALYSIS SUMMARY"
Write-Output "=" * 50
Write-Output "Filtering Criteria:"
Write-Output "  - Unresolved issues only"
Write-Output "  - Projects with activity in last 90 days (based on Updated field)"
Write-Output "  - Exclude ORL, TOKR, RC, EOKR, OBSRV projects (archived/inactive)"
Write-Output "  - Cutoff date: $($CutoffDate.ToString('yyyy-MM-dd'))"
Write-Output ""
Write-Output "Results:"
Write-Output "  - Total issues in system: $($AllIssues.Count)"
Write-Output "  - Unresolved issues: $($UnresolvedIssues.Count)"
Write-Output "  - Projects with recent activity: $($ProjectsWithRecentActivity.Count)"
Write-Output "  - Filtered issues analyzed: $($FilteredIssues.Count)"
Write-Output "  - Project-to-project links: $($ProjectLinks.Count)"
Write-Output "  - Projects with relationships: $($ProjectSummary.Count)"
Write-Output ""
Write-Output "TOP 10 MOST CONNECTED PROJECTS:"
$ProjectSummary | Select-Object -First 10 | ForEach-Object { 
    Write-Output "  $($_.ProjectKey): $($_.LinkCount) total links to $($_.ConnectedProjects) projects"
}

Write-Output ""
Write-Output "TOP 10 STRONGEST PROJECT RELATIONSHIPS:"
$ProjectRelationships | Select-Object -First 10 | ForEach-Object {
    Write-Output "  $($_.ProjectKey) <-> $($_.ConnectedProject): $($_.LinkCount) links"
}

Write-Output ""
Write-Output "NEXT STEPS:"
Write-Output "  1. Use '$RelationshipsFile' for Python affinity analysis"
Write-Output "  2. Update Python scripts to use filtered data"
Write-Output "  3. Generate new visualizations"
Write-Output ""
Write-Output "SUCCESS: Filtered affinity analysis data ready!"
