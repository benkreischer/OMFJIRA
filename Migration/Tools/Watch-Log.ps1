# Watch-Log.ps1 - Monitor migration logs in real-time
#
# Usage: .\Watch-Log.ps1 -ProjectKey QUAL
#        .\Watch-Log.ps1 -LogFile "path\to\logfile.log.md"

param(
    [string]$ProjectKey,
    [string]$LogFile
)

# Find the most recent log file
if ($LogFile) {
    if (-not (Test-Path $LogFile)) {
        Write-Error "Log file not found: $LogFile"
        exit 1
    }
} elseif ($ProjectKey) {
    $projectDir = Join-Path $PSScriptRoot "projects\$ProjectKey\out"
    
    if (-not (Test-Path $projectDir)) {
        Write-Error "Project directory not found: $projectDir"
        exit 1
    }
    
    $logFiles = Get-ChildItem -Path $projectDir -Filter "*.log.md" | Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -eq 0) {
        Write-Error "No log files found in: $projectDir"
        exit 1
    }
    
    $LogFile = $logFiles[0].FullName
    Write-Host "📊 Found log file: $($logFiles[0].Name)" -ForegroundColor Cyan
} else {
    # Find the most recent log across all projects
    $projectsDir = Join-Path $PSScriptRoot "projects"
    
    if (-not (Test-Path $projectsDir)) {
        Write-Error "Projects directory not found: $projectsDir"
        exit 1
    }
    
    $logFiles = Get-ChildItem -Path $projectsDir -Recurse -Filter "*.log.md" | Sort-Object LastWriteTime -Descending
    
    if ($logFiles.Count -eq 0) {
        Write-Error "No log files found"
        exit 1
    }
    
    $LogFile = $logFiles[0].FullName
    Write-Host "📊 Found most recent log: $($logFiles[0].Name)" -ForegroundColor Cyan
}

Write-Host "📄 Watching: $LogFile" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop`n" -ForegroundColor Gray
Write-Host ("=" * 80) -ForegroundColor DarkGray

# Display existing content first
if (Test-Path $LogFile) {
    Get-Content -Path $LogFile
}

Write-Host "`n" + ("=" * 80) -ForegroundColor DarkGray
Write-Host "Waiting for new entries...`n" -ForegroundColor Gray

# Monitor for new content
Get-Content -Path $LogFile -Wait -Tail 0

