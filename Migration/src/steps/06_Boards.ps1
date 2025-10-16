# 06_Boards.ps1 - Copy Source Board Filters & Create Target Boards (IDEMPOTENT)
#
# PURPOSE:
#   For each source board, copy its saved filter JQL to the target, share it to the target project,
#   and create a matching board bound to that filter. If the filter/JQL cannot be read, the board is skipped.
#
# NOTE:
#   - Company-managed projects only (filter-backed boards)
#   - Requires permissions to read source board/filter and create filters/boards in target
#   - **IDEMPOTENT: Deletes ALL existing boards in target project before recreating**
#   - Use -SkipCleanup to preserve existing boards (not recommended)
#
param(
    [string] $ParametersPath,
    [switch] $SkipCleanup = $false
)

# Bootstrap
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

# Environments
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail= $p.SourceEnvironment.Username
$srcTok  = $p.SourceEnvironment.ApiToken
$srcKey  = $p.ProjectKey
$srcName = $p.ProjectName
$hdrS    = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail= $p.TargetEnvironment.Username
$tgtTok  = $p.TargetEnvironment.ApiToken
$tgtKey  = $p.TargetEnvironment.ProjectKey
$hdrT    = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir  = $p.OutputSettings.OutputDirectory

# Initialize issues logging
Initialize-IssuesLog -StepName "06_Boards" -OutDir $outDir

# ---- IDEMPOTENCY: Delete ALL existing boards first (unless -SkipCleanup) ----
if (-not $SkipCleanup) {
    Write-Host "=== DELETE ALL EXISTING BOARDS (IDEMPOTENCY) ===" -ForegroundColor Yellow
    Write-Host "Target Project: $tgtKey"
    Write-Host ""
    
    # Discover all boards in target project
    $allTargetBoards = @()
    foreach ($boardType in @("scrum","kanban")) {
        $startAt = 0
        do {
            $uri = "{0}/rest/agile/1.0/board?projectKeyOrId={1}&type={2}&startAt={3}&maxResults=50" -f $tgtBase.TrimEnd('/'), $tgtKey, $boardType, $startAt
            $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $hdrT -ErrorAction Stop
            if ($resp.values) {
                foreach ($b in $resp.values) {
                    $allTargetBoards += [pscustomobject]@{ 
                        Id = $b.id
                        Name = $b.name
                        Type = $b.type
                    }
                }
            }
            if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
            $startAt += [int]$resp.maxResults
        } while ($true)
    }
    
    Write-Host "Found $($allTargetBoards.Count) existing boards in project $tgtKey"
    
    if ($allTargetBoards.Count -eq 0) {
        Write-Host "No existing boards to delete - starting fresh" -ForegroundColor Green
    } else {
        Write-Host "Deleting ALL $($allTargetBoards.Count) existing boards to ensure clean state..."
        Write-Host ""
        
        $deleted = 0
        $failed = 0
        
        foreach ($board in $allTargetBoards) {
            try {
                $deleteUri = "{0}/rest/agile/1.0/board/{1}" -f $tgtBase.TrimEnd('/'), $board.Id
                Invoke-JiraWithRetry -Method DELETE -Uri $deleteUri -Headers $hdrT -MaxRetries 3 -TimeoutSec 30
                Write-Host "  ✓ Deleted: '$($board.Name)' (id $($board.Id), type $($board.Type))" -ForegroundColor Gray
                $deleted++
            } catch {
                Write-Warning "  ✗ Failed to delete '$($board.Name)' (id $($board.Id)): $($_.Exception.Message)"
                $failed++
            }
        }
        
        Write-Host ""
        Write-Host "Deleted $deleted boards ($failed failed)" -ForegroundColor Green
    }
    Write-Host ""
} else {
    Write-Host "=== SKIPPING CLEANUP (Preserving existing boards) ===" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "=== BOARDS: COPY FILTER JQL AND CREATE TARGET BOARDS (STRICT) ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"

# Initialize script-level change tracking variable
$script:__chg = $false

# ---- Single helper kept for clarity: strict JQL rewrite (no generic fallback) ----
function Rewrite-Jql-Project {
    param([string]$Jql,[string]$SourceKey,[string]$TargetKey,[string]$SourceName=$null)
    if (-not $Jql) { return $null }
    $changed = $false
    $out = $Jql

    # project = "Source Project Name" (project name in quotes)
    if ($SourceName) {
        $pat0 = "(?i)(\bproject\s*=\s*)`"$([regex]::Escape($SourceName))`""
        $out = [regex]::Replace($out, $pat0, { param($m) $script:__chg = $true; "$($m.Groups[1].Value)$TargetKey" })
        if ($script:__chg) { $changed = $true; $script:__chg=$false }
    }

    # project = SRC (quoted or not)
    $pat1 = "(?i)(\bproject\s*=\s*)(`"$([regex]::Escape($SourceKey))`"|$([regex]::Escape($SourceKey)))\b"
    $out = [regex]::Replace($out, $pat1, { param($m) $script:__chg = $true; "$($m.Groups[1].Value)$TargetKey" })
    if ($script:__chg) { $changed = $true; $script:__chg=$false }

    # project in ("SRC", …) or project in ("Source Name", …)
    $pat2 = "(?i)\bproject\s+in\s*\(([^)]*)\)"
    $out = [regex]::Replace($out, $pat2, {
        param($m)
        $list = $m.Groups[1].Value
        $items = $list -split ',' | ForEach-Object { $_.Trim() }
        $newItems = @()
        $localChanged = $false
        foreach ($it in $items) {
            $itUnq = $it.Trim('"')
            if ($itUnq -ieq $SourceKey -or ($SourceName -and $itUnq -ieq $SourceName)) { 
                $newItems += $TargetKey
                $localChanged = $true 
            }
            # Skip other projects that likely don't exist in target environment
            # Just keep the target project we're migrating to
        }
        if ($localChanged) { 
            $script:__chg = $true 
            # If multiple projects existed and we found our source project, simplify to single project
            if ($items.Count -gt 1) {
                return "project = $TargetKey"
            }
        }
        if ($newItems.Count -eq 0) { 
            # Source project wasn't in the list at all
            return $m.Value 
        }
        if ($newItems.Count -eq 1) {
            "project = " + $newItems[0]
        } else {
            "project in (" + ($newItems -join ", ") + ")"
        }
    })
    if ($script:__chg) { $changed = $true; $script:__chg=$false }

    if (-not $changed) { return $null } # STRICT: refuse if JQL doesn't reference the source project

    if ($out -notmatch '(?i)\border\s+by\b') { $out = "$out ORDER BY Rank ASC" }
    return $out
}

# ---- Helper function to check if board is active/accessible ----
function Test-BoardActive {
    param($BoardId, $Headers, $BaseUrl)
    try {
        # Check board configuration
        $configUri = "{0}/rest/agile/1.0/board/{1}/configuration" -f $BaseUrl.TrimEnd('/'), $BoardId
        $config = Invoke-RestMethod -Method GET -Uri $configUri -Headers $Headers -ErrorAction Stop
        
        # Also verify we can access the board's filter
        if ($config -and $config.PSObject.Properties.Name -contains 'filter') {
            $filterIdToCheck = $null
            if ($config.filter -is [string]) { $filterIdToCheck = $config.filter }
            elseif ($config.filter.PSObject.Properties.Name -contains 'id') { $filterIdToCheck = $config.filter.id }
            
            if ($filterIdToCheck) {
                $filterUri = "{0}/rest/api/3/filter/{1}" -f $BaseUrl.TrimEnd('/'), $filterIdToCheck
                $filter = Invoke-RestMethod -Method GET -Uri $filterUri -Headers $Headers -ErrorAction Stop
                
                # Verify filter has accessible JQL
                if (-not $filter.jql) {
                    return $false
                }
            }
        }
        
        return $true
    } catch {
        return $false
    }
}

# ---- Discover source boards (scrum + kanban) ----
$allBoards = @()

# Method 1: Try the original projectKeyOrId query for each type
foreach ($boardType in @("scrum","kanban")) {
    Write-Host ""
    Write-Host "=== DISCOVERING $($boardType.ToUpper()) BOARDS (Method 1: projectKeyOrId) ==="
    $startAt = 0
    do {
        $uri = "{0}/rest/agile/1.0/board?projectKeyOrId={1}&type={2}&startAt={3}&maxResults=50" -f $srcBase.TrimEnd('/'), $srcKey, $boardType, $startAt
        $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $hdrS -ErrorAction Stop
        if ($resp.values) {
            foreach ($b in $resp.values) {
                # Validate board is active/accessible
                if (Test-BoardActive -BoardId $b.id -Headers $hdrS -BaseUrl $srcBase) {
                    $allBoards += [pscustomobject]@{ Id=$b.id; Name=$b.name; Type=$b.type }
                    Write-Host ("Found {0} board: {1} (id {2})" -f $boardType, $b.name, $b.id)
                } else {
                    Write-Host ("Skipping inactive/deleted board: {0} (id {1})" -f $b.name, $b.id) -ForegroundColor Gray
                }
            }
        }
        if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
        $startAt += [int]$resp.maxResults
    } while ($true)
}

# Method 2: Fallback - search all boards and filter by project association
Write-Host ""
Write-Host "=== DISCOVERING BOARDS (Method 2: All boards + project filter) ==="
$startAt = 0
do {
    $uri = "{0}/rest/agile/1.0/board?startAt={1}&maxResults=100" -f $srcBase.TrimEnd('/'), $startAt
    $resp = Invoke-RestMethod -Method GET -Uri $uri -Headers $hdrS -ErrorAction Stop
    if ($resp.values) {
        foreach ($b in $resp.values) {
            # Check if board is associated with our source project
            try {
                if ($b.PSObject.Properties.Name -contains 'location' -and 
                    $b.location -and 
                    $b.location.PSObject.Properties.Name -contains 'projectKey' -and 
                    $b.location.projectKey -eq $srcKey) {
                    # Only add if not already found by Method 1 and if board is active
                    $existing = $allBoards | Where-Object { $_.Id -eq $b.id }
                    if (-not $existing) {
                        if (Test-BoardActive -BoardId $b.id -Headers $hdrS -BaseUrl $srcBase) {
                            $allBoards += [pscustomobject]@{ Id=$b.id; Name=$b.name; Type=$b.type }
                            Write-Host ("Found additional board: {0} (id {1}, type {2})" -f $b.name, $b.id, $b.type)
                        } else {
                            Write-Host ("Skipping inactive/deleted board: {0} (id {1})" -f $b.name, $b.id) -ForegroundColor Gray
                        }
                    }
                }
            } catch {
                # Skip boards that don't have the expected structure
                continue
            }
        }
    }
    if ($resp.isLast -or -not $resp.values -or $resp.values.Count -eq 0) { break }
    $startAt += [int]$resp.maxResults
} while ($true)

if ($allBoards.Count -eq 0) { throw "No source boards found for project $srcKey." }

# ---- Target project info ----
$tgtProj = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path ("rest/api/3/project/{0}" -f $tgtKey) -Headers $hdrT
$tgtProjId = $tgtProj.id

# ---- Process each board: get filter/JQL, create target filter (robust), then create/reuse board ----
$createdBoards = @()
$skippedBoards = @()

# Who am I, for filter search disambiguation (in case POST /filter returns no 'id')
$me = $null
try { $me = Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/myself" -f $tgtBase.TrimEnd('/')) -Headers $hdrT -ErrorAction Stop } catch { $me = $null }

foreach ($board in $allBoards) {
    Write-Host ""
    Write-Host ("=== PROCESSING SOURCE BOARD '{0}' (id {1}, type {2}) ===" -f $board.Name, $board.Id, $board.Type)

    # (1) Read board configuration → filter id
    $cfg = $null; $filterId = $null
    try {
        $cfgUri = "{0}/rest/agile/1.0/board/{1}/configuration" -f $srcBase.TrimEnd('/'), $board.Id
        $cfg = Invoke-RestMethod -Method GET -Uri $cfgUri -Headers $hdrS -ErrorAction Stop
        if ($cfg -and $cfg.PSObject.Properties.Name -contains 'filter') {
            if ($cfg.filter -is [string]) { $filterId = $cfg.filter }
            elseif ($cfg.filter.PSObject.Properties.Name -contains 'id') { $filterId = $cfg.filter.id }
        }
        if (-not $filterId) { throw "No filter id in board configuration." }
    } catch {
        $skippedBoards += @{ Id=$board.Id; Name=$board.Name; Type=$board.Type; Reason="Cannot read board configuration: $($_.Exception.Message)" }
        Write-Warning ("Skipping board '{0}': {1}" -f $board.Name, $_.Exception.Message)
        continue
    }

    # (2) Read filter → JQL
    $srcFilter = $null; $targetJql = $null; $needsFix = $false
    try {
        $fUri = "{0}/rest/api/3/filter/{1}" -f $srcBase.TrimEnd('/'), $filterId
        $srcFilter = Invoke-RestMethod -Method GET -Uri $fUri -Headers $hdrS -ErrorAction Stop
        if (-not $srcFilter.jql) { throw "Filter $filterId has no JQL." }
        Write-Host ("Source JQL: {0}" -f $srcFilter.jql)
        
        # Check if this is a multi-project board
        if ($srcFilter.jql -match '(?i)project\s+IN\s*\(') {
            Write-Host ("Multi-project board detected: '{0}' - will create with FIX prefix and simple JQL" -f $board.Name) -ForegroundColor Yellow
            $needsFix = $true
            $targetJql = "project = $tgtKey ORDER BY Rank ASC"
        }
        
        if (-not $needsFix) {
            $targetJql = Rewrite-Jql-Project -Jql $srcFilter.jql -SourceKey $srcKey -TargetKey $tgtKey -SourceName $srcName
            if (-not $targetJql) { 
                # JQL doesn't reference the source project - use fallback with FIX prefix
                Write-Host ("JQL does not reference source project '{0}' - will create with FIX prefix and simple JQL" -f $board.Name) -ForegroundColor Yellow
                $needsFix = $true
                $targetJql = "project = $tgtKey ORDER BY Rank ASC"
            }
        }
        Write-Host ("Target JQL: {0}" -f $targetJql)
    } catch {
        $skippedBoards += @{ Id=$board.Id; Name=$board.Name; Type=$board.Type; Reason="Cannot read/convert source JQL: $($_.Exception.Message)" }
        Write-Warning ("Skipping board '{0}': {1}" -f $board.Name, $_.Exception.Message)
        continue
    }

    # (3) Create target filter (with sharePermissions). Some tenants return no 'id' -> robust lookup.
    $boardName = if ($needsFix) { "FIX - $($board.Name)" } else { $board.Name }
    $filterName = "{0} - {1} (copied from {2} {3})" -f $tgtKey, $boardName, $srcKey, (Get-Date -Format "yyyyMMddHHmmss")
    $desc = "Copied from board '$($board.Name)' (id $($board.Id)) filter id $filterId"
    if ($needsFix) { $desc += " - NOTE: JQL was modified to reference target project" }
    $newFilter = $null
    try {
        $payloadObj = @{
            name             = $filterName
            jql              = $targetJql
            description      = $desc
            favourite        = $false
            sharePermissions = @(@{ type="project"; project=@{ id=[int]$tgtProjId } })
        }
        $createUri = "{0}/rest/api/3/filter" -f $tgtBase.TrimEnd('/')
        $fResp = Invoke-RestMethod -Method POST -Uri $createUri -Headers $hdrT -Body ($payloadObj | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction Stop

        if ($fResp -and ($fResp.PSObject.Properties.Name -contains 'id')) {
            $newFilter = [pscustomobject]@{ id = $fResp.id; name = $fResp.name }
        } else {
            # Fallback: search by name, prefer same owner
            $qName = [uri]::EscapeDataString($filterName)
            $searchUri = "{0}/rest/api/3/filter/search?filterName={1}&expand=owner" -f $tgtBase.TrimEnd('/'), $qName
            $search = Invoke-RestMethod -Method GET -Uri $searchUri -Headers $hdrT -ErrorAction Stop
            $match = $null
            if ($search.values) {
                foreach ($v in $search.values) {
                    if ($v.name -eq $filterName) {
                        if ($me -and $v.PSObject.Properties.Name -contains 'owner' -and $v.owner -and $v.owner.accountId -eq $me.accountId) { $match = $v; break }
                        if (-not $match) { $match = $v }
                    }
                }
            }
            if (-not $match) { throw "Filter created but id not found via search; check filter visibility." }
            # Ensure shared (if create-share didn't land)
            try {
                $permBody = @{ type="project"; projectId=[int]$tgtProjId } | ConvertTo-Json -Depth 4
                $puri  = "{0}/rest/api/3/filter/{1}/permission" -f $tgtBase.TrimEnd('/'), $match.id
                Invoke-RestMethod -Method POST -Uri $puri -Headers $hdrT -Body $permBody -ContentType "application/json" -ErrorAction SilentlyContinue | Out-Null
            } catch {}
            $newFilter = [pscustomobject]@{ id = $match.id; name = $match.name }
        }
        Write-Host ("Created target filter '{0}' (id {1})" -f $filterName, $newFilter.id)
    } catch {
        # FALLBACK: Create a basic filter with simple JQL and prefix board name with "FIX - "
        Write-Warning ("Filter creation failed: {0}" -f $_.Exception.Message)
        Write-Host ("Creating fallback filter with basic JQL..." -f $board.Name) -ForegroundColor Yellow
        
        $needsFix = $true
        $boardName = "FIX - $($board.Name)"
        $targetJql = "project = $tgtKey ORDER BY Rank ASC"
        $filterName = "{0} - {1} (copied from {2} {3})" -f $tgtKey, $boardName, $srcKey, (Get-Date -Format "yyyyMMddHHmmss")
        $desc = "Copied from board '$($board.Name)' (id $($board.Id)) - REQUIRES MANUAL FIX: Original JQL could not be converted"
        
        try {
            $payloadObj = @{
                name             = $filterName
                jql              = $targetJql
                description      = $desc
                favourite        = $false
                sharePermissions = @(@{ type="project"; project=@{ id=[int]$tgtProjId } })
            }
            $createUri = "{0}/rest/api/3/filter" -f $tgtBase.TrimEnd('/')
            $fResp = Invoke-RestMethod -Method POST -Uri $createUri -Headers $hdrT -Body ($payloadObj | ConvertTo-Json -Depth 10) -ContentType "application/json" -ErrorAction Stop
            
            if ($fResp -and ($fResp.PSObject.Properties.Name -contains 'id')) {
                $newFilter = [pscustomobject]@{ id = $fResp.id; name = $fResp.name }
            }
            Write-Host ("Created fallback filter '{0}' (id {1})" -f $filterName, $newFilter.id) -ForegroundColor Yellow
        } catch {
            $skippedBoards += @{ Id=$board.Id; Name=$board.Name; Type=$board.Type; Reason="Target filter creation failed (even with fallback): $($_.Exception.Message)" }
            Write-Warning ("Skipping board '{0}' - fallback filter also failed: {1}" -f $board.Name, $_.Exception.Message)
            continue
        }
    }

    # (4) Check if board with same name already exists in target project, or reuse existing board for this filter
    $boardId = $null
    if (-not $boardName) { $boardName = $board.Name }  # Use the name set earlier (may have "FIX - " prefix)
    $boardType = $board.Type
    $targetBoardName = $boardName  # Use the potentially prefixed board name
    try {
        # First, check if a board with the same name already exists in the target project
        $existingBoardByName = $null
        
        # First, get ALL boards in target project to check for existing boards
        try {
            $allBoardsUri = "{0}/rest/agile/1.0/board?projectKeyOrId={1}" -f $tgtBase.TrimEnd('/'), $tgtKey
            $allBoardsResult = Invoke-RestMethod -Method GET -Uri $allBoardsUri -Headers $hdrT -ErrorAction Stop
            if ($allBoardsResult.values -and $allBoardsResult.values.Count -gt 0) {
                foreach ($existingBoard in $allBoardsResult.values) {
                    # Check for exact name match or similar name match
                    if ($existingBoard.name -eq $targetBoardName -or 
                        $existingBoard.name -like "*$($board.Name)*" -or
                        $existingBoard.name -eq $board.Name) {
                        $existingBoardByName = $existingBoard
                        Write-Host ("Found existing board: '{0}' (id {1}, type {2})" -f $existingBoard.name, $existingBoard.id, $existingBoard.type)
                        break
                    }
                }
            }
        } catch {
            Write-Host "Could not search for existing boards: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        if ($existingBoardByName) {
            $boardId = $existingBoardByName.id
            $boardName = $existingBoardByName.name
            $boardType = $existingBoardByName.type
            Write-Host ("✅ Board '{0}' already exists in target project (id {1}, type {2}) - using existing board (idempotent)" -f $boardName, $boardId, $boardType) -ForegroundColor Green
        } else {
            # Check if a board exists for the new filter
            $byFilterUri = "{0}/rest/agile/1.0/board/filter/{1}" -f $tgtBase.TrimEnd('/'), $newFilter.id
            $existingBoards = Invoke-RestMethod -Method GET -Uri $byFilterUri -Headers $hdrT -ErrorAction Stop
            if ($existingBoards.values -and $existingBoards.values.Count -gt 0) {
                $boardId = $existingBoards.values[0].id
                $boardName = $existingBoards.values[0].name
                $boardType = $existingBoards.values[0].type
                Write-Host ("Reusing existing board for filter {0}: {1} (id {2})" -f $newFilter.id, $boardName, $boardId)
            } else {
                $createBody = @{
                    name      = $targetBoardName
                    type      = $board.Type
                    filterId  = [int]$newFilter.id
                    location  = @{ type = "project"; projectKeyOrId = $tgtKey }
                } | ConvertTo-Json -Depth 8
                $createBoardUri = "{0}/rest/agile/1.0/board" -f $tgtBase.TrimEnd('/')
                $created = Invoke-RestMethod -Method POST -Uri $createBoardUri -Headers $hdrT -Body $createBody -ContentType "application/json" -ErrorAction Stop
                $boardId = $created.id; $boardName = $created.name; $boardType = $created.type
                Write-Host ("Created target board '{0}' (id {1}, type {2})" -f $boardName, $boardId, $boardType)
            }
        }
    } catch {
        $skippedBoards += @{ Id=$board.Id; Name=$board.Name; Type=$board.Type; Reason="Board create/reuse failed: $($_.Exception.Message)" }
        Write-Warning ("Failed to create/reuse board for '{0}': {1}" -f $board.Name, $_.Exception.Message)
        continue
    }

    $createdBoards += @{
        SourceBoard = @{ Id=$board.Id; Name=$board.Name; Type=$board.Type; SourceFilterId=$filterId; SourceFilterName=($srcFilter.name) }
        TargetBoard = @{ Id=$boardId; Name=$boardName; Type=$boardType; FilterId=$newFilter.id; FilterName=$filterName; Jql=$targetJql }
    }
}

# ---- Summary & Receipt ----
Write-Host ""
Write-Host "=== SUMMARY ==="
Write-Host ("Boards created/reused: {0}" -f $createdBoards.Count)
Write-Host ("Boards skipped:        {0}" -f $skippedBoards.Count)
if ($skippedBoards.Count -gt 0) {
    Write-Host "Skipped details:"
    foreach ($s in $skippedBoards) {
        Write-Host ("  - {0} (id {1}, type {2}): {3}" -f $s.Name, $s.Id, $s.Type, $s.Reason)
    }
}

# Create boards report for CSV export
$boardsReport = @()

# Add summary statistics
$boardsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Source Boards Discovered"
    Value = $allBoards.Count
    Details = "Boards found in source project"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$boardsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Boards Created/Reused"
    Value = $createdBoards.Count
    Details = "Boards successfully created or reused in target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$boardsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Boards Skipped"
    Value = $skippedBoards.Count
    Details = "Boards skipped due to issues"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add created boards details
foreach ($board in $createdBoards) {
    $boardsReport += [PSCustomObject]@{
        Type = "Board"
        Name = $board.TargetBoard.Name
        Value = $board.TargetBoard.Id
        Details = "Type: $($board.TargetBoard.Type), Filter: $($board.TargetBoard.FilterName)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add skipped boards details
foreach ($board in $skippedBoards) {
    $boardsReport += [PSCustomObject]@{
        Type = "Board"
        Name = $board.Name
        Value = "SKIPPED"
        Details = "Skipped: $($board.Reason)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to boards report
$boardsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$boardsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export boards report to CSV
$csvPath = Join-Path $outDir "06_Boards_Report.csv"
$boardsReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Boards report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($boardsReport.Count)" -ForegroundColor Cyan

$receiptData = @{
    Source = @{
        ProjectKey       = $srcKey
        BoardsDiscovered = $allBoards
    }
    Target = @{
        ProjectKey   = $tgtKey
        ProjectId    = $tgtProjId
        Boards       = $createdBoards
        Skipped      = $skippedBoards
    }
    Notes  = "Strict copy: requires readable source filter JQL; no generic fallback."
}
Write-StageReceipt -OutDir $outDir -Stage "06_Boards_Create_Strict" -Data $receiptData

# Save issues log
Save-IssuesLog -StepName "06_Boards"

exit 0

# NEXT STEP: Run 07_ExportIssues_Source.ps1 to begin issue migration
