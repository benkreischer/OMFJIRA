# =============================================================================
# SCRIPT: Merge Project Links Results
# =============================================================================
#
# DESCRIPTION: Merges the main analysis results with the batch 3 recovery results
# to create a comprehensive CSV showing all active project cross-links
#
# =============================================================================

try {
    Write-Output "Starting merge of project links results..."

    # File paths
    $MainFile = "Issue Links - GET Project to Project Links - Anon - Official.csv"
    $RecoveryFile = "Issue Links - GET Project to Project Links - Batch3 Recovery - Anon - Official.csv"
    $MergedFile = "Issue Links - GET Project to Project Links - Complete - Anon - Official.csv"

    # Check if both files exist
    if (-not (Test-Path $MainFile)) {
        Write-Output "ERROR: Main file not found: $MainFile"
        exit 1
    }

    if (-not (Test-Path $RecoveryFile)) {
        Write-Output "ERROR: Recovery file not found: $RecoveryFile"
        exit 1
    }

    Write-Output "Loading main analysis results from: $MainFile"
    $MainResults = Import-Csv $MainFile

    Write-Output "Loading recovery results from: $RecoveryFile"
    $RecoveryResults = Import-Csv $RecoveryFile

    Write-Output "Main analysis projects: $($MainResults.Count)"
    Write-Output "Recovery projects: $($RecoveryResults.Count)"

    # Combine results
    $AllResults = @()
    $AllResults += $MainResults
    $AllResults += $RecoveryResults

    Write-Output "Combined total projects: $($AllResults.Count)"

    # Sort by ProjectKey for consistency
    $SortedResults = $AllResults | Sort-Object ProjectKey

    # Export merged results
    $SortedResults | Export-Csv -Path $MergedFile -NoTypeInformation -Force

    Write-Output ""
    Write-Output "SUCCESS: Merged results exported to: $MergedFile"
    Write-Output ""
    Write-Output "FINAL SUMMARY:"
    Write-Output "=============="
    Write-Output "  - Main analysis projects: $($MainResults.Count)"
    Write-Output "  - Recovery projects: $($RecoveryResults.Count)"
    Write-Output "  - Total active projects: $($AllResults.Count)"
    Write-Output "  - Projects with cross-project links: $(($AllResults | Where-Object { [int]$_.LinkCount -gt 0 }).Count)"
    Write-Output "  - Projects with zero links: $(($AllResults | Where-Object { [int]$_.LinkCount -eq 0 }).Count)"

    # Show top linked projects
    Write-Output ""
    Write-Output "TOP 15 MOST CONNECTED PROJECTS:"
    Write-Output "==============================="
    $TopLinked = $AllResults | Where-Object { [int]$_.LinkCount -gt 0 } | Sort-Object { [int]$_.LinkCount } -Descending | Select-Object -First 15
    foreach ($p in $TopLinked) {
        Write-Output "  $($p.ProjectKey): $($p.LinkCount) links"
    }

    Write-Output ""
    Write-Output "Complete project-to-project relationship analysis ready!"

} catch {
    Write-Output "Merge failed: $($_.Exception.Message)"
    exit 1
}