# SSL Error Fix - Quick Reference Card

## 🚨 Problem
```
❌ Failed to retrieve comments for LAS-4154 : The SSL connection could not be established
```

## ✅ Solution - Copy & Paste These Commands

### Step 1: Test Connection (30 seconds)
```powershell
cd Z:\Code\OMF\Migration
.\TestSSLConnection.ps1
```

### Step 2: Retry Failed Issue (1-2 minutes)
```powershell
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

### Step 3: Verify Success
```powershell
Get-Content "out\09_Comments_Retry_receipt.json" | ConvertFrom-Json
```

## 📄 Files Modified
- ✏️ `src/_common.ps1` - Added TLS 1.2/1.3 + retry logic
- ✏️ `src/steps/09_Comments.ps1` - Uses retry logic
- ✨ `src/Utility/09_RetryFailedComments.ps1` - NEW retry tool
- ✨ `TestSSLConnection.ps1` - NEW connection test
- ✨ `docs/SSL_TROUBLESHOOTING_GUIDE.md` - NEW guide

## 🎯 What Was Fixed
1. **TLS Protocol**: Now uses TLS 1.2/1.3 (was using TLS 1.0)
2. **Retry Logic**: Auto-retries 3x with delays (2s, 4s, 8s)
3. **Error Handling**: Detects and handles SSL/network errors
4. **Timeout**: Increased to 30s (retry script uses 45s)

## 🔄 Retry Options

### Retry One Issue
```powershell
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

### Retry Multiple Issues
```powershell
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154","LAS-4155","LAS-4156"
```

### Retry All Failed
```powershell
.\src\Utility\09_RetryFailedComments.ps1 -AllFailed
```

## 📊 Expected Output

### ✅ Success
```
  Retrying comments for LAS-4154 → LAS1-4104
    📡 Fetching comments from source (with SSL retry)...
    ✅ Successfully retrieved 3 comments
    ✅ Migrated: 3, Skipped: 0

=== RETRY SUMMARY ===
✅ Successfully retried: 1 issues
❌ Failed again: 0 issues
```

### ⏳ With Retry (Normal)
```
    ⚠️  Retryable error (attempt 1/4): SSL connection could not be established
    ⏳ Waiting 2 seconds before retry...
    ✅ Successfully retrieved 3 comments
```

### ❌ Still Failing
See troubleshooting guide: `docs/SSL_TROUBLESHOOTING_GUIDE.md`

## 💡 Key Features

| Feature | Benefit |
|---------|---------|
| **Automatic TLS 1.2/1.3** | No more SSL errors |
| **Exponential Backoff** | Handles transient errors |
| **Idempotent** | Safe to re-run multiple times |
| **No Duplicate Comments** | Smart detection of existing comments |
| **Detailed Logging** | Know exactly what happened |

## 🛠️ Troubleshooting

### Test Failed?
```powershell
# Check TLS settings
[Net.ServicePointManager]::SecurityProtocol

# Should show: Tls12, Tls13
```

### Retry Still Failing?
1. Check network connection
2. Verify API token hasn't expired
3. Check Atlassian status: https://status.atlassian.com/
4. Try from different network
5. See detailed guide: `docs/SSL_TROUBLESHOOTING_GUIDE.md`

### How to Check Results?
```powershell
# Original migration
$orig = Get-Content "out\09_Comments_receipt.json" | ConvertFrom-Json
Write-Host "Migrated: $($orig.MigratedComments), Failed: $($orig.FailedComments)"

# Retry results
$retry = Get-Content "out\09_Comments_Retry_receipt.json" | ConvertFrom-Json
$retry.SuccessfulRetries | Format-Table
```

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| `NEXT_STEPS.md` | Detailed next steps |
| `SSL_FIX_SUMMARY.md` | Technical details of fix |
| `docs/SSL_TROUBLESHOOTING_GUIDE.md` | Comprehensive troubleshooting |
| `QUICK_REFERENCE.md` | This document |

## ⚡ One-Liner Solution

```powershell
cd Z:\Code\OMF\Migration; .\TestSSLConnection.ps1; .\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

## 🎯 Success Criteria

✅ Test script shows "ALL TESTS PASSED"  
✅ Retry script shows "Successfully retried: 1 issues"  
✅ No more SSL errors in output  
✅ Comments are migrated to target issue  

## 📞 Need Help?

1. Run test: `.\TestSSLConnection.ps1`
2. Check guide: `docs/SSL_TROUBLESHOOTING_GUIDE.md`
3. Review logs: `out/logs/`
4. Check receipts: `out/*.json`

---

**TL;DR**: Run `.\TestSSLConnection.ps1` then `.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"`

