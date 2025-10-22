# _terminal_logging.ps1 - Complete Terminal Output Logging for Migration Scripts
#
# This module captures ALL terminal output and writes it to markdown files
# with the naming convention: XX_StepName_Log.md

# Global variables for transcript management
$script:TranscriptPath = ""
$script:TranscriptStarted = $false
$script:StepName = ""
$script:OutDir = ""

function Start-TerminalLog {
    param(
        [string]$StepName,
        [string]$OutDir,
        [string]$ProjectKey = ""
    )
    
    $script:StepName = $StepName
    $script:OutDir = $OutDir
    
    # Create log file path
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $logFileName = "${StepName}_Log.md"
    $script:TranscriptPath = Join-Path $OutDir $logFileName
    
    # Ensure output directory exists
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    
    # Create markdown header
    $header = @"
# Terminal Output Log: $StepName

**Project:** $ProjectKey  
**Started:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
**Log File:** ``$script:TranscriptPath``

---

## Terminal Output

``````text
"@
    
    $header | Out-File -FilePath $script:TranscriptPath -Encoding UTF8 -Force
    
    # Start PowerShell transcript
    $transcriptFile = Join-Path $OutDir "${StepName}_transcript.txt"
    Start-Transcript -Path $transcriptFile -Append
    
    $script:TranscriptStarted = $true
    
    Write-Host "📝 Terminal logging started: $script:TranscriptPath" -ForegroundColor Cyan
    Write-Host "📄 Transcript file: $transcriptFile" -ForegroundColor Gray
    
    return $script:TranscriptPath
}

function Stop-TerminalLog {
    param(
        [switch]$Success = $true,
        [string]$Summary = ""
    )
    
    if (-not $script:TranscriptStarted) {
        Write-Warning "Terminal logging was not started"
        return
    }
    
    # Stop transcript
    Stop-Transcript
    
    # Read transcript content
    $transcriptFile = Join-Path $script:OutDir "${script:StepName}_transcript.txt"
    if (Test-Path $transcriptFile) {
        $transcriptContent = Get-Content -Path $transcriptFile -Raw
        
        # Append transcript content to markdown file
        $transcriptContent | Out-File -FilePath $script:TranscriptPath -Encoding UTF8 -Append
        
        # Add closing code block and footer
        $footer = @"

``````

---

## Summary

$(if ($Success) { "✅ **COMPLETED SUCCESSFULLY**" } else { "❌ **COMPLETED WITH ERRORS**" })

**Completed:** $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

$(if ($Summary) { "`n$Summary`n" })

**Transcript File:** ``$transcriptFile``
"@
        
        $footer | Out-File -FilePath $script:TranscriptPath -Encoding UTF8 -Append
        
        # Clean up transcript file (optional - keep for debugging)
        # Remove-Item -Path $transcriptFile -Force
    }
    
    $script:TranscriptStarted = $false
    $finalLogPath = $script:TranscriptPath
    $script:TranscriptPath = ""
    
    Write-Host "📝 Terminal logging completed: $finalLogPath" -ForegroundColor Green
}

function Write-TerminalLog {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    
    # This function can be used to add custom entries to the log
    # while transcript is running
    if ($script:TranscriptStarted -and $script:TranscriptPath) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        $entry = "[$timestamp] [$Level] $Message"
        
        # Write to console
        Write-Host $entry
        
        # Also write to a separate log file for structured entries
        $structuredLog = Join-Path $script:OutDir "${script:StepName}_structured.log"
        $entry | Out-File -FilePath $structuredLog -Encoding UTF8 -Append
    }
}

# Cleanup function for error handling
function Stop-TerminalLogOnError {
    param([string]$ErrorMessage = "Script terminated with error")
    
    if ($script:TranscriptStarted) {
        Write-Host "❌ $ErrorMessage" -ForegroundColor Red
        Stop-TerminalLog -Success:$false -Summary "Script terminated with error: $ErrorMessage"
    }
}

# Note: Functions are available in calling scope since this is dot-sourced
# Export-ModuleMember is not needed and would cause an error
