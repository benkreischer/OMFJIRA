# Migration Configuration Options

This document describes the configuration options available for automated (non-interactive) migration runs.

## Overview

The migration system now supports **fully automated execution** via `Run-All.ps1` without requiring user input. All configuration choices are pre-defined in `migration-parameters.json`.

## Configuration Options

### 1. Project Configuration Template (Step 02)

**Location:** `ProjectCreation.ConfigurationTemplate` in `migration-parameters.json`

**Purpose:** Determines which project template to use when creating the target project.

**Options:**
- **`XRAY`** - Uses shared configuration from the XRAY reference project (default)
  - Copies: Schemes, workflows, screens, fields, issue types
  - Requires: `ProjectCreation.ConfigSourceProjectKey` (set to "XRAY")
  
- **`STANDARD`** - Creates a standard Jira project with default configuration
  - Uses: Default Jira project template (no shared configuration)
  - Configurable: `ProjectCreation.StandardProjectTypeKey` (default: "software")
  
- **`ENHANCED`** - Uses shared configuration from an ENHANCED reference project
  - Copies: Schemes, workflows, screens, fields, issue types
  - Requires: `ProjectCreation.EnhancedConfigSourceProjectKey` (set to "ENHANCED" or your template project key)

**Example Configuration:**

```json
"ProjectCreation": {
  "ConfigurationTemplate": "XRAY",
  "ConfigSourceProjectKey": "XRAY",
  "StandardProjectTypeKey": "software",
  "EnhancedConfigSourceProjectKey": "ENHANCED"
}
```

**When to Use Each Template:**
- **XRAY**: When you want to maintain consistency with existing XRAY-configured projects
- **STANDARD**: For simple projects or when you want to start with default Jira configuration
- **ENHANCED**: When you have a custom template project with advanced configuration

---

### 2. Issue Export Scope (Step 07)

**Location:** `IssueExportSettings.Scope` in `migration-parameters.json`

**Purpose:** Determines which issues to export from the source project.

**Options:**
- **`UNRESOLVED`** - Exports only unresolved issues (recommended for active projects)
  - Best for: Migrating active work without historical closed issues
  - JQL: `project = KEY AND resolution = Unresolved`
  
- **`ALL`** - Exports all issues including resolved/closed
  - Best for: Complete historical migration
  - JQL: `project = KEY`

**Example Configuration:**

```json
"IssueExportSettings": {
  "Scope": "UNRESOLVED"
}
```

**When to Use Each Scope:**
- **UNRESOLVED**: Faster migration, smaller dataset, focuses on active work
- **ALL**: Complete project history, includes closed issues for reference

---

## Complete Example Configuration

```json
{
  "ProjectName": "LAS",
  "ProjectKey": "LAS",
  "Description": "Migration from onemain to onemainfinancial-sandbox-575",
  "Created": "2025-10-09",
  
  "SourceEnvironment": {
    "BaseUrl": "https://onemain.atlassian.net/",
    "Username": "ben.kreischer.ce@omf.com",
    "ApiToken": "ATATT3x...",
    "ProjectKey": "LAS"
  },
  
  "TargetEnvironment": {
    "BaseUrl": "https://onemainfinancial-sandbox-575.atlassian.net",
    "Username": "ben.kreischer.ce@omf.com",
    "ApiToken": "ATATT3x...",
    "ProjectKey": "LAS1",
    "ProjectName": "LAS Sandbox"
  },
  
  "ProjectCreation": {
    "ConfigurationTemplate": "XRAY",
    "ConfigSourceProjectKey": "XRAY",
    "StandardProjectTypeKey": "software",
    "EnhancedConfigSourceProjectKey": "ENHANCED"
  },
  
  "IssueExportSettings": {
    "Scope": "UNRESOLVED"
  },
  
  "AnalysisSettings": {
    "MaxIssuesToAnalyze": 50000,
    "IncludeClosedIssues": true,
    "IncludeSubTasks": true,
    "BatchSize": 100,
    "RetryAttempts": 3
  },
  
  "MigrationSettings": {
    "DryRun": false,
    "MigrateSprints": false,
    "MigrateAttachments": true,
    "MigrateComments": true,
    "MigrateLinks": true,
    "MigrateCustomFields": true,
    "MigrateLegacyKeys": true
  },
  
  "OutputSettings": {
    "LogLevel": "INFO",
    "GenerateHtmlReport": true,
    "GenerateCsvReport": true,
    "OpenReportInBrowser": false,
    "OutputDirectory": "./out",
    "LogDirectory": "./out/logs"
  }
}
```

---

## Running Automated Migration

### Option 1: Auto-Run All Steps

```powershell
.\Run-All.ps1 -Project LAS
```

This will:
1. Load configuration from `projects/LAS/parameters.json`
2. Execute all 16 steps sequentially
3. Use pre-configured options (no prompts)
4. Generate live HTML dashboard
5. Log all output to `projects/LAS/out/logs/`

### Option 2: Interactive Step-by-Step

```powershell
.\RunMigration.ps1 -Project LAS
```

This will:
1. Show a menu with all steps
2. Let you run steps individually
3. Use pre-configured options (no prompts within steps)
4. Update progress dashboard after each step

### Option 3: Run Specific Step

```powershell
.\RunMigration.ps1 -Project LAS -Step 07
```

---

## Migration Modes Comparison

| Mode | User Prompts | Configuration Source | Best For |
|------|--------------|---------------------|----------|
| **Run-All (Auto)** | None | parameters.json | Fully automated migrations |
| **Interactive** | Step selection only | parameters.json | Controlled step-by-step execution |
| **Legacy** | Many prompts | parameters.json + interactive | Manual testing (deprecated) |

---

## Validation

Before running the migration, validate your configuration:

```powershell
.\RunMigration.ps1 -Project LAS -DryRun
```

This will:
- Check all configuration parameters
- Validate connectivity to source and target
- Verify project exists in source
- Report any configuration issues

---

## Other Existing Configuration Options

These settings were already configurable and don't require interactive prompts:

### Sprint Migration
```json
"SprintSettings": {
  "Mode": "Auto",
  "CopyClosedSprints": true,
  "CreateFutureSprints": true
}
```

### Attachment/Comment Migration
```json
"MigrationSettings": {
  "MigrateAttachments": true,
  "MigrateComments": true,
  "MigrateLinks": true
}
```

### Board Detection
```json
"BoardResolution": {
  "Mode": "AutoDetect",
  "SelectionStrategy": "MostClosedSprints"
}
```

---

## Summary of Changes

### Files Modified:
1. **`config/migration-parameters.json`**
   - Added `ProjectCreation.ConfigurationTemplate`
   - Added `ProjectCreation.StandardProjectTypeKey`
   - Added `ProjectCreation.EnhancedConfigSourceProjectKey`
   - Added `IssueExportSettings.Scope`

2. **`src/steps/02_CreateProject_FromSharedConfig.ps1`**
   - Now supports three configuration templates (XRAY, STANDARD, ENHANCED)
   - Handles standard project creation without shared config
   - Updated header comments and verification logic

3. **`src/steps/07_ExportIssues_Source.ps1`**
   - Removed interactive prompt for export scope
   - Now reads from `IssueExportSettings.Scope` in parameters
   - Updated header comments

### Benefits:
✅ **Fully automated migrations** - No manual intervention required  
✅ **Reproducible** - Same configuration = same results  
✅ **Documented** - All choices recorded in parameters.json  
✅ **Flexible** - Three project templates + two export scopes  
✅ **Auditable** - All configuration choices logged in receipts  

---

## Need Help?

For questions or issues:
1. Check `projects/[PROJECT]/out/logs/` for detailed logs
2. Review `projects/[PROJECT]/out/*_receipt.json` for step outputs
3. Run with `-DryRun` flag to validate configuration
4. Review this document for configuration options

