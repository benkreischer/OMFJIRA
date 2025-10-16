# SSL Connection Error Fix - Summary

## Problem

During comment migration for issue `LAS-4154`, the following error occurred:

```
❌ Failed to retrieve comments for LAS-4154 : The SSL connection could not be established, see inner exception.
```

## Root Cause

PowerShell by default uses older TLS protocols (1.0/1.1) which are not supported by modern Atlassian APIs. Additionally, the migration script had no retry mechanism for transient network/SSL errors.

## Solution Implemented

### 1. **TLS/SSL Configuration** ✅

**File**: `Migration/src/_common.ps1`

Added automatic TLS 1.2/1.3 configuration at script initialization:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
[Net.ServicePointManager]::DefaultConnectionLimit = 100
[Net.ServicePointManager]::Expect100Continue = $false
```

**Impact**: All scripts that load `_common.ps1` now automatically use secure TLS protocols.

### 2. **Retry Logic with Exponential Backoff** ✅

**File**: `Migration/src/_common.ps1`

Added new function `Invoke-JiraWithRetry` that:
- Automatically retries failed requests up to 3 times (configurable)
- Uses exponential backoff: 2s, 4s, 8s delays between retries
- Handles these error types:
  - SSL connection failures
  - Network timeouts
  - Connection errors
  - Rate limiting (HTTP 429, 502, 503, 504)

Updated `Invoke-Jira` function to use the retry wrapper automatically.

**Impact**: All API calls through `Invoke-Jira` now have automatic retry capability.

### 3. **Enhanced Comment Migration** ✅

**File**: `Migration/src/steps/09_Comments.ps1`

Updated all REST API calls to use retry mechanism:
- Line 123: Get comments from source issue
- Line 136: Get existing comments from target issue
- Line 229: Create comments in target issue

**Impact**: Comment migration is now resilient to transient SSL/network errors.

### 4. **Retry Failed Issues Utility** ✅ NEW

**File**: `Migration/src/Utility/09_RetryFailedComments.ps1`

New utility script that allows retrying specific failed issues:

```powershell
# Retry specific issues
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154","LAS-4155"

# Retry all failed issues from last run
.\src\Utility\09_RetryFailedComments.ps1 -AllFailed
```

Features:
- Uses 5 retry attempts (vs 3 in normal migration)
- 45-second timeout (vs 30 in normal migration)
- Detailed progress output
- Idempotency-aware (won't duplicate comments)

### 5. **Connection Test Script** ✅ NEW

**File**: `Migration/TestSSLConnection.ps1`

New diagnostic script to verify SSL connections before migration:

```powershell
.\TestSSLConnection.ps1
```

Tests:
- TLS configuration
- Source Jira authentication and connectivity
- Target Jira authentication and connectivity
- Comment API endpoint specifically
- Provides troubleshooting hints for failures

### 6. **Comprehensive Documentation** ✅ NEW

**File**: `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md`

Complete troubleshooting guide covering:
- Root causes of SSL errors
- Prevention tips
- Advanced troubleshooting steps
- Configuration tuning
- Monitoring and logging

## Files Modified

| File | Status | Description |
|------|--------|-------------|
| `Migration/src/_common.ps1` | ✏️ Modified | Added TLS config and retry logic |
| `Migration/src/steps/09_Comments.ps1` | ✏️ Modified | Updated to use retry mechanism |
| `Migration/src/Utility/09_RetryFailedComments.ps1` | ✨ NEW | Utility for retrying failed issues |
| `Migration/TestSSLConnection.ps1` | ✨ NEW | Connection diagnostic tool |
| `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md` | ✨ NEW | Comprehensive troubleshooting guide |
| `Migration/SSL_FIX_SUMMARY.md` | ✨ NEW | This file |

## How to Use

### Step 1: Test the Fix

Run the connection test to verify SSL is working:

```powershell
cd Migration
.\TestSSLConnection.ps1
```

Expected output:
```
=== JIRA SSL CONNECTION TEST ===
1️⃣  Testing TLS Configuration...
   ✅ TLS 1.2 is enabled
2️⃣  Testing Source Jira Connection...
   ✅ Source environment: ALL TESTS PASSED
3️⃣  Testing Target Jira Connection...
   ✅ Target environment: ALL TESTS PASSED
```

### Step 2: Retry Failed Issue(s)

For the specific LAS-4154 issue:

```powershell
cd Migration\src\Utility
.\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

Or retry all failed issues:

```powershell
.\09_RetryFailedComments.ps1 -AllFailed
```

### Step 3: Verify Results

Check the retry receipt:

```powershell
cd Migration
Get-Content "out\09_Comments_Retry_receipt.json" | ConvertFrom-Json
```

## Expected Outcome

After running the retry script, you should see:

```
=== RETRY FAILED COMMENT MIGRATIONS ===
Source Project: LAS
Target Project: LAS1

  Retrying comments for LAS-4154 → LAS1-4104
    📡 Fetching comments from source (with SSL retry)...
    ✅ Successfully retrieved X comments
    ✅ Migrated: X, Skipped: X

=== RETRY SUMMARY ===
✅ Successfully retried: 1 issues
❌ Failed again: 0 issues
```

## Technical Details

### TLS Protocol Support

Before fix:
```
SecurityProtocol: Ssl3, Tls
```

After fix:
```
SecurityProtocol: Tls12, Tls13
```

### Retry Behavior

| Attempt | Wait Time | Total Time Elapsed |
|---------|-----------|-------------------|
| 1 (initial) | 0s | 0s |
| 2 | 2s | 2s |
| 3 | 4s | 6s |
| 4 | 8s | 14s |

### Timeout Configuration

- Default timeout: **30 seconds** per request
- Retry script timeout: **45 seconds** per request
- Total max time per request (with retries): **~2 minutes**

## Monitoring Future Runs

### Check for Retry Activity

During migration, look for yellow warning messages indicating retries:

```
⚠️  Retryable error (attempt 1/4): The SSL connection could not be established
⏳ Waiting 2 seconds before retry...
```

### Review Comment Migration Receipt

```powershell
$receipt = Get-Content "Migration\out\09_Comments_receipt.json" | ConvertFrom-Json

Write-Host "Comments Migrated: $($receipt.MigratedComments)"
Write-Host "Comments Failed: $($receipt.FailedComments)"
Write-Host "Comments Skipped: $($receipt.SkippedComments)"

# Show any failures
if ($receipt.FailedCommentDetails) {
    $receipt.FailedCommentDetails | Format-Table SourceKey, TargetKey, Error
}
```

## Prevention for Future Migrations

1. **Always run TestSSLConnection.ps1 first** to verify connectivity
2. **Monitor during migration** for yellow retry warnings
3. **Use off-peak hours** to avoid rate limiting
4. **Ensure stable network** (wired connection preferred)
5. **Keep API tokens fresh** (regenerate if near expiration)

## Additional Notes

### About LAS-4154 Specifically

From the migration log, we noticed:
- Both LAS-4153 and LAS-4154 map to the same target issue: **LAS1-4104**
- This suggests these issues were merged or combined
- The SSL error may have prevented detection of existing comments

When retrying, the idempotency check will prevent duplicate comments.

### Performance Impact

The retry mechanism adds minimal overhead:
- **No retries needed**: No delay
- **1 retry**: +2 seconds
- **2 retries**: +6 seconds total
- **3 retries**: +14 seconds total

For a migration with 100 issues and 1% failure rate:
- Best case: No additional time
- Worst case (all fail once): +200 seconds (~3 minutes)

## Troubleshooting

If SSL errors persist after implementing this fix:

1. Check Windows TLS registry settings (see guide)
2. Verify corporate firewall allows TLS 1.2
3. Test from different network (to rule out network issues)
4. Check Atlassian status: https://status.atlassian.com/
5. Contact Atlassian support if API is consistently failing

For detailed troubleshooting, see: `Migration/docs/SSL_TROUBLESHOOTING_GUIDE.md`

## Support

For questions or issues:

1. Review `SSL_TROUBLESHOOTING_GUIDE.md`
2. Run `TestSSLConnection.ps1` for diagnostics
3. Check migration receipts in `out/` directory
4. Review logs in `out/logs/` directory

## Summary

✅ SSL/TLS configuration fixed  
✅ Retry logic implemented  
✅ Comment migration enhanced  
✅ Retry utility created  
✅ Test script provided  
✅ Comprehensive documentation added  

**Status**: Ready to retry failed issues. Run `.\TestSSLConnection.ps1` to verify, then `.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"` to retry the failed issue.

