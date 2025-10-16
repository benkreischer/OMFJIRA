# Historical Timestamps Setup Guide

## Overview

The migration toolkit now **preserves original created and updated timestamps** from source issues, ensuring complete historical accuracy in the target project. This is similar to how we preserve comment authors in Step 09 and worklog attribution in Step 12.

---

## Why This Matters

When migrating issues, Jira sets the **created date** to the migration date, not the original date. This means:
- ❌ Historical timelines are lost
- ❌ Age-based reports are inaccurate  
- ❌ You can't see when issues were originally created
- ❌ Sorting by created date shows everything as "created today"

With historical timestamp preservation:
- ✅ Original creation dates are preserved
- ✅ Original update dates are preserved
- ✅ Original creator information is captured
- ✅ Accurate historical reporting
- ✅ Complete audit trail maintained

---

## Required Custom Fields in Target

You need to create **two DateTime custom fields** in your target Jira project:

### 1. Original Created Date

**Field Type:** Date Time Picker
**Field Name:** `Original Created Date`
**Description:** `Original creation date from source Jira instance`
**Screen:** Add to View screen (optional - for visibility)

### 2. Original Updated Date

**Field Type:** Date Time Picker
**Field Name:** `Original Updated Date`
**Description:** `Original last updated date from source Jira instance`
**Screen:** Add to View screen (optional - for visibility)

---

## Setup Instructions

### Step 1: Create Custom Fields in Target Jira

1. **Navigate to Custom Fields**
   - Go to: ⚙️ Settings → Issues → Custom fields
   - Or direct link: `https://[your-site].atlassian.net/secure/admin/ViewCustomFields.jspa`

2. **Create "Original Created Date" Field**
   - Click **Create custom field**
   - Select field type: **Date Time Picker**
   - Name: `Original Created Date`
   - Description: `Original creation date from source Jira instance`
   - Click **Create**

3. **Associate with Screens**
   - Select screens to add this field to (recommended: Default Screen)
   - Click **Update**

4. **Note the Field ID**
   - After creation, find the field in the custom fields list
   - Click **"..."** → **View screens**
   - Look at the URL: `customfield_XXXXX` (e.g., `customfield_11952`)
   - **Copy this field ID** - you'll need it for configuration

5. **Repeat for "Original Updated Date"**
   - Follow same steps
   - Name: `Original Updated Date`
   - Description: `Original last updated date from source Jira instance`
   - **Copy this field ID** as well (e.g., `customfield_11953`)

---

### Step 2: Update Migration Parameters

Edit your project's `parameters.json` file:

```json
{
  "CustomFields": {
    "LegacyKeyURL": "customfield_11950",
    "LegacyKey": "customfield_11951",
    "OriginalCreatedDate": "customfield_11952",  // ← Add this
    "OriginalUpdatedDate": "customfield_11953"   // ← Add this
  }
}
```

**Replace the IDs** with the actual field IDs you noted in Step 1.

---

### Step 3: Run Migration

The migration will now automatically:

1. **Set Custom Fields:**
   - Original Created Date = source issue's created date
   - Original Updated Date = source issue's updated date

2. **Add to Description:**
   - Appends historical info at bottom of description:
     ```
     ---
     **Original Created:** 2023-06-15T10:30:00.000+0000
     **Original Updated:** 2024-01-20T14:45:00.000+0000
     **Original Creator:** John Smith
     ```

3. **Preserve in Receipts:**
   - Issue creation receipts include original timestamps for audit

---

## What Gets Preserved

### Issue Creation (Step 08)
- ✅ Original created date → `OriginalCreatedDate` custom field
- ✅ Original updated date → `OriginalUpdatedDate` custom field
- ✅ Original creator name → Appended to description
- ✅ All dates also appended to description as backup

### Comments (Step 09)
- ✅ Original comment timestamps preserved
- ✅ Comment author attribution maintained
- ✅ "On behalf of" notation for unmapped users

### Worklogs (Step 12)
- ✅ Original worklog timestamps preserved
- ✅ Worklog author attribution maintained
- ✅ Time tracking accuracy preserved

### Attachments (Step 10)
- ✅ Original upload timestamps preserved
- ✅ File metadata maintained

---

## Viewing Historical Data

### In Jira UI

1. **Issue View:**
   - Custom fields show in right sidebar or details section
   - Shows exact original created/updated dates

2. **List View:**
   - Add `Original Created Date` column to issue lists
   - Sort by original creation date for historical accuracy

3. **JQL Queries:**
   ```jql
   # Issues originally created before a specific date
   "Original Created Date" < 2023-01-01
   
   # Issues with large time gap between original creation and migration
   created > startOfMonth() AND "Original Created Date" < startOfYear(-1)
   ```

### In Reports

- **Age reports:** Use `Original Created Date` instead of `Created`
- **Timeline reports:** Reference custom fields for accurate historical view
- **Burndown charts:** Can reference original dates for historical analysis

---

## Troubleshooting

### Issue: Custom field IDs are wrong

**Symptoms:** Errors during Step 08 about invalid fields

**Solution:**
1. Go to: ⚙️ Settings → Issues → Custom fields
2. Find your "Original Created Date" field
3. Click **"..."** → **View screens**
4. Check URL for `customfield_XXXXX`
5. Update `parameters.json` with correct ID

### Issue: Fields not showing on issues

**Symptoms:** Issues created but custom fields empty

**Solutions:**
1. **Check field association:** Make sure fields are associated with your project's screens
2. **Check permissions:** Ensure fields are visible to your user role
3. **Re-run Step 08:** Script is idempotent - it will skip existing issues

### Issue: Don't see custom fields option

**Symptoms:** Can't create DateTime fields

**Requirements:**
- You need **Jira Administrator** permissions
- Custom fields require certain Jira plans (Standard or higher)
- If using Jira Free, custom fields may be limited

---

## Optional: Field Configuration

### Make Fields Read-Only

To prevent accidental editing:

1. Go to field configuration
2. Find the fields in your field configuration scheme
3. Make them **Read-Only** or remove from edit screens

### Create Custom Tab

For better organization:

1. Go to screen configuration
2. Create a new tab called "Migration Info"
3. Add all migration-related fields:
   - Legacy Key
   - Legacy Key URL
   - Original Created Date
   - Original Updated Date

---

## Benefits of Historical Preservation

### Compliance & Audit
- ✅ Complete audit trail maintained
- ✅ Historical accuracy for compliance reporting
- ✅ Can prove when issues were originally created

### Reporting & Analytics
- ✅ Accurate age-based reports
- ✅ Correct historical trending
- ✅ Proper lifecycle analysis

### Team Productivity
- ✅ Context preserved for team members
- ✅ Historical patterns visible
- ✅ Better understanding of issue evolution

### Business Intelligence
- ✅ Accurate KPIs and metrics
- ✅ Historical comparison capabilities
- ✅ Long-term trend analysis

---

## Example: Before & After

### Before (No Timestamp Preservation)

```
Issue: ABC-123 → ABC-456
Created: 2025-01-15 (migration date)
Updated: 2025-01-15 (migration date)

❌ Looks like a brand new issue!
❌ Can't tell it's 2 years old
❌ Historical reports are meaningless
```

### After (With Timestamp Preservation)

```
Issue: ABC-123 → ABC-456
Created: 2025-01-15 (migration date)
Updated: 2025-01-15 (migration date)
Original Created: 2023-01-10 ✅
Original Updated: 2024-12-20 ✅

Description includes:
---
**Original Created:** 2023-01-10T09:30:00.000+0000
**Original Updated:** 2024-12-20T16:45:00.000+0000
**Original Creator:** Jane Doe

✅ Complete historical context!
✅ Can see real age
✅ Accurate reporting possible
```

---

## Summary

**Historical timestamp preservation is critical for:**
- Maintaining accurate project timelines
- Generating meaningful reports
- Compliance and audit requirements
- Team understanding and context

**Setup is simple:**
1. Create two DateTime custom fields in target
2. Note their field IDs
3. Update `parameters.json`
4. Run migration

**The migration toolkit handles the rest automatically!**

---

**Related Documentation:**
- [Legacy Key Preservation](LEGACY_KEY_PRESERVATION.md) - Source key tracking
- [Configuration Options](CONFIGURATION_OPTIONS.md) - All configuration settings
- [Quick Reference](QUICK_REFERENCE.md) - Common commands

---

**Last Updated:** October 12, 2025
**Version:** 1.0

