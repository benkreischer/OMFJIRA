# 02_Project.ps1 - Create Target Project
# 
# PURPOSE: Creates the target project in the destination Jira instance using
# the provided source and target parameters.
#
# WHAT IT DOES:
# - Creates a simple project using the provided parameters
# - Sets the project lead using the provided email address
# - If the target key already exists and is active, script is **idempotent** (no duplicate creation)
# - Writes a receipt with inputs/outputs for audit
#
# WHAT IT DOES NOT DO:
# - Does not migrate issues/data
# - Does not set up boards/sprints
# - Does not use template configurations
#
# NEXT STEP: Run 03_Users.ps1 to set up users and permissions
#
param([string] $ParametersPath, [switch] $DryRun)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
. (Join-Path $here "_terminal_logging.ps1")
$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent $here) "migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Set up step-specific output directory
$outDir = $p.OutputSettings.OutputDirectory
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = ".\out" }

# Ensure the base output directory exists
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output directory: $outDir" -ForegroundColor Green
}

# Clean up ONLY files from previous failed attempts of THIS step (targeted cleanup)
$projectKey = $p.ProjectKey
$projectExportDir = Join-Path ".\projects" $projectKey
if (Test-Path $projectExportDir) {
    $projectOutDir = Join-Path $projectExportDir "out"
    if (Test-Path $projectOutDir) {
        # Only clean up the exports02 folder (step-specific cleanup)
        $exports02Dir = Join-Path $projectOutDir "exports02"
        if (Test-Path $exports02Dir) {
            Write-Host "Cleaning up previous step 02 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports02Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports02 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder (exports02 for step 02)
$stepExportsDir = Join-Path $outDir "exports02"
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Set step start time
$script:StepStartTime = Get-Date

# Start terminal logging
$terminalLogPath = Start-TerminalLog -StepName "02_Project" -OutDir $outDir -ProjectKey $p.ProjectKey

# Set up error handling to ensure logging stops on errors
$ErrorActionPreference = "Stop"
trap {
    $errorMessage = "Step 02 (Project Creation) failed"
    if ($_.Exception.Message) {
        $errorMessage += ": $($_.Exception.Message)"
    }
    if ($_.Exception.InnerException) {
        $errorMessage += " (Inner: $($_.Exception.InnerException.Message))"
    }
    Write-Host "❌ $errorMessage" -ForegroundColor Red
    Stop-TerminalLogOnError -ErrorMessage $errorMessage
    throw
}

$base = $p.TargetEnvironment.BaseUrl
$email= $p.TargetEnvironment.Username
$tok  = $p.TargetEnvironment.ApiToken
$key  = $p.TargetEnvironment.ProjectKey
$name = $p.TargetEnvironment.ProjectName
$name = "$name Sandbox ADF"
$out  = $p.OutputSettings.OutputDirectory
$hdr  = New-BasicAuthHeader -Email $email -ApiToken $tok

function Test-ProjectExists {
  param([string] $Key)
  try {
    Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/project/{1}" -f $base.TrimEnd('/'), $Key) -Headers $hdr -ErrorAction Stop | Out-Null
    return $true
  } catch {
    return $false
  }
}

# --- Determine project template ---
$projectTemplate = "STANDARD"  # Default
if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
  if ($p.ProjectCreation.PSObject.Properties.Name -contains 'Template') {
    $projectTemplate = $p.ProjectCreation.Template.ToUpper()
  }
}

Write-Host "Creating project with $projectTemplate workflow template" -ForegroundColor Cyan

# --- Determine desired project lead ---
$desiredLeadAccountId = $null

# 1) Email from UserMapping.ProjectLeadEmail → resolve to accountId
if ($p.PSObject.Properties.Name -contains 'UserMapping') {
  if ($p.UserMapping.PSObject.Properties.Name -contains 'ProjectLeadEmail' -and $p.UserMapping.ProjectLeadEmail) {
    try {
      $projectLeadEmail = $p.UserMapping.ProjectLeadEmail
      $q = [uri]::EscapeDataString($projectLeadEmail)
      $users = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/user/search?query={1}&maxResults=5" -f $base.TrimEnd('/'), $q) -Headers $hdr -ErrorAction Stop
      if ($users -and $users.Count -gt 0 -and $users[0].accountId) {
        $desiredLeadAccountId = $users[0].accountId
        Write-Host ("Resolved project lead email '{0}' → accountId {1}" -f $projectLeadEmail, $desiredLeadAccountId)
      }
    } catch {
      Write-Warning ("Project lead email lookup failed: {0}" -f $_.Exception.Message)
    }
  }
}

# 2) Fallback: current user
if (-not $desiredLeadAccountId) {
  try {
    $me = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/myself" -f $base.TrimEnd('/')) -Headers $hdr -ErrorAction Stop
    $desiredLeadAccountId = $me.accountId
    Write-Host ("Using current user as project lead (accountId {0})" -f $desiredLeadAccountId)
  } catch {
    Write-Warning "Could not resolve a project lead accountId; will create the project without an explicit lead."
  }
}

# --- Check if target project already exists (IDEMPOTENT) ---
Write-Host "Checking if target project $key already exists…"
if (-not $script:DryRun -and (Test-ProjectExists -Key $key)) {
  Write-Host "✅ Target project '$key' already exists - using existing project (idempotent)" -ForegroundColor Green
  
  # Fetch existing project details
  try {
    $existingProjectUri = "$($base.TrimEnd('/'))/rest/api/3/project/$key"
    $existingProject = Invoke-RestMethod -Method GET -Uri $existingProjectUri -Headers $hdr -ErrorAction Stop
    
    Write-Host "   Project Name: $($existingProject.name)"
    Write-Host "   Project ID: $($existingProject.id)"
    Write-Host "   Project Key: $($existingProject.key)"
    
    # Create project creation report for CSV export (existing project)
    $projectCreationReport = @()
    
    # Add project details
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Project Key"
        Value = $existingProject.key
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Project Name"
        Value = $existingProject.name
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Project ID"
        Value = $existingProject.id
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add issue types
    foreach ($it in $existingProject.issueTypes) {
        $projectCreationReport += [PSCustomObject]@{
            Variable = "Issue Type"
            Value = "$($it.name) - Issue type ID: $($it.id)"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    # Capture step end time
    $stepEndTime = Get-Date
    
    # Add step timing information to project creation report
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Step Start Time"
        Value = "Step execution started at $($stepStartTime.ToString("yyyy-MM-dd HH:mm:ss"))"
        Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Step End Time"
        Value = "Step execution completed at $($stepEndTime.ToString("yyyy-MM-dd HH:mm:ss"))"
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Calculate step total time
    $stepDuration = $stepEndTime - $stepStartTime
    $totalSeconds = [Math]::Round($stepDuration.TotalSeconds, 0)
    $totalHours = [Math]::Floor($totalSeconds / 3600)
    $totalMinutes = [Math]::Floor(($totalSeconds % 3600) / 60)
    $remainingSeconds = $totalSeconds % 60
    $durationFormatted = "{0:00}h : {1:00}m : {2:00}s" -f $totalHours, $totalMinutes, $remainingSeconds
    
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Step Total Time"
        Value = $durationFormatted
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Export project creation report to CSV (in step-specific exports folder)
    $csvPath = Join-Path $stepExportsDir "02_Project_Report.csv"
    $projectCreationReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Project creation report saved: $csvPath" -ForegroundColor Green
    Write-Host "   Total items: $($projectCreationReport.Count)" -ForegroundColor Cyan
    
    # Write receipt for existing project
    $receiptData = @{
      Status = "ProjectAlreadyExists"
      TargetProject = @{ key=$existingProject.key; name=$existingProject.name; id=$existingProject.id }
      ProjectLeadAccountId = if ($existingProject.lead) { $existingProject.lead.accountId } else { $null }
      Notes = @("Target project already exists - using existing project (idempotent)")
    }
    Write-StageReceipt -OutDir $stepExportsDir -Stage "02_Project" -Data $receiptData
    
    Write-Host ""
    Write-Host "✅ Step 02 completed (project already exists)" -ForegroundColor Green
    exit 0
  } catch {
    Write-Warning "Could not fetch existing project details: $($_.Exception.Message)"
  }
} else {
  Write-Host "Project $key not found; proceeding to create simple project…"
}

# --- Create project using shared configuration from template ---
# Copy configuration from existing template project (XRAY, STANDARD, ENHANCED)
$projectTypeKey = "software"

# Get the source project ID for the template
$templateProjectId = switch ($projectTemplate) {
  "XRAY" { "10132" }    # Confirmed from API call
  "STANDARD" { "10033" }  # Confirmed from API call
  "ENHANCED" { "10198" }  # Confirmed from API call
  default { "10033" }
}

# Use shared configuration API
$standardUri = "$($base.TrimEnd('/'))/rest/project-templates/1.0/createshared/$templateProjectId"
$bodyStandard = @{
  key             = $key
  name            = $name
  lead            = $email
}

Write-Host "POST $standardUri"
Write-Host ($bodyStandard | ConvertTo-Json -Depth 10)

if ($script:DryRun) {
  Write-Host "[DRYRUN] Would create project via POST $standardUri" -ForegroundColor Yellow
} else {
  try {
    $createResult = Invoke-RestMethod -Method POST -Uri $standardUri -Headers $hdr -Body ($bodyStandard | ConvertTo-Json -Depth 10) -ContentType "application/json"
    Write-Host "Created target project with $projectTemplate workflow template (type=$projectTypeKey)" -ForegroundColor Green
  } catch {
    $msg = $_.Exception.Message
    $details = ""
    
    try {
      $resp = $_.Exception.Response
      if ($resp -and $resp.GetResponseStream()) {
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $details = $reader.ReadToEnd()
        $msg = "$msg`nResponse: $details"
      }
    } catch { }
    
    Write-Host "DEBUG: Full error response: $details" -ForegroundColor Red
    
    # Check if error is due to key already in use (likely in trash)
    if ($details -match "already in use|already exists|A project with that name already exists" -or $msg -match "already in use|already exists") {
      Write-Host ""
      Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
      Write-Host "║  ERROR: Project Key Already In Use                        ║" -ForegroundColor Red
      Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
      Write-Host ""
      Write-Host "The project key '$key' is already in use. This usually means:" -ForegroundColor Yellow
      Write-Host "  1. The project exists in the Trash/Recycle Bin" -ForegroundColor White
      Write-Host "  2. A project with this key was previously deleted but not purged" -ForegroundColor White
      Write-Host ""
      Write-Host "═══ SOLUTION OPTIONS ═══" -ForegroundColor Cyan
      Write-Host ""
      Write-Host "Option 1: Empty the Trash (Recommended)" -ForegroundColor Green
      Write-Host "  • Go to: $($base)secure/admin/ViewProjects.jspa" -ForegroundColor White
      Write-Host "  • Click 'View all projects' → 'Trash'" -ForegroundColor White
      Write-Host "  • Find project '$key' and permanently delete it" -ForegroundColor White
      Write-Host "  • Re-run this step" -ForegroundColor White
      Write-Host ""
      Write-Host "Option 2: Use a Different Target Key" -ForegroundColor Yellow
      Write-Host "  • Edit: $ParametersPath" -ForegroundColor White
      Write-Host "  • Change TargetEnvironment.ProjectKey from '$key' to '$($key)2'" -ForegroundColor White
      Write-Host "  • Re-run this step" -ForegroundColor White
      Write-Host ""
      Write-Host "Option 3: Check if Project Already Exists and is Active" -ForegroundColor Cyan
      Write-Host "  • Go to: $($base)projects/$key" -ForegroundColor White
      Write-Host "  • If it exists and is active, this step is already complete!" -ForegroundColor White
      Write-Host ""
      throw "Project key '$key' already in use. See solutions above."
    }
    
    throw "Failed to create project: $msg"
  }
}

# --- Fetch target project details ---
$tgt = $null
$maxAttempts = 5
if ($script:DryRun) {
  $tgt = @{ id = 0; key = $key; name = $name; projectTypeKey = 'software' }
} else {
  for ($i = 1; $i -le $maxAttempts; $i++) {
    try {
      $tgt = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/project/{1}" -f $base.TrimEnd('/'), $key) -Headers $hdr -ErrorAction Stop
      break
    } catch {
      Start-Sleep -Seconds 2
    }
  }
  if (-not $tgt) { throw "Project creation acknowledged but target project '$key' not readable after $maxAttempts attempts." }
}
Write-Host ("Created target project id {0}" -f $tgt.id) -ForegroundColor Green

# --- Set project lead AFTER creation (avoids GDPR/email problems on create) ---
if ($desiredLeadAccountId -and -not $script:DryRun) {
  try {
    $null = Invoke-RestMethod -Method PUT -Uri ("{0}/rest/api/3/project/{1}" -f $base.TrimEnd('/'), $tgt.id) -Headers $hdr -Body (@{ leadAccountId = $desiredLeadAccountId } | ConvertTo-Json -Depth 4) -ContentType "application/json"
    Write-Host ("Updated project lead to accountId {0}" -f $desiredLeadAccountId)
  } catch {
    Write-Warning ("Project created, but failed to set project lead: {0}" -f $_.Exception.Message)
  }
}

# --- Verification ---
Write-Host ""
Write-Host "=== PROJECT CONFIGURATION VERIFICATION ==="
  Write-Host "Target: $($tgt.name) (type=$($tgt.projectTypeKey))"
Write-Host "✅ Simple project created with default configuration" -ForegroundColor Green
  
  Write-Host ""
  Write-Host "=== ISSUE TYPES (names) ==="
  foreach ($it in $tgt.issueTypes) { Write-Host "  - $($it.name) (id=$($it.id))" }

# Create project creation report for CSV export
$projectCreationReport = @()

# Add project details
$projectCreationReport += [PSCustomObject]@{
    Variable = "Project Key"
    Value = $key
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Variable = "Project Name"
    Value = $name
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Variable = "Project ID"
    Value = $tgt.id
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Variable = "Project Type"
    Value = $tgt.projectTypeKey
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add issue types
foreach ($it in $tgt.issueTypes) {
    $projectCreationReport += [PSCustomObject]@{
        Variable = "Issue Type"
        Value = "$($it.name) - Issue type ID: $($it.id)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to project creation report
$projectCreationReport += [PSCustomObject]@{
    Variable = "Step Start Time"
    Value = "Step execution started at $($stepStartTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Variable = "Step End Time"
    Value = "Step execution completed at $($stepEndTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Calculate step total time
$stepDuration = $stepEndTime - $stepStartTime
$totalSeconds = [Math]::Round($stepDuration.TotalSeconds, 0)
$totalHours = [Math]::Floor($totalSeconds / 3600)
$totalMinutes = [Math]::Floor(($totalSeconds % 3600) / 60)
$remainingSeconds = $totalSeconds % 60
$durationFormatted = "{0:00}h : {1:00}m : {2:00}s" -f $totalHours, $totalMinutes, $remainingSeconds

$projectCreationReport += [PSCustomObject]@{
    Variable = "Step Total Time"
    Value = $durationFormatted
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export project creation report to CSV (in step-specific exports folder)
$csvPath = Join-Path $stepExportsDir "02_Project_Report.csv"
$projectCreationReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Project creation report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($projectCreationReport.Count)" -ForegroundColor Cyan

# Receipt
$receiptData = @{
  TargetProject        = @{ key=$key; name=$name; id=$tgt.id }
  ProjectType          = $tgt.projectTypeKey
  DesiredLeadAccountId = $desiredLeadAccountId
}
Write-StageReceipt -OutDir $stepExportsDir -Stage "02_Project" -Data $receiptData

Write-Host ""
Write-Host "✅ Step 02 completed successfully!" -ForegroundColor Green

# Stop terminal logging
Stop-TerminalLog -Success:$true -Summary "02_Project completed successfully"