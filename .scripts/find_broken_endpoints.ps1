# Script to find all broken endpoints by checking CSV files for errors
Write-Host "🔍 FINDING ALL BROKEN ENDPOINTS" -ForegroundColor Red
Write-Host "================================" -ForegroundColor Red

$BrokenEndpoints = @()

# Get all CSV files
$CsvFiles = Get-ChildItem -Path ".endpoints" -Recurse -Filter "*.csv"
Write-Host "Found $($CsvFiles.Count) CSV files to check" -ForegroundColor Yellow

foreach ($csvFile in $CsvFiles) {
    try {
        $content = Get-Content $csvFile.FullName -Raw -ErrorAction SilentlyContinue

        # Check for error patterns in CSV content
        $hasError = $false
        $errorType = ""

        if ($content -match "404.*Not Found" -or $content -match "The remote server returned an error.*404") {
            $hasError = $true
            $errorType = "404 Not Found"
        }
        elseif ($content -match "400.*Bad Request" -or $content -match "The remote server returned an error.*400") {
            $hasError = $true
            $errorType = "400 Bad Request"
        }
        elseif ($content -match "403.*Forbidden" -or $content -match "The remote server returned an error.*403") {
            $hasError = $true
            $errorType = "403 Forbidden"
        }
        elseif ($content -match "405.*Method Not Allowed" -or $content -match "The remote server returned an error.*405") {
            $hasError = $true
            $errorType = "405 Method Not Allowed"
        }
        elseif ($content -match "Failed to retrieve" -or $content -match '"Error"') {
            $hasError = $true
            $errorType = "General Error"
        }

        if ($hasError) {
            $relativePath = $csvFile.DirectoryName.Replace("$PWD\.endpoints\", "")
            $endpointName = $csvFile.Name -replace "\.csv$", ""

            Write-Host "❌ BROKEN: $relativePath\$endpointName" -ForegroundColor Red
            Write-Host "   Error: $errorType" -ForegroundColor Gray

            $BrokenEndpoints += [PSCustomObject]@{
                Folder = $relativePath
                EndpointName = $endpointName
                ErrorType = $errorType
                CSVFile = $csvFile.FullName
                PS1File = $csvFile.FullName -replace "\.csv$", ".ps1"
            }
        }
    }
    catch {
        Write-Host "⚠️  Could not read: $($csvFile.Name)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "📊 SUMMARY:" -ForegroundColor Cyan
Write-Host "Total CSV files checked: $($CsvFiles.Count)" -ForegroundColor White
Write-Host "Broken endpoints found: $($BrokenEndpoints.Count)" -ForegroundColor Red
Write-Host "Working endpoints: $($CsvFiles.Count - $BrokenEndpoints.Count)" -ForegroundColor Green

if ($BrokenEndpoints.Count -gt 0) {
    Write-Host ""
    Write-Host "🚨 BROKEN ENDPOINTS BY ERROR TYPE:" -ForegroundColor Red
    $BrokenEndpoints | Group-Object ErrorType | ForEach-Object {
        Write-Host "$($_.Name): $($_.Count) endpoints" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "📋 FULL LIST OF BROKEN ENDPOINTS:" -ForegroundColor Red
    $BrokenEndpoints | Format-Table Folder, EndpointName, ErrorType -AutoSize

    # Export to CSV for reference
    $BrokenEndpoints | Export-Csv -Path "broken_endpoints_list.csv" -NoTypeInformation -Force
    Write-Host ""
    Write-Host "📁 Detailed list saved to: broken_endpoints_list.csv" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✅ Analysis complete!" -ForegroundColor Green