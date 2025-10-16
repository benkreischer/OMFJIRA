# Cross-Project Links - Quick Start Guide

## 🎯 Problem

When migrating issues that link to other projects (CUSTIAM, JIRA, XRAY, etc.), those links can't be migrated because the target issues don't exist yet.

**Example:**
```
LAS-749 → links to → CUSTIAM-834
         ❌ CUSTIAM not migrated yet
         ❌ Link is lost
```

## ✅ Solution

Document the skipped links during migration, then restore them later!

---

## 🚀 Quick Start (3 Steps)

### Step 1: Enable Documentation During Migration

```powershell
cd Z:\Code\OMF\Migration
.\src\steps\11_Links.ps1 -DocumentSkippedLinks
```

**What happens:**
- Migration runs normally
- Skipped cross-project links are documented in comments
- Each affected issue gets a comment listing the missing links

**Example comment added to LAS1-4324:**
```
🔗 Migration Note: The following cross-project links could not be migrated:

• CUSTIAM-834 (Relates to)
• JIRA-123 (Blocks)

These links can be restored once target projects are migrated.
Search keyword: migrationLinksSkipped
```

### Step 2: Find Issues with Skipped Links

```powershell
cd src\Utility
.\11_RestoreSkippedLinks.ps1 -ListOnly
```

**Output:**
```
✅ Found 15 issues with documented skipped links

Issues with skipped links:
  - LAS1-4324: Implement authentication
  - LAS1-4201: Payment gateway fix
  - LAS1-4156: Customer dashboard
```

### Step 3: Restore Links (After Other Projects Migrate)

```powershell
# Restore all documented links
.\11_RestoreSkippedLinks.ps1 -RestoreAll

# Or restore specific issues
.\11_RestoreSkippedLinks.ps1 -IssueKeys "LAS1-4324","LAS1-4201"
```

**Output:**
```
✅ Links restored: 12
⏭️  Links still missing: 3
```

---

## 📋 Command Reference

| Command | Purpose |
|---------|---------|
| `.\src\steps\11_Links.ps1 -DocumentSkippedLinks` | Enable documentation during migration |
| `.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly` | List all issues with skipped links |
| `.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll` | Restore all possible links |
| `.\src\Utility\11_RestoreSkippedLinks.ps1 -IssueKeys "XX"` | Restore specific issues |

---

## 🔍 Search in Jira

Find all issues needing link restoration:

```
project = LAS1 AND comment ~ "migrationLinksSkipped"
```

---

## 📊 Check Status

View migration statistics:

```powershell
$receipt = Get-Content "out\11_Links_receipt.json" | ConvertFrom-Json
$receipt.Documentation | Format-List
```

Output:
```
Enabled          : True
CommentsCreated  : 15
IssuesDocumented : 15
SearchKeyword    : migrationLinksSkipped
```

---

## 🎯 Real-World Workflow

```
Day 1: Migrate LAS Project
  ↓
  Use -DocumentSkippedLinks
  ↓
  45 comments created documenting skipped links
  
Day 30: Migrate CUSTIAM Project
  ↓
  Run restoration utility
  ↓
  38 links automatically restored!
  
Day 60: Migrate JIRA Project
  ↓
  Run restoration utility again
  ↓
  All remaining links restored!
```

---

## 💡 Benefits

✅ **Never lose link information**  
✅ **Easy to search and find** (`migrationLinksSkipped`)  
✅ **Automated restoration** (one command)  
✅ **Clickable links** to source issues  
✅ **Audit trail** for compliance  

---

## ⚠️ Important Notes

1. **Enable before migration** - Can't add documentation retroactively
2. **Search keyword** - `migrationLinksSkipped` finds all affected issues
3. **Link type** - Restored links use "Relates" by default
4. **Keep comments** - Don't delete until all links restored
5. **Run multiple times** - As more projects get migrated

---

## 📚 Full Documentation

For complete details, see: `Migration/docs/CROSS_PROJECT_LINKS_GUIDE.md`

---

## 🆘 Quick Help

```powershell
# Where am I?
cd Z:\Code\OMF\Migration

# What issues need restoration?
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly

# Restore everything possible now
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll

# Check results
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly
```

---

## ✨ One-Liner Summary

**Document during migration** → **Search to find** → **Restore after other projects migrate**

```powershell
# 1. Document
.\src\steps\11_Links.ps1 -DocumentSkippedLinks

# 2. Find
.\src\Utility\11_RestoreSkippedLinks.ps1 -ListOnly

# 3. Restore
.\src\Utility\11_RestoreSkippedLinks.ps1 -RestoreAll
```

---

**Done!** Your cross-project links are preserved and can be restored later. 🎉

