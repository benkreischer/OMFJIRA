# =============================================================================
# Complete Fresh Start with Pagination
# =============================================================================
# This script will:
# 1. Delete all existing CSV files from the .endpoints directory
# 2. Run all GET endpoint scripts with proper pagination to get ALL records
# 3. Provide a comprehensive summary of results
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

Write-Host "COMPLETE FRESH START WITH PAGINATION" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

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
# STEP 2: Get all records with pagination
# =============================================================================
Write-Host "`nSTEP 2: Getting ALL records with pagination..." -ForegroundColor Yellow

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

$totalEndpoints = $getScripts.Count
Write-Host "Found $totalEndpoints GET endpoint scripts to process" -ForegroundColor Yellow

# Process each endpoint script
foreach ($script in $getScripts) {
    Write-Host "`nProcessing: $($script.Name)" -ForegroundColor Cyan
    
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
            
            # Keep fetching pages until we get fewer than maxResults records
            do {
                $pageCount++
                Write-Host "  Fetching page $pageCount (startAt: $startAt, maxResults: $maxResults)..." -ForegroundColor Yellow
                
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
                
            } while ($records.Count -eq $maxResults)
            
            Write-Host "  Total records collected: $($allRecords.Count)" -ForegroundColor Green
            
            # Generate CSV filename
            $csvFileName = $script.Name -replace "\.ps1$", ".csv"
            $csvPath = Join-Path $script.Directory $csvFileName
            
            # Convert to CSV and save
            if ($allRecords.Count -gt 0) {
                $allRecords | Export-Csv -Path $csvPath -NoTypeInformation
                Write-Host "  Saved to: $csvFileName" -ForegroundColor Green
                $totalRecords += $allRecords.Count
            } else {
                Write-Host "  No records found" -ForegroundColor Yellow
            }
            
            $successCount++
            
        } else {
            Write-Host "  Could not extract API endpoint from script" -ForegroundColor Red
            $errorCount++
        }
        
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

# =============================================================================
# FINAL SUMMARY
# =============================================================================
Write-Host "`n" + "="*60 -ForegroundColor Magenta
Write-Host "COMPLETE FRESH START FINISHED" -ForegroundColor Magenta
Write-Host "="*60 -ForegroundColor Magenta
Write-Host "CSV Files Deleted: $deletedCount" -ForegroundColor White
Write-Host "Total Endpoints Processed: $totalEndpoints" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $errorCount" -ForegroundColor Red
Write-Host "Total Records Collected: $totalRecords" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Magenta
