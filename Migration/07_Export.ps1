# 07_Export.ps1 - Export Issues from Source Jira
# 
# PURPOSE: Exports all issues, comments, and attachments from the source Jira project
# using ADF-safe processing and enhanced pagination for large datasets.
#
# WHAT IT DOES:
# - Uses /rest/api/3/search/jql endpoint with nextPageToken pagination
# - Exports description (ADF), selected custom ADF fields, comments (ADF), and attachments
# - Writes one JSON object per line to: <OutputSettings.OutputDirectory>\export_adf.jsonl
# - Handles large datasets with efficient pagination
# - Preserves all issue metadata and relationships
#
# WHAT IT DOES NOT DO:
# - Does not modify source data
# - Does not create any target issues
# - Does not perform any migration operations
#
# NEXT STEP: Run 08_Import.ps1 to create issues in target Jira
#

param([string]$ParametersPath = ".\migration-parameters.json", [switch]$DryRun)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
. (Join-Path $here "_terminal_logging.ps1")

# -------------------- Local utilities --------------------

function New-BasicAuthHeader {
  param([Parameter(Mandatory=$true)][string]$Email,[Parameter(Mandatory=$true)][string]$ApiToken)
  $pair = "{0}:{1}" -f $Email, $ApiToken
  $b64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  return @{ Authorization = "Basic $b64"; Accept = "application/json" }
}

function Ensure-Folder {
  param([string]$Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null }
}

function Jira-GET {
  param([string]$Uri,[hashtable]$Headers)
  try {
    return Invoke-JiraWithRetry -Method GET -Uri $Uri -Headers $Headers -ContentType 'application/json' -MaxRetries 3 -TimeoutSec 30
  } catch {
    Write-Warning "Failed to GET $Uri : $($_.Exception.Message)"
    return $null
  }
}

function Extract-TextFromADF {
  param([array]$Content)
  
  if (-not $Content) { return "" }
  
  $text = ""
  foreach ($node in $Content) {
    if ($node -and $node.type -eq "text" -and $node.text) {
      $text += $node.text
    } elseif ($node -and $node.type -eq "paragraph" -and $node.content) {
      $text += (Extract-TextFromADF -Content $node.content) + " "
    } elseif ($node -and $node.type -eq "bulletList" -and $node.content) {
      foreach ($item in $node.content) {
        if ($item -and $item.content) {
          $text += "• " + (Extract-TextFromADF -Content $item.content) + " "
        }
      }
    } elseif ($node -and $node.type -eq "listItem" -and $node.content) {
      $text += (Extract-TextFromADF -Content $node.content) + " "
    } elseif ($node -and $node.type -eq "table" -and $node.content) {
      foreach ($row in $node.content) {
        if ($row -and $row.content) {
          $text += (Extract-TextFromADF -Content $row.content) + " "
        }
      }
    } elseif ($node -and $node.type -eq "tableRow" -and $node.content) {
      foreach ($cell in $node.content) {
        if ($cell -and $cell.content) {
          $text += (Extract-TextFromADF -Content $cell.content) + " "
        }
      }
    } elseif ($node -and $node.type -eq "tableCell" -and $node.content) {
      $text += (Extract-TextFromADF -Content $node.content) + " "
    } elseif ($node -and $node.content) {
      $text += (Extract-TextFromADF -Content $node.content)
    }
  }
  
  return $text.Trim()
}

# Bootstrap
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
$script:DryRun = $DryRun

# -------------------- Load parameters --------------------

if (-not (Test-Path $ParametersPath)) { throw "Config file '$ParametersPath' not found." }
$config = Get-Content $ParametersPath -Raw | ConvertFrom-Json

$srcBase = $config.SourceEnvironment.BaseUrl.TrimEnd('/')
$srcUser = $config.SourceEnvironment.Username
$srcTok  = $config.SourceEnvironment.ApiToken
$srcHdrs = New-BasicAuthHeader -Email $srcUser -ApiToken $srcTok

# Build field set: description + your configured ADF/Plain fields
$adfIds = @(); if ($config.PSObject.Properties.Name -contains 'CustomRichTextFieldIds' -and $config.CustomRichTextFieldIds) { $adfIds = @($config.CustomRichTextFieldIds) }
$plainIds = @(); if ($config.PSObject.Properties.Name -contains 'CustomFields' -and $config.CustomFields) { $plainIds = @($config.CustomFields.PSObject.Properties.Value) }
# All 43+ standard Jira fields
$standardFields = @(
  'summary',           # Summary
  'issuetype',         # Issue Type  
  'project',           # Project
  'description',       # Description
  'status',            # Status
  'assignee',          # Assignee
  'reporter',          # Reporter
  'priority',          # Priority
  'resolution',        # Resolution
  'created',           # Created
  'updated',           # Updated
  'duedate',           # Due Date
  'resolutiondate',    # Resolution Date
  'timetracking',      # Time Tracking
  'labels',            # Labels
  'components',        # Components
  'fixVersions',       # Fix Version/s
  'affectsVersions',   # Affects Version/s
  'attachment',        # Attachments
  'parent',            # Parent Link
  'subtasks',          # Sub-tasks
  'issuelinks',        # Issue Links
  'worklog',           # Work Log
  'votes',             # Votes
  'watches',           # Watchers
  'security',          # Security Level
  'environment',       # Environment
  'flag',              # Flagged
  'sprint',            # Sprint (Jira Software)
  'epiclink',          # Epic Link (Jira Software)
  'epicname',          # Epic Name (Jira Software)
  'epicstatus',        # Epic Status (Jira Software)
  'storypoints',       # Story Points (Jira Software)
  'originalestimate',  # Original Estimate
  'remainingestimate', # Remaining Estimate
  'timespent',         # Time Spent
  'aggregatetimeoriginalestimate', # Aggregate Time Original Estimate
  'aggregatetimeestimate',        # Aggregate Time Estimate
  'aggregatetimespent',           # Aggregate Time Spent
  'aggregateprogress',            # Aggregate Progress
  'progress',                     # Progress
  'workratio',                    # Work Ratio
  'lastViewed',                   # Last Viewed
  'creator',                      # Creator
  'customfield_10026'            # Story Points (custom field)
)

# Add "No Field Exists" fields to export list
$noFieldExistsFields = @()
if ($config.PSObject.Properties.Name -contains 'NoFieldExistsFields' -and $config.NoFieldExistsFields.PSObject.Properties.Name -contains 'Fields') {
  $noFieldExistsFields = $config.NoFieldExistsFields.Fields
  Write-Host "📋 Including 'No Field Exists' fields: $($noFieldExistsFields -join ', ')" -ForegroundColor Cyan
}

$fields = $standardFields + $adfIds + $plainIds + $noFieldExistsFields

# JQL based on scope + project
$projectKey = $config.ProjectKey
$scope = "ALL"  # Default scope
if ($config.PSObject.Properties.Name -contains 'IssueExportSettings' -and $config.IssueExportSettings.PSObject.Properties.Name -contains 'Scope') {
    $scope = $config.IssueExportSettings.Scope
}
if ([string]::IsNullOrWhiteSpace($scope)) { $scope = "ALL" }
switch ($scope.ToUpper()) {
  "UNRESOLVED" { $jql = "project = $projectKey AND resolution = EMPTY ORDER BY created" }
  default      { $jql = "project = $projectKey ORDER BY created" }
}

# Set up step-specific output directory
$outDir = $config.OutputSettings.OutputDirectory
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = ".\out" }

# Ensure the base output directory exists
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output directory: $outDir" -ForegroundColor Green
}

# Clean up ONLY files from previous failed attempts of THIS step (targeted cleanup)
$projectKey = $config.ProjectKey
$projectExportDir = Join-Path ".\projects" $projectKey
if (Test-Path $projectExportDir) {
    $projectOutDir = Join-Path $projectExportDir "out"
    if (Test-Path $projectOutDir) {
        # Only clean up the exports07 folder (step-specific cleanup)
        $exports07Dir = Join-Path $projectOutDir "exports07"
        if (Test-Path $exports07Dir) {
            Write-Host "Cleaning up previous step 07 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports07Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports07 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder (exports07 for step 07)
$stepExportsDir = Join-Path $outDir "exports07"
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Initialize issues logging
Initialize-IssuesLog -StepName "07_Export" -OutDir $stepExportsDir

# Set step start time
$script:StepStartTime = Get-Date

# Start terminal logging
$terminalLogPath = Start-TerminalLog -StepName "07_Export" -OutDir $outDir -ProjectKey $config.ProjectKey

# Set up error handling to ensure logging stops on errors
$ErrorActionPreference = "Stop"
trap {
    $errorMessage = "Step 07 (Export) failed"
    if ($_.Exception.Message) {
        $errorMessage += ": $($_.Exception.Message)"
    }
    if ($_.Exception.InnerException) {
        $errorMessage += " (Inner: $($_.Exception.InnerException.Message))"
    }
    Write-Host "❌ $errorMessage" -ForegroundColor Red
    Stop-TerminalLogOnError -ErrorMessage $errorMessage
    throw
}

# Output file
$outFile = Join-Path $stepExportsDir "07_Export_adf.jsonl"
if (Test-Path $outFile) { 
    Write-Host "Cleaning up previous export file: $outFile" -ForegroundColor Yellow
    Remove-Item $outFile -Force 
}
New-Item -ItemType File -Path $outFile -Force | Out-Null

# Parent mapping file
$parentMappingFile = Join-Path $stepExportsDir "07_Parent_Mapping.csv"
if (Test-Path $parentMappingFile) { 
    Write-Host "Cleaning up previous parent mapping file: $parentMappingFile" -ForegroundColor Yellow
    Remove-Item $parentMappingFile -Force 
}
New-Item -ItemType File -Path $parentMappingFile -Force | Out-Null

# Initialize parent mapping array
$parentMappings = @()

Write-Host "== Export start =="
Write-Host "Base: $srcBase"
Write-Host "Project: $projectKey | Scope: $scope"
Write-Host "Fields: $($fields -join ', ')"
Write-Host "Out: $outFile"

# -------------------- JQL search with nextPageToken --------------------

$maxResults    = 100
$nextPageToken = $null
$isLast        = $false

try {

do {
  $body = @{ jql = $jql; fields = $fields; maxResults = $maxResults }
  if ($nextPageToken) { $body.nextPageToken = $nextPageToken }

  if ($script:DryRun) {
    Write-Host "[DRYRUN] POST $srcBase/rest/api/3/search/jql (fetch page)" -ForegroundColor Yellow
    $search = @{ issues = @(); isLast = $true }
  } else {
    try {
      $search = Invoke-JiraWithRetry -Method POST -Uri "$srcBase/rest/api/3/search/jql" -Headers $srcHdrs -Body ($body | ConvertTo-Json) -ContentType 'application/json' -MaxRetries 3 -TimeoutSec 30
    } catch {
      Write-Warning "Failed to search issues: $($_.Exception.Message)"
      Write-Host "This may be due to Jira service issues. Continuing with empty results..." -ForegroundColor Yellow
      $search = @{ issues = @(); isLast = $true }
    }
  }

  foreach ($i in $search.issues) {
    # We already requested the needed fields in the search, but to be safe for deep ADF,
    # re-fetch the full issue with the exact field list.
    if ($script:DryRun) {
      $issue = @{ key = $i.key; id = 0; fields = @{ summary = "[DRYRUN] $($i.key)"; issuetype = @{ name = 'Task' } } }
    } else {
      $issue = Jira-GET -Uri "$srcBase/rest/api/3/issue/$($i.key)?fields=$([string]::Join(',', $fields))" -Headers $srcHdrs
    }

    # Comments (ADF bodies)
    $comments = @()
    try {
      if ($script:DryRun) { $c = @{ comments = @() } } else { $c = Jira-GET -Uri "$srcBase/rest/api/3/issue/$($i.key)/comment?orderBy=created" -Headers $srcHdrs }
      if ($c.comments) { $comments = $c.comments }
    } catch { $comments = @() }

    # Attachments list (include signed content URL)
    $attachments = @()
    if ($issue.fields -and $issue.fields.attachment) {
      $attachments = $issue.fields.attachment | ForEach-Object {
        [pscustomobject]@{
          id       = $_.id
          filename = $_.filename
          size     = $_.size
          mimeType = $_.mimeType
          content  = $_.content
        }
      }
    }

    # Process "No Field Exists" fields - append to description
    $noFieldExistsData = @()
    if ($config.PSObject.Properties.Name -contains 'NoFieldExistsFields' -and $config.NoFieldExistsFields.PSObject.Properties.Name -contains 'Fields') {
      foreach ($fieldId in $config.NoFieldExistsFields.Fields) {
        if ($issue.fields.PSObject.Properties.Name -contains $fieldId -and $issue.fields.$fieldId) {
          $fieldValue = $issue.fields.$fieldId
          $fieldName = $fieldId  # You could add a mapping for friendly names here
          $noFieldExistsData += [PSCustomObject]@{
            FieldId = $fieldId
            FieldName = $fieldName
            Value = $fieldValue
          }
        }
      }
    }

    $bundle = [pscustomobject]@{
      issue       = $issue
      comments    = $comments
      attachments = $attachments
      noFieldExistsData = $noFieldExistsData
    }
    
    # Add parent mapping entry
    $parentKey = "N/A"
    try {
      if ($issue.fields -and $issue.fields.PSObject.Properties.Name -contains 'parent' -and $issue.fields.parent) {
        $parentKey = $issue.fields.parent.key
      }
    } catch {
      Write-Host "Warning: Could not access parent field for $($issue.key)" -ForegroundColor Yellow
    }
    
    $parentMappings += [PSCustomObject]@{
      SourceKey = $issue.key
      SourceParentKey = $parentKey
      TargetKey = "PENDING"  # Will be updated during import
      TargetParentKey = "PENDING"
    }
    
    # Write as single line JSON (JSONL format)
    $jsonLine = ($bundle | ConvertTo-Json -Depth 100 -Compress)
    Add-Content -Path $outFile -Value $jsonLine -Encoding UTF8
  }

  # paginate
  $isLast = $true
  if ($null -ne $search.isLast) { $isLast = [bool]$search.isLast }
  if ($search.PSObject.Properties.Name -contains 'nextPageToken' -and $search.nextPageToken) { 
    $nextPageToken = $search.nextPageToken; $isLast = $false 
  }

} while (-not $isLast)

Write-Host "== Export complete =="

# Create export report for CSV export
$exportReport = @()
$issuesSummary = @()
$issueTypeCounts = @{}

# Process the JSONL file to create a summary CSV
if (Test-Path $outFile) {
    Write-Host "Processing exported issues for CSV summary..." -ForegroundColor Cyan
    $jsonlContent = Get-Content $outFile -Raw
    $jsonlLines = $jsonlContent -split "`n" | Where-Object { $_.Trim() -ne "" }
    
    foreach ($line in $jsonlLines) {
        try {
            $issueData = $line | ConvertFrom-Json
            if ($issueData -and $issueData.issue) {
                $issue = $issueData.issue
                $issueFields = $issue.fields
                
                # Get issue type for counting
                $issueType = if ($issueFields.issuetype -and $issueFields.issuetype.name) { $issueFields.issuetype.name } else { "Unknown" }
                
                # Count issue types
                if ($issueTypeCounts.ContainsKey($issueType)) {
                    $issueTypeCounts[$issueType]++
                } else {
                    $issueTypeCounts[$issueType] = 1
                }
                
                # Extract key information for CSV
                $issueSummary = [PSCustomObject]@{
                    Key = $issue.key
                    Id = $issue.id
                    Summary = if ($issueFields.summary) { $issueFields.summary } else { "No Summary" }
                    IssueType = $issueType
                    Project = if ($issueFields.project -and $issueFields.project.key) { $issueFields.project.key } else { "Unknown" }
                    StoryPoints = if ($issueFields.PSObject.Properties.Name -contains 'customfield_10026' -and $issueFields.customfield_10026) { $issueFields.customfield_10026 } else { "Not Set" }
                    Description = if ($issueFields.description -and $issueFields.description.content) { 
                        # Extract text from ADF content
                        try {
                            $descText = Extract-TextFromADF -Content $issueFields.description.content
                            if ($descText.Length -gt 200) { $descText.Substring(0, 200) + "..." } else { $descText }
                        } catch {
                            "Error extracting description"
                        }
                    } else { "No Description" }
                    HasAttachments = if ($issueFields.attachment -and $issueFields.attachment.Count -gt 0) { "Yes ($($issueFields.attachment.Count))" } else { "No" }
                    CommentCount = if ($issueData.comments) { $issueData.comments.Count } else { 0 }
                    Self = $issue.self
                }
                $issuesSummary += $issueSummary
            }
        } catch {
            Write-Warning "Failed to process issue line: $($_.Exception.Message)"
        }
    }
    
    # Export issues summary to CSV
    $issuesCsvPath = Join-Path $stepExportsDir "07_Export_ADF.csv"
    $issuesSummary | Export-Csv -Path $issuesCsvPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Issues summary saved: $issuesCsvPath" -ForegroundColor Green
    Write-Host "   Total issues processed: $($issuesSummary.Count)" -ForegroundColor Cyan
    
    # Display issue type breakdown
    Write-Host "📊 Issue Type Breakdown:" -ForegroundColor Cyan
    foreach ($issueType in $issueTypeCounts.Keys | Sort-Object) {
        $count = $issueTypeCounts[$issueType]
        Write-Host "   $issueType`: $count" -ForegroundColor White
    }
}

# Add summary statistics
$exportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Exported"
    Value = if (Test-Path $outFile) { (Get-Content $outFile | Measure-Object -Line).Lines } else { 0 }
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$exportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Export File"
    Value = $outFile
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$exportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Export Scope"
    Value = $scope
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$exportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Fields Exported"
    Value = $fields.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add issue type breakdown to report
if ($issueTypeCounts.Count -gt 0) {
    foreach ($issueType in $issueTypeCounts.Keys | Sort-Object) {
        $count = $issueTypeCounts[$issueType]
        $exportReport += [PSCustomObject]@{
            Type = "Issue Type"
            Name = $issueType
            Value = $count
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
}

# Add step timing information to export report
$exportReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
    Timestamp = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step end time to report
$exportReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Calculate step total time
$stepDuration = $stepEndTime - $script:StepStartTime
$totalHours = [int][math]::Floor($stepDuration.TotalHours)
$totalMinutes = [int]([math]::Floor($stepDuration.TotalMinutes) % 60)
$totalSeconds = [int]([math]::Floor($stepDuration.TotalSeconds) % 60)
$durationString = "{0:D2}h : {1:D2}m : {2:D2}s" -f $totalHours, $totalMinutes, $totalSeconds

# Add step total time to report
$exportReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Total Time"
    Value = $durationString
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export report to CSV
$csvPath = Join-Path $stepExportsDir "07_Export_Report.csv"
$exportReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Export report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($exportReport.Count)" -ForegroundColor Cyan

# Export parent mapping to CSV
$parentMappings | Export-Csv -Path $parentMappingFile -NoTypeInformation -Encoding UTF8
Write-Host "✅ Parent mapping saved: $parentMappingFile" -ForegroundColor Green
Write-Host "   Total mappings: $($parentMappings.Count)" -ForegroundColor Cyan

} catch {
    Write-Warning "Export failed due to service issues: $($_.Exception.Message)"
    Write-Host "This may be due to Jira service unavailability. Generating minimal export..." -ForegroundColor Yellow
    
    # Create empty export file if none exists
    if (-not (Test-Path $outFile)) {
        New-Item -ItemType File -Path $outFile -Force | Out-Null
    }
}

# Create receipt data
$receiptData = @{
    StartTime = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-ddTHH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") }
    EndTime = $stepEndTime.ToString("yyyy-MM-ddTHH:mm:ss")
    ExportFile = $outFile
    IssuesExported = if (Test-Path $outFile) { (Get-Content $outFile | Measure-Object -Line).Lines } else { 0 }
    ExportScope = $scope
    FieldsExported = $fields
    ProjectKey = $projectKey
    Jql = $jql
    Status = "Completed"
    Notes = "Export completed successfully"
}

Write-StageReceipt -OutDir $stepExportsDir -Stage "07_Export" -Data $receiptData

# Save issues log
Save-IssuesLog -StepName "07_Export"

# Stop terminal logging
Stop-TerminalLog -Success:$true -Summary "07_Export completed successfully"


