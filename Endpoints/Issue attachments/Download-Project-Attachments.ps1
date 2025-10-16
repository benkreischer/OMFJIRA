# =============================================================================
# DOWNLOAD PROJECT ATTACHMENTS
# =============================================================================
#
# DESCRIPTION: Downloads all attachments from a project attachment CSV file
#
# USAGE: 
#   .\Download-Project-Attachments.ps1 -ProjectKey "ENGOPS"
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectKey
)


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# LOAD ATTACHMENT DATA
# =============================================================================
$CsvFile = ".\Project_${ProjectKey}_Attachments.csv"

if (-not (Test-Path $CsvFile)) {
    Write-Host "Error: Could not find attachment file: $CsvFile" -ForegroundColor Red
    Write-Host "Please run Get-Project-Attachments-From-Data.ps1 first." -ForegroundColor Yellow
    exit 1
}

Write-Host "Loading attachment data from: $CsvFile" -ForegroundColor Yellow
$Attachments = Import-Csv $CsvFile

Write-Host "Found $($Attachments.Count) attachments to download" -ForegroundColor Green
Write-Host ""

# =============================================================================
# CREATE OUTPUT DIRECTORY
# =============================================================================
$OutputDir = ".\Attachments_$ProjectKey"
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# =============================================================================
# DOWNLOAD ATTACHMENTS
# =============================================================================
$SuccessCount = 0
$FailCount = 0
$SkipCount = 0
$TotalSize = 0

foreach ($attachment in $Attachments) {
    $IssueKey = $attachment.IssueKey
    $Filename = $attachment.AttachmentFilename
    $AttachmentId = $attachment.AttachmentId
    $ContentUrl = $attachment.AttachmentContentUrl
    $Size = [int]$attachment.AttachmentSize
    
    # Create issue-specific subdirectory
    $IssueDir = Join-Path $OutputDir $IssueKey
    if (-not (Test-Path $IssueDir)) {
        New-Item -ItemType Directory -Path $IssueDir | Out-Null
    }
    
    # Full path for the file
    $OutputPath = Join-Path $IssueDir $Filename
    
    # Check if file already exists
    if (Test-Path $OutputPath) {
        $ExistingFile = Get-Item $OutputPath
        if ($ExistingFile.Length -eq $Size) {
            Write-Host "[SKIP] $IssueKey/$Filename (already exists)" -ForegroundColor Gray
            $SkipCount++
            $TotalSize += $Size
            continue
        }
    }
    
    Write-Host "[DOWNLOADING] $IssueKey/$Filename ($([math]::Round($Size/1KB, 2)) KB)..." -ForegroundColor Yellow
    
    try {
        # Download the attachment
        Invoke-WebRequest -Uri $ContentUrl -Headers $AuthHeader -OutFile $OutputPath -ErrorAction Stop
        
        Write-Host "  [SUCCESS] Downloaded to: $OutputPath" -ForegroundColor Green
        $SuccessCount++
        $TotalSize += $Size
        
        # Small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
        
    } catch {
        Write-Host "  [FAILED] Error: $($_.Exception.Message)" -ForegroundColor Red
        $FailCount++
    }
}

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DOWNLOAD COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total Attachments: $($Attachments.Count)" -ForegroundColor White
Write-Host "Successfully Downloaded: $SuccessCount" -ForegroundColor Green
Write-Host "Skipped (already exists): $SkipCount" -ForegroundColor Gray
Write-Host "Failed: $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { "Red" } else { "White" })
Write-Host "Total Size: $([math]::Round($TotalSize/1MB, 2)) MB" -ForegroundColor White
Write-Host ""
Write-Host "Files saved to: $OutputDir" -ForegroundColor Cyan


