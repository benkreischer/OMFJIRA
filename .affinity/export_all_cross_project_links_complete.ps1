# =============================================================================
# COMPLETE CROSS-PROJECT LINKS EXPORT - GOLD COPY
# =============================================================================
# Exports ALL cross-project links with NO FILTERS
# Includes assignee information for both source and target issues
# Only excludes internal/self-links (same project links)
# =============================================================================

Write-Host "🔍 Exporting COMPLETE cross-project links (UNFILTERED - GOLD COPY)..." -ForegroundColor Cyan

# Read the All Issues with Links CSV
$csvPath = "..\.endpoints\Issue links\Issue Links - GET All Issues with Links - Anon - Hybrid.csv"
$allData = Import-Csv $csvPath

Write-Host "📊 Total records: $($allData.Count)" -ForegroundColor Green

# Create a hash table for quick lookup of issue details by key
Write-Host "🔄 Building issue lookup index..." -ForegroundColor Yellow
$issueLookup = @{}
foreach ($issue in $allData) {
    if ($issue.Key) {
        $issueLookup[$issue.Key] = $issue
    }
}
Write-Host "✅ Indexed $($issueLookup.Count) issues" -ForegroundColor Green

Write-Host "🔄 Processing ALL cross-project links (no filters)..." -ForegroundColor Yellow

# Array to store detailed links
$detailedLinks = @()
$linkCount = 0

foreach ($row in $allData) {
    # Extract source project from issue key
    $sourceProject = if ($row.Key -match "^([A-Z]+)-") { $matches[1] } else { "UNKNOWN" }
    $sourceIssueKey = $row.Key
    
    # Process outbound links
    if ($row.OutwardLinks -and $row.OutwardLinks.Trim() -ne "") {
        $outwardMatches = [regex]::Matches($row.OutwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $outwardMatches) {
            $targetIssueKey = $match.Value
            $targetProject = $match.Groups[1].Value
            
            # Only include cross-project links (source != target)
            if ($sourceProject -ne $targetProject) {
                # Look up target issue details
                $targetIssue = $issueLookup[$targetIssueKey]
                
                $detailedLinks += [PSCustomObject]@{
                    SourceProject = $sourceProject
                    TargetProject = $targetProject
                    SourceIssueKey = $sourceIssueKey
                    TargetIssueKey = $targetIssueKey
                    LinkDirection = "Outbound"
                    SourceSummary = $row.Summary
                    TargetSummary = if ($targetIssue) { $targetIssue.Summary } else { "" }
                    SourceStatus = $row.Status
                    TargetStatus = if ($targetIssue) { $targetIssue.Status } else { "" }
                    SourceAssignee = $row.Assignee
                    TargetAssignee = if ($targetIssue) { $targetIssue.Assignee } else { "" }
                    SourceReporter = $row.Reporter
                    TargetReporter = if ($targetIssue) { $targetIssue.Reporter } else { "" }
                    SourceCreated = $row.Created
                    TargetCreated = if ($targetIssue) { $targetIssue.Created } else { "" }
                    SourceUpdated = $row.Updated
                    TargetUpdated = if ($targetIssue) { $targetIssue.Updated } else { "" }
                    SourceIssueType = $row.IssueType
                    TargetIssueType = if ($targetIssue) { $targetIssue.IssueType } else { "" }
                }
                $linkCount++
            }
        }
    }
    
    # Process inbound links
    if ($row.InwardLinks -and $row.InwardLinks.Trim() -ne "") {
        $inwardMatches = [regex]::Matches($row.InwardLinks, '([A-Z]+)-(\d+)')
        foreach ($match in $inwardMatches) {
            $targetIssueKey = $match.Value
            $targetProject = $match.Groups[1].Value
            
            # Only include cross-project links (source != target)
            if ($sourceProject -ne $targetProject) {
                # Look up target issue details
                $targetIssue = $issueLookup[$targetIssueKey]
                
                $detailedLinks += [PSCustomObject]@{
                    SourceProject = $sourceProject
                    TargetProject = $targetProject
                    SourceIssueKey = $sourceIssueKey
                    TargetIssueKey = $targetIssueKey
                    LinkDirection = "Inbound"
                    SourceSummary = $row.Summary
                    TargetSummary = if ($targetIssue) { $targetIssue.Summary } else { "" }
                    SourceStatus = $row.Status
                    TargetStatus = if ($targetIssue) { $targetIssue.Status } else { "" }
                    SourceAssignee = $row.Assignee
                    TargetAssignee = if ($targetIssue) { $targetIssue.Assignee } else { "" }
                    SourceReporter = $row.Reporter
                    TargetReporter = if ($targetIssue) { $targetIssue.Reporter } else { "" }
                    SourceCreated = $row.Created
                    TargetCreated = if ($targetIssue) { $targetIssue.Created } else { "" }
                    SourceUpdated = $row.Updated
                    TargetUpdated = if ($targetIssue) { $targetIssue.Updated } else { "" }
                    SourceIssueType = $row.IssueType
                    TargetIssueType = if ($targetIssue) { $targetIssue.IssueType } else { "" }
                }
                $linkCount++
            }
        }
    }
    
    # Progress indicator
    if ($linkCount % 1000 -eq 0 -and $linkCount -gt 0) {
        Write-Host "  Processed $linkCount cross-project links..." -ForegroundColor Gray
    }
}

Write-Host "✅ Processing complete!" -ForegroundColor Green
Write-Host "📊 Total cross-project links found: $($detailedLinks.Count)" -ForegroundColor Cyan

# Export to CSV
$outputPath = ".\Complete_Cross_Project_Links_Gold_Copy.csv"
$detailedLinks | Export-Csv -Path $outputPath -NoTypeInformation

Write-Host "✅ Export complete!" -ForegroundColor Green
Write-Host "📄 File: $outputPath" -ForegroundColor White
Write-Host "📊 Total links exported: $($detailedLinks.Count)" -ForegroundColor White

# Show summary statistics
Write-Host "`n📈 TOP 20 PROJECT PAIRS BY LINK COUNT:" -ForegroundColor Cyan
$summary = $detailedLinks | Group-Object SourceProject, TargetProject | 
    Select-Object @{N='SourceProject';E={$_.Group[0].SourceProject}},
                  @{N='TargetProject';E={$_.Group[0].TargetProject}},
                  @{N='LinkCount';E={$_.Count}} |
    Sort-Object LinkCount -Descending

$summary | Select-Object -First 20 | Format-Table -AutoSize

# Show status breakdown
Write-Host "`n📊 STATUS BREAKDOWN:" -ForegroundColor Cyan
$statusBreakdown = $detailedLinks | Group-Object SourceStatus | 
    Select-Object @{N='Status';E={$_.Name}}, @{N='Count';E={$_.Count}} |
    Sort-Object Count -Descending
$statusBreakdown | Select-Object -First 10 | Format-Table -AutoSize

Write-Host "🎯 GOLD COPY EXPORT COMPLETE!" -ForegroundColor Green
Write-Host "   This file contains ALL cross-project links with NO FILTERS" -ForegroundColor White
Write-Host "   Includes: All projects, All statuses, All dates" -ForegroundColor White
Write-Host "   Excludes: Only internal/self-links" -ForegroundColor White

