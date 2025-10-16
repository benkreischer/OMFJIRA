# =============================================================================
# Complete Fresh Start with ALL CSV Files (Including Failed Endpoints)
# =============================================================================
# This script will:
# 1. Delete all existing CSV files from the .endpoints directory
# 2. Run all GET endpoint scripts with proper pagination to get ALL records
# 3. Create CSV files for ALL endpoints (successful AND failed)
# 4. Provide a comprehensive summary of results
# =============================================================================

# Define Jira connection variables
$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570"

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

$endpointsDir = ".endpoints"
$deletedCount = 0
$successCount = 0
$errorCount = 0
$totalRecords = 0

Write-Host "COMPLETE FRESH START WITH ALL CSV FILES" -ForegroundColor Magenta
Write-Host "=========================================" -ForegroundColor Magenta

# =============================================================================
# STEP 1: Delete all CSV files
# =============================================================================
Write-Host "`nSTEP 1: Cleaning up existing CSV files..." -ForegroundColor Yellow

try {
    $csvFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.csv"
    $deletedCount = $csvFiles.Count
    
    foreach ($file in $csvFiles) {
        try {
            Remove-Item -Path $file.FullName -Force
            Write-Host "  Deleted: $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  Failed to delete: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    Write-Host "`nDeleted $deletedCount CSV files" -ForegroundColor Green
    
} catch {
    Write-Host "Error during cleanup: $($_.Exception.Message)" -ForegroundColor Red
}

# =============================================================================
# STEP 2: Get all records with pagination and create CSV for ALL endpoints
# =============================================================================
Write-Host "`nSTEP 2: Processing ALL endpoints and creating CSV files..." -ForegroundColor Yellow

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

$totalEndpoints = $getScripts.Count
Write-Host "Found $totalEndpoints GET endpoint scripts to process" -ForegroundColor Yellow

# Process each endpoint script
foreach ($script in $getScripts) {
    Write-Host "`nProcessing: $($script.Name)" -ForegroundColor Cyan
    
    # Generate CSV filename
    $csvFileName = $script.Name -replace "\.ps1$", ".csv"
    $csvPath = Join-Path $script.Directory $csvFileName
    
    try {
        # Read the script content
        $scriptContent = Get-Content -Path $script.FullName -Raw
        
        # Extract the API endpoint from the script
        if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"?]+)') {
            $apiPath = $matches[1]
            $fullEndpoint = "/rest/api/3/$apiPath"
            
            Write-Host "  API Endpoint: $fullEndpoint" -ForegroundColor Green
            
            # Initialize pagination variables
            $startAt = 0
            $maxResults = 1000
            $allRecords = @()
            $pageCount = 0
            $errorOccurred = $false
            $errorMessage = ""
            
            # Keep fetching pages until we get fewer than maxResults records
            do {
                $pageCount++
                Write-Host "  Fetching page $pageCount (startAt: $startAt, maxResults: $maxResults)..." -ForegroundColor Yellow
                
                try {
                    # Build the paginated URL
                    $paginatedUrl = "${BaseUrl}${fullEndpoint}?startAt=${startAt}&maxResults=${maxResults}"
                    
                    # Make the API call
                    $response = Invoke-RestMethod -Uri $paginatedUrl -Method GET -Headers @{
                        "Authorization" = $AuthHeader
                        "Accept" = "application/json"
                        "Content-Type" = "application/json"
                    }
                    
                    # Handle different response types
                    if ($response -is [array]) {
                        $records = $response
                    } elseif ($response -is [object] -and $response.values) {
                        $records = $response.values
                    } elseif ($response -is [object]) {
                        $records = @($response)
                    } else {
                        $records = @()
                    }
                    
                    Write-Host "    Got $($records.Count) records on this page" -ForegroundColor Green
                    
                    # Add records to our collection
                    if ($records.Count -gt 0) {
                        $allRecords += $records
                    }
                    
                    # Move to next page
                    $startAt += $maxResults
                    
                } catch {
                    $errorOccurred = $true
                    $errorMessage = $_.Exception.Message
                    Write-Host "  Error: $errorMessage" -ForegroundColor Red
                    break
                }
                
            } while ($records.Count -eq $maxResults -and -not $errorOccurred)
            
            # Create CSV file regardless of success or failure
            if ($errorOccurred) {
                # Create error record
                $errorRecord = [PSCustomObject]@{
                    Status = "Error"
                    ErrorMessage = $errorMessage
                    Endpoint = $fullEndpoint
                    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    RecordsFound = 0
                }
                $errorRecord | Export-Csv -Path $csvPath -NoTypeInformation
                Write-Host "  Created error CSV: $csvFileName" -ForegroundColor Red
                $errorCount++
            } else {
                # Create success CSV
                if ($allRecords.Count -gt 0) {
                    $allRecords | Export-Csv -Path $csvPath -NoTypeInformation
                    Write-Host "  Saved to: $csvFileName ($($allRecords.Count) records)" -ForegroundColor Green
                    $totalRecords += $allRecords.Count
                } else {
                    # Create empty CSV with header
                    $emptyRecord = [PSCustomObject]@{
                        Status = "No Data"
                        Message = "Endpoint returned no records"
                        Endpoint = $fullEndpoint
                        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                    $emptyRecord | Export-Csv -Path $csvPath -NoTypeInformation
                    Write-Host "  Created empty CSV: $csvFileName" -ForegroundColor Yellow
                }
                $successCount++
            }
            
        } else {
            # Create error CSV for scripts that couldn't be parsed
            $parseErrorRecord = [PSCustomObject]@{
                Status = "Parse Error"
                ErrorMessage = "Could not extract API endpoint from script"
                ScriptName = $script.Name
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $parseErrorRecord | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "  Created parse error CSV: $csvFileName" -ForegroundColor Red
            $errorCount++
        }
        
    } catch {
        # Create error CSV for any other errors
        $generalErrorRecord = [PSCustomObject]@{
            Status = "General Error"
            ErrorMessage = $_.Exception.Message
            ScriptName = $script.Name
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $generalErrorRecord | Export-Csv -Path $csvPath -NoTypeInformation
        Write-Host "  Created general error CSV: $csvFileName" -ForegroundColor Red
        $errorCount++
    }
}

# =============================================================================
# STEP 3: Summary
# =============================================================================
Write-Host "`n" + "=" * 60 -ForegroundColor Magenta
Write-Host "COMPLETE FRESH START FINISHED" -ForegroundColor Magenta
Write-Host "=" * 60 -ForegroundColor Magenta
Write-Host "CSV Files Deleted: $deletedCount" -ForegroundColor Green
Write-Host "Total Endpoints Processed: $totalEndpoints" -ForegroundColor Yellow
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $errorCount" -ForegroundColor Red
Write-Host "Total Records Collected: $totalRecords" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Magenta

# Verify we have the expected number of CSV files
$finalCsvCount = (Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.csv").Count
Write-Host "`nFinal CSV File Count: $finalCsvCount" -ForegroundColor Cyan
if ($finalCsvCount -eq $totalEndpoints) {
    Write-Host "✅ SUCCESS: All $totalEndpoints endpoints have CSV files!" -ForegroundColor Green
} else {
    Write-Host "⚠️  WARNING: Expected $totalEndpoints CSV files, but found $finalCsvCount" -ForegroundColor Yellow
}

