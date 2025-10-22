# Update-AllScriptsWithLogging.ps1 - Add Terminal Logging to All Migration Scripts
#
# This script updates all migration scripts to include complete terminal output logging

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = @(
    "02_Project.ps1",
    "03_Users.ps1", 
    "04_Components.ps1",
    "05_Versions.ps1",
    "06_Boards.ps1",
    "07_Export.ps1",
    "08_Import.ps1",
    "09_Comments.ps1",
    "10_Attachments.ps1",
    "11_Links.ps1",
    "12_Worklogs.ps1",
    "13_Sprints.ps1",
    "14_History.ps1",
    "15_Review.ps1",
    "15_Summary.ps1",
    "16_PushToConfluence.ps1"
)

foreach ($script in $scripts) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Updating $script..." -ForegroundColor Cyan
    
    # Read the script content
    $content = Get-Content -Path $scriptPath -Raw
    
    # Extract step name from script (e.g., "02_Project" from "02_Project.ps1")
    $stepName = $script -replace '\.ps1$', ''
    
    # 1. Add terminal logging import after _common.ps1
    $content = $content -replace '\. \(Join-Path \$here "_common\.ps1"\)', '. (Join-Path $here "_common.ps1")' + "`n. (Join-Path `$here `"_terminal_logging.ps1`")"
    
    # 2. Add terminal logging start after step start time
    $loggingStart = @"

# Start terminal logging
`$terminalLogPath = Start-TerminalLog -StepName "$stepName" -OutDir `$outDir -ProjectKey `$p.ProjectKey

# Set up error handling to ensure logging stops on errors
`$ErrorActionPreference = "Stop"
trap {
    Stop-TerminalLogOnError -ErrorMessage `$_.Exception.Message
    throw
}
"@
    $content = $content -replace '(\$script:StepStartTime = Get-Date)', '$1' + $loggingStart
    
    # 3. Add terminal logging stop before exit statements
    $loggingStop = @"

# Stop terminal logging
Stop-TerminalLog -Success:`$true -Summary "$stepName completed successfully"
"@
    $content = $content -replace '(exit 0)', $loggingStop + "`n`n$1"
    
    $loggingStopError = @"

# Stop terminal logging
Stop-TerminalLog -Success:`$false -Summary "$stepName failed"
"@
    $content = $content -replace '(exit 1)', $loggingStopError + "`n`n$1"
    
    # Write the updated content back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "✅ Updated $script" -ForegroundColor Green
}

Write-Host "`n🎉 All migration scripts updated with terminal logging!" -ForegroundColor Green
Write-Host "`nEach script will now create a log file named: XX_StepName_Log.md" -ForegroundColor Cyan
Write-Host "Example: 01_Preflight_Log.md, 02_Project_Log.md, etc." -ForegroundColor Gray
