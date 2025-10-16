# Jira Migration Workflow Guide

## Overview

This document provides a comprehensive guide to the Jira migration workflow from `onemain-omfdirty` (ENGOPS project) to `onemain-omfclean` (QESB1 project). Each step is clearly documented with its purpose, actions, and limitations.

## Migration Process Structure

The migration follows a structured 17-step process divided into three main phases:

### Phase 1: Setup and Preparation (Steps 01-06)
### Phase 2: Data Migration (Steps 07-12)  
### Phase 3: Validation and Completion (Steps 13-17)

---

## Phase 1: Setup and Preparation

### 01_Preflight.ps1 - Migration Preflight Validation

**PURPOSE:** Performs preflight validation checks before starting the migration process. It does NOT create any projects or perform any actual migration work.

**WHAT IT DOES:**
- Validates that all required parameters are present in the configuration file
- Checks that the migration-parameters.json file is properly structured
- Ensures all source and target environment settings are configured
- Creates a receipt file to track that preflight validation passed

**WHAT IT DOES NOT DO:**
- Does not create projects in the target environment
- Does not migrate any data
- Does not perform any actual Jira operations

**NEXT STEP:** Run 02_CreateProject_FromSharedConfig.ps1 to actually create the target project

---

### 02_CreateProject_FromSharedConfig.ps1 - Create Target Project with Shared Configuration

**PURPOSE:** Creates the target project in the destination Jira instance and copies configuration from a reference project (XRAY) to ensure consistent setup.

**WHAT IT DOES:**
- Creates a new project using the same project type as XRAY project
- Resolves the configuration source project (XRAY) to get its project ID and configuration
- Uses ben.kreischer.ce@omf.com as project lead fallback if source lead cannot be resolved
- Verifies project configuration matches XRAY project (issue types, schemes, workflows)
- Creates a receipt tracking the project creation details

**WHAT IT DOES NOT DO:**
- Does not migrate any issues or data
- Does not set up boards or sprints
- Does not automatically apply schemes (requires manual configuration)

**NEXT STEP:** Run 03_SyncUsersAndRoles.ps1 to set up users and permissions

---

### 03_SyncUsersAndRoles.ps1 - Synchronize Users and Roles

**PURPOSE:** Ensures all users from the source project exist in the target environment and assigns appropriate roles to maintain access permissions during migration.

**WHAT IT DOES:**
- Enumerates all users and roles from the source project
- Verifies that user accounts exist in the target environment
- Assigns appropriate roles to users in the target project
- Creates a receipt tracking user synchronization status

**WHAT IT DOES NOT DO:**
- Does not create new user accounts (users must exist in target)
- Does not modify user permissions outside the project
- Does not migrate user preferences or settings

**NEXT STEP:** Run 04_ComponentsAndLabels.ps1 to set up project components

---

### 04_ComponentsAndLabels.ps1 - Set Up Components and Capture Labels

**PURPOSE:** Recreates project components from the source and captures all labels used in issues to ensure proper categorization and organization in the target project.

**WHAT IT DOES:**
- Copies all components from the source project to the target project
- Captures and catalogs all labels used in source issues
- Creates a receipt tracking component and label setup

**WHAT IT DOES NOT DO:**
- Does not migrate issues yet
- Does not assign components to issues
- Does not modify existing component configurations

**NEXT STEP:** Run 05_Versions.ps1 to set up project versions

---

### 05_Versions.ps1 - Create Project Versions

**PURPOSE:** Creates matching versions in the target project to maintain version tracking and ensure proper issue version associations during migration.

**WHAT IT DOES:**
- Retrieves all versions from the source project
- Creates corresponding versions in the target project
- Maintains version names, descriptions, and release dates
- Creates a receipt tracking version creation status

**WHAT IT DOES NOT DO:**
- Does not migrate issues yet
- Does not assign versions to issues
- Does not modify version release status

**NEXT STEP:** Run 06_Boards.ps1 to set up project boards

---

### 06_Boards.ps1 - Copy Board Filters and Create Target Boards (with Intelligent JQL Rewriting)

**PURPOSE:** Automatically discovers all boards in the source project, intelligently rewrites their JQL filters for the target environment, creates matching filters and boards in the target project, and prevents duplicate board creation on repeated runs.

**WHAT IT DOES:**

**Board Discovery:**
- Automatically discovers ALL boards in the source project (both Scrum and Kanban types)
- Retrieves board configuration and associated filter information for each board
- Identifies boards by reading their saved filter JQL queries
- Supports company-managed projects with filter-backed boards

**Intelligent JQL Rewriting:**
- Handles project key references: Converts `project = SOURCE_KEY` to `project = TARGET_KEY`
- Handles project name references: Converts `project = "Source Project Name"` to `project = TARGET_KEY`
- Simplifies multi-project JQL: Converts `project in (PROJ1, PROJ2, SOURCE_KEY)` to `project = TARGET_KEY`
- Removes references to projects that don't exist in the target environment
- Automatically adds ORDER BY Rank ASC if not present in JQL
- Operates in STRICT mode: only migrates boards that reference the source project

**Filter and Board Creation:**
- Creates a new filter in the target project for each source board
- Shares filters with the target project automatically
- Creates boards bound to the new filters
- Handles both Scrum and Kanban board types
- Maintains board names from source to target

**Duplicate Prevention:**
- Checks if a board with the same name already exists before creating
- Skips board creation if duplicate found (uses existing board)
- Prevents accumulation of duplicate boards on repeated script executions
- Creates new filters on each run but reuses existing boards

**Optional Duplicate Cleanup:**
- Use `-CleanupDuplicatesFirst` parameter to remove existing duplicates before migration
- Identifies boards with duplicate names in target project
- Automatically keeps the most recent board (highest ID)
- Deletes older duplicate boards to clean up environment

**Error Handling:**
- Gracefully handles boards with unreadable filters
- Skips boards whose JQL doesn't reference the source project
- Reports detailed error messages for failed filter or board creation
- Continues processing remaining boards if one fails
- Creates comprehensive receipts with success and failure details

**WHAT IT DOES NOT DO:**
- Does not migrate sprints (handled separately)
- Does not migrate board configuration (column mapping, swimlanes, etc.)
- Does not assign issues to boards (handled during issue migration)
- Does not migrate board administrators or permissions
- Does not create team-managed (next-gen) boards
- Does not migrate sprint goals or sprint metadata

**STRICT MODE BEHAVIOR:**
The script operates in STRICT mode, meaning:
- Only processes boards whose filter JQL explicitly references the source project
- Boards with generic or unrelated JQL are skipped
- Ensures only project-relevant boards are migrated
- Prevents migration of shared boards that span multiple projects

**USAGE EXAMPLES:**

Standard migration (with duplicate prevention):
```powershell
.\06_Boards.ps1
```

Migration with pre-cleanup of duplicates:
```powershell
.\06_Boards.ps1 -CleanupDuplicatesFirst
```

**TECHNICAL DETAILS:**

JQL Transformation Examples:
- `project = DEP` → `project = DEP1`
- `project = "DevOps Engineering Platform"` → `project = DEP1`  
- `project in (ESDL, CARD, DEP)` → `project = DEP1`
- `project IN (PROJ1, PROJ2, DEP) AND labels = "test"` → `project = DEP1 AND labels = "test"`

Filter Naming Convention:
- Target filters named as: `[TARGET_KEY] - [Board Name] (copied from [SOURCE_KEY] [TIMESTAMP])`
- Example: `DEP1 - DEP Sprints (copied from DEP 20251008103051)`
- Timestamp ensures uniqueness on repeated runs

**RECEIPT INFORMATION:**
Creates a detailed receipt file tracking:
- All source boards discovered
- Filter IDs and JQL for each board
- Target filter IDs and rewritten JQL
- Target board IDs and types
- Boards successfully created/reused
- Boards skipped with reason codes
- Complete mapping of source to target boards

**NEXT STEP:** Run 07_ExportIssues_Source.ps1 to begin issue migration

---

## Phase 2: Data Migration

### 07_ExportIssues_Source.ps1 - Export Issues from Source Project

**PURPOSE:** Exports all issues from the source project and builds a comprehensive mapping of issue keys to IDs for use in the migration process.

**WHAT IT DOES:**
- Retrieves all issues from the source project using JQL queries
- Exports issue data including fields, relationships, and metadata
- Builds a key→ID mapping for cross-referencing during migration
- Handles pagination for large issue sets
- Creates detailed export logs and receipts

**WHAT IT DOES NOT DO:**
- Does not modify any issues in the source project
- Does not create issues in the target project
- Does not migrate attachments or comments yet

**NEXT STEP:** Run 08_CreateIssues_Target.ps1 to create issues in the target project

---

### 08_CreateIssues_Target.ps1 - Create Issues in Target Project

**PURPOSE:** Creates all issues in the target project using the exported data from the source, applying field mappings and custom field transformations as needed.

**WHAT IT DOES:**
- Creates issues in the target project using exported source data
- Applies issue type mappings and field transformations
- Appends custom field values to issue descriptions for preservation
- Maps source issue keys to target issue keys
- Handles bulk creation with error handling and retry logic
- Creates detailed creation logs and receipts

**WHAT IT DOES NOT DO:**
- Does not migrate comments, attachments, or worklogs yet
- Does not create issue links yet
- Does not assign issues to sprints yet

**NEXT STEP:** Run 09_Comments.ps1 to migrate issue comments

---

### 09_Comments.ps1 - Migrate Issue Comments

**PURPOSE:** Migrates all comments from source issues to their corresponding target issues, preserving comment history, authors, and timestamps.

**WHAT IT DOES:**
- Retrieves all comments from source issues
- Maps comments to their corresponding target issues using key mappings
- Preserves comment authors, timestamps, and content
- Handles comment threading and visibility settings
- Creates detailed migration logs and receipts

**WHAT IT DOES NOT DO:**
- Does not migrate attachments (handled separately)
- Does not modify comment content or formatting
- Does not migrate comments for issues that failed to create

**NEXT STEP:** Run 10_Attachments.ps1 to migrate file attachments

---

### 10_Attachments.ps1 - Migrate File Attachments

**PURPOSE:** Downloads all file attachments from source issues and uploads them to their corresponding target issues, preserving file content and metadata.

**WHAT IT DOES:**
- Downloads all attachments from source issues
- Uploads attachments to corresponding target issues using key mappings
- Preserves file names, sizes, and upload timestamps
- Handles large files and network timeouts with retry logic
- Creates detailed migration logs and receipts

**WHAT IT DOES NOT DO:**
- Does not modify attachment content or compress files
- Does not migrate attachments for issues that failed to create
- Does not handle attachments that exceed target environment limits

**NEXT STEP:** Run 11_Links.ps1 to migrate issue links and relationships

---

### 11_Links.ps1 - Migrate Issue Links and Relationships

**PURPOSE:** Recreates all issue links and relationships in the target project, mapping source issue keys to target issue keys.

**WHAT IT DOES:**
- Retrieves all issue links from source issues
- Maps source issue keys to target issue keys using migration mappings
- Recreates links with the same relationship types (blocks, relates to, etc.)
- Handles both internal and external issue links
- Creates detailed migration logs and receipts

**WHAT IT DOES NOT DO:**
- Does not migrate links to issues outside the migration scope
- Does not modify link descriptions or types
- Does not create links for issues that failed to migrate

**NEXT STEP:** Run 12_Worklogs.ps1 to migrate time tracking data

---

### 12_Worklogs.ps1 - Migrate Time Tracking Worklogs

**PURPOSE:** Migrates all worklog entries from source issues to target issues, preserving time tracking data, comments, and user assignments.

**WHAT IT DOES:**
- Retrieves all worklog entries from source issues
- Maps worklogs to corresponding target issues using key mappings
- Preserves worklog authors, time spent, dates, and comments
- Handles worklog visibility and permissions
- Creates detailed migration logs and receipts

**WHAT IT DOES NOT DO:**
- Does not modify worklog time entries or dates
- Does not migrate worklogs for issues that failed to create
- Does not adjust worklog timestamps for time zone differences

**NEXT STEP:** Run 13_Automations.ps1 to migrate automation rules

---

## Phase 3: Validation and Completion

### 13_Automations.ps1 - Migrate Project Automation Rules

**PURPOSE:** Exports and imports project automation rules to maintain workflow automation and business logic in the target environment.

**WHAT IT DOES:**
- Exports automation rules from the source project
- Imports automation rules to the target project with appropriate mappings
- Updates rule conditions and actions to use target project references
- Validates automation rule functionality in the target environment
- Creates detailed migration logs and receipts

**WHAT IT DOES NOT DO:**
- Does not migrate global automation rules (project-specific only)
- Does not modify automation rule logic or conditions
- Does not migrate rules that reference non-migrated components

**NEXT STEP:** Run 14_PermissionsAndSchemes.ps1 to validate permissions

---

### 14_PermissionsAndSchemes.ps1 - Validate Permissions and Schemes

**PURPOSE:** Validates that permission schemes and notification schemes are properly configured in the target project and patches any differences as needed.

**WHAT IT DOES:**
- Validates that shared configuration schemes are properly applied
- Compares source and target permission schemes for differences
- Patches permission scheme differences if needed
- Validates notification scheme configurations
- Creates detailed validation logs and receipts

**WHAT IT DOES NOT DO:**
- Does not modify global schemes (project-specific only)
- Does not create new permission schemes
- Does not migrate user-specific permissions

**NEXT STEP:** Run 15_QA_Validation.ps1 for final quality assurance checks

---

### 15_QA_Validation.ps1 - Quality Assurance Validation

**PURPOSE:** Performs comprehensive quality assurance checks to validate the migration was successful and all data was properly transferred.

**WHAT IT DOES:**
- Compares issue counts between source and target projects
- Performs spot checks on migrated issues for data integrity
- Validates that all relationships and links are properly created
- Generates validation reports with pass/fail status
- Creates detailed QA logs and receipts

**WHAT IT DOES NOT DO:**
- Does not modify any data in either environment
- Does not automatically fix validation failures
- Does not provide detailed analysis of failed validations

**NEXT STEP:** Run 16_FinalizeAndComms.ps1 to complete the migration

---

### 16_FinalizeAndComms.ps1 - Finalize Migration and Communications

**PURPOSE:** Completes the migration process by sending communications to stakeholders and optionally making the source project read-only to prevent further changes.

**WHAT IT DOES:**
- Sends migration completion notifications to project stakeholders
- Optionally sets the source project to read-only mode
- Updates project documentation with migration details
- Creates final migration summary and receipts

**WHAT IT DOES NOT DO:**
- Does not delete or archive the source project
- Does not modify target project settings beyond notifications
- Does not send notifications to external systems

**NEXT STEP:** Run 17_PostMigration_Report.ps1 to generate final reports

---

### 17_PostMigration_Report.ps1 - Generate Post-Migration Reports

**PURPOSE:** Compiles all migration logs and receipts into comprehensive reports for documentation, auditing, and stakeholder review.

**WHAT IT DOES:**
- Compiles logs and receipts from all migration steps
- Generates comprehensive HTML and CSV reports
- Creates migration summary with statistics and outcomes
- Documents any errors or warnings encountered during migration
- Provides recommendations for post-migration activities

**WHAT IT DOES NOT DO:**
- Does not modify any project data
- Does not send reports automatically (manual distribution required)
- Does not perform additional data validation

**FINAL STEP:** Review reports and distribute to stakeholders

---

## Migration Configuration

### Source Environment
- **Instance:** onemain-omfdirty.atlassian.net
- **Project:** ENGOPS (Engineering Operations)
- **Project Key:** ENGOPS

### Target Environment
- **Instance:** onemain-omfclean.atlassian.net
- **Project:** QESB1 (Engineering Operations - QESB1)
- **Project Key:** QESB1

### Configuration Source
- **Reference Project:** XRAY (for shared configuration)

---

## Quick Reference

### Running Scripts
All scripts can be run without parameters as they automatically resolve the configuration file path:

```powershell
# Simple execution - no parameters needed!
.\01_Preflight.ps1
.\02_CreateProject_FromSharedConfig.ps1
.\03_SyncUsersAndRoles.ps1
# ... and so on for all 17 scripts
```

### Alternative: Manual Parameter Override
```powershell
# Example with explicit path (if needed for custom config)
.\01_Preflight.ps1 -ParametersPath "Z:\Code\OMF\Migration\config\migration-parameters.json"
```

### Special Parameters

**06_Boards.ps1 - Cleanup Duplicates:**
```powershell
# If you need to clean up duplicate boards before migration
.\06_Boards.ps1 -CleanupDuplicatesFirst
```
This will identify and delete duplicate boards (keeping the most recent) before creating new ones.

### Key Files
- **Configuration:** `Migration\config\migration-parameters.json`
- **Receipts:** `.\out\` directory
- **Logs:** `.\out\logs\` directory

---

## Document Maintenance

This document should be updated whenever:
- Script functionality changes
- New steps are added to the migration process
- Process flow modifications are made
- Configuration requirements change

Last Updated: 2025-10-08

**Recent Updates:**
- 2025-10-08: Completely rewrote Step 06_Boards.ps1 documentation to reflect intelligent JQL rewriting, duplicate prevention, project name handling, and multi-project simplification features
