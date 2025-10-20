# RunMigration.ps1 - Multi-Project Migration Launcher
#
# PURPOSE: Simplified launcher for running migration steps across multiple projects.
# Automatically detects available projects and loads correct configuration.
#
# USAGE:
#   .\RunMigration.ps1                    # Interactive project selection
#   .\RunMigration.ps1 -Project LAS       # Specific project
#   .\RunMigration.ps1 -Project LAS -Step 08  # Run specific step
#   .\RunMigration.ps1 -Project LAS -DryRun   # Dry run validation
#
param(
    [string]$Project,          # Project key (DEP, LAS, etc.)
    [string]$Step,             # Step number (01-18) or name
    [switch]$DryRun,           # Run dry run validation
    [switch]$ListProjects,     # List available projects
    [switch]$AutoRun,          # Run all steps automatically with HTML dashboard
    [switch]$Interactive       # Interactive mode with auto-relaunch (default)
)

$ErrorActionPreference = "Stop"

# Load shared dashboard functions and logging
. (Join-Path $PSScriptRoot "_dashboard.ps1")
. (Join-Path $PSScriptRoot "_logging.ps1")

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                JIRA MIGRATION TOOLKIT                      ║" -ForegroundColor Cyan
Write-Host "║                   Project Launcher                        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Discover available projects
$projectsDir = Join-Path $PSScriptRoot "projects"
if (-not (Test-Path $projectsDir)) {
    Write-Host "❌ Projects directory not found: $projectsDir" -ForegroundColor Red
    Write-Host "   Run from the Migration root directory" -ForegroundColor Yellow
    exit 1
}

$availableProjects = @()
Get-ChildItem $projectsDir -Directory | ForEach-Object {
    $paramFile = Join-Path $_.FullName "parameters.json"
    if (Test-Path $paramFile) {
        try {
            $params = Get-Content $paramFile -Raw | ConvertFrom-Json
            $projName = $_.Name
            $friendlyName = $projName
            $sourceKey = "Unknown"
            $targetKey = "Unknown"
            
            if ($params.PSObject.Properties.Name -contains 'ProjectName') {
                $friendlyName = $params.ProjectName
            }
            if ($params.PSObject.Properties.Name -contains 'SourceEnvironment' -and 
                $params.SourceEnvironment.PSObject.Properties.Name -contains 'ProjectKey') {
                $sourceKey = $params.SourceEnvironment.ProjectKey
            }
            if ($params.PSObject.Properties.Name -contains 'TargetEnvironment' -and 
                $params.TargetEnvironment.PSObject.Properties.Name -contains 'ProjectKey') {
                $targetKey = $params.TargetEnvironment.ProjectKey
            }
            
            $availableProjects += [PSCustomObject]@{
                Key = $projName
                Name = $friendlyName
                SourceProject = $sourceKey
                TargetProject = $targetKey
                ParametersFile = $paramFile
            }
        } catch {
            Write-Warning "Failed to load parameters for $($_.Name): $($_.Exception.Message)"
        }
    }
}

if ($availableProjects.Count -eq 0) {
    Write-Host "❌ No projects found in: $projectsDir" -ForegroundColor Red
    Write-Host "   Create a project folder with parameters.json" -ForegroundColor Yellow
    exit 1
}

# List projects if requested
if ($ListProjects) {
    Write-Host "Available Projects:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($proj in $availableProjects) {
        Write-Host "  📁 $($proj.Key)" -ForegroundColor Yellow
        Write-Host "     Name: $($proj.Name)"
        Write-Host "     Source: $($proj.SourceProject) → Target: $($proj.TargetProject)"
        Write-Host "     Config: $($proj.ParametersFile)"
        Write-Host ""
    }
    exit 0
}

# Select project
if (-not $Project) {
    if ($availableProjects.Count -eq 1) {
        $Project = $availableProjects[0].Key
        Write-Host "Auto-selected only project: $Project" -ForegroundColor Cyan
    } else {
        Write-Host "Available Projects:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $availableProjects.Count; $i++) {
            $proj = $availableProjects[$i]
            Write-Host "  [$($i+1)] $($proj.Key) - $($proj.Name) ($($proj.SourceProject) → $($proj.TargetProject))"
        }
        Write-Host ""
        $selection = Read-Host "Select project (1-$($availableProjects.Count))"
        $Project = $availableProjects[$selection - 1].Key
    }
}

# Validate project
$selectedProject = $availableProjects | Where-Object { $_.Key -eq $Project }
if (-not $selectedProject) {
    Write-Host "❌ Project not found: $Project" -ForegroundColor Red
    Write-Host "   Available projects: $($availableProjects.Key -join ', ')" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Selected Project: $Project" -ForegroundColor Green

# Load parameters to show source/target URLs
try {
    $params = Get-Content $selectedProject.ParametersFile -Raw | ConvertFrom-Json
    Write-Host "  Name: $($selectedProject.Name)"
    Write-Host ""
    Write-Host "  🔵 Source: $($params.SourceEnvironment.BaseUrl)" -ForegroundColor Cyan
    Write-Host "     Project: $($selectedProject.SourceProject)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  🟢 Target: $($params.TargetEnvironment.BaseUrl)" -ForegroundColor Green
    Write-Host "     Project: $($selectedProject.TargetProject)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  📁 Config: $($selectedProject.ParametersFile)" -ForegroundColor Gray
} catch {
    Write-Host "  Name: $($selectedProject.Name)"
    Write-Host "  Source: $($selectedProject.SourceProject)"
    Write-Host "  Target: $($selectedProject.TargetProject)"
    Write-Host "  Parameters: $($selectedProject.ParametersFile)"
}
Write-Host ""

# Get output directory for the selected project
$projectOutDir = Join-Path (Split-Path $selectedProject.ParametersFile -Parent) "out"
$dashboardPath = Join-Path $projectOutDir "migration_progress.html"

# Initialize or continue logging (check if log already exists from previous steps)
if (-not $env:MIGRATION_LOG_FILE -or -not (Test-Path $env:MIGRATION_LOG_FILE)) {
    $logFile = Initialize-MigrationLog -ProjectKey $Project -OutDir $projectOutDir -Operation "Migration"
    Write-Host "📊 Log file: $logFile" -ForegroundColor Cyan
    Write-Host "💡 To monitor: .\Watch-Log.ps1 -ProjectKey $Project" -ForegroundColor Yellow
    Write-Host ""
    Write-LogStep "Migration Started: $Project"
    Write-LogInfo "Project: $($selectedProject.Name)" -Component "Setup"
    Write-LogInfo "Source: $($selectedProject.SourceProject) → Target: $($selectedProject.TargetProject)" -Component "Setup"
} else {
    # Continue existing log
    Initialize-MigrationLog -ProjectKey $Project -OutDir $projectOutDir -ContinueExisting
}

# Use shared migration steps from _dashboard.ps1
$allSteps = $script:AllMigrationSteps
# Compute total steps dynamically so messages stay accurate if steps change
$totalSteps = if ($allSteps -and $allSteps.Keys) { $allSteps.Keys.Count } else { 0 }

# Run dry run if requested
if ($DryRun) {
    Write-Host "Running dry run validation..." -ForegroundColor Cyan
    $dryRunScript = Join-Path $PSScriptRoot "src\DryRun_Master.ps1"
    & $dryRunScript -ParametersPath $selectedProject.ParametersFile
    exit $LASTEXITCODE
}

# If AutoRun mode, run all steps with HTML dashboard
if ($AutoRun) {
    $autoRunScript = Join-Path $PSScriptRoot "Run-All.ps1"
    & $autoRunScript -Project $Project
    exit $LASTEXITCODE
}

# If no step specified, show menu
if (-not $Step) {
    # If already in Interactive mode (relaunched), skip mode selection
    if (-not $Interactive) {
        Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "  MIGRATION MODE SELECTION" -ForegroundColor Cyan
        Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  [I] Interactive Mode (Step by Step)" -ForegroundColor Yellow
        Write-Host "  [A] Auto-Run Mode (Run All Steps)" -ForegroundColor Yellow
        Write-Host "  [D] Dry Run (Validation Only)" -ForegroundColor Yellow
        Write-Host "  [Q] Quit" -ForegroundColor Yellow
        Write-Host ""
        $mode = Read-Host "Select mode"
        
        if ($mode -eq "Q" -or $mode -eq "q") {
            exit 0
        }
        if ($mode -eq "D" -or $mode -eq "d") {
            $dryRunScript = Join-Path $PSScriptRoot "src\DryRun_Master.ps1"
            & $dryRunScript -ParametersPath $selectedProject.ParametersFile
            exit $LASTEXITCODE
        }
        if ($mode -eq "A" -or $mode -eq "a") {
            $autoRunScript = Join-Path $PSScriptRoot "Run-All.ps1"
            & $autoRunScript -Project $Project
            exit $LASTEXITCODE
        }
        
        # User selected Interactive mode, set flag
        $Interactive = $true
    }
    
    # Interactive mode - show step menu
    Clear-Host
    
    # Update dashboard before showing menu
    try {
        Update-UnifiedDashboard -ProjectKey $Project -ProjectName $selectedProject.Name -DashboardPath $dashboardPath -OutDir $projectOutDir -Mode "Interactive"
        
        # Check if this is the first run (no completed steps) and dashboard was just created
        $completedSteps = Get-ChildItem -Path $projectOutDir -Filter "*_receipt.json" -ErrorAction SilentlyContinue
        if (-not $completedSteps -and (Test-Path $dashboardPath)) {
            Write-Host "📊 Created progress dashboard: $dashboardPath" -ForegroundColor Cyan
            Write-Host "   Opening in browser..." -ForegroundColor Cyan
            Start-Process $dashboardPath
            Start-Sleep -Seconds 2
            Clear-Host
        }
    } catch {
        # Silently continue if dashboard update fails
    }
    
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║              INTERACTIVE MIGRATION - $Project" -ForegroundColor Cyan
    $padding = " " * (42 - $Project.Length)
    Write-Host "║              INTERACTIVE MIGRATION - $Project$padding║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "ℹ️  All steps are IDEMPOTENT - safe to re-run multiple times" -ForegroundColor Cyan
    Write-Host ""
    
    # Calculate and show progress
    $completedCount = 0
    foreach ($stepNum in $allSteps.Keys) {
        if ((Get-StepStatus -StepNumber $stepNum -OutDir $projectOutDir) -eq "completed") {
            $completedCount++
        }
    }
    $progressPercent = if ($totalSteps -gt 0) { [math]::Round(($completedCount / $totalSteps) * 100) } else { 0 }
    Write-Host "Progress: $completedCount/$totalSteps steps completed ($progressPercent%)" -ForegroundColor Cyan
    
    # Show dashboard link if it exists
    if (Test-Path $dashboardPath) {
        Write-Host "Dashboard: $dashboardPath" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Migration Steps:" -ForegroundColor Yellow
    Write-Host ""
    
    # Display steps with completion status
    foreach ($stepNum in $allSteps.Keys) {
        $stepName = $allSteps[$stepNum]
        $status = Get-StepStatus -StepNumber $stepNum -OutDir $projectOutDir
        $checkmark = if ($status -eq "completed") { " ✓" } else { "" }
        $color = if ($status -eq "completed") { "Green" } else { "White" }
        
        Write-Host "  [$stepNum] $stepName$checkmark" -ForegroundColor $color
    }
    Write-Host ""
    Write-Host "  [Q] Quit" -ForegroundColor Yellow
    Write-Host ""
    $Step = Read-Host "Select step (or Q to quit)"
    
    if ($Step -eq "Q" -or $Step -eq "q") {
        exit 0
    }
    
}

# Normalize step number (remove leading zeros, convert to 2-digit)
$Step = $Step.Trim()
if ($Step -match '^\d+$') {
    $Step = $Step.PadLeft(2, '0')
}

# Map step number to script name
$stepScripts = @{
    "01" = "01_Preflight.ps1"
    "02" = "02_Project.ps1"
    "03" = "03_Users.ps1"
    "04" = "04_Components.ps1"
    "05" = "05_Versions.ps1"
    "06" = "06_Boards.ps1"
    "07" = "07_Export.ps1"
    "08" = "08_Import.ps1"
    "09" = "09_Comments.ps1"
    "10" = "10_Attachments.ps1"
    "11" = "11_Links.ps1"
    "12" = "12_Worklogs.ps1"
    "13" = "13_Sprints.ps1"
    "14" = "14_History.ps1"
    "15" = "15_Review.ps1"
    "16" = "16_Confluence.ps1"
}

if (-not $stepScripts.ContainsKey($Step)) {
    Write-Host "❌ Invalid step: $Step" -ForegroundColor Red
    Write-Host "   Valid steps: 01-16" -ForegroundColor Yellow
    exit 1
}

$scriptName = $stepScripts[$Step]
$scriptPath = Join-Path $PSScriptRoot $scriptName

if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Executing: Step $Step - $scriptName" -ForegroundColor Yellow
Write-Host "Project: $Project ($($selectedProject.Name))" -ForegroundColor Cyan
Write-Host "Parameters: $($selectedProject.ParametersFile)" -ForegroundColor Gray
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# Log step execution
$stepName = if ($allSteps.Contains($Step)) { $allSteps[$Step] } else { $scriptName }
Write-LogStep "Step ${Step}: $stepName"
Write-LogInfo "Executing: $scriptPath" -Component "Runner"

# Execute the script with project-specific parameters
try {
    & $scriptPath -ParametersPath $selectedProject.ParametersFile
    $exitCode = if ($LASTEXITCODE) { $LASTEXITCODE } else { 0 }
} catch {
    $exitCode = 1
    Write-LogError "Step execution failed" -ErrorRecord $_ -Component "Runner"
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

if ($exitCode -eq 0) {
    Write-Host "✅ Step $Step completed successfully!" -ForegroundColor Green
    Write-LogSuccess "Step $Step completed successfully" -Component "Runner"
} else {
    Write-Host "❌ Step $Step failed with exit code: $exitCode" -ForegroundColor Red
    Write-LogError "Step $Step failed with exit code: $exitCode" -Component "Runner"
}

Write-Host ""
Write-Host "Project folder: .\projects\$Project\" -ForegroundColor Cyan
Write-Host "Outputs: .\projects\$Project\out\" -ForegroundColor Cyan

# Update dashboard after step completion (if in interactive mode)
if ($PSBoundParameters.ContainsKey('Interactive') -or (-not $PSBoundParameters.ContainsKey('Step'))) {
    try {
        Write-Host "📊 Updating progress dashboard..." -ForegroundColor Cyan
        Update-UnifiedDashboard -ProjectKey $Project -ProjectName $selectedProject.Name -DashboardPath $dashboardPath -OutDir $projectOutDir -Mode "Interactive"
        if (Test-Path $dashboardPath) {
            Write-Host "   Dashboard: $dashboardPath" -ForegroundColor Gray
        }
    } catch {
        # Silently continue if dashboard update fails
    }
}

Write-Host ""

# If in interactive mode (step was selected from menu), relaunch menu
if ($PSBoundParameters.ContainsKey('Interactive') -or (-not $PSBoundParameters.ContainsKey('Step'))) {
    Write-Host ""
    Write-Host "Press any key to return to menu..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Relaunch the script in interactive mode
    & $PSCommandPath -Project $Project -Interactive
    exit 0
}

exit $exitCode

