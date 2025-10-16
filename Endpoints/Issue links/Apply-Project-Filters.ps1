# =============================================================================
# APPLY PROJECT FILTERS - PRACTICAL APPROACH
# =============================================================================
# Using existing project data to apply filtering criteria
# =============================================================================

Write-Output "Starting Project Filtering Analysis..."
Write-Output "Using existing project link data as proxy for activity"

# =============================================================================
# LOAD EXISTING DATA
# =============================================================================
Write-Output "PHASE 1: Loading existing project data..."

# Load the project link summary data
$ProjectLinkData = Import-Csv "Project_Link_Summary.csv"
Write-Output "  Loaded $($ProjectLinkData.Count) projects from Project_Link_Summary.csv"

# Load the unresolved project links data (our current analysis data)
$UnresolvedData = Import-Csv "Issue Links - GET Project to Project Links - Unresolved Only - No ORL - Anon - Official.csv"
Write-Output "  Loaded $($UnresolvedData.Count) project relationships from unresolved data"

# =============================================================================
# APPLY FILTERING CRITERIA
# =============================================================================
Write-Output "PHASE 2: Applying filtering criteria..."

# Filter criteria:
# 1. Remove ORL (already done in unresolved data)
# 2. Projects with 100+ issues (using IssuesWithLinks as proxy)
# 3. Projects with significant link activity (using TotalLinks as proxy for recent activity)

$MinIssues = 100
$MinLinks = 500  # Projects with 500+ links likely have recent activity

Write-Output "  Filtering criteria:"
Write-Output "    - Projects with $MinIssues+ issues with links"
Write-Output "    - Projects with $MinLinks+ total links (activity proxy)"

# Get projects that meet our criteria (excluding ORL)
$FilteredProjects = $ProjectLinkData | Where-Object { 
    $_.IssuesWithLinks -ge $MinIssues -and $_.TotalLinks -ge $MinLinks -and $_.Project -ne "ORL"
}

Write-Output "  Found $($FilteredProjects.Count) projects meeting criteria"

# Get the project keys that should be included
$IncludedProjectKeys = $FilteredProjects | ForEach-Object { $_.Project }

Write-Output "  Included projects: $($IncludedProjectKeys -join ', ')"

# =============================================================================
# FILTER THE UNRESOLVED DATA
# =============================================================================
Write-Output "PHASE 3: Filtering unresolved project links data..."

# Filter the unresolved data to only include projects that meet our criteria
$FilteredUnresolvedData = $UnresolvedData | Where-Object { 
    $_.ProjectKey -in $IncludedProjectKeys
}

Write-Output "  Filtered unresolved data: $($FilteredUnresolvedData.Count) project relationships"

# =============================================================================
# CREATE NEW FILTERED DATASET
# =============================================================================
Write-Output "PHASE 4: Creating filtered dataset..."

# Export the filtered data
$FilteredOutputFile = "Issue Links - GET Project to Project Links - Filtered - Unresolved Only - No ORL - Anon - Official.csv"
$FilteredUnresolvedData | Export-Csv -Path $FilteredOutputFile -NoTypeInformation

Write-Output "  Exported filtered data to: $FilteredOutputFile"

# =============================================================================
# CREATE PROJECT METADATA SUMMARY
# =============================================================================
Write-Output "PHASE 5: Creating project metadata summary..."

$ProjectMetadata = @()
foreach ($project in $ProjectLinkData) {
    $IncludeInAnalysis = $project.Project -in $IncludedProjectKeys
    
    $ProjectData = [PSCustomObject]@{
        ProjectKey = $project.Project
        ProjectName = $project.Project  # We don't have full names, using key as proxy
        TotalIssues = [int]$project.IssuesWithLinks
        TotalLinks = [int]$project.TotalLinks
        AvgLinksPerIssue = [double]$project.AvgLinksPerIssue
        IncludeInAnalysis = $IncludeInAnalysis
        Reason = if ($IncludeInAnalysis) { "Meets criteria" } else { "Below thresholds" }
    }
    $ProjectMetadata += $ProjectData
}

$MetadataOutputFile = "Project_Metadata_Filtered_Analysis.csv"
$ProjectMetadata | Export-Csv -Path $MetadataOutputFile -NoTypeInformation

Write-Output "  Exported project metadata to: $MetadataOutputFile"

# =============================================================================
# SUMMARY STATISTICS
# =============================================================================
Write-Output ""
Write-Output "SUMMARY:"
Write-Output "  - Total projects in system: $($ProjectLinkData.Count)"
Write-Output "  - Projects meeting criteria: $($FilteredProjects.Count)"
Write-Output "  - Projects excluded: $($ProjectLinkData.Count - $FilteredProjects.Count)"
Write-Output ""
Write-Output "FILTERING BREAKDOWN:"
Write-Output "  - Projects with $MinIssues+ issues: $($ProjectLinkData | Where-Object { [int]$_.IssuesWithLinks -ge $MinIssues } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Output "  - Projects with $MinLinks+ links: $($ProjectLinkData | Where-Object { [int]$_.TotalLinks -ge $MinLinks } | Measure-Object | Select-Object -ExpandProperty Count)"
Write-Output "  - Projects meeting BOTH criteria: $($FilteredProjects.Count)"

Write-Output ""
Write-Output "TOP 10 INCLUDED PROJECTS BY ISSUE COUNT:"
$ProjectMetadata | Where-Object { $_.IncludeInAnalysis } | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table -AutoSize

Write-Output ""
Write-Output "TOP 10 EXCLUDED PROJECTS BY ISSUE COUNT:"
$ProjectMetadata | Where-Object { -not $_.IncludeInAnalysis } | Sort-Object TotalIssues -Descending | Select-Object -First 10 | Format-Table -AutoSize

Write-Output ""
Write-Output "NEXT STEPS:"
Write-Output "  1. Use '$FilteredOutputFile' for new affinity analysis"
Write-Output "  2. Update Python scripts to use filtered data"
Write-Output "  3. Generate new visualizations with filtered projects"