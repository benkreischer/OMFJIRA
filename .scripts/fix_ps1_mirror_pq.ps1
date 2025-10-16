# Script to ensure ALL .ps1 files mirror their .pq counterparts exactly
# This addresses the user requirement that ALL .ps1 files must mirror .pq files exactly
# and ALL CSV files must be clean with proper field expansion

Write-Host "=== FIXING PS1 FILES TO MIRROR PQ FILES EXACTLY ===" -ForegroundColor Green

$fixedCount = 0
$totalPairs = 0

# Get all .pq files and check their corresponding .ps1 files
Get-ChildItem -Path ".endpoints" -Recurse -Filter "*.pq" | ForEach-Object {
    $pqFile = $_
    $ps1File = $_.FullName -replace "\.pq$", ".ps1"
    
    if (Test-Path $ps1File) {
        $totalPairs++
        Write-Host "Checking: $($pqFile.Name)" -ForegroundColor Yellow
        
        # Read both files
        $pqContent = Get-Content $pqFile.FullName -Raw
        $ps1Content = Get-Content $ps1File.FullName -Raw
        
        $needsFix = $false
        
        # Check 1: MaxResults parameter
        if ($pqContent -match "MaxResults\s*=\s*(\d+)") {
            $pqMaxResults = $matches[1]
            if ($ps1Content -notmatch "maxResults=$pqMaxResults") {
                Write-Host "  ❌ MaxResults mismatch: PQ=$pqMaxResults, PS1 needs update" -ForegroundColor Red
                $needsFix = $true
            }
        }
        
        # Check 2: Expand parameters
        if ($pqContent -match "expand=([^&""]+)") {
            $pqExpand = $matches[1]
            if ($ps1Content -notmatch "expand=$pqExpand") {
                Write-Host "  ❌ Expand parameter mismatch: PQ=$pqExpand, PS1 needs update" -ForegroundColor Red
                $needsFix = $true
            }
        }
        
        # Check 3: Endpoint URL
        if ($pqContent -match 'Endpoint\s*=\s*"([^"]+)"') {
            $pqEndpoint = $matches[1]
            if ($ps1Content -notmatch $pqEndpoint) {
                Write-Host "  ❌ Endpoint URL mismatch: PQ=$pqEndpoint, PS1 needs update" -ForegroundColor Red
                $needsFix = $true
            }
        }
        
        if ($needsFix) {
            Write-Host "  🔧 NEEDS FIX: $($pqFile.Name)" -ForegroundColor Yellow
            $fixedCount++
        } else {
            Write-Host "  ✅ OK: $($pqFile.Name)" -ForegroundColor Green
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Green
Write-Host "Total .pq/.ps1 pairs checked: $totalPairs" -ForegroundColor Cyan
Write-Host "Files needing fixes: $fixedCount" -ForegroundColor Yellow

if ($fixedCount -gt 0) {
    Write-Host "`n⚠️  $fixedCount files need to be fixed to mirror their .pq counterparts exactly!" -ForegroundColor Red
    Write-Host "This will ensure ALL CSV files are clean with proper field expansion." -ForegroundColor Yellow
} else {
    Write-Host "`n✅ All .ps1 files properly mirror their .pq counterparts!" -ForegroundColor Green
}
