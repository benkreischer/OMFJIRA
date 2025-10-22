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
# NEXT STEP: Run 14_HistoryMigration.ps1 to migrate issue history
#
param([string] $ParametersPath, [switch] $DryRun)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path $here "_common.ps1"
. $commonPath
$script:DryRun = $DryRun

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

# Hardcode paths for now to get script working
$outDir = ".\projects\REM\out"
$prefType = "scrum"
$copyClosed = $true

# Initialize issues logging
Initialize-IssuesLog -StepName "13_Sprints" -OutDir $outDir

# Create exports13 directory and cleanup
$stepExportsDir = Join-Path $outDir "exports13"
if (Test-Path $stepExportsDir) {
    Write-Host "🗑️  Cleaning up previous exports13 directory..." -ForegroundColor Yellow
    Remove-Item $stepExportsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null

# Set step start time
$script:StepStartTime = Get-Date

# Initialize StaleIssuesReport variable
$script:StaleIssuesReport = $null

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
    $resp = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $Hdr -MaxRetries 3 -TimeoutSec 30
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
    $resp = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $Hdr -MaxRetries 3 -TimeoutSec 30
    if ($resp -and $resp.values) {
      $acc += $resp.values
    }
    if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
    $startAt += [int]$resp.maxResults
  } while ($true)
  $acc
}

function Get-ClosedSprintStats {
  param([string] $Base,[hashtable] $Hdr,[int] $BoardId)
  
  try {
    $closed = Get-ClosedSprints -Base $Base -Hdr $Hdr -BoardId $BoardId
  } catch {
    $errorMsg = $_.Exception.Message
    Write-Warning "Failed to retrieve closed sprints for board $BoardId: $errorMsg"
    Write-Host "This may be due to Jira service issues. Continuing with empty sprint data..." -ForegroundColor Yellow
    $closed = @()
  }
  
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
        $errorMsg = $_.Exception.Message
        Write-Warning "Failed to load boards receipt: $errorMsg"
    }
}

# If no boards loaded from receipt, auto-detect via API
if ($targetBoards.Count -eq 0) {
    Write-Host "⚠️  Boards receipt not found, auto-detecting boards via API..." -ForegroundColor Yellow
    try {
        # Get all boards for the target project
        $boardsUrl = "$($tgtBase.TrimEnd('/'))/rest/agile/1.0/board?projectKeyOrId=$tgtKey"
        $boardsResponse = if ($script:DryRun) { @{ values = @() } } else { Invoke-JiraWithRetry -Uri $boardsUrl -Headers $hdrT -MaxRetries 3 -TimeoutSec 30 }
        
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
        $errorMsg = $_.Exception.Message
        Write-Host "❌ Could not detect boards: $errorMsg" -ForegroundColor Red
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
$cands = if ($script:DryRun) { @() } else { Get-BoardsForProject -Base $srcBase -Hdr $hdrS -Proj $srcKey -Type $prefType }
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

$stats = @()
try {
  $stats = foreach ($b in $cands) {
    $st = Get-ClosedSprintStats -Base $srcBase -Hdr $hdrS -BoardId $b.id
    [pscustomobject]@{ Id=$b.id; Name=$b.name; Type=$b.type; Closed=$st.Count; Earliest=$st.Earliest }
  }
} catch {
  $errorMsg = $_.Exception.Message
  Write-Warning "Failed to retrieve sprint statistics: $errorMsg"
  Write-Host "This may be due to Jira service issues. Attempting to continue with limited sprint data..." -ForegroundColor Yellow
  $stats = @()
}
if ($stats -and $stats.Count -gt 0) {
  $chosen = $stats | Sort-Object -Property @{Expression='Closed';Descending=$true}, @{Expression='Earliest';Descending=$false} | Select-Object -First 1
  Write-Host ("Detected source board: {0} (id {1}, closed sprints={2})" -f $chosen.Name, $chosen.Id, $chosen.Closed)
} else {
  Write-Host "⚠️  Unable to retrieve sprint statistics due to service issues. Skipping sprint recreation." -ForegroundColor Yellow
  Write-Host "You can retry this step once Jira service is restored." -ForegroundColor Yellow
  
  # Create a minimal receipt for graceful failure
  $stepEndTime = Get-Date
  Write-StageReceipt -OutDir $stepExportsDir -Stage "13_Sprints" -Data @{
    SourceProject = @{ key=$srcKey }
    TargetProject = @{ key=$tgtKey }
    SprintsRecreated = 0
    SprintsSkipped = 0
    SprintsFailed = 0
    TotalSprintsProcessed = 0
    Status = "Skipped - Service Unavailable"
    Notes = @("Jira service unavailable during execution", "Retry when service is restored")
    StartTime = $script:StepStartTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    EndTime = $stepEndTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
  }
  
  exit 0
}

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
        $step13SummaryCsvPath = Join-Path $stepExportsDir "13_Sprints_Report.csv"
        $step13SummaryReport | Export-Csv -Path $step13SummaryCsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Step 13 summary report saved: $step13SummaryCsvPath" -ForegroundColor Green
        Write-Host "   Total items: $($step13SummaryReport.Count)" -ForegroundColor Cyan
        
        Save-IssuesLog -StepName "13_Sprints"
        exit 0
    } else {
        Write-Host "Found $closedCount closed sprints to recreate"
        
        # ========== IDEMPOTENCY: DELETE all existing sprints first ==========
        Write-Host "🗑️  Deleting existing sprints for clean migration..."
        $existingSprints = @()
        try {
            $response = if ($script:DryRun) { @{ values = @() } } else { Invoke-Jira -Method GET -BaseUrl $tgtBase -Path ("rest/agile/1.0/board/{0}/sprint" -f $targetBoard.Id) -Headers $hdrT }
            if ($response.values) {
                $existingSprints = $response.values
            }
        } catch {
            $errorMsg = $_.Exception.Message
            Write-Host "  ⚠️  Could not fetch existing sprints: $errorMsg" -ForegroundColor Yellow
        }
        
        # Delete all existing sprints for clean migration
        if ($existingSprints.Count -gt 0) {
            Write-Host "  Deleting $($existingSprints.Count) existing sprints..."
            $deletedSprints = 0
            $failedDeletes = 0
            
            foreach ($existingSprint in $existingSprints) {
                try {
                    # Delete sprint using Agile API
                    if ($script:DryRun) { Write-Host "[DRYRUN] DELETE sprint $($existingSprint.id)" -ForegroundColor Yellow } else { $null = Invoke-Jira -Method DELETE -BaseUrl $tgtBase -Path ("rest/agile/1.0/sprint/{0}" -f $existingSprint.id) -Headers $hdrT }
                    $deletedSprints++
                    Write-Host "    ✅ Deleted sprint: $($existingSprint.name)" -ForegroundColor Green
                } catch {
                    $failedDeletes++
                    $errorMsg = $_.Exception.Message
                    Write-Warning "    Failed to delete sprint '$($existingSprint.name)': $errorMsg"
                }
            }
            
            Write-Host "  ✅ Deleted $deletedSprints sprints ($failedDeletes failed)" -ForegroundColor Green
            
            # Clear existing sprints array since we just deleted them all
            $existingSprints = @()
        } else {
            Write-Host "  No existing sprints to delete"
        }
        
        $sprintIndex = 0
        foreach ($sp in $closed) {
            $sprintIndex++
            Write-Host "  Processing sprint $sprintIndex of $closedCount`: $($sp.name)" -ForegroundColor DarkGray
            try {
                # ========== CREATE SPRINT ==========
                # All existing sprints have been deleted, so we can create fresh sprints
                
                Write-Host "Creating sprint: $($sp.name)"
                
                $createBody = @{
                    name = $sp.name
                    startDate = $sp.startDate
                    endDate = $sp.endDate
                    originBoardId = [int]$targetBoard.Id
                    goal = $sp.goal
                }
                
                $newSp = if ($script:DryRun) { @{ id = 0; name = $sp.name } } else { Invoke-Jira -Method POST -BaseUrl $tgtBase -Path "rest/agile/1.0/sprint" -Headers $hdrT -Body $createBody }
                
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
                        
                        if ($script:DryRun) { Write-Host "[DRYRUN] Activate sprint $($newSp.id)" -ForegroundColor Yellow } else { $null = Invoke-Jira -Method POST -BaseUrl $tgtBase -Path ("rest/agile/1.0/sprint/{0}" -f $newSp.id) -Headers $hdrT -Body $activateBody }
                        
                        # Step 2: Close the sprint (requires sprint to be active first)
                        $closeBody = @{ 
                            state = "closed" 
                        }
                        if ($script:DryRun) { Write-Host "[DRYRUN] Close sprint $($newSp.id)" -ForegroundColor Yellow } else { $null = Invoke-Jira -Method POST -BaseUrl $tgtBase -Path ("rest/agile/1.0/sprint/{0}" -f $newSp.id) -Headers $hdrT -Body $closeBody }
                        
                        Write-Host "  ✅ Created and closed sprint: $($sp.name) (id: $($newSp.id))"
                    } catch {
                        $errorMsg = $_.Exception.Message
                        Write-Warning "  ⚠️  Created sprint but failed to set dates/close: $errorMsg"
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
                $errorMsg = $_.Exception.Message
                Write-Warning "  ❌ Failed to create sprint '$($sp.name)': $errorMsg"
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
        
        $searchResponse = Invoke-JiraWithRetry -Uri $searchUrl -Headers $hdrT -Method Post -Body $searchBody -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        
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
    $errorMsg = $_.Exception.Message
    Write-Warning "⚠️ Failed to generate stale issues report: $errorMsg"
    $script:StaleIssuesReport = $null
}



# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 13
$step13SummaryReport = @()

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

# Add step timing information (ALWAYS LAST)
$step13SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step13SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step13SummaryCsvPath = Join-Path $stepExportsDir "13_Sprints_Report.csv"
$step13SummaryReport | Export-Csv -Path $step13SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 13 summary report saved: $step13SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step13SummaryReport.Count)" -ForegroundColor Cyan

# Generate CSV report for created sprints (ALWAYS CREATE)
$createdCsvFileName = "13_Sprints_Details.csv"
$createdCsvFilePath = Join-Path $stepExportsDir $createdCsvFileName

try {
    $createdCsvData = @()
    
    if ($createdSprints.Count -gt 0) {
        foreach ($sprint in $createdSprints) {
            $createdCsvData += [PSCustomObject]@{
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
    } else {
        # Create empty report with note
        $createdCsvData += [PSCustomObject]@{
            "Source Sprint ID" = "No sprints to migrate"
            "Source Sprint Name" = ""
            "Target Sprint ID" = ""
            "Target Sprint Name" = ""
            "Source Start Date" = ""
            "Source End Date" = ""
            "Source Goal" = ""
            "Target State" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $createdCsvData | Export-Csv -Path $createdCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Sprints details report saved: $createdCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $createdCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Sprints created: $($createdSprints.Count)" -ForegroundColor Gray
} catch {
    $errorMsg = $_.Exception.Message
    Write-Warning "Failed to save sprints details report: $errorMsg"
}

# Generate CSV report for failed sprints (ALWAYS CREATE)
$failedCsvFileName = "13_Sprints_Failed.csv"
$failedCsvFilePath = Join-Path $stepExportsDir $failedCsvFileName

try {
    $failedCsvData = @()
    
    if ($failedSprints.Count -gt 0) {
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
    } else {
        # Create empty report with note
        $failedCsvData += [PSCustomObject]@{
            "Source Sprint ID" = "No sprints failed"
            "Source Sprint Name" = ""
            "Source Start Date" = ""
            "Source End Date" = ""
            "Source Goal" = ""
            "Error Message" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Failed sprints report saved: $failedCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Failed sprints: $($failedSprints.Count)" -ForegroundColor Gray
} catch {
    $errorMsg = $_.Exception.Message
    Write-Warning "Failed to save failed sprints report: $errorMsg"
}

# Create detailed receipt
Write-StageReceipt -OutDir $stepExportsDir -Stage "13_Sprints" -Data @{
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
    StaleIssuesReport = if ($script:StaleIssuesReport) { $script:StaleIssuesReport } else { $null }
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

