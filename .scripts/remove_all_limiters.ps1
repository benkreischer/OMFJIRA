# =============================================================================
# Remove All Limiters from Endpoint Files
# =============================================================================
# This script removes all maxResults, limit, startAt, and other pagination
# parameters from Power Query files to ensure ALL records are returned
# for comprehensive Jira environment auditing
# =============================================================================

$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

Write-Host "🔍 Removing all limiters from endpoint files..." -ForegroundColor Green
Write-Host "📁 Processing directory: $endpointsDir" -ForegroundColor Yellow

# Get all .pq files in the endpoints directory
$pqFiles = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.pq"

foreach ($file in $pqFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw
        $originalContent = $content
        $changesMade = $false
        
        Write-Host "📄 Processing: $($file.Name)" -ForegroundColor Cyan
        
        # Remove maxResults parameters and set to maximum possible
        if ($content -match 'maxResults\s*=\s*[^,\n]+') {
            $content = $content -replace 'maxResults\s*=\s*[^,\n]+', 'maxResults = 2147483647'
            $changesMade = $true
            Write-Host "  ✅ Removed maxResults limiter" -ForegroundColor Green
        }
        
        # Remove limit parameters and set to maximum possible
        if ($content -match 'limit\s*=\s*[^,\n]+') {
            $content = $content -replace 'limit\s*=\s*[^,\n]+', 'limit = 2147483647'
            $changesMade = $true
            Write-Host "  ✅ Removed limit limiter" -ForegroundColor Green
        }
        
        # Remove startAt parameters and set to 0 (start from beginning)
        if ($content -match 'startAt\s*=\s*[^,\n]+') {
            $content = $content -replace 'startAt\s*=\s*[^,\n]+', 'startAt = 0'
            $changesMade = $true
            Write-Host "  ✅ Reset startAt to 0" -ForegroundColor Green
        }
        
        # Remove MaxResults parameters (capitalized version)
        if ($content -match 'MaxResults\s*=\s*[^,\n]+') {
            $content = $content -replace 'MaxResults\s*=\s*[^,\n]+', 'MaxResults = 2147483647'
            $changesMade = $true
            Write-Host "  ✅ Removed MaxResults limiter" -ForegroundColor Green
        }
        
        # Remove Limit parameters (capitalized version)
        if ($content -match 'Limit\s*=\s*[^,\n]+') {
            $content = $content -replace 'Limit\s*=\s*[^,\n]+', 'Limit = 2147483647'
            $changesMade = $true
            Write-Host "  ✅ Removed Limit limiter" -ForegroundColor Green
        }
        
        # Remove StartAt parameters (capitalized version)
        if ($content -match 'StartAt\s*=\s*[^,\n]+') {
            $content = $content -replace 'StartAt\s*=\s*[^,\n]+', 'StartAt = 0'
            $changesMade = $true
            Write-Host "  ✅ Reset StartAt to 0" -ForegroundColor Green
        }
        
        # Fix pagination logic to always fetch all records
        # Replace pagination conditions that limit results
        if ($content -match 'if\s+StartAt\s*\+\s*\d+\s*<\s*Total\s+then\s+Values\s*&\s*@GetAllPages\(StartAt\s*\+\s*\d+\)\s+else\s+Values') {
            $content = $content -replace 'if\s+StartAt\s*\+\s*\d+\s*<\s*Total\s+then\s+Values\s*&\s*@GetAllPages\(StartAt\s*\+\s*\d+\)\s+else\s+Values', 'if IsLast = false then Values & @GetAllPages(NextStartAt) else Values'
            $changesMade = $true
            Write-Host "  ✅ Fixed pagination logic to fetch all records" -ForegroundColor Green
        }
        
        # Remove hardcoded page size limits in pagination
        if ($content -match 'StartAt\s*\+\s*50\s*<\s*Total') {
            $content = $content -replace 'StartAt\s*\+\s*50\s*<\s*Total', 'IsLast = false'
            $changesMade = $true
            Write-Host "  ✅ Removed hardcoded page size limit" -ForegroundColor Green
        }
        
        # Set default maxResults to maximum if not specified
        if ($content -notmatch 'maxResults\s*=' -and $content -match 'Endpoint\s*=\s*"[^"]*rest/api/3/[^"]*"') {
            # Add maxResults parameter to endpoints that don't have it
            $content = $content -replace '(Endpoint\s*=\s*"[^"]*rest/api/3/[^"]*")', '$1 & "?maxResults=2147483647"'
            $changesMade = $true
            Write-Host "  ✅ Added maxResults parameter" -ForegroundColor Green
        }
        
        # Save the file if changes were made
        if ($changesMade) {
            Set-Content -Path $file.FullName -Value $content -Encoding UTF8
            $fixedCount++
            Write-Host "  💾 File updated successfully" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  No limiters found in this file" -ForegroundColor Yellow
        }
        
    } catch {
        $errorCount++
        Write-Host "  ❌ Error processing $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n🎯 SUMMARY:" -ForegroundColor Magenta
Write-Host "✅ Files processed: $($pqFiles.Count)" -ForegroundColor Green
Write-Host "✅ Files updated: $fixedCount" -ForegroundColor Green
Write-Host "❌ Errors: $errorCount" -ForegroundColor Red

if ($fixedCount -gt 0) {
    Write-Host "`n🚀 All limiters have been removed! Endpoints will now return ALL records." -ForegroundColor Green
    Write-Host "📊 This ensures comprehensive auditing of your Jira environment." -ForegroundColor Cyan
} else {
    Write-Host "`nℹ️  No files needed updating - all endpoints already return unlimited results." -ForegroundColor Yellow
}
