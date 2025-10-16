# =============================================================================
# PROJECT LINK ANALYSIS SCRIPT
# =============================================================================
# Analyzes the Simple Links CSV to count linked items by project
# =============================================================================

Write-Host "🔍 Analyzing project link counts from Simple Links data..." -ForegroundColor Cyan

# Read the Simple Links CSV
$csvPath = ".\Issue Links - GET Simple Links - Anon - Hybrid.csv"
$data = Import-Csv $csvPath

Write-Host "📊 Total records: $($data.Count)" -ForegroundColor Green

# Initialize counters
$projectLinkCounts = @{}
$projectIssueCounts = @{}
$projectOutboundLinks = @{}
$projectInboundLinks = @{}

Write-Host "🔄 Processing links..." -ForegroundColor Yellow

foreach ($row in $data) {
    # Extract project from issue key (e.g., "COR-620" -> "COR")
    $sourceProject = if ($row.Key -match "^([A-Z]+)-") { $matches[1] } else { "UNKNOWN" }
    
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
    
    # Parse linked keys to count outbound links
    if ($row.LinkedKeys -and $row.LinkedKeys.Trim() -ne "") {
        $linkedKeys = $row.LinkedKeys -split ";"
        foreach ($linkedKey in $linkedKeys) {
            $linkedKey = $linkedKey.Trim()
            if ($linkedKey -match "^([A-Z]+)-") {
                $targetProject = $matches[1]
                
                # Count outbound links from source project
                if (-not $projectOutboundLinks.ContainsKey($sourceProject)) {
                    $projectOutboundLinks[$sourceProject] = @{}
                }
                if (-not $projectOutboundLinks[$sourceProject].ContainsKey($targetProject)) {
                    $projectOutboundLinks[$sourceProject][$targetProject] = 0
                }
                $projectOutboundLinks[$sourceProject][$targetProject]++
                
                # Count inbound links to target project
                if (-not $projectInboundLinks.ContainsKey($targetProject)) {
                    $projectInboundLinks[$targetProject] = @{}
                }
                if (-not $projectInboundLinks[$targetProject].ContainsKey($sourceProject)) {
                    $projectInboundLinks[$targetProject][$sourceProject] = 0
                }
                $projectInboundLinks[$targetProject][$sourceProject]++
            }
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
