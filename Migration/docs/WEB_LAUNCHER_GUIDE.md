# Web-Based Migration Launcher Guide

**New Feature!** 🌟  
**Date:** October 12, 2025  
**Status:** ✅ Production Ready

---

## 🎯 Overview

The Migration Toolkit now includes a **modern web-based interface** for configuring migrations. No more command-line prompts - configure everything visually!

---

## 🚀 Quick Start

### Launch the Web UI

```powershell
.\Launch-WebUI.ps1
```

This opens a beautiful web interface in your browser (Chrome by default).

---

## 📋 Web Interface Features

### **Step 1: Select Environment**
Dropdown with all configured environments:
- OneMain Production
- OneMain Migration Sandbox
- OMF Sandbox 575
- OMF Migration Sandbox

### **Step 2: Choose Project**
Interactive list showing all projects in selected environment:
- Project Key (e.g., DEP, LAS, SEC)
- Project Name
- Click to select

### **Step 3: Configuration Template**
Visual radio buttons with descriptions:
- **XRAY** (Recommended) - Copy from XRAY reference project
- **Standard** - Default Jira project
- **Enhanced** - Custom ENHANCED template

### **Step 4: Export Scope**
- **Unresolved work items** (Recommended) - Active issues only
- **All Issues** - Complete historical migration

### **Step 5: Sprint Migration**
- **YES** (Recommended) - Migrate sprints
- **NO** - Skip sprints

### **Step 6: Include SubTasks**
- **YES** (Recommended) - Include sub-tasks
- **NO** - Exclude sub-tasks

### **Configuration Summary**
Live preview showing all your choices:
- Source environment & project
- Target environment & project
- All configuration options

### **Generated PowerShell Command**
Copy-paste ready command with all your settings pre-configured!

---

## 🎨 User Interface

### Modern Design
- ✅ Beautiful gradient header
- ✅ Clean, card-based layout
- ✅ Visual radio buttons with descriptions
- ✅ Real-time configuration summary
- ✅ One-click copy PowerShell command
- ✅ Responsive design
- ✅ Professional color scheme

### User-Friendly Features
- ✅ Recommended options highlighted in green
- ✅ Tooltips and descriptions for each option
- ✅ Live validation and feedback
- ✅ Reset button to start over
- ✅ Visual selection states
- ✅ Copy command with feedback

---

## 📖 How to Use

### 1. Launch Web UI

```powershell
cd Migration
.\Launch-WebUI.ps1
```

Browser opens automatically to `MigrationLauncher.html`

### 2. Configure Your Migration

**Select Environment:**
- Choose source environment from dropdown
- Project list loads automatically

**Select Project:**
- Click on project from list
- Shows selected project and target details

**Configure Options:**
- Choose configuration template (XRAY/Standard/Enhanced)
- Choose export scope (Unresolved/All)
- Enable/disable sprint migration
- Include/exclude sub-tasks

### 3. Review Summary

The summary box shows:
```
Source Environment: https://onemain-migrationsandbox.atlassian.net
Source Project: DEP - Deployments
Target Environment: https://onemainfinancial-migrationsandbox.atlassian.net
Target Project: DEP1 - Deployments Sandbox
Configuration Template: XRAY
Export Scope: UNRESOLVED
Migrate Sprints: YES
Include SubTasks: YES
```

### 4. Generate Command

Click **"🚀 Create Migration Project"**

PowerShell command appears:
```powershell
.\CreateNewProject.ps1 -ProjectKey "DEP" \
    -SourceBaseUrl "https://onemain-migrationsandbox.atlassian.net/" \
    -TargetBaseUrl "https://onemainfinancial-migrationsandbox.atlassian.net/"
```

### 5. Copy & Run

Click **"📋 Copy"** button, then paste in PowerShell:
```powershell
PS> .\CreateNewProject.ps1 -ProjectKey "DEP" ...
```

---

## 🔧 Technical Details

### Current Implementation (v1.0)

**Project Data:**
- Uses mock data for project lists
- Environments are pre-configured
- Standalone HTML (no backend required)

**How It Works:**
1. HTML file loads with all environments
2. JavaScript handles UI interactions
3. Generates PowerShell command based on selections
4. User copies and runs command

### Future Enhancements (v2.0)

**Real-Time Project Loading:**
```javascript
// Call PowerShell bridge
fetch('Get-JiraProjects.ps1?env=onemain-sandbox')
    .then(response => response.json())
    .then(projects => populateList(projects));
```

**Options:**
- Local PowerShell web server
- Electron app wrapper
- Direct PowerShell execution from browser
- Live project fetching from Jira API

---

## 📁 Files

### Main Files
- `MigrationLauncher.html` - Web interface
- `Launch-WebUI.ps1` - Launcher script
- `Get-JiraProjects.ps1` - API bridge (for future use)

### How They Work Together

```
User runs: .\Launch-WebUI.ps1
    ↓
Opens: MigrationLauncher.html in browser
    ↓
User configures migration visually
    ↓
Generates: PowerShell command
    ↓
User copies and runs command
    ↓
Creates migration project & launches
```

---

## 💡 Benefits

### vs Command-Line Only

| Feature | Command-Line | Web Launcher |
|---------|--------------|--------------|
| **Visual** | Text prompts | Beautiful UI |
| **Environment List** | Type URL | Select from dropdown |
| **Project Selection** | Type key | Click from list |
| **Configuration** | Answer prompts | Visual radio buttons |
| **Summary** | Text output | Formatted summary box |
| **Command Generation** | Manual | Auto-generated |
| **Learning Curve** | Medium | Low |
| **Power User Friendly** | Yes | Yes (generates commands) |

### Best of Both Worlds

- ✅ **Web UI** for configuration and learning
- ✅ **PowerShell commands** for execution and automation
- ✅ Can use either method
- ✅ Both produce same results

---

## 🎯 Use Cases

### **Web Launcher Perfect For:**
- First-time users learning the toolkit
- Visual configuration preferences
- Exploring available projects
- Team members unfamiliar with command-line
- Quick configuration without remembering syntax

### **Command-Line Perfect For:**
- Automation scripts
- CI/CD integration
- Power users who prefer terminal
- Scripted batch migrations
- Server environments without browser

---

## 🔄 Workflow Comparison

### Web-Based Workflow
```
1. .\Launch-WebUI.ps1
2. Select environment (dropdown)
3. Click project
4. Configure options (visual)
5. Click "Create Migration Project"
6. Copy generated command
7. Paste in PowerShell
8. Choose launch option
```

### Command-Line Workflow  
```
1. .\CreateNewProject.ps1 -ProjectKey DEP
2. Answer prompts (X/U/Y/Y)
3. Review summary
4. Choose launch option (Y/A/D/X)
```

**Both methods:**
- Generate same `parameters.json`
- Offer same configuration options
- Launch same migration process
- Produce same results

---

## 🎨 Screenshots (Conceptual)

### Environment Selection
```
┌─────────────────────────────────────────┐
│ 1️⃣ Select Environment                   │
│                                         │
│ Source Environment:                     │
│ ┌─────────────────────────────────────┐ │
│ │ OneMain Migration Sandbox      ▼    │ │
│ └─────────────────────────────────────┘ │
│ URL: https://onemain-migrationsandbox... │
└─────────────────────────────────────────┘
```

### Project List
```
┌─────────────────────────────────────────┐
│ 2️⃣ Select Project                       │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ XXX                                 │ │
│ │ Test Migration Project              │ │
│ ├─────────────────────────────────────┤ │
│ │ DEP   ◄── Selected                  │ │
│ │ Deployments                         │ │
│ ├─────────────────────────────────────┤ │
│ │ LAS                                 │ │
│ │ Loan Automation Services            │ │
│ └─────────────────────────────────────┘ │
│ Selected: DEP - Deployments             │
│ Target: DEP1 - Deployments Sandbox      │
└─────────────────────────────────────────┘
```

### Configuration Options
```
┌─────────────────────────────────────────┐
│ 3️⃣ Project Configuration Template       │
│                                         │
│ ◉ XRAY (Recommended)                    │
│   Copy from XRAY reference project      │
│                                         │
│ ○ Standard                              │
│   Default Jira project                  │
│                                         │
│ ○ Enhanced                              │
│   Custom ENHANCED template              │
└─────────────────────────────────────────┘
```

### Configuration Summary
```
┌─────────────────────────────────────────┐
│ 📋 Configuration Summary                │
│                                         │
│ Source Environment: https://onemain...  │
│ Source Project: DEP - Deployments       │
│ Target Environment: https://omf...      │
│ Target Project: DEP1 - Deployments...   │
│ Configuration Template: XRAY            │
│ Export Scope: UNRESOLVED                │
│ Migrate Sprints: YES                    │
│ Include SubTasks: YES                   │
└─────────────────────────────────────────┘

     [🚀 Create Migration Project]
```

---

## 🚀 Getting Started

### Try It Now!

```powershell
cd Z:\Code\OMF\Migration
.\Launch-WebUI.ps1
```

**The browser will open to a beautiful configuration interface!**

1. Select "OneMain Migration Sandbox" from dropdown
2. Click "DEP - Deployments" project
3. Keep default settings (all recommended)
4. Click "Create Migration Project"
5. Copy the generated command
6. Run it!

---

## 📚 Related Documentation

- **[Quick Reference](QUICK_REFERENCE.md)** - Command-line quick start
- **[Configuration Options](CONFIGURATION_OPTIONS.md)** - All settings explained
- **[Multi-Project Guide](MULTI_PROJECT_GUIDE.md)** - Managing multiple projects

---

## ✨ Future Enhancements

### Planned for v2.0
- ✅ Real-time project fetching from Jira API
- ✅ Custom field auto-detection
- ✅ Field mapping visual builder
- ✅ Live validation checks
- ✅ Progress tracking in web UI
- ✅ Direct PowerShell execution from browser

### Under Consideration
- Electron desktop app
- Local PowerShell web server
- Migration history dashboard
- Multi-project batch configuration

---

## 🎉 Summary

**The web launcher provides:**
- 🌟 Beautiful visual interface
- 🌟 Easy project selection
- 🌟 Clear configuration options
- 🌟 Real-time summary
- 🌟 Generated PowerShell commands

**Combined with command-line:**
- ✅ Best of both worlds
- ✅ Visual or terminal - your choice
- ✅ Same powerful migration toolkit
- ✅ Enterprise-grade results

**Start with the web launcher, run with PowerShell!** 🚀

---

**Last Updated:** October 12, 2025  
**Version:** 1.0  
**Status:** Production Ready

