# _logging.ps1 - Centralized Logging Utility for Migration Operations
#
# This module provides markdown-formatted logging that can be monitored in real-time

# Initialize log file path (will be set by main scripts)
$script:LogFilePath = ""
$script:LogStartTime = Get-Date

function Initialize-MigrationLog {
    param(
        [string]$ProjectKey,
        [string]$OutDir,
        [string]$Operation = "Migration",
        [switch]$ContinueExisting  # If true, continue an existing log instead of creating new
    )
    
    # Check if there's an existing log path in environment variable
    if ($env:MIGRATION_LOG_FILE -and (Test-Path $env:MIGRATION_LOG_FILE) -and $ContinueExisting) {
        $script:LogFilePath = $env:MIGRATION_LOG_FILE
        $script:LogStartTime = (Get-Item $script:LogFilePath).CreationTime
        Write-Verbose "Continuing existing log: $script:LogFilePath"
        return $script:LogFilePath
    }
    
    # Create log file path
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $script:LogFilePath = Join-Path $OutDir "${timestamp}_${ProjectKey}_${Operation}.log.md"
    $script:LogStartTime = Get-Date
    
    # Ensure directory exists
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    
    # Write header
    $header = @"
# Migration Log: $ProjectKey
**Operation:** $Operation  
**Started:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Log File:** ``$script:LogFilePath``

---

"@
    
    $header | Out-File -FilePath $script:LogFilePath -Encoding UTF8 -Force
    
    # Store in environment variable for child processes
    $env:MIGRATION_LOG_FILE = $script:LogFilePath
    
    return $script:LogFilePath
}

function Write-LogEntry {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Step", "SubStep", "Detail")]
        [string]$Level = "Info",
        [string]$Component = "",
        [switch]$NoTimestamp
    )
    
    if (-not $script:LogFilePath) {
        Write-Warning "Log not initialized. Call Initialize-MigrationLog first."
        return
    }
    
    $timestamp = if ($NoTimestamp) { "" } else { "[$(Get-Date -Format 'HH:mm:ss')] " }
    
    $emoji = switch ($Level) {
        "Info"    { "ℹ️" }
        "Success" { "✅" }
        "Warning" { "⚠️" }
        "Error"   { "❌" }
        "Step"    { "🔷" }
        "SubStep" { "▫️" }
        "Detail"  { "  →" }
    }
    
    $prefix = if ($Component) { "**[$Component]** " } else { "" }
    
    $formattedMessage = switch ($Level) {
        "Step"    { "`n## $emoji $Message`n" }
        "SubStep" { "`n### $emoji $Message`n" }
        "Error"   { "$timestamp$emoji **ERROR** $prefix$Message" }
        "Warning" { "$timestamp$emoji **WARNING** $prefix$Message" }
        "Success" { "$timestamp$emoji $prefix$Message" }
        default   { "$timestamp$emoji $prefix$Message" }
    }
    
    $formattedMessage | Out-File -FilePath $script:LogFilePath -Encoding UTF8 -Append
    
    # Also write to console with color
    $color = switch ($Level) {
        "Error"   { "Red" }
        "Warning" { "Yellow" }
        "Success" { "Green" }
        "Step"    { "Cyan" }
        "SubStep" { "Cyan" }
        default   { "White" }
    }
    
    Write-Host $formattedMessage -ForegroundColor $color
}

function Write-LogStep {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "Step" -Component $Component
}

function Write-LogSubStep {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "SubStep" -Component $Component
}

function Write-LogInfo {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "Info" -Component $Component
}

function Write-LogSuccess {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "Success" -Component $Component
}

function Write-LogWarning {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "Warning" -Component $Component
}

function Write-LogError {
    param([string]$Message, [string]$Component = "", [System.Management.Automation.ErrorRecord]$ErrorRecord)
    
    if ($ErrorRecord) {
        $errorDetails = @"
$Message

**Error Details:**
- **Message:** $($ErrorRecord.Exception.Message)
- **Type:** $($ErrorRecord.Exception.GetType().FullName)
- **Line:** $($ErrorRecord.InvocationInfo.ScriptLineNumber)
- **Script:** $($ErrorRecord.InvocationInfo.ScriptName)

``````
$($ErrorRecord.ScriptStackTrace)
``````
"@
        Write-LogEntry -Message $errorDetails -Level "Error" -Component $Component
    } else {
        Write-LogEntry -Message $Message -Level "Error" -Component $Component
    }
}

function Write-LogDetail {
    param([string]$Message, [string]$Component = "")
    Write-LogEntry -Message $Message -Level "Detail" -Component $Component
}

function Write-LogTable {
    param(
        [string]$Title,
        [hashtable]$Data
    )
    
    if (-not $script:LogFilePath) {
        return
    }
    
    $table = "`n**$Title**`n`n"
    $table += "| Property | Value |`n"
    $table += "|----------|-------|`n"
    
    foreach ($key in $Data.Keys) {
        $value = $Data[$key]
        if ($null -eq $value) { $value = "null" }
        $table += "| $key | $value |`n"
    }
    
    $table += "`n"
    $table | Out-File -FilePath $script:LogFilePath -Encoding UTF8 -Append
    Write-Host $table
}

function Write-LogCodeBlock {
    param(
        [string]$Title,
        [string]$Code,
        [string]$Language = "json"
    )
    
    if (-not $script:LogFilePath) {
        return
    }
    
    $block = "`n**$Title**`n`n``````$Language`n$Code`n```````n`n"
    $block | Out-File -FilePath $script:LogFilePath -Encoding UTF8 -Append
    Write-Host $block
}

function Complete-MigrationLog {
    param(
        [switch]$Success,
        [string]$Summary = ""
    )
    
    if (-not $script:LogFilePath) {
        return
    }
    
    $duration = (Get-Date) - $script:LogStartTime
    $durationText = "{0:hh\:mm\:ss}" -f $duration
    
    $status = if ($Success) { "✅ **COMPLETED SUCCESSFULLY**" } else { "❌ **COMPLETED WITH ERRORS**" }
    
    $footer = @"

---

## Summary

$status

**Duration:** $durationText  
**Completed:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

"@
    
    if ($Summary) {
        $footer += "`n$Summary`n"
    }
    
    $footer | Out-File -FilePath $script:LogFilePath -Encoding UTF8 -Append
    
    Write-Host "`n$footer" -ForegroundColor $(if ($Success) { "Green" } else { "Red" })
    Write-Host "`n📄 Log saved to: $script:LogFilePath" -ForegroundColor Cyan
}

function Start-LogMonitor {
    param([string]$LogPath)
    
    if (-not $LogPath -and $script:LogFilePath) {
        $LogPath = $script:LogFilePath
    }
    
    if (-not $LogPath -or -not (Test-Path $LogPath)) {
        Write-Warning "Log file not found: $LogPath"
        return
    }
    
    Write-Host "📊 Monitoring log file: $LogPath" -ForegroundColor Cyan
    Write-Host "Press Ctrl+C to stop monitoring`n" -ForegroundColor Gray
    
    Get-Content -Path $LogPath -Wait
}

# Note: This file is dot-sourced, not imported as a module
# All functions are automatically available in the calling scope
# Export-ModuleMember is not needed (and would cause an error)

