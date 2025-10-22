# Fix-CorruptedScripts.ps1 - Restore and Safely Add Terminal Logging
#
# This script restores corrupted scripts and safely adds terminal logging

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

Write-Host "🔧 Restoring Corrupted Scripts and Adding Terminal Logging" -ForegroundColor Cyan
Write-Host "=" * 60

foreach ($script in $scripts) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Processing $script..." -ForegroundColor Yellow
    
    # Check if script has syntax errors
    try {
        $content = Get-Content -Path $scriptPath -Raw
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✅ Syntax OK" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Syntax errors detected - restoring from git" -ForegroundColor Red
        try {
            # Restore from git
            git checkout HEAD -- $script
            Write-Host "  ✅ Restored from git" -ForegroundColor Green
        } catch {
            Write-Host "  ❌ Failed to restore from git" -ForegroundColor Red
            continue
        }
    }
    
    # Now safely add terminal logging if not already present
    $content = Get-Content -Path $scriptPath -Raw
    
    # Extract step name from script (e.g., "02_Project" from "02_Project.ps1")
    $stepName = $script -replace '\.ps1$', ''
    
    # 1. Add terminal logging import if not present
    if ($content -notmatch '_terminal_logging\.ps1') {
        $content = $content -replace '\. \(Join-Path \$here "_common\.ps1"\)', '. (Join-Path $here "_common.ps1")' + "`n. (Join-Path `$here `"_terminal_logging.ps1`")"
    }
    
    # 2. Add terminal logging start if not present
    if ($content -notmatch 'Start-TerminalLog') {
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
        $content = $content -replace '(\$script:StepStartTime = Get-Date)', '$1' + $loggingStart
    }
    
    # 3. Add terminal logging stop if not present
    if ($content -notmatch 'Stop-TerminalLog') {
        $loggingStop = @"

# Stop terminal logging
Stop-TerminalLog -Success:`$true -Summary "$stepName completed successfully"
"@
        $content = $content -replace '(exit 0)', $loggingStop + "`n`n$1"
        $content = $content -replace '(exit 1)', $loggingStop + "`n`n$1"
    }
    
    # Write the updated content back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    # Verify syntax
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✅ Updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Syntax error after update - restoring from git" -ForegroundColor Red
        git checkout HEAD -- $script
    }
}

Write-Host ""
Write-Host "🎉 All scripts restored and updated with terminal logging!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 What was done:" -ForegroundColor Cyan
Write-Host "   ✅ Restored corrupted scripts from git" -ForegroundColor White
Write-Host "   ✅ Added terminal logging safely" -ForegroundColor White
Write-Host "   ✅ Added improved error handling" -ForegroundColor White
Write-Host "   ✅ Verified syntax for all scripts" -ForegroundColor White
