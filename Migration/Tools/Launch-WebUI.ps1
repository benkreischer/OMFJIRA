# Launch-WebUI.ps1 - Launch Web-Based Migration Configuration UI with Live Data
#
# PURPOSE: Starts local web server and opens migration configuration interface
# USAGE: .\Launch-WebUI.ps1
#

$ErrorActionPreference = 'Stop'

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║     OMF JIRA MIGRATION - WEB LAUNCHER                    ║" -ForegroundColor Cyan
Write-Host "║                   WITH LIVE DATA                         ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Check if server script exists
$serverScript = Join-Path $PSScriptRoot "Start-MigrationServer.ps1"
if (-not (Test-Path $serverScript)) {
    Write-Error "Start-MigrationServer.ps1 not found at: $serverScript"
    exit 1
}

Write-Host "🚀 Starting local web server with live Jira data..." -ForegroundColor Cyan
Write-Host ""
Write-Host "The server will:" -ForegroundColor Yellow
Write-Host "  • Fetch real project lists from Jira" -ForegroundColor White
Write-Host "  • Serve the web interface at http://localhost:8765" -ForegroundColor White
Write-Host "  • Auto-open in Chrome" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server when done." -ForegroundColor Yellow
Write-Host ""

Start-Sleep -Seconds 2

# Launch server (this will open the browser automatically)
& $serverScript

