$csv = Import-Csv "Issue Search - GET Issue search - Anon - Official Jan2025-MergeDev-Test.csv"
Write-Output "Total Records: $($csv.Count)"
Write-Output ""
Write-Output "Sample of Created Dates (first 20):"
$csv | Select-Object -First 20 | ForEach-Object { Write-Output $_.Created }
Write-Output ""
Write-Output "Sample of Project Keys (first 20):"
$csv | Select-Object -First 20 | ForEach-Object { Write-Output $_.Key }
Write-Output ""
Write-Output "Date Distribution (showing unique Created dates):"
$csv | Where-Object { $_.Created -ne "" } | Group-Object Created | Select-Object Name, Count | Sort-Object Name | Select-Object -First 10
Write-Output ""
Write-Output "Project Distribution (showing unique project prefixes):"
$csv | ForEach-Object { 
    if ($_.Key -match "^([A-Z]+)-") { 
        $matches[1] 
    } 
} | Group-Object | Select-Object Name, Count | Sort-Object Count -Descending | Select-Object -First 10
