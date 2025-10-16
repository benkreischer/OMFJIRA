# Jira Migration Toolkit
OMF Migration Suite

**Status:** ✅ Sandbox Ready  
**Last Updated:** October 12, 2025

---

## 🎯 Quick Start
Command-Line (Classic)

```powershell
# Create a new migration project - Interactive prompts
.\CreateNewProject.ps1 -ProjectKey "ABC"
```

# Jira Migration Toolkit

This repository contains a modular, idempotent set of PowerShell scripts, utilities, and documentation that together automate project creation, configuration copying, issue export/import, attachments, links, worklogs, sprints, and a comprehensive QA verification system.

## Highlights
- Modular 16-step migration flow covering project creation, users & roles, issues, comments, attachments, links, worklogs, sprints, post-migration review, and Confluence publishing.
- Idempotent design: safe to re-run steps when recovery or retries are needed.
- Live HTML dashboards and interactive QA reports for fast validation and stakeholder-ready outputs.
- Config-driven: global defaults in `config/migration-parameters.json` and per-project overrides in `projects/[KEY]/parameters.json`.

- CLI (recommended for automation or advanced users)
  - Create a new project config: `.\CreateNewProject.ps1 -ProjectKey "ABC"`
  - Edit `projects/ABC/parameters.json` to tune template, scope, and options.
  - Run the full migration (auto-run mode): `.\RunMigration.ps1 -Project ABC -AutoRun`
  - Run interactively (step-by-step): `.\RunMigration.ps1 -Project ABC` and choose Interactive mode.

Tip: Use `-DryRun` to validate configuration without making changes.

## Typical workflow (recommended)

1. Create or copy project config: `.\CreateNewProject.ps1 -ProjectKey ABC`.
2. Inspect and edit `projects/ABC/parameters.json` if you need to change templates or scope.
3. Run in `-AutoRun` for a full migration, or run individual steps when troubleshooting.
4. After completion, run the QA step to validate everything: `.\RunMigration.ps1 -Project ABC -Step 16`.

## What the toolkit does (concise)

- Project creation and configuration copy (templates: XRAY, STANDARD, ENHANCED)
- User and role synchronization
- Components, labels, versions, boards
- Export issues from source (scopes: ALL or UNRESOLVED)
- Create issues in target while preserving historical timestamps and authors
- Migrate comments, attachments, links (including remote links), worklogs, and sprints
- Produce interactive HTML dashboards and QA reports

## Important files & directories

- `config/migration-parameters.json` — global defaults and feature toggles
- `src/_common.ps1` — shared helper functions
- `src/_dashboard.ps1` — dashboard and reporting helpers
- `src/steps/` — migration steps (01_Preflight..16_PushToConfluence and archived steps)
- `src/Utility/` — helper utilities (cleanup, permission checks, restore helpers)
- `projects/[PROJECT_KEY]/parameters.json` — per-project config and overrides
- `projects/[PROJECT_KEY]/out/` — migration output: logs, exports, receipts, and dashboards

## Configuration highlights

- Project template: set `ProjectCreation.ConfigurationTemplate` to `XRAY`, `STANDARD`, or `ENHANCED` in `projects/[KEY]/parameters.json`.
- Export scope: `IssueExportSettings.Scope` — `UNRESOLVED` (recommended) or `ALL`.
- Remote link fallback: enable `CreateRemoteLinksForSkipped` to try to preserve cross-project references when direct links cannot be migrated.

## Execution modes

- AutoRun: full non-interactive run with dashboard (`-AutoRun`).
- Interactive: step-by-step selection and manual control.
- DryRun: validate config and run validations without making changes.

## QA and validation

Run the QA step (16) for a comprehensive validation suite:
- 30+ checks across issues, related items (comments, attachments, links, worklogs), and cross-step consistency.
- Generates stakeholder-ready HTML reports with drill-down and suggested remediations.

## Troubleshooting & common tasks

- Permission issues: use `src/Utility/CheckProjectPermissions.ps1` and review the generated Permission Validation Report.
- Duplicates: the QA system will flag duplicates; use the QA dashboard to view suggested fixes.
- Missing links or remote links: see `docs/HANDLING_LINKS_GUIDE.md` and enable `CreateRemoteLinksForSkipped` when appropriate.
- SSL issues: see `docs/SSL_TROUBLESHOOTING_GUIDE.md` for connection diagnostics.

## Extending & customizing

- Add per-project overrides in `projects/[KEY]/parameters.json`.
- Add or modify steps under `src/steps/` — follow the existing step naming and logging conventions.
- Utilities in `src/Utility/` provide reusable building blocks for feature additions.

## Directory map (short)

Migration/
├─ config/                 # Default configuration templates
├─ docs/                   # User & technical guides (21+ files)
├─ src/
│  ├─ steps/               # Migration step scripts
│  ├─ Utility/             # Utility scripts
│  └─ _common.ps1
├─ projects/               # Per-project configs & outputs
└─ Launch-WebUI.ps1        # Optional web UI launcher

## Next steps and recommended checks

1. Review `projects/EXAMPLE/parameters.json` (if present) and create your project config.
2. Run `.\RunMigration.ps1 -Project YOURKEY -DryRun` and fix any preflight warnings.
3. Run full migration with `-AutoRun` and then `-Step 16` for QA.
4. Archive project outputs in `projects/[KEY]/out/` for auditing and rollback.

## Where to find more help

- Read the detailed guides in `docs/` (configuration, QA, links handling, SSL troubleshooting, etc.).
- Each script includes header documentation and usage examples.

If you'd like, I can:
- add a short example `projects/example/parameters.json` and a minimal sample output folder,
- or create a small quickstart script that runs DryRun → AutoRun → QA in sequence.

---

Maintainers: check `docs/SESSION_SUMMARY_2025-10-12.md` for recent changes and the code quality audit in `docs/CODE_QUALITY_AUDIT_REPORT.md`.
