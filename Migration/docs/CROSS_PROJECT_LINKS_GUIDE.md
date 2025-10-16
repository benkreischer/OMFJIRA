# Cross-Project Links - Documentation & Restoration Guide

## Overview

When migrating a Jira project, links to issues in other projects (e.g., CUSTIAM, JIRA, etc.) cannot be migrated because those issues don't exist in the target instance. This guide explains how to:

1. **Document** skipped cross-project links during migration
2. **Find** issues that had skipped links
3. **Restore** those links after other projects are migrated

---

## 🎯 Problem Scenario

### During Migration:

```
Issue: LAS-749 has links to:
  • CUSTIAM-834 (Relates to)
  • JIRA-123 (Blocks)
  
Migration Result:
  ✅ LAS-749 migrated to LAS1-4324
  ❌ Links to CUSTIAM-834 and JIRA-123 skipped (projects not migrated)
```

### Without Documentation:
- ❌ Link information is lost
- ❌ Users don't know what was connected
- ❌ Manual research needed to restore

### With Documentation:
- ✅ Comment added to LAS1-4324 listing skipped links
- ✅ Easy to search and find affected issues
- ✅ Links can be restored after other projects migrate

---

## 🚀 How to Use

### Step 1: Enable Documentation During Migration

Run the link migration step with the `-DocumentSkippedLinks` flag:

```powershell
cd Z:\Code\OMF\Migration
.\src\steps\11_Links.ps1 -ParametersPath "config\migration-parameters.json" -DocumentSkippedLinks
```

Or if also using remote link fallback:

```powershell
.\src\steps\11_Links.ps1 -DocumentSkippedLinks -CreateRemoteLinksForSkipped
```

### Step 2: Migration Creates Documentation Comments

For each issue with skipped cross-project links, a comment is added:

```
🔗 Migration Note: The following cross-project links could not be migrated:

• CUSTIAM-834 (Relates to)
• JIRA-123 (Blocks - inward)

These links can be restored manually once the target projects are migrated.
Search for this comment to find all issues needing link restoration: migrationLinksSkipped
```

### Step 3: Find Issues Needing Restoration

Use the search keyword to find all affected issues:

**In Jira UI:**
```
project = LAS1 AND comment ~ "migrationLinksSkipped"
```

**Using PowerShell utility:**
```powershell
cd Z:\Code\OMF\Migration\src\Utility
.\11_RestoreSkippedLinks.ps1 -ListOnly
```

Output:
```
🔍 Searching for issues with documented skipped links...
✅ Found 15 issues with documented skipped links

Issues with skipped links:
  - LAS1-4324: Implement authentication module
  - LAS1-4201: Fix payment gateway integration
  - LAS1-4156: Update customer dashboard
  ...
```

### Step 4: Restore Links After Other Projects Migrate

After migrating the other projects (CUSTIAM, JIRA, etc.), restore the links:

**Restore specific issues:**
```powershell
.\11_RestoreSkippedLinks.ps1 -IssueKeys "LAS1-4324","LAS1-4201"
```

**Restore all documented links:**
```powershell
.\11_RestoreSkippedLinks.ps1 -RestoreAll
```

Output:
```
📋 Processing 15 issues...

Processing LAS1-4324...
  Found 2 documented link(s)
    ✅ Linked to CUSTIAM1-156
    ⏭️  JIRA-123 not yet migrated

Processing LAS1-4201...
  Found 1 documented link(s)
    ✅ Linked to CUSTIAM1-89

=== RESTORATION SUMMARY ===
✅ Links restored: 12
⏭️  Links still missing: 3
📋 Comments processed: 15
```

---

## 📊 What the Documentation Comment Includes

Each comment contains:

1. **Visual indicator**: 🔗 emoji for easy recognition
2. **List of skipped links**: Issue keys with clickable URLs to source instance
3. **Link types**: Relationship type (Relates, Blocks, etc.) and direction
4. **Instructions**: How to restore and search keyword
5. **Search tag**: `migrationLinksSkipped` for easy filtering

### Example Comment Structure:

```markdown
🔗 Migration Note: The following cross-project links could not be migrated:

• [CUSTIAM-834](https://source.atlassian.net/browse/CUSTIAM-834) (Relates to)
• [JIRA-123](https://source.atlassian.net/browse/JIRA-123) (Blocks - inward)
• [XRAY-456](https://source.atlassian.net/browse/XRAY-456) (Is blocked by)

These links can be restored manually once the target projects are migrated.
Search for this comment to find all issues needing link restoration: migrationLinksSkipped
```

---

## 🔍 Finding Issues with Skipped Links

### Method 1: Jira Search (JQL)

```
project = LAS1 AND comment ~ "migrationLinksSkipped"
```

### Method 2: PowerShell Utility

```powershell
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

### Method 3: Check Migration Receipt

```powershell
$receipt = Get-Content "out\11_Links_receipt.json" | ConvertFrom-Json
$receipt.Documentation | Format-List

# Output:
# Enabled              : True
# CommentsCreated      : 15
# IssuesDocumented     : 15
# SearchKeyword        : migrationLinksSkipped
```

---

## 🔄 Restoration Workflow

### Complete Workflow:

```
1. Migrate Project A (LAS)
   ↓
2. Use -DocumentSkippedLinks flag
   ↓
3. Documentation comments created
   ↓
4. Later: Migrate Project B (CUSTIAM)
   ↓
5. Run restoration utility
   ↓
6. Links automatically restored
   ↓
7. Manually delete documentation comments (optional)
```

### Step-by-Step Commands:

```powershell
# 1. Initial migration with documentation
cd Z:\Code\OMF\Migration
.\src\steps\11_Links.ps1 -DocumentSkippedLinks

# 2. Check what was documented
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly

# 3. After other projects are migrated, restore links
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll

# 4. Verify restoration
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

---

## 📋 Command Reference

### Documentation During Migration

```powershell
# Document skipped links only
.\src\steps\11_Links.ps1 -DocumentSkippedLinks

# Document + create remote link fallbacks
.\src\steps\11_Links.ps1 -DocumentSkippedLinks -CreateRemoteLinksForSkipped
```

### Finding Documented Links

```powershell
# List all issues with documented skipped links
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

### Restoring Links

```powershell
# Restore specific issues
.\src\Utility\11_RestoreSkippedLinks.ps1 -IssueKeys "LAS1-123","LAS1-456"

# Restore all (if target issues now exist)
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll
```

---

## ⚙️ Configuration

### Parameters File

No changes needed in `config/migration-parameters.json`. The feature is controlled by command-line flags.

### Flags Explained

| Flag | Purpose | When to Use |
|------|---------|-------------|
| `-DocumentSkippedLinks` | Adds comments documenting skipped links | Always recommended for cross-project migrations |
| `-CreateRemoteLinksForSkipped` | Creates remote links to source instance | Use if you want clickable links to source |

---

## 💡 Best Practices

### 1. **Always Document for Multi-Project Migrations**

If you're migrating multiple projects, always use `-DocumentSkippedLinks`:

```powershell
.\src\steps\11_Links.ps1 -DocumentSkippedLinks
```

### 2. **Restore in Dependency Order**

Migrate and restore in logical order:
1. Migrate core/parent projects first
2. Document their skipped links
3. Migrate dependent projects
4. Restore links back to core projects

### 3. **Search Before Each Restoration**

Always check what's available before restoring:

```powershell
# Check current state
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly

# Restore what's possible
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll

# Check what's still missing
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

### 4. **Keep Documentation Comments**

Don't delete the comments until:
- All linked projects are migrated
- All links are restored
- Restoration is verified

### 5. **Track in Receipt File**

Check the migration receipt for statistics:

```powershell
$receipt = Get-Content "out\11_Links_receipt.json" | ConvertFrom-Json
Write-Host "Documented: $($receipt.Documentation.CommentsCreated) comments"
Write-Host "Search for: $($receipt.Documentation.SearchKeyword)"
```

---

## 🎯 Real-World Example

### Scenario: Migrating LAS Project

**Step 1: Initial Migration**
```powershell
# LAS project has links to CUSTIAM, JIRA, XRAY
.\src\steps\11_Links.ps1 -DocumentSkippedLinks
```

**Result:**
```
=== MIGRATION SUMMARY ===
✅ Links migrated: 1,234
⏭️  Links skipped: 89
📝 Documentation comments created: 45

📝 Skipped cross-project links have been documented in comments
   Search for: migrationLinksSkipped
```

**Step 2: Check Documentation**
```powershell
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

**Output:**
```
✅ Found 45 issues with documented skipped links

Issues with skipped links:
  - LAS1-4324: Implement auth (links to: CUSTIAM-834, JIRA-123)
  - LAS1-4201: Payment gateway (links to: XRAY-456)
  - LAS1-4156: Customer dashboard (links to: CUSTIAM-901)
  ...
```

**Step 3: Migrate CUSTIAM Project**
```powershell
# ... migrate CUSTIAM project ...
# CUSTIAM-834 becomes CUSTIAM1-156
# CUSTIAM-901 becomes CUSTIAM1-789
```

**Step 4: Restore Links**
```powershell
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll
```

**Result:**
```
=== RESTORATION SUMMARY ===
✅ Links restored: 38
⏭️  Links still missing: 51 (JIRA and XRAY not yet migrated)
```

**Step 5: Check What's Left**
```powershell
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

**Output:**
```
✅ Found 30 issues with documented skipped links
(Down from 45 - some have all links restored!)
```

---

## 🔧 Troubleshooting

### Issue: Comments Not Found

**Problem:**
```
✅ No issues found with documented skipped links
```

**Solutions:**
1. Check if `-DocumentSkippedLinks` was used during migration
2. Verify project key is correct
3. Check if comments were manually deleted

### Issue: Links Not Restoring

**Problem:**
```
⏭️  CUSTIAM-123 not yet migrated
```

**Solutions:**
1. Verify target issue exists: Check in Jira UI
2. Check project key: Ensure CUSTIAM project is migrated
3. Check permissions: Verify API token has link creation rights

### Issue: Link Type Not Preserved

**Note:** The restoration utility uses "Relates" as the default link type because the original relationship type may not be stored in the comment format.

**Solutions:**
1. Manually update link types in Jira UI after restoration
2. Check migration receipt for link type statistics
3. Use remote links feature if relationship type is critical

---

## 📚 Related Documentation

- **Link Migration**: `Migration/src/steps/11_Links.ps1`
- **Restoration Utility**: `Migration/src/Utility/11_RestoreSkippedLinks.ps1`
- **Migration Receipt**: `Migration/out/11_Links_receipt.json`
- **SSL Troubleshooting**: `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md`

---

## 📊 Statistics and Reporting

### Check Documentation Statistics

```powershell
$receipt = Get-Content "out\11_Links_receipt.json" | ConvertFrom-Json

# Documentation info
$receipt.Documentation | Format-List

# Link statistics
Write-Host "Total Skipped: $($receipt.IssueLinks.Skipped)"
Write-Host "Documented: $($receipt.Documentation.CommentsCreated)"
Write-Host "Issues with docs: $($receipt.Documentation.IssuesDocumented)"
```

### Export List of Issues for Planning

```powershell
# Get all issues with docs
$jql = "project = LAS1 AND comment ~ migrationLinksSkipped"
# Run in Jira and export to CSV for project planning
```

---

## ✨ Summary

### Benefits of Documentation Feature:

✅ **Preserves Information** - Never lose track of cross-project dependencies  
✅ **Easy Discovery** - Simple JQL search finds all affected issues  
✅ **Automated Restoration** - One command restores all possible links  
✅ **Audit Trail** - Comments provide history of migration  
✅ **Planning Tool** - Know what projects need to be migrated next  
✅ **User-Friendly** - Clickable links to source issues  

### Key Commands:

```powershell
# Document during migration
.\src\steps\11_Links.ps1 -DocumentSkippedLinks

# List documented issues
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly

# Restore all links
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll
```

### Search Keyword:

```
migrationLinksSkipped
```

Use this in Jira search to find all issues needing link restoration!

---

**Questions?** Check the migration receipt or review the source code for implementation details.

