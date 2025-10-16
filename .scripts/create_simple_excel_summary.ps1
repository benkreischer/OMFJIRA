# Simple PowerShell script to create Excel summary without COM errors

Write-Host "=== CREATING SIMPLE EXCEL SUMMARY ===" -ForegroundColor Green

# Get all CSV files from .endpoints directory
$csvFiles = Get-ChildItem -Path ".endpoints" -Recurse -Include "*.csv" | Sort-Object FullName

Write-Host "Found $($csvFiles.Count) CSV files" -ForegroundColor Yellow

# Create summary data
$summaryData = @()
$totalRecords = 0

foreach ($csvFile in $csvFiles) {
    try {
        # Read CSV to get record count
        $csvData = Import-Csv -Path $csvFile.FullName -ErrorAction SilentlyContinue
        $recordCount = if ($csvData) { $csvData.Count } else { 0 }
        
        # Extract category and endpoint name from file path
        $relativePath = $csvFile.FullName -replace [regex]::Escape((Get-Location).Path), ""
        $pathParts = $relativePath -split "\\"
        $category = if ($pathParts.Count -gt 1) { $pathParts[1] } else { "Unknown" }
        $endpointName = $csvFile.BaseName
        
        # Determine status
        $status = if ($recordCount -gt 0) { "Working ($recordCount records)" } else { "Empty (0 records)" }
        
        $summaryData += [PSCustomObject]@{
            Category = $category
            Endpoint = $endpointName
            Status = $status
            RecordCount = $recordCount
            FilePath = $relativePath
            PowerQueryFile = $relativePath -replace "\.csv$", ".pq"
            PowerShellFile = $relativePath -replace "\.csv$", ".ps1"
        }
        
        $totalRecords += $recordCount
        
    } catch {
        Write-Host "Error processing $($csvFile.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Create Excel file using simple method
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Add()
$worksheet = $workbook.ActiveSheet
$worksheet.Name = "Working Endpoints Summary"

# Add headers
$worksheet.Cells.Item(1, 1) = "Category"
$worksheet.Cells.Item(1, 2) = "Endpoint"
$worksheet.Cells.Item(1, 3) = "Status"
$worksheet.Cells.Item(1, 4) = "Record Count"
$worksheet.Cells.Item(1, 5) = "CSV File Path"
$worksheet.Cells.Item(1, 6) = "Power Query File"
$worksheet.Cells.Item(1, 7) = "PowerShell File"

# Format headers
for ($col = 1; $col -le 7; $col++) {
    $worksheet.Cells.Item(1, $col).Font.Bold = $true
    $worksheet.Cells.Item(1, $col).Interior.Color = 0x4472C4
    $worksheet.Cells.Item(1, $col).Font.Color = 0xFFFFFF
}

# Add data
$row = 2
foreach ($item in $summaryData) {
    $worksheet.Cells.Item($row, 1) = $item.Category
    $worksheet.Cells.Item($row, 2) = $item.Endpoint
    $worksheet.Cells.Item($row, 3) = $item.Status
    $worksheet.Cells.Item($row, 4) = $item.RecordCount
    $worksheet.Cells.Item($row, 5) = $item.FilePath
    $worksheet.Cells.Item($row, 6) = $item.PowerQueryFile
    $worksheet.Cells.Item($row, 7) = $item.PowerShellFile
    $row++
}

# Auto-fit columns
$worksheet.UsedRange.Columns.AutoFit() | Out-Null

# Add summary at the bottom
$summaryRow = $row + 2
$worksheet.Cells.Item($summaryRow, 1) = "SUMMARY:"
$worksheet.Cells.Item($summaryRow, 1).Font.Bold = $true
$summaryRow++
$worksheet.Cells.Item($summaryRow, 1) = "Total Endpoints:"
$worksheet.Cells.Item($summaryRow, 2) = $summaryData.Count
$summaryRow++
$workingEndpoints = $summaryData | Where-Object { $_.RecordCount -gt 0 }
$worksheet.Cells.Item($summaryRow, 1) = "Working Endpoints:"
$worksheet.Cells.Item($summaryRow, 2) = $workingEndpoints.Count
$summaryRow++
$worksheet.Cells.Item($summaryRow, 1) = "Total Records:"
$worksheet.Cells.Item($summaryRow, 2) = $totalRecords

# Save Excel file
$excelPath = "Jira_API_Working_Endpoints_For_PowerBI.xlsx"
$workbook.SaveAs((Resolve-Path ".").Path + "\" + $excelPath)
$workbook.Close()
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host ""
Write-Host "=== SUMMARY COMPLETE ===" -ForegroundColor Green
Write-Host "Total Endpoints Found: $($summaryData.Count)" -ForegroundColor White
Write-Host "Working Endpoints: $($workingEndpoints.Count)" -ForegroundColor Green
Write-Host "Total Records: $totalRecords" -ForegroundColor Cyan
Write-Host ""
Write-Host "Excel file created: $excelPath" -ForegroundColor Green
Write-Host ""
Write-Host "TOP 10 ENDPOINTS BY RECORD COUNT:" -ForegroundColor Yellow
$workingEndpoints | Sort-Object RecordCount -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.RecordCount.ToString().PadLeft(6)) records - $($_.Endpoint)" -ForegroundColor White
}
