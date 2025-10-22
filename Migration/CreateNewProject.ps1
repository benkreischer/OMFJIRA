# =============================================================================
# CREATE NEW MIGRATION PROJECT
# =============================================================================
#
# DESCRIPTION: Creates a new migration project with XXX/XXX1 structure
# 
# USAGE: 
#   .\CreateNewProject.ps1 -ProjectKey "XXX"
#   .\CreateNewProject.ps1 -ProjectKey "XXX" -Force  # Overwrite existing project
#   .\CreateNewProject.ps1 -ProjectKey "XXX" -SourceBaseUrl "https://custom.atlassian.net/" -TargetBaseUrl "https://target.atlassian.net/" -UserEmail "user@company.com"
#
# CONFIGURATION:
#   Default values are loaded from config/migration-parameters.json:
#   - SourceEnvironment.BaseUrl
#   - TargetEnvironment.BaseUrl
#   - Username (from .env file or config)
#
#   You can override these with command-line parameters:
#   .\CreateNewProject.ps1 -ProjectKey "XXX" -SourceBaseUrl "https://custom.atlassian.net/" -TargetBaseUrl "https://target.atlassian.net/" -UserEmail "user@company.com"
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectKey,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetKey,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("XRAY", "STANDARD", "ENHANCED")]
    [string]$Template,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("UNRESOLVED", "ALL")]
    [string]$ExportScope,
    
    [Parameter(Mandatory=$false)]
    [bool]$MigrateSprints,
    
    [Parameter(Mandatory=$false)]
    [bool]$IncludeSubTasks,
    
    [Parameter(Mandatory=$false)]
    [string]$Description = "Migration from {0} to {0}1",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    
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

# Set default TargetKey if not provided
if (-not $TargetKey) {
    $TargetKey = "$ProjectKey" + "1"
}

# Validate project key format
if ($ProjectKey -notmatch '^[A-Z]{2,10}$') {
    Write-Error "ProjectKey must be 2-10 uppercase letters (e.g., 'XXX', 'ABC', 'PROJECT')"
    exit 1
}

# Validate target project key format
if ($TargetKey -notmatch '^[A-Z0-9]{2,10}$') {
    Write-Error "TargetKey must be 2-10 uppercase letters and numbers (e.g., 'XXX1', 'ABC1', 'PROJECT')"
    exit 1
}

# Check if project already exists and delete it if it does
$projectPath = Join-Path "projects" $ProjectKey
if (Test-Path $projectPath) {
    Write-Host "Project '$ProjectKey' already exists at '$projectPath'" -ForegroundColor Yellow
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
$tempOutDir = Join-Path "projects" "$ProjectKey\out"
if (-not (Test-Path $tempOutDir)) {
    New-Item -ItemType Directory -Path $tempOutDir -Force | Out-Null
}

# Initialize log
$script:LogFile = Initialize-MigrationLog -ProjectKey $ProjectKey -OutDir $tempOutDir -Operation "ProjectCreation"

Write-LogStep "Create New Migration Project: $ProjectKey"

Write-Host "`n📊 Log file: $script:LogFile" -ForegroundColor Cyan
Write-Host "💡 To monitor in another terminal: .\Watch-Log.ps1 -ProjectKey $ProjectKey`n" -ForegroundColor Yellow

Write-LogSubStep "Validation"
Write-LogSuccess "Project key format is valid: $ProjectKey" -Component "Validation"
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

# Fetch source project details
try {
    $srcProjectUri = "$($SourceBaseUrl.TrimEnd('/'))/rest/api/3/project/$ProjectKey"
    Write-LogInfo "Fetching project: $srcProjectUri" -Component "API"
    $srcProject = Invoke-RestMethod -Method GET -Uri $srcProjectUri -Headers $authHeader -ErrorAction Stop
    $actualProjectName = $srcProject.name
    $targetProjectName = "$actualProjectName Sandbox"
    
    Write-LogSuccess "Found project: $actualProjectName (Key: $ProjectKey)" -Component "API"
    Write-LogTable "Project Details" @{
        "Source Key" = $ProjectKey
        "Source Name" = $actualProjectName
        "Target Key" = $TargetKey
        "Target Name" = $targetProjectName
    }
} catch {
    if ($_.Exception.Message -match '404') {
        Write-LogWarning "Project '$ProjectKey' not found in source Jira" -Component "API"
        Write-LogInfo "Source URL: $SourceBaseUrl" -Component "API"
        Write-Host ""
        Write-Host "⚠️  WARNING: This project doesn't exist in the source Jira!" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The migration will still create the project configuration, but" -ForegroundColor Yellow
        Write-Host "Step 01 (Preflight) will fail unless you:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. Verify the project key '$ProjectKey' is correct" -ForegroundColor Cyan
        Write-Host "  2. Update the source URL in parameters.json if needed" -ForegroundColor Cyan
        Write-Host "  3. Confirm the project exists in your source Jira" -ForegroundColor Cyan
        Write-Host ""
        $continue = Read-Host "Continue anyway? (Y/N)"
        if ($continue -ne "Y" -and $continue -ne "y") {
            Write-LogInfo "Project creation cancelled by user" -Component "Config"
            Complete-MigrationLog -Success:$false -Summary "Cancelled - source project not found"
            exit 0
        }
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
    $projectDescription = "Migration from $ProjectKey ($actualProjectName) to $TargetKey ($targetProjectName)"
}

# =============================================================================
# MIGRATION CONFIGURATION PROMPTS
# =============================================================================

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  MIGRATION CONFIGURATION" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Configuration Template
if ($Template) {
    # Template provided via parameter
    $configTemplate = $Template
    Write-Host "1️⃣  Project Configuration Template" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ Using $configTemplate template (from parameter)" -ForegroundColor Green
} else {
    # Prompt for template choice
    Write-Host "1️⃣  Project Configuration Template" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [X] XRAY (Recommended)" -ForegroundColor Green
    Write-Host "   [S] Standard" -ForegroundColor White
    Write-Host "   [E] Enhanced" -ForegroundColor White
    Write-Host ""
    $templateChoice = Read-Host "   Choose template (X/S/E)"

    $configTemplate = "XRAY"
    if ($templateChoice -eq "S" -or $templateChoice -eq "s") {
        $configTemplate = "STANDARD"
        Write-Host "   ✅ Using STANDARD template" -ForegroundColor Green
    } elseif ($templateChoice -eq "E" -or $templateChoice -eq "e") {
        $configTemplate = "ENHANCED"
        Write-Host "   ✅ Using ENHANCED template" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Using XRAY template (default)" -ForegroundColor Green
    }
}

Write-Host ""

# 2. Export Scope
if ($ExportScope) {
    # Export scope provided via parameter
    $exportScope = $ExportScope
    Write-Host "2️⃣  Issue Export Scope" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ Will export $exportScope issues (from parameter)" -ForegroundColor Green
} else {
    # Prompt for export scope choice
    Write-Host "2️⃣  Issue Export Scope" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [U] Unresolved work items (Recommended)" -ForegroundColor Green
    Write-Host "   [A] All Issues including resolved work items" -ForegroundColor White
    Write-Host ""
    $scopeChoice = Read-Host "   Choose scope (U/A)"

    $exportScope = "UNRESOLVED"
    if ($scopeChoice -eq "A" -or $scopeChoice -eq "a") {
        $exportScope = "ALL"
        Write-Host "   ✅ Will export ALL issues (including closed)" -ForegroundColor Green
    } else {
        Write-Host "   ✅ Will export UNRESOLVED issues only (default)" -ForegroundColor Green
    }
}

Write-Host ""

# 3. Sprint Migration
if ($PSBoundParameters.ContainsKey('MigrateSprints')) {
    # Migrate sprints provided via parameter
    $migrateSprints = $MigrateSprints
    Write-Host "3️⃣  Migrate Sprints?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ Sprint migration $(if ($migrateSprints) { 'enabled' } else { 'disabled' }) (from parameter)" -ForegroundColor Green
} else {
    # Prompt for sprint migration choice
    Write-Host "3️⃣  Migrate Sprints?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [Y] YES - Migrate sprints with dates and goals (Recommended)" -ForegroundColor Green
    Write-Host "   [N] NO - Skip sprint migration" -ForegroundColor White
    Write-Host ""
    $sprintChoice = Read-Host "   Migrate sprints? (Y/N)"

    $migrateSprints = $true
    if ($sprintChoice -eq "N" -or $sprintChoice -eq "n") {
        $migrateSprints = $false
        Write-Host "   ⏭️  Sprint migration disabled" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Sprint migration enabled (default)" -ForegroundColor Green
    }
}

Write-Host ""

# 4. SubTasks
if ($PSBoundParameters.ContainsKey('IncludeSubTasks')) {
    # Include sub-tasks provided via parameter
    $includeSubTasks = $IncludeSubTasks
    Write-Host "4️⃣  Include SubTasks?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ Sub-tasks will be $(if ($includeSubTasks) { 'included' } else { 'excluded' }) (from parameter)" -ForegroundColor Green
} else {
    # Prompt for sub-tasks choice
    Write-Host "4️⃣  Include SubTasks?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   [Y] YES - Include sub-tasks (Recommended)" -ForegroundColor Green
    Write-Host "   [N] NO - Exclude sub-tasks" -ForegroundColor White
    Write-Host ""
    $subTaskChoice = Read-Host "   Include sub-tasks? (Y/N)"

    $includeSubTasks = $true
    if ($subTaskChoice -eq "N" -or $subTaskChoice -eq "n") {
        $includeSubTasks = $false
        Write-Host "   ⏭️  Sub-tasks will be excluded" -ForegroundColor Yellow
    } else {
        Write-Host "   ✅ Sub-tasks will be included (default)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# =============================================================================
# CREATE PROJECT STRUCTURE
# =============================================================================

Write-Host "Creating new migration project: $ProjectKey" -ForegroundColor Green
Write-Host "Source: $ProjectKey → Target: $TargetKey" -ForegroundColor Cyan

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
    ProjectKey = $ProjectKey
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
        BatchSize = 100
        RetryAttempts = 3
    }
    OutputSettings = [ordered]@{
        LogLevel = "INFO"
        GenerateHtmlReport = $true
        GenerateCsvReport = $true
        OpenReportInBrowser = $false
        OutputDirectory = "./projects/$ProjectKey/out"
        LogDirectory = "./projects/$ProjectKey/out/logs"
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
    # ProjectCreation: Template determines workflow/scheme for target project creation
    # IMPORTANT: Template (XRAY, STANDARD, ENHANCED) tells Jira what workflow to use
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

Write-LogTable "Template Configuration" @{
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
Write-LogSuccess "Created parameters.json with migration settings" -Component "Config"
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
    $readmeContent = $readmeContent -replace '\{PROJECT_KEY\}', $ProjectKey
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
# ... continue through Step 18
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

### Phase 3: Configuration (Steps 13-15)

- [ ] **Step 13: Automation Guide**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 13
  ```
  Generates interactive HTML guide for automation rules

- [ ] **Step 14: Permissions & Schemes**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 14
  ```
  Generates validation checklist, runs automated tests

- [ ] **Step 13: Migrate Sprints** ✅ IDEMPOTENT
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 13
  ```
  Migrates closed sprints with dates and goals

### Phase 4: Validation & Finalization (Steps 16-18)

- [ ] **Step 16: QA Validation ⭐ CRITICAL**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 16
  ```
  Runs comprehensive quality checks
  - Generates interactive HTML dashboard
  - Checks duplicates, field accuracy, links
  - Provides quality score

- [ ] **Step 17: Finalize & Communications**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 17
  ```
  Generates notification templates
  Archives migration documentation

- [ ] **Step 18: Post-Migration Reports ⭐ CRITICAL**
  ```powershell
  .\RunMigration.ps1 -Project {PROJECT_KEY} -Step 18
  ```
  Generates final comprehensive reports
  - HTML report (visual overview)
  - CSV report (detailed data)
  - JSON report (complete data)
  - Skipped links analysis

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
| **Configuration** | 13-15 | Automation, permissions, sprints |
| **Validation** | 16-18 | QA checks, reports |

---

## ⚠️ Critical: Don't Skip Steps!

**Each step builds on the previous ones:**
- Step 07 exports data → Step 08 uses it to create issues
- Step 08 creates key mappings → Steps 09-12 use them
- Step 06 creates boards → Step 15 uses them for sprints
- All steps create receipts → Step 16 validates them
- Step 16 validates → Step 18 includes QA results

**Common Mistakes to Avoid:**
- ❌ **Skipping Step 07** - Without export, nothing else will work  
- ❌ **Skipping Step 01** - Might miss configuration issues  
- ❌ **Skipping Step 06** - Sprints won't work without boards  
- ❌ **Skipping Step 16** - Won't know if migration succeeded  
- ❌ **Skipping Step 18** - No audit trail for stakeholders  

**✅ Run ALL steps 01-18 in order!**

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

**Steps 08-12 and 15 are IDEMPOTENT:**
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

**Then continue sequentially through Step 18!**

**All outputs will go to:** `.\projects\{PROJECT_KEY}\out\`

---

**Complete checklist = Successful migration!** ✅

**This migration uses the idempotent, legacy-key-enabled toolkit - safe and traceable!** 🌟
"@
    
    # Replace placeholders with actual values
    $readmeContent = $readmeContent -replace '\{PROJECT_KEY\}', $ProjectKey
    $readmeContent = $readmeContent -replace '\{CREATED_DATE\}', (Get-Date -Format "yyyy-MM-dd")
    
    $readmePath = Join-Path $projectPath "README.md"
    $readmeContent | Out-File -FilePath $readmePath -Encoding UTF8
    Write-LogSuccess "Created README.md (fallback)" -Component "Docs"
}

# =============================================================================
# COMPLETION SUMMARY
# =============================================================================

Write-LogStep "Project Creation Complete"

Write-LogSuccess "Project created successfully!" -Component "Summary"

Write-LogTable "Configuration Summary" @{
    "Project" = "$ProjectKey → $TargetKey"
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
Write-Host "║  🎉 PROJECT CREATED SUCCESSFULLY!                         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# =============================================================================
# CONFIGURATION SUMMARY
# =============================================================================

Write-Host "═══ CONFIGURATION SUMMARY ═══" -ForegroundColor Cyan
Write-Host ""
Write-Host "📁 Project:        $ProjectKey → $TargetKey" -ForegroundColor White
Write-Host "📋 Name:           $actualProjectName → $targetProjectName" -ForegroundColor White
Write-Host ""
Write-Host "🔵 SOURCE:" -ForegroundColor Cyan
Write-Host "   URL:            $SourceBaseUrl" -ForegroundColor White
Write-Host "   Project:        $ProjectKey" -ForegroundColor Gray
Write-Host ""
Write-Host "🟢 TARGET:" -ForegroundColor Green
Write-Host "   URL:            $TargetBaseUrl" -ForegroundColor White
Write-Host "   Project:        $TargetKey" -ForegroundColor Gray
Write-Host ""
Write-Host "⚙️  SETTINGS:" -ForegroundColor Yellow
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
Write-Host "🚀 Ready to start migration!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Choose next action:" -ForegroundColor White
Write-Host ""
Write-Host "  [Y] Migrate Step by Step (Recommended)" -ForegroundColor Green
Write-Host "  [A] Auto-Run All Steps" -ForegroundColor Yellow
Write-Host "  [D] Dry Run" -ForegroundColor Cyan
Write-Host "  [X] Exit" -ForegroundColor White
Write-Host ""
$launch = Read-Host "Choice (Y/A/D/X)"

if ($launch -eq "Y" -or $launch -eq "y" -or $launch -eq "") {
    Write-Host ""
    Write-Host "🚀 Launching step-by-step migration for project: $ProjectKey" -ForegroundColor Cyan
    Write-Host ""
    
    # Open HTML dashboard
    $dashboardPath = Join-Path $projectPath "out\migration_progress.html"
    if (Test-Path $dashboardPath) {
        Write-Host "📊 Opening progress dashboard..." -ForegroundColor Cyan
        Start-Process $dashboardPath
        Start-Sleep -Seconds 1
    }
    
    $runMigrationScript = Join-Path $PSScriptRoot "RunMigration.ps1"
    & $runMigrationScript -Project $ProjectKey -Interactive
    
} elseif ($launch -eq "A" -or $launch -eq "a") {
    Write-Host ""
    Write-Host "🚀 Launching AUTO-RUN mode for project: $ProjectKey" -ForegroundColor Cyan
    Write-Host ""
    
    # Open HTML dashboard (will be created by Auto-Run)
    Write-Host "📊 Dashboard will open automatically..." -ForegroundColor Cyan
    Start-Sleep -Seconds 1
    
    $runMigrationScript = Join-Path $PSScriptRoot "RunMigration.ps1"
    & $runMigrationScript -Project $ProjectKey -AutoRun
    
} elseif ($launch -eq "D" -or $launch -eq "d") {
    Write-Host ""
    Write-Host "🔍 Running DRY RUN validation for project: $ProjectKey" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This will validate configuration without making any changes..." -ForegroundColor Yellow
    Write-Host ""
    Start-Sleep -Seconds 1
    
    $runMigrationScript = Join-Path $PSScriptRoot "RunMigration.ps1"
    & $runMigrationScript -Project $ProjectKey -DryRun
    
} elseif ($launch -eq "X" -or $launch -eq "x") {
    Write-Host ""
    Write-Host "✅ Configuration created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "When ready to migrate, run one of:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Dry Run (validate):    .\RunMigration.ps1 -Project $ProjectKey -DryRun" -ForegroundColor Cyan
    Write-Host "  Interactive:           .\RunMigration.ps1 -Project $ProjectKey" -ForegroundColor Cyan
    Write-Host "  Auto-Run:              .\RunMigration.ps1 -Project $ProjectKey -AutoRun" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Dashboard will be available at:" -ForegroundColor Gray
    Write-Host "   .\projects\$ProjectKey\out\migration_progress.html" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Invalid choice: $launch" -ForegroundColor Red
    Write-Host "   Please choose Y, A, D, or X" -ForegroundColor Yellow
    Write-Host ""
}

# =============================================================================
# FINALIZE LOG
# =============================================================================

Complete-MigrationLog -Success:$true -Summary "Project $ProjectKey created successfully and ready for migration. All configuration files generated."

Write-Host "`n📄 Complete log available at:" -ForegroundColor Cyan
Write-Host "   $script:LogFile`n" -ForegroundColor White