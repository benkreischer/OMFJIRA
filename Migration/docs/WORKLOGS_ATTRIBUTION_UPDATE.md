# Worklogs Attribution Update

## ✅ Changes Implemented

Updated the worklog migration script to preserve original author information by adding attribution to worklog comments, just like we did for issue comments.

---

## 🎯 Problem

**Jira API Limitation:** The Jira REST API doesn't allow setting the worklog author during creation. Worklogs are always created by the authenticated API user.

**Before Update:**
```
Worklog: 2 hours
Created by: api-user@company.com  ❌ Wrong person!
Comment: "Fixed authentication bug"
```

**After Update:**
```
Worklog: 2 hours
Created by: api-user@company.com (API limitation)
Comment: "Originally logged by John Doe on March 15, 2024 at 2:30 PM

Fixed authentication bug"
```

---

## 📝 What Was Changed

### File: `Migration/src/steps/12_Worklogs.ps1`

### 1. **Added Author Attribution to Comments**

Every worklog now gets attribution text prepended to its comment:

```
Originally logged by [Author Name] on [Friendly Date]
```

**Format Examples:**
- "Originally logged by John Doe on March 15, 2024 at 2:30 PM"
- "Originally logged by Jane Smith on January 5, 2024 at 9:15 AM"
- "Originally logged by Bob Johnson on December 31, 2024 at 4:45 PM"

### 2. **Updated Idempotency Check**

Changed from checking time/date to checking for attribution text:

**Before:**
```powershell
# Checked if same time spent and date existed
$worklogExists = $existingWorklogs | Where-Object {
    $_.timeSpent -eq $worklog.timeSpent -and
    $existingStarted.Date -eq $worklogStarted.Date
}
```

**After:**
```powershell
# Check if attribution text exists in comment
$attributionText = "Originally logged by $originalAuthor on $originalDate"
# Searches for this text in existing worklogs
```

### 3. **Handles All Comment Formats**

- **ADF (Atlassian Document Format)**: Prepends attribution paragraph
- **Plain text**: Prepends attribution with formatting
- **No comment**: Creates comment with just attribution

### 4. **Added SSL Retry Logic**

All REST API calls now use `Invoke-JiraWithRetry`:
- Get worklogs from source ✅
- Get existing worklogs from target ✅
- Create worklog in target ✅

### 5. **User-Friendly Date Format**

Uses the same friendly format as comments:
- Format: `MMMM d, yyyy \a\t h:mm tt`
- Example: `March 15, 2024 at 2:30 PM`

---

## 🎨 Example Output

### Worklog with Existing Comment (ADF Format)

```
Time Spent: 2 hours
Started: March 15, 2024 at 2:30 PM
Comment:
  Originally logged by John Doe on March 15, 2024 at 2:30 PM
  
  Fixed authentication bug. Updated password hashing algorithm
  and added two-factor authentication support.
```

### Worklog without Existing Comment

```
Time Spent: 30 minutes
Started: January 5, 2024 at 9:15 AM
Comment:
  Originally logged by Jane Smith on January 5, 2024 at 9:15 AM
```

### Worklog with Plain Text Comment

```
Time Spent: 4 hours
Started: December 1, 2024 at 1:00 PM
Comment:
  Originally logged by Bob Johnson on December 1, 2024 at 1:00 PM
  
  Code review and testing
```

---

## ✅ Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Attribution** | ✅ | Preserves original author name |
| **Friendly Dates** | ✅ | "March 15, 2024 at 2:30 PM" format |
| **Idempotent** | ✅ | Safe to re-run multiple times |
| **ADF Support** | ✅ | Handles Atlassian Document Format |
| **Plain Text Support** | ✅ | Handles plain text comments |
| **No Comment Handling** | ✅ | Creates attribution-only comment |
| **SSL Retry** | ✅ | Automatic retry on SSL errors |
| **Preserves Original Comment** | ✅ | Appends to existing worklog comment |

---

## 🔄 How It Works

### Migration Process:

```
1. Read worklog from source
   ↓
2. Extract: Author, Date, Time Spent, Comment
   ↓
3. Build attribution text:
   "Originally logged by John Doe on March 15, 2024 at 2:30 PM"
   ↓
4. Check if worklog with this attribution already exists (idempotency)
   ↓
5. If exists: Skip
   If not: Create new worklog
   ↓
6. Prepend attribution to worklog comment
   ↓
7. Create worklog in target issue
```

### Idempotency Check:

```
For each existing worklog in target:
  Check if comment contains:
    "Originally logged by [author] on [date]"
  
  If found: Skip (already migrated)
  If not found: Migrate
```

---

## 📊 Migration Output Examples

### During Migration:

```
Migrating worklogs for LAS-749 → LAS1-4324
  Found 5 worklogs
    ✅ Worklog created (id=12345) - 2h
    ✅ Worklog created (id=12346) - 30m
    ⏭️  Worklog already exists (skipped): 1h
    ✅ Worklog created (id=12347) - 4h
    ✅ Worklog created (id=12348) - 1.5h
```

### Summary:

```
=== MIGRATION SUMMARY ===
✅ Worklogs migrated: 234
⏭️  Worklogs skipped: 15 (already existed - idempotency)
❌ Worklogs failed: 0
📊 Total worklogs processed: 249
⏱️  Total time migrated: 156.5 hours

Top worklog contributors:
  - John Doe: 45 worklogs (78.5 hours)
  - Jane Smith: 32 worklogs (54.0 hours)
  - Bob Johnson: 28 worklogs (45.5 hours)
```

---

## 🆚 Comparison

### Before vs After

| Aspect | Before | After |
|--------|--------|-------|
| **Author** | API user | Attributed in comment |
| **Date Format** | `2024-03-15 14:30:00` | `March 15, 2024 at 2:30 PM` |
| **Idempotency** | Time + Date match | Attribution text match |
| **SSL Errors** | No retry | Automatic retry 3x |
| **Comment Preservation** | ✅ | ✅ Enhanced with attribution |

---

## 💡 Usage

### Normal Migration:

```powershell
cd Z:\Code\OMF\Migration
.\src\steps\12_Worklogs.ps1 -ParametersPath "config\migration-parameters.json"
```

### What You'll See:

```
=== MIGRATING TIME TRACKING WORKLOGS ===
Source Project: LAS
Target Project: LAS1
Batch Size: 100

  Migrating worklogs for LAS-123 → LAS1-456
    Found 3 worklogs
      ✅ Worklog created (id=12345) - 2h
      ✅ Worklog created (id=12346) - 1h 30m
      ✅ Worklog created (id=12347) - 4h
```

### Re-running (Idempotency):

```powershell
# Safe to re-run - will skip existing worklogs
.\src\steps\12_Worklogs.ps1
```

Output:
```
  Migrating worklogs for LAS-123 → LAS1-456
    Found 3 worklogs
      ⏭️  Worklog already exists (skipped): 2h
      ⏭️  Worklog already exists (skipped): 1h 30m
      ⏭️  Worklog already exists (skipped): 4h
```

---

## ⚠️ Important Notes

### 1. **API Limitation**

Jira API doesn't support setting the worklog author. This is by design for audit and accountability reasons. The authenticated API user is always recorded as the creator.

**Our Solution:** Add attribution text to the comment so everyone knows who actually did the work.

### 2. **Time Zone Handling**

Worklogs are converted to UTC for API submission but display in local time in Jira UI based on user preferences.

### 3. **Existing Worklogs**

If you've already migrated worklogs without attribution, re-running will create new worklogs with attribution (duplicates). To avoid this:
- Option A: Accept duplicates and manually delete old ones
- Option B: Manually add attribution text to existing worklog comments first

### 4. **Worklog Permissions**

The API user must have permission to add worklogs to issues. Check project permissions if worklogs fail to create.

---

## 🔍 Verification

### Check Migrated Worklogs:

1. **In Jira UI:**
   - Go to any migrated issue
   - Click "Time Tracking" or "Work Log" tab
   - Look for worklog comments with attribution text

2. **In Migration Receipt:**
   ```powershell
   $receipt = Get-Content "out\12_Worklogs_receipt.json" | ConvertFrom-Json
   $receipt | Format-List
   ```

### Example Receipt Data:

```json
{
  "TotalWorklogsProcessed": 249,
  "MigratedWorklogs": 234,
  "SkippedWorklogs": 15,
  "FailedWorklogs": 0,
  "TotalTimeMigratedHours": 156.5,
  "IdempotencyEnabled": true
}
```

---

## 🎯 Benefits

✅ **Preserves Attribution** - Know who did the work  
✅ **Friendly Dates** - Easy to read date/time format  
✅ **Idempotent** - Safe to re-run  
✅ **Resilient** - Automatic SSL retry  
✅ **Complete** - Preserves all worklog data  
✅ **Auditable** - Full migration trail  

---

## 📚 Related Updates

This change aligns with similar updates made to:
- ✅ **Comment Migration** (`09_Comments.ps1`)
- ✅ **Comment Retry Utility** (`09_RetryFailedComments.ps1`)

All three now use:
- Same friendly date format
- Same attribution pattern
- Same idempotency approach
- Same SSL retry logic

---

## ✨ Summary

**Problem:** Jira API can't set worklog authors  
**Solution:** Add attribution to worklog comments  
**Format:** "Originally logged by [Name] on [Friendly Date]"  
**Result:** Full worklog history preserved with proper attribution  

**Status:** ✅ **Ready to Use**

---

**Next Migration:** Your worklogs will include attribution like:
```
Originally logged by John Doe on March 15, 2024 at 2:30 PM
```

Perfect for maintaining accountability and audit trails! 🎉

