#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================================================
# SSL/TLS Configuration
# ============================================================
# Force PowerShell to use TLS 1.2 and 1.3 for HTTPS connections
# This prevents "SSL connection could not be established" errors
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# Increase connection limits for better performance
[Net.ServicePointManager]::DefaultConnectionLimit = 100
[Net.ServicePointManager]::Expect100Continue = $false

# SSL Certificate Validation Bypass for Sandbox Environments
# This allows connections to sandbox environments with self-signed or mismatched certificates
try {
    add-type @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(
                ServicePoint svcPoint, X509Certificate certificate,
                WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
} catch {
    # Fallback: Use PowerShell's built-in SSL bypass
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
}

function Get-EnvVariables {
  param([string] $EnvFilePath)
  
  $envVars = @{}
  
  if (Test-Path $EnvFilePath) {
    Get-Content $EnvFilePath | ForEach-Object {
      if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $envVars[$matches[1].Trim()] = $matches[2].Trim()
      }
    }
  }
  
  return $envVars
}

function Read-JsonFile {
  param([Parameter(Mandatory)][string] $Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "Parameters file not found: $Path" }
  $params = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
  
  # Load .env file and merge credentials
  # Try to find .env file - check multiple possible locations
  $envFile = $null
  $possiblePaths = @(
    (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) ".env"),
    (Join-Path (Get-Location) ".env"),
    (Join-Path (Get-Location) "..\..\.env")
  )
  
  foreach ($testPath in $possiblePaths) {
    if (Test-Path $testPath) {
      $envFile = $testPath
      break
    }
  }
  
  if ($envFile -and (Test-Path $envFile)) {
    $envVars = Get-EnvVariables -EnvFilePath $envFile
    
    # Add or merge Username and ApiToken from .env
    if ($params.PSObject.Properties['SourceEnvironment']) {
      if (-not $params.SourceEnvironment.PSObject.Properties['Username']) {
        $params.SourceEnvironment | Add-Member -MemberType NoteProperty -Name 'Username' -Value $envVars['USERNAME'] -Force
      } elseif (-not $params.SourceEnvironment.Username -and $envVars['USERNAME']) {
        $params.SourceEnvironment.Username = $envVars['USERNAME']
      }
      
      if (-not $params.SourceEnvironment.PSObject.Properties['ApiToken']) {
        $params.SourceEnvironment | Add-Member -MemberType NoteProperty -Name 'ApiToken' -Value $envVars['JIRA_API_TOKEN'] -Force
      } elseif (-not $params.SourceEnvironment.ApiToken -and $envVars['JIRA_API_TOKEN']) {
        $params.SourceEnvironment.ApiToken = $envVars['JIRA_API_TOKEN']
      }
    }
    
    if ($params.PSObject.Properties['TargetEnvironment']) {
      if (-not $params.TargetEnvironment.PSObject.Properties['Username']) {
        $params.TargetEnvironment | Add-Member -MemberType NoteProperty -Name 'Username' -Value $envVars['USERNAME'] -Force
      } elseif (-not $params.TargetEnvironment.Username -and $envVars['USERNAME']) {
        $params.TargetEnvironment.Username = $envVars['USERNAME']
      }
      
      if (-not $params.TargetEnvironment.PSObject.Properties['ApiToken']) {
        $params.TargetEnvironment | Add-Member -MemberType NoteProperty -Name 'ApiToken' -Value $envVars['JIRA_API_TOKEN'] -Force
      } elseif (-not $params.TargetEnvironment.ApiToken -and $envVars['JIRA_API_TOKEN']) {
        $params.TargetEnvironment.ApiToken = $envVars['JIRA_API_TOKEN']
      }
    }
    
    # Add or merge Confluence settings from .env
    if (-not $params.PSObject.Properties['ConfluenceEnvironment']) {
      $params | Add-Member -MemberType NoteProperty -Name 'ConfluenceEnvironment' -Value ([PSCustomObject]@{}) -Force
    }
    
    if (-not $params.ConfluenceEnvironment.PSObject.Properties['BaseUrl']) {
      $params.ConfluenceEnvironment | Add-Member -MemberType NoteProperty -Name 'BaseUrl' -Value $envVars['CONFLUENCE_BASE_URL'] -Force
    } elseif (-not $params.ConfluenceEnvironment.BaseUrl -and $envVars['CONFLUENCE_BASE_URL']) {
      $params.ConfluenceEnvironment.BaseUrl = $envVars['CONFLUENCE_BASE_URL']
    }
    
    if (-not $params.ConfluenceEnvironment.PSObject.Properties['SpaceKey']) {
      $params.ConfluenceEnvironment | Add-Member -MemberType NoteProperty -Name 'SpaceKey' -Value $envVars['CONFLUENCE_SPACE_KEY'] -Force
    } elseif (-not $params.ConfluenceEnvironment.SpaceKey -and $envVars['CONFLUENCE_SPACE_KEY']) {
      $params.ConfluenceEnvironment.SpaceKey = $envVars['CONFLUENCE_SPACE_KEY']
    }
    
    if (-not $params.ConfluenceEnvironment.PSObject.Properties['Username']) {
      $params.ConfluenceEnvironment | Add-Member -MemberType NoteProperty -Name 'Username' -Value $envVars['CONFLUENCE_USERNAME'] -Force
    } elseif (-not $params.ConfluenceEnvironment.Username -and $envVars['CONFLUENCE_USERNAME']) {
      $params.ConfluenceEnvironment.Username = $envVars['CONFLUENCE_USERNAME']
    }
    
    if (-not $params.ConfluenceEnvironment.PSObject.Properties['ApiToken']) {
      $params.ConfluenceEnvironment | Add-Member -MemberType NoteProperty -Name 'ApiToken' -Value $envVars['CONFLUENCE_API_TOKEN'] -Force
    } elseif (-not $params.ConfluenceEnvironment.ApiToken -and $envVars['CONFLUENCE_API_TOKEN']) {
      $params.ConfluenceEnvironment.ApiToken = $envVars['CONFLUENCE_API_TOKEN']
    }
    
    # Add or merge UserMapping ProjectLeadEmail
    if ($params.PSObject.Properties['UserMapping']) {
      if (-not $params.UserMapping.PSObject.Properties['ProjectLeadEmail']) {
        $params.UserMapping | Add-Member -MemberType NoteProperty -Name 'ProjectLeadEmail' -Value $envVars['FALLBACK_PROJECT_LEAD_EMAIL'] -Force
      } elseif (-not $params.UserMapping.ProjectLeadEmail -and $envVars['FALLBACK_PROJECT_LEAD_EMAIL']) {
        $params.UserMapping.ProjectLeadEmail = $envVars['FALLBACK_PROJECT_LEAD_EMAIL']
      }
    }
  }
  
  return $params
}

function New-BasicAuthHeader {
  param([Parameter(Mandatory)][string] $Email,[Parameter(Mandatory)][string] $ApiToken)
  $pair='{0}:{1}' -f $Email,$ApiToken
  $b64=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  @{ Authorization="Basic $b64"; 'Content-Type'='application/json'; Accept='application/json' }
}

function Invoke-JiraWithRetry {
  <#
  .SYNOPSIS
    Invokes a REST method with retry logic for transient failures
  .DESCRIPTION
    Handles SSL errors, timeouts, and rate limiting with exponential backoff
  #>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][Microsoft.PowerShell.Commands.WebRequestMethod] $Method,
    [Parameter(Mandatory)][string] $Uri,
    [Parameter(Mandatory)][hashtable] $Headers,
    [Parameter()] $Body,
    [Parameter()][string] $ContentType = "application/json",
    [Parameter()][int] $MaxRetries = 3,
    [Parameter()][int] $TimeoutSec = 30
  )
  
  $attempt = 0
  $maxAttempts = $MaxRetries + 1
  
  # Honor global DryRun: log and simulate
  if ($script:DryRun) {
    Write-Host ("[DRYRUN] {0} {1}" -f $Method, $Uri) -ForegroundColor Yellow
    return $null
  }

  while ($attempt -lt $maxAttempts) {
    $attempt++
    
    try {
      $params = @{
        Method = $Method
        Uri = $Uri
        Headers = $Headers
        TimeoutSec = $TimeoutSec
        ErrorAction = 'Stop'
      }
      
      if ($Body) {
        $params.Body = $Body
        $params.ContentType = $ContentType
      }
      
      $response = Invoke-RestMethod @params
      return $response
      
    } catch {
      $errorMessage = $_.Exception.Message
      $isLastAttempt = ($attempt -eq $maxAttempts)
      
      # Check if this is a retryable error
      $isRetryable = $false
      $retryableErrors = @(
        'SSL connection could not be established',
        'The underlying connection was closed',
        'The operation has timed out',
        'Unable to connect to the remote server',
        'The remote name could not be resolved',
        'A connection attempt failed',
        '429',  # Rate limiting
        '502',  # Bad Gateway
        '503',  # Service Unavailable
        '504'   # Gateway Timeout
      )
      
      foreach ($retryableError in $retryableErrors) {
        if ($errorMessage -like "*$retryableError*") {
          $isRetryable = $true
          break
        }
      }
      
      if ($isRetryable -and -not $isLastAttempt) {
        # Exponential backoff: 2^attempt seconds (2s, 4s, 8s)
        $waitTime = [Math]::Pow(2, $attempt)
        Write-Host "      ⚠️  Retryable error (attempt $attempt/$maxAttempts): $errorMessage" -ForegroundColor Yellow
        Write-Host "      ⏳ Waiting $waitTime seconds before retry..." -ForegroundColor Yellow
        Start-Sleep -Seconds $waitTime
      } else {
        # Non-retryable error or last attempt - throw it
        throw
      }
    }
  }
}

function Invoke-Jira {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string] $Method,
    [Parameter(Mandatory)][string] $BaseUrl,
    [Parameter(Mandatory)][string] $Path,
    [Parameter(Mandatory)][hashtable] $Headers,
    [Parameter()] $Body
  )
  $uri = ($BaseUrl.TrimEnd('/')) + '/' + $Path.TrimStart('/')
  if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body -and -not ($Body -is [string])) {
      $Body = ($Body | ConvertTo-Json -Depth 10)
  }
  
  # Use the retry wrapper (handles DryRun internally)
  Invoke-JiraWithRetry -Method $Method -Uri $uri -Headers $Headers -Body $Body -MaxRetries 3 -TimeoutSec 30
}

# Multipart upload helper honoring DryRun
function Invoke-JiraMultipartUpload {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $BaseUrl,
    [Parameter(Mandatory)][string] $Path,
    [Parameter(Mandatory)][hashtable] $Headers,
    [Parameter(Mandatory)][string] $FilePath
  )
  $uri = ($BaseUrl.TrimEnd('/')) + '/' + $Path.TrimStart('/')
  if ($script:DryRun) {
    Write-Host ("[DRYRUN] POST (multipart) {0} < {1}" -f $uri, $FilePath) -ForegroundColor Yellow
    return $null
  }
  $uploadHeaders = $Headers.Clone()
  $uploadHeaders.Remove('Content-Type')
  $uploadHeaders['X-Atlassian-Token'] = 'no-check'
  return Invoke-RestMethod -Method POST -Uri $uri -Headers $uploadHeaders -InFile $FilePath -ContentType 'multipart/form-data'
}

function EnsureDirectory { param([string] $Path) if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

function Write-StageReceipt {
  param([string] $OutDir,[string] $Stage,[hashtable] $Data)
  EnsureDirectory -Path $OutDir
  
  # Always include timing data if not already present
  # Use -not $Data['StartTime'] instead of ContainsKey for broader compatibility
  if (-not $Data['StartTime']) {
    if ($script:StepStartTime) {
      $Data['StartTime'] = $script:StepStartTime.ToString("o")
    } else {
      $Data['StartTime'] = (Get-Date).ToString("o")
    }
  }
  if (-not $Data['EndTime']) {
    $Data['EndTime'] = (Get-Date).ToString("o")
  }
  if (-not $Data['Duration']) {
    if ($script:StepStartTime) {
      $Data['Duration'] = [math]::Round(((Get-Date) - $script:StepStartTime).TotalSeconds, 2)
    }
  }
  
  # Write receipt file (for referencing by other scripts)
  $receiptFile = Join-Path $OutDir ("{0}_receipt.json" -f $Stage)
  ($Data | ConvertTo-Json -Depth 8) | Out-File -FilePath $receiptFile -Encoding UTF8
  
  Write-Host "✅ Receipt written: $receiptFile"
  
  if ($Data['Duration']) {
    Write-Host "⏱️  Step Duration: $($Data['Duration']) seconds" -ForegroundColor Cyan
  }
}

# ============================================================
# ISSUES LOGGING - Track warnings, errors, and actions needed
# ============================================================

# Initialize timing and logging for steps
$script:StepIssuesLog = @()
$script:CurrentStepName = $null
$script:IssuesLogDir = $null
$script:StepStartTime = $null

function Start-MigrationStep {
  $script:StepStartTime = Get-Date
}

function Initialize-IssuesLog {
  param(
    [Parameter(Mandatory)][string] $StepName,
    [Parameter(Mandatory)][string] $OutDir
  )
  
  $script:CurrentStepName = $StepName
  $script:IssuesLogDir = $OutDir
  $script:StepIssuesLog = @()
  
  EnsureDirectory -Path $OutDir
}

function Write-IssueLog {
  param(
    [Parameter(Mandatory)][ValidateSet('Error','Warning','Info','Action')][string] $Type,
    [Parameter(Mandatory)][string] $Message,
    [string] $IssueKey = $null,
    [string] $Category = $null,
    [string] $ActionUrl = $null,
    [hashtable] $Details = @{}
  )
  
  $entry = @{
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Type = $Type
    Category = if ($Category) { $Category } else { "General" }
    Message = $Message
    IssueKey = $IssueKey
    ActionUrl = $ActionUrl
    Details = $Details
  }
  
  $script:StepIssuesLog += $entry
}

function Save-IssuesLog {
  param([string] $StepName = $script:CurrentStepName)
  
  if (-not $script:IssuesLogDir -or -not $script:StepIssuesLog -or $script:StepIssuesLog.Count -eq 0) {
    return
  }
  
  $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
  
  # Save step-specific issues log
  $stepLogFile = Join-Path $script:IssuesLogDir "${timestamp}-${StepName}_issues.json"
  $script:StepIssuesLog | ConvertTo-Json -Depth 5 | Out-File -FilePath $stepLogFile -Encoding UTF8
  
  # Also create a readable text version
  $stepLogText = Join-Path $script:IssuesLogDir "${timestamp}-${StepName}_issues.txt"
  $textContent = @()
  $textContent += "=" * 80
  $textContent += "ISSUES LOG: $StepName"
  $textContent += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $textContent += "=" * 80
  $textContent += ""
  
  # Group by type
  $errors = @($script:StepIssuesLog | Where-Object { $_.Type -eq 'Error' })
  $warnings = @($script:StepIssuesLog | Where-Object { $_.Type -eq 'Warning' })
  $actions = @($script:StepIssuesLog | Where-Object { $_.Type -eq 'Action' })
  $info = @($script:StepIssuesLog | Where-Object { $_.Type -eq 'Info' })
  
  if ($errors -and $errors.Count -gt 0) {
    $textContent += "=== ERRORS ($($errors.Count)) ==="
    $textContent += ""
    foreach ($item in $errors) {
      $textContent += "[$($item.Timestamp)] $($item.Category)"
      if ($item.IssueKey) { $textContent += "  Issue: $($item.IssueKey)" }
      $textContent += "  $($item.Message)"
      if ($item.ActionUrl) { $textContent += "  Action: $($item.ActionUrl)" }
      if ($item.Details -and $item.Details.Count -gt 0) {
        foreach ($key in $item.Details.Keys) {
          $textContent += "    - ${key}: $($item.Details[$key])"
        }
      }
      $textContent += ""
    }
  }
  
  if ($warnings -and $warnings.Count -gt 0) {
    $textContent += "=== WARNINGS ($($warnings.Count)) ==="
    $textContent += ""
    foreach ($item in $warnings) {
      $textContent += "[$($item.Timestamp)] $($item.Category)"
      if ($item.IssueKey) { $textContent += "  Issue: $($item.IssueKey)" }
      $textContent += "  $($item.Message)"
      if ($item.ActionUrl) { $textContent += "  Action: $($item.ActionUrl)" }
      if ($item.Details -and $item.Details.Count -gt 0) {
        foreach ($key in $item.Details.Keys) {
          $textContent += "    - ${key}: $($item.Details[$key])"
        }
      }
      $textContent += ""
    }
  }
  
  if ($actions -and $actions.Count -gt 0) {
    $textContent += "=== ACTIONS REQUIRED ($($actions.Count)) ==="
    $textContent += ""
    foreach ($item in $actions) {
      $textContent += "[$($item.Timestamp)] $($item.Category)"
      if ($item.IssueKey) { $textContent += "  Issue: $($item.IssueKey)" }
      $textContent += "  $($item.Message)"
      if ($item.ActionUrl) { $textContent += "  🔗 $($item.ActionUrl)" }
      if ($item.Details -and $item.Details.Count -gt 0) {
        foreach ($key in $item.Details.Keys) {
          $textContent += "    - ${key}: $($item.Details[$key])"
        }
      }
      $textContent += ""
    }
  }
  
  if ($info -and $info.Count -gt 0) {
    $textContent += "=== INFORMATION ($($info.Count)) ==="
    $textContent += ""
    foreach ($item in $info) {
      $textContent += "[$($item.Timestamp)] $($item.Category)"
      if ($item.IssueKey) { $textContent += "  Issue: $($item.IssueKey)" }
      $textContent += "  $($item.Message)"
      $textContent += ""
    }
  }
  
  $textContent += "=" * 80
  $textContent += "SUMMARY"
  $textContent += "=" * 80
  $textContent += "Errors: $($errors.Count)"
  $textContent += "Warnings: $($warnings.Count)"
  $textContent += "Actions Required: $($actions.Count)"
  $textContent += "Informational: $($info.Count)"
  $textContent += "=" * 80
  
  $textContent -join "`n" | Out-File -FilePath $stepLogText -Encoding UTF8
  
  # Append to master log
  $masterLogFile = Join-Path $script:IssuesLogDir "MASTER_ISSUES_LOG.txt"
  $masterContent = @()
  $masterContent += ""
  $masterContent += "=" * 80
  $masterContent += "STEP: $StepName - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  $masterContent += "=" * 80
  if ($errors -and $errors.Count -gt 0) { $masterContent += "❌ ERRORS: $($errors.Count)" }
  if ($warnings -and $warnings.Count -gt 0) { $masterContent += "⚠️  WARNINGS: $($warnings.Count)" }
  if ($actions -and $actions.Count -gt 0) { $masterContent += "🔧 ACTIONS: $($actions.Count)" }
  $masterContent += ""
  
  # Add top issues to master log
  if ($errors -and $errors.Count -gt 0) {
    $masterContent += "Top Errors:"
    foreach ($item in ($errors | Select-Object -First 5)) {
      $masterContent += "  • $($item.Category): $($item.Message)"
      if ($item.IssueKey) { $masterContent += "    Issue: $($item.IssueKey)" }
    }
    if ($errors.Count -gt 5) {
      $masterContent += "  ... and $($errors.Count - 5) more errors (see $stepLogText)"
    }
    $masterContent += ""
  }
  
  if ($warnings -and $warnings.Count -gt 0) {
    $masterContent += "Top Warnings:"
    foreach ($item in ($warnings | Select-Object -First 5)) {
      $masterContent += "  • $($item.Category): $($item.Message)"
      if ($item.IssueKey) { $masterContent += "    Issue: $($item.IssueKey)" }
    }
    if ($warnings.Count -gt 5) {
      $masterContent += "  ... and $($warnings.Count - 5) more warnings (see $stepLogText)"
    }
    $masterContent += ""
  }
  
  if ($actions -and $actions.Count -gt 0) {
    $masterContent += "Actions Required:"
    foreach ($item in $actions) {
      $masterContent += "  🔧 $($item.Message)"
      if ($item.ActionUrl) { $masterContent += "     🔗 $($item.ActionUrl)" }
    }
    $masterContent += ""
  }
  
  $masterContent += "Detailed log: $stepLogText"
  $masterContent += ""
  
  $masterContent -join "`n" | Out-File -FilePath $masterLogFile -Encoding UTF8 -Append
  
  Write-Host ""
  Write-Host "📋 Issues logged to: $stepLogText" -ForegroundColor Cyan
  if (($errors -and $errors.Count -gt 0) -or ($warnings -and $warnings.Count -gt 0) -or ($actions -and $actions.Count -gt 0)) {
    Write-Host "📋 Master log updated: $masterLogFile" -ForegroundColor Cyan
  }
}

function Expand-Template {
  param([Parameter(Mandatory)][string] $Template, [Parameter(Mandatory)] $Params)
  $map = @{
    "{TargetProjectKey}"  = $Params.TargetEnvironment.ProjectKey
    "{TargetProjectName}" = $Params.TargetEnvironment.ProjectName
    "{SourceProjectKey}"  = $Params.ProjectKey
  }
  $out = $Template
  foreach ($k in $map.Keys) { $out = $out -replace [regex]::Escape($k), [regex]::Escape($map[$k]) }
  return $out
}

# =============================================================================
# CENTRALIZED LOGGING - Redacts tokens and provides consistent logging
# =============================================================================
function Write-VerboseLog {
    param(
        [Parameter(Mandatory)][string] $Message,
        [string] $Color = "White"
    )
    
    # Redact API tokens and sensitive data
    $redactedMessage = $Message
    $redactedMessage = $redactedMessage -replace 'api[_-]?token["\s]*[:=]["\s]*[a-zA-Z0-9_-]+', 'api-token=***REDACTED***'
    $redactedMessage = $redactedMessage -replace 'password["\s]*[:=]["\s]*[^"\s]+', 'password=***REDACTED***'
    $redactedMessage = $redactedMessage -replace 'token["\s]*[:=]["\s]*[a-zA-Z0-9_-]+', 'token=***REDACTED***'
    
    # Truncate long messages for readability
    if ($redactedMessage.Length -gt 200) {
        $redactedMessage = $redactedMessage.Substring(0, 197) + "..."
    }
    
    Write-Host $redactedMessage -ForegroundColor $Color
}

# =============================================================================
# USER ACTIVITY - Gather activity metrics for a user within a project
# =============================================================================
function Get-UserActivity {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string] $Base,
    [Parameter(Mandatory)][hashtable] $Hdr,
    [Parameter(Mandatory)][string] $ProjectKey,
    [Parameter(Mandatory)][string] $AccountId
  )

  # Basic return shape
  $result = [PSCustomObject]@{
    Roles = @()
    AssignedIssues = 0
    ReportedIssues = 0
    CommentedIssues = 0
    WatchedIssues = 0
    VotedIssues = 0
    WorklogIssues = 0
    TotalActivityScore = 0
  }

  if (-not $AccountId) { return $result }

  try {
    # 1) Roles in the project - use user/assignable/search or project role membership is already handled elsewhere
    # We'll use search to find issues where user appears in roles (assignee, reporter, comment author, worklog author)

    # Helper to run JQL with paging
    $run_jql = {
      param([string] $jql)
      $startAt = 0
      $maxResults = 50
      $total = 1
      $items = @()
      while ($startAt -lt $total) {
        $path = "rest/api/3/search?jql=$([uri]::EscapeDataString($jql))&startAt=$startAt&maxResults=$maxResults&fields=key,comment,worklog"
        $resp = Invoke-Jira -Method 'GET' -BaseUrl $Base -Path $path -Headers $Hdr
        if (-not $resp) { break }
        $total = if ($resp.total) { [int]$resp.total } else { 0 }
        if ($resp.issues) { $items += $resp.issues }
        $startAt += $maxResults
      }
      return $items
    }

    # Assigned issues
  $assignedJql = "project = $ProjectKey AND assignee = '$AccountId'"
  $assigned = & $run_jql $assignedJql
    $result.AssignedIssues = ($assigned | Measure-Object).Count

    # Reported issues
  $reportedJql = "project = $ProjectKey AND reporter = '$AccountId'"
  $reported = & $run_jql $reportedJql
    $result.ReportedIssues = ($reported | Measure-Object).Count

    # Issues with worklogs by user
  $worklogJql = "project = $ProjectKey AND worklogAuthor = '$AccountId'"
  $worklog = & $run_jql $worklogJql
    $result.WorklogIssues = ($worklog | Measure-Object).Count

    # Issues where user commented - Jira JQL doesn't directly support comment author in all instances; use search by text and then inspect comments
    $commented = @()
    $candidateIssues = @()
    $jqlForComments = "project = $ProjectKey AND (comment ~ '$AccountId' OR comment ~ '$($AccountId.Split(':')[-1])')"
    try {
      $candidateIssues = & $run_jql $jqlForComments
      foreach ($iss in $candidateIssues) {
        if ($iss.fields.comment -and $iss.fields.comment.comments) {
          foreach ($c in $iss.fields.comment.comments) {
            if ($c.author -and ($c.author.accountId -eq $AccountId -or $c.author.name -eq $AccountId)) { $commented += $iss }
          }
        }
      }
    } catch { }
    $result.CommentedIssues = ($commented | Select-Object -Unique).Count

    # Votes - Jira server/cloud differences; try the votes endpoint per issue list
    $votedCount = 0
    $votedIssues = @()
    $issuesToCheck = @($assigned + $reported + $worklog + $candidateIssues) | Select-Object -Unique
    foreach ($iss in $issuesToCheck) {
      try {
        $issueKey = if ($iss.key) { $iss.key } else { $iss.fields.key }
        if (-not $issueKey) { continue }
        $path = "rest/api/3/issue/$issueKey?votes"
        $issueDetail = Invoke-Jira -Method 'GET' -BaseUrl $Base -Path $path -Headers $Hdr
        if ($issueDetail -and $issueDetail.fields -and $issueDetail.fields.votes -and $issueDetail.fields.votes.voters) {
          foreach ($v in $issueDetail.fields.votes.voters) {
            if ($v.accountId -eq $AccountId) {
              $votedCount++
              $votedIssues += $issueKey
              break
            }
          }
        }
      } catch { }
    }
    $result.VotedIssues = ($votedIssues | Select-Object -Unique).Count

    # Watched issues - Jira Cloud does not expose watchers for privacy; attempt if available
    $watchedCount = 0
    try {
      foreach ($iss in $issuesToCheck) {
        $issueKey = if ($iss.key) { $iss.key } else { $iss.fields.key }
        if (-not $issueKey) { continue }
        try {
          $path = "rest/api/3/issue/$issueKey/watchers"
          $watchers = Invoke-Jira -Method 'GET' -BaseUrl $Base -Path $path -Headers $Hdr
          if ($watchers -and $watchers.watchers) {
            foreach ($w in $watchers.watchers) {
              if ($w.accountId -eq $AccountId) { $watchedCount++; break }
            }
          }
        } catch { }
      }
    } catch { }
    $result.WatchedIssues = $watchedCount

    # Roles - get roles via project roles API and list any role memberships containing this accountId
    try {
      $rolesPath = "rest/api/3/project/$ProjectKey/role"
      $roles = Invoke-Jira -Method 'GET' -BaseUrl $Base -Path $rolesPath -Headers $Hdr
      if ($roles) {
        foreach ($rName in $roles.PSObject.Properties.Name) {
          $rUrl = $roles.$rName
          try {
            $rDetail = Invoke-Jira -Method 'GET' -BaseUrl $Base -Path ($rUrl -replace '^https?://[^/]+/','') -Headers $Hdr
            if ($rDetail.actors) {
              foreach ($a in $rDetail.actors) {
                if ($a.type -eq 'atlassian-user-role-actor') {
                  $acct = $null
                  if ($a.PSObject.Properties.Name -contains 'actorUser' -and $a.actorUser -and $a.actorUser.PSObject.Properties.Name -contains 'accountId') { $acct = $a.actorUser.accountId }
                  elseif ($a.PSObject.Properties.Name -contains 'accountId') { $acct = $a.accountId }
                  if ($acct -and $acct -eq $AccountId) { $result.Roles += $rName }
                }
              }
            }
          } catch { }
        }
      }
    } catch { }

    # Compute a simple activity score (weighted)
    $score = 0
    $score += ($result.AssignedIssues * 1.5)
    $score += ($result.ReportedIssues * 1.2)
    $score += ($result.CommentedIssues * 1.0)
    $score += ($result.WorklogIssues * 1.8)
    $score += ($result.VotedIssues * 0.5)
    $score += ($result.WatchedIssues * 0.3)
    $result.TotalActivityScore = [Math]::Round($score,2)

    # Deduplicate roles
    $result.Roles = ($result.Roles | Select-Object -Unique)

  } catch {
    # On any failure, return defaults
    return $result
  }

  return $result
}
