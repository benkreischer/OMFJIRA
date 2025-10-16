# Migration Log: DAWA
**Operation:** ProjectCreation  
**Started:** 2025-10-14 03:53:30  
**Log File:** `projects\DAWA\out\20251014_035330_DAWA_ProjectCreation.log.md`

---


## 🔷 Create New Migration Project: DAWA


### ▫️ Validation

[03:53:30] ✅ **[Validation]** Project key format is valid: DAWA
[03:53:30] ✅ **[Validation]** Project directory is available

### ▫️ Fetch Project Details from Jira

[03:53:30] ℹ️ **[API]** Connecting to source Jira...
[03:53:30] ℹ️ **[Auth]** Loading API credentials from .env...
[03:53:30] ✅ **[Auth]** API credentials loaded
[03:53:30] ℹ️ **[API]** Fetching project: https://onemain.atlassian.net/rest/api/3/project/DAWA
[03:53:31] ✅ **[API]** Found project: Data Warehouse (Key: DAWA)

**Project Details**

| Property | Value |
|----------|-------|
| Project Name | Data Warehouse |
| Target Name | Data Warehouse Sandbox |
| Project Key | DAWA |



### ▫️ Create Project Structure

[03:53:41] ℹ️ **[FileSystem]** Creating project directory: projects\DAWA
[03:53:41] ✅ **[FileSystem]** Created project directory: projects\DAWA
[03:53:41] ℹ️ **[FileSystem]** Creating output directories...
[03:53:41] ✅ **[FileSystem]** Created output directories (out, exports, logs)

### ▫️ Generate Configuration Files

[03:53:41] ℹ️ **[Config]** Creating parameters.json...

**Template Configuration**

| Property | Value |
|----------|-------|
| Export Scope | UNRESOLVED |
| Template Project Key | XRAY |
| Template Environment | TARGET (onemainfinancial-migrationsandbox) |
| Migrate Sprints | YES |
| Include SubTasks | YES |
| Template URL | https://onemainfinancial-migrationsandbox.atlassian.net/ |
| Template Type | XRAY |


[03:53:41] ✅ **[Config]** Created parameters.json with migration settings
[03:53:41]   → Config file: projects\DAWA\parameters.json
[03:53:41]   → Template source: Project 'XRAY' in onemainfinancial-migrationsandbox.atlassian.net
[03:53:41] ℹ️ **[Docs]** Creating README.md...
[03:53:41] ✅ **[Docs]** Created README.md from template

## 🔷 Project Creation Complete

[03:53:41] ✅ **[Summary]** Project created successfully!

**Configuration Summary**

| Property | Value |
|----------|-------|
| Migrate Sprints | YES |
| Include SubTasks | YES |
| Project | DAWA → DAWA1 |
| Target URL | https://onemainfinancial-migrationsandbox.atlassian.net/ |
| Source URL | https://onemain.atlassian.net/ |
| Location | projects\DAWA |
| Name | Data Warehouse → Data Warehouse Sandbox |
| Template | XRAY |
| Export Scope | UNRESOLVED |



---

## Summary

✅ **COMPLETED SUCCESSFULLY**

**Duration:** 00:00:17  
**Completed:** 2025-10-14 03:53:47

Project DAWA created successfully and ready for migration. All configuration files generated.


## 🔷 Step 01: Preflight Validation

[03:54:30] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\01_Preflight.ps1
[03:54:32] ✅ **[Runner]** Step 01 completed successfully

## 🔷 Step 02: Create Target Project

[03:54:40] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\02_CreateProject_FromSharedConfig.ps1
[03:54:48] ✅ **[Runner]** Step 02 completed successfully

## 🔷 Step 03: Migrate Users and Roles

[03:54:59] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\03_SyncUsersAndRoles.ps1
[03:55:57] ✅ **[Runner]** Step 03 completed successfully

## 🔷 Step 04: Components and Labels

[03:58:56] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\04_ComponentsAndLabels.ps1
[03:59:54] ✅ **[Runner]** Step 04 completed successfully

## 🔷 Step 05: Versions

[04:02:35] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\05_Versions.ps1
[04:02:53] ✅ **[Runner]** Step 05 completed successfully

## 🔷 Step 05: Versions

[04:03:42] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\05_Versions.ps1
[04:03:46] ✅ **[Runner]** Step 05 completed successfully

## 🔷 Step 06: Boards

[04:03:57] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\06_Boards.ps1
[04:04:52] ✅ **[Runner]** Step 06 completed successfully

## 🔷 Step 07: Export Issues from Source

[04:08:06] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\07_ExportIssues_Source.ps1
[04:09:17] ✅ **[Runner]** Step 07 completed successfully

## 🔷 Step 08: Create Issues in Target

[04:11:24] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\08_CreateIssues_Target.ps1
[04:22:38] ✅ **[Runner]** Step 08 completed successfully

## 🔷 Step 09: Migrate Comments

[04:22:48] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\09_Comments.ps1
[04:24:46] ✅ **[Runner]** Step 09 completed successfully

## 🔷 Step 10: Migrate Attachments

[04:25:01] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\10_Attachments.ps1
[04:33:20] ✅ **[Runner]** Step 10 completed successfully

## 🔷 Step 11: Migrate Links

[04:35:06] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\11_Links.ps1
[04:39:50] ✅ **[Runner]** Step 11 completed successfully

## 🔷 Step 12: Migrate Worklogs

[04:40:31] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\12_Worklogs.ps1
[04:41:26] ✅ **[Runner]** Step 12 completed successfully

## 🔷 Step 13: Migrate Sprints

[04:41:48] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\13_Sprints.ps1
[04:42:56] ✅ **[Runner]** Step 13 completed successfully

## 🔷 Step 14: History Migration

[04:43:06] ℹ️ **[Runner]** Executing: Z:\Code\OMF\Migration\src\steps\14_HistoryMigration.ps1
