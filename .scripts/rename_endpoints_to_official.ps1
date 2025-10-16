# =============================================================================
# RENAME ALL OFFICIAL API ENDPOINTS TO ADD " - Official" SUFFIX
# =============================================================================
# This script renames all official Atlassian API endpoint files to add " - Official"
# after the authentication name (e.g., " - Anon" becomes " - Anon - Official")
# =============================================================================

Write-Host "=== RENAMING ALL OFFICIAL API ENDPOINTS ===" -ForegroundColor Green

# Get all endpoint folders
$endpointFolders = Get-ChildItem -Directory

foreach ($folder in $endpointFolders) {
    Write-Host "Processing folder: $($folder.Name)" -ForegroundColor Yellow
    
    # Get all files in the folder that match the pattern " - Anon.*" but are NOT already " - Official" or " - Custom"
    $filesToRename = Get-ChildItem -Path $folder.FullName -File | Where-Object {
        $_.Name -match " - Anon\." -and 
        $_.Name -notmatch " - Official" -and 
        $_.Name -notmatch " - Custom"
    }
    
    foreach ($file in $filesToRename) {
        $newName = $file.Name -replace " - Anon\.", " - Anon - Official."
        $newPath = Join-Path $folder.FullName $newName
        
        try {
            Rename-Item -Path $file.FullName -NewName $newName
            Write-Host "  Renamed: $($file.Name) -> $newName" -ForegroundColor Green
        } catch {
            Write-Host "  Error renaming $($file.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "=== RENAMING COMPLETE ===" -ForegroundColor Green
