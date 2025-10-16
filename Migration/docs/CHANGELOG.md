# CHANGELOG

All notable changes to the Migration toolkit are documented in this file.

## [Unreleased] - 2025-10-12
### Added
- Rewrote top-level `README.md` for clearer quick start instructions and concise workflow guidance.
- Added example project configuration: `projects/example/parameters.json` to help new users get started quickly.
- Added sample outputs for the example project:
  - `projects/example/out/logs/example-migration.log`
  - `projects/example/out/exports/export-receipt.json`
  - `projects/example/out/migration_progress.html`
- Added `quickstart.ps1` — a small orchestrator that runs DryRun → AutoRun → QA and saves receipts under `projects/[KEY]/out/`.

### Notes
- Example files are intentionally minimal and safe to inspect locally. Edit `projects/example/parameters.json` to point to your environments and tokens before running.
- The quickstart script assumes `RunMigration.ps1` is present and callable from the repository root.

---

For older history, see `docs/SESSION_SUMMARY_2025-10-12.md` and `docs/CODE_QUALITY_AUDIT_REPORT.md` for audit details.
