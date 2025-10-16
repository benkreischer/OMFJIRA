# =============================================================================
# PROJECT LINK ANALYSIS SCRIPT - ACTIVE ISSUES ONLY
# =============================================================================
# Analyzes unresolved issues updated within last 180 days
# Excludes: ORL, TOKR, RC, EOKR, OBSRV, EPMC, EDME, BOKR
# Filters: Unresolved status + Updated within 180 days
# =============================================================================

Write-Host "🔍 Analyzing project link counts from ACTIVE issues (unresolved + updated in last 180 days)..." -ForegroundColor Cyan

# Read the All Issues with Links CSV (includes status information)
$csvPath = "..\.endpoints\Issue links\Issue Links - GET All Issues with Links - Anon - Hybrid.csv"
$allData = Import-Csv $csvPath

Write-Host "📊 Total records: $($allData.Count)" -ForegroundColor Green

# Define resolved/closed statuses to exclude
$resolvedStatuses = @('Done', 'Closed', 'Resolved', 'Cancelled', 'Complete', 'Completed')

# Calculate the cutoff date (180 days ago)
$cutoffDate = (Get-Date).AddDays(-180)
Write-Host "📅 Filtering for issues updated after: $($cutoffDate.ToString('yyyy-MM-dd'))" -ForegroundColor Cyan

# Filter to only unresolved issues updated within last 180 days
$unresolvedData = $allData | Where-Object { $resolvedStatuses -notcontains $_.Status }
Write-Host "✅ Total unresolved issues: $($unresolvedData.Count)" -ForegroundColor Green

$data = $unresolvedData | Where-Object { 
    try {
        $updatedDate = [DateTime]::Parse($_.Updated)
        $updatedDate -ge $cutoffDate
    } catch {
        $false
    }
}

Write-Host "✅ Unresolved issues updated in last 180 days: $($data.Count)" -ForegroundColor Green
Write-Host "🚫 Resolved/Closed issues filtered out: $($allData.Count - $unresolvedData.Count)" -ForegroundColor Yellow
Write-Host "🚫 Stale issues (>180 days) filtered out: $($unresolvedData.Count - $data.Count)" -ForegroundColor Yellow

# Define projects to exclude from analysis
$excludedProjects = @('ORL', 'TOKR', 'RC', 'EOKR', 'OBSRV', 'EPMC', 'EDME', 'BOKR')
Write-Host "🚫 Excluding projects: $($excludedProjects -join ', ')" -ForegroundColor Yellow

# Initialize counters
$projectLinkCounts = @{}
$projectIssueCounts = @{}
$projectOutboundLinks = @{}
$projectInboundLinks = @{}

Write-Host "🔄 Processing links..." -ForegroundColor Yellow

foreach ($row in $data) {
    # Extract project from issue key (e.g., "COR-620" -> "COR")
    $sourceProject = if ($row.Key -match "^([A-Z]+)-") { $matches[1] } else { "UNKNOWN" }
    
    # Skip excluded projects
    if ($excludedProjects -contains $sourceProject) {
        continue
    }
    
    # Count issues per project
    if (-not $projectIssueCounts.ContainsKey($sourceProject)) {
        $projectIssueCounts[$sourceProject] = 0
    }
    $projectIssueCounts[$sourceProject]++
    
    # Count total links per project
    if (-not $projectLinkCounts.ContainsKey($sourceProject)) {
        $projectLinkCounts[$sourceProject] = 0
    }
    $projectLinkCounts[$sourceProject] += [int]$row.TotalLinks
    
    # Parse outbound links
    if ($row.OutwardLinks -and $row.OutwardLinks.Trim() -ne "") {
        # OutwardLinks format: "relates to: KEY - Summary"
        $outwardMatches = [regex]::Matches($row.OutwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $outwardMatches) {
            $targetProject = $match.Groups[1].Value
            
            # Skip if target project is excluded
            if ($excludedProjects -contains $targetProject) {
                continue
            }
            
            # Count outbound links from source project
            if (-not $projectOutboundLinks.ContainsKey($sourceProject)) {
                $projectOutboundLinks[$sourceProject] = @{}
            }
            if (-not $projectOutboundLinks[$sourceProject].ContainsKey($targetProject)) {
                $projectOutboundLinks[$sourceProject][$targetProject] = 0
            }
            $projectOutboundLinks[$sourceProject][$targetProject]++
        }
    }
    
    # Parse inbound links
    if ($row.InwardLinks -and $row.InwardLinks.Trim() -ne "") {
        # InwardLinks format: "relates to: KEY - Summary"
        $inwardMatches = [regex]::Matches($row.InwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $inwardMatches) {
            $targetProject = $match.Groups[1].Value
            
            # Skip if target project is excluded
            if ($excludedProjects -contains $targetProject) {
                continue
            }
            
            # Count inbound links to source project (from target)
            if (-not $projectInboundLinks.ContainsKey($sourceProject)) {
                $projectInboundLinks[$sourceProject] = @{}
            }
            if (-not $projectInboundLinks[$sourceProject].ContainsKey($targetProject)) {
                $projectInboundLinks[$sourceProject][$targetProject] = 0
            }
            $projectInboundLinks[$sourceProject][$targetProject]++
        }
    }
}

Write-Host "✅ Analysis complete!" -ForegroundColor Green

# Create summary report
$summary = @()

# Get all unique projects
$allProjects = ($projectIssueCounts.Keys + $projectLinkCounts.Keys) | Sort-Object -Unique

foreach ($project in $allProjects) {
    $issueCount = if ($projectIssueCounts.ContainsKey($project)) { $projectIssueCounts[$project] } else { 0 }
    $linkCount = if ($projectLinkCounts.ContainsKey($project)) { $projectLinkCounts[$project] } else { 0 }
    
    # Count unique connected projects (outbound)
    $outboundProjects = if ($projectOutboundLinks.ContainsKey($project)) { $projectOutboundLinks[$project].Keys.Count } else { 0 }
    
    # Count unique connected projects (inbound)
    $inboundProjects = if ($projectInboundLinks.ContainsKey($project)) { $projectInboundLinks[$project].Keys.Count } else { 0 }
    
    # Total unique connected projects
    $totalConnectedProjects = ($outboundProjects + $inboundProjects)
    
    $summary += [PSCustomObject]@{
        Project = $project
        IssuesWithLinks = $issueCount
        TotalLinks = $linkCount
        OutboundConnections = $outboundProjects
        InboundConnections = $inboundProjects
        TotalConnectedProjects = $totalConnectedProjects
        AvgLinksPerIssue = if ($issueCount -gt 0) { [math]::Round($linkCount / $issueCount, 2) } else { 0 }
    }
}

# Sort by total links descending
$summary = $summary | Sort-Object TotalLinks -Descending

# Export to CSV
$outputPath = ".\Project_Link_Analysis_Summary.csv"
$summary | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "📈 TOP 20 PROJECTS BY LINK COUNT:" -ForegroundColor Cyan
$summary | Select-Object -First 20 | Format-Table -AutoSize

Write-Host "📊 SUMMARY STATISTICS:" -ForegroundColor Cyan
Write-Host "  Total Projects: $($summary.Count)" -ForegroundColor White
Write-Host "  Total Issues with Links: $($summary | Measure-Object -Property IssuesWithLinks -Sum).Sum" -ForegroundColor White
Write-Host "  Total Links: $($summary | Measure-Object -Property TotalLinks -Sum).Sum" -ForegroundColor White
Write-Host "  Average Links per Project: $([math]::Round(($summary | Measure-Object -Property TotalLinks -Sum).Sum / $summary.Count, 2))" -ForegroundColor White

Write-Host "✅ Results exported to: $outputPath" -ForegroundColor Green

# Create detailed project-to-project connections
Write-Host "🔗 Creating detailed project-to-project connections..." -ForegroundColor Yellow

$detailedConnections = @()
foreach ($sourceProject in $projectOutboundLinks.Keys) {
    foreach ($targetProject in $projectOutboundLinks[$sourceProject].Keys) {
        $outboundCount = $projectOutboundLinks[$sourceProject][$targetProject]
        $inboundCount = if ($projectInboundLinks.ContainsKey($targetProject) -and $projectInboundLinks[$targetProject].ContainsKey($sourceProject)) { 
            $projectInboundLinks[$targetProject][$sourceProject] 
        } else { 0 }
        
        $detailedConnections += [PSCustomObject]@{
            SourceProject = $sourceProject
            TargetProject = $targetProject
            OutboundLinks = $outboundCount
            InboundLinks = $inboundCount
            TotalLinks = $outboundCount + $inboundCount
        }
    }
}

# Sort by total links descending
$detailedConnections = $detailedConnections | Sort-Object TotalLinks -Descending

# Export detailed connections
$detailedOutputPath = ".\Project_to_Project_Detailed_Connections.csv"
$detailedConnections | Export-Csv -Path $detailedOutputPath -NoTypeInformation

Write-Host "✅ Detailed connections exported to: $detailedOutputPath" -ForegroundColor Green

Write-Host "🔗 TOP 20 PROJECT-TO-PROJECT CONNECTIONS:" -ForegroundColor Cyan
$detailedConnections | Select-Object -First 20 | Format-Table -AutoSize

Write-Host "🎯 ANALYSIS COMPLETE!" -ForegroundColor Green
Write-Host "  Files generated:" -ForegroundColor White
Write-Host "    - $outputPath" -ForegroundColor Gray
Write-Host "    - $detailedOutputPath" -ForegroundColor Gray
