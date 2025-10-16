# Handling Skipped and Remote Links in Jira Migration

## Overview

During Jira migrations, issue links can be challenging to handle, especially when dealing with:
- **Skipped Links**: Links to issues not included in the migration (cross-project links)
- **Remote Links**: Links to external systems (Confluence, GitHub, web URLs, etc.)

This document explains how our migration handles these scenarios and provides best practices.

## Types of Links in Jira

### 1. Issue Links (Internal)
Standard links between Jira issues (blocks, relates to, duplicates, etc.)
- ✅ **Migrated by**: `11_Links.ps1`
- **Behavior**: Successfully migrated when both issues are in migration scope

### 2. Remote Links (External)
Links to external resources:
- Confluence pages
- Other Jira instances  
- GitHub/BitBucket PRs
- Generic web URLs
- ✅ **Migrated by**: `11a_RemoteLinks.ps1`

### 3. Skipped Links (Cross-Project)
Links to issues NOT included in migration:
- Cross-project links where target project wasn't migrated
- Links to archived issues
- Links to restricted issues
- ⚠️ **Handled by**: `11_Links.ps1` with `-CreateRemoteLinksForSkipped` option

## Migration Script

### `11_Links.ps1` - Unified Link Migration (Issue Links + Remote Links)

**Default Behavior:**
```powershell
.\Migration\src\steps\11_Links.ps1
```
**Migrates BOTH:**
- ✅ Issue links between migrated issues (blocks, relates to, etc.)
- ✅ Remote links (Confluence pages, GitHub, web URLs, etc.)
- ⏭️  Skips cross-project issue links to non-migrated issues
- 📊 Tracks all skipped links in receipt

**Enhanced Behavior (Remote Link Fallback):**
```powershell
.\Migration\src\steps\11_Links.ps1 -CreateRemoteLinksForSkipped
```
**Migrates:**
- ✅ All issue links between migrated issues
- ✅ All remote links (Confluence, GitHub, etc.)
- ✅ **Converts skipped cross-project links to remote links** pointing back to source instance
- 🔗 Preserves link relationship in remote link metadata
- 👆 Users can click through to view non-migrated issues

**When to use each:**
- **Default**: Test migrations, partial migrations where you'll merge later
- **With flag**: Production migrations where cross-project links should remain accessible

**What Gets Migrated:**
1. **Issue Links** (internal relationships):
   - Blocks / Is Blocked By
   - Relates To
   - Duplicates / Is Duplicated By
   - Clones / Is Cloned By
   - Causes / Is Caused By
   - Custom link types

2. **Remote Links** (external references):
   - Confluence page links
   - GitHub PR/Issue links
   - BitBucket links
   - External system links (SpiraPlan, etc.)
   - Generic web URLs

### Post-Migration Reporting (Includes Skipped Links)

```powershell
.\src\steps\18_PostMigration_Report.ps1
```

Generates comprehensive reports including:
- 📊 **Overall migration summary** (HTML, CSV, JSON)
- 🔗 **Skipped links report** (automatically included if links were skipped)
- 📄 **CSV export** for analysis
- 💡 **Recommendations** for handling skipped links

**Note:** Skipped links reporting is now integrated into the main post-migration report (Step 18).

## Migration Workflow

### Standard Workflow (All Projects)

```powershell
# When migrating all related projects together
.\Migration\src\steps\11_Links.ps1
```

**Result**: All issue links AND remote links migrated successfully, minimal skipped links.

### Partial Migration Workflow

```powershell
# When migrating only some projects
.\src\steps\11_Links.ps1                      # Migrate all links (some skipped)
.\src\steps\18_PostMigration_Report.ps1       # Generates report including skipped links
```

**Review the report**, then decide:

**Option A: Create Remote Link Fallbacks**
```powershell
# Re-run with fallback enabled
.\Migration\src\steps\11_Links.ps1 -CreateRemoteLinksForSkipped
```
- Creates clickable links back to source instance
- Preserves relationship information
- Users can access non-migrated issues

**Option B: Migrate Additional Projects**
- Include linked projects in next migration phase
- Re-run link migration after all projects migrated

**Option C: Accept Skipped Links**
- Provide report to stakeholders
- Handle critical links manually
- Document for future reference

## Best Practices

### 1. Plan Cross-Project Dependencies

**Before migration:**
```powershell
# Analyze which projects are linked
.\Migration\src\steps\11_Links.ps1   # Run once
.\Migration\src\steps\18a_SkippedLinks_Report.ps1   # See dependencies
```

Review the report to identify which projects should be migrated together.

### 2. Phased Migration Strategy

**Phase 1: Core Projects**
```powershell
# Migrate primary projects
.\Migration\src\steps\11_Links.ps1 -CreateRemoteLinksForSkipped
```
- Use remote link fallback to maintain access
- Links remain functional during migration

**Phase 2: Dependent Projects**
```powershell
# Migrate remaining projects
# Links between Phase 1 and Phase 2 will connect automatically
```

### 3. Testing Approach

**Test Migration:**
```powershell
# Don't create remote links in test
.\Migration\src\steps\11_Links.ps1
.\Migration\src\steps\18a_SkippedLinks_Report.ps1
```
- Review skipped links
- Validate approach
- Adjust migration scope

**Production Migration:**
```powershell
# Create remote links for accessibility
.\Migration\src\steps\11_Links.ps1 -CreateRemoteLinksForSkipped
.\Migration\src\steps\11a_RemoteLinks.ps1
```

### 4. Post-Migration Verification

After migration:
1. ✅ Check link counts in target vs source
2. ✅ Verify critical cross-project links work
3. ✅ Test remote link functionality
4. ✅ Review skipped links report with stakeholders

## Troubleshooting

### "Too many skipped links"

**Cause**: Many cross-project dependencies not in migration scope

**Solution**:
1. Review `18a_SkippedLinks_Report.ps1` output
2. Identify primary linked projects
3. Include them in migration scope
4. OR use `-CreateRemoteLinksForSkipped` flag

### "Remote links not working"

**Cause**: Source instance URL changed or authentication required

**Solution**:
1. Verify source instance still accessible
2. Check application links configuration
3. Update remote link URLs if needed

### "Duplicate links created"

**Cause**: Running link migration multiple times

**Solution**:
- Links are NOT idempotent
- Only run once per migration
- Use cleanup scripts if needed to remove duplicates

## Examples

### Example 1: Single Project Migration

```powershell
# Scenario: Migrating PROJECT-A only
# PROJECT-A has links to PROJECT-B (not migrating)

# Step 1: Run migration with remote link fallback
.\Migration\src\steps\11_Links.ps1 -CreateRemoteLinksForSkipped

# Step 2: Migrate external remote links
.\Migration\src\steps\11a_RemoteLinks.ps1

# Result: 
# - Internal PROJECT-A links: Migrated as issue links
# - Links to PROJECT-B: Converted to remote links (clickable)
# - Confluence/external links: Migrated as remote links
```

### Example 2: Multi-Project Migration

```powershell
# Scenario: Migrating PROJECT-A and PROJECT-B together

# Step 1: Migrate both projects (steps 1-10)
# Step 2: Run link migration (no flag needed)
.\Migration\src\steps\11_Links.ps1

# Step 3: Migrate remote links
.\Migration\src\steps\11a_RemoteLinks.ps1

# Result:
# - All internal links work perfectly
# - Minimal skipped links
# - External links migrated
```

### Example 3: Analysis Only

```powershell
# Scenario: Want to understand dependencies before migrating

# Step 1: Run test migration (steps 1-10) with test data
# Step 2: Migrate links without fallback
.\Migration\src\steps\11_Links.ps1

# Step 3: Generate report
.\Migration\src\steps\18a_SkippedLinks_Report.ps1

# Review HTML report to plan full migration
```

## Receipt Files

Each script creates a detailed receipt in `out/` directory:

### `11_Links_receipt.json`
```json
{
  "MigratedLinks": 494,
  "SkippedLinks": 135,
  "SkippedLinkDetails": [...]
}
```

### `11a_RemoteLinks_receipt.json`
```json
{
  "MigratedRemoteLinks": 89,
  "RemoteLinksByType": {...}
}
```

### Generated Reports

- `skipped_links_report.html` - Interactive web report
- `skipped_links_report.csv` - Excel-compatible export

## Summary

| Scenario | Script | Flag | Result |
|----------|--------|------|--------|
| Full migration (all projects) | `11_Links.ps1` | None | ✅ All links work |
| Partial migration (preserve access) | `11_Links.ps1` | `-CreateRemoteLinksForSkipped` | ✅ Clickable links to source |
| Partial migration (analyze later) | `11_Links.ps1` | None | ⚠️ Links skipped, tracked |
| External links | `11a_RemoteLinks.ps1` | N/A | ✅ All external links |
| Report generation | `18a_SkippedLinks_Report.ps1` | N/A | 📊 Analysis & recommendations |

## Support

For questions or issues:
1. Check the generated HTML report for specific recommendations
2. Review the receipt JSON files for detailed migration data
3. Consult Atlassian documentation on issue links and remote links

