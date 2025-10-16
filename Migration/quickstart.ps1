<#
Quickstart runner for the Migration toolkit.
Usage: .\quickstart.ps1 -ProjectKey EXAMPLE
This script performs: DryRun -> AutoRun -> QA (Step 16), saves logs and receipts to the project's out/ folder.
#>
param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectKey
)

$projectPath = Join-Path -Path $PSScriptRoot -ChildPath "projects\$ProjectKey"
$outPath = Join-Path -Path $projectPath -ChildPath "out"
if (-not (Test-Path $projectPath)) {
  Write-Error "Project path not found: $projectPath"
  exit 2
}

function Save-Receipt($stage, $content) {
  $receiptFile = Join-Path $outPath "$($stage)-receipt-$(Get-Date -Format yyyyMMdd-HHmmss).json"
  $content | ConvertTo-Json -Depth 6 | Out-File -FilePath $receiptFile -Encoding UTF8
  Write-Host "Saved receipt: $receiptFile"
}

Write-Host "Starting quickstart for project: $ProjectKey"

# 1) DryRun
Write-Host "Running DryRun (validation only)..."
$dryRunOutput = & .\RunMigration.ps1 -Project $ProjectKey -DryRun 2>&1
$dryRunLog = Join-Path $outPath "quickstart-dryrun-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$dryRunOutput | Out-File -FilePath $dryRunLog -Encoding UTF8
Write-Host "DryRun log saved to: $dryRunLog"
Save-Receipt -stage "dryrun" -content @{ project = $ProjectKey; stage = 'dryrun'; log = $dryRunLog; timestamp = (Get-Date).ToString('o') }

# If DryRun returned errors, prompt user
if ($LASTEXITCODE -ne 0) {
  Write-Warning "DryRun indicated errors. Inspect the log before proceeding. Exiting quickstart."
  exit 3
}

# 2) AutoRun
Write-Host "Running full AutoRun migration..."
$autoRunOutput = & .\RunMigration.ps1 -Project $ProjectKey -AutoRun 2>&1
$autoRunLog = Join-Path $outPath "quickstart-autorun-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$autoRunOutput | Out-File -FilePath $autoRunLog -Encoding UTF8
Write-Host "AutoRun log saved to: $autoRunLog"
Save-Receipt -stage "autorun" -content @{ project = $ProjectKey; stage = 'autorun'; log = $autoRunLog; timestamp = (Get-Date).ToString('o') }

# 3) QA (Step 16)
Write-Host "Running QA validation (Step 16)..."
$qaOutput = & .\RunMigration.ps1 -Project $ProjectKey -Step 16 2>&1
$qaLog = Join-Path $outPath "quickstart-qa-$(Get-Date -Format yyyyMMdd-HHmmss).log"
$qaOutput | Out-File -FilePath $qaLog -Encoding UTF8
Write-Host "QA log saved to: $qaLog"
Save-Receipt -stage "qa" -content @{ project = $ProjectKey; stage = 'qa'; log = $qaLog; timestamp = (Get-Date).ToString('o') }

Write-Host "Quickstart finished. Check the project's out/ directory for logs, receipts, and dashboards."