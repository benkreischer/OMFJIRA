# Jira Migration Toolkit
OMF Migration Suite

**Status:** ✅ Sandbox Ready with Complete Terminal Logging  
**Last Updated:** October 21, 2025

---

## 🎯 Quick Start

### Create a New Migration Project
```powershell
# Interactive project creation with prompts
.\CreateNewProject.ps1 -ProjectKey "ABC"

# Or create a standard project template
.\CreateNewStandardProject.ps1 -SourceKey "ABC" -TargetKey "ABC1" -SourceBaseUrl "https://company.atlassian.net/" -TargetBaseUrl "https://company-sandbox.atlassian.net/"
```

### Run Migration with Complete Logging
```powershell
# Interactive step-by-step migration
.\RunMigration.ps1 -Project "ABC"

# Auto-run full migration
.\RunMigration.ps1 -Project "ABC" -AutoRun

# Run individual steps
.\RunMigration.ps1 -Project "ABC" -Step 01
```

---

## 🆕 **NEW: Complete Terminal Logging**

**Every migration script now captures ALL terminal output and creates detailed markdown logs:**

- **Log Files**: `XX_StepName_Log.md` (e.g., `01_Preflight_Log.md`, `02_Project_Log.md`)
- **Complete Capture**: All console output, errors, warnings, verbose messages, debug output
- **Markdown Format**: Easy to read, share, and archive
- **Error Handling**: Logs are created even if scripts fail
- **Audit Trail**: Complete history for compliance and debugging

### Example Log Files Created:
- `01_Preflight_Log.md` - Preflight validation output
- `02_Project_Log.md` - Project creation output  
- `03_Users_Log.md` - User synchronization output
- `04_Components_Log.md` - Component migration output
- `05_Versions_Log.md` - Version migration output
- `06_Boards_Log.md` - Board creation output
- `07_Export_Log.md` - Issue export output
- `08_Import_Log.md` - Issue import output
- `09_Comments_Log.md` - Comment migration output
- `10_Attachments_Log.md` - Attachment migration output
- `11_Links_Log.md` - Link migration output
- `12_Worklogs_Log.md` - Worklog migration output
- `13_Sprints_Log.md` - Sprint migration output
- `14_History_Log.md` - History migration output
- `15_Review_Log.md` - Review and validation output
- `16_PushToConfluence_Log.md` - Confluence publishing output

---

## 🏗️ **Migration System Overview**

This repository contains a modular, idempotent set of PowerShell scripts, utilities, and documentation that together automate project creation, configuration copying, issue export/import, attachments, links, worklogs, sprints, and a comprehensive QA verification system.

## ✨ **Key Features**

- **🔄 Modular 16-Step Migration Flow**: Complete project migration from creation to Confluence publishing
- **🛡️ Idempotent Design**: Safe to re-run steps when recovery or retries are needed
- **📊 Live HTML Dashboards**: Interactive QA reports for fast validation and stakeholder-ready outputs
- **📝 Complete Terminal Logging**: Every script captures ALL output in markdown format
- **⚙️ Config-Driven**: Global defaults and per-project overrides
- **🔒 Deletion Safeguards**: Protected destructive operations with configuration flags
- **🧪 DryRun Mode**: Validate configuration without making changes

## 🚀 **Migration Steps (16 Total)**

1. **01_Preflight** - Validates configuration, auto-updates ProjectNames
2. **02_Project** - Creates target project from template  
3. **03_Users** - Syncs users and roles to target project
4. **04_Components** - Migrates components and labels
5. **05_Versions** - Migrates versions/releases
6. **06_Boards** - Creates boards and filters
7. **07_Export** - Exports all issues from source
8. **08_Import** - Creates issues in target
9. **09_Comments** - Migrates all comments
10. **10_Attachments** - Migrates all attachments
11. **11_Links** - Migrates issue and remote links
12. **12_Worklogs** - Migrates time tracking data
13. **13_Sprints** - Migrates sprint data
14. **14_History** - Migrates issue history
15. **15_Review** - Comprehensive quality checks
16. **16_PushToConfluence** - Publishes results to Confluence

## 🔧 **Configuration & Safety**

### 🧪 **DryRun Mode**
All migration steps support `-DryRun` mode for safe testing:
```powershell
.\01_Preflight.ps1 -DryRun
.\02_Project.ps1 -DryRun
# ... and so on for all steps
```

### 🔒 **Deletion Safeguards**
Destructive operations are protected by configuration flags:
- `DeleteTargetIssuesBeforeImport`: Delete existing issues before import (Step 08)
- `DeleteTargetComponentsBeforeImport`: Delete existing components before import (Step 04)  
- `DeleteTargetVersionsBeforeImport`: Delete existing versions before import (Step 05)
- `DeleteTargetBoardsBeforeImport`: Delete existing boards before import (Step 06)

**Set these to `true` in your `migration-parameters.json` to enable destructive operations.**

### 📝 **Terminal Logging Configuration**
Every script automatically creates detailed logs:
- **Location**: `projects/[PROJECT_KEY]/out/XX_StepName_Log.md`
- **Content**: Complete terminal output, errors, warnings, verbose messages
- **Format**: Markdown for easy reading and sharing
- **Error Handling**: Logs created even if scripts fail

## 🚀 **Typical Workflow (Recommended)**

1. **Create Project**: `.\CreateNewProject.ps1 -ProjectKey ABC`
2. **Configure**: Edit `projects/ABC/parameters.json` if needed
3. **Test**: Run `.\RunMigration.ps1 -Project ABC -Step 01 -DryRun` to validate
4. **Migrate**: Run `.\RunMigration.ps1 -Project ABC -AutoRun` for full migration
5. **Validate**: Run `.\RunMigration.ps1 -Project ABC -Step 15` for QA validation
6. **Publish**: Run `.\RunMigration.ps1 -Project ABC -Step 16` to publish to Confluence

## 🎯 **What the Toolkit Does**

- **Project Creation**: Templates (XRAY, STANDARD, ENHANCED) with full configuration copy
- **User & Role Sync**: Automatic user synchronization and permission mapping
- **Data Migration**: Components, labels, versions, boards, issues, comments, attachments, links, worklogs, sprints
- **Historical Preservation**: Maintains original timestamps, authors, and relationships
- **Quality Assurance**: 30+ validation checks with interactive HTML reports
- **Complete Logging**: Every step creates detailed markdown logs for audit trails

## 📁 **Important Files & Directories**

### **Core Scripts**
- `_common.ps1` — Shared helper functions
- `_dashboard.ps1` — Dashboard and reporting helpers  
- `_terminal_logging.ps1` — **NEW**: Complete terminal logging module
- `_logging.ps1` — Legacy logging functions

### **Migration Steps**
- `01_Preflight.ps1` through `16_PushToConfluence.ps1` — Complete migration pipeline
- Each step now includes automatic terminal logging

### **Project Management**
- `CreateNewProject.ps1` — Interactive project creation
- `CreateNewStandardProject.ps1` — Standard template project creation
- `RunMigration.ps1` — Main migration launcher

### **Configuration**
- `migration-parameters.json` — Global defaults and feature toggles
- `projects/[PROJECT_KEY]/parameters.json` — Per-project config and overrides

### **Output & Logs**
- `projects/[PROJECT_KEY]/out/` — Migration outputs:
  - `XX_StepName_Log.md` — **NEW**: Complete terminal logs for each step
  - `exports/` — Exported source data
  - `logs/` — Legacy step logs  
  - `*.json` — Step receipts
  - `*.html` — Reports & dashboards
  - `*.csv` — Data exports

## ⚙️ **Configuration Highlights**

- **Project Template**: Set `ProjectCreation.ConfigurationTemplate` to `XRAY`, `STANDARD`, or `ENHANCED`
- **Export Scope**: `IssueExportSettings.Scope` — `UNRESOLVED` (recommended) or `ALL`
- **Remote Link Fallback**: Enable `CreateRemoteLinksForSkipped` to preserve cross-project references
- **Terminal Logging**: Automatically enabled for all scripts (no configuration needed)

## 🎮 **Execution Modes**

- **AutoRun**: Full non-interactive run with dashboard (`-AutoRun`)
- **Interactive**: Step-by-step selection and manual control
- **DryRun**: Validate config and run validations without making changes
- **Individual Steps**: Run specific steps with `-Step XX`

## 🔍 **QA and Validation**

**Step 15 (Review)** provides comprehensive validation:
- **30+ Checks**: Issues, comments, attachments, links, worklogs, cross-step consistency
- **Interactive Reports**: Stakeholder-ready HTML dashboards with drill-down
- **Remediation Suggestions**: Automated fix recommendations
- **Complete Logs**: Every validation step logged in markdown format

## 🛠️ **Troubleshooting & Common Tasks**

### **Permission Issues**
- Use `Support/CheckProjectPermissions.ps1` and review the generated Permission Validation Report
- Check terminal logs for detailed permission error messages

### **Duplicate Issues**
- QA system automatically flags duplicates
- Use the QA dashboard to view suggested fixes
- Review `15_Review_Log.md` for detailed duplicate analysis

### **Missing Links**
- See `docs/HANDLING_LINKS_GUIDE.md` for comprehensive link handling
- Enable `CreateRemoteLinksForSkipped` when appropriate
- Check `11_Links_Log.md` for link migration details

### **SSL Issues**
- See `docs/SSL_TROUBLESHOOTING_GUIDE.md` for connection diagnostics
- Check `01_Preflight_Log.md` for SSL validation results

### **Terminal Logging**
- **All logs**: Check `projects/[PROJECT_KEY]/out/XX_StepName_Log.md`
- **Error details**: Every error is captured with full context
- **Debug info**: Verbose and debug output included in logs

## 🔧 **Extending & Customizing**

- **Per-Project Overrides**: Add customizations in `projects/[KEY]/parameters.json`
- **New Steps**: Follow existing step naming and logging conventions
- **Utilities**: Use `Tools/` and `Support/` for reusable building blocks
- **Terminal Logging**: All new scripts automatically get logging via `_terminal_logging.ps1`

## 📂 **Directory Structure**

```
Migration/
├─ _terminal_logging.ps1      # NEW: Complete terminal logging module
├─ _common.ps1                 # Shared helper functions
├─ _dashboard.ps1              # Dashboard and reporting helpers
├─ 01_Preflight.ps1           # Migration steps (01-16)
├─ 02_Project.ps1
├─ ... (through 16_PushToConfluence.ps1)
├─ CreateNewProject.ps1        # Project creation scripts
├─ CreateNewStandardProject.ps1
├─ RunMigration.ps1            # Main migration launcher
├─ migration-parameters.json   # Global configuration
├─ projects/                   # Per-project configs & outputs
│  └─ [PROJECT_KEY]/
│     ├─ parameters.json       # Project-specific config
│     └─ out/                  # Migration outputs
│        ├─ XX_StepName_Log.md # NEW: Complete terminal logs
│        ├─ exports/            # Exported data
│        ├─ logs/              # Legacy step logs
│        ├─ *.json             # Step receipts
│        ├─ *.html             # Reports & dashboards
│        └─ *.csv               # Data exports
├─ docs/                       # Documentation (38+ files)
├─ Tools/                      # Utility scripts
└─ Support/                    # Helper scripts
```

## 🚀 **Next Steps & Recommended Checks**

1. **Create Project**: `.\CreateNewProject.ps1 -ProjectKey YOURKEY`
2. **Validate Config**: `.\RunMigration.ps1 -Project YOURKEY -Step 01 -DryRun`
3. **Run Migration**: `.\RunMigration.ps1 -Project YOURKEY -AutoRun`
4. **QA Validation**: `.\RunMigration.ps1 -Project YOURKEY -Step 15`
5. **Review Logs**: Check all `XX_StepName_Log.md` files for complete audit trail

## 📚 **Where to Find More Help**

- **Documentation**: `docs/` directory (38+ detailed guides)
- **Script Headers**: Each script includes comprehensive documentation
- **Terminal Logs**: Complete execution history in markdown format
- **QA Reports**: Interactive HTML dashboards with drill-down capabilities

---

**🎉 Ready to migrate? Start with:**
```powershell
.\CreateNewProject.ps1 -ProjectKey "YOUR_PROJECT"
```
