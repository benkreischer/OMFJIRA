# Historical Data Preservation - Implementation Summary

**Date:** October 12, 2025
**Feature:** Complete historical timeline preservation for migrated issues

---

## ✅ Problem Solved

### The Issue
When migrating Jira issues, the standard API sets the **created** and **updated** dates to the migration date, not the original dates. This causes:
- Loss of historical timeline
- Inaccurate age-based reporting
- Missing context about issue evolution
- Compliance/audit issues

### The Solution
We now **preserve complete historical information** including:
- ✅ Original created date
- ✅ Original updated date
- ✅ Original creator name
- ✅ All stored in custom fields + description

This matches how we already preserve history in:
- **Step 09 (Comments)** - Author attribution with timestamps
- **Step 10 (Attachments)** - Original upload dates
- **Step 11 (Links)** - Relationship timestamps
- **Step 12 (Worklogs)** - Work log timestamps and authors

---

## 🔧 What Changed

### 1. Configuration Files

**File:** `config/migration-parameters.json`

Added two new custom field mappings:

```json
"CustomFields": {
  "LegacyKeyURL": "customfield_11950",
  "LegacyKey": "customfield_11951",
  "OriginalCreatedDate": "customfield_11952",  // ← NEW
  "OriginalUpdatedDate": "customfield_11953"   // ← NEW
}
```

### 2. Issue Creation Script

**File:** `src/steps/08_CreateIssues_Target.ps1`

**Changes:**
- Loads new custom field IDs from parameters
- Sets `OriginalCreatedDate` = source issue's created date
- Sets `OriginalUpdatedDate` = source issue's updated date
- Appends historical info to description as backup
- Includes original creator name in description
- Updated header documentation

**Code Added:**
```powershell
# Load timestamp field IDs
$originalCreatedDateField = $p.CustomFields.OriginalCreatedDate
$originalUpdatedDateField = $p.CustomFields.OriginalUpdatedDate

# Set in issue payload
if ($originalCreatedDateField) {
    $issuePayload.fields.$originalCreatedDateField = $sourceIssue.fields.created
}
if ($originalUpdatedDateField) {
    $issuePayload.fields.$originalUpdatedDateField = $sourceIssue.fields.updated
}

# Add to description for visibility
$customFieldValues += "**Original Created:** $($sourceIssue.fields.created)"
$customFieldValues += "**Original Updated:** $($sourceIssue.fields.updated)"
$customFieldValues += "**Original Creator:** $($sourceIssue.fields.creator.displayName)"
```

### 3. Project Creation Script

**File:** `CreateNewProject.ps1`

**Changes:**
- Auto-generates new custom field entries in `parameters.json`
- Default IDs provided (user should update with actual IDs)
- Documentation updated to mention timestamp fields

### 4. Documentation

**New File:** `docs/HISTORICAL_TIMESTAMPS_SETUP.md`
- Complete setup guide
- Field creation instructions
- Configuration examples
- Troubleshooting tips
- Before/after examples

**Updated:** `README.md`
- Added mention of historical preservation
- Updated feature list

---

## 📋 Required Setup Steps

### For Users

1. **Create Custom Fields in Target Jira:**
   - Field 1: "Original Created Date" (DateTime Picker)
   - Field 2: "Original Updated Date" (DateTime Picker)

2. **Note Field IDs:**
   - Find the `customfield_XXXXX` IDs for each field

3. **Update Configuration:**
   - Edit `projects/[PROJECT]/parameters.json`
   - Set correct field IDs in `CustomFields` section

4. **Run Migration:**
   - Script automatically preserves timestamps
   - History appears in both custom fields AND description

### For New Projects

Using `CreateNewProject.ps1` now auto-generates configuration with placeholder IDs:

```powershell
.\CreateNewProject.ps1 -ProjectKey ABC
```

Then just:
1. Create the custom fields in target
2. Update the IDs in generated `parameters.json`
3. Run migration

---

## 🎯 What Gets Preserved

### During Issue Creation (Step 08)

**Custom Fields:**
- `OriginalCreatedDate` = Source issue's `created` date
- `OriginalUpdatedDate` = Source issue's `updated` date

**Description Appended:**
```
---
**Original Created:** 2023-06-15T10:30:00.000+0000
**Original Updated:** 2024-01-20T14:45:00.000+0000
**Original Creator:** John Smith
```

**Console Output:**
```
Creating issue: ABC-123
  Setting legacy key: ABC-123
  Preserving original created date: 2023-06-15T10:30:00.000+0000
  Preserving original updated date: 2024-01-20T14:45:00.000+0000
  ✅ Created: DEF-456
```

### Complete Historical Chain

| Step | What's Preserved | How |
|------|------------------|-----|
| **08 - Issues** | Created/Updated dates, Creator | Custom fields + Description |
| **09 - Comments** | Comment timestamps, Authors | "On behalf of" notation |
| **10 - Attachments** | Upload timestamps, Uploaders | File metadata |
| **11 - Links** | Link creation dates | Link properties |
| **12 - Worklogs** | Work log timestamps, Authors | Time tracking data |

**Result:** Complete, accurate historical timeline! ✅

---

## 💡 Benefits

### Compliance & Audit
- ✅ Complete audit trail maintained
- ✅ Can prove when issues were originally created
- ✅ Historical accuracy for compliance reporting

### Reporting & Analytics
- ✅ Accurate age-based reports (use `OriginalCreatedDate`)
- ✅ Correct historical trending
- ✅ Proper lifecycle analysis
- ✅ Meaningful KPIs and metrics

### Team Productivity
- ✅ Context preserved for team members
- ✅ Can see issue evolution over time
- ✅ Better understanding of historical patterns

### Data Quality
- ✅ No information loss during migration
- ✅ Reversible - can trace back to source
- ✅ Backup in description if custom fields unavailable

---

## 🔍 Example Use Cases

### JQL Queries

```jql
# Find issues originally created last year
"Original Created Date" >= 2024-01-01 AND "Original Created Date" <= 2024-12-31

# Find old issues recently migrated
created > startOfMonth() AND "Original Created Date" < startOfYear(-1)

# Find stale issues (not updated in 6 months in source)
"Original Updated Date" < startOfMonth(-6)
```

### Reporting

**Age Report:**
```
Use "Original Created Date" instead of "Created" field
Shows true age of issues, not migration date
```

**Timeline Analysis:**
```
Plot issue creation over time using Original Created Date
See actual historical patterns, not migration spike
```

**Velocity Tracking:**
```
Reference original dates for historical velocity
Calculate actual resolution times
```

---

## 🎨 Visual Example

### Before (Without Timestamp Preservation)

```
╔════════════════════════════════════════════════╗
║ Issue: DEF-456 (migrated from ABC-123)        ║
╠════════════════════════════════════════════════╣
║ Created: 2025-01-15  ← MIGRATION DATE         ║
║ Updated: 2025-01-15  ← MIGRATION DATE         ║
║ Creator: Migration User                        ║
╚════════════════════════════════════════════════╝

❌ Looks brand new!
❌ Can't see it's 2 years old
❌ All issues look same age
❌ Reports are useless
```

### After (With Timestamp Preservation)

```
╔════════════════════════════════════════════════╗
║ Issue: DEF-456 (migrated from ABC-123)        ║
╠════════════════════════════════════════════════╣
║ Created: 2025-01-15 (migration date)          ║
║ Updated: 2025-01-15 (migration date)          ║
║ Creator: Migration User                        ║
║                                                ║
║ Original Created: 2023-01-10 ✅               ║
║ Original Updated: 2024-12-20 ✅               ║
║                                                ║
║ Description includes:                          ║
║ ---                                            ║
║ **Original Created:** 2023-01-10T09:30:00     ║
║ **Original Updated:** 2024-12-20T16:45:00     ║
║ **Original Creator:** Jane Doe                ║
╚════════════════════════════════════════════════╝

✅ Complete historical context!
✅ Can see real age (2 years old)
✅ Know original creator
✅ Accurate for reporting
```

---

## 🚀 Migration Flow

```
Source Issue (ABC-123)
├─ created: 2023-01-10
├─ updated: 2024-12-20
└─ creator: Jane Doe
     │
     ▼
  MIGRATION (Step 08)
     │
     ├─ Creates target issue (DEF-456)
     │  └─ created: 2025-01-15 (system sets this)
     │
     ├─ Sets custom fields:
     │  ├─ OriginalCreatedDate: 2023-01-10 ✅
     │  └─ OriginalUpdatedDate: 2024-12-20 ✅
     │
     └─ Appends to description:
        └─ "**Original Created:** 2023-01-10..."  ✅
     │
     ▼
Target Issue (DEF-456)
├─ created: 2025-01-15 (new)
├─ OriginalCreatedDate: 2023-01-10 (preserved) ✅
├─ OriginalUpdatedDate: 2024-12-20 (preserved) ✅
└─ Description includes historical info ✅
```

---

## 📚 Related Documentation

- **[Historical Timestamps Setup Guide](HISTORICAL_TIMESTAMPS_SETUP.md)** - Detailed setup instructions
- **[Legacy Key Preservation](LEGACY_KEY_PRESERVATION.md)** - Source key tracking
- **[Configuration Options](CONFIGURATION_OPTIONS.md)** - All configuration settings
- **[Quick Reference](QUICK_REFERENCE.md)** - Common commands

---

## ✨ Summary

**What:** Preserve original created/updated timestamps from source issues

**Why:** Maintain accurate historical timeline and enable proper reporting

**How:** Custom DateTime fields + description backup

**Impact:** Complete historical preservation, matching Steps 09-12

**Status:** ✅ **IMPLEMENTED & DOCUMENTED**

---

**The migration toolkit now preserves COMPLETE historical data across all steps!** 🎉

---

**Last Updated:** October 12, 2025
**Version:** 1.0
**Feature Status:** Production Ready

