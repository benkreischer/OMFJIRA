# DeleteComponents.ps1 - Delete all components from target project
#
# PURPOSE: Clean up components from target project (useful for testing/troubleshooting)
#
# USAGE:
#   .\DeleteComponents.ps1 -Project LAS    # Delete from LAS target
#   .\DeleteComponents.ps1 -ParametersPath "path\to\parameters.json"
#
param(
    [string]$Project,
    [string]$ParametersPath
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "║           DELETE ALL TARGET COMPONENTS                    ║" -ForegroundColor Red
Write-Host "║                  ⚠️  WARNING  ⚠️                          ║" -ForegroundColor Red
Write-Host "║                                                           ║" -ForegroundColor Red
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
Write-Host ""

# Load common functions
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "src\_common.ps1")

# Determine parameters file
if (-not $ParametersPath -and $Project) {
    $projectsDir = Join-Path $here "projects"
    $ParametersPath = Join-Path $projectsDir "$Project\parameters.json"
}

if (-not $ParametersPath) {
    Write-Host "❌ No parameters file specified" -ForegroundColor Red
    Write-Host "   Usage: .\DeleteComponents.ps1 -Project LAS" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $ParametersPath)) {
    Write-Host "❌ Parameters file not found: $ParametersPath" -ForegroundColor Red
    exit 1
}

Write-Host "Loading parameters from: $ParametersPath" -ForegroundColor Cyan
$p = Read-JsonFile -Path $ParametersPath

# Target environment setup
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host ""
Write-Host "Target Project: $tgtKey" -ForegroundColor Yellow
Write-Host "Target URL: $tgtBase" -ForegroundColor Yellow
Write-Host ""

# Get project details
try {
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Project Name: $($tgtProject.name)" -ForegroundColor Cyan
    Write-Host "Project ID: $($tgtProject.id)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to retrieve target project: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get all components
Write-Host ""
Write-Host "Retrieving components..." -ForegroundColor Cyan
$components = @()
try {
    $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$($tgtProject.id)/components"
    $components = Invoke-RestMethod -Method GET -Uri $uri -Headers $tgtHdr -ErrorAction Stop
    if (-not $components) { $components = @() }
    Write-Host "Found $($components.Count) components" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Failed to retrieve components: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if ($components.Count -eq 0) {
    Write-Host ""
    Write-Host "✅ No components to delete!" -ForegroundColor Green
    exit 0
}

# List components
Write-Host ""
Write-Host "Components to be deleted:" -ForegroundColor Yellow
foreach ($comp in $components) {
    Write-Host "  - $($comp.name) (id: $($comp.id))" -ForegroundColor Gray
}

# Confirmation
Write-Host ""
Write-Host "⚠️  This will DELETE ALL $($components.Count) COMPONENTS from $tgtKey ⚠️" -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type 'DELETE' to confirm (or anything else to cancel)"

if ($confirm -ne "DELETE") {
    Write-Host ""
    Write-Host "❌ Cancelled - no components were deleted" -ForegroundColor Yellow
    exit 0
}

# Delete components
Write-Host ""
Write-Host "=== DELETING COMPONENTS ===" -ForegroundColor Red
$deleted = 0
$failed = 0
$errors = @()

foreach ($comp in $components) {
    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/component/$($comp.id)"
        Invoke-RestMethod -Method DELETE -Uri $uri -Headers $tgtHdr -ErrorAction Stop | Out-Null
        Write-Host "  ✅ Deleted: $($comp.name)" -ForegroundColor Green
        $deleted++
    } catch {
        $msg = $_.Exception.Message
        Write-Host "  ❌ Failed: $($comp.name) - $msg" -ForegroundColor Red
        $failed++
        $errors += @{
            Name = $comp.name
            Id = $comp.id
            Error = $msg
        }
    }
}

# Summary
Write-Host ""
Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total components: $($components.Count)"
Write-Host "Deleted: $deleted" -ForegroundColor Green
Write-Host "Failed: $failed" -ForegroundColor $(if ($failed -gt 0) { "Red" } else { "Gray" })

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "Errors:" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "  - $($err.Name): $($err.Error)"
    }
}

Write-Host ""
if ($deleted -eq $components.Count) {
    Write-Host "✅ All components deleted successfully!" -ForegroundColor Green
} elseif ($deleted -gt 0) {
    Write-Host "⚠️  Partial success - some components could not be deleted" -ForegroundColor Yellow
} else {
    Write-Host "❌ No components were deleted" -ForegroundColor Red
}

exit $(if ($failed -eq 0) { 0 } else { 1 })

