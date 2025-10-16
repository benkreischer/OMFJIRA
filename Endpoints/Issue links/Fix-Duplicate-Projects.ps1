# =============================================================================
# SCRIPT: Fix Duplicate Projects in Merged Results
# =============================================================================
#
# DESCRIPTION: Removes duplicate project entries and keeps the version with
# the highest link count for each project
#
# =============================================================================

try {
    Write-Output "Fixing duplicate projects in merged results..."

    # Load the merged file with duplicates
    $MergedFile = "Issue Links - GET Project to Project Links - Complete - Anon - Official.csv"
    $FixedFile = "Issue Links - GET Project to Project Links - FINAL - Anon - Official.csv"

    if (-not (Test-Path $MergedFile)) {
        Write-Output "ERROR: Merged file not found: $MergedFile"
        exit 1
    }

    Write-Output "Loading merged results with duplicates..."
    $AllResults = Import-Csv $MergedFile

    Write-Output "Total rows before deduplication: $($AllResults.Count)"

    # Group by ProjectKey and keep the entry with highest LinkCount
    Write-Output "Removing duplicates and keeping best data for each project..."
    $DeduplicatedResults = $AllResults | Group-Object ProjectKey | ForEach-Object {
        # For each project, keep the entry with the highest LinkCount
        $_.Group | Sort-Object { [int]$_.LinkCount } -Descending | Select-Object -First 1
    }

    Write-Output "Total unique projects after deduplication: $($DeduplicatedResults.Count)"

    # Sort by ProjectKey for consistency
    $FinalResults = $DeduplicatedResults | Sort-Object ProjectKey

    # Export deduplicated results
    $FinalResults | Export-Csv -Path $FixedFile -NoTypeInformation -Force

    Write-Output ""
    Write-Output "SUCCESS: Fixed results exported to: $FixedFile"
    Write-Output ""
    Write-Output "CORRECTED SUMMARY:"
    Write-Output "=================="
    Write-Output "  - Total active projects: $($FinalResults.Count)"
    Write-Output "  - Projects with cross-project links: $(($FinalResults | Where-Object { [int]$_.LinkCount -gt 0 }).Count)"
    Write-Output "  - Projects with zero links: $(($FinalResults | Where-Object { [int]$_.LinkCount -eq 0 }).Count)"

    # Show top linked projects
    Write-Output ""
    Write-Output "TOP 15 MOST CONNECTED PROJECTS (CORRECTED):"
    Write-Output "==========================================="
    $TopLinked = $FinalResults | Where-Object { [int]$_.LinkCount -gt 0 } | Sort-Object { [int]$_.LinkCount } -Descending | Select-Object -First 15
    foreach ($p in $TopLinked) {
        Write-Output "  $($p.ProjectKey): $($p.LinkCount) links"
    }

    Write-Output ""
    Write-Output "Corrected project-to-project relationship analysis ready!"

} catch {
    Write-Output "Fix failed: $($_.Exception.Message)"
    exit 1
}