# OMF Folder Structure

This document describes the complete organizational structure of the OMF (OneMain Financial) Jira Analytics and Migration project.

## Overview

The OMF project is organized into specialized folders using a dotfile (`.prefix`) convention for organization and clarity. The structure separates concerns between API endpoints, migration tools, documentation, scripts, and various data formats.

---

## Top-Level Directory Structure

```
Z:\Code\OMF\
├── .affinity/              # Project affinity/relationship data
├── .backup/                # Backup files and archives
├── .docs/                  # Comprehensive project documentation
├── .excel/                 # Excel workbooks and CSV exports
├── .images/                # Logos, screenshots, and graphics
├── .json/                  # Configuration and template JSON files
├── .other/                 # Atlassian CLI tools and advanced scripts
├── .powerbi/               # PowerBI dashboard files and templates
├── .scripts/               # Utility and automation scripts
├── .trash/                 # Deleted items (temporary storage)
├── .vba/                   # Excel VBA modules
├── cursor/                 # Cursor AI configuration and rules
├── Endpoints/              # Jira API endpoint implementations
└── Migration/              # Jira migration toolkit
```

---

## Detailed Folder Descriptions

### `.docs/` - Project Documentation
**Purpose:** Centralized location for all project documentation, guides, and reports.

**Contents:**
- Implementation guides (OAuth2, PowerBI, Excel setup)
- Phase completion summaries (Phase 1-4)
- Comprehensive API analysis documents
- Setup instructions and troubleshooting guides
- Master plans and roadmaps
- 50+ markdown documentation files

**Key Files:**
- `OMF_USER_GUIDE.md` - Main user guide
- `ADVANCED_ANALYTICS_MASTER_PLAN.md` - Analytics roadmap
- `COMPREHENSIVE_ENDPOINT_ANALYSIS.md` - API endpoint documentation
- Phase summaries (PHASE1-4_COMPLETE_SUMMARY.md)

---

### `.scripts/` - Utility Scripts
**Purpose:** Automation, testing, and utility scripts for project maintenance.

**Contents:** 130+ PowerShell scripts including:
- Endpoint creation and management scripts
- Data analysis and validation tools
- PowerBI connection helpers
- Excel integration scripts
- Testing and debugging utilities
- Performance monitoring tools

**Key Scripts:**
- `execute_all_get_endpoints.ps1` - Run all GET endpoints
- `create_powerbi_dashboard.ps1` - Generate PowerBI dashboards
- `fix_all_endpoints.ps1` - Bulk endpoint fixes
- `test_all_endpoints.ps1` - Endpoint validation

---

### `.excel/` - Excel Files and Exports
**Purpose:** Excel workbooks, CSV exports, and data analysis files.

**Contents:**
- Live API connection workbooks
- CSV data exports from endpoints
- Field usage analysis files
- Project analysis spreadsheets
- Presentation data workbooks

**Key Files:**
- `Jira_API_Endpoints_Live_Connections.xlsx` - Live API data
- `field_usage_counts.csv` - Custom field analysis
- `Active-Independent-Projects-Analysis.csv` - Project analytics

---

### `.powerbi/` - PowerBI Dashboards
**Purpose:** PowerBI dashboard files and PowerQuery templates.

**Contents:**
- PowerBI dashboard files (.pbix)
- PowerQuery M code templates (.pq)
- Connection management scripts
- Data model documentation

**Key Files:**
- `OMF PowerBI Master.pbix` - Main dashboard
- `OMF Dirty Sandbox Master.pbix` - Test environment
- `Jira_API_PowerQuery_Complete.pq` - Complete PowerQuery template
- `Data_Model_Documentation.md` - Data model guide

---

### `.json/` - Configuration Files
**Purpose:** JSON configuration files for various integrations.

**Contents:**
- OAuth2 configuration
- Dashboard templates
- API configurations
- Field definitions

**Key Files:**
- `oauth2_config.json` - OAuth2 settings
- `Jira_API_Dashboard_Template.json` - Dashboard template
- `fields_onemainfinancial.json` - Custom field definitions

---

### `.vba/` - VBA Modules
**Purpose:** Excel VBA code for dynamic Jira integration.

**Contents:**
- Excel-Jira integration modules
- Date conversion utilities
- Dynamic query builders

**Key Files:**
- `excel-jira-integration.vba` - Main integration module
- `jira-date-conversion-vba.vba` - Date handling

---

### `.images/` - Graphics and Logos
**Purpose:** Logos, screenshots, and visual assets.

**Contents:**
- OneMain Financial logos (PNG, SVG)
- Screenshots for documentation
- UI mockups

---

### `.other/` - Advanced Tools
**Purpose:** Atlassian CLI tools, advanced analytics, and specialized scripts.

**Contents:**
- Atlassian CLI executable (acli.exe)
- Advanced analytics scripts (OAuth2-based)
- Enterprise feature implementations
- Admin organization tools
- Advanced security and compliance scripts
- Integration management tools
- Audit and compliance scripts

**Organization:**
- Organized into subfolders by category:
  - `Admin Organization/` - User, group, license management
  - `Advanced Agile/` - Sprint, velocity, burndown analytics
  - `Advanced Analytics/` - Cross-project, team performance
  - `Advanced Security/` - Threat detection, compliance
  - `Enterprise Features/` - Enterprise-level analytics
  - `Integration Management/` - Third-party integrations

---

### `.backup/` and `.trash/`
**Purpose:** Temporary storage for deleted or archived content.

**Usage:** Not for active development; used for recovery if needed.

---

## Main Project Folders

### `Endpoints/` - Jira API Implementations
**Purpose:** Complete implementation of Jira REST API v3 endpoints.

**Organization:**
- Organized by API category (60+ categories)
- Each endpoint has 4 file types:
  - `.ps1` - PowerShell script
  - `.pq` - Power Query M code
  - `.csv` - Sample data export
  - `.md` - API documentation

**File Naming Convention:**
```
[Category] - [HTTP Method] [Endpoint Name] - [Auth Type] - Official.[extension]

Examples:
- Projects - GET Projects Paginated - Anon - Official.ps1
- Dashboards - GET All Dashboards - Anon - Official.pq
- Users - GET Users - Anon - Official.csv
```

**Key Files:**
- `endpoint_compliance_tracking.md` - Implementation tracking
- `endpoints-parameters.json` - Shared configuration
- `Get-EndpointParameters.ps1` - Parameter loader
- `Fix-All-Endpoints.ps1` - Bulk maintenance

**Categories Include:**
- Projects, Issues, Users, Groups
- Dashboards, Filters, Boards
- Workflows, Issue Types, Fields
- Permissions, Security, Audit
- And 50+ more categories

---

### `Migration/` - Jira Migration Toolkit
**Purpose:** Complete toolkit for migrating Jira projects between instances.

**Structure:**
```
Migration/
├── config/
│   └── migration-parameters.json    # Master configuration
├── docs/                            # 21 documentation files
│   ├── CONFIGURATION_OPTIONS.md     # Configuration guide
│   ├── QUICK_REFERENCE.md          # Quick start guide
│   ├── MULTI_PROJECT_GUIDE.md      # Multi-project setup
│   └── ... (18+ more docs)
├── src/
│   ├── steps/                       # 18 migration steps
│   │   ├── 01_Preflight.ps1
│   │   ├── 02_CreateProject_FromSharedConfig.ps1
│   │   ├── ... (through step 18)
│   ├── Utility/                     # Troubleshooting scripts
│   │   ├── 08_DeleteAllIssues.ps1
│   │   ├── 09_RetryFailedComments.ps1
│   │   └── ... (13 utility scripts)
│   ├── _common.ps1                  # Shared functions
│   └── _dashboard.ps1               # Dashboard functions
├── projects/                        # Project-specific configs
│   └── [PROJECT_KEY]/
│       ├── parameters.json
│       ├── out/
│       │   ├── logs/
│       │   └── exports/
│       └── README.md
├── Other/                           # Archived scripts
├── Workflows/                       # XRAY workflow diagrams
├── RunMigration.ps1                 # Main launcher
└── README.md                        # Main documentation
```

**Migration Steps (18 total):**
1. Preflight - Validation
2. CreateProject - Project setup with template choice
3. SyncUsersAndRoles - User management
4. ComponentsAndLabels - Project metadata
5. Versions - Version management
6. Boards - Board setup
7. ExportIssues - Export from source (with scope choice)
8. CreateIssues - Import to target
9. Comments - Migrate comments
10. Attachments - File migration
11. Links - Issue link migration
12. Worklogs - Time tracking
13. Sprints - Sprint migration
14. Automations - Automation rules
15. PermissionsAndSchemes - Security setup
16. QA_Validation - Quality checks
17. FinalizeAndComms - Finalization
18. PostMigration_Report - Final reporting

**Key Features:**
- **Idempotent**: All steps can be re-run safely
- **Multi-project**: Supports multiple projects
- **Automated**: Can run all steps unattended
- **Configurable**: Three project templates (XRAY, STANDARD, ENHANCED)
- **Scoped exports**: Choose ALL or UNRESOLVED issues
- **Live dashboard**: HTML progress tracking
- **Comprehensive logging**: Detailed execution logs

**Documentation in `Migration/docs/`:**
- Configuration guides
- Feature summaries
- Troubleshooting guides
- Quick reference materials
- Validation reports

---

### `cursor/` - Cursor AI Configuration
**Purpose:** Cursor AI editor configuration and rules.

**Contents:**
- `mcp.json` - Model Context Protocol config
- `rules/` - Cursor rules (.mdc files)
  - API compliance rules
  - Documentation standards
  - File structure enforcement
  - Jira API guidelines
  - Self-improvement rules

---

## File Type Conventions

### PowerShell Scripts (`.ps1`)
- **Location:** `.scripts/`, `Endpoints/`, `Migration/src/`
- **Purpose:** Automation, API calls, data processing
- **Naming:** Descriptive names with hyphens or underscores
- **Standard:** Use "Official" suffix for production scripts

### Power Query (`.pq`)
- **Location:** `Endpoints/`, `.powerbi/`, `.scripts/`
- **Purpose:** Data transformation, PowerBI connections
- **Naming:** Match corresponding .ps1 file names

### CSV Files (`.csv`)
- **Location:** `Endpoints/`, `.excel/`, `.scripts/`
- **Purpose:** Data exports, sample data, analysis results
- **Standard:** Include header row, use UTF-8 encoding

### Markdown (`.md`)
- **Location:** ALWAYS in `docs/` folders (`.docs/`, `Migration/docs/`)
- **Purpose:** Documentation, guides, reports
- **Standard:** Use proper markdown syntax, include TOC for long docs

### JSON Files (`.json`)
- **Location:** `.json/`, `config/`, `Migration/config/`
- **Purpose:** Configuration, templates, data structures
- **Standard:** Pretty-printed, validated JSON

### Excel Files (`.xlsx`, `.xlsm`)
- **Location:** `.excel/`
- **Purpose:** Workbooks, data analysis, dashboards
- **Types:** Regular (.xlsx) or macro-enabled (.xlsm)

### PowerBI Files (`.pbix`)
- **Location:** `.powerbi/`
- **Purpose:** Business intelligence dashboards
- **Standard:** Include data model documentation

### VBA Code (`.vba`)
- **Location:** `.vba/`
- **Purpose:** Excel automation and integration
- **Standard:** Module-based organization

---

## Project-Specific Organization

### Migration Projects
Each migration project in `Migration/projects/` follows this structure:

```
projects/[PROJECT_KEY]/
├── parameters.json          # Project configuration
├── out/
│   ├── *_receipt.json      # Step completion receipts
│   ├── logs/
│   │   └── step_*.log      # Execution logs
│   ├── exports/
│   │   ├── source_issues_export.json
│   │   └── key_to_id_mapping.json
│   └── migration_progress.html  # Live dashboard
└── README.md                # Project notes
```

**Configuration:**
- Source and target environments
- Project creation template (XRAY/STANDARD/ENHANCED)
- Issue export scope (ALL/UNRESOLVED)
- Migration settings (attachments, comments, links, etc.)
- User mapping rules
- Sprint settings
- Custom field mappings

---

## Important Conventions

### Documentation Files
- ✅ **ALWAYS** create markdown files in `docs/` folders
- ❌ **NEVER** create markdown files in project root
- Migration docs → `Migration/docs/`
- General docs → `.docs/`

### Naming Conventions
- **Endpoints:** `[Category] - [Method] [Name] - [Auth] - Official.[ext]`
- **Scripts:** `lowercase-with-hyphens.ps1` or `PascalCase.ps1`
- **Docs:** `UPPERCASE_WITH_UNDERSCORES.md`
- **Projects:** `UPPERCASE_KEY` (e.g., LAS, DEP, XXX)

### File Placement
- Scripts → `.scripts/` or appropriate `src/` folder
- Data exports → `.excel/` or project `out/` folder
- Configuration → `.json/` or `config/` folder
- Documentation → `.docs/` or `docs/` subfolder
- PowerBI → `.powerbi/`
- Images → `.images/`

---

## Usage Patterns

### Working with Endpoints
1. All endpoint implementations in `Endpoints/[Category]/`
2. Each has 4 files: .ps1, .pq, .csv, .md
3. Use `endpoints-parameters.json` for shared config
4. Run with `Get-EndpointParameters.ps1` for parameter loading

### Running Migrations
1. Configure project in `Migration/projects/[KEY]/parameters.json`
2. Choose template: XRAY, STANDARD, or ENHANCED
3. Choose export scope: ALL or UNRESOLVED
4. Run: `.\RunMigration.ps1 -Project [KEY]`
5. Or auto-run: `.\Run-All.ps1 -Project [KEY]`

### Creating Documentation
1. Determine type: general (`.docs/`) or migration-specific (`Migration/docs/`)
2. Use descriptive uppercase filename with underscores
3. Include proper markdown headers and structure
4. Add to appropriate docs folder

---

## Summary

The OMF project structure is designed for:
- **Clarity:** Dotfile organization keeps things organized
- **Separation:** Each file type has its designated location
- **Scalability:** Easy to add new endpoints, projects, or scripts
- **Maintainability:** Consistent naming and structure
- **Documentation:** Comprehensive docs in proper locations
- **Automation:** Scripts for common tasks

All team members should follow these conventions to maintain project organization and quality.

---

**Last Updated:** 2025-10-12  
**Version:** 1.0  
**Location:** `.docs/OMF_FOLDER_STRUCTURE.md`

