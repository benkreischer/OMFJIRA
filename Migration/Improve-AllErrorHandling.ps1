# Improve-AllErrorHandling.ps1 - Apply Enhanced Error Handling to All Migration Scripts
#
# This script updates all migration scripts with improved error handling

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$scripts = @(
    "01_Preflight.ps1",
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

Write-Host "🔧 Improving Error Handling in All Migration Scripts" -ForegroundColor Cyan
Write-Host "=" * 60

foreach ($script in $scripts) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Updating $script..." -ForegroundColor Yellow
    
    # Read the script content
    $content = Get-Content -Path $scriptPath -Raw
    
    # Extract step name from script (e.g., "02_Project" from "02_Project.ps1")
    $stepName = $script -replace '\.ps1$', ''
    
    # 1. Add improved error handling import after _terminal_logging.ps1
    if ($content -notmatch '_improved_error_handling\.ps1') {
        $content = $content -replace '\. \(Join-Path \$here "_terminal_logging\.ps1"\)', '. (Join-Path $here "_terminal_logging.ps1")' + "`n. (Join-Path `$here `"_improved_error_handling.ps1`")"
    }
    
    # 2. Improve the trap error handling
    $improvedTrap = @"
trap {
    `$errorMessage = "Step $stepName failed"
    if (`$_.Exception.Message) {
        `$errorMessage += ": `$(`$_.Exception.Message)"
    }
    if (`$_.Exception.InnerException) {
        `$errorMessage += " (Inner: `$(`$_.Exception.InnerException.Message))"
    }
    Write-Host "❌ `$errorMessage" -ForegroundColor Red
    
    # Try to provide more specific error information
    if (`$_.Exception.Response) {
        `$statusCode = `$_.Exception.Response.StatusCode.value__
        Write-Host "   HTTP Status: `$statusCode" -ForegroundColor Red
    }
    
    Stop-TerminalLogOnError -ErrorMessage `$errorMessage
    throw
}
"@
    
    # Replace the existing trap with improved version
    $content = $content -replace 'trap \{[^}]+\}', $improvedTrap
    
    # 3. Add better error handling for common API calls
    $content = $content -replace 'Invoke-RestMethod.*-ErrorAction Stop', 'try { Invoke-RestMethod -ErrorAction Stop } catch { Write-APIError -StepName "$stepName" -ApiEndpoint $Uri -StatusCode $_.Exception.Response.StatusCode.value__ -ErrorMessage $_.Exception.Message; throw }'
    
    # Write the updated content back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "✅ Updated $script" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 All migration scripts updated with enhanced error handling!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Improvements Applied:" -ForegroundColor Cyan
Write-Host "   ✅ Enhanced error messages with context" -ForegroundColor White
Write-Host "   ✅ HTTP status code reporting" -ForegroundColor White
Write-Host "   ✅ Inner exception details" -ForegroundColor White
Write-Host "   ✅ API-specific error handling" -ForegroundColor White
Write-Host "   ✅ Better user guidance" -ForegroundColor White
Write-Host ""
Write-Host "🔍 Error handling now provides:" -ForegroundColor Yellow
Write-Host "   • Clear error descriptions" -ForegroundColor Gray
Write-Host "   • HTTP status codes" -ForegroundColor Gray
Write-Host "   • Suggested solutions" -ForegroundColor Gray
Write-Host "   • Context information" -ForegroundColor Gray
Write-Host "   • Better debugging information" -ForegroundColor Gray
