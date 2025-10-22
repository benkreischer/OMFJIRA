# Add-TerminalLoggingManually.ps1 - Manually Add Terminal Logging to Key Scripts
#
# This script manually adds terminal logging to specific scripts one by one

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "🔧 Manually Adding Terminal Logging to Key Scripts" -ForegroundColor Cyan
Write-Host "=" * 50

# Scripts to update (excluding 01, 02, 03 which are already done)
$scriptsToUpdate = @(
    "04_Components.ps1",
    "05_Versions.ps1", 
    "06_Boards.ps1",
    "07_Export.ps1"
)

foreach ($script in $scriptsToUpdate) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Processing $script..." -ForegroundColor Yellow
    
    # Extract step name
    $stepName = $script -replace '\.ps1$', ''
    
    # Read content
    $content = Get-Content -Path $scriptPath -Raw
    
    # Check if already has terminal logging
    if ($content -match '_terminal_logging\.ps1') {
        Write-Host "  ✅ Already has terminal logging" -ForegroundColor Green
        continue
    }
    
    # 1. Add import after _common.ps1
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
    
    # Add after step start time
    if ($content -match '(\$script:StepStartTime = Get-Date)') {
        $content = $content -replace '(\$script:StepStartTime = Get-Date)', '$1' + $loggingStart
    }
    
    # 3. Add terminal logging stop before exit
    $loggingStop = @"

# Stop terminal logging
Stop-TerminalLog -Success:`$true -Summary "$stepName completed successfully"
"@
    
    # Add before exit 0
    if ($content -match 'exit 0') {
        $content = $content -replace '(exit 0)', $loggingStop + "`n`n$1"
    }
    
    # Write back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    # Verify syntax
    try {
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✅ Updated successfully" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Syntax error - restoring from git" -ForegroundColor Red
        git checkout HEAD -- $script
    }
}

Write-Host ""
Write-Host "🎉 Terminal logging added to key scripts!" -ForegroundColor Green
