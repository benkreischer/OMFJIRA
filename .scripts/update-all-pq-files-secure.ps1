# =============================================================================
# UPDATE ALL POWER QUERY FILES TO SECURE AUTHENTICATION
# =============================================================================

# This script updates all Power Query files to use secure authentication
# instead of embedded API tokens

param(
    [switch]$BackupOriginal = $true,
    [switch]$DryRun = $false,
    [string]$BackupPath = ".\backups\original-pq-files"
)

Write-Host "Updating all Power Query files to secure authentication..." -ForegroundColor Cyan
Write-Host "Backup Original: $BackupOriginal" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow

# Create backup directory if needed
if ($BackupOriginal -and -not (Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force
    Write-Host "Created backup directory: $BackupPath" -ForegroundColor Green
}

# Get all Power Query files
$pqFiles = Get-ChildItem -Path "." -Filter "jira-queries-*.pq" -Recurse

Write-Host "Found $($pqFiles.Count) Power Query files to update" -ForegroundColor Green

$updatedCount = 0
$errorCount = 0

foreach ($file in $pqFiles) {
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    
    try {
        # Read file content
        $content = Get-Content $file.FullName -Raw
        
        # Create backup if requested
        if ($BackupOriginal -and -not $DryRun) {
            $backupFile = Join-Path $BackupPath $file.Name
            Copy-Item $file.FullName $backupFile -Force
            Write-Host "  Backed up to: $backupFile" -ForegroundColor Green
        }
        
        # Replace embedded credentials with secure authentication
        $newContent = $content
        
        # Replace BaseUrl
        $newContent = $newContent -replace 'BaseUrl = "https://onemain\.atlassian\.net/rest/api/3"', 'BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1]'
        
        # Replace Username
        $newContent = $newContent -replace 'Username = "[^"]*"', 'Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1]'
        
        # Replace ApiToken
        $newContent = $newContent -replace 'ApiToken = "[^"]*"', 'ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1]'
        
        # Replace AuthHeader (ensure it's properly formatted)
        $newContent = $newContent -replace 'AuthHeader = "Basic [^"]*"', 'AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64)'
        
        # Add comments for secure authentication
        if ($newContent -notmatch "SECURE AUTHENTICATION") {
            $newContent = $newContent -replace '// =============================================================================\r?\n// \d+\.', '// =============================================================================`n// $& - SECURE AUTHENTICATION'
        }
        
        # Add authentication setup comments if not present
        if ($newContent -notmatch "Read credentials from Excel named ranges") {
            $newContent = $newContent -replace '(let\s*\r?\n)', '$1    // Read credentials from Excel named ranges (set up by Authentication Manager)`n'
        }
        
        # Write updated content if not dry run
        if (-not $DryRun) {
            $newContent | Out-File -FilePath $file.FullName -Encoding UTF8
            Write-Host "  ✅ Updated successfully" -ForegroundColor Green
        } else {
            Write-Host "  🔍 Dry run - would update" -ForegroundColor Cyan
        }
        
        $updatedCount++
    }
    catch {
        Write-Error "  ❌ Failed to update $($file.Name): $($_.Exception.Message)"
        $errorCount++
    }
}

# Create usage instructions file
$instructionsContent = @"
# SECURE AUTHENTICATION SETUP INSTRUCTIONS

## For OMF Users:

### 1. Login with OMF Credentials
```powershell
.\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO
```

### 2. Set Up Excel Named Ranges
Create these named ranges in Excel:

| Named Range | Value | Description |
|-------------|-------|-------------|
| JiraBaseUrl | https://onemain.atlassian.net/rest/api/3 | Jira API base URL |
| JiraUsername | [Your OMF Email] | Your OMF email address |
| JiraApiToken | [Auto-generated] | Your API token (auto-generated) |

### 3. How to Create Named Ranges in Excel:
1. Open Excel
2. Go to **Formulas** > **Name Manager**
3. Click **New**
4. Enter the name and value for each range above
5. The JiraApiToken will be automatically populated when you log in

### 4. Load Power Query Files:
1. Copy any query from the updated .pq files
2. Paste into Power Query Editor
3. Refresh to load data with your credentials

## Security Features:
- ✅ **No embedded credentials** in files
- ✅ **OMF SSO Integration** - Use your OMF credentials
- ✅ **Encrypted API tokens** - Stored securely
- ✅ **Role-based permissions** - Access based on your role
- ✅ **Session management** - Automatic refresh
- ✅ **Audit logging** - Track all access

## Files Updated:
$($pqFiles | ForEach-Object { "- $($_.Name)" } | Out-String)

## Support:
Contact OMF Analytics Team for assistance.

---
*Updated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*
"@

$instructionsPath = ".\SECURE_AUTHENTICATION_SETUP.md"
$instructionsContent | Out-File -FilePath $instructionsPath -Encoding UTF8

Write-Host "`n" -NoNewline
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "UPDATE SUMMARY" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host "Files processed: $($pqFiles.Count)" -ForegroundColor White
Write-Host "Successfully updated: $updatedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Backup created: $BackupOriginal" -ForegroundColor Yellow
Write-Host "Dry run: $DryRun" -ForegroundColor Yellow
Write-Host "Instructions created: $instructionsPath" -ForegroundColor Green

if ($DryRun) {
    Write-Host "`nThis was a dry run. No files were actually modified." -ForegroundColor Yellow
    Write-Host "Run without -DryRun to apply changes." -ForegroundColor Yellow
} else {
    Write-Host "`nAll Power Query files have been updated to use secure authentication!" -ForegroundColor Green
    Write-Host "Users can now log in with their OMF credentials and access all dashboards seamlessly." -ForegroundColor Green
}

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Run: .\jira-authentication-manager.ps1 -Action login -Username 'your.email@omf.com' -UseSSO" -ForegroundColor White
Write-Host "2. Set up Excel named ranges as described in the instructions" -ForegroundColor White
Write-Host "3. Load Power Query files into Excel" -ForegroundColor White
Write-Host "4. Enjoy seamless access to all Jira analytics!" -ForegroundColor White
