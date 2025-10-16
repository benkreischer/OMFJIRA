# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a **Jira Migration Toolkit** - an enterprise-grade, production-ready system for migrating Jira projects between instances. The toolkit is modular, idempotent, and config-driven, handling complete project migrations including issues, comments, attachments, links, worklogs, sprints, users, and roles.

## Quick Command Reference

### Running Migrations

```powershell
# Launch web-based configuration UI
.\Launch-WebUI.ps1

# Create a new project configuration
.\CreateNewProject.ps1 -ProjectKey ABC

# Run full automated migration
.\RunMigration.ps1 -Project ABC -AutoRun

# Run specific step
.\RunMigration.ps1 -Project ABC -Step 08

# Run QA validation (step 15)
.\RunMigration.ps1 -Project ABC -Step 15

# Dry run validation
.\RunMigration.ps1 -Project ABC -DryRun

# List available projects
.\RunMigration.ps1 -ListProjects
```

### Utility Scripts

```powershell
# Check project permissions
.\src\Utility\CheckProjectPermissions.ps1 -ParametersPath ".\projects\ABC\parameters.json"

# Create user invitation list
.\src\Utility\CreateUserInvitationList.ps1 -ParametersPath ".\projects\ABC\parameters.json"

# Update issue assignees
.\src\Utility\UpdateIssueAssignees.ps1 -ParametersPath ".\projects\ABC\parameters.json"

# Restore skipped links
.\src\Utility\11_RestoreSkippedLinks.ps1 -ParametersPath ".\projects\ABC\parameters.json"

# Delete components
.\src\Utility\04_DeleteComponents.ps1 -ProjectKey ABC

# Delete all issues (cleanup)
.\src\Utility\08_DeleteAllIssues.ps1 -ProjectKey ABC1 -TargetEnv
```

## Architecture

### Core Design Principles

1. **Idempotent Execution**: All steps can be safely re-run. Receipt files track completion state.
2. **Config-Driven**: Global defaults in `config/migration-parameters.json`, per-project overrides in `projects/[KEY]/parameters.json`.
3. **Modular Steps**: 16 distinct migration steps that can run independently or in sequence.
4. **Receipt System**: Each step generates a `{STEP}_{NAME}_receipt.json` file for tracking and idempotency.

### Directory Structure

```
Migration/
├─ config/
│  └─ migration-parameters.json      # Global configuration template
├─ src/
│  ├─ _common.ps1                    # Shared helper functions (auth, JSON, logging)
│  ├─ _dashboard.ps1                 # Dashboard generation and reporting
│  ├─ steps/                         # Migration step scripts (01-15)
│  │  ├─ 01_Preflight.ps1
│  │  ├─ 02_CreateProject_FromSharedConfig.ps1
│  │  ├─ 03_SyncUsersAndRoles.ps1
│  │  ├─ 04_ComponentsAndLabels.ps1
│  │  ├─ 05_Versions.ps1
│  │  ├─ 06_Boards.ps1
│  │  ├─ 07_ExportIssues_Source.ps1
│  │  ├─ 08_CreateIssues_Target.ps1
│  │  ├─ 09_Comments.ps1
│  │  ├─ 10_Attachments.ps1
│  │  ├─ 11_Links.ps1
│  │  ├─ 12_Worklogs.ps1
│  │  ├─ 13_Sprints.ps1
│  │  ├─ 14_HistoryMigration.ps1
│  │  └─ 15_ReviewMigration.ps1
│  └─ Utility/                       # Helper utilities for troubleshooting
├─ projects/                         # Per-project configurations and outputs
│  └─ [PROJECT_KEY]/
│     ├─ parameters.json             # Project-specific configuration
│     └─ out/                        # Migration outputs
│        ├─ logs/                    # Execution logs
│        ├─ exports/                 # Exported data
│        ├─ *_receipt.json           # Step completion receipts
│        └─ migration_progress.html  # Live progress dashboard
├─ docs/                             # Comprehensive documentation
├─ Launch-WebUI.ps1                  # Web-based configuration launcher
├─ CreateNewProject.ps1              # Project scaffolding script
├─ RunMigration.ps1                  # Main migration orchestrator (interactive/single-step)
└─ Run-All.ps1                       # Automated full migration with live dashboard
```

### Key Components

#### `src/_common.ps1`
Shared utility functions loaded by all steps:
- `Read-JsonFile`: Loads configuration with .env credential merging
- `New-BasicAuthHeader`: Creates Jira API authentication headers
- `Get-EnvVariables`: Parses .env files for credentials
- `Write-StageReceipt`: Creates receipt files for idempotency tracking
- SSL/TLS configuration for HTTPS connections

#### `src/_dashboard.ps1`
Dashboard generation and reporting:
- `$script:AllMigrationSteps`: Ordered dictionary of all 16 migration steps
- `Get-StepStatus`: Checks completion status via receipt files
- `Format-ReceiptSummary`: Generates HTML summaries for each step
- Interactive HTML dashboard generation with verification links

#### `src/_logging.ps1`
Centralized logging and monitoring:
- `Initialize-MigrationLog`: Creates timestamped log files in markdown format
- `Write-LogStep`, `Write-LogInfo`, `Write-LogSuccess`, `Write-LogError`: Structured logging functions
- `Write-LogWarning`: Highlights important warnings
- Automatic log continuation for multi-step runs

#### Step Scripts (`src/steps/*.ps1`)
Each step:
- Accepts `-ParametersPath` parameter pointing to `projects/[KEY]/parameters.json`
- Sources `_common.ps1` for shared functions
- Writes receipt file on completion
- Logs to project's `out/logs/` directory
- Returns exit code 0 on success

### Configuration System

#### Global Template: `config/migration-parameters.json`
Contains default settings for:
- Environment URLs and credentials
- Project creation templates (XRAY, STANDARD, ENHANCED)
- Issue export scope (ALL vs UNRESOLVED)
- Status and issue type mappings
- Custom field definitions
- Sprint settings and board resolution
- User mapping configuration

#### Project Override: `projects/[KEY]/parameters.json`
Overrides global settings for specific project. Key sections:
- `ProjectKey`: Source project key
- `ProjectName`: Source project name
- `SourceEnvironment`: Source Jira instance details
- `TargetEnvironment`: Target Jira instance details (includes TargetProjectKey)
- `ProjectCreation.ConfigurationTemplate`: Template choice ("XRAY", "STANDARD", or "ENHANCED")
- `IssueExportSettings.Scope`: Export scope ("UNRESOLVED" or "ALL")
- `LinkMigration.CreateRemoteLinksForSkipped`: Enable cross-project link fallback

#### Credentials: `.env`
Store API credentials outside version control:
```
USERNAME=user@example.com
JIRA_API_TOKEN=your_api_token_here
FALLBACK_PROJECT_LEAD_EMAIL=lead@example.com
```

### Migration Workflow (16 Steps)

1. **Preflight**: Validates configuration and Jira connectivity
2. **Create Project**: Creates target project from template (XRAY/STANDARD/ENHANCED)
3. **Users and Roles**: Syncs users and application roles
4. **Components and Labels**: Migrates project components and global labels
5. **Versions**: Migrates project versions
6. **Boards**: Creates boards (Scrum/Kanban)
7. **Export Issues**: Exports issues from source (scope: ALL or UNRESOLVED)
8. **Create Issues**: Creates issues in target with historical timestamps
9. **Comments**: Migrates comments with original authors/timestamps
10. **Attachments**: Downloads and uploads attachments
11. **Links**: Migrates issue links (including cross-project handling)
12. **Worklogs**: Migrates worklogs with original authors/times
13. **Sprints**: Migrates sprint assignments
14. **History**: Migrates issue history events
15. **Review**: Comprehensive QA validation and reporting (30+ checks)

### Receipt System

Receipt files in `projects/[KEY]/out/` track:
- Step completion status
- Execution timestamp
- Key metrics (counts, success/failure)
- Data mappings (issue key mappings, user mappings)
- Errors and warnings

Pattern: `{STEP_NUMBER}_{STEP_NAME}_receipt.json`

Example: `08_CreateIssues_receipt.json` contains:
```json
{
  "IssueMapping": {
    "ABC-1": "ABC1-1",
    "ABC-2": "ABC1-2"
  },
  "TotalCreated": 123,
  "Errors": [],
  "TimeUtc": "2025-10-12T10:30:00Z"
}
```

### Special Features

#### Historical Timestamp Preservation
Issues, comments, and worklogs maintain original created/updated timestamps and author attribution through Jira's `updateHistory=true` API parameter.

#### Legacy Key Tracking
Custom fields store original issue keys for audit trail:
- `customfield_10400`: Legacy Key URL
- `customfield_10401`: Legacy Key
- `customfield_10402`: Original Created Date
- `customfield_10403`: Original Updated Date

#### Cross-Project Link Handling
When direct links can't be migrated (cross-project), optional remote links preserve relationships. See `LinkMigration.CreateRemoteLinksForSkipped` setting.

#### Sprint Migration
Auto-detects source board, creates target board, and preserves sprint assignments including closed/future sprints.

## Development Patterns

### Adding a New Step

1. Create `src/steps/XX_StepName.ps1`
2. Include param block: `param([string] $ParametersPath)`
3. Source common functions: `. (Join-Path (Split-Path -Parent $here) "_common.ps1")`
4. Load config: `$p = Read-JsonFile -Path $ParametersPath`
5. Write receipt on completion: `Write-StageReceipt -OutDir $p.OutputSettings.OutputDirectory -Stage "XX_StepName" -Data @{...}`
6. Add to `$script:AllMigrationSteps` in `src/_dashboard.ps1`

### API Call Pattern

```powershell
# Load parameters
$p = Read-JsonFile -Path $ParametersPath

# Create auth headers
$srcHdr = New-BasicAuthHeader -Email $p.SourceEnvironment.Username -ApiToken $p.SourceEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $p.TargetEnvironment.Username -ApiToken $p.TargetEnvironment.ApiToken

# Make API call
$response = Invoke-RestMethod -Method GET -Uri $uri -Headers $srcHdr -ContentType "application/json"
```

### Error Handling

```powershell
try {
    # API operations
} catch {
    Write-Warning "Operation failed: $($_.Exception.Message)"
    # Log to error collection
    $errors += @{
        Operation = "Description"
        Error = $_.Exception.Message
    }
}
```

### Idempotency Pattern

```powershell
# Check if step already completed
$receiptPath = Join-Path $p.OutputSettings.OutputDirectory "08_CreateIssues_receipt.json"
if (Test-Path $receiptPath) {
    $existingReceipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
    # Use existing mappings or skip
}
```

## Testing and Validation

### Dry Run Mode
Validates configuration without making changes:
```powershell
.\RunMigration.ps1 -Project ABC -DryRun
```

### QA Validation (Step 15)
Comprehensive validation suite with 30+ checks:
- Issue counts and duplicates
- Custom field data integrity
- Comments, attachments, links, worklogs verification
- Cross-step consistency validation
- Generates interactive HTML dashboard with drill-down

Output: `projects/[KEY]/out/master_qa_dashboard.html`

### Permission Validation
```powershell
.\src\Utility\CheckProjectPermissions.ps1 -ParametersPath ".\projects\ABC\parameters.json"
```

## Troubleshooting

### Common Issues

**SSL/TLS Connection Errors**: See `docs/SSL_TROUBLESHOOTING_GUIDE.md`. The `_common.ps1` forces TLS 1.2/1.3.

**Missing Links**: Enable `CreateRemoteLinksForSkipped` in config. See `docs/HANDLING_LINKS_GUIDE.md`.

**Duplicate Issues**: Run QA validation (step 15) to identify, then use `src/Utility/08_RemoveDuplicatesIssues.ps1`.

**Permission Errors**: Run `CheckProjectPermissions.ps1` to generate permission validation report.

**Failed Comments/Attachments**: Use retry utilities:
- `src/Utility/09_RetryFailedComments.ps1`

### Recovery Patterns

1. Review receipt files in `projects/[KEY]/out/` to identify last successful step
2. Check logs in `projects/[KEY]/out/logs/`
3. Re-run failed step (idempotent design allows safe re-execution)
4. Use utility scripts for targeted fixes
5. Re-run QA validation to confirm

## Important Notes

- **Credentials**: Never commit `.env` files. API tokens in `.env` are merged at runtime.
- **Source/Target Naming**: Convention is `{KEY}` for source, `{KEY}1` for target (e.g., `ABC` → `ABC1`).
- **Template Projects**: XRAY/ENHANCED templates must exist in target instance before project creation.
- **Receipt Files**: Don't manually edit receipt files - they're used for idempotency tracking.
- **Parallel Execution**: Steps must run sequentially; dependencies between steps exist.

## Documentation

Comprehensive guides in `docs/`:
- `CONFIGURATION_OPTIONS.md`: Configuration reference
- `QA_VALIDATION_SYSTEM_GUIDE.md`: QA system details
- `HANDLING_LINKS_GUIDE.md`: Cross-project link handling
- `SSL_TROUBLESHOOTING_GUIDE.md`: Connection troubleshooting
- `MULTI_PROJECT_GUIDE.md`: Managing multiple projects
- `IDEMPOTENCY_COMPLETE.md`: Idempotency design details
- `QUICK_REFERENCE.md`: Quick command reference

## Web Launcher

`Launch-WebUI.ps1` provides a modern web interface for:
- Visual project configuration
- Template selection
- Scope configuration
- PowerShell command generation

Launches `MigrationLauncher.html` with embedded configuration UI.
