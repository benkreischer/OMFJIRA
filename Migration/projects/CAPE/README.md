# CAPE Migration Project

**Created:** 2025-10-14  
**Source Project:** CAPE  
**Target Project:** CAPE1 (Sandbox)

---

## 🎯 Quick Start - 3 Simple Steps

> **Note:** This project was created using `.\CreateNewProject.ps1 -ProjectKey CAPE`

### Step 1: Configure Credentials (.env file)

Ensure the `.env` file in the `Migration` directory has your credentials:

```bash
USERNAME=your.email@company.com
JIRA_API_TOKEN=your_jira_api_token_here
ORGANIZATION_API_KEY=your_org_api_key_here
ORGANIZATION_ID=your_org_id_here
WORKSPACE_ID=your_workspace_id_here
```

### Step 2: Update Parameters

Edit `parameters.json` in this folder:
- **SourceEnvironment.BaseUrl** - Your source Jira URL
- **SourceEnvironment.ProjectKey** - Source project key (currently: CAPE)
- **TargetEnvironment.BaseUrl** - Your target Jira URL
- **TargetEnvironment.ProjectKey** - Target project key (currently: CAPE1)
- Leave Username/ApiToken/ProjectNames empty (auto-filled from .env and API)

### Step 3: Run Migration Using Launcher

```powershell
# From the Migration directory, run the interactive launcher:
.\RunMigration.ps1 -Project CAPE
```

The launcher will show you a menu. Run the steps in order from 01 to 18:
- Select step 01, let it complete
- Select step 02, let it complete
- Continue through step 18

**Or run steps directly by number:**

```powershell
.\RunMigration.ps1 -Project CAPE -Step 01
.\RunMigration.ps1 -Project CAPE -Step 02
.\RunMigration.ps1 -Project CAPE -Step 03
# ... continue through step 18
```

---

## 📂 Project Structure

```
CAPE/
├── parameters.json      # Migration configuration
├── out/                 # Output directory
│   ├── exports/         # Exported source data
│   ├── logs/            # Migration logs
│   ├── *.json           # Step receipts
│   ├── *.html           # Reports & dashboards
│   └── *.csv            # Data exports
└── README.md            # This file
```

---

## ✅ Migration Steps (Run via Launcher)

**All steps must be run using `.\RunMigration.ps1 -Project CAPE -Step ##`**

1. **Preflight** - Validates configuration, auto-updates ProjectNames
2. **Create Project** - Creates target project from template
3. **Sync Users and Roles** - Syncs users to target project
4. **Components and Labels** - Migrates components and labels
5. **Versions** - Migrates versions/releases
6. **Boards** - Creates boards and filters
7. **Export Issues** - Exports all issues from source
8. **Create Issues** - Creates issues in target
9. **Comments** - Migrates all comments
10. **Attachments** - Migrates all attachments
11. **Links** - Migrates issue and remote links
12. **Worklogs** - Migrates time tracking data
13. **Sprints** - Migrates sprint data
14. **Automations** - Interactive guide for automation rules
15. **Permissions and Schemes** - Validates permissions
16. **QA Validation** - Comprehensive quality checks
17. **Finalize** - Updates project descriptions and notifications
18. **Post-Migration Report** - Generates final report

---

## 🔧 Troubleshooting

### Common Issues

**"Missing required parameters" error**
- Ensure `.env` file exists in Migration directory
- Verify all required fields in `parameters.json` are filled

**"User not found in target" warnings**
- Users must be invited to target environment first
- Enable `AutoInvite` in `parameters.json` or manually invite users

**"Project already exists" error**
- Target project key already exists
- Either use existing project or choose different target key

**API authentication failures**
- Verify API tokens in `.env` are valid and not expired
- Ensure user has appropriate permissions in both environments

### Getting Help

- Check step receipts in `out/` directory for detailed error messages
- Review step logs in `out/logs/` directory
- Consult main Migration README for detailed documentation

---

## 📊 Migration Progress

Track your progress using the receipts in the `out/` directory:
- Each step creates a timestamped receipt (e.g., `20251010_120000-01_Preflight.json`)
- Each step also updates a reference receipt (e.g., `01_Preflight_receipt.json`)
- Step 18 generates comprehensive HTML and CSV reports

---

## 🎯 Next Steps

1. **Configure** - Update `parameters.json` with your project details
2. **Start** - Run `.\RunMigration.ps1 -Project CAPE`
3. **Execute** - Run steps 01-18 in sequence using the launcher
4. **Verify** - Review Step 18 report and validate migration quality

**Ready to start?**
```powershell
.\RunMigration.ps1 -Project CAPE
```

