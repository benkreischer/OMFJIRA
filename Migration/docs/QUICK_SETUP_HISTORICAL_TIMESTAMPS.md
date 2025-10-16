# Quick Setup: Historical Timestamps

**⚠️ IMPORTANT:** Set this up BEFORE running Step 08 (CreateIssues)

---

## Why You Need This

Without these fields, all migrated issues will show:
- ❌ Created date = Migration date (not original date)
- ❌ Updated date = Migration date (not original date)
- ❌ Can't sort by original creation date
- ❌ Age-based reports are useless

With these fields, you preserve:
- ✅ Original creation dates
- ✅ Original update dates  
- ✅ Complete historical timeline
- ✅ Accurate reporting

---

## 3-Step Setup (5 minutes)

### Step 1: Create Two Custom Fields in Target Jira

1. Go to: ⚙️ Settings → Issues → Custom fields
2. Click "Create custom field"
3. Select: **Date Time Picker**
4. Name: `Original Created Date`
5. Description: `Original creation date from source`
6. Click Create → Associate with screens

Repeat for:
7. Name: `Original Updated Date`
8. Description: `Original last updated date from source`

### Step 2: Get Field IDs

1. In Custom Fields list, find "Original Created Date"
2. Click **"..."** → **View screens**
3. Look at URL: `customfield_XXXXX` (e.g., `customfield_10401`)
4. **Copy this ID**

Repeat for "Original Updated Date" (e.g., `customfield_10402`)

### Step 3: Update Configuration

Edit: `projects/[YOUR_PROJECT]/parameters.json`

Find the `CustomFields` section and update:

```json
"CustomFields": {
  "LegacyKeyURL": "customfield_10400",
  "LegacyKey": "customfield_10399",
  "OriginalCreatedDate": "customfield_10401",    // ← YOUR ID HERE
  "OriginalUpdatedDate": "customfield_10402"     // ← YOUR ID HERE
}
```

**Replace with your actual field IDs from Step 2!**

---

## ✅ That's It!

Now run your migration:

```powershell
.\RunMigration.ps1 -Project [YOUR_PROJECT] -AutoRun
```

Step 08 will automatically:
- Set `OriginalCreatedDate` for every issue
- Set `OriginalUpdatedDate` for every issue
- Append historical info to description
- Log the preservation in console output

---

## Verification

After Step 08 completes, check a migrated issue:

1. Open any migrated issue in target
2. Look for custom fields:
   - **Original Created Date:** 2023-06-15 10:30 ✅
   - **Original Updated Date:** 2024-12-20 14:45 ✅
3. Scroll to bottom of description:
   ```
   ---
   **Original Created:** 2023-06-15T10:30:00.000+0000
   **Original Updated:** 2024-12-20T14:45:00.000+0000
   **Original Creator:** Jane Doe
   ```

---

## Common Mistakes

### ❌ Wrong Field Type
**Problem:** Using "Date Picker" instead of "Date Time Picker"
**Fix:** Delete and recreate as "Date Time Picker"

### ❌ Wrong Field IDs
**Problem:** Copy-pasted example IDs instead of actual IDs
**Fix:** Check custom fields list, get real IDs, update config

### ❌ Fields Not in Project
**Problem:** Created fields globally but didn't associate with project
**Fix:** Go to field configuration, add to project screens

---

## Need Help?

**Full Guide:** [Historical Timestamps Setup Guide](HISTORICAL_TIMESTAMPS_SETUP.md)

**Questions:**
- "How do I find field IDs?" → See Step 2 above
- "Can I skip this?" → Yes, but you'll lose historical timeline
- "Can I add this later?" → Hard to backfill; do it before Step 08

---

**Last Updated:** October 12, 2025

