# =============================================================================
# DETAILED CROSS-PROJECT LINKS EXPORT
# =============================================================================
# Exports exhaustive list of all cross-project links with individual issue keys
# Filters: Unresolved + Updated within 180 days + Excluded projects
# =============================================================================

Write-Host "🔍 Exporting detailed cross-project links..." -ForegroundColor Cyan

# Read the All Issues with Links CSV
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

# Define projects to exclude from analysis
$excludedProjects = @('ORL', 'TOKR', 'RC', 'EOKR', 'OBSRV', 'EPMC', 'EDME', 'BOKR')
Write-Host "🚫 Excluding projects: $($excludedProjects -join ', ')" -ForegroundColor Yellow

Write-Host "🔄 Processing cross-project links..." -ForegroundColor Yellow

# Array to store detailed links
$detailedLinks = @()

foreach ($row in $data) {
    # Extract source project from issue key
    $sourceProject = if ($row.Key -match "^([A-Z]+)-") { $matches[1] } else { "UNKNOWN" }
    
    # Skip excluded projects
    if ($excludedProjects -contains $sourceProject) {
        continue
    }
    
    $sourceIssueKey = $row.Key
    
    # Process outbound links
    if ($row.OutwardLinks -and $row.OutwardLinks.Trim() -ne "") {
        $outwardMatches = [regex]::Matches($row.OutwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $outwardMatches) {
            $targetIssueKey = $match.Value
            $targetProject = $match.Groups[1].Value
            
            # Skip if target project is excluded
            if ($excludedProjects -contains $targetProject) {
                continue
            }
            
            # Only include cross-project links (source != target)
            if ($sourceProject -ne $targetProject) {
                $detailedLinks += [PSCustomObject]@{
                    SourceProject = $sourceProject
                    TargetProject = $targetProject
                    SourceIssueKey = $sourceIssueKey
                    TargetIssueKey = $targetIssueKey
                    LinkDirection = "Outbound"
                    SourceSummary = $row.Summary
                    SourceStatus = $row.Status
                    SourceUpdated = $row.Updated
                }
            }
        }
    }
    
    # Process inbound links
    if ($row.InwardLinks -and $row.InwardLinks.Trim() -ne "") {
        $inwardMatches = [regex]::Matches($row.InwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $inwardMatches) {
            $targetIssueKey = $match.Value
            $targetProject = $match.Groups[1].Value
            
            # Skip if target project is excluded
            if ($excludedProjects -contains $targetProject) {
                continue
            }
            
            # Only include cross-project links (source != target)
            if ($sourceProject -ne $targetProject) {
                $detailedLinks += [PSCustomObject]@{
                    SourceProject = $sourceProject
                    TargetProject = $targetProject
                    SourceIssueKey = $sourceIssueKey
                    TargetIssueKey = $targetIssueKey
                    LinkDirection = "Inbound"
                    SourceSummary = $row.Summary
                    SourceStatus = $row.Status
                    SourceUpdated = $row.Updated
                }
            }
        }
    }
}

Write-Host "✅ Processing complete!" -ForegroundColor Green
Write-Host "📊 Total cross-project links found: $($detailedLinks.Count)" -ForegroundColor Cyan

# Export to CSV
$outputPath = ".\Detailed_Cross_Project_Links.csv"
$detailedLinks | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "✅ Export complete!" -ForegroundColor Green
Write-Host "📄 File: $outputPath" -ForegroundColor White
Write-Host "📊 Total links exported: $($detailedLinks.Count)" -ForegroundColor White

# Show summary statistics
Write-Host "`n📈 SUMMARY BY PROJECT PAIR:" -ForegroundColor Cyan
$summary = $detailedLinks | Group-Object SourceProject, TargetProject | 
    Select-Object @{N='SourceProject';E={$_.Group[0].SourceProject}},
                  @{N='TargetProject';E={$_.Group[0].TargetProject}},
                  @{N='LinkCount';E={$_.Count}} |
    Sort-Object LinkCount -Descending

$summary | Select-Object -First 20 | Format-Table -AutoSize

Write-Host "🎯 EXPORT COMPLETE!" -ForegroundColor Green

