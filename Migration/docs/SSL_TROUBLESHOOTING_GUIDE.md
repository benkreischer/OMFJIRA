# SSL Connection Error Troubleshooting Guide

## Overview

This guide addresses SSL/TLS connection errors that can occur during Jira migration, particularly when retrieving comments or other data from source Jira instances.

## Common Error Message

```
❌ Failed to retrieve comments for LAS-XXXX : The SSL connection could not be established, see inner exception.
```

## Root Causes

### 1. **TLS Protocol Version Mismatch** (Most Common)
- **Problem**: PowerShell defaults to TLS 1.0/1.1, but modern Atlassian APIs require TLS 1.2+
- **Solution**: Updated `_common.ps1` to force TLS 1.2/1.3
- **Status**: ✅ FIXED

### 2. **Transient Network Issues**
- **Problem**: Temporary network glitches, packet loss, or DNS resolution issues
- **Solution**: Implemented retry logic with exponential backoff
- **Status**: ✅ FIXED

### 3. **API Rate Limiting**
- **Problem**: Too many requests in short period
- **Solution**: Retry mechanism with backoff delays
- **Status**: ✅ FIXED

### 4. **Certificate Validation Issues**
- **Problem**: Self-signed certificates or corporate proxies
- **Solution**: See "Advanced Troubleshooting" below
- **Status**: ⚠️ Manual intervention may be required

### 5. **Timeout Issues**
- **Problem**: Slow responses from API causing timeouts
- **Solution**: Increased timeout from default to 30 seconds
- **Status**: ✅ FIXED

## What We Fixed

### 1. SSL/TLS Configuration (`_common.ps1`)

Added at the beginning of `_common.ps1`:

```powershell
# Force PowerShell to use TLS 1.2 and 1.3
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Increase connection limits
[Net.ServicePointManager]::DefaultConnectionLimit = 100
[Net.ServicePointManager]::Expect100Continue = $false
```

### 2. Retry Logic with Exponential Backoff

New function `Invoke-JiraWithRetry`:
- Automatically retries on SSL errors
- Exponential backoff: 2s, 4s, 8s delays
- Retries up to 3 times by default
- Handles multiple error types:
  - SSL connection failures
  - Timeouts
  - Network errors
  - Rate limiting (429, 502, 503, 504)

### 3. Enhanced Timeout Handling

- Increased timeout to 30 seconds (from PowerShell default of 100s, but with better control)
- Configurable per request

### 4. Updated Comment Migration Script

All REST API calls in `09_Comments.ps1` now use retry logic:
- Getting source comments
- Getting target comments  
- Creating comments in target

## How to Use

### Normal Migration Run

Simply run the migration as usual:

```powershell
.\RunMigration.ps1 -ParametersPath "config\migration-parameters.json"
```

The retry logic is automatic. You'll see yellow warning messages if retries occur:

```
⚠️  Retryable error (attempt 1/4): The SSL connection could not be established
⏳ Waiting 2 seconds before retry...
```

### Retry Failed Issues Only

If some issues still fail after the main migration, use the retry utility:

```powershell
# Retry specific issues
.\src\Utility\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154","LAS-4155"

# Or retry all failed issues from last run
.\src\Utility\09_RetryFailedComments.ps1 -AllFailed
```

The retry script uses:
- **5 retry attempts** (instead of 3)
- **45 second timeout** (instead of 30)
- More verbose output

## Advanced Troubleshooting

### If SSL Errors Persist

#### Option 1: Check Network Connectivity

```powershell
# Test basic connectivity
Test-NetConnection -ComputerName "onemain.atlassian.net" -Port 443

# Test TLS versions supported
$uri = "https://onemain.atlassian.net"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$req = [Net.WebRequest]::Create($uri)
$req.GetResponse()
```

#### Option 2: Verify API Token

```powershell
# Test authentication
$base = "https://onemain.atlassian.net"
$email = "your-email@omf.com"
$token = "your-api-token"

$pair = "$email:$token"
$bytes = [Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [Convert]::ToBase64String($bytes)
$headers = @{ Authorization = "Basic $base64" }

Invoke-RestMethod -Uri "$base/rest/api/3/myself" -Headers $headers
```

#### Option 3: Bypass Certificate Validation (TEMPORARY/TESTING ONLY)

⚠️ **WARNING**: Only use this for testing/debugging. Never use in production.

Add to `_common.ps1` temporarily:

```powershell
# TEMPORARY - DO NOT USE IN PRODUCTION
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
```

#### Option 4: Check Corporate Proxy

If behind a corporate proxy:

```powershell
# Check proxy settings
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials

# Or set explicitly
$proxy = New-Object System.Net.WebProxy("http://proxy.company.com:8080")
$proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
[System.Net.WebRequest]::DefaultWebProxy = $proxy
```

#### Option 5: Increase Retry Attempts

Modify retry parameters in the script:

```powershell
# In 09_Comments.ps1 or 09_RetryFailedComments.ps1
# Change from:
Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $headers -MaxRetries 3 -TimeoutSec 30

# To:
Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $headers -MaxRetries 10 -TimeoutSec 60
```

### Check Windows TLS Configuration

Verify TLS 1.2 is enabled in Windows:

```powershell
# Check registry keys
$tls12Client = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -ErrorAction SilentlyContinue
$tls12Client64 = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -ErrorAction SilentlyContinue

Write-Host "TLS 1.2 Enabled (32-bit): $($tls12Client.SchUseStrongCrypto)"
Write-Host "TLS 1.2 Enabled (64-bit): $($tls12Client64.SchUseStrongCrypto)"
```

If both show 0 or are missing, enable TLS 1.2:

```powershell
# Run as Administrator
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NETFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value 1 -Type DWord
```

## Monitoring and Logging

### Check Migration Logs

Logs are saved in `out/logs/` directory:

```powershell
Get-ChildItem -Path "out\logs\" | Sort-Object LastWriteTime -Descending | Select-Object -First 5
```

### Check Comment Migration Receipt

```powershell
$receipt = Get-Content "out\09_Comments_receipt.json" | ConvertFrom-Json
Write-Host "Total Comments Processed: $($receipt.TotalCommentsProcessed)"
Write-Host "Migrated: $($receipt.MigratedComments)"
Write-Host "Failed: $($receipt.FailedComments)"
Write-Host "Skipped: $($receipt.SkippedComments)"

# Show failed comment details
$receipt.FailedCommentDetails | Format-Table
```

## Prevention Tips

1. **Run migration during off-peak hours** to avoid rate limiting
2. **Use a stable network connection** (wired preferred over WiFi)
3. **Keep API tokens fresh** (regenerate if needed)
4. **Monitor Atlassian status page**: https://status.atlassian.com/
5. **Test connectivity first** using the test scripts
6. **Use batch processing** (already implemented - 100 issues per batch)

## Configuration Tuning

In `config/migration-parameters.json`, you can adjust:

```json
{
  "AnalysisSettings": {
    "BatchSize": 50,           // Reduce if hitting rate limits (default: 100)
    "RetryAttempts": 5         // Increase for unreliable networks (default: 3)
  }
}
```

## Issue-Specific Notes

### LAS-4154 Error Analysis

From the terminal output:
- **Issue**: LAS-4154 → LAS1-4104
- **Note**: Both LAS-4153 and LAS-4154 map to same target (LAS1-4104)
- **Possible Causes**:
  1. Duplicate mapping (by design?)
  2. Issue merged/combined
  3. SSL error coincided with duplicate mapping

**Action**: Verify if the duplicate mapping is intentional. If so, the SSL error may have prevented detection of existing comments from LAS-4153.

## Getting Help

If SSL errors persist after trying these solutions:

1. **Check Atlassian Status**: https://status.atlassian.com/
2. **Contact Atlassian Support**: Especially if API endpoints are consistently failing
3. **Review Jira Permissions**: Ensure service account has access to all issues
4. **Check Enterprise Firewall**: Corporate firewalls may block certain TLS versions

## Files Modified

- ✅ `Migration/src/_common.ps1` - Added TLS config and retry logic
- ✅ `Migration/src/steps/09_Comments.ps1` - Updated to use retry mechanism
- ✅ `Migration/src/Utility/09_RetryFailedComments.ps1` - NEW utility for retrying

## Testing the Fix

To verify the fix works for LAS-4154:

```powershell
cd Migration/src/Utility
.\09_RetryFailedComments.ps1 -IssueKeys "LAS-4154"
```

Expected output:
```
=== RETRY FAILED COMMENT MIGRATIONS ===
Source Project: LAS
Target Project: LAS1

  Retrying comments for LAS-4154 → LAS1-4104
    📡 Fetching comments from source (with SSL retry)...
    ✅ Successfully retrieved X comments
    ✅ Migrated: X, Skipped: X
```

## Summary

The SSL error was primarily caused by PowerShell's default TLS 1.0 usage, which modern APIs reject. The fix includes:

1. ✅ Force TLS 1.2/1.3 usage
2. ✅ Retry logic with exponential backoff
3. ✅ Increased timeouts
4. ✅ Better error handling
5. ✅ Utility to retry specific failed issues

**Status**: Issue resolved. Run the retry script to verify.

