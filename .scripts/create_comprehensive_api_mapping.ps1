# =============================================================================
# Create Comprehensive API Mapping
# =============================================================================
# This script extracts all correct API endpoints from Power Query files
# and creates a comprehensive mapping for fixing PowerShell scripts
# =============================================================================

$endpointsDir = ".endpoints"
$apiMappings = @{}

Write-Host "Extracting API endpoints from Power Query files..." -ForegroundColor Green

# Get all .pq files in the endpoints directory
$pqFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.pq"

foreach ($file in $pqFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        
        # Extract endpoint from the file
        if ($content -match 'Endpoint = "([^"]+)"') {
            $endpoint = $matches[1]
            
            # Extract category and method from filename
            $fileName = $file.BaseName
            if ($fileName -match "^([^-]+)\s*-\s*(GET|POST|PUT|DEL|DELETE)\s+(.+)$") {
                $category = $matches[1].Trim()
                $httpMethod = $matches[2].Trim()
                
                # Initialize category if not exists
                if (-not $apiMappings.ContainsKey($category)) {
                    $apiMappings[$category] = @{}
                }
                
                # Store the endpoint
                $apiMappings[$category][$httpMethod] = $endpoint
                
                Write-Host "Found: $category - $httpMethod : $endpoint" -ForegroundColor Cyan
            }
        }
    } catch {
        Write-Host "Error processing $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Output the comprehensive mapping
Write-Host "`nComprehensive API Mapping:" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green

$apiMappings.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $category = $_.Key
    $methods = $_.Value
    
    Write-Host "`n$category" -ForegroundColor Yellow
    $methods.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor White
    }
}

# Save to file for reference
$mappingFile = "comprehensive_api_mapping.txt"
$apiMappings.GetEnumerator() | Sort-Object Name | ForEach-Object {
    $category = $_.Key
    $methods = $_.Value
    
    Add-Content -Path $mappingFile -Value "`n$category"
    $methods.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Add-Content -Path $mappingFile -Value "  $($_.Key): $($_.Value)"
    }
}

Write-Host "`nMapping saved to: $mappingFile" -ForegroundColor Green
Write-Host "Total categories found: $($apiMappings.Count)" -ForegroundColor Cyan
