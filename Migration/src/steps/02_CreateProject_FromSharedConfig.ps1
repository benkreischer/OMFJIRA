# 02_CreateProject_FromSharedConfig.ps1 - Create Target Project with Configuration Template
# 
# PURPOSE: Creates the target project in the destination Jira instance using one of three
# configuration templates: XRAY, STANDARD, or ENHANCED.
#
# CONFIGURATION TEMPLATES:
# - XRAY: Uses shared configuration from the XRAY reference project (schemes, workflows, screens, fields, issue types)
# - STANDARD: Uses shared configuration from the STANDARD reference project
# - ENHANCED: Uses shared configuration from the ENHANCED reference project
#
# WHAT IT DOES:
# - Reads ConfigurationTemplate from parameters (XRAY, STANDARD, or ENHANCED)
# - For XRAY/STANDARD/ENHANCED: Resolves the configuration source project and uses its shared configuration
# - Sets the **project lead to source project's lead** when visible; otherwise falls back (param email → fallback email → caller)
# - If the target key already exists and is active, script is **idempotent** (no duplicate creation)
# - Verifies the resulting project configuration against the source (for shared config templates)
# - Writes a receipt with inputs/outputs for audit
#
# WHAT IT DOES NOT DO:
# - Does not migrate issues/data
# - Does not set up boards/sprints
#
# NEXT STEP: Run 03_SyncUsersAndRoles.ps1 to set up users and permissions
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

$base = $p.TargetEnvironment.BaseUrl
$email= $p.TargetEnvironment.Username
$tok  = $p.TargetEnvironment.ApiToken
$key  = $p.TargetEnvironment.ProjectKey
$name = $p.TargetEnvironment.ProjectName
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

function Get-NextProjectKey {
  param([string] $Key)
  $m = [regex]::Match($Key,'^(.*?)(\d+)$')
  if ($m.Success) {
    $prefix = $m.Groups[1].Value
    $num    = [int]$m.Groups[2].Value + 1
  } else {
    $prefix = $Key
    $num    = 2
  }
  while ($true) {
    $trial = "{0}{1}" -f $prefix, $num
    if (-not (Test-ProjectExists -Key $trial)) { return $trial }
    $num++
  }
}

# --- Determine configuration template to use ---
$configTemplate = "XRAY"  # Default
if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
  if ($p.ProjectCreation.PSObject.Properties.Name -contains 'ConfigurationTemplate') {
    $configTemplate = $p.ProjectCreation.ConfigurationTemplate.ToUpper()
  }
}

Write-Host "Configuration Template: $configTemplate" -ForegroundColor Cyan

# --- Determine config source environment (where template projects live) ---
# Default to target environment (where XRAY, STANDARD, ENHANCED templates exist)
$configBase = $base
$configHdr = $hdr
Write-Host "Config source environment: $configBase" -ForegroundColor Cyan
Write-Host "  (This is where XRAY, STANDARD, and ENHANCED template projects are located)" -ForegroundColor Gray

if ($p.PSObject.Properties.Name -contains 'ProjectCreation' -and 
    $p.ProjectCreation.PSObject.Properties.Name -contains 'ConfigSourceEnvironment') {
  $configEnv = $p.ProjectCreation.ConfigSourceEnvironment
  if ($configEnv.BaseUrl) {
    $configBase = $configEnv.BaseUrl
    $configEmail = if ($configEnv.Username) { $configEnv.Username } else { $email }
    $configToken = if ($configEnv.ApiToken) { $configEnv.ApiToken } else { $tok }
    $configHdr = New-BasicAuthHeader -Email $configEmail -ApiToken $configToken
    Write-Host "OVERRIDE: Using custom config source environment: $configBase" -ForegroundColor Yellow
  }
}

# --- Resolve configuration source project id/key (for XRAY and ENHANCED templates) ---
$srcKey = $null; $srcId = $null; $useSharedConfig = $false

if ($configTemplate -eq "XRAY") {
  $useSharedConfig = $true
  if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'ConfigSourceProjectKey') { $srcKey = $p.ProjectCreation.ConfigSourceProjectKey }
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'ConfigSourceProjectId')  { $srcId  = $p.ProjectCreation.ConfigSourceProjectId }
  }
  if (-not $srcId) {
    if (-not $srcKey) { throw "XRAY template requires ProjectCreation.ConfigSourceProjectId or ProjectCreation.ConfigSourceProjectKey" }
    $src = Invoke-Jira -Method GET -BaseUrl $configBase -Path ("rest/api/3/project/{0}" -f $srcKey) -Headers $configHdr
    $srcId = $src.id
    Write-Host "Resolved XRAY source '$srcKey' to id $srcId" -ForegroundColor Green
  }
} elseif ($configTemplate -eq "ENHANCED") {
  $useSharedConfig = $true
  if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'EnhancedConfigSourceProjectKey') { $srcKey = $p.ProjectCreation.EnhancedConfigSourceProjectKey }
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'EnhancedConfigSourceProjectId')  { $srcId  = $p.ProjectCreation.EnhancedConfigSourceProjectId }
  }
  if (-not $srcId) {
    if (-not $srcKey) { throw "ENHANCED template requires ProjectCreation.EnhancedConfigSourceProjectId or ProjectCreation.EnhancedConfigSourceProjectKey" }
    $src = Invoke-Jira -Method GET -BaseUrl $configBase -Path ("rest/api/3/project/{0}" -f $srcKey) -Headers $configHdr
    $srcId = $src.id
    Write-Host "Resolved ENHANCED source '$srcKey' to id $srcId" -ForegroundColor Green
  }
} elseif ($configTemplate -eq "STANDARD") {
  $useSharedConfig = $true
  if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'StandardConfigSourceProjectKey') { $srcKey = $p.ProjectCreation.StandardConfigSourceProjectKey }
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'StandardConfigSourceProjectId')  { $srcId  = $p.ProjectCreation.StandardConfigSourceProjectId }
  }
  if (-not $srcId) {
    if (-not $srcKey) { throw "STANDARD template requires ProjectCreation.StandardConfigSourceProjectId or ProjectCreation.StandardConfigSourceProjectKey" }
    $src = Invoke-Jira -Method GET -BaseUrl $configBase -Path ("rest/api/3/project/{0}" -f $srcKey) -Headers $configHdr
    $srcId = $src.id
    Write-Host "Resolved STANDARD source '$srcKey' to id $srcId" -ForegroundColor Green
  }
} else {
  throw "Invalid ConfigurationTemplate: $configTemplate. Valid options: XRAY, STANDARD, ENHANCED"
}

# --- Get source project details (for shared config templates) ---
$xrayProject = $null
if ($useSharedConfig) {
  Write-Host "Retrieving configuration source project details…"
  try {
    $xrayProject = Invoke-Jira -Method GET -BaseUrl $configBase -Path ("rest/api/3/project/{0}" -f $srcId) -Headers $configHdr
    Write-Host "Config source project: $($xrayProject.name) (key=$($xrayProject.key), type=$($xrayProject.projectTypeKey))" -ForegroundColor Green
  } catch {
    throw "Cannot read configuration source project: $($_.Exception.Message)"
  }
}

# --- Determine desired project lead (prefer source project's lead; fallback to params → known email → caller) ---
$desiredLeadAccountId = $null
# 1) Source project's lead (if using shared config and API exposes it)
if ($xrayProject -and $xrayProject.PSObject.Properties.Name -contains 'lead') {
  if ($xrayProject.lead -and $xrayProject.lead.PSObject.Properties.Name -contains 'accountId') {
    $desiredLeadAccountId = $xrayProject.lead.accountId
    Write-Host ("Using source project lead accountId: {0}" -f $desiredLeadAccountId)
  }
}

# 2) Explicit accountId from params
if (-not $desiredLeadAccountId -and $p.PSObject.Properties.Name -contains 'ProjectCreation') {
  if ($p.ProjectCreation.PSObject.Properties.Name -contains 'ProjectLeadAccountId' -and $p.ProjectCreation.ProjectLeadAccountId) {
    $desiredLeadAccountId = $p.ProjectCreation.ProjectLeadAccountId
    Write-Host ("Using ProjectCreation.ProjectLeadAccountId: {0}" -f $desiredLeadAccountId)
  }
}

# 3) Email from params → resolve to accountId
if (-not $desiredLeadAccountId -and $p.PSObject.Properties.Name -contains 'ProjectCreation') {
  if ($p.ProjectCreation.PSObject.Properties.Name -contains 'ProjectLeadEmail' -and $p.ProjectCreation.ProjectLeadEmail) {
    try {
      $q = [uri]::EscapeDataString($p.ProjectCreation.ProjectLeadEmail)
      $users = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/user/search?query={1}&maxResults=5" -f $base.TrimEnd('/'), $q) -Headers $hdr -ErrorAction Stop
      if ($users -and $users.Count -gt 0 -and $users[0].accountId) {
        $desiredLeadAccountId = $users[0].accountId
        Write-Host ("Resolved ProjectLeadEmail '{0}' → accountId {1}" -f $p.ProjectCreation.ProjectLeadEmail, $desiredLeadAccountId)
      }
    } catch {
      Write-Warning ("ProjectLeadEmail lookup failed: {0}" -f $_.Exception.Message)
    }
  }
}

# 4) Fallback email from parameters (loaded from .env) → accountId
if (-not $desiredLeadAccountId -and $p.PSObject.Properties.Name -contains 'UserMapping') {
  if ($p.UserMapping.PSObject.Properties.Name -contains 'ProjectLeadEmail' -and $p.UserMapping.ProjectLeadEmail) {
    try {
      $fallbackEmail = $p.UserMapping.ProjectLeadEmail
      $q = [uri]::EscapeDataString($fallbackEmail)
      $users = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/user/search?query={1}&maxResults=5" -f $base.TrimEnd('/'), $q) -Headers $hdr -ErrorAction Stop
      if ($users -and $users.Count -gt 0 -and $users[0].accountId) {
        $desiredLeadAccountId = $users[0].accountId
        Write-Host ("Using fallback project lead '{0}' → accountId {1}" -f $fallbackEmail, $desiredLeadAccountId)
      }
    } catch {
      Write-Warning ("Fallback email lookup failed: {0}" -f $_.Exception.Message)
    }
  }
}

# 5) Final fallback: caller
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
if (Test-ProjectExists -Key $key) {
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
        Item = "Project Key"
        Value = $existingProject.key
        Status = "EXISTS"
        Details = "Target project key (already exists)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Item = "Project Name"
        Value = $existingProject.name
        Status = "EXISTS"
        Details = "Target project name (already exists)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Item = "Project ID"
        Value = $existingProject.id
        Status = "EXISTS"
        Details = "Target project ID (already exists)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Item = "Configuration Template"
        Value = $configTemplate
        Status = "APPLIED"
        Details = "Configuration template used"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Add issue types
    foreach ($it in $existingProject.issueTypes) {
        $projectCreationReport += [PSCustomObject]@{
            Item = "Issue Type"
            Value = $it.name
            Status = "CONFIGURED"
            Details = "Issue type ID: $($it.id)"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    # Capture step end time
    $stepEndTime = Get-Date
    
    # Add step timing information to project creation report
    $projectCreationReport += [PSCustomObject]@{
        Item = "Step Start Time"
        Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        Status = "INFO"
        Details = "Step execution started"
        Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $projectCreationReport += [PSCustomObject]@{
        Item = "Step End Time"
        Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
        Status = "INFO"
        Details = "Step execution completed"
        Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    # Export project creation report to CSV
    $csvPath = Join-Path $out "02_CreateProject_Report.csv"
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
    Write-StageReceipt -OutDir $out -Stage "02_CreateProject_FromSharedConfig" -Data $receiptData
    
    Write-Host ""
    Write-Host "✅ Step 02 completed (project already exists)" -ForegroundColor Green
    exit 0
  } catch {
    Write-Warning "Could not fetch existing project details: $($_.Exception.Message)"
  }
} else {
  Write-Host "Project $key not found; proceeding to create with shared configuration…"
}

# --- Create project (with or without shared configuration) ---
if ($useSharedConfig) {
  # Create WITH shared configuration from source project
  $sharedUri = "$($base.TrimEnd('/'))/rest/simplified/latest/project/shared"
  $bodyShared = @{
    key               = $key
    name              = $name
    existingProjectId = [int]$srcId
  }
  Write-Host "POST $sharedUri"
  Write-Host ($bodyShared | ConvertTo-Json -Depth 10)
  
  try {
    $null = Invoke-RestMethod -Method POST -Uri $sharedUri -Headers $hdr -Body ($bodyShared | ConvertTo-Json -Depth 10) -ContentType "application/json"
    Write-Host "Requested target project creation with $configTemplate shared configuration" -ForegroundColor Green
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
    
    throw "Failed to create project with shared configuration: $msg"
  }
} else {
  # Create STANDARD project (no shared configuration)
  $projectTypeKey = "software"  # Default
  if ($p.PSObject.Properties.Name -contains 'ProjectCreation') {
    if ($p.ProjectCreation.PSObject.Properties.Name -contains 'StandardProjectTypeKey') {
      $projectTypeKey = $p.ProjectCreation.StandardProjectTypeKey
    }
  }
  
  $standardUri = "$($base.TrimEnd('/'))/rest/api/3/project"
  $bodyStandard = @{
    key             = $key
    name            = $name
    projectTypeKey  = $projectTypeKey
    leadAccountId   = $desiredLeadAccountId
  }
  
  # Optional: Add project template key if specified in config
  if ($p.PSObject.Properties.Name -contains 'ProjectCreation' -and 
      $p.ProjectCreation.PSObject.Properties.Name -contains 'StandardProjectTemplateKey' -and
      $p.ProjectCreation.StandardProjectTemplateKey) {
    $bodyStandard.projectTemplateKey = $p.ProjectCreation.StandardProjectTemplateKey
  }
  
  Write-Host "POST $standardUri"
  Write-Host ($bodyStandard | ConvertTo-Json -Depth 10)
  
  try {
    $createResult = Invoke-RestMethod -Method POST -Uri $standardUri -Headers $hdr -Body ($bodyStandard | ConvertTo-Json -Depth 10) -ContentType "application/json"
    Write-Host "Requested target project creation with STANDARD template (type=$projectTypeKey)" -ForegroundColor Green
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
    
    throw "Failed to create standard project: $msg"
  }
}

# --- Fetch target project details (don’t assume response contains 'id') ---
$tgt = $null
$maxAttempts = 5
for ($i = 1; $i -le $maxAttempts; $i++) {
  try {
    $tgt = Invoke-Jira -Method GET -BaseUrl $base -Path ("rest/api/3/project/{0}" -f $key) -Headers $hdr
    break
  } catch {
    Start-Sleep -Seconds 2
  }
}
if (-not $tgt) { throw "Project creation acknowledged but target project '$key' not readable after $maxAttempts attempts." }
Write-Host ("Created target project id {0} with $configTemplate configuration" -f $tgt.id) -ForegroundColor Green

# --- Set project lead AFTER creation (avoids GDPR/email problems on create) ---
if ($desiredLeadAccountId) {
  try {
    $null = Invoke-RestMethod -Method PUT -Uri ("{0}/rest/api/3/project/{1}" -f $base.TrimEnd('/'), $tgt.id) -Headers $hdr -Body (@{ leadAccountId = $desiredLeadAccountId } | ConvertTo-Json -Depth 4) -ContentType "application/json"
    Write-Host ("Updated project lead to accountId {0}" -f $desiredLeadAccountId)
  } catch {
    Write-Warning ("Project created, but failed to set project lead: {0}" -f $_.Exception.Message)
  }
}

# --- Verification (compare with source if using shared config) ---
Write-Host ""
Write-Host "=== PROJECT CONFIGURATION VERIFICATION ==="
if ($useSharedConfig -and $xrayProject) {
  Write-Host "Source: $($xrayProject.name) (type=$($xrayProject.projectTypeKey))"
  Write-Host "Target: $($tgt.name) (type=$($tgt.projectTypeKey))"

  if ($xrayProject.projectTypeKey -eq $tgt.projectTypeKey) {
    Write-Host "✅ Project types MATCH" -ForegroundColor Green
  } else {
    Write-Host "❌ Project types differ: target=$($tgt.projectTypeKey), source=$($xrayProject.projectTypeKey)" -ForegroundColor Red
  }

  Write-Host ""
  Write-Host "=== ISSUE TYPES (names) ==="
  Write-Host "Source:"
  foreach ($it in $xrayProject.issueTypes) { Write-Host "  - $($it.name) (id=$($it.id))" }
  Write-Host "Target:"
  foreach ($it in $tgt.issueTypes)       { Write-Host "  - $($it.name) (id=$($it.id))" }

  try {
    $xrayIssueScheme = Invoke-Jira -Method GET -BaseUrl $base -Path ("rest/api/3/issuetypescheme/project?projectId={0}" -f $srcId) -Headers $hdr
    $tgtIssueScheme  = Invoke-Jira -Method GET -BaseUrl $base -Path ("rest/api/3/issuetypescheme/project?projectId={0}" -f $tgt.id) -Headers $hdr
    Write-Host ""
    Write-Host "=== ISSUE TYPE SCHEMES ==="
    Write-Host "Source: $($xrayIssueScheme.values[0].issueTypeScheme.name) (id=$($xrayIssueScheme.values[0].issueTypeScheme.id))"
    Write-Host "Target: $($tgtIssueScheme.values[0].issueTypeScheme.name) (id=$($tgtIssueScheme.values[0].issueTypeScheme.id))"
    if ($xrayIssueScheme.values[0].issueTypeScheme.id -eq $tgtIssueScheme.values[0].issueTypeScheme.id) {
      Write-Host "✅ Issue type schemes MATCH" -ForegroundColor Green
    } else {
      Write-Host "❌ Issue type schemes differ" -ForegroundColor Red
    }
  } catch {
    Write-Warning "Could not retrieve issue type scheme info: $($_.Exception.Message)"
  }

  try {
    $xrayWf = Invoke-Jira -Method GET -BaseUrl $base -Path ("rest/api/3/workflowscheme/project?projectId={0}" -f $srcId) -Headers $hdr
    $tgtWf  = Invoke-Jira -Method GET -BaseUrl $base -Path ("rest/api/3/workflowscheme/project?projectId={0}" -f $tgt.id) -Headers $hdr
    Write-Host ""
    Write-Host "=== WORKFLOW SCHEMES ==="
    Write-Host "Source: $($xrayWf.values[0].workflowScheme.name) (id=$($xrayWf.values[0].workflowScheme.id))"
    Write-Host "Target: $($tgtWf.values[0].workflowScheme.name) (id=$($tgtWf.values[0].workflowScheme.id))"
    if ($xrayWf.values[0].workflowScheme.id -eq $tgtWf.values[0].workflowScheme.id) {
      Write-Host "✅ Workflow schemes MATCH" -ForegroundColor Green
    } else {
      Write-Host "❌ Workflow schemes differ" -ForegroundColor Red
    }
  } catch {
    Write-Warning "Could not retrieve workflow scheme info: $($_.Exception.Message)"
  }
} else {
  Write-Host "Target: $($tgt.name) (type=$($tgt.projectTypeKey))"
  Write-Host "✅ STANDARD project created with default configuration" -ForegroundColor Green
  
  Write-Host ""
  Write-Host "=== ISSUE TYPES (names) ==="
  foreach ($it in $tgt.issueTypes) { Write-Host "  - $($it.name) (id=$($it.id))" }
}

# Create project creation report for CSV export
$projectCreationReport = @()

# Add project details
$projectCreationReport += [PSCustomObject]@{
    Item = "Project Key"
    Value = $key
    Status = "CREATED"
    Details = "Target project key"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Item = "Project Name"
    Value = $name
    Status = "CREATED"
    Details = "Target project name"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Item = "Project ID"
    Value = $tgt.id
    Status = "CREATED"
    Details = "Target project ID"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Item = "Configuration Template"
    Value = $configTemplate
    Status = "APPLIED"
    Details = "Configuration template used"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

if ($useSharedConfig) {
    $projectCreationReport += [PSCustomObject]@{
        Item = "Config Source Project"
        Value = $srcKey
        Status = "LINKED"
        Details = "Source project for shared configuration (ID: $srcId)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add issue types
foreach ($it in $tgt.issueTypes) {
    $projectCreationReport += [PSCustomObject]@{
        Item = "Issue Type"
        Value = $it.name
        Status = "CONFIGURED"
        Details = "Issue type ID: $($it.id)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to project creation report
$projectCreationReport += [PSCustomObject]@{
    Item = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Status = "INFO"
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$projectCreationReport += [PSCustomObject]@{
    Item = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Status = "INFO"
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export project creation report to CSV
$csvPath = Join-Path $out "02_CreateProject_Report.csv"
$projectCreationReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Project creation report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($projectCreationReport.Count)" -ForegroundColor Cyan

# Receipt
$receiptData = @{
  TargetProject        = @{ key=$key; name=$name; id=$tgt.id }
  ConfigurationTemplate = $configTemplate
  DesiredLeadAccountId = $desiredLeadAccountId
}
if ($useSharedConfig) {
  $receiptData.ConfigSource = @{ id=$srcId; key=$srcKey }
}
Write-StageReceipt -OutDir $out -Stage "02_CreateProject_FromSharedConfig" -Data $receiptData
