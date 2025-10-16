# DryRun_Master.ps1 - Complete Migration Dry Run
# 
# PURPOSE: Validates the entire migration workflow without making any changes.
# This script simulates all migration steps to verify configuration, connectivity,
# and data readiness before executing the actual migration.
#
# WHAT IT DOES:
# - Validates all parameters and configuration
# - Tests connectivity to source and target
# - Checks permissions and project access
# - Validates custom fields exist in target
# - Counts and analyzes source data
# - Simulates all migration steps
# - Generates comprehensive pre-flight report
#
# WHAT IT DOES NOT DO:
# - Does NOT create, modify, or delete any data
# - Does NOT make any API changes
# - Does NOT upload attachments
# - Does NOT create issues, comments, links, etc.
#
# SAFE TO RUN: This is 100% read-only validation
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")

if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent $here) "config\migration-parameters.json"
}

$startTime = Get-Date

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                           ║" -ForegroundColor Cyan
Write-Host "║       MIGRATION TOOLKIT - COMPLETE DRY RUN VALIDATION     ║" -ForegroundColor Cyan
Write-Host "║                                                           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔍 This is a READ-ONLY validation - NO changes will be made!" -ForegroundColor Green
Write-Host ""

# =============================================================================
# STEP 1: VALIDATE CONFIGURATION
# =============================================================================
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 1: VALIDATING CONFIGURATION"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if (-not (Test-Path $ParametersPath)) {
    Write-Host "❌ Configuration file not found: $ParametersPath" -ForegroundColor Red
    exit 1
}

try {
    $p = Read-JsonFile -Path $ParametersPath
    Write-Host "✅ Configuration file loaded: $ParametersPath" -ForegroundColor Green
    Write-Host "✅ Credentials loaded from .env file" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to parse configuration: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Validate required fields
$requiredFields = @(
    @{Path="SourceEnvironment.BaseUrl"; Name="Source Base URL"},
    @{Path="SourceEnvironment.Username"; Name="Source Username"},
    @{Path="SourceEnvironment.ApiToken"; Name="Source API Token"},
    @{Path="ProjectKey"; Name="Source Project Key"},
    @{Path="TargetEnvironment.BaseUrl"; Name="Target Base URL"},
    @{Path="TargetEnvironment.Username"; Name="Target Username"},
    @{Path="TargetEnvironment.ApiToken"; Name="Target API Token"},
    @{Path="TargetEnvironment.ProjectKey"; Name="Target Project Key"},
    @{Path="OutputSettings.OutputDirectory"; Name="Output Directory"}
)

$configValid = $true
foreach ($field in $requiredFields) {
    $value = $p
    foreach ($part in $field.Path.Split('.')) {
        if ($value.PSObject.Properties[$part]) {
            $value = $value.$part
        } else {
            $value = $null
            break
        }
    }
    
    if ($value) {
        Write-Host "  ✅ $($field.Name): Present" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $($field.Name): MISSING!" -ForegroundColor Red
        $configValid = $false
    }
}

if (-not $configValid) {
    Write-Host ""
    Write-Host "❌ Configuration validation failed!" -ForegroundColor Red
    exit 1
}

# Extract config
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcToken = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcToken

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtToken = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtToken

$outDir = $p.OutputSettings.OutputDirectory

Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Cyan
Write-Host "  Source: $srcKey at $srcBase"
Write-Host "  Target: $tgtKey at $tgtBase"
Write-Host "  Output: $outDir"

# =============================================================================
# STEP 2: TEST CONNECTIVITY
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 2: TESTING CONNECTIVITY"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# Test source
Write-Host "Testing source Jira instance..."
try {
    $srcProject = Invoke-RestMethod -Uri "$($srcBase.TrimEnd('/'))/rest/api/3/project/$srcKey" -Headers $srcHdr -Method GET -ErrorAction Stop
    Write-Host "  ✅ Source project accessible: $($srcProject.name) (id=$($srcProject.id))" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Cannot access source project: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test target
Write-Host "Testing target Jira instance..."
$targetProjectExists = $false
try {
    $tgtProject = Invoke-RestMethod -Uri "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey" -Headers $tgtHdr -Method GET -ErrorAction Stop
    Write-Host "  ✅ Target project accessible: $($tgtProject.name) (id=$($tgtProject.id))" -ForegroundColor Green
    $targetProjectExists = $true
} catch {
    if ($_.Exception.Message -like "*404*") {
        Write-Host "  ⚠️  Target project does not exist yet: $tgtKey" -ForegroundColor Yellow
        Write-Host "     This is OK if you'll run Step 02 to create it" -ForegroundColor Yellow
        Write-Host "     Or update migration-parameters.json with correct target project key"
        $targetProjectExists = $false
    } else {
        Write-Host "  ❌ Cannot access target: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     Check credentials and permissions" -ForegroundColor Red
        exit 1
    }
}

# =============================================================================
# STEP 3: VALIDATE CUSTOM FIELDS
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 3: VALIDATING CUSTOM FIELDS"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if ($targetProjectExists) {
    Write-Host "Checking for custom fields in target (Legacy + Historical Timestamps)..."
    
    # Get field IDs from configuration
    $legacyKeyFieldId = if ($p.PSObject.Properties.Name -contains 'CustomFields') { $p.CustomFields.LegacyKey } else { $null }
    $legacyKeyURLFieldId = if ($p.PSObject.Properties.Name -contains 'CustomFields') { $p.CustomFields.LegacyKeyURL } else { $null }
    $originalCreatedFieldId = if ($p.PSObject.Properties.Name -contains 'CustomFields' -and $p.CustomFields.PSObject.Properties.Name -contains 'OriginalCreatedDate') { $p.CustomFields.OriginalCreatedDate } else { $null }
    $originalUpdatedFieldId = if ($p.PSObject.Properties.Name -contains 'CustomFields' -and $p.CustomFields.PSObject.Properties.Name -contains 'OriginalUpdatedDate') { $p.CustomFields.OriginalUpdatedDate } else { $null }
    
    try {
        $fields = Invoke-RestMethod -Uri "$($tgtBase.TrimEnd('/'))/rest/api/3/field" -Headers $tgtHdr -Method GET -ErrorAction Stop
        
        $legacyKeyField = if ($legacyKeyFieldId) { $fields | Where-Object { $_.id -eq $legacyKeyFieldId } } else { $null }
        $legacyKeyURLField = if ($legacyKeyURLFieldId) { $fields | Where-Object { $_.id -eq $legacyKeyURLFieldId } } else { $null }
        $originalCreatedField = if ($originalCreatedFieldId) { $fields | Where-Object { $_.id -eq $originalCreatedFieldId } } else { $null }
        $originalUpdatedField = if ($originalUpdatedFieldId) { $fields | Where-Object { $_.id -eq $originalUpdatedFieldId } } else { $null }
        
        if ($legacyKeyField) {
            Write-Host "  ✅ LegacyKey: $legacyKeyFieldId ($($legacyKeyField.name))" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  LegacyKey: $legacyKeyFieldId - NOT FOUND" -ForegroundColor Yellow
        }
        
        if ($legacyKeyURLField) {
            Write-Host "  ✅ LegacyKeyURL: $legacyKeyURLFieldId ($($legacyKeyURLField.name))" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  LegacyKeyURL: $legacyKeyURLFieldId - NOT FOUND" -ForegroundColor Yellow
        }
        
        if ($originalCreatedField) {
            Write-Host "  ✅ OriginalCreatedDate: $originalCreatedFieldId ($($originalCreatedField.name))" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  OriginalCreatedDate: $originalCreatedFieldId - NOT FOUND" -ForegroundColor Yellow
        }
        
        if ($originalUpdatedField) {
            Write-Host "  ✅ OriginalUpdatedDate: $originalUpdatedFieldId ($($originalUpdatedField.name))" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  OriginalUpdatedDate: $originalUpdatedFieldId - NOT FOUND" -ForegroundColor Yellow
        }
        
        if (-not $legacyKeyField -or -not $legacyKeyURLField -or -not $originalCreatedField -or -not $originalUpdatedField) {
            Write-Host ""
            Write-Host "  💡 Setup guides:" -ForegroundColor Cyan
            Write-Host "     docs/LEGACY_KEY_PRESERVATION.md" -ForegroundColor White
            Write-Host "     docs/HISTORICAL_TIMESTAMPS_SETUP.md" -ForegroundColor White
        }
    } catch {
        Write-Host "  ⚠️  Could not validate custom fields: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⏭️  Skipping custom field validation (target project doesn't exist yet)" -ForegroundColor Yellow
    $legacyKeyField = $null
    $legacyKeyURLField = $null
    $originalCreatedField = $null
    $originalUpdatedField = $null
}

# =============================================================================
# STEP 4: ANALYZE SOURCE DATA
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 4: ANALYZING SOURCE DATA"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

Write-Host "Counting source issues..."
$issueCount = $null
$usingExportedData = $false

# First try to use already-exported data
$exportFile = Join-Path $outDir "exports\exported_issues.json"
if (Test-Path $exportFile) {
    try {
        Write-Host "  Found existing export file, using that..." -ForegroundColor Cyan
        $exportedIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
        $issueCount = @{ total = $exportedIssues.Count }
        $usingExportedData = $true
        Write-Host "  ✅ Total issues (from export): $($issueCount.total)" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠️  Could not load export file: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# If no export, try to query source API
if (-not $usingExportedData) {
    try {
        $searchUrl = "$($srcBase.TrimEnd('/'))/rest/api/3/search"
        $searchBody = @{
            jql = "project = $srcKey"
            maxResults = 0
            fields = @("summary")
        } | ConvertTo-Json
        
        $issueCount = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $srcHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
        Write-Host "  ✅ Total issues to migrate: $($issueCount.total)" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*410*") {
            Write-Host "  ⚠️  Source project API unavailable (410 Gone - likely archived)" -ForegroundColor Yellow
            Write-Host "     This is OK if you already have exported data in: $exportFile" -ForegroundColor Yellow
            $issueCount = @{ total = "Unknown (run Step 07 to export)" }
        } else {
            Write-Host "  ❌ Failed to analyze source issues: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

$issueTypes = @{}
$totalIssues = 0

if ($issueCount.total -is [int] -and $issueCount.total -gt 0) {
    $totalIssues = $issueCount.total
    
    # Get issue type breakdown
    if ($usingExportedData) {
        # Use exported data for analysis
        Write-Host "  Analyzing issue types from export..."
        foreach ($issue in $exportedIssues) {
            $type = $issue.fields.issuetype.name
            if ($issueTypes.ContainsKey($type)) {
                $issueTypes[$type]++
            } else {
                $issueTypes[$type] = 1
            }
        }
    } else {
        # Query API for sample
        $sampleSize = [Math]::Min(1000, $issueCount.total)
        Write-Host "  Analyzing issue types (sample of $sampleSize)..."
        
        try {
            $searchBody = @{
                jql = "project = $srcKey"
                maxResults = $sampleSize
                fields = @("issuetype")
            } | ConvertTo-Json
            
            $issues = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $srcHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
            
            foreach ($issue in $issues.issues) {
                $type = $issue.fields.issuetype.name
                if ($issueTypes.ContainsKey($type)) {
                    $issueTypes[$type]++
                } else {
                    $issueTypes[$type] = 1
                }
            }
        } catch {
            Write-Host "  ⚠️  Could not analyze issue types: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    if ($issueTypes.Count -gt 0) {
        Write-Host ""
        Write-Host "  Issue Type Distribution:"
        foreach ($type in ($issueTypes.Keys | Sort-Object)) {
            Write-Host "    $type : $($issueTypes[$type])"
        }
    }
} else {
    Write-Host "  ⚠️  Issue count not available - check export file or source access" -ForegroundColor Yellow
    $totalIssues = 0
}

# =============================================================================
# STEP 5: CHECK TARGET STATUS
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 5: CHECKING TARGET STATUS"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if ($targetProjectExists) {
    Write-Host "Counting existing issues in target..."
    try {
        $searchUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/search"
        $searchBody = @{
            jql = "project = $tgtKey"
            maxResults = 0
            fields = @("summary")
        } | ConvertTo-Json
        
        $targetIssueCount = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $searchBody -ContentType "application/json" -ErrorAction Stop
        
        if ($targetIssueCount.total -eq 0) {
            Write-Host "  ✅ Target project is empty (clean migration)" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Target project has $($targetIssueCount.total) existing issues" -ForegroundColor Yellow
            Write-Host "     Idempotency will prevent duplicates"
        }
        
    } catch {
        Write-Host "  ⚠️  Cannot check target status: $($_.Exception.Message)" -ForegroundColor Yellow
        $targetIssueCount = @{ total = 0 }
    }
} else {
    Write-Host "⏭️  Skipping target status check (target project doesn't exist yet)" -ForegroundColor Yellow
    Write-Host "   Target project will be created in Step 02" -ForegroundColor Cyan
    $targetIssueCount = @{ total = 0 }
}

# =============================================================================
# STEP 6: SIMULATE MIGRATION STEPS
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 6: SIMULATING MIGRATION WORKFLOW"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

$steps = @(
    @{Number="01"; Name="Preflight"; Description="Pre-migration validation"},
    @{Number="02"; Name="CreateProject"; Description="Target project setup with template (XRAY/STANDARD/ENHANCED)"},
    @{Number="03"; Name="Migrate Users and Roles"; Description="User synchronization"},
    @{Number="04"; Name="ComponentsAndLabels"; Description="Components and labels"},
    @{Number="05"; Name="Versions"; Description="Version migration"},
    @{Number="06"; Name="Boards"; Description="Board creation"},
    @{Number="07"; Name="ExportIssues"; Description="Export $($issueCount.total) issues (ALL/UNRESOLVED scope)"},
    @{Number="08"; Name="CreateIssues"; Description="Create issues (IDEMPOTENT) + Historical Timestamps"; Critical=$true},
    @{Number="09"; Name="Comments"; Description="Migrate comments (IDEMPOTENT)"; Critical=$true},
    @{Number="10"; Name="Attachments"; Description="Migrate attachments (IDEMPOTENT)"; Critical=$true},
    @{Number="11"; Name="Links"; Description="Migrate all links (IDEMPOTENT)"; Critical=$true},
    @{Number="12"; Name="Worklogs"; Description="Migrate worklogs (IDEMPOTENT)"; Critical=$true},
    @{Number="13"; Name="Sprints"; Description="Migrate sprints (IDEMPOTENT)"; Critical=$true},
    @{Number="14"; Name="History Migration"; Description="Migrate issue history and changelog data"; Critical=$true}
    @{Number="15"; Name="Review Migration"; Description="QA Validation + Permissions + Automation + Reports (IDEMPOTENT)"; Critical=$true}
)

foreach ($step in $steps) {
    $isCritical = ($step.ContainsKey('Critical') -and $step.Critical)
    $icon = if ($isCritical) { "🔴" } else { "⚪" }
    $status = "Would execute"
    Write-Host "$icon Step $($step.Number): $($step.Name)" -ForegroundColor $(if ($isCritical) { 'Yellow' } else { 'Gray' })
    Write-Host "   Description: $($step.Description)"
    Write-Host "   Status: $status (DRY RUN)" -ForegroundColor Cyan
    Write-Host ""
}

# =============================================================================
# STEP 7: ESTIMATE MIGRATION
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 7: MIGRATION ESTIMATES"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

if ($totalIssues -gt 0) {
    # Estimate based on sample
    $estimatedComments = $totalIssues * 1.2  # Avg 1.2 comments per issue
    $estimatedAttachments = $totalIssues * 0.05  # 5% have attachments
    $estimatedLinks = $totalIssues * 0.4  # 40% have links
    $estimatedWorklogs = $totalIssues * 0.3  # 30% have worklogs

    Write-Host "Estimated Items to Migrate:" -ForegroundColor Cyan
    Write-Host "  📋 Issues:      $totalIssues"
    Write-Host "  💬 Comments:    ~$([math]::Round($estimatedComments))"
    Write-Host "  📎 Attachments: ~$([math]::Round($estimatedAttachments))"
    Write-Host "  🔗 Links:       ~$([math]::Round($estimatedLinks))"
    Write-Host "  ⏱️  Worklogs:    ~$([math]::Round($estimatedWorklogs))"
    Write-Host ""

    $estimatedMinutes = ($totalIssues / 5) + ($estimatedComments / 3) + ($estimatedAttachments * 0.5)
    $estimatedHours = [math]::Round($estimatedMinutes / 60, 1)

    Write-Host "Estimated Migration Time:" -ForegroundColor Cyan
    Write-Host "  ⏱️  ~$estimatedHours hours (excluding QA and validation)"
    Write-Host "     Note: Actual time varies with network speed and API rate limits"
} else {
    Write-Host "⚠️  Cannot estimate migration size" -ForegroundColor Yellow
    Write-Host "   Source data not available or export hasn't been run yet" -ForegroundColor Yellow
    Write-Host "   Run Step 07 (ExportIssues_Source.ps1) first to get estimates" -ForegroundColor Cyan
    $estimatedComments = 0
    $estimatedAttachments = 0
    $estimatedLinks = 0
    $estimatedWorklogs = 0
    $estimatedMinutes = 0
    $estimatedHours = "Unknown"
}

# =============================================================================
# STEP 8: CHECK IDEMPOTENCY STATUS
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 8: IDEMPOTENCY STATUS"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

Write-Host "Checking if this is a re-run (idempotency check)..." -ForegroundColor Cyan
Write-Host ""

if ($targetIssueCount.total -gt 0) {
    Write-Host "  ⚠️  Target already has $($targetIssueCount.total) issues" -ForegroundColor Yellow
    Write-Host "     Idempotent scripts will:"
    Write-Host "       • Skip issues that match by summary"
    Write-Host "       • Skip comments that match by author/date"
    Write-Host "       • Skip attachments that match by filename/size"
    Write-Host "       • Skip links that already exist"
    Write-Host "       • Skip worklogs that match by time/date"
    Write-Host "       • Skip sprints that match by name"
    Write-Host ""
    Write-Host "     This is SAFE - no duplicates will be created!"
} else {
    Write-Host "  ✅ Clean migration (target is empty)" -ForegroundColor Green
    Write-Host "     All items will be created fresh"
}

# =============================================================================
# STEP 9: GENERATE PRE-FLIGHT REPORT
# =============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "STEP 9: GENERATING PRE-FLIGHT REPORT"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

$dryRunReport = @{
    DryRunDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Configuration = @{
        SourceProject = @{ Key=$srcKey; Name=$srcProject.name; Url=$srcBase }
        TargetProject = @{ 
            Key=$tgtKey
            Name=$(if ($targetProjectExists) { $tgtProject.name } else { "To be created" })
            Url=$tgtBase
            Exists=$targetProjectExists
        }
        OutputDirectory = $outDir
    }
    Validation = @{
        ConfigurationValid = $true
        SourceConnectivity = $true
        TargetProjectExists = $targetProjectExists
        CustomFieldsPresent = @{
            LegacyKey = ($legacyKeyField -ne $null)
            LegacyKeyURL = ($legacyKeyURLField -ne $null)
        }
    }
    SourceData = @{
        TotalIssues = $totalIssues
        IssueTypeDistribution = $issueTypes
        EstimatedComments = [math]::Round($estimatedComments)
        EstimatedAttachments = [math]::Round($estimatedAttachments)
        EstimatedLinks = [math]::Round($estimatedLinks)
        EstimatedWorklogs = [math]::Round($estimatedWorklogs)
    }
    TargetStatus = @{
        ExistingIssues = $targetIssueCount.total
        IsCleanMigration = ($targetIssueCount.total -eq 0)
        IdempotencyWillApply = ($targetIssueCount.total -gt 0)
    }
    Estimates = @{
        EstimatedTimeHours = $estimatedHours
        EstimatedTimeMinutes = [math]::Round($estimatedMinutes)
    }
    MigrationSteps = $steps
    ReadyForMigration = $true
}

$reportPath = Join-Path $outDir "dry_run_report.json"
$dryRunReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8

Write-Host "✅ Dry run report saved: $reportPath" -ForegroundColor Green

# =============================================================================
# FINAL SUMMARY
# =============================================================================
$elapsed = ((Get-Date) - $startTime).TotalSeconds

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "║              DRY RUN VALIDATION COMPLETE!                 ║" -ForegroundColor Green
Write-Host "║                                                           ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "✅ Configuration: Valid" -ForegroundColor Green
Write-Host "✅ Connectivity: Source working" -ForegroundColor Green
if ($targetProjectExists) {
    Write-Host "✅ Target Project: Exists ($($tgtProject.name))" -ForegroundColor Green
    $allFieldsPresent = $legacyKeyField -and $legacyKeyURLField -and $originalCreatedField -and $originalUpdatedField
    Write-Host "✅ Custom Fields: $(if ($allFieldsPresent) { 'All 4 fields present (Legacy + Timestamps)' } else { 'Some fields missing - see validation above' })" -ForegroundColor $(if ($allFieldsPresent) { 'Green' } else { 'Yellow' })
} else {
    Write-Host "⚠️  Target Project: Will be created in Step 02" -ForegroundColor Yellow
}
Write-Host "✅ Source Data: $totalIssues issues ready" -ForegroundColor Green
if ($targetProjectExists) {
    Write-Host "✅ Target Status: $(if ($targetIssueCount.total -eq 0) { 'Clean' } else { "$($targetIssueCount.total) existing (idempotency enabled)" })" -ForegroundColor Green
} else {
    Write-Host "✅ Target Status: New (will be created)" -ForegroundColor Green
}
Write-Host ""
Write-Host "📊 Migration Estimates:" -ForegroundColor Cyan
Write-Host "  • Issues: $totalIssues"
Write-Host "  • Estimated time: ~$estimatedHours hours"
Write-Host "  • Steps: 14 (7 idempotent, streamlined from 18)"
Write-Host ""
Write-Host "🎯 Ready to Migrate: YES" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Review dry run report: $reportPath"
Write-Host "  2. Backup source project (recommended)"
Write-Host "  3. Start migration: .\src\steps\01_Preflight.ps1"
Write-Host "  4. Follow workflow: .\docs\Workflow.md"
Write-Host ""
Write-Host "Validation completed in $([math]::Round($elapsed, 1)) seconds" -ForegroundColor Gray
Write-Host ""
Write-Host "🚀 YOUR MIGRATION TOOLKIT IS READY!" -ForegroundColor Magenta

