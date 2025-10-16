# =============================================================================
# Fix All Endpoint PowerShell Scripts
# =============================================================================
# This script fixes all .ps1 files in the .endpoints directory to use the
# correct API endpoints instead of the generic /rest/api/3/field template
# =============================================================================

$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

# API endpoint mappings based on the correct Jira REST API v3 endpoints
$apiMappings = @{
    "Projects" = @{
        "GET" = "/rest/api/3/project"
        "POST" = "/rest/api/3/project"
        "PUT" = "/rest/api/3/project/{id}"
        "DEL" = "/rest/api/3/project/{id}"
    }
    "Users" = @{
        "GET" = "/rest/api/3/user"
        "POST" = "/rest/api/3/user"
        "PUT" = "/rest/api/3/user"
        "DEL" = "/rest/api/3/user"
    }
    "Issues" = @{
        "GET" = "/rest/api/3/issue/{id}"
        "POST" = "/rest/api/3/issue"
        "PUT" = "/rest/api/3/issue/{id}"
        "DEL" = "/rest/api/3/issue/{id}"
    }
    "Issue Fields" = @{
        "GET" = "/rest/api/3/field"
        "POST" = "/rest/api/3/field"
        "PUT" = "/rest/api/3/field/{id}"
        "DEL" = "/rest/api/3/field/{id}"
    }
    "Components" = @{
        "GET" = "/rest/api/3/component/{id}"
        "POST" = "/rest/api/3/component"
        "PUT" = "/rest/api/3/component/{id}"
        "DEL" = "/rest/api/3/component/{id}"
    }
    "Workflows" = @{
        "GET" = "/rest/api/3/workflow"
        "POST" = "/rest/api/3/workflow"
        "PUT" = "/rest/api/3/workflow/{id}"
        "DEL" = "/rest/api/3/workflow/{id}"
    }
    "Permission Schemes" = @{
        "GET" = "/rest/api/3/permissionscheme"
        "POST" = "/rest/api/3/permissionscheme"
        "PUT" = "/rest/api/3/permissionscheme/{id}"
        "DEL" = "/rest/api/3/permissionscheme/{id}"
    }
    "Status" = @{
        "GET" = "/rest/api/3/status"
        "POST" = "/rest/api/3/status"
        "PUT" = "/rest/api/3/status/{id}"
        "DEL" = "/rest/api/3/status/{id}"
    }
    "Screens" = @{
        "GET" = "/rest/api/3/screens"
        "POST" = "/rest/api/3/screens"
        "PUT" = "/rest/api/3/screens/{id}"
        "DEL" = "/rest/api/3/screens/{id}"
    }
    "Filters" = @{
        "GET" = "/rest/api/3/filter"
        "POST" = "/rest/api/3/filter"
        "PUT" = "/rest/api/3/filter/{id}"
        "DEL" = "/rest/api/3/filter/{id}"
    }
}

Write-Host "Starting to fix all endpoint PowerShell scripts..." -ForegroundColor Green
Write-Host "Scanning directory: $endpointsDir" -ForegroundColor Cyan

# Get all .ps1 files in the endpoints directory
$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        Write-Host "Processing: $($file.FullName)" -ForegroundColor Yellow
        
        # Read the file content
        $content = Get-Content -Path $file.FullName -Raw
        
        # Extract category and HTTP method from filename
        $fileName = $file.BaseName
        $category = ""
        $httpMethod = ""
        
        # Parse filename to extract category and method
        if ($fileName -match "^([^-]+)\s*-\s*(GET|POST|PUT|DEL|DELETE)\s+(.+)$") {
            $category = $matches[1].Trim()
            $httpMethod = $matches[2].Trim()
        }
        
        # Skip if we can't parse the filename
        if (-not $category -or -not $httpMethod) {
            Write-Host "Skipping $fileName - cannot parse category/method" -ForegroundColor Yellow
            continue
        }
        
        # Get the correct API endpoint
        $correctEndpoint = ""
        if ($apiMappings.ContainsKey($category) -and $apiMappings[$category].ContainsKey($httpMethod)) {
            $correctEndpoint = $apiMappings[$category][$httpMethod]
        } else {
            # Try to find a partial match
            foreach ($key in $apiMappings.Keys) {
                if ($category -like "*$key*" -or $key -like "*$category*") {
                    if ($apiMappings[$key].ContainsKey($httpMethod)) {
                        $correctEndpoint = $apiMappings[$key][$httpMethod]
                        break
                    }
                }
            }
        }
        
        if (-not $correctEndpoint) {
            Write-Host "No mapping found for $category - $httpMethod" -ForegroundColor Yellow
            continue
        }
        
        # Replace the generic endpoint with the correct one
        $oldPattern = '\$apiPath = "/rest/api/3/field"'
        $newPattern = "`$apiPath = `"$correctEndpoint`""
        
        if ($content -match $oldPattern) {
            $content = $content -replace [regex]::Escape($oldPattern), $newPattern
            Write-Host "Fixed endpoint for $category - $httpMethod : $correctEndpoint" -ForegroundColor Green
            
            # Write the updated content back to the file
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $fixedCount++
        } else {
            Write-Host "No generic endpoint found in $fileName" -ForegroundColor Blue
        }
        
    } catch {
        Write-Host "Error processing $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "Fix completed!" -ForegroundColor Green
Write-Host "Files fixed: $fixedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Total files processed: $($ps1Files.Count)" -ForegroundColor Cyan