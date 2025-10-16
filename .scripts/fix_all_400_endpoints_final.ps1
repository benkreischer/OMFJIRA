# Fix All 400 Bad Request Endpoints with Correct Parameters
$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "Fixing all 400 Bad Request endpoints with correct parameters..." -ForegroundColor Green

# Your account ID from the myself endpoint
$accountId = "712020:27226219-226e-4bf3-9d13-545a6e6c9f8c"

# Define the endpoints that need fixing
$endpointsToFix = @(
    @{ "File" = "User Properties - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "accountId=$accountId" },
    @{ "File" = "User Properties - GET User Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "accountId=$accountId" },
    @{ "File" = "User Search - GET User Search (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "User Search - GET User Search by Property (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "User Search - GET User Search by Username (Anon).ps1"; "Endpoint" = "/rest/api/3/user/search"; "Param" = "query=Origination" },
    @{ "File" = "Users - GET User Properties (Anon).ps1"; "Endpoint" = "/rest/api/3/user"; "Param" = "accountId=$accountId" }
)

foreach ($endpoint in $endpointsToFix) {
    try {
        $filePath = Get-ChildItem -Path $endpointsDir -Recurse -Filter $endpoint.File | Select-Object -First 1
        
        if ($filePath) {
            Write-Host "Processing: $($endpoint.File)" -ForegroundColor Cyan
            
            $content = Get-Content -Path $filePath.FullName -Raw
            $changesMade = $false
            
            # Fix the Invoke-RestMethod URL
            if ($content -match 'Invoke-RestMethod.*Uri.*"\$BaseUrl/rest/api/3/([^"]*)"') {
                $oldUrl = $matches[0]
                $newUrl = $oldUrl -replace '"\$BaseUrl/rest/api/3/([^"]*)"', "`"`$BaseUrl/rest/api/3/$($endpoint.Endpoint -replace '/rest/api/3/', '')?$($endpoint.Param)`""
                $content = $content -replace [regex]::Escape($oldUrl), $newUrl
                $changesMade = $true
                Write-Host "  Fixed Invoke-RestMethod URL" -ForegroundColor Green
            }
            
            # Fix the Write-Host URL
            if ($content -match 'Write-Host.*"\$BaseUrl/rest/api/3/([^"]*)"') {
                $oldUrl = $matches[0]
                $newUrl = $oldUrl -replace '"\$BaseUrl/rest/api/3/([^"]*)"', "`"`$BaseUrl/rest/api/3/$($endpoint.Endpoint -replace '/rest/api/3/', '')?$($endpoint.Param)`""
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
Write-Host "- Account ID: $accountId" -ForegroundColor Cyan
Write-Host "- Search Query: Origination" -ForegroundColor Cyan
