# Multi-Project Migration Guide

**The toolkit now supports multiple concurrent migrations!**

---

## 🎯 Overview

The migration toolkit is organized to support multiple project migrations simultaneously, with clear separation of data and configuration.

---

## 📂 Folder Structure

```
Migration/
├── RunMigration.ps1            # Project launcher (NEW!)
├── src/
│   ├── steps/                  # Shared migration scripts (01-18)
│   ├── Utility/                # Shared utility scripts
│   └── DryRun_Master.ps1      # Shared dry run validator
│
├── projects/                   # ← Per-project folders
│   ├── DEP/                    # DevOps Engineering Platform
│   │   ├── parameters.json     # DEP configuration
│   │   ├── out/                # DEP outputs
│   │   └── README.md           # DEP notes
│   │
│   └── LAS/                    # LAS Project
│       ├── parameters.json     # LAS configuration
│       ├── out/                # LAS outputs
│       └── README.md           # LAS notes
│
├── docs/                       # Shared documentation
└── config/                     # (deprecated - use projects/)
```

---

## 🚀 Using The Project Launcher

### Quick Start
```powershell
cd Z:\Code\OMF\Migration

# List available projects
.\RunMigration.ps1 -ListProjects

# Run dry run for a project
.\RunMigration.ps1 -Project LAS -DryRun

# Run specific step
.\RunMigration.ps1 -Project LAS -Step 07

# Interactive menu
.\RunMigration.ps1 -Project LAS
```

### Options

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Project` | Project key (DEP, LAS, etc.) | `-Project LAS` |
| `-Step` | Step number (01-18) | `-Step 08` |
| `-DryRun` | Run validation only (no changes) | `-DryRun` |
| `-ListProjects` | Show all available projects | `-ListProjects` |

---

## 📊 Managing Multiple Projects

### Scenario 1: Parallel Migrations
```powershell
# Team A works on DEP
.\RunMigration.ps1 -Project DEP -Step 08

# Team B works on LAS (simultaneously!)
.\RunMigration.ps1 -Project LAS -Step 07

# No conflicts - data is isolated!
```

### Scenario 2: Sequential Migrations
```powershell
# Complete DEP first
.\RunMigration.ps1 -Project DEP
# ... complete all steps ...

# Then start LAS
.\RunMigration.ps1 -Project LAS
# ... complete all steps ...

# Both migrations preserved in their folders!
```

### Scenario 3: Re-running Previous Migration
```powershell
# DEP migration completed last week
# Need to re-run a step? No problem!

.\RunMigration.ps1 -Project DEP -Step 09  # Idempotent!
```

---

## 🆕 Adding a New Project

### Step 1: Create Project Folder
```powershell
$projectKey = "ENGOPS"  # Your project key

# Create structure
New-Item -ItemType Directory -Path ".\projects\$projectKey\out\exports" -Force
New-Item -ItemType Directory -Path ".\projects\$projectKey\out\logs" -Force
```

### Step 2: Create Parameters File
```powershell
# Copy template
Copy-Item ".\projects\LAS\parameters.json" ".\projects\$projectKey\parameters.json"

# Edit for your project
notepad ".\projects\$projectKey\parameters.json"
```

Update:
- `ProjectName`
- `SourceEnvironment.ProjectKey`
- `SourceEnvironment.ProjectName`
- `TargetEnvironment.ProjectKey`
- `TargetEnvironment.ProjectName`

### Step 3: Create README
```powershell
# Copy template
Copy-Item ".\projects\LAS\README.md" ".\projects\$projectKey\README.md"

# Customize
notepad ".\projects\$projectKey\README.md"
```

### Step 4: Validate
```powershell
.\RunMigration.ps1 -Project $projectKey -DryRun
```

### Step 5: Start Migration
```powershell
.\RunMigration.ps1 -Project $projectKey
```

---

## 📋 Project Configuration

Each project has its own `parameters.json` with:

### Required Settings:
- Source environment (URL, credentials, project key)
- Target environment (URL, credentials, project key)
- Output directory (`./out` - relative to project folder)

### Optional Settings:
- Status mappings
- Issue type mappings
- Sprint settings
- Custom field mappings
- Migration flags

**Note:** Output directory is `./out` which resolves relative to the project folder!

---

## 🔍 Finding Project Data

### List All Projects:
```powershell
Get-ChildItem .\projects\ -Directory
```

### Check Project Status:
```powershell
# DEP migration
Get-ChildItem .\projects\DEP\out\*_receipt.json

# LAS migration
Get-ChildItem .\projects\LAS\out\*_receipt.json
```

### View Project Reports:
```powershell
# DEP dashboard
Start-Process .\projects\DEP\out\master_qa_dashboard.html

# LAS dashboard (after migration)
Start-Process .\projects\LAS\out\master_qa_dashboard.html
```

---

## ✅ Benefits of Multi-Project Structure

### 1. **Clear Separation**
Each project has its own:
- Configuration
- Outputs
- Receipts
- Reports
- Logs

### 2. **Easy Archiving**
```powershell
# Archive completed migration
Move-Item .\projects\DEP\ .\archive\DEP-2025-10-05\
```

### 3. **Reusable Scripts**
All scripts are in `src/` - shared by all projects:
- No duplication
- Single source of truth
- Easy to maintain
- Consistent behavior

### 4. **Parallel Work**
- Multiple teams can work simultaneously
- No risk of overwriting data
- Independent timelines
- Clear ownership

### 5. **Historical Reference**
- Keep old migrations for reference
- Compare approaches
- Learn from past migrations
- Audit trail preserved

---

## 🛠️ Utility Scripts with Multiple Projects

### Remove Duplicates (Specific Project)
```powershell
.\src\Utility\08_RemoveDuplicatesIssues.ps1 -ParametersPath .\projects\DEP\parameters.json -DryRun
```

### Remove Comments (Specific Project)
```powershell
.\src\Utility\09_RemoveComments.ps1 -ParametersPath .\projects\LAS\parameters.json
```

### QA Validation (Specific Project)
```powershell
.\src\steps\16_QA_Validation_Orchestrator.ps1 -ParametersPath .\projects\LAS\parameters.json
```

---

## 📊 Comparing Projects

### View Side-by-Side:
```powershell
# DEP statistics
$depReceipt = Get-Content .\projects\DEP\out\08_CreateIssues_Target_receipt.json | ConvertFrom-Json
Write-Host "DEP: $($depReceipt.CreatedIssues) issues created"

# LAS statistics  
$lasReceipt = Get-Content .\projects\LAS\out\08_CreateIssues_Target_receipt.json | ConvertFrom-Json
Write-Host "LAS: $($lasReceipt.CreatedIssues) issues created"
```

---

## 🎓 Best Practices

### Do:
- ✅ Use project launcher for consistency
- ✅ Run dry run before each new project
- ✅ Keep project READMEs updated
- ✅ Archive completed migrations
- ✅ Use descriptive project folder names

### Don't:
- ❌ Mix data between projects
- ❌ Manually edit receipts
- ❌ Delete project folders (archive instead)
- ❌ Use same output directory for multiple projects
- ❌ Forget to update parameters.json for each project

---

## 📚 Documentation

### Project-Specific:
- Each project has its own README in `projects/{PROJECT}/README.md`

### Shared:
- Main guides in `docs/`
- [Workflow.md](Workflow.md) - Complete migration workflow
- [TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md) - Feature overview
- [IDEMPOTENCY_COMPLETE.md](IDEMPOTENCY_COMPLETE.md) - Safe re-runs

---

## 🎯 Migration Workflow (Multi-Project)

### For Each Project:

1. **Setup**
   ```powershell
   # Create project folder
   # Create parameters.json
   # Run dry run
   ```

2. **Execute**
   ```powershell
   .\RunMigration.ps1 -Project {KEY}
   # Follow steps 01-18
   ```

3. **Validate**
   ```powershell
   .\RunMigration.ps1 -Project {KEY} -Step 16
   ```

4. **Archive**
   ```powershell
   # Keep folder for reference
   # Or move to archive/
   ```

---

## ✨ This Makes The Toolkit:

- ✅ **Scalable** - Handle unlimited projects
- ✅ **Organized** - Clear data separation
- ✅ **Professional** - Enterprise-grade structure
- ✅ **Maintainable** - Easy to manage
- ✅ **Flexible** - Work on multiple projects

**Ready for enterprise-scale migrations!** 🌟

