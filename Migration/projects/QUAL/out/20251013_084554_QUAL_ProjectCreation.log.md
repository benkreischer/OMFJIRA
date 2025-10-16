# Migration Log: QUAL
**Operation:** ProjectCreation  
**Started:** 2025-10-13 08:45:54  
**Log File:** `projects\QUAL\out\20251013_084554_QUAL_ProjectCreation.log.md`

---


## 🔷 Create New Migration Project: QUAL


### ▫️ Validation

[08:45:54] ✅ **[Validation]** Project key format is valid: QUAL
[08:45:54] ✅ **[Validation]** Project directory is available

### ▫️ Fetch Project Details from Jira

[08:45:54] ℹ️ **[API]** Connecting to source Jira...
[08:45:54] ℹ️ **[Auth]** Loading API credentials from .env...
[08:45:54] ✅ **[Auth]** API credentials loaded
[08:45:54] ℹ️ **[API]** Fetching project: https://onemain-migrationsandbox.atlassian.net/rest/api/3/project/QUAL
[08:45:55] ✅ **[API]** Found project: EO - Quality Assurance (Key: QUAL)

**Project Details**

| Property | Value |
|----------|-------|
| Project Name | EO - Quality Assurance |
| Project Key | QUAL |
| Target Name | EO - Quality Assurance Sandbox |



### ▫️ Create Project Structure

[08:46:04] ℹ️ **[FileSystem]** Creating project directory: projects\QUAL
[08:46:04] ✅ **[FileSystem]** Created project directory: projects\QUAL
[08:46:04] ℹ️ **[FileSystem]** Creating output directories...
[08:46:04] ✅ **[FileSystem]** Created output directories (out, exports, logs)

### ▫️ Generate Configuration Files

[08:46:04] ℹ️ **[Config]** Creating parameters.json...

**Template Configuration**

| Property | Value |
|----------|-------|
| Template URL | https://onemainfinancial-migrationsandbox.atlassian.net/ |
| Migrate Sprints | YES |
| Template Environment | TARGET (onemainfinancial-migrationsandbox) |
| Include SubTasks | YES |
| Template Project Key | STANDARD |
| Export Scope | UNRESOLVED |
| Template Type | STANDARD |


[08:46:04] ✅ **[Config]** Created parameters.json with migration settings
[08:46:04]   → Config file: projects\QUAL\parameters.json
[08:46:04]   → Template source: Project 'STANDARD' in onemainfinancial-migrationsandbox.atlassian.net
[08:46:04] ℹ️ **[Docs]** Creating README.md...
[08:46:04] ✅ **[Docs]** Created README.md from template

## 🔷 Project Creation Complete

[08:46:04] ✅ **[Summary]** Project created successfully!

**Configuration Summary**

| Property | Value |
|----------|-------|
| Export Scope | UNRESOLVED |
| Project | QUAL → QUAL1 |
| Include SubTasks | YES |
| Location | projects\QUAL |
| Source URL | https://onemain-migrationsandbox.atlassian.net/ |
| Target URL | https://onemainfinancial-migrationsandbox.atlassian.net/ |
| Name | EO - Quality Assurance → EO - Quality Assurance Sandbox |
| Template | STANDARD |
| Migrate Sprints | YES |



## 🔷 Step 01: Preflight Validation

[08:46:19] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\01_Preflight.ps1
[08:46:26] ✅ **[Runner]** Step 01 completed successfully

## 🔷 Step 02: Create Target Project

[08:46:35] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\02_CreateProject_FromSharedConfig.ps1
[08:46:43] ✅ **[Runner]** Step 02 completed successfully

## 🔷 Step 03: Migrate Users and Roles

[08:46:51] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\03_SyncUsersAndRoles.ps1
[08:49:15] ✅ **[Runner]** Step 03 completed successfully

## 🔷 Step 04: Components and Labels

[08:53:58] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\04_ComponentsAndLabels.ps1
[09:04:33] ✅ **[Runner]** Step 04 completed successfully
