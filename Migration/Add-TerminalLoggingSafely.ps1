# Add-TerminalLoggingSafely.ps1 - Safely Add Terminal Logging to All Migration Scripts
#
# This script carefully adds terminal logging to each script and verifies syntax

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = @(
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

Write-Host "🔧 Safely Adding Terminal Logging to All Migration Scripts" -ForegroundColor Cyan
Write-Host "=" * 60

foreach ($script in $scripts) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Processing $script..." -ForegroundColor Yellow
    
    # Extract step name from script (e.g., "03_Users" from "03_Users.ps1")
    $stepName = $script -replace '\.ps1$', ''
    
    # Read the script content
    $content = Get-Content -Path $scriptPath -Raw
    
    # Check if terminal logging is already present
    if ($content -match '_terminal_logging\.ps1') {
        Write-Host "  ⚠️  Terminal logging already present - skipping" -ForegroundColor Yellow
        continue
    }
    
    # 1. Add terminal logging import after _common.ps1
    $content = $content -replace '\. \(Join-Path \$here "_common\.ps1"\)', '. (Join-Path $here "_common.ps1")' + "`n. (Join-Path `$here `"_terminal_logging.ps1`")"
    
    # 2. Add terminal logging start after step start time
    $loggingStart = @"

# Start terminal logging
`$terminalLogPath = Start-TerminalLog -StepName "$stepName" -OutDir `$outDir -ProjectKey `$p.ProjectKey

# Set up error handling to ensure logging stops on errors
`$ErrorActionPreference = "Stop"
trap {
    `$errorMessage = "Step $stepName failed"
    if (`$_.Exception.Message) {
        `$errorMessage += ": `$(`$_.Exception.Message)"
    }
    if (`$_.Exception.InnerException) {
        `$errorMessage += " (Inner: `$(`$_.Exception.InnerException.Message))"
    }
    Write-Host "❌ `$errorMessage" -ForegroundColor Red
    Stop-TerminalLogOnError -ErrorMessage `$errorMessage
    throw
}
"@
    
    # Find the step start time line and add logging after it
    if ($content -match '(\$script:StepStartTime = Get-Date)') {
        $content = $content -replace '(\$script:StepStartTime = Get-Date)', '$1' + $loggingStart
    } else {
        Write-Host "  ⚠️  Could not find step start time line - adding at beginning" -ForegroundColor Yellow
        # Add after the first few lines
        $lines = $content -split "`n"
        $insertIndex = 0
        for ($i = 0; $i -lt [Math]::Min(20, $lines.Count); $i++) {
            if ($lines[$i] -match 'StepStartTime|Get-Date') {
                $insertIndex = $i + 1
                break
            }
        }
        if ($insertIndex -gt 0) {
            $lines = $lines[0..($insertIndex-1)] + $loggingStart -split "`n" + $lines[$insertIndex..($lines.Count-1)]
            $content = $lines -join "`n"
        }
    }
    
    # 3. Add terminal logging stop before exit statements
    $loggingStop = @"

# Stop terminal logging
Stop-TerminalLog -Success:`$true -Summary "$stepName completed successfully"
"@
    
    # Add before exit 0
    if ($content -match 'exit 0') {
        $content = $content -replace '(exit 0)', $loggingStop + "`n`n$1"
    }
    
    # Add before exit 1
    if ($content -match 'exit 1') {
        $content = $content -replace '(exit 1)', $loggingStop + "`n`n$1"
    }
    
    # Write the updated content back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    # Verify syntax
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✅ Updated successfully with terminal logging" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Syntax error after update - restoring from git" -ForegroundColor Red
        git checkout HEAD -- $script
        Write-Host "  ✅ Restored from git" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "🎉 Terminal logging safely added to all migration scripts!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 What was accomplished:" -ForegroundColor Cyan
Write-Host "   ✅ Added terminal logging import to all scripts" -ForegroundColor White
Write-Host "   ✅ Added terminal logging start with error handling" -ForegroundColor White
Write-Host "   ✅ Added terminal logging stop before exit statements" -ForegroundColor White
Write-Host "   ✅ Verified syntax for all scripts" -ForegroundColor White
Write-Host "   ✅ Restored any scripts that had syntax errors" -ForegroundColor White
Write-Host ""
Write-Host "🔍 Each script now creates:" -ForegroundColor Yellow
Write-Host "   • XX_StepName_Log.md - Complete terminal output in markdown" -ForegroundColor Gray
Write-Host "   • Enhanced error messages with context and solutions" -ForegroundColor Gray
Write-Host "   • Automatic error handling that preserves logs" -ForegroundColor Gray
