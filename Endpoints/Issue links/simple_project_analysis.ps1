# Simple Project Link Analysis
Write-Host "Analyzing project links..." -ForegroundColor Green

# Import CSV data
$data = Import-Csv "Issue Links - GET Simple Links - Anon - Hybrid.csv"
Write-Host "Total records: $($data.Count)" -ForegroundColor Yellow

# Initialize hashtables for counting
$projectCounts = @{}
$projectLinks = @{}

# Process each row
foreach ($row in $data) {
    # Extract project from key (e.g., "COR-620" -> "COR")
    if ($row.Key -match "^([A-Z]+)-") {
        $project = $matches[1]
        
        # Count issues per project
        if (-not $projectCounts.ContainsKey($project)) {
            $projectCounts[$project] = 0
        }
        $projectCounts[$project]++
        
        # Count total links per project
        if (-not $projectLinks.ContainsKey($project)) {
            $projectLinks[$project] = 0
        }
        $projectLinks[$project] += [int]$row.TotalLinks
    }
}

# Create summary
$summary = @()
foreach ($project in $projectCounts.Keys | Sort-Object) {
    $summary += [PSCustomObject]@{
        Project = $project
        IssuesWithLinks = $projectCounts[$project]
        TotalLinks = $projectLinks[$project]
        AvgLinksPerIssue = [math]::Round($projectLinks[$project] / $projectCounts[$project], 2)
    }
}

# Sort by total links descending
$summary = $summary | Sort-Object TotalLinks -Descending

# Display top 20
Write-Host "`nTop 20 Projects by Link Count:" -ForegroundColor Cyan
$summary | Select-Object -First 20 | Format-Table -AutoSize

# Export to CSV
$summary | Export-Csv "Project_Link_Summary.csv" -NoTypeInformation
Write-Host "`nResults exported to: Project_Link_Summary.csv" -ForegroundColor Green

# Display statistics
$totalProjects = $summary.Count
$totalIssues = ($summary | Measure-Object -Property IssuesWithLinks -Sum).Sum
$totalLinks = ($summary | Measure-Object -Property TotalLinks -Sum).Sum

Write-Host "`nSummary Statistics:" -ForegroundColor Cyan
Write-Host "Total Projects: $totalProjects" -ForegroundColor White
Write-Host "Total Issues with Links: $totalIssues" -ForegroundColor White
Write-Host "Total Links: $totalLinks" -ForegroundColor White
Write-Host "Average Links per Project: $([math]::Round($totalLinks / $totalProjects, 2))" -ForegroundColor White
