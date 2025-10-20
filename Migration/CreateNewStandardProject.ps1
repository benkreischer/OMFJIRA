# =============================================================================
# CREATE NEW STANDARD MIGRATION PROJECT (STREAMLINED)
# =============================================================================
#
# DESCRIPTION: Creates a new migration project with SourceKey/TargetKey structure using
#              standard settings without prompting
# 
# USAGE: 
#   .\CreateNewStandardProject.ps1 -SourceKey "DEP" -TargetKey "DEPX"
#   .\CreateNewStandardProject.ps1 -SourceKey "ABC" -TargetKey "ABC1"
#   .\CreateNewStandardProject.ps1 -SourceKey "DEP" -TargetKey "DEPX" -SourceBaseUrl "https://custom.atlassian.net/" -TargetBaseUrl "https://target.atlassian.net/" -UserEmail "user@company.com"
#
# CONFIGURATION:
#   - Uses STANDARD template
#   - Exports UNRESOLVED issues only
#   - Migrates sprints (YES)
#   - Includes sub-tasks (YES)
#   - Auto-runs migration after creation
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$SourceKey,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetKey,
    
    [Parameter(Mandatory=$false)]
    [string]$Description = "Migration from {0} to {1}",
    
    [Parameter(Mandatory=$false)]
    [string]$SourceBaseUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetBaseUrl,
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$UserEmail
)

# =============================================================================
# LOAD CONFIGURATION DEFAULTS
# =============================================================================

# Load default values from migration-parameters.json
$configPath = Join-Path $PSScriptRoot "migration-parameters.json"
if (Test-Path $configPath) {
    try {
        $configContent = Get-Content $configPath -Raw | ConvertFrom-Json
        
        # Set defaults from config file if not provided via command line
        if (-not $SourceBaseUrl) {
            $SourceBaseUrl = $configContent.SourceEnvironment.BaseUrl
        }
        if (-not $TargetBaseUrl) {
            $TargetBaseUrl = $configContent.TargetEnvironment.BaseUrl
        }
        if (-not $Username) {
            # Try to get username from .env file first, then fall back to config
            $envFile = Join-Path $PSScriptRoot ".env"
            if (Test-Path $envFile) {
                Get-Content $envFile | ForEach-Object {
                    if ($_ -match '^\s*USERNAME\s*=\s*(.*)$') {
                        $Username = $matches[1].Trim()
                    }
                }
            }
        }
        if (-not $UserEmail) {
            # Try to get user email from .env file first, then fall back to username
            $envFile = Join-Path $PSScriptRoot ".env"
            if (Test-Path $envFile) {
                Get-Content $envFile | ForEach-Object {
                    if ($_ -match '^\s*USERNAME\s*=\s*(.*)$') {
                        $UserEmail = $matches[1].Trim()
                    }
                }
            }
        }
    } catch {
        Write-Warning "Could not load config file: $configPath. Using hardcoded defaults."
        # Fallback to hardcoded defaults if config load fails
        if (-not $SourceBaseUrl) { $SourceBaseUrl = "https://onemain.atlassian.net/" }
        if (-not $TargetBaseUrl) { $TargetBaseUrl = "https://onemainfinancial-migrationsandbox.atlassian.net/" }
        if (-not $Username) { $Username = "ben.kreischer.ce@omf.com" }
        if (-not $UserEmail) { $UserEmail = "ben.kreischer.ce@omf.com" }
    }
} else {
    Write-Warning "Config file not found at: $configPath. Using hardcoded defaults."
    # Fallback to hardcoded defaults if config file doesn't exist
    if (-not $SourceBaseUrl) { $SourceBaseUrl = "https://onemain.atlassian.net/" }
    if (-not $TargetBaseUrl) { $TargetBaseUrl = "https://onemainfinancial-migrationsandbox.atlassian.net/" }
    if (-not $Username) { $Username = "ben.kreischer.ce@omf.com" }
    if (-not $UserEmail) { $UserEmail = "ben.kreischer.ce@omf.com" }
}

# =============================================================================
# VALIDATION (Must happen BEFORE creating any directories)
# =============================================================================

# Validate source project key format
if ($SourceKey -notmatch '^[A-Z]{2,10}$') {
    Write-Error "SourceKey must be 2-10 uppercase letters (e.g., 'DEP', 'ABC', 'PROJECT')"
    exit 1
}

# Validate target project key format
if ($TargetKey -notmatch '^[A-Z]{2,10}$') {
    Write-Error "TargetKey must be 2-10 uppercase letters (e.g., 'DEPX', 'ABC1', 'PROJECT')"
    exit 1
}

# Check if project already exists and delete it if it does
$projectPath = Join-Path "projects" $SourceKey
if (Test-Path $projectPath) {
    Write-Host "Project '$SourceKey' already exists at '$projectPath'" -ForegroundColor Yellow
    Write-Host "Deleting existing project folder to regenerate..." -ForegroundColor Yellow
    Remove-Item -Path $projectPath -Recurse -Force
    Write-Host "Existing project folder deleted successfully" -ForegroundColor Green
}

# =============================================================================
# INITIALIZE LOGGING (After validation passes)
# =============================================================================

# Load logging module
. "$PSScriptRoot\_logging.ps1"

# Create out directory for logging
$tempOutDir = Join-Path "projects" "$SourceKey\out"
if (-not (Test-Path $tempOutDir)) {
    New-Item -ItemType Directory -Path $tempOutDir -Force | Out-Null
}

# Initialize log
$script:LogFile = Initialize-MigrationLog -ProjectKey $SourceKey -OutDir $tempOutDir -Operation "StandardProjectCreation"

Write-LogStep "Create New Standard Migration Project: $SourceKey → $TargetKey"

Write-Host "`n📊 Log file: $script:LogFile" -ForegroundColor Cyan
Write-Host "💡 To monitor in another terminal: .\Watch-Log.ps1 -ProjectKey $SourceKey`n" -ForegroundColor Yellow

Write-LogSubStep "Validation"
Write-LogSuccess "Source project key format is valid: $SourceKey" -Component "Validation"
Write-LogSuccess "Target project key format is valid: $TargetKey" -Component "Validation"
Write-LogSuccess "Project directory is available" -Component "Validation"

# =============================================================================
# FETCH PROJECT NAME FROM JIRA
# =============================================================================

Write-LogSubStep "Fetch Project Details from Jira"
Write-LogInfo "Connecting to source Jira..." -Component "API"

# Load API token from .env file
$envFile = Join-Path $PSScriptRoot ".env"
Write-LogInfo "Loading API credentials from .env..." -Component "Auth"
if (-not (Test-Path $envFile)) {
    Write-LogError ".env file not found at: $envFile" -Component "Auth"
    Write-LogDetail "Please create a .env file with your JIRA_API_TOKEN"
    Complete-MigrationLog -Success:$false
    throw ".env file not found"
}

$apiToken = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*JIRA_API_TOKEN\s*=\s*(.*)$') {
        $apiToken = $matches[1].Trim()
    }
}

if (-not $apiToken) {
    Write-LogError "JIRA_API_TOKEN not found in .env file" -Component "Auth"
    Complete-MigrationLog -Success:$false
    throw "JIRA_API_TOKEN not found in .env file"
}
Write-LogSuccess "API credentials loaded" -Component "Auth"

# Create auth header
$pair = "$($Username):$($apiToken)"
$bytes = [System.Text.Encoding]::UTF8.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$authHeader = @{ Authorization = "Basic $base64" }

# Note: We don't check if target project exists because:
# 1. Migration steps are idempotent and will clean up/recreate artifacts
# 2. Steps 4+ delete and reload components, comments, etc.
# 3. This allows re-running the script for recovery/re-migration
Write-LogSubStep "Target Project Validation"
Write-LogInfo "Target project validation skipped - migration is idempotent" -Component "Validation"
Write-Host "ℹ️  Target project validation skipped (migration steps are idempotent)" -ForegroundColor Cyan

# Fetch source project details
try {
    $srcProjectUri = "$($SourceBaseUrl.TrimEnd('/'))/rest/api/3/project/$SourceKey"
    Write-LogInfo "Fetching project: $srcProjectUri" -Component "API"
    $srcProject = Invoke-RestMethod -Method GET -Uri $srcProjectUri -Headers $authHeader -ErrorAction Stop
    $actualProjectName = $srcProject.name
    $targetProjectName = "$actualProjectName Sandbox"
    
    Write-LogSuccess "Found project: $actualProjectName (Key: $SourceKey)" -Component "API"
    Write-LogTable "Project Details" @{
        "Source Key" = $SourceKey
        "Source Name" = $actualProjectName
        "Target Key" = $TargetKey
        "Target Name" = $targetProjectName
    }
} catch {
    if ($_.Exception.Message -match '404') {
        Write-LogWarning "Project '$SourceKey' not found in source Jira" -Component "API"
        Write-LogInfo "Source URL: $SourceBaseUrl" -Component "API"
        Write-Host ""
        Write-Host "⚠️  WARNING: This project doesn't exist in the source Jira!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The migration will still create the project configuration, but" -ForegroundColor Yellow
        Write-Host "Step 01 (Preflight) will fail unless you:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Verify the project key '$SourceKey' is correct" -ForegroundColor Cyan
        Write-Host "  2. Update the source URL in parameters.json if needed" -ForegroundColor Cyan
        Write-Host "  3. Confirm the project exists in your source Jira" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠️  Continuing automatically with placeholder names..." -ForegroundColor Yellow
        Write-LogInfo "Continuing with placeholder names (will be updated in Step 01 if project exists)" -Component "API"
    } else {
        Write-LogWarning "Could not fetch project details from Jira: $($_.Exception.Message)" -Component "API"
        Write-LogInfo "Using placeholder names (will be updated in Step 01)" -Component "API"
    }
    $actualProjectName = "Updated in Preflight check"
    $targetProjectName = "Updated in Preflight check"
}

# Generate description
if ($actualProjectName -eq "Updated in Preflight check") {
    $projectDescription = "Updated in Preflight check"
} else {
    $projectDescription = "Migration from $SourceKey ($actualProjectName) to $TargetKey ($targetProjectName)"
}

# =============================================================================
# STANDARD MIGRATION CONFIGURATION (NO PROMPTS)
# =============================================================================

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  STANDARD MIGRATION CONFIGURATION (AUTO-SELECTED)" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Pre-configured settings
$configTemplate = "STANDARD"
$exportScope = "UNRESOLVED"
$migrateSprints = $true
$includeSubTasks = $true

Write-Host "1️⃣  Project Configuration Template: STANDARD ✅" -ForegroundColor Green
Write-Host "2️⃣  Issue Export Scope: UNRESOLVED issues only ✅" -ForegroundColor Green
Write-Host "3️⃣  Migrate Sprints: YES ✅" -ForegroundColor Green
Write-Host "4️⃣  Include SubTasks: YES ✅" -ForegroundColor Green

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# CREATE PROJECT STRUCTURE
# =============================================================================

Write-Host "Creating new standard migration project: $SourceKey" -ForegroundColor Green
Write-Host "Source: $SourceKey → Target: $TargetKey" -ForegroundColor Cyan

# Create main project directory
Write-LogSubStep "Create Project Structure"
Write-LogInfo "Creating project directory: $projectPath" -Component "FileSystem"
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
Write-LogSuccess "Created project directory: $projectPath" -Component "FileSystem"

# Create output directory
$outPath = Join-Path $projectPath "out"
Write-LogInfo "Creating output directories..." -Component "FileSystem"
New-Item -ItemType Directory -Path $outPath -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $outPath "exports") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $outPath "logs") -Force | Out-Null
Write-LogSuccess "Created output directories (out, exports, logs)" -Component "FileSystem"

# =============================================================================
# GENERATE PARAMETERS.JSON
# =============================================================================

$parameters = [ordered]@{
    ProjectKey = $SourceKey
    ProjectName = $actualProjectName
    Description = $projectDescription
    Created = Get-Date -Format "yyyy-MM-dd"
    
    SourceEnvironment = [ordered]@{
        BaseUrl = $SourceBaseUrl
        Username = $Username
        ApiToken = $apiToken
    }
    TargetEnvironment = [ordered]@{
        BaseUrl = $TargetBaseUrl
        ProjectKey = $TargetKey
        ProjectName = $targetProjectName
        Username = $Username
        ApiToken = $apiToken
    }
    MigrationSettings = [ordered]@{
        DryRun = $false
        MigrateSprints = $migrateSprints
        MigrateAttachments = $true
        MigrateComments = $true
        MigrateLinks = $true
        MigrateCustomFields = $true
        MigrateLegacyKeys = $true
        DeleteTargetIssuesBeforeImport = $false
        DeleteTargetComponentsBeforeImport = $false
        DeleteTargetVersionsBeforeImport = $false
        DeleteTargetBoardsBeforeImport = $false
    }
    AnalysisSettings = [ordered]@{
        MaxIssuesToAnalyze = 50000
        IncludeClosedIssues = $false
        IncludeSubTasks = $includeSubTasks
        BatchSize = 50
        RetryAttempts = 5
    }
    OutputSettings = [ordered]@{
        LogLevel = "INFO"
        GenerateHtmlReport = $true
        GenerateCsvReport = $true
        OpenReportInBrowser = $false
        OutputDirectory = "./projects/$SourceKey/out"
        LogDirectory = "./projects/$SourceKey/out/logs"
    }
    StatusMapping = [ordered]@{
        "Backlog" = "Backlog"
        "Analysis" = "Analysis"
        "Acceptance" = "Acceptance"
        "Achieved" = "Achieved"
        "Blocked" = "Blocked"
        "Cancelled" = "Cancelled"
        "Closed" = "Done"
        "Done" = "Done"
        "In Progress" = "In Progress"
        "Not Met" = "Not Met"
        "Prioritized" = "Prioritized"
        "Ready for Work" = "Ready for Work"
        "Refinement" = "Refinement"
        "Resolved" = "Done"
        "Review" = "Review"
        "Testing" = "Testing"
        "To Do" = "To Do"
        "UX Design" = "UX Design"
    }
    IssueTypeMapping = [ordered]@{
        "Epic" = "Epic"
        "Story" = "Story"
        "Task" = "Task"
        "Sub-task" = "Sub-task"
        "Bug" = "Bug"
        "Initiative" = "Initiative"
        "Theme" = "Theme"
        "Capability" = "Capability"
        "Feature" = "Feature"
        "Enabler" = "Enabler"
        "Requirement" = "Requirement"
        "Change Request" = "Change Request"
        "Improvement" = "Improvement"
        "Spike" = "Spike"
        "Technical Debt" = "Technical Debt"
        "User Research" = "User Research"
        "Design" = "Design"
        "Service Request" = "Service Request"
        "Service Request with Approval" = "Service Request with Approval"
        "Incident" = "Incident"
        "Problem" = "Problem"
        "Change" = "Change"
        "Post-incident Review" = "Post-incident Review"
        "Risk" = "Risk"
        "Control" = "Control"
        "Audit" = "Audit"
        "Objective" = "Objective"
        "Key Result" = "Key Result"
        "Milestone" = "Milestone"
        "Test" = "Test"
        "Test Case" = "Test Case"
        "Defect" = "Defect"
        "Improvement Request" = "Improvement Request"
        "Idea" = "Idea"
        "Opportunity" = "Opportunity"
        "Research" = "Research"
        "Experiment" = "Experiment"
        "Release" = "Release"
        "Deployment" = "Deployment"
        "Bug Report" = "Bug"
    }
    CustomFields = [ordered]@{
        LegacyKeyURL = "customfield_10400"
        LegacyKey = "customfield_10401"
        OriginalCreatedDate = "customfield_10402"
        OriginalUpdatedDate = "customfield_10403"
    }
    CustomFieldMapping = [ordered]@{
        "customfield_10023" = "customfield_10058"
        "customfield_10030" = "customfield_10091"
        "customfield_12135" = "customfield_10289"
        "customfield_10003" = "customfield_10003"
        "customfield_10244" = "customfield_10092"
        "customfield_11940" = "customfield_10226"
        "customfield_11941" = "customfield_10227"
        "customfield_10108" = "customfield_10158"
        "customfield_11797" = "customfield_10190"
        "customfield_10351" = "customfield_10190"
        "customfield_11859" = "customfield_10190"
        "customfield_10366" = "customfield_10190"
        "customfield_11943" = "customfield_10229"
        "customfield_11945" = "customfield_10231"
        "customfield_11946" = "customfield_10232"
        "customfield_11761" = "customfield_10032"
        "customfield_10109" = "customfield_10095"
        "customfield_10761" = "customfield_10124"
        "customfield_10760" = "customfield_10096"
        "customfield_10396" = "customfield_10100"
        "customfield_10283" = "customfield_10250"
        "customfield_10127" = "customfield_10250"
        "customfield_10141" = "customfield_10250"
        "customfield_10120" = "customfield_10250"
        "customfield_10245" = "customfield_10250"
        "customfield_11970" = "customfield_10250"
        "customfield_12102" = "customfield_10256"
        "customfield_11808" = "customfield_10031"
        "customfield_11937" = "customfield_10223"
        "customfield_11938" = "customfield_10224"
        "customfield_11939" = "customfield_10225"
        "customfield_11779" = "customfield_10004"
        "customfield_11841" = "customfield_10004"
        "customfield_11942" = "customfield_10228"
        "customfield_11944" = "customfield_10230"
        "customfield_10347" = "customfield_10029"
        "customfield_10345" = "customfield_10030"
        "customfield_11762" = "customfield_10034"
        "customfield_11763" = "customfield_10035"
        "customfield_10758" = "customfield_10097"
        "customfield_10240" = "customfield_10322"
        "customfield_10246" = "customfield_10010"
        "customfield_11807" = "customfield_10024"
        "customfield_10694" = "customfield_10099"
        "customfield_10759" = "customfield_10098"
        "customfield_10027" = "customfield_10101"
        "customfield_10346" = "customfield_10028"
        "customfield_10032" = "customfield_10023"
        "customfield_10031" = "customfield_10022"
        "customfield_10394" = "customfield_10093"
        "customfield_10395" = "customfield_10094"
        "customfield_10348" = "customfield_10027"
        "customfield_11778" = "customfield_10033"
    }
    SprintSettings = [ordered]@{
        Mode = "Auto"
        PreferredBoardType = "scrum"
        CreateTargetFilter = $true
        TargetBoardNameTemplate = "{TargetProjectKey} Scrum Board"
        SprintNamePattern = $null
        CopyClosedSprints = $true
        CreateFutureSprints = $true
        SprintMapping = [ordered]@{}
    }
    BoardResolution = [ordered]@{
        Mode = "AutoDetect"
        SelectionStrategy = "MostClosedSprints"
        NameContains = $null
    }
    UserMapping = [ordered]@{
        FallbackToProjectLead = $true
        ProjectLeadEmail = $UserEmail
    }
    UserInvitation = [ordered]@{
        AutoInvite = $true
    }
    # ProjectCreation: Configuration will be copied from template projects in TARGET environment
    # IMPORTANT: Template projects (XRAY, STANDARD, ENHANCED) are located in:
    #            https://onemainfinancial-migrationsandbox.atlassian.net/
    ProjectCreation = [ordered]@{
        Template = $configTemplate
    }
    IssueExportSettings = [ordered]@{
        Scope = $exportScope
    }
    ConfluenceEnvironment = [ordered]@{
        BaseUrl = "https://onemainfinancial.atlassian.net/wiki"
        SpaceKey = "JIRA"
        Username = $Username
        ApiToken = $apiToken
    }
}

Write-LogSubStep "Generate Configuration Files"
Write-LogInfo "Creating parameters.json..." -Component "Config"

Write-LogTable "Standard Configuration" @{
    "Template Type" = $configTemplate
    "Template Project Key" = $configTemplate
    "Template Environment" = "TARGET (onemainfinancial-migrationsandbox)"
    "Template URL" = $TargetBaseUrl
    "Export Scope" = $exportScope
    "Migrate Sprints" = $(if ($migrateSprints) { "YES" } else { "NO" })
    "Include SubTasks" = $(if ($includeSubTasks) { "YES" } else { "NO" })
    "Confluence Integration" = "YES (JIRA space)"
}

$parametersJson = $parameters | ConvertTo-Json -Depth 10
$parametersPath = Join-Path $projectPath "parameters.json"
$parametersJson | Out-File -FilePath $parametersPath -Encoding UTF8
Write-LogSuccess "Created parameters.json with standard migration settings" -Component "Config"
Write-LogDetail "Config file: $parametersPath"
Write-LogDetail "Template source: Project '$configTemplate' in onemainfinancial-migrationsandbox.atlassian.net"

# =============================================================================
# COPY README FROM TEMPLATE
# =============================================================================

# Copy README template from XXX project
Write-LogInfo "Creating README.md..." -Component "Docs"
$templateReadme = Join-Path $PSScriptRoot "projects\XXX\README.md"
if (Test-Path $templateReadme) {
    $readmeContent = Get-Content $templateReadme -Raw
    
    # Replace placeholders with actual values
    $readmeContent = $readmeContent -replace '\{PROJECT_KEY\}', $SourceKey
    $readmeContent = $readmeContent -replace '\{CREATED_DATE\}', (Get-Date -Format "yyyy-MM-dd")
    
    $readmePath = Join-Path $projectPath "README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-LogSuccess "Created README.md from template" -Component "Docs"
} else {
    Write-LogWarning "Template README not found, generating basic README..." -Component "Docs"
    $readmeContent = @"
# {PROJECT_KEY} Migration Project

**Project:** {PROJECT_KEY} → {PROJECT_KEY}1  
**Status:** 🚀 Ready to Start  
**Date:** {CREATED_DATE}

---

## 🚀 Quick Start

**Location:** `Z:\Code\OMF\Migration`

### Option 1: Interactive Launcher (Recommended)

```powershell
# Launch interactive menu - select steps one by one
.\RunMigration.ps1 -Project {PROJECT_KEY}
```

This will show you a menu where you can select each step interactively. Just keep selecting the next step until you complete all 16 steps.

### Option 2: Run Individual Steps

```powershell
# Validate everything first
.\RunMigration.ps1 -Project {PROJECT_KEY} -DryRun

# Then run each step in order:
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 01
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 02
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 03
# ... continue through Step 16
```

**⚠️ IMPORTANT:** Run ALL 16 steps in order - each step depends on previous ones!

---

## 📂 Project Structure

```
{PROJECT_KEY}/
├── parameters.json       # Migration configuration
├── out/                  # All migration outputs (created during migration)
│   ├── exports/          # Will contain exported source data
│   ├── logs/             # Migration logs
│   ├── *.json            # Step receipts
│   ├── *.html            # Reports & dashboards
│   └── *.csv             # Data exports
└── README.md             # This file
```

---

## ✅ Complete Migration Checklist

**⚠️ IMPORTANT: ALL steps must be run in order for each project!**

### Pre-Migration

- [ ] Read documentation: `../../docs/Workflow.md`
- [ ] Review and update `parameters.json`
- [ ] Run validation: `.\RunMigration.ps1 -Project {PROJECT_KEY} -DryRun`
- [ ] Backup source project (if possible)
- [ ] Communicate with stakeholders

### Phase 1: Setup & Export (Required Foundation)

- [ ] **Step 01: Preflight Validation**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 01
  ```
  Validates configuration, connectivity, API access

- [ ] **Step 02: Create Target Project**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 02
  ```
  Creates {PROJECT_KEY}1 in sandbox with correct configuration

- [ ] **Step 03: Migrate Users and Roles**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 03
  ```
  Ensures all source users exist in target

- [ ] **Step 04: Components and Labels**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 04
  ```
  Migrates components, creates components from labels

- [ ] **Step 05: Versions**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 05
  ```
  Migrates fix versions and affected versions

- [ ] **Step 06: Boards**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 06
  ```
  Creates scrum/kanban boards (required for sprints)

- [ ] **Step 07: Export Issues ⭐ CRITICAL**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 07
  ```
  Exports ALL issues from {PROJECT_KEY} source project

### Phase 2: Core Data Migration (Steps 08-12) ✅ IDEMPOTENT

**✅ All these steps are IDEMPOTENT - safe to re-run!**

- [ ] **Step 08: Create Issues + Legacy Keys ⭐**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 08
  ```
  Creates all issues, sets LegacyKey custom fields

- [ ] **Step 09: Migrate Comments**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 09
  ```
  Migrates all comments with original author attribution

- [ ] **Step 10: Migrate Attachments**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 10
  ```
  Downloads and uploads all attachments

- [ ] **Step 11: Migrate Links**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 11
  ```
  Creates issue links and remote links

- [ ] **Step 12: Migrate Worklogs**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 12
  ```
  Migrates time tracking entries

### Phase 3: Configuration (Steps 13-14)

- [ ] **Step 13: Migrate Sprints** ✅ IDEMPOTENT
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 13
  ```
  Migrates closed sprints with dates and goals

- [ ] **Step 14: History Migration** ✅ IDEMPOTENT
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 14
  ```
  Migrates issue history and change logs

### Phase 4: Validation & Finalization (Steps 15-16)

- [ ] **Step 15: Review Migration ⭐ CRITICAL**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 15
  ```
  Runs comprehensive migration review and validation
  - Generates interactive HTML dashboard
  - Checks duplicates, field accuracy, links
  - Provides quality score and completion summary

- [ ] **Step 16: Push to Confluence ⭐ CRITICAL**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 16
  ```
  Pushes migration documentation to Confluence
  - Generates final comprehensive reports
  - HTML report (visual overview)
  - CSV report (detailed data)
  - JSON report (complete data)
  - Documentation in Confluence space

### Post-Migration Tasks

- [ ] Review QA dashboard: `out/master_qa_dashboard.html`
- [ ] Review post-migration report: `out/migration_report.html`
- [ ] Address any quality issues identified
- [ ] Verify sample issues manually
- [ ] Review automation guide: `out/automation_migration_guide.html`
- [ ] Complete permissions checklist
- [ ] Test user access in target
- [ ] Communicate completion to stakeholders

---

## 📊 What Each Phase Does

| Phase | Steps | Purpose |
|-------|-------|---------|
| **Setup** | 01-07 | Prepare target, export source |
| **Core Migration** | 08-12 | Migrate issues, comments, attachments, links, worklogs |
| **Configuration** | 13-14 | Sprints, history migration |
| **Validation** | 15-16 | Review, Confluence documentation |

---

## ⚠️ Critical: Don't Skip Steps!

**Each step builds on the previous ones:**
- Step 07 exports data → Step 08 uses it to create issues
- Step 08 creates key mappings → Steps 09-12 use them
- Step 06 creates boards → Step 13 uses them for sprints
- All steps create receipts → Step 15 validates them
- Step 15 validates → Step 16 includes QA results in Confluence

**Common Mistakes to Avoid:**
- ❌ **Skipping Step 07** - Without export, nothing else will work  
- ❌ **Skipping Step 01** - Might miss configuration issues  
- ❌ **Skipping Step 06** - Sprints won't work without boards  
- ❌ **Skipping Step 15** - Won't know if migration succeeded  
- ❌ **Skipping Step 16** - No audit trail for stakeholders  

**✅ Run ALL steps 01-16 in order!**

---

## ✨ Key Features

### Idempotency
All core migration scripts (08-12, 15) are **idempotent** - safe to re-run:
- ✅ Prevents duplicates automatically
- ✅ Skips items that already exist
- ✅ Perfect for recovery from failures

### Legacy Key Tracking
Every migrated issue will have:
- **LegacyKey** - Original source key (searchable via JQL)
- **LegacyKeyURL** - Clickable link back to source
- **OriginalCreatedDate** - Original creation timestamp from source
- **OriginalUpdatedDate** - Original last updated timestamp from source

Search by source key: `LegacyKey = "{PROJECT_KEY}-123"`
Sort by original date: Order by `OriginalCreatedDate`

### Comprehensive QA
After migration, run QA validation for:
- Duplicate detection
- Data integrity checks
- Field accuracy validation
- Interactive HTML dashboard

---

## 🔄 If You Need to Re-Run

**Steps 08-12, 13, and 14 are IDEMPOTENT:**
- Safe to re-run without creating duplicates
- Will skip items that already exist
- Perfect for recovery from failures

```powershell
# Example: Re-run issue creation
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 08  # Safe - no duplicates!
```

---

## 🎯 Expected Results

After completing all steps:

- ✅ All issues migrated with legacy keys
- ✅ All comments with proper attribution
- ✅ All attachments transferred
- ✅ All valid links created
- ✅ All worklogs migrated
- ✅ Sprints recreated
- ✅ Quality score 95%+
- ✅ Comprehensive reports generated

---

## 🛠️ Troubleshooting

### If Step Fails
All core steps are idempotent - just re-run:
```powershell
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 08  # Re-runs safely
```

### If Duplicates Created
```powershell
.\src\Utility\08_RemoveDuplicatesIssues.ps1 -ParametersPath .\projects\{PROJECT_KEY}\parameters.json -DryRun
```

### If Comments Need Re-migration
```powershell
.\src\Utility\09_RemoveComments.ps1 -ParametersPath .\projects\{PROJECT_KEY}\parameters.json
```

---

## 🔍 Monitoring Progress

### Check Receipts
```powershell
Get-ChildItem .\out\*_receipt.json | Select-Object Name, LastWriteTime
```

### View Reports
```powershell
# Open QA dashboard
Start-Process .\out\master_qa_dashboard.html

# Open post-migration report
Start-Process .\out\migration_report.html
```

### Check Logs
```powershell
Get-ChildItem .\out\logs\
```

---

## 📝 Configuration

Edit `parameters.json` to customize:
- Source/Target credentials
- Issue type mappings
- Status mappings
- Sprint settings
- Custom field mappings

---

## 📚 Documentation

Main documentation: `../../docs/`

Key guides:
- [Workflow.md](../../docs/Workflow.md) - Complete migration guide
- [IDEMPOTENCY_COMPLETE.md](../../docs/IDEMPOTENCY_COMPLETE.md) - Safe re-runs
- [QA_VALIDATION_SYSTEM_GUIDE.md](../../docs/QA_VALIDATION_SYSTEM_GUIDE.md) - QA system
- [TOOLKIT_SUMMARY.md](../../docs/TOOLKIT_SUMMARY.md) - Feature overview

---

## 🎯 Start Here

**Your first command:**
```powershell
.\RunMigration.ps1 -Project {PROJECT_KEY} -Step 01
```

**Then continue sequentially through Step 16!**

**All outputs will go to:** `.\projects\{PROJECT_KEY}\out\`

---

**Complete checklist = Successful migration!** ✅

**This migration uses the idempotent, legacy-key-enabled toolkit - safe and traceable!** 🌟
"@
    
    # Replace placeholders with actual values
    $readmeContent = $readmeContent -replace '\{PROJECT_KEY\}', $SourceKey
    $readmeContent = $readmeContent -replace '\{CREATED_DATE\}', (Get-Date -Format "yyyy-MM-dd")
    
    $readmePath = Join-Path $projectPath "README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-LogSuccess "Created README.md (fallback)" -Component "Docs"
}

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

Write-LogStep "Standard Project Creation Complete"

Write-LogSuccess "Standard project created successfully!" -Component "Summary"

Write-LogTable "Standard Configuration Summary" @{
    "Project" = "$SourceKey → $TargetKey"
    "Name" = "$actualProjectName → $targetProjectName"
    "Source URL" = $SourceBaseUrl
    "Target URL" = $TargetBaseUrl
    "Template" = $configTemplate
    "Export Scope" = $exportScope
    "Migrate Sprints" = $(if ($migrateSprints) { 'YES' } else { 'NO' })
    "Include SubTasks" = $(if ($includeSubTasks) { 'YES' } else { 'NO' })
    "Confluence Integration" = "YES (JIRA space)"
    "Location" = $projectPath
}

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  🎉 STANDARD PROJECT CREATED SUCCESSFULLY!                ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# =============================================================================
# CONFIGURATION SUMMARY
# =============================================================================

Write-Host "═══ STANDARD CONFIGURATION SUMMARY ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Project:        $SourceKey → $TargetKey" -ForegroundColor White
Write-Host "📋 Name:           $actualProjectName → $targetProjectName" -ForegroundColor White
Write-Host ""
Write-Host "🔵 SOURCE:" -ForegroundColor Cyan
Write-Host "   URL:            $SourceBaseUrl" -ForegroundColor White
Write-Host "   Project:        $SourceKey" -ForegroundColor Gray
Write-Host ""
Write-Host "🟢 TARGET:" -ForegroundColor Green
Write-Host "   URL:            $TargetBaseUrl" -ForegroundColor White
Write-Host "   Project:        $TargetKey" -ForegroundColor Gray
Write-Host ""
Write-Host "⚙️  STANDARD SETTINGS:" -ForegroundColor Yellow
Write-Host "   Template:         $configTemplate" -ForegroundColor White
Write-Host "   Export Scope:     $exportScope" -ForegroundColor White
Write-Host "   Migrate Sprints:  $(if ($migrateSprints) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($migrateSprints) { "Green" } else { "Gray" })
Write-Host "   Include SubTasks: $(if ($includeSubTasks) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($includeSubTasks) { "Green" } else { "Gray" })
Write-Host ""
Write-Host "📁 Files:" -ForegroundColor Yellow
Write-Host "   Location:       $projectPath" -ForegroundColor White
Write-Host "   Config:         parameters.json" -ForegroundColor Gray
Write-Host "   Dashboard:      out\migration_progress.html" -ForegroundColor Gray
Write-Host ""

# =============================================================================
# AUTO-LAUNCH MIGRATION
# =============================================================================

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Launching AUTO-RUN mode for project: $SourceKey" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will run all migration steps automatically." -ForegroundColor White
Write-Host "The process will run continuously without pauses." -ForegroundColor White
Write-Host ""
Write-Host "📊 Dashboard will open automatically..." -ForegroundColor Cyan
Start-Sleep -Seconds 1

$runMigrationScript = Join-Path $PSScriptRoot "RunMigration.ps1"
& $runMigrationScript -Project $SourceKey -AutoRun

# =============================================================================
# FINALIZE LOG
# =============================================================================

Complete-MigrationLog -Success:$true -Summary "Standard project $SourceKey created successfully and ready for migration. All configuration files generated with standard settings."

Write-Host "`n📄 Complete log available at:" -ForegroundColor Cyan
Write-Host "   $script:LogFile`n" -ForegroundColor White
