# Fix-GenericErrorMessages.ps1 - Replace Generic Error Messages with Helpful Ones
#
# This script finds and replaces generic error messages with more informative ones

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

Write-Host "🔧 Fixing Generic Error Messages in All Migration Scripts" -ForegroundColor Cyan
Write-Host "=" * 60

foreach ($script in $scripts) {
    $scriptPath = Join-Path $here $script
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Script not found: $script"
        continue
    }
    
    Write-Host "Fixing $script..." -ForegroundColor Yellow
    
    # Read the script content
    $content = Get-Content -Path $scriptPath -Raw
    
    # Replace generic error messages with more helpful ones
    
    # 1. Generic "FAILED: Response status code" messages
    $content = $content -replace 'Write-Warning \("  FAILED: \{0\}" -f \$errorMsg\)', @'
            # Enhanced error reporting
            Write-Host "  ❌ FAILED: Operation failed" -ForegroundColor Red
            Write-Host "     Error: $errorMsg" -ForegroundColor Yellow
            Write-Host "     💡 Check API permissions and target environment" -ForegroundColor Cyan
'@
    
    # 2. Generic "FAILED: {0}" messages  
    $content = $content -replace 'Write-Warning \("  FAILED: \{0\}" -f \$gres\.msg\)', @'
            # Enhanced error reporting for groups
            Write-Host "  ❌ FAILED: Adding group to role" -ForegroundColor Red
            Write-Host "     Error: $gres.msg" -ForegroundColor Yellow
            Write-Host "     💡 Check group exists and has proper permissions" -ForegroundColor Cyan
'@
    
    # 3. Generic "Unknown error" messages
    $content = $content -replace '"Unknown error"', '"No specific error details available"'
    
    # 4. Generic warning messages
    $content = $content -replace 'Write-Warning \("User \{0\} not found in target"', 'Write-Host "  ⚠️  User {0} not found in target" -ForegroundColor Yellow'
    
    # 5. Generic "FAILED" without context
    $content = $content -replace 'Write-Warning \("FAILED: \{0\}"', 'Write-Host "  ❌ FAILED: {0}" -ForegroundColor Red'
    
    # Write the updated content back
    $content | Out-File -FilePath $scriptPath -Encoding UTF8
    
    Write-Host "✅ Updated $script" -ForegroundColor Green
}

Write-Host ""
Write-Host "🎉 All generic error messages replaced with helpful ones!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Improvements Applied:" -ForegroundColor Cyan
Write-Host "   ✅ Clear error descriptions with context" -ForegroundColor White
Write-Host "   ✅ Color-coded error messages" -ForegroundColor White
Write-Host "   ✅ Specific solutions for common issues" -ForegroundColor White
Write-Host "   ✅ Better user guidance" -ForegroundColor White
Write-Host ""
Write-Host "🔍 Error messages now provide:" -ForegroundColor Yellow
Write-Host "   • What operation failed" -ForegroundColor Gray
Write-Host "   • Why it failed" -ForegroundColor Gray
Write-Host "   • How to fix it" -ForegroundColor Gray
Write-Host "   • Visual indicators (❌ ⚠️ 💡)" -ForegroundColor Gray
