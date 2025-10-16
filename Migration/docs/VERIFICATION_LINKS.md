# Dashboard Verification Links

## Overview

The unified migration dashboard now includes **direct verification links** to Jira for each completed step. These links open both source and target project settings pages, making it easy to compare and verify that migrations were successful.

## Features

### 🔗 Direct Jira Links for Each Step

When you expand a completed step in the dashboard, you'll see "🔍 Verify" sections with clickable links:

| Step | Verification Links | Purpose |
|------|-------------------|---------|
| **02 - Create Project** | 📁 Target Project<br>⚙️ Project Settings | View target project and access settings |
| **03 - Sync Users** | 👥 Source Project Roles<br>👥 Target Project Roles | Compare user roles and permissions |
| **04 - Components** | 📦 Source Components<br>📦 Target Components | Verify all components match |
| **05 - Versions** | 🏷️ Source Versions<br>🏷️ Target Versions | Verify all versions match |
| **06 - Boards** | 📊 Source Boards<br>📊 Target Boards | Compare board configurations |
| **08 - Create Issues** | 🎫 Source Issues<br>🎫 Target Issues | Browse and compare issue lists |
| **13 - Sprints** | 🏃 Source Sprints<br>🏃 Target Sprints | Verify sprints (via boards page) |

### 🎯 Example: Verifying Components

```
Step 04: Components and Labels ✓
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
┌─────────────────────────┐
│ 23 Components Created   │
│ 57 Unique Labels        │
└─────────────────────────┘

🔍 Verify Components Match:
[📦 Source Components ↗]  [📦 Target Components ↗]
```

Clicking these buttons opens:
- **Source**: `https://onemain.atlassian.net/plugins/servlet/project-config/DEP/administer-components`
- **Target**: `https://onemainfinancial-sandbox-575.atlassian.net/plugins/servlet/project-config/DEP1/administer-components`

You can then visually compare the two pages side-by-side to ensure all components were migrated correctly.

## How It Works

### URL Resolution

The dashboard automatically loads Jira base URLs from `parameters.json`:

```json
{
  "SourceEnvironment": {
    "BaseUrl": "https://onemain.atlassian.net/"
  },
  "TargetEnvironment": {
    "BaseUrl": "https://onemainfinancial-sandbox-575.atlassian.net/",
    "ProjectKey": "DEP1"
  }
}
```

These URLs are combined with project-specific paths to generate direct deep links to Jira settings pages.

### Jira URL Patterns Used

| Resource | URL Pattern |
|----------|-------------|
| Project Browse | `{base}/browse/{key}` |
| Project Settings | `{base}/plugins/servlet/project-config/{key}/summary` |
| Project Roles | `{base}/plugins/servlet/project-config/{key}/people` |
| Components | `{base}/plugins/servlet/project-config/{key}/administer-components` |
| Versions | `{base}/plugins/servlet/project-config/{key}/administer-versions` |
| Boards | `{base}/jira/software/c/projects/{key}/boards` |

## Benefits

✅ **Instant Access** - No hunting for URLs or navigating through Jira menus
✅ **Side-by-Side Comparison** - Open source and target in separate tabs
✅ **Context-Aware** - Links only appear for completed steps
✅ **Safe Clicking** - Links use `event.stopPropagation()` so clicking them won't collapse the step

## Technical Implementation

### Changes to `_dashboard.ps1`

1. **`Format-ReceiptSummary` Function**:
   - Now accepts `$SourceBase`, `$TargetBase`, `$SourceProjectKey`, `$TargetProjectKey` parameters
   - Constructs Jira URLs for each step type
   - Adds styled "🔍 Verify" sections with clickable links

2. **`Update-UnifiedDashboard` Function**:
   - Loads `parameters.json` from project directory
   - Extracts `BaseUrl` from `SourceEnvironment` and `TargetEnvironment`
   - Passes URLs to `Format-ReceiptSummary` for each completed step

3. **No Changes to Migration Scripts**:
   - All existing scripts work without modification
   - URLs are derived from existing configuration files

## Browser Compatibility

All links use standard `<a href="">` tags with `target='_blank'` to open in new tabs. Works in:
- ✅ Chrome
- ✅ Firefox
- ✅ Edge
- ✅ Safari

## Security Notes

- Links include your Jira domain names (already configured in `parameters.json`)
- API tokens are **never** included in dashboard HTML
- Links require you to be logged into Jira to view the pages
- If not logged in, Jira will prompt for authentication

## Troubleshooting

**Q: Links aren't appearing for some steps**

A: Verify that `parameters.json` exists and has valid `BaseUrl` values:
```powershell
Get-Content "projects\DEP\parameters.json" | ConvertFrom-Json | Select-Object -ExpandProperty SourceEnvironment
Get-Content "projects\DEP\parameters.json" | ConvertFrom-Json | Select-Object -ExpandProperty TargetEnvironment
```

**Q: Links open but show "Project not found"**

A: The project key might have changed. Check the receipt files to see what keys were actually used.

**Q: Clicking a link collapses the step**

A: This shouldn't happen anymore - we added `event.stopPropagation()`. If it does, please report as a bug.

## Future Enhancements

Potential additions for future versions:
- 🔮 Direct links to automation rules pages (when Step 14 runs)
- 🔮 Direct links to permission schemes (when Step 15 runs)
- 🔮 JQL queries pre-populated for issue comparisons
- 🔮 Deep links to specific configuration pages (workflows, fields, screens)
- 🔮 "Open both in split view" button for side-by-side comparison

---

**Last Updated**: 2025-10-11
**Version**: 1.0

