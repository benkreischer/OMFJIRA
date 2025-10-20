# Legacy Key Preservation - Implementation Summary

## ✅ Enhancement Complete

**Date:** 2025-10-09
**Script:** `08_Import.ps1`

---

## 🎯 What Was Done

Enhanced the issue creation script to **write source issue keys and URLs to dedicated legacy custom fields** in the target project.

---

## 📋 Target Custom Fields (Verified)

| Field ID | Field Name | Type | Purpose |
|----------|------------|------|---------|
| `customfield_11951` | `LegacyKey` | String | Stores source issue key (e.g., "SRC-123") |
| `customfield_11950` | `LegacyKeyURL` | String | Stores clickable URL to source issue |

**Note:** These fields exist **only in the target project** (DEP1), not in the source.

---

## 🔧 Implementation Details

### Code Changes

**Location:** Line 469-475 in `08_Import.ps1`

```powershell
# ========== PRESERVE LEGACY KEY INFORMATION ==========
# Write source key and URL to target's legacy key custom fields
# These fields only exist in target, not source
$issuePayload.fields.customfield_11951 = $sourceIssue.key  # LegacyKey
$issuePayload.fields.customfield_11950 = "$($srcBase.TrimEnd('/'))/browse/$($sourceIssue.key)"  # LegacyKeyURL

Write-Host "    Setting legacy key: $($sourceIssue.key)"
```

### What Gets Written

For each migrated issue:

| Source Issue | Field | Value Written |
|--------------|-------|---------------|
| `SRC-123` | `LegacyKey` | `SRC-123` |
| `SRC-123` | `LegacyKeyURL` | `https://source.atlassian.net/browse/SRC-123` |

---

## 📊 Benefits

### Before Enhancement:
- ❌ Legacy key only in description (text)
- ❌ Not searchable via JQL
- ❌ No direct link to source
- ❌ Manual lookup required

### After Enhancement:
- ✅ **Searchable:** `LegacyKey = "SRC-123"`
- ✅ **Filterable:** JQL queries work
- ✅ **Clickable:** Direct link to source
- ✅ **Reportable:** Build dashboards by legacy key
- ✅ **Automatable:** Trigger workflows based on legacy key
- ✅ **Professional:** Industry standard practice

---

## 🔍 How To Use

### Search By Legacy Key (JQL)
```jql
LegacyKey = "SRC-123"
LegacyKey in ("SRC-100", "SRC-101", "SRC-102")
LegacyKey ~ "SRC-*"
project = DEP1 AND LegacyKey is not EMPTY
```

### Create Reports
- Group by LegacyKey
- Filter by source project
- Track migration coverage

### Access Source Issue
- Click the `LegacyKeyURL` field
- Opens original issue in source instance
- Perfect for comparison/reference

---

## 🎨 Example Migrated Issue

```
Target Issue: DEP1-456
├── Summary: "Deploy firewall in AWS"
├── Description: [original content]
├── LegacyKey: "SRC-123"  ← Searchable!
├── LegacyKeyURL: "https://source.atlassian.net/browse/SRC-123"  ← Clickable!
└── ... other fields
```

---

## 🚀 Console Output

When creating issues, you'll now see:

```
Creating issue: SRC-123 [Epic] Deploy firewall...
    Mapped issue type: Epic → Epic
    Setting legacy key: SRC-123
    ✅ Created: DEP1-456
```

---

## 📝 Additional Changes

### 1. Updated Custom Field Names
**Changed from:**
- `"Legacy Key"` (with space)
- `"Legacy Key URL"` (with spaces)

**To:**
- `"LegacyKey"` (no space) ✅
- `"LegacyKeyURL"` (no spaces) ✅

These match the **actual field names in target project**.

### 2. Excluded from Description
Legacy key fields are **no longer duplicated** in the description text since they're now proper custom fields.

### 3. Documentation Updated
- Added to script header
- Noted idempotency feature
- Documented field IDs and names

---

## ✅ Verification Checklist

After running the migration:

- [ ] Search for an issue: `LegacyKey = "SRC-123"`
- [ ] Verify the legacy key field is populated
- [ ] Click the LegacyKeyURL link
- [ ] Confirm it opens the source issue
- [ ] Create a filter using legacy key
- [ ] Build a report/dashboard

---

## 🎯 Use Cases

### 1. Auditing
```jql
project = DEP1 AND LegacyKey is EMPTY
```
Find any issues that weren't properly migrated.

### 2. Cross-Reference
When users report issues about "the old SRC-456":
```jql
LegacyKey = "SRC-456"
```
Instantly find the new issue.

### 3. Bulk Operations
```jql
LegacyKey in (SRC-100, SRC-101, SRC-102)
```
Update multiple related issues.

### 4. Reporting
- Group by source project (extract from LegacyKey)
- Track migration coverage
- Analyze by original structure

### 5. Automation
Trigger workflows when:
- LegacyKey matches pattern
- Legacy URL accessed
- Reference to source needed

---

## 🔐 Migration Traceability

Every issue now has **perfect traceability** back to its source:

```
Migration Flow:
SRC-123 (source) 
    ↓
    Migrated by script
    ↓
DEP1-456 (target)
    ├── LegacyKey: "SRC-123"  ← Traceability!
    └── LegacyKeyURL: "https://..." ← Reference!
```

---

## 📚 Best Practices

### Do:
- ✅ Use JQL to search legacy keys
- ✅ Create bookmarks with legacy key filters
- ✅ Add legacy key column to issue navigator
- ✅ Use in automation rules
- ✅ Reference in documentation

### Don't:
- ❌ Manually edit legacy key fields (managed by migration)
- ❌ Delete these custom fields
- ❌ Change field names after migration

---

## 🎉 Result

**Your migration now includes professional-grade legacy key preservation!**

Every migrated issue is:
- ✅ Fully traceable to its source
- ✅ Searchable by original key
- ✅ Linked to source instance
- ✅ Ready for production use
- ✅ Audit-compliant

**This is a standard best practice for enterprise Jira migrations!** 🌟

