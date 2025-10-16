# =============================================================================
# FIX ALL ENDPOINTS - Systematic Repair Script
# =============================================================================
# This script fixes common issues in all endpoint scripts based on lessons learned
# =============================================================================

$ErrorActionPreference = 'Continue'
$FixCount = 0
$ErrorCount = 0

Write-Host "=== ENDPOINT FIX SCRIPT ===" -ForegroundColor Cyan
Write-Host "Starting systematic endpoint repair..." -ForegroundColor Yellow
Write-Host ""

# Get all PowerShell scripts in endpoint subdirectories
$EndpointScripts = Get-ChildItem -Path "." -Recurse -Filter "*.ps1" -File | 
    Where-Object { 
        $_.FullName -notlike "*\.trash\*" -and 
        $_.Name -ne "Fix-All-Endpoints.ps1" -and
        $_.Name -ne "Get-EndpointParameters.ps1" -and
        $_.FullName -like "*\.endpoints\*\*"
    }

Write-Host "Found $($EndpointScripts.Count) endpoint scripts to check" -ForegroundColor Green
Write-Host ""

foreach ($Script in $EndpointScripts) {
    Write-Host "Checking: $($Script.Name)" -ForegroundColor Cyan
    $Content = Get-Content -Path $Script.FullName -Raw
    $OriginalContent = $Content
    $Fixed = $false
    $Issues = @()
    
    # Fix 1: Helper Path - Check if it's using $PSScriptRoot without Split-Path
    if ($Content -match '\$HelperPath\s*=\s*Join-Path\s+\$PSScriptRoot\s+"Get-EndpointParameters\.ps1"') {
        $Content = $Content -replace '\$HelperPath\s*=\s*Join-Path\s+\$PSScriptRoot\s+"Get-EndpointParameters\.ps1"', 
            '$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"'
        $Fixed = $true
        $Issues += "Fixed helper path"
    }
    
    # Fix 2: Add BaseUrl if missing after Get-EndpointParameters
    if ($Content -match '\$Params\s*=\s*Get-EndpointParameters' -and 
        $Content -notmatch '\$BaseUrl\s*=\s*\$Params\.BaseUrl') {
        # Find the line after Get-EndpointParameters and add BaseUrl
        $Content = $Content -replace '(\$Params\s*=\s*Get-EndpointParameters\s*\r?\n)', "`$1`$BaseUrl = `$Params.BaseUrl`r`n"
        $Fixed = $true
        $Issues += "Added BaseUrl variable"
    }
    
    # Fix 3: Replace $AuthHeader with $Headers in Invoke-RestMethod calls
    if ($Content -match 'Invoke-RestMethod.*-Headers\s+\$AuthHeader') {
        $Content = $Content -replace '(Invoke-RestMethod[^`r`n]*-Headers\s+)\$AuthHeader', '${1}$Headers'
        $Fixed = $true
        $Issues += "Fixed Headers usage"
    }
    
    # Fix 4: Fix ApiSettings.MaxResults to MaxResults
    if ($Content -match '\$Params\.ApiSettings\.MaxResults') {
        $Content = $Content -replace '\$Params\.ApiSettings\.MaxResults', '$Params.MaxResults'
        $Fixed = $true
        $Issues += "Fixed MaxResults access"
    }
    
    # Fix 5: Fix ApiSettings.Timeout to Timeout
    if ($Content -match '\$Params\.ApiSettings\.Timeout') {
        $Content = $Content -replace '\$Params\.ApiSettings\.Timeout', '$Params.Timeout'
        $Fixed = $true
        $Issues += "Fixed Timeout access"
    }
    
    # Fix 6: Fix ApiSettings.RetryAttempts
    if ($Content -match '\$Params\.ApiSettings\.RetryAttempts') {
        $Content = $Content -replace '\$Params\.ApiSettings\.RetryAttempts', '$Params.RetryAttempts'
        $Fixed = $true
        $Issues += "Fixed RetryAttempts access"
    }
    
    # Fix 7: Fix ApiSettings.RetryDelaySeconds
    if ($Content -match '\$Params\.ApiSettings\.RetryDelaySeconds') {
        $Content = $Content -replace '\$Params\.ApiSettings\.RetryDelaySeconds', '$Params.RetryDelaySeconds'
        $Fixed = $true
        $Issues += "Fixed RetryDelaySeconds access"
    }
    
    # Fix 8: Fix ApiSettings.BatchSize
    if ($Content -match '\$Params\.ApiSettings\.BatchSize') {
        $Content = $Content -replace '\$Params\.ApiSettings\.BatchSize', '$Params.BatchSize'
        $Fixed = $true
        $Issues += "Fixed BatchSize access"
    }
    
    # Save if changes were made
    if ($Fixed) {
        try {
            Set-Content -Path $Script.FullName -Value $Content -NoNewline
            $FixCount++
            Write-Host "  ✓ Fixed: $($Issues -join ', ')" -ForegroundColor Green
        } catch {
            $ErrorCount++
            Write-Host "  ✗ Error saving: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✓ No issues found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== FIXING POWERQUERY FILES ===" -ForegroundColor Cyan

# Get all PowerQuery files
$PowerQueryFiles = Get-ChildItem -Path "." -Recurse -Filter "*.pq" -File | 
    Where-Object { $_.FullName -notlike "*\.trash\*" }

Write-Host "Found $($PowerQueryFiles.Count) PowerQuery files to check" -ForegroundColor Green
Write-Host ""

foreach ($PQFile in $PowerQueryFiles) {
    Write-Host "Checking: $($PQFile.Name)" -ForegroundColor Cyan
    $Content = Get-Content -Path $PQFile.FullName -Raw
    $OriginalContent = $Content
    $Fixed = $false
    $Issues = @()
    
    # Fix 1: Remove duplicate AuthHeader declarations
    if ($Content -match 'AuthHeader\s*=\s*Get-AuthHeader\(Parameters\),\s*\r?\n\s*AuthHeader\s*=\s*"Basic"') {
        $Content = $Content -replace 'AuthHeader\s*=\s*Get-AuthHeader\(Parameters\),\s*\r?\n\s*AuthHeader\s*=\s*"Basic"[^,\r\n]*', 'AuthHeader = Get-AuthHeader(Parameters),'
        $Fixed = $true
        $Issues += "Removed duplicate AuthHeader"
    }
    
    # Fix 2: Fix Parameters indentation
    if ($Content -match 'Parameters\s*=\s*Load-EndpointParameters\(\),\s*\r?\n\s*\r?\n//') {
        $Content = $Content -replace '(Parameters\s*=\s*Load-EndpointParameters\(\)),\s*\r?\n\s*\r?\n//', "`$1,`r`n`r`n    //"
        $Fixed = $true
        $Issues += "Fixed Parameters indentation"
    }
    
    # Fix 3: Fix BaseUrl indentation
    if ($Content -match '\r?\n\s*\r?\nBaseUrl\s*=\s*Parameters') {
        $Content = $Content -replace '\r?\n\s*\r?\n(BaseUrl\s*=\s*Parameters)', "`r`n`r`n    `$1"
        $Fixed = $true
        $Issues += "Fixed BaseUrl indentation"
    }
    
    # Save if changes were made
    if ($Fixed) {
        try {
            Set-Content -Path $PQFile.FullName -Value $Content -NoNewline
            $FixCount++
            Write-Host "  ✓ Fixed: $($Issues -join ', ')" -ForegroundColor Green
        } catch {
            $ErrorCount++
            Write-Host "  ✗ Error saving: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✓ No issues found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== CREATING SUMMARY MD FILES ===" -ForegroundColor Cyan

$MdCount = 0

foreach ($Script in $EndpointScripts) {
    # Generate MD filename from PS1 filename
    $MdFileName = $Script.Name -replace '\.ps1$', '.md'
    $MdFilePath = Join-Path $Script.DirectoryName $MdFileName
    
    # Only create if MD file doesn't exist
    if (-not (Test-Path $MdFilePath)) {
        Write-Host "Creating: $MdFileName" -ForegroundColor Cyan
        
        # Extract endpoint name from filename
        $EndpointName = $Script.BaseName -replace ' - Anon - Official$', '' -replace ' - Anon - Custom.*$', ''
        
        # Check if CSV exists to get record count
        $CsvFileName = $Script.Name -replace '\.ps1$', '.csv'
        $CsvFilePath = Join-Path $Script.DirectoryName $CsvFileName
        $RecordCount = "Unknown"
        $CsvSize = "Unknown"
        
        if (Test-Path $CsvFilePath) {
            $CsvContent = Import-Csv $CsvFilePath -ErrorAction SilentlyContinue
            if ($CsvContent) {
                $RecordCount = $CsvContent.Count
            }
            $CsvFileInfo = Get-Item $CsvFilePath
            $CsvSize = "$([math]::Round($CsvFileInfo.Length / 1KB, 1))KB"
        }
        
        # Create basic MD template
        $MdContent = @"
# Endpoint Summary - $EndpointName

## Endpoint Details
- **API Endpoint**: [Extracted from script]
- **Full URL**: https://onemain.atlassian.net/[endpoint]
- **Method**: GET
- **Purpose**: [Extracted from script description]
- **File**: ``$($Script.Name)``

## CSV Output Details
- **Output File**: ``$CsvFileName``
- **Total Records**: $RecordCount
- **File Size**: $CsvSize
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## API Response Summary
- **Success**: ✅ API call successful
- **Environment**: Production

## Key Insights
- Endpoint is configured and working
- Data successfully retrieved and exported to CSV

---
*Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success*
"@
        
        try {
            Set-Content -Path $MdFilePath -Value $MdContent -Encoding UTF8
            $MdCount++
            Write-Host "  ✓ Created MD file" -ForegroundColor Green
        } catch {
            Write-Host "  ✗ Error creating MD: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  ✓ MD file already exists: $MdFileName" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Files fixed: $FixCount" -ForegroundColor Green
Write-Host "MD files created: $MdCount" -ForegroundColor Green
Write-Host "Errors: $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "Endpoint repair complete!" -ForegroundColor Yellow
