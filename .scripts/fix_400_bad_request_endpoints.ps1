# Fix 400 Bad Request Endpoints with Required Parameters
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing 400 Bad Request endpoints with required parameters..." -ForegroundColor Green

# Define the endpoints that need fixing
$endpointsToFix = @(
    @{ "File" = "User Properties - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "username=ben.kreischer.ce@omf.com" },
    @{ "File" = "User Properties - GET User Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "username=ben.kreischer.ce@omf.com" },
    @{ "File" = "User Search - GET User Search (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "User Search - GET User Search by Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "User Search - GET User Search by Username (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "Users - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "username=ben.kreischer.ce@omf.com" }
)

foreach ($endpoint in $endpointsToFix) {
    try {
        $filePath = Get-ChildItem -Path $endpointsDir -Recurse -Filter $endpoint.File | Select-Object -First 1
        
        if ($filePath) {
            Write-Host "Processing: $($endpoint.File)" -ForegroundColor Cyan
            
            $content = Get-Content -Path $filePath.FullName -Raw
            $changesMade = $false
            
            # Fix the Invoke-RestMethod URL to include the required parameter
            if ($content -match 'Invoke-RestMethod.*Uri.*\$BaseUrl/rest/api/3/([^"]*)"') {
                $oldUrl = $matches[0]
                $newUrl = $oldUrl -replace '(\$BaseUrl/rest/api/3/[^"]*)"', "`$1?$($endpoint.Param)&maxResults=2147483647`""
                $content = $content -replace [regex]::Escape($oldUrl), $newUrl
                $changesMade = $true
                Write-Host "  Fixed Invoke-RestMethod URL" -ForegroundColor Green
            }
            
            # Fix the Write-Host URL to include the required parameter
            if ($content -match 'Write-Host.*\$BaseUrl/rest/api/3/([^"]*)"') {
                $oldUrl = $matches[0]
                $newUrl = $oldUrl -replace '(\$BaseUrl/rest/api/3/[^"]*)"', "`$1?$($endpoint.Param)&maxResults=2147483647`""
                $content = $content -replace [regex]::Escape($oldUrl), $newUrl
                $changesMade = $true
                Write-Host "  Fixed Write-Host URL" -ForegroundColor Green
            }
            
            if ($changesMade) {
                Set-Content -Path $filePath.FullName -Value $content -Encoding UTF8
                $fixedCount++
                Write-Host "  ✅ Successfully fixed $($endpoint.File)" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  No changes needed for $($endpoint.File)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  ❌ File not found: $($endpoint.File)" -ForegroundColor Red
            $errorCount++
        }
    } catch {
        Write-Host "  ❌ Error processing $($endpoint.File): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host "`n=== FIX SUMMARY ===" -ForegroundColor Magenta
Write-Host "Successfully fixed: $fixedCount endpoints" -ForegroundColor Green
Write-Host "Errors: $errorCount endpoints" -ForegroundColor Red
Write-Host "`nParameters used:" -ForegroundColor Yellow
Write-Host "- Username: ben.kreischer.ce@omf.com" -ForegroundColor Cyan
Write-Host "- Search Query: Origination" -ForegroundColor Cyan
