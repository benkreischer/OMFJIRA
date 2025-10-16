# PowerShell script to create comprehensive summary of working endpoints and Excel file for Power BI

Write-Host "=== CREATING WORKING ENDPOINTS SUMMARY ===" -ForegroundColor Green

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

# Create Excel file
$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$workbook = $excel.Workbooks.Add()
$worksheet = $workbook.ActiveSheet

# Rename default sheet
$worksheet.Name = "Summary"

# Add headers
$headers = @("Category", "Endpoint", "Status", "Record Count", "CSV File Path", "Power Query File", "PowerShell File")
for ($i = 0; $i -lt $headers.Count; $i++) {
    $worksheet.Cells.Item(1, $i + 1) = $headers[$i]
    $worksheet.Cells.Item(1, $i + 1).Font.Bold = $true
    $worksheet.Cells.Item(1, $i + 1).Interior.Color = 0x4472C4
    $worksheet.Cells.Item(1, $i + 1).Font.Color = 0xFFFFFF
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

# Add summary statistics
$statsRow = $row + 2
$worksheet.Cells.Item($statsRow, 1) = "SUMMARY STATISTICS"
$worksheet.Cells.Item($statsRow, 1).Font.Bold = $true
$worksheet.Cells.Item($statsRow, 1).Font.Size = 14

$statsRow++
$worksheet.Cells.Item($statsRow, 1) = "Total Endpoints:"
$worksheet.Cells.Item($statsRow, 2) = $summaryData.Count

$statsRow++
$workingEndpoints = $summaryData | Where-Object { $_.RecordCount -gt 0 }
$worksheet.Cells.Item($statsRow, 1) = "Working Endpoints:"
$worksheet.Cells.Item($statsRow, 2) = $workingEndpoints.Count

$statsRow++
$worksheet.Cells.Item($statsRow, 1) = "Total Records:"
$worksheet.Cells.Item($statsRow, 2) = $totalRecords

$statsRow++
$worksheet.Cells.Item($statsRow, 1) = "Categories:"
$categories = $summaryData | Select-Object -ExpandProperty Category | Sort-Object -Unique
$worksheet.Cells.Item($statsRow, 2) = $categories.Count

# Create Power BI setup instructions sheet
$pbWorksheet = $workbook.Worksheets.Add()
$pbWorksheet.Name = "Power BI Setup"

$pbInstructions = @"
JIRA API POWER BI SETUP INSTRUCTIONS
=====================================

BASE CONFIGURATION:
- Base URL: https://onemain-omfdirty.atlassian.net
- Username: ben.kreischer.ce@omf.com
- Authentication: Basic Auth with API Token

QUICK SETUP STEPS:
1. Open Power BI Desktop
2. Get Data → Blank Query
3. Advanced Editor
4. Copy Power Query code from .pq files
5. Replace [YOUR_API_TOKEN] with actual token
6. Apply & Close

WORKING ENDPOINTS BY CATEGORY:
"@

$pbRow = 1
$pbInstructions -split "`n" | ForEach-Object {
    $pbWorksheet.Cells.Item($pbRow, 1) = $_
    $pbRow++
}

# Add category breakdown
$pbRow++
$pbWorksheet.Cells.Item($pbRow, 1) = ""
$pbRow++
$pbWorksheet.Cells.Item($pbRow, 1) = "CATEGORY BREAKDOWN:"
$pbRow++

$categoryStats = $summaryData | Group-Object Category | Sort-Object Name
foreach ($category in $categoryStats) {
    $workingInCategory = $category.Group | Where-Object { $_.RecordCount -gt 0 }
    $pbWorksheet.Cells.Item($pbRow, 1) = "$($category.Name): $($workingInCategory.Count) working endpoints"
    $pbRow++
}

# Create Power Query templates sheet
$pqWorksheet = $workbook.Worksheets.Add()
$pqWorksheet.Name = "Power Query Templates"

$pqRow = 1
$pqWorksheet.Cells.Item($pqRow, 1) = "POWER QUERY CONNECTION TEMPLATES"
$pqRow++
$pqWorksheet.Cells.Item($pqRow, 1) = "Copy these templates into Power BI Desktop"
$pqRow += 2

# Add sample Power Query templates for top endpoints
$topEndpoints = $workingEndpoints | Sort-Object RecordCount -Descending | Select-Object -First 10

foreach ($endpoint in $topEndpoints) {
    $pqWorksheet.Cells.Item($pqRow, 1) = "=== $($endpoint.Endpoint) ==="
    $pqRow++
    $pqWorksheet.Cells.Item($pqRow, 1) = "Records: $($endpoint.RecordCount)"
    $pqRow++
    $pqWorksheet.Cells.Item($pqRow, 1) = "Power Query File: $($endpoint.PowerQueryFile)"
    $pqRow++
    $pqWorksheet.Cells.Item($pqRow, 1) = ""
    $pqRow++
}

# Auto-fit columns
$pbWorksheet.UsedRange.Columns.AutoFit() | Out-Null
$pqWorksheet.UsedRange.Columns.AutoFit() | Out-Null

# Save Excel file
$excelPath = "Jira_API_Working_Endpoints_Summary.xlsx"
$workbook.SaveAs((Resolve-Path ".").Path + "\" + $excelPath)
$workbook.Close()
$excel.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel) | Out-Null

Write-Host ""
Write-Host "=== SUMMARY COMPLETE ===" -ForegroundColor Green
Write-Host "Total Endpoints Found: $($summaryData.Count)" -ForegroundColor White
Write-Host "Working Endpoints: $($workingEndpoints.Count)" -ForegroundColor Green
Write-Host "Total Records: $totalRecords" -ForegroundColor Cyan
Write-Host "Categories: $($categories.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Excel file created: $excelPath" -ForegroundColor Green
Write-Host ""
Write-Host "TOP 10 ENDPOINTS BY RECORD COUNT:" -ForegroundColor Yellow
$workingEndpoints | Sort-Object RecordCount -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  $($_.RecordCount.ToString().PadLeft(6)) records - $($_.Endpoint)" -ForegroundColor White
}
