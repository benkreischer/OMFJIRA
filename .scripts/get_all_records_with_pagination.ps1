# =============================================================================
# Get ALL Records with Pagination
# =============================================================================
# This script implements proper pagination to get ALL records from each endpoint
# by making multiple requests of 1,000 records each until everything is fetched
# =============================================================================

$endpointsDir = ".endpoints"
$successCount = 0
$errorCount = 0
$totalRecords = 0

Write-Host "GETTING ALL RECORDS WITH PAGINATION" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

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
        if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"]+)') {
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
                $paginatedUrl = "$BaseUrl$fullEndpoint?startAt=$startAt&maxResults=$maxResults"
                
                # Make the API call
                $response = Invoke-RestMethod -Uri $paginatedUrl -Method GET -Headers @{
                    "Authorization" = "Basic $authString"
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

# Final summary
Write-Host "`n" + "="*60 -ForegroundColor Magenta
Write-Host "PAGINATION COMPLETE" -ForegroundColor Magenta
Write-Host "="*60 -ForegroundColor Magenta
Write-Host "Total Endpoints Processed: $totalEndpoints" -ForegroundColor White
Write-Host "Successful: $successCount" -ForegroundColor Green
Write-Host "Failed: $errorCount" -ForegroundColor Red
Write-Host "Total Records Collected: $totalRecords" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Magenta
