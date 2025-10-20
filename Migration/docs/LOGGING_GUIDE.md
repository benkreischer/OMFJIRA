# Migration Logging Guide

## Overview

The migration system now includes centralized logging that writes to markdown files in real-time. You can monitor these logs in a terminal window to see progress and catch errors as they happen.

## Quick Start

### 1. Start a log monitor (in a separate terminal)

```powershell
# Watch logs for a specific project
.\Watch-Log.ps1 -ProjectKey QUAL

# Or watch a specific log file
.\Watch-Log.ps1 -LogFile "projects\QUAL\out\20251013_143022_QUAL_Migration.log.md"

# Or auto-find the most recent log
.\Watch-Log.ps1
```

### 2. Run your migration

The logging will automatically capture everything in markdown format.

## Integration Example

To integrate logging into a migration step:

```powershell
# At the start of your script
. "$PSScriptRoot\..\src\_logging.ps1"

# Initialize the log
$logFile = Initialize-MigrationLog -ProjectKey $ProjectKey -OutDir $OutDir -Operation "SyncUsers"

Write-LogStep "Step 03: Sync Users and Roles"

Write-LogInfo "Loading source project users..." -Component "API"
# ... your code ...

Write-LogSuccess "Found 45 users in source project" -Component "API"

Write-LogSubStep "Processing User Synchronization"

foreach ($user in $users) {
    Write-LogDetail "Processing: $($user.displayName) ($($user.emailAddress))"
    
    try {
        # ... your code ...
        Write-LogSuccess "✓ Added user: $($user.displayName)"
    }
    catch {
        Write-LogError "Failed to add user: $($user.displayName)" -ErrorRecord $_
    }
}

# At the end
Write-LogTable "Summary Statistics" @{
    "Total Users" = $totalUsers
    "Succeeded" = $succeeded
    "Failed" = $failed
    "Skipped" = $skipped
}

Complete-MigrationLog -Success:$($failed -eq 0)
```

## Log Output Format

The log file will look like this:

```markdown
# Migration Log: QUAL
**Operation:** Migration  
**Started:** 2025-10-13 14:30:22  

---

## 🔷 Step 03: Sync Users and Roles

[14:30:23] ℹ️ **[API]** Loading source project users...
[14:30:25] ✅ **[API]** Found 45 users in source project

### ▫️ Processing User Synchronization

[14:30:26]   → Processing: John Doe (john@example.com)
[14:30:27] ✅ ✓ Added user: John Doe
[14:30:27]   → Processing: Jane Smith (jane@example.com)
[14:30:28] ❌ **ERROR** Failed to add user: Jane Smith

**Summary Statistics**

| Property | Value |
|----------|-------|
| Total Users | 45 |
| Succeeded | 44 |
| Failed | 1 |
| Skipped | 0 |

---

## Summary

❌ **COMPLETED WITH ERRORS**

**Duration:** 00:02:15  
**Completed:** 2025-10-13 14:32:37
```

## Available Functions

### Initialization
- `Initialize-MigrationLog` - Start a new log file

### Logging Levels
- `Write-LogStep` - Major step header (##)
- `Write-LogSubStep` - Sub-step header (###)
- `Write-LogInfo` - Informational message
- `Write-LogSuccess` - Success message
- `Write-LogWarning` - Warning message
- `Write-LogError` - Error message (can include full error details)
- `Write-LogDetail` - Detailed/verbose message

### Special Formatting
- `Write-LogTable` - Create markdown table
- `Write-LogCodeBlock` - Create code block (JSON, etc.)
- `Complete-MigrationLog` - Write summary footer

## Tips

1. **Use two terminal windows**: One to run the migration, one to watch the log
2. **Logs are timestamped**: Each entry shows HH:mm:ss for easy tracking
3. **Markdown format**: Logs can be opened in any markdown viewer after completion
4. **Error details**: Full stack traces are captured for debugging
5. **Component tagging**: Use `-Component` to categorize messages (API, Validation, etc.)

## Log File Location

Logs are stored in: `projects\{PROJECT_KEY}\out\{TIMESTAMP}_{PROJECT_KEY}_{OPERATION}.log.md`

Example: `projects\QUAL\out\20251013_143022_QUAL_Migration.log.md`

