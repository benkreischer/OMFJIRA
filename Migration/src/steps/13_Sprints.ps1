# 13_Sprints.ps1 - Recreate Closed Sprints from Source Project
# 
# PURPOSE: Recreates all closed sprints from the source project to maintain sprint history
# and organization in the target project. Works with existing boards created in step 06.
#
# WHAT IT DOES:
# - Discovers the best source board based on closed sprint statistics
# - Recreates all closed sprints from the source project
# - Maps source sprint IDs to target sprint IDs for future reference
# - Creates sprint mapping data for issue migration
#
# WHAT IT DOES NOT DO:
# - Does not create new boards (uses existing boards from step 06)
# - Does not migrate issues to sprints yet
# - Does not create active or future sprints
# - Does not migrate sprint goals or other sprint metadata
#
# NEXT STEP: Run 14_Automations.ps1 to generate automation migration guide
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail= $p.SourceEnvironment.Username
$srcTok  = $p.SourceEnvironment.ApiToken
$srcKey  = $p.ProjectKey
$hdrS    = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail= $p.TargetEnvironment.Username
$tgtTok  = $p.TargetEnvironment.ApiToken
$tgtKey  = $p.TargetEnvironment.ProjectKey
$hdrT    = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir  = $p.OutputSettings.OutputDirectory
$prefType= $p.SprintSettings.PreferredBoardType
$copyClosed = [bool]$p.SprintSettings.CopyClosedSprints

# Initialize issues logging
Initialize-IssuesLog -StepName "13_Sprints" -OutDir $outDir

Write-Host "=== SPRINT RECREATION ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host "Preferred Board Type: $prefType"
Write-Host "Copy Closed Sprints: $copyClosed"

function Get-BoardsForProject {
  param([string] $Base,[hashtable] $Hdr,[string] $Proj,[string] $Type)
  $startAt = 0; $acc = @()
  do {
    $uri = "{0}/rest/agile/1.0/board?projectKeyOrId={1}&type={2}&startAt={3}&maxResults=50" -f $Base.TrimEnd('/'), $Proj, $Type, $startAt
    $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
    $acc  += $resp.values
    if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
    $startAt += [int]$resp.maxResults
  } while ($true)
  $acc
}

function Get-ClosedSprints {
  param([string] $Base,[hashtable] $Hdr,[int] $BoardId)
  $startAt = 0; $acc = @()
  do {
    $uri = "{0}/rest/agile/1.0/board/{1}/sprint?state=closed&startAt={2}&maxResults=50" -f $Base.TrimEnd('/'), $BoardId, $startAt
    $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
    $acc += $resp.values
    if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
    $startAt += [int]$resp.maxResults
  } while ($true)
  $acc
}

function Get-ClosedSprintStats {
  param([string] $Base,[hashtable] $Hdr,[int] $BoardId)
  $closed = Get-ClosedSprints -Base $Base -Hdr $Hdr -BoardId $BoardId
  $earliest = $null
  
  # Handle case where $closed might be null or empty
  if ($closed -and $closed.Count -gt 0) {
    foreach ($sp in $closed) {
      if ($sp.startDate) {
        $sd = [datetime]$sp.startDate
        if (-not $earliest -or $sd -lt $earliest) { $earliest = $sd }
      }
    }
  }
  
  # Safely get count - use 0 if $closed is null or doesn't have Count property
  $count = if ($closed -and $closed.Count -ge 0) { $closed.Count } else { 0 }
  
  @{ Count = $count; Earliest=$earliest }
}

# Get target boards from step 06 OR auto-detect
Write-Host ""
Write-Host "=== LOADING TARGET BOARDS ==="
$boardsReceiptFile = Join-Path $outDir "06_Boards_receipt.json"
$targetBoards = @()

if (Test-Path $boardsReceiptFile) {
    # Load from receipt if available
    try {
        $boardsReceipt = Get-Content $boardsReceiptFile -Raw | ConvertFrom-Json
        $targetBoards = $boardsReceipt.Target.Boards
        Write-Host "✅ Loaded $($targetBoards.Count) target boards from step 06 receipt"
    } catch {
        Write-Warning "Failed to load boards receipt: $($_.Exception.Message)"
    }
}

# If no boards loaded from receipt, auto-detect via API
if ($targetBoards.Count -eq 0) {
    Write-Host "⚠️  Boards receipt not found, auto-detecting boards via API..." -ForegroundColor Yellow
    try {
        # Get all boards for the target project
        $boardsUrl = "$($tgtBase.TrimEnd('/'))/rest/agile/1.0/board?projectKeyOrId=$tgtKey"
        $boardsResponse = Invoke-RestMethod -Uri $boardsUrl -Headers $hdrT
        
        if ($boardsResponse.values -and $boardsResponse.values.Count -gt 0) {
            Write-Host "✅ Found $($boardsResponse.values.Count) existing boards in target project"

            # Convert to expected format - use PSCustomObject for proper property access
            $targetBoards = $boardsResponse.values | ForEach-Object {
                [PSCustomObject]@{
                    TargetBoard = [PSCustomObject]@{
                        Id = $_.id
                        Name = $_.name
                        Type = $_.type.ToLower()
                        Self = $_.self
                    }
                }
            }
        } else {
            Write-Host "No boards found in target project. Sprint migration will be skipped." -ForegroundColor Yellow
            
            # Create receipt for no target boards scenario
            Write-StageReceipt -OutDir $outDir -Stage "13_Sprints" -Data @{
                Source = @{ 
                    ProjectKey=$srcKey; 
                    BoardId=$null; 
                    BoardName="No source boards found"; 
                    ClosedSprints=0 
                }
                Target = @{ 
                    ProjectKey=$tgtKey; 
                    BoardId=$null; 
                    BoardName="No target boards found"; 
                    BoardType="N/A" 
                }
                SprintMapping = @()
                CreatedSprints = @()
                SkippedSprints = 0
                FailedSprints = @()
                TotalSprintsProcessed = 0
                IdempotencyEnabled = $true
                SprintsCreated = 0
                SprintsFailed = 0
                Notes = @(
                    "No target boards found - sprint migration skipped",
                    "Please run step 06_Boards.ps1 to create boards first"
                )
            }
            
            Write-Host "✅ Sprint migration skipped - no target boards available" -ForegroundColor Green
            Write-Host "📄 Receipt created: $outDir\13_Sprints_receipt.json" -ForegroundColor Green
            exit 0
        }
    } catch {
        Write-Host ""
        Write-Host "❌ Could not detect boards: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please either:" -ForegroundColor Yellow
        Write-Host "  1. Run step 06_Boards.ps1 to create boards, OR" -ForegroundColor Yellow
        Write-Host "  2. Create a Scrum board manually in Jira UI" -ForegroundColor Yellow
        
        # Create receipt for error scenario
        Write-StageReceipt -OutDir $outDir -Stage "13_Sprints" -Data @{
            Source = @{ 
                ProjectKey=$srcKey; 
                BoardId=$null; 
                BoardName="Error detecting source boards"; 
                ClosedSprints=0 
            }
            Target = @{ 
                ProjectKey=$tgtKey; 
                BoardId=$null; 
                BoardName="Error detecting target boards"; 
                BoardType="N/A" 
            }
            SprintMapping = @()
            CreatedSprints = @()
            SkippedSprints = 0
            FailedSprints = @()
            TotalSprintsProcessed = 0
            IdempotencyEnabled = $true
            SprintsCreated = 0
            SprintsFailed = 0
            Notes = @(
                "Error detecting boards - sprint migration skipped",
                "Error: $($_.Exception.Message)"
            )
        }
        
        Write-Host "✅ Sprint migration skipped due to board detection error" -ForegroundColor Green
        Write-Host "📄 Receipt created: $outDir\13_Sprints_receipt.json" -ForegroundColor Green
        exit 0
    }
}

# Find the best target board (prefer scrum boards for sprints)
$targetBoard = $null
foreach ($board in $targetBoards) {
    if ($board.TargetBoard.Type -eq $prefType) {
        $targetBoard = $board.TargetBoard
        break
    }
}

if (-not $targetBoard) {
    # Fallback to any board if preferred type not found
    $targetBoard = $targetBoards[0].TargetBoard
    Write-Host "⚠️  Preferred board type '$prefType' not found, using: $($targetBoard.Name)"
}

Write-Host "Using target board: $($targetBoard.Name) (id: $($targetBoard.Id), type: $($targetBoard.Type))"

# Discover source boards and find the best one
Write-Host ""
Write-Host "=== DISCOVERING SOURCE BOARDS ==="
$cands = Get-BoardsForProject -Base $srcBase -Hdr $hdrS -Proj $srcKey -Type $prefType
if (-not $cands -or $cands.Count -eq 0) {
    Write-Host ("No {0} boards found for source project {1}" -f $prefType, $srcKey) -ForegroundColor Yellow
    Write-Host "Sprint migration will be skipped - no boards available" -ForegroundColor Yellow
    
    # Create receipt for no boards scenario
    Write-StageReceipt -OutDir $outDir -Stage "13_Sprints" -Data @{
        Source = @{ 
            ProjectKey=$srcKey; 
            BoardId=$null; 
            BoardName="No boards found"; 
            ClosedSprints=0 
        }
        Target = @{ 
            ProjectKey=$tgtKey; 
            BoardId=$targetBoard.Id; 
            BoardName=$targetBoard.Name; 
            BoardType=$targetBoard.Type 
        }
        SprintMapping = @()
        CreatedSprints = @()
        SkippedSprints = 0
        FailedSprints = @()
        TotalSprintsProcessed = 0
        IdempotencyEnabled = $true
        SprintsCreated = 0
        SprintsFailed = 0
        Notes = @(
            "No source boards found - sprint migration skipped",
            "Project may not use Agile/Scrum methodology",
            "No sprint data to migrate"
        )
        Status = "Skipped - No Source Boards"
        NextSteps = @(
            "Verify source project uses Agile/Scrum boards",
            "Proceed with issue migration (sprints not required)"
        )
    }
    
    Save-IssuesLog -StepName "13_Sprints"
    exit 0
}

$stats = foreach ($b in $cands) {
  $st = Get-ClosedSprintStats -Base $srcBase -Hdr $hdrS -BoardId $b.id
  [pscustomobject]@{ Id=$b.id; Name=$b.name; Type=$b.type; Closed=$st.Count; Earliest=$st.Earliest }
}
$chosen = $stats | Sort-Object -Property @{Expression='Closed';Descending=$true}, @{Expression='Earliest';Descending=$false} | Select-Object -First 1
Write-Host ("Detected source board: {0} (id {1}, closed sprints={2})" -f $chosen.Name, $chosen.Id, $chosen.Closed)

# Recreate CLOSED sprints
$sprintMap = @()
$createdSprints = @()
$failedSprints = @()
$skippedSprints = 0

if ($copyClosed) {
    Write-Host ""
    Write-Host "=== RECREATING CLOSED SPRINTS ==="
    $closed = Get-ClosedSprints -Base $srcBase -Hdr $hdrS -BoardId $chosen.Id
    
    # Safely get count - handle case where $closed might be null
    $closedCount = if ($closed -and $closed.Count -ge 0) { $closed.Count } else { 0 }
    
    if ($closedCount -eq 0) {
        Write-Host "No closed sprints found in source board" -ForegroundColor Yellow
        Write-Host "Sprint migration completed - no sprints to recreate" -ForegroundColor Yellow
        
        # Create receipt for no sprints scenario
        Write-StageReceipt -OutDir $outDir -Stage "13_Sprints" -Data @{
            Source = @{ 
                ProjectKey=$srcKey; 
                BoardId=$chosen.Id; 
                BoardName=$chosen.Name; 
                ClosedSprints=0 
            }
            Target = @{ 
                ProjectKey=$tgtKey; 
                BoardId=$targetBoard.Id; 
                BoardName=$targetBoard.Name; 
                BoardType=$targetBoard.Type 
            }
            SprintMapping = @()
            CreatedSprints = @()
            SkippedSprints = 0
            FailedSprints = @()
            TotalSprintsProcessed = 0
            IdempotencyEnabled = $true
            SprintsCreated = 0
            SprintsFailed = 0
            Notes = @(
                "No closed sprints found in source board",
                "Sprint migration completed successfully",
                "Project may be new or not use closed sprints"
            )
            Status = "Completed - No Sprints to Migrate"
            NextSteps = @(
                "Proceed with issue migration",
                "Sprint data not required for this project"
            )
        }
        
        # Capture step end time
        $stepEndTime = Get-Date
        
        # Create main summary CSV for Step 13 (no sprints scenario)
        $step13SummaryReport = @()
        
        # Add step timing information
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Step"
            Name = "Step Start Time"
            Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
            Details = "Step execution started"
            Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Step"
            Name = "Step End Time"
            Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
            Details = "Step execution completed"
            Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Add summary statistics (no sprints scenario)
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Summary"
            Name = "Total Sprints Processed"
            Value = 0
            Details = "Total closed sprints processed from source"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Summary"
            Name = "Sprints Created"
            Value = 0
            Details = "Sprints successfully created in target"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Summary"
            Name = "Sprints Skipped"
            Value = 0
            Details = "Sprints skipped (already exist or no target board)"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        $step13SummaryReport += [PSCustomObject]@{
            Type = "Summary"
            Name = "Sprints Failed"
            Value = 0
            Details = "Sprints that failed to create"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        
        # Export main summary report to CSV
        $step13SummaryCsvPath = Join-Path $outDir "13_Sprints_SummaryReport.csv"
        $step13SummaryReport | Export-Csv -Path $step13SummaryCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Step 13 summary report saved: $step13SummaryCsvPath" -ForegroundColor Green
        Write-Host "   Total items: $($step13SummaryReport.Count)" -ForegroundColor Cyan
        
        Save-IssuesLog -StepName "13_Sprints"
        exit 0
    } else {
        Write-Host "Found $closedCount closed sprints to recreate"
        
        # ========== IDEMPOTENCY: Get existing sprints from target board ==========
        Write-Host "Checking for existing sprints (idempotency)..."
        $existingSprints = @()
        try {
            $response = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path ("rest/agile/1.0/board/{0}/sprint" -f $targetBoard.Id) -Headers $hdrT
            if ($response.values) {
                $existingSprints = $response.values
            }
        } catch {
            Write-Host "  ⚠️  Could not fetch existing sprints: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        Write-Host "Found $($existingSprints.Count) existing sprints in target board"
        
        $sprintIndex = 0
        foreach ($sp in $closed) {
            $sprintIndex++
            Write-Host "  Processing sprint $sprintIndex of $closedCount`: $($sp.name)" -ForegroundColor DarkGray
            try {
                # ========== IDEMPOTENCY CHECK ==========
                # Check if sprint with same name already exists
                $sprintExists = $existingSprints | Where-Object { $_.name -eq $sp.name }
                
                if ($sprintExists) {
                    Write-Host "  ⏭️  Sprint already exists (skipped): $($sp.name)" -ForegroundColor Yellow
                    $sprintMap += [pscustomobject]@{ 
                        SourceId=$sp.id; 
                        TargetId=$sprintExists.id; 
                        Name=$sp.name;
                        SourceStartDate=$sp.startDate;
                        SourceEndDate=$sp.endDate;
                        SourceGoal=$sp.goal;
                        Status="Existing"
                    }
                    $skippedSprints++
                    continue
                }
                
                Write-Host "Creating sprint: $($sp.name)"
                
                $createBody = @{
                    name = $sp.name
                    startDate = $sp.startDate
                    endDate = $sp.endDate
                    originBoardId = [int]$targetBoard.Id
                    goal = $sp.goal
                }
                
                $newSp = Invoke-Jira -Method POST -BaseUrl $tgtBase -Path "rest/agile/1.0/sprint" -Headers $hdrT -Body $createBody
                
                # Set sprint to closed state if it has dates
                if ($sp.startDate -and $sp.endDate) {
                    try {
                        # Jira requires sprints to be started before they can be closed
                        # We need to transition: future -> active -> closed
                        
                        # Step 1: Activate the sprint with dates
                        $activateBody = @{ 
                            state = "active"
                        }
                        # Add dates if they exist and are valid
                        if ($sp.startDate) { $activateBody.startDate = $sp.startDate }
                        if ($sp.endDate) { $activateBody.endDate = $sp.endDate }
                        
                        $null = Invoke-Jira -Method POST -BaseUrl $tgtBase -Path ("rest/agile/1.0/sprint/{0}" -f $newSp.id) -Headers $hdrT -Body $activateBody
                        
                        # Step 2: Close the sprint (requires sprint to be active first)
                        $closeBody = @{ 
                            state = "closed" 
                        }
                        $null = Invoke-Jira -Method POST -BaseUrl $tgtBase -Path ("rest/agile/1.0/sprint/{0}" -f $newSp.id) -Headers $hdrT -Body $closeBody
                        
                        Write-Host "  ✅ Created and closed sprint: $($sp.name) (id: $($newSp.id))"
                    } catch {
                        Write-Warning "  ⚠️  Created sprint but failed to set dates/close: $($_.Exception.Message)"
                        # Sprint still exists, just not in closed state
                    }
                } else {
                    Write-Host "  ✅ Created sprint: $($sp.name) (id: $($newSp.id)) - no dates to set"
                }
                
                $sprintMap += [pscustomobject]@{ 
                    SourceId=$sp.id; 
                    TargetId=$newSp.id; 
                    Name=$sp.name;
                    SourceStartDate=$sp.startDate;
                    SourceEndDate=$sp.endDate;
                    SourceGoal=$sp.goal
                }
                
                $createdSprints += @{
                    SourceSprint = @{ Id=$sp.id; Name=$sp.name; StartDate=$sp.startDate; EndDate=$sp.endDate; Goal=$sp.goal }
                    TargetSprint = @{ Id=$newSp.id; Name=$newSp.name; State="closed" }
                }
                
            } catch {
                Write-Warning "  ❌ Failed to create sprint '$($sp.name)': $($_.Exception.Message)"
                $failedSprints += @{
                    SourceSprint = @{ Id=$sp.id; Name=$sp.name; StartDate=$sp.startDate; EndDate=$sp.endDate; Goal=$sp.goal }
                    Error = $_.Exception.Message
                }
            }
        }
    }
} else {
    Write-Host "Sprint recreation disabled in configuration"
}

Write-Host ""
Write-Host "=== SPRINT RECREATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Sprints created: $($createdSprints.Count)" -ForegroundColor Green
Write-Host "⏭️  Sprints skipped: $skippedSprints (already existed - idempotency)" -ForegroundColor Yellow
Write-Host "❌ Sprints failed: $($failedSprints.Count)" -ForegroundColor Red
Write-Host "📊 Total sprints processed: $closedCount" -ForegroundColor Blue

if ($failedSprints.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed sprints:"
    foreach ($failed in $failedSprints) {
        Write-Host "  - $($failed.SourceSprint.Name): $($failed.Error)"
    }
}

# =============================================================================
# GENERATE STALE ISSUES REPORT (Updated > 12 months ago)
# =============================================================================

Write-Host ""
Write-Host "=== GENERATING STALE ISSUES REPORT ===" -ForegroundColor Cyan

try {
    # Load key mapping to get source-target relationships
    $exportDir = Join-Path $outDir "exports"
    $keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"
    
    if (-not (Test-Path $keyMappingFile)) {
        Write-Host "⚠️ Skipping stale issues report - key mapping file not found" -ForegroundColor Yellow
        Write-Host "   Run steps 07 and 08 first to generate this report" -ForegroundColor Yellow
    } else {
        Write-Host "📁 Loading key mapping and querying target issues..." -ForegroundColor Gray
        
        # Load key mapping
        $keyMapping = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
        
        # Convert key mapping to hashtable (source -> target)
        $sourceToTargetKeyMap = @{}
        $targetToSourceKeyMap = @{}
        foreach ($prop in $keyMapping.PSObject.Properties) {
            $sourceToTargetKeyMap[$prop.Name] = $prop.Value
            $targetToSourceKeyMap[$prop.Value] = $prop.Name
        }
        
        # Calculate 12 months ago date
        $twelveMonthsAgo = (Get-Date).AddMonths(-12)
        $today = Get-Date
        
        # Query all issues from target project
        Write-Host "🔍 Querying all issues from target project $tgtKey..." -ForegroundColor Gray
        $jql = "project = $tgtKey ORDER BY updated DESC"
        $searchUrl = "$tgtBase/rest/api/3/search/jql"
        $searchBody = @{
            jql = $jql
            maxResults = 1000
            fields = @("summary", "created", "updated", "customfield_10402", "customfield_10403")
        } | ConvertTo-Json -Depth 10
        
        $searchResponse = Invoke-RestMethod -Uri $searchUrl -Headers $hdrT -Method Post -Body $searchBody -ContentType "application/json"
        
        Write-Host "📊 Found $($searchResponse.issues.Count) issues in target project" -ForegroundColor Gray
        
        # Filter issues updated more than 12 months ago
        $staleIssues = @()
        
        foreach ($issue in $searchResponse.issues) {
            $targetKey = $issue.key
            $sourceKey = $targetToSourceKeyMap[$targetKey]
            
            # Only include issues that were migrated from source (have source mapping)
            if (-not $sourceKey) {
                continue
            }
            
            # Get original updated date from custom fields (set during migration)
            $originalUpdatedDate = $null
            $originalCreatedDate = $null
            
            # Try to get from custom fields first (original dates from source)
            if ($issue.fields.customfield_10403) {
                try {
                    $originalUpdatedDate = [DateTime]::Parse($issue.fields.customfield_10403)
                } catch {
                    # Fallback to standard updated field
                    if ($issue.fields.updated) {
                        $originalUpdatedDate = [DateTime]::Parse($issue.fields.updated)
                    }
                }
            } elseif ($issue.fields.updated) {
                $originalUpdatedDate = [DateTime]::Parse($issue.fields.updated)
            }
            
            # Try to get original created date
            if ($issue.fields.customfield_10402) {
                try {
                    $originalCreatedDate = [DateTime]::Parse($issue.fields.customfield_10402)
                } catch {
                    # Fallback to standard created field
                    if ($issue.fields.created) {
                        $originalCreatedDate = [DateTime]::Parse($issue.fields.created)
                    }
                }
            } elseif ($issue.fields.created) {
                $originalCreatedDate = [DateTime]::Parse($issue.fields.created)
            }
            
            # Check if issue was updated more than 12 months ago
            if ($originalUpdatedDate -and $originalUpdatedDate -lt $twelveMonthsAgo) {
                # Calculate days since updated and created
                $daysSinceUpdated = ($today - $originalUpdatedDate).Days
                $daysSinceCreated = if ($originalCreatedDate) { ($today - $originalCreatedDate).Days } else { "N/A" }
                
                $staleIssues += [PSCustomObject]@{
                    SourceIssueId = $sourceKey
                    TargetIssueId = $targetKey
                    Summary = $issue.fields.summary
                    OriginalUpdatedDate = $originalUpdatedDate.ToString("yyyy-MM-dd")
                    OriginalCreatedDate = if ($originalCreatedDate) { $originalCreatedDate.ToString("yyyy-MM-dd") } else { "N/A" }
                    DaysSinceUpdated = $daysSinceUpdated
                    DaysSinceCreated = $daysSinceCreated
                    SourceIssueUrl = "$($srcBase.TrimEnd('/'))/browse/$sourceKey"
                    TargetIssueUrl = "$($tgtBase.TrimEnd('/'))/browse/$targetKey"
                }
            }
        }
        
        # Sort by days since updated (oldest first)
        $staleIssues = $staleIssues | Sort-Object DaysSinceUpdated -Descending
        
        Write-Host "📊 Found $($staleIssues.Count) issues updated more than 12 months ago" -ForegroundColor Green
        
        if ($staleIssues.Count -gt 0) {
            # Create CSV report
            $csvFileName = "Issues_Updated_More_Than_12_Months_Ago.csv"
            $csvFilePath = Join-Path $outDir $csvFileName
            
            # Create CSV with hyperlinks (Excel-compatible format)
            $csvData = @()
            foreach ($issue in $staleIssues) {
                $csvData += [PSCustomObject]@{
                    "Source Issue ID" = $issue.SourceIssueId
                    "Target Issue ID" = $issue.TargetIssueId
                    "Summary" = $issue.Summary
                    "Original Updated Date" = $issue.OriginalUpdatedDate
                    "Original Created Date" = $issue.OriginalCreatedDate
                    "Days Since Updated" = $issue.DaysSinceUpdated
                    "Days Since Created" = $issue.DaysSinceCreated
                    "Source Issue URL" = $issue.SourceIssueUrl
                    "Target Issue URL" = $issue.TargetIssueUrl
                    "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
            
            $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
            
            Write-Host "✅ Stale issues report created: $csvFileName" -ForegroundColor Green
            Write-Host "   📄 Location: $csvFilePath" -ForegroundColor Gray
            Write-Host "   📊 Issues found: $($staleIssues.Count)" -ForegroundColor Gray
            
            # Store report data for Confluence integration
            $script:StaleIssuesReport = @{
                Count = $staleIssues.Count
                FileName = $csvFileName
                FilePath = $csvFilePath
                Issues = $staleIssues
                GeneratedAt = $today.ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            Write-Host "✅ No stale issues found - all issues have been updated within the last 12 months" -ForegroundColor Green
            $script:StaleIssuesReport = @{
                Count = 0
                FileName = "Issues_Updated_More_Than_12_Months_Ago.csv"
                FilePath = Join-Path $outDir "Issues_Updated_More_Than_12_Months_Ago.csv"
                Issues = @()
                GeneratedAt = $today.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    }
} catch {
    Write-Warning "⚠️ Failed to generate stale issues report: $($_.Exception.Message)"
    $script:StaleIssuesReport = $null
}

# Generate CSV report for created sprints
if ($createdSprints.Count -gt 0) {
    $csvFileName = "13_Sprints_Report.csv"
    $csvFilePath = Join-Path $outDir $csvFileName
    
    try {
        $csvData = @()
        foreach ($sprint in $createdSprints) {
            $csvData += [PSCustomObject]@{
                "Source Sprint ID" = $sprint.SourceSprint.Id
                "Source Sprint Name" = $sprint.SourceSprint.Name
                "Target Sprint ID" = $sprint.TargetSprint.Id
                "Target Sprint Name" = $sprint.TargetSprint.Name
                "Source Start Date" = if ($sprint.SourceSprint.StartDate) { $sprint.SourceSprint.StartDate } else { "N/A" }
                "Source End Date" = if ($sprint.SourceSprint.EndDate) { $sprint.SourceSprint.EndDate } else { "N/A" }
                "Source Goal" = if ($sprint.SourceSprint.Goal) { $sprint.SourceSprint.Goal } else { "N/A" }
                "Target State" = $sprint.TargetSprint.State
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "✅ Sprints report saved: $csvFileName" -ForegroundColor Green
        Write-Host "   📄 Location: $csvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Sprints created: $($createdSprints.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save sprints report: $($_.Exception.Message)"
    }
}

# Generate CSV report for failed sprints (if any)
if ($failedSprints.Count -gt 0) {
    $failedCsvFileName = "13_FailedSprints.csv"
    $failedCsvFilePath = Join-Path $outDir $failedCsvFileName
    
    try {
        $failedCsvData = @()
        foreach ($sprint in $failedSprints) {
            $failedCsvData += [PSCustomObject]@{
                "Source Sprint ID" = $sprint.SourceSprint.Id
                "Source Sprint Name" = $sprint.SourceSprint.Name
                "Source Start Date" = if ($sprint.SourceSprint.StartDate) { $sprint.SourceSprint.StartDate } else { "N/A" }
                "Source End Date" = if ($sprint.SourceSprint.EndDate) { $sprint.SourceSprint.EndDate } else { "N/A" }
                "Source Goal" = if ($sprint.SourceSprint.Goal) { $sprint.SourceSprint.Goal } else { "N/A" }
                "Error Message" = $sprint.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "❌ Failed sprints report saved: $failedCsvFileName" -ForegroundColor Red
        Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Failed sprints: $($failedSprints.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save failed sprints report: $($_.Exception.Message)"
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 13
$step13SummaryReport = @()

# Add step timing information
$step13SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step13SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Add summary statistics
$step13SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Sprints Processed"
    Value = $closedCount
    Details = "Total closed sprints processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step13SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Sprints Created"
    Value = $createdSprints.Count
    Details = "Sprints successfully created in target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step13SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Sprints Skipped"
    Value = $skippedSprints
    Details = "Sprints skipped (already exist or no target board)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step13SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Sprints Failed"
    Value = $failedSprints.Count
    Details = "Sprints that failed to create"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step13SummaryCsvPath = Join-Path $outDir "13_Sprints_SummaryReport.csv"
$step13SummaryReport | Export-Csv -Path $step13SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 13 summary report saved: $step13SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step13SummaryReport.Count)" -ForegroundColor Cyan

# Generate CSV report for created sprints (if any)
if ($createdSprints.Count -gt 0) {
    $createdCsvFileName = "13_CreatedSprints.csv"
    $createdCsvFilePath = Join-Path $outDir $createdCsvFileName
    
    try {
        $createdCsvData = @()
        foreach ($sprint in $createdSprints) {
            $createdCsvData += [PSCustomObject]@{
                "Source Sprint ID" = $sprint.SourceSprint.Id
                "Source Sprint Name" = $sprint.SourceSprint.Name
                "Target Sprint ID" = $sprint.TargetSprint.Id
                "Target Sprint Name" = $sprint.TargetSprint.Name
                "Source Start Date" = if ($sprint.SourceSprint.StartDate) { $sprint.SourceSprint.StartDate } else { "N/A" }
                "Source End Date" = if ($sprint.SourceSprint.EndDate) { $sprint.SourceSprint.EndDate } else { "N/A" }
                "Source Goal" = if ($sprint.SourceSprint.Goal) { $sprint.SourceSprint.Goal } else { "N/A" }
                "Target Board ID" = $sprint.TargetBoard.Id
                "Target Board Name" = $sprint.TargetBoard.Name
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $createdCsvData | Export-Csv -Path $createdCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "✅ Created sprints report saved: $createdCsvFileName" -ForegroundColor Green
        Write-Host "   📄 Location: $createdCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Created sprints: $($createdSprints.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save created sprints report: $($_.Exception.Message)"
    }
}

# Generate CSV report for failed sprints (if any)
if ($failedSprints.Count -gt 0) {
    $failedCsvFileName = "13_FailedSprints.csv"
    $failedCsvFilePath = Join-Path $outDir $failedCsvFileName
    
    try {
        $failedCsvData = @()
        foreach ($sprint in $failedSprints) {
            $failedCsvData += [PSCustomObject]@{
                "Source Sprint ID" = $sprint.SourceSprint.Id
                "Source Sprint Name" = $sprint.SourceSprint.Name
                "Source Start Date" = if ($sprint.SourceSprint.StartDate) { $sprint.SourceSprint.StartDate } else { "N/A" }
                "Source End Date" = if ($sprint.SourceSprint.EndDate) { $sprint.SourceSprint.EndDate } else { "N/A" }
                "Source Goal" = if ($sprint.SourceSprint.Goal) { $sprint.SourceSprint.Goal } else { "N/A" }
                "Error Message" = $sprint.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "❌ Failed sprints report saved: $failedCsvFileName" -ForegroundColor Red
        Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Failed sprints: $($failedSprints.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save failed sprints report: $($_.Exception.Message)"
    }
}

# Create detailed receipt
Write-StageReceipt -OutDir $outDir -Stage "13_Sprints" -Data @{
    Source = @{ 
        ProjectKey=$srcKey; 
        BoardId=$chosen.Id; 
        BoardName=$chosen.Name; 
        ClosedSprints=$chosen.Closed 
    }
    Target = @{ 
        ProjectKey=$tgtKey; 
        BoardId=$targetBoard.Id; 
        BoardName=$targetBoard.Name; 
        BoardType=$targetBoard.Type 
    }
    SprintMapping = $sprintMap
    CreatedSprints = $createdSprints
    SkippedSprints = $skippedSprints
    FailedSprints = $failedSprints
    TotalSprintsProcessed = $closedCount
    IdempotencyEnabled = $true
    SprintsCreated = $createdSprints.Count
    SprintsFailed = $failedSprints.Count
    StaleIssuesReport = $script:StaleIssuesReport
    Notes = @(
        "Closed sprint recreation completed",
        "Sprint mapping data created for issue migration",
        "Sprint dates and goals preserved where possible",
        "Sprints created in closed state to maintain historical accuracy",
        "Stale issues report generated for issues updated > 12 months ago"
    )
    Status = if ($failedSprints.Count -eq 0) { "All Sprints Created Successfully" } else { "Some Sprints Failed" }
    NextSteps = @(
        "Use sprint mapping data during issue migration",
        "Verify sprint recreation in target project",
        "Review stale issues report for maintenance planning",
        "Proceed with issue export and migration"
    )
}

# Save issues log
Save-IssuesLog -StepName "13_Sprints"

exit 0
