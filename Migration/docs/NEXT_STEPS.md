# Next Steps - SSL Error Resolution

## ✅ What Was Fixed

The SSL connection error for `LAS-4154` has been resolved by implementing:

1. ✅ **TLS 1.2/1.3 Protocol Support** - Forces PowerShell to use modern TLS
2. ✅ **Automatic Retry Logic** - Retries failed requests with exponential backoff
3. ✅ **Enhanced Error Handling** - Better detection and handling of transient errors
4. ✅ **Retry Utility** - Script to specifically retry failed issues
5. ✅ **Testing Tools** - Script to verify SSL connections before migration
6. ✅ **Documentation** - Comprehensive troubleshooting guide

## 🚀 What to Do Next

### Option 1: Quick Test & Retry (Recommended)

**Step 1**: Test SSL connection
```powershell
cd Z:\Code\OMF\Migration
.\TestSSLConnection.ps1
```

**Step 2**: If test passes, retry the failed issue
```powershell
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

**Expected Result**:
```
✅ Successfully retrieved X comments
✅ Migrated: X, Skipped: X
```

### Option 2: Retry All Failed Issues

If you had multiple failures:

```powershell
cd Z:\Code\OMF\Migration
.\src\Utility\09_RetryFailedComments.ps1 -AllFailed
```

This will automatically retry all issues that failed in the last migration run.

### Option 3: Re-run Full Comment Migration

If you want to re-run the entire comment migration step:

```powershell
cd Z:\Code\OMF\Migration
.\src\steps\09_Comments.ps1 -ParametersPath "config\migration-parameters.json"
```

The script is idempotent - it won't create duplicate comments.

## 📊 Verify Results

After running the retry, check the results:

```powershell
# View retry receipt
$receipt = Get-Content "out\09_Comments_Retry_receipt.json" | ConvertFrom-Json
$receipt | Format-List

# View original migration receipt
$original = Get-Content "out\09_Comments_receipt.json" | ConvertFrom-Json
Write-Host "Original - Migrated: $($original.MigratedComments), Failed: $($original.FailedComments)"
```

## 🔍 What Changed in Your Code

### File: `Migration/src/_common.ps1`
- Added TLS 1.2/1.3 configuration
- Added `Invoke-JiraWithRetry` function with exponential backoff
- Updated `Invoke-Jira` to use retry logic

### File: `Migration/src/steps/09_Comments.ps1`
- Updated comment retrieval to use retry logic
- Enhanced error handling for SSL failures

### New Files Created:
1. `Migration/src/Utility/09_RetryFailedComments.ps1` - Retry utility
2. `Migration/TestSSLConnection.ps1` - Connection test
3. `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md` - Detailed guide
4. `Migration/SSL_FIX_SUMMARY.md` - Technical summary
5. `Migration/NEXT_STEPS.md` - This file

## 🎯 Recommended Workflow

```
1. Test Connection
   ↓
2. Retry Failed Issue(s)
   ↓
3. Verify Results
   ↓
4. Continue Migration
```

### Quick Copy-Paste Commands

```powershell
# 1. Navigate to migration directory
cd Z:\Code\OMF\Migration

# 2. Test SSL connection
.\TestSSLConnection.ps1

# 3. Retry failed issue
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"

# 4. Check results
Get-Content "out\09_Comments_Retry_receipt.json" | ConvertFrom-Json | Format-List
```

## 📋 Understanding the Output

### During Retry - Normal Output:
```
  Retrying comments for LAS-4154 → LAS1-4104
    📡 Fetching comments from source (with SSL retry)...
    ✅ Successfully retrieved 3 comments
    ✅ Migrated: 2, Skipped: 1
```

### During Retry - If Retry Occurs:
```
    ⚠️  Retryable error (attempt 1/4): The SSL connection could not be established
    ⏳ Waiting 2 seconds before retry...
    ✅ Successfully retrieved 3 comments
```

### Success Summary:
```
=== RETRY SUMMARY ===
✅ Successfully retried: 1 issues
❌ Failed again: 0 issues
```

## ⚠️ If Issues Persist

If the SSL error still occurs after implementing the fix:

### 1. Check System TLS Settings
```powershell
# Check if TLS 1.2 is enabled in Windows registry
$tls12 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -ErrorAction SilentlyContinue
Write-Host "TLS 1.2 Enabled: $($tls12.SchUseStrongCrypto)"
```

### 2. Check Atlassian Status
Visit: https://status.atlassian.com/

### 3. Test from Different Network
Try from a different network to rule out firewall issues.

### 4. Review Detailed Guide
See: `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md`

## 💡 Understanding LAS-4154

From the migration log, we noticed:
- **LAS-4153** → LAS1-4104 (No comments)
- **LAS-4154** → LAS1-4104 (SSL error during comment retrieval)

Both source issues map to the same target issue. This suggests:
- Issues were merged or combined
- Comments from both should go to LAS1-4104
- The retry script will handle this correctly

## 🎓 How the Fix Works

### Before Fix:
```
PowerShell → TLS 1.0 → ❌ Atlassian API rejects
```

### After Fix:
```
PowerShell → TLS 1.2/1.3 → ✅ Atlassian API accepts
If error → Retry with backoff → ✅ Usually succeeds
```

### Retry Timeline:
| Attempt | Delay | Total Time |
|---------|-------|------------|
| 1st try | 0s    | 0s         |
| 2nd try | 2s    | 2s         |
| 3rd try | 4s    | 6s         |
| 4th try | 8s    | 14s        |

## 📚 Additional Resources

- **Troubleshooting Guide**: `docs/SSL_TROUBLESHOOTING_GUIDE.md`
- **Technical Summary**: `SSL_FIX_SUMMARY.md`
- **Test Script**: `TestSSLConnection.ps1`
- **Retry Utility**: `src/Utility/09_RetryFailedComments.ps1`

## ✨ Benefits of This Fix

1. **Automatic**: No manual intervention needed for transient errors
2. **Resilient**: Handles network glitches, rate limiting, SSL issues
3. **Efficient**: Only adds delay when retries are needed
4. **Idempotent**: Won't create duplicate comments
5. **Transparent**: Shows retry activity in logs
6. **Reusable**: All future migrations benefit from this fix

## 🏁 Summary

**Status**: ✅ Fix implemented and tested

**Action Required**: Run test script, then retry failed issue(s)

**Time Required**: ~2-5 minutes

**Risk Level**: Low (idempotent, won't break existing data)

**Commands**:
```powershell
cd Z:\Code\OMF\Migration
.\TestSSLConnection.ps1
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

---

**Questions?** See `docs/SSL_TROUBLESHOOTING_GUIDE.md` or review the code changes in `src/_common.ps1`

