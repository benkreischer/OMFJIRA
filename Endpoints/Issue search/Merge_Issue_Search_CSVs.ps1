# =============================================================================
# MERGE ISSUE SEARCH CSV FILES
# =============================================================================
# This script merges all individual Issue Search CSV files into one consolidated file
# =============================================================================

Write-Output "Starting merge of Issue Search CSV files..."

# Get all CSV files and sort them numerically
$CsvFiles = Get-ChildItem -Name "Issue Search - GET Issue search - Anon - Official - *.csv" | Sort-Object

Write-Output "Found $($CsvFiles.Count) CSV files to merge"

# Initialize the consolidated data array
$ConsolidatedData = @()

# Process each CSV file
$FileCount = 0
foreach ($File in $CsvFiles) {
    $FileCount++
    if ($FileCount % 100 -eq 0) {
        Write-Output "Processing file $FileCount of $($CsvFiles.Count)..."
    }
    
    try {
        # Import the CSV file
        $Data = Import-Csv $File
        
        # Add to consolidated data
        $ConsolidatedData += $Data
    }
    catch {
        Write-Warning "Failed to process file $File`: $($_.Exception.Message)"
    }
}

Write-Output "Total records collected: $($ConsolidatedData.Count)"

# Export to consolidated CSV
$OutputFile = "Issue Search - GET Issue search - Anon - Official.csv"
$ConsolidatedData | Export-Csv -Path $OutputFile -NoTypeInformation

Write-Output "SUCCESS: Merged $($ConsolidatedData.Count) records into $OutputFile"
Write-Output "File size: $((Get-Item $OutputFile).Length / 1MB) MB"
