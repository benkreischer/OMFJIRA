# =============================================================================
# MERGE ALL ISSUES BATCHES
# =============================================================================
# Merges all the batch CSV files into a single comprehensive dataset
# =============================================================================

Write-Output "Starting batch file merge process..."

# Get all batch files
$BatchFiles = Get-ChildItem -Path "." -Filter "Issue Search - GET All Issues with Links - Anon - Official - *.csv" | Sort-Object Name

if ($BatchFiles.Count -eq 0) {
    Write-Output "No batch files found. Make sure the Get-All-Issues-With-Links.ps1 script has completed."
    exit
}

Write-Output "Found $($BatchFiles.Count) batch files to merge"

# Initialize the combined dataset
$AllIssues = @()

# Process each batch file
foreach ($BatchFile in $BatchFiles) {
    Write-Output "  Processing $($BatchFile.Name)..."
    
    try {
        $BatchData = Import-Csv -Path $BatchFile.FullName
        $AllIssues += $BatchData
        Write-Output "    Added $($BatchData.Count) issues from $($BatchFile.Name)"
    } catch {
        Write-Error "Failed to process $($BatchFile.Name): $($_.Exception.Message)"
    }
}

Write-Output "Merged $($AllIssues.Count) total issues"

# Export the combined dataset
$OutputFile = "All Issues with Links - Complete Dataset.csv"
$AllIssues | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Output "SUCCESS: Exported complete dataset to $OutputFile"

# Generate summary statistics
Write-Output ""
Write-Output "DATASET SUMMARY:"
Write-Output "  - Total Issues: $($AllIssues.Count)"
Write-Output "  - Unique Projects: $(($AllIssues | Select-Object -ExpandProperty ProjectKey -Unique).Count)"
Write-Output "  - Issues with Links: $(($AllIssues | Where-Object { $_.LinkedIssueCount -gt 0 }).Count)"
Write-Output "  - Unresolved Issues: $(($AllIssues | Where-Object { $_.Status -notmatch 'Done|Closed|Resolved' }).Count)"

# Show top projects by issue count
Write-Output ""
Write-Output "TOP 10 PROJECTS BY ISSUE COUNT:"
$ProjectStats = $AllIssues | Group-Object ProjectKey | Sort-Object Count -Descending | Select-Object -First 10
foreach ($Project in $ProjectStats) {
    Write-Output "  $($Project.Name): $($Project.Count) issues"
}

Write-Output ""
Write-Output "NEXT STEPS:"
Write-Output "  1. Use '$OutputFile' for filtering and analysis"
Write-Output "  2. Filter for unresolved issues only"
Write-Output "  3. Apply project activity criteria"
Write-Output "  4. Generate new affinity analysis"
