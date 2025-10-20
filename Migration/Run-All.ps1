#requires -Version 5.1
# Run-All.ps1 - Automated Migration with Live HTML Dashboard
#
# PURPOSE: Run all 16 migration steps sequentially with a live progress dashboard
# USAGE: .\Run-All.ps1 -Project DEP
#
param(
    [Parameter(Mandatory=$true)]
    [string]$Project
)

$ErrorActionPreference = "Continue"  # Continue on errors to complete dashboard

$script:RunnerRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:StepsRoot  = Join-Path $RunnerRoot ""

# Load shared dashboard functions and logging
. (Join-Path $RunnerRoot "_dashboard.ps1")
. (Join-Path $RunnerRoot "_logging.ps1")

# Load project configuration
$projectPath = Join-Path $RunnerRoot "projects\$Project"
$parametersPath = Join-Path $projectPath "parameters.json"

if (-not (Test-Path $parametersPath)) {
    Write-Error "Project not found: $Project"
    Write-Error "Parameters file missing: $parametersPath"
    exit 1
}

# Map step numbers to script names
$steps = [ordered]@{
    "01" = @{ Name = "Preflight Validation"; Script = "01_Preflight.ps1" }
    "02" = @{ Name = "Create Target Project"; Script = "02_Project.ps1" }
    "03" = @{ Name = "Migrate Users and Roles"; Script = "03_Users.ps1" }
    "04" = @{ Name = "Components and Labels"; Script = "04_Components.ps1" }
    "05" = @{ Name = "Versions"; Script = "05_Versions.ps1" }
    "06" = @{ Name = "Boards"; Script = "06_Boards.ps1" }
    "07" = @{ Name = "Export Issues from Source"; Script = "07_Export.ps1" }
    "08" = @{ Name = "Create Issues in Target"; Script = "08_Import.ps1" }
    "09" = @{ Name = "Migrate Attachments"; Script = "09_Attachments.ps1" }
    "10" = @{ Name = "Migrate Comments"; Script = "10_Comments.ps1" }
    "11" = @{ Name = "Migrate Links"; Script = "11_Links.ps1" }
    "12" = @{ Name = "Migrate Worklogs"; Script = "12_Worklogs.ps1" }
    "13" = @{ Name = "Migrate Sprints"; Script = "13_Sprints.ps1" }
    "14" = @{ Name = "History Migration"; Script = "14_History.ps1" }
    "15" = @{ Name = "Review Migration"; Script = "15_Review.ps1" }
    "16" = @{ Name = "Push to Confluence"; Script = "16_Confluence.ps1" }
}

# Compute total steps dynamically for messaging and dashboard
$totalSteps = if ($steps -and $steps.Keys) { $steps.Keys.Count } else { 0 }

# HTML Dashboard Path
$dashboardPath = Join-Path $projectPath "out\migration_progress.html"
$logDir = Join-Path $projectPath "out\logs"

# Create output directories
$outDirPath = Join-Path $projectPath "out"
if (-not (Test-Path $outDirPath)) {
    New-Item -ItemType Directory -Path $outDirPath -Force | Out-Null
    Write-Host "Created output directory: $outDirPath" -ForegroundColor Green
}

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Write-Host "Created logs directory: $logDir" -ForegroundColor Green
}

# Initialize logging for auto-run
$outDir = Join-Path $projectPath "out"
$logFile = Initialize-MigrationLog -ProjectKey $Project -OutDir $outDir -Operation "AutoRun"

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          AUTO-RUN MIGRATION - $Project                       ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will run all $totalSteps migration steps automatically." -ForegroundColor Yellow
Write-Host "Progress dashboard: $dashboardPath" -ForegroundColor Cyan
Write-Host "Log file: $logFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 To monitor in another terminal:" -ForegroundColor Yellow
Write-Host "   .\Watch-Log.ps1 -ProjectKey $Project" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Starting migration automatically..." -ForegroundColor Green

Write-LogStep "Auto-Run Migration Started"
Write-LogInfo "Project: $Project" -Component "AutoRun"
Write-LogInfo "Total steps to run: $totalSteps" -Component "AutoRun"

# Initialize dashboard (using unified dashboard from _dashboard.ps1)
Update-UnifiedDashboard -ProjectKey $Project -ProjectName $Project -DashboardPath $dashboardPath -OutDir (Join-Path $projectPath "out") -Mode "Auto-Run"

# OLD DASHBOARD FUNCTIONS REMOVED - ALL CODE BELOW IS LEGACY AND WILL BE REMOVED
# ============================================================================
function New-Dashboard-OLD {
    param($ProjectName)
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="5">
    <title>Migration Progress - $ProjectName</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2em; margin-bottom: 10px; }
        .header p { opacity: 0.9; font-size: 1.1em; }
        .progress-bar {
            height: 8px;
            background: rgba(255,255,255,0.3);
            margin: 20px 30px;
            border-radius: 4px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: #10b981;
            transition: width 0.5s ease;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            padding: 20px 30px;
            background: #f9fafb;
            border-bottom: 1px solid #e5e7eb;
        }
        .stat { text-align: center; }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #6b7280;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .steps {
            padding: 30px;
        }
        .step {
            background: #f9fafb;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            margin-bottom: 15px;
            overflow: hidden;
            transition: all 0.3s ease;
        }
        .step.completed { border-color: #10b981; }
        .step.running { border-color: #3b82f6; animation: pulse 2s infinite; }
        .step.failed { border-color: #ef4444; }
        @keyframes pulse {
            0%, 100% { box-shadow: 0 0 0 0 rgba(59, 130, 246, 0.4); }
            50% { box-shadow: 0 0 0 8px rgba(59, 130, 246, 0); }
        }
        .step-header {
            padding: 20px;
            display: flex;
            align-items: center;
            cursor: pointer;
            user-select: none;
        }
        .step-header:hover { background: #f3f4f6; }
        .checkbox {
            width: 24px;
            height: 24px;
            border: 2px solid #d1d5db;
            border-radius: 4px;
            margin-right: 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }
        .step.completed .checkbox {
            background: #10b981;
            border-color: #10b981;
        }
        .step.running .checkbox {
            background: #3b82f6;
            border-color: #3b82f6;
        }
        .step.failed .checkbox {
            background: #ef4444;
            border-color: #ef4444;
        }
        .checkbox::after {
            content: '✓';
            color: white;
            font-weight: bold;
            display: none;
        }
        .step.completed .checkbox::after { display: block; }
        .step.running .checkbox::after {
            content: '⟳';
            display: block;
            animation: spin 1s linear infinite;
        }
        .step.failed .checkbox::after {
            content: '✗';
            display: block;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .step-title {
            flex: 1;
            font-weight: 600;
            color: #1f2937;
        }
        .step-number {
            color: #667eea;
            font-weight: bold;
            margin-right: 10px;
        }
        .step-status {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .status-pending { background: #e5e7eb; color: #6b7280; }
        .status-running { background: #dbeafe; color: #1e40af; }
        .status-completed { background: #d1fae5; color: #065f46; }
        .status-failed { background: #fee2e2; color: #991b1b; }
        .step-details {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease;
        }
        .step.expanded .step-details {
            max-height: 2000px;
        }
        .step-output {
            padding: 20px;
            background: #1f2937;
            color: #e5e7eb;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
            line-height: 1.6;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 400px;
            overflow-y: auto;
        }
        .expand-icon {
            margin-left: 10px;
            color: #9ca3af;
            transition: transform 0.3s ease;
        }
        .step.expanded .expand-icon {
            transform: rotate(180deg);
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #6b7280;
            border-top: 1px solid #e5e7eb;
        }
        .auto-refresh {
            color: #10b981;
            font-weight: 600;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 Migration Progress</h1>
            <p>Project: $ProjectName</p>
        </div>
        <div class="progress-bar">
            <div class="progress-fill" id="progressFill" style="width: 0%"></div>
        </div>
        <div class="stats">
            <div class="stat">
                <div class="stat-value" id="completedCount">0</div>
                <div class="stat-label">Completed</div>
            </div>
            <div class="stat">
                <div class="stat-value" id="runningCount">0</div>
                <div class="stat-label">Running</div>
            </div>
            <div class="stat">
                        <div class="stat-value" id="pendingCount">$totalSteps</div>
                        <div class="stat-label">Pending</div>
                    </div>
            <div class="stat">
                <div class="stat-value" id="failedCount">0</div>
                <div class="stat-label">Failed</div>
            </div>
        </div>
        <div class="steps" id="stepsList">
            <!-- Steps will be inserted here -->
        </div>
        <div class="footer">
            <p><span class="auto-refresh">●</span> Auto-refreshing every 5 seconds</p>
            <p style="margin-top: 10px; font-size: 0.9em;">Last updated: <span id="lastUpdate">--</span></p>
        </div>
    </div>
    <script>
        document.addEventListener('DOMContentLoaded', () => {
            document.querySelectorAll('.step-header').forEach(header => {
                header.addEventListener('click', () => {
                    header.parentElement.classList.toggle('expanded');
                });
            });
            
            document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
        });
    </script>
</body>
</html>
"@
    
    return $html
}

# Update step in dashboard
function Update-Dashboard {
    param(
        $StepNumber,
        $Status,  # pending, running, completed, failed
        $Output = ""
    )
    
    # Read current dashboard or create new
    if (Test-Path $dashboardPath) {
        $html = Get-Content $dashboardPath -Raw
    } else {
        $html = New-Dashboard -ProjectName $Project
    }
    
    # Count stats
    $completed = 0
    $running = 0
    $failed = 0
    $pending = $totalSteps
    
    foreach ($num in $steps.Keys) {
        $stepClass = "pending"
        $stepStatus = "Pending"
        $statusClass = "status-pending"
        
        if ($num -eq $StepNumber) {
            if ($Status -eq "running") {
                $stepClass = "running"
                $stepStatus = "Running..."
                $statusClass = "status-running"
                $running++
                $pending--
            } elseif ($Status -eq "completed") {
                $stepClass = "completed"
                $stepStatus = "Completed"
                $statusClass = "status-completed"
                $completed++
                $pending--
            } elseif ($Status -eq "failed") {
                $stepClass = "failed"
                $stepStatus = "Failed"
                $statusClass = "status-failed"
                $failed++
                $pending--
            }
        } elseif ([int]$num -lt [int]$StepNumber) {
            # Previous steps assumed completed
            $stepClass = "completed"
            $stepStatus = "Completed"
            $statusClass = "status-completed"
            if ($Status -ne "running") {
                $completed++
                $pending--
            }
        }
        
        $outputHtml = if ($num -eq $StepNumber -and $Output) {
            "<div class=`"step-details`"><div class=`"step-output`">$([System.Web.HttpUtility]::HtmlEncode($Output))</div></div>"
        } else { "" }
        
        $stepHtml += @"
            <div class="step $stepClass">
                <div class="step-header">
                    <div class="checkbox"></div>
                    <span class="step-number">Step $num</span>
                    <span class="step-title">$($steps[$num].Name)</span>
                    <span class="step-status $statusClass">$stepStatus</span>
                    <span class="expand-icon">▼</span>
                </div>
                $outputHtml
            </div>
"@
    }
    
    $progress = if ($totalSteps -gt 0) { [math]::Round(($completed / $totalSteps) * 100) } else { 0 }
    
    # Replace placeholders
    $html = $html -replace '<div class="steps" id="stepsList">[\s\S]*?</div>\s*<div class="footer">', @"
<div class="steps" id="stepsList">
$stepHtml
        </div>
        <div class="footer">
"@
    
    $html = $html -replace 'id="progressFill" style="width: \d+%"', "id=`"progressFill`" style=`"width: $progress%`""
    $html = $html -replace '<div class="stat-value" id="completedCount">\d+</div>', "<div class=`"stat-value`" id=`"completedCount`">$completed</div>"
    $html = $html -replace '<div class="stat-value" id="runningCount">\d+</div>', "<div class=`"stat-value`" id=`"runningCount`">$running</div>"
    $html = $html -replace '<div class="stat-value" id="pendingCount">\d+</div>', "<div class=`"stat-value`" id=`"pendingCount`">$pending</div>"
    $html = $html -replace '<div class="stat-value" id="failedCount">\d+</div>', "<div class=`"stat-value`" id=`"failedCount`">$failed</div>"
    
    $html | Out-File -FilePath $dashboardPath -Encoding UTF8 -Force
}

# Open dashboard in browser
Write-Host "Opening progress dashboard..." -ForegroundColor Cyan
Start-Process $dashboardPath

Write-Host ""
Write-Host "Starting migration..." -ForegroundColor Green
Write-Host ""

# Run each step
foreach ($stepNum in $steps.Keys) {
    $step = $steps[$stepNum]
    $scriptPath = Join-Path $StepsRoot $step['Script']
    
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Step not found: $($step['Script'])"
        continue
    }
    
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  STEP ${stepNum}: $($step['Name'])" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Log step start
    Write-LogStep "Step ${stepNum}: $($step['Name'])"
    Write-LogInfo "Executing: $($step['Script'])" -Component "AutoRun"
    
    # Update dashboard - step starting (no "running" state in unified dashboard, it just shows completed/pending)
    
    # Execute step and capture output
    $logFile = Join-Path $logDir "step_$stepNum.log"
    $output = ""
    
    # Ensure log directory exists before writing
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Write-Host "Created logs directory: $logDir" -ForegroundColor Yellow
    }
    
    try {
        & $scriptPath -ParametersPath $parametersPath 2>&1 | Tee-Object -Variable output | Out-Host
        $exitCode = $LASTEXITCODE
        
        # Save log
        $output | Out-File -FilePath $logFile -Encoding UTF8
        
        if ($exitCode -eq 0 -or $null -eq $exitCode) {
            Write-Host ""
            Write-Host "✅ Step $stepNum completed successfully!" -ForegroundColor Green
            Write-LogSuccess "Step $stepNum completed successfully" -Component "AutoRun"
            # Update dashboard - it will automatically detect the new receipt file
            Update-UnifiedDashboard -ProjectKey $Project -ProjectName $Project -DashboardPath $dashboardPath -OutDir (Join-Path $projectPath "out") -Mode "Auto-Run"
        } else {
            Write-Host ""
            Write-Host "❌ Step $stepNum failed with exit code: $exitCode" -ForegroundColor Red
            Write-LogError "Step $stepNum failed with exit code: $exitCode" -Component "AutoRun"
            # Update dashboard to show current state
            Update-UnifiedDashboard -ProjectKey $Project -ProjectName $Project -DashboardPath $dashboardPath -OutDir (Join-Path $projectPath "out") -Mode "Auto-Run"
        }
    } catch {
        Write-Host ""
        Write-Host "❌ Step $stepNum failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-LogError "Step $stepNum failed" -ErrorRecord $_ -Component "AutoRun"
        $errorOutput = $output -join "`n" + "`n`nERROR: $($_.Exception.Message)"
        # Update dashboard to show current state
        Update-UnifiedDashboard -ProjectKey $Project -ProjectName $Project -DashboardPath $dashboardPath -OutDir (Join-Path $projectPath "out") -Mode "Auto-Run"
    }
    
    Write-Host ""
    Start-Sleep -Seconds 2
}

Write-Host ""

# Complete the log
Complete-MigrationLog -Success:$true -Summary "Auto-run migration completed. All $totalSteps steps have been executed. Check dashboard for detailed results."

Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          MIGRATION COMPLETE!                                 ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Dashboard: $dashboardPath" -ForegroundColor Cyan
Write-Host "Logs: $logDir" -ForegroundColor Cyan
Write-Host "Migration Log: $env:MIGRATION_LOG_FILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
