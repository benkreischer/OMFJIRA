# 04_ComponentsAndLabels.ps1 - Copy Components from Source and Create from Labels (IDEMPOTENT)
#
# PURPOSE: Copy actual components from source project AND create additional components from labels.
#
# WHAT IT DOES:
# - **DELETES all existing components in target project (idempotency)**
# - Copies ALL components from the source project to the target project (with descriptions)
# - Collects labels used by issues in the SOURCE project (and only that project)
# - Creates additional components in the TARGET project from label names (if not already created)
# - Writes a receipt with what was created/skipped and label usage stats
#
# IDEMPOTENT: Safe to re-run - deletes all existing components first
#
# NEXT STEP: Run 05_Versions.ps1 to set up project versions
#
param(
    [string] $ParametersPath,
    [switch] $DryRun
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "_common.ps1")
. (Join-Path $here "_terminal_logging.ps1")

$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok   = $p.SourceEnvironment.ApiToken
$srcKey   = $p.ProjectKey
$srcHdr   = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail= $p.TargetEnvironment.Username
$tgtTok  = $p.TargetEnvironment.ApiToken
$tgtKey  = $p.TargetEnvironment.ProjectKey
$tgtHdr  = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

# Set up step-specific output directory
$outDir = $p.OutputSettings.OutputDirectory
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = ".\out" }

# Ensure the base output directory exists
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output directory: $outDir" -ForegroundColor Green
}

# Clean up ONLY files from previous failed attempts of THIS step (targeted cleanup)
$projectKey = $p.ProjectKey
$projectExportDir = Join-Path ".\projects" $projectKey
if (Test-Path $projectExportDir) {
    $projectOutDir = Join-Path $projectExportDir "out"
    if (Test-Path $projectOutDir) {
        # Only clean up the exports04 folder (step-specific cleanup)
        $exports04Dir = Join-Path $projectOutDir "exports04"
        if (Test-Path $exports04Dir) {
            Write-Host "Cleaning up previous step 04 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports04Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports04 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder (exports04 for step 04)
$stepExportsDir = Join-Path $outDir "exports04"
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Initialize issues logging
Initialize-IssuesLog -StepName "04_Components" -OutDir $stepExportsDir

# Set step start time
$script:StepStartTime = Get-Date

Write-Host "=== COPY COMPONENTS FROM SOURCE & CREATE FROM LABELS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"

# --- Helpers ---
function Invoke-JqlSearchPage {
    param(
        [string] $Base,
        [hashtable] $Hdr,
        [string] $Jql,
        [string] $NextPageToken,
        [int] $MaxResults,
        [int] $StartAt = 0
    )
    $baseTrim = $Base.TrimEnd('/')
    # Primary: new enhanced endpoint
    $uri = "$baseTrim/rest/api/3/search/jql"
    $body = @{
        jql        = $Jql
        maxResults = $MaxResults
        fields     = @("labels")
    }
    if ($NextPageToken) { $body.nextPageToken = $NextPageToken }
    $json = $body | ConvertTo-Json -Depth 6

    try {
        return Invoke-JiraWithRetry -Method POST -Uri $uri -Headers $Hdr -Body $json -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
    } catch {
        # Fallback for older tenants if needed
        $status = $null
        try { $status = [int]$_.Exception.Response.StatusCode } catch {}
        if ($status -in 404,410,405) {
            # Old POST /search with startAt pagination
            $fallbackBody = @{
                jql        = $Jql
                startAt    = $StartAt
                maxResults = $MaxResults
                fields     = @("labels")
            } | ConvertTo-Json -Depth 6
            $fallbackUri = "$baseTrim/rest/api/3/search"
            return Invoke-JiraWithRetry -Method POST -Uri $fallbackUri -Headers $Hdr -Body $fallbackBody -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        }

        $msg = $_.Exception.Message
        try {
            $resp = $_.Exception.Response
            if ($resp -and $resp.GetResponseStream()) {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $details = $reader.ReadToEnd()
                $msg = "$msg`nResponse: $details"
            }
        } catch {}
        throw "Search request failed: $msg"
    }
}

function Sanitize-ComponentName {
    param([string] $Name)
    if (-not $Name) { return $Name }
    $n = $Name.Trim()
    if ($n.Length -gt 255) { $n = $n.Substring(0,255) }
    return $n
}

# --- Get project details ---
try {
    $srcProject = Invoke-Jira -Method GET -BaseUrl $srcBase -Path "rest/api/3/project/$srcKey" -Headers $srcHdr
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Source project: $($srcProject.name) (id=$($srcProject.id))"
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve project details: $($_.Exception.Message)"
}

# --- First, copy actual components from source project ---
Write-Host ""
Write-Host "=== COPYING COMPONENTS FROM SOURCE PROJECT ==="
$sourceComponents = @()
try {
    $uri = "$($srcBase.TrimEnd('/'))/rest/api/3/project/$($srcProject.id)/components"
    $sourceComponents = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
    if (-not $sourceComponents) { $sourceComponents = @() }
    Write-Host ("Found {0} components in source project" -f $sourceComponents.Count)
} catch {
    Write-Warning "Could not retrieve source components: $($_.Exception.Message)"
    $sourceComponents = @()
}

# --- Capture labels ONLY from the source project issues (new pagination: nextPageToken) ---
Write-Host ""
Write-Host "=== CAPTURING LABELS FROM SOURCE PROJECT ISSUES ==="
$allLabels      = @{}  # canonicalName -> @{ Name; UsageCount; FirstSeenIn }
$labelKeyIndex  = @{}  # lower(name)    -> canonicalName
$nextToken      = $null
$startAt        = 0
$maxResults     = 1000
$issuesScanned  = 0
$jql            = "project = `"$srcKey`" AND labels IS NOT EMPTY AND resolution IS EMPTY"
$useLegacyPagination = $false

do {
    if ($useLegacyPagination) {
        Write-Host ("Querying issues (maxResults={0}) startAt={1}" -f $maxResults, $startAt)
        $resp = Invoke-JqlSearchPage -Base $srcBase -Hdr $srcHdr -Jql $jql -MaxResults $maxResults -StartAt $startAt
    } else {
        Write-Host ("Querying issues (maxResults={0}) nextPageToken={1}" -f $maxResults, $(if ($nextToken) { $nextToken } else { "<none>" }))
        $resp = Invoke-JqlSearchPage -Base $srcBase -Hdr $srcHdr -Jql $jql -NextPageToken $nextToken -MaxResults $maxResults
    }

    # Two possible shapes:
    # - Enhanced: { issues: [...], isLast: bool, nextPageToken: "..." }
    # - Legacy fallback: { issues: [...], startAt: n, total: n, maxResults: n }
    $issues = $resp.issues
    if ($issues) {
        foreach ($issue in $issues) {
            $issuesScanned++
            $labels = $issue.fields.labels
            if (-not $labels) { continue }
            foreach ($label in $labels) {
                if (-not $label) { continue }
                $key = $label.ToLowerInvariant()
                if (-not $labelKeyIndex.ContainsKey($key)) {
                    $labelKeyIndex[$key] = $label
                    $allLabels[$label] = @{
                        Name        = $label
                        UsageCount  = 1
                        FirstSeenIn = $issue.key
                    }
                } else {
                    $canon = $labelKeyIndex[$key]
                    $allLabels[$canon].UsageCount++
                }
            }
        }
    }

    # Determine pagination method and next page
    if ($resp.PSObject.Properties.Name -contains 'isLast') {
        # Enhanced pagination
        if ([bool]$resp.isLast) { 
            $nextToken = $null 
        } else { 
            $nextToken = $resp.nextPageToken 
        }
    } elseif ($resp.PSObject.Properties.Name -contains 'total' -and $resp.PSObject.Properties.Name -contains 'startAt') {
        # Legacy pagination - continue fetching
        $useLegacyPagination = $true
        $startAt = $resp.startAt + $resp.maxResults
        if ($startAt -ge $resp.total -or $issues.Count -eq 0) {
            $nextToken = $null
        } else {
            $nextToken = "continue"  # Flag to continue loop
        }
    } else {
        $nextToken = $null
    }
} while ($nextToken)

Write-Host ("Captured {0} unique labels from project '{1}' (issues scanned: {2})" -f $allLabels.Count, $srcKey, $issuesScanned)

# --- Retrieve existing target components (by project) ---
Write-Host ""
Write-Host "=== RETRIEVING EXISTING TARGET COMPONENTS ==="
$tgtComponents = @()
try {
    $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$($tgtProject.id)/components"
    $tgtComponents = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
    if (-not $tgtComponents) { $tgtComponents = @() }
    Write-Host ("Found {0} existing components in target project" -f $tgtComponents.Count)
} catch {
    Write-Warning "Could not retrieve target components: $($_.Exception.Message)"
    $tgtComponents = @()
}

# --- DELETE all existing components to ensure idempotency ---
if ($tgtComponents.Count -gt 0) {
    # Check if deletion is enabled in config
    $deleteComponents = $p.MigrationSettings.DeleteTargetComponentsBeforeImport
    if (-not $deleteComponents) {
        Write-Host ""
        Write-Host "=== SKIPPING COMPONENT DELETION ===" -ForegroundColor Yellow
        Write-Host "MigrationSettings.DeleteTargetComponentsBeforeImport is not enabled" -ForegroundColor Yellow
        Write-Host "Skipping deletion of $($tgtComponents.Count) existing components" -ForegroundColor Yellow
        Write-Host "This may result in duplicate components if re-running the migration" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "=== DELETING EXISTING COMPONENTS (IDEMPOTENCY) ===" -ForegroundColor Yellow
        Write-Host "Deleting $($tgtComponents.Count) existing components to ensure clean state..."
    
    $deletedCount = 0
    $failedDeletes = 0
    
    foreach ($comp in $tgtComponents) {
        try {
            $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/component/$($comp.id)"
            Invoke-JiraWithRetry -Method DELETE -Uri $deleteUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 | Out-Null
            $deletedCount++
            Write-Host "  ✓ Deleted: $($comp.name)" -ForegroundColor Gray
        } catch {
            $failedDeletes++
            Write-Warning "  ✗ Failed to delete '$($comp.name)': $($_.Exception.Message)"
        }
    }
    
        Write-Host "Deleted $deletedCount components ($failedDeletes failed)" -ForegroundColor Green
        
        # Clear the components list since we just deleted them all
        $tgtComponents = @()
    }
}

# Case-insensitive lookup for existing component names (should be empty after deletion)
$existingCompIndex = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($c in $tgtComponents) { if ($c.name) { [void]$existingCompIndex.Add($c.name.ToLowerInvariant()) } }

# --- Create components in target: first from source components, then from labels ---
Write-Host ""
Write-Host "=== CREATING COMPONENTS IN TARGET ==="
$createdComponents  = @()
$existingComponents = @()
$failedComponents   = @()
$componentSourceMap = @{}  # Track where each component came from

# First, create components from source project
Write-Host "Creating components from source project..."
foreach ($srcComp in $sourceComponents) {
    if (-not $srcComp.name) { continue }
    $sanitized = Sanitize-ComponentName $srcComp.name
    if (-not $sanitized) { continue }

    $lc = $sanitized.ToLowerInvariant()
    if ($existingCompIndex.Contains($lc)) {
        Write-Host ("  Component '{0}' already exists in target (from source component)" -f $sanitized)
        $existing = $tgtComponents | Where-Object { $_.name -ieq $sanitized } | Select-Object -First 1
        $existingComponents += @{ 
            Name = $sanitized
            Source = "SourceComponent"
            SourceId = $srcComp.id
            TargetId = $(if ($existing) { $existing.id } else { $null })
        }
        continue
    }

    # Create the component
    $description = if ($srcComp.PSObject.Properties.Name -contains 'description' -and $srcComp.description) { 
        $srcComp.description 
    } else { 
        "Component copied from source project $srcKey"
    }
    
    $componentPayload = @{
        name        = $sanitized
        description = $description
        project     = $tgtKey
    }
    
    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/component"
        $created = Invoke-JiraWithRetry -Method POST -Uri $uri -Headers $tgtHdr -Body ($componentPayload | ConvertTo-Json -Depth 6) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        Write-Host ("  ✅ Created component '{0}' from source (id={1})" -f $sanitized, $created.id)
        $createdComponents += @{
            Name = $sanitized
            Source = "SourceComponent"
            SourceId = $srcComp.id
            TargetId = $created.id
            Description = $description
        }
        [void]$existingCompIndex.Add($lc)
        $componentSourceMap[$lc] = "SourceComponent"
    } catch {
        Write-Warning ("  ❌ Failed to create component '{0}': {1}" -f $sanitized, $_.Exception.Message)
        $failedComponents += @{ Name = $sanitized; Reason = $_.Exception.Message; Source = "SourceComponent" }
        
        # Log this error
        Write-IssueLog -Type Error -Category "Component Creation Failed" `
            -Message "Failed to create component '$sanitized': $($_.Exception.Message)" `
            -Details @{
                ComponentName = $sanitized
                Source = "SourceComponent"
            }
    }
}

# Reload target components to get updated IDs (in case we created new ones)
try {
    $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$($tgtProject.id)/components"
    $tgtComponents = Invoke-JiraWithRetry -Method GET -Uri $uri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
    if (-not $tgtComponents) { $tgtComponents = @() }
} catch {
    Write-Warning "Could not reload target components: $($_.Exception.Message)"
}

# Then, create components from labels (if not already created)
Write-Host ""
Write-Host "Creating components from labels..."
foreach ($labelName in $allLabels.Keys) {
    $labelInfo = $allLabels[$labelName]
    $sanitized = Sanitize-ComponentName $labelName
    if (-not $sanitized) { continue }

    $lc = $sanitized.ToLowerInvariant()
    if ($existingCompIndex.Contains($lc)) {
        $sourceType = if ($componentSourceMap.ContainsKey($lc)) { $componentSourceMap[$lc] } else { "AlreadyExisted" }
        Write-Host ("  Component '{0}' already exists in target (from {1})" -f $sanitized, $sourceType)
        $existing = $tgtComponents | Where-Object { $_.name -ieq $sanitized } | Select-Object -First 1
        $existingComponents += @{
            LabelName  = $labelName
            Source     = "Label-AlreadyExists"
            TargetId   = $(if ($existing) { $existing.id } else { $null })
            Name       = $(if ($existing) { $existing.name } else { $sanitized })
            UsageCount = $labelInfo.UsageCount
        }
        continue
    }

    $createBody = @{
        name        = $sanitized
        project     = $tgtKey
        description = "Component created from label '$labelName' (used $($labelInfo.UsageCount) times in source project $($srcProject.key))"
    }

    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/component"
        $newComp = Invoke-JiraWithRetry -Method POST -Uri $uri -Headers $tgtHdr -Body ($createBody | ConvertTo-Json -Depth 5) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        Write-Host ("  ✅ Created component '{0}' from label (id={1})" -f $sanitized, $newComp.id)
        $createdComponents += @{
            LabelName   = $labelName
            Source      = "Label"
            TargetId    = $newComp.id
            Name        = $sanitized
            UsageCount  = $labelInfo.UsageCount
            Description = $createBody.description
        }
        [void]$existingCompIndex.Add($lc)
        $componentSourceMap[$lc] = "Label"
        $tgtComponents += $newComp
    } catch {
        $msg = $_.Exception.Message
        try {
            $resp = $_.Exception.Response
            if ($resp -and $resp.GetResponseStream()) {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $details = $reader.ReadToEnd()
                $msg = "$msg`nResponse: $details"
            }
        } catch {}
        Write-Warning ("  ❌ Failed: '{0}' — {1}" -f $sanitized, $msg)
        $failedComponents += @{
            LabelName   = $labelName
            Error       = $msg
            UsageCount  = $labelInfo.UsageCount
        }
    }
}

# --- Reporting ---
$sortedLabels = $allLabels.Values | Sort-Object UsageCount -Descending

Write-Host ""
Write-Host "=== SUMMARY ==="
Write-Host ("Source components found:  {0}" -f $sourceComponents.Count)
Write-Host ("Labels captured (unique): {0}" -f $allLabels.Count)
Write-Host ("Components created:       {0}" -f $createdComponents.Count)
$fromSource = @($createdComponents | Where-Object { $_.Source -eq "SourceComponent" })
$fromLabels = @($createdComponents | Where-Object { $_.Source -eq "Label" })
Write-Host ("  - From source project:  {0}" -f $fromSource.Count)
Write-Host ("  - From labels:          {0}" -f $fromLabels.Count)
Write-Host ("Components existed:       {0}" -f $existingComponents.Count)
Write-Host ("Components failed:        {0}" -f $failedComponents.Count)

if ($sortedLabels -and $sortedLabels.Count -gt 0) {
    Write-Host ""
    Write-Host "Top 10 labels by usage:"
    $sortedLabels | Select-Object -First 10 | ForEach-Object {
        Write-Host ("  - {0} (used {1})" -f $_.Name, $_.UsageCount)
    }
}

# Create components and labels report for CSV export
$componentsLabelsReport = @()

# Add summary statistics
$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Source Components Found"
    Value = $sourceComponents.Count
    Details = "Components found in source project"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Labels Captured"
    Value = $allLabels.Count
    Details = "Unique labels found in source issues"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Components"
    Value = $createdComponents.Count
    Details = "Total components created in target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Created From Source"
    Value = $fromSource.Count
    Details = "Components copied from source project"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Existing Components"
    Value = $existingComponents.Count
    Details = "Components that already existed"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Failed Components"
    Value = $failedComponents.Count
    Details = "Components that failed to create"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add source components details
foreach ($comp in $sourceComponents) {
    $componentsLabelsReport += [PSCustomObject]@{
        Type = "Component"
        Name = "$($comp.name) (Source)"
        Value = $comp.id
        Details = "Found in source project"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add created components details
foreach ($comp in $createdComponents) {
    $componentsLabelsReport += [PSCustomObject]@{
        Type = "Component"
        Name = $comp.Name
        Value = $comp.TargetId
        Details = "Created from $($comp.Source)$(if ($comp.PSObject.Properties.Name -contains 'LabelName' -and $comp.LabelName) { " (label: $($comp.LabelName))" })"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add existing components details (only if not already in created components)
foreach ($comp in $existingComponents) {
    # Check if this component was already added as a created component
    $alreadyAdded = $createdComponents | Where-Object { $_.Name -eq $comp.Name -and $_.TargetId -eq $comp.TargetId }
    if (-not $alreadyAdded) {
        $componentsLabelsReport += [PSCustomObject]@{
            Type = "Component"
            Name = "$($comp.Name) (Existing)"
            Value = $comp.TargetId
            Details = "Already existed in target"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
}

# Add failed components details
foreach ($comp in $failedComponents) {
    $componentsLabelsReport += [PSCustomObject]@{
        Type = "Component"
        Name = "$($comp.Name) (Failed)"
        Value = "FAILED"
        Details = "Failed to create: $($comp.Error)"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add top labels by usage
if ($sortedLabels -and $sortedLabels.Count -gt 0) {
    $sortedLabels | Select-Object -First 20 | ForEach-Object {
        # Get the label ID from Jira API
        $labelId = $null
        try {
            $labelUri = "$($srcBase.TrimEnd('/'))/rest/api/3/label?name=$([uri]::EscapeDataString($_.Name))"
            $labelResponse = Invoke-JiraWithRetry -Method GET -Uri $labelUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
            if ($labelResponse -and $labelResponse.id) {
                $labelId = $labelResponse.id
            }
        } catch {
            # Label ID not found, continue without it
        }
        
        # Smart pluralization for issue/issues
        $issueText = if ($_.UsageCount -eq 1) { "issue" } else { "issues" }
        
        $componentsLabelsReport += [PSCustomObject]@{
            Type = "Label"
            Name = $_.Name
            Value = if ($labelId) { "In $($_.UsageCount) $issueText, ID $labelId" } else { "In $($_.UsageCount) $issueText" }
            Details = "Used in $($_.UsageCount) issues"
            Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Calculate step total time
$stepDuration = $stepEndTime - $stepStartTime
$totalSeconds = [Math]::Round($stepDuration.TotalSeconds, 0)
$totalHours = [Math]::Floor($totalSeconds / 3600)
$totalMinutes = [Math]::Floor(($totalSeconds % 3600) / 60)
$remainingSeconds = $totalSeconds % 60
$durationFormatted = "{0:00}h : {1:00}m : {2:00}s" -f $totalHours, $totalMinutes, $remainingSeconds

# Add step timing information to components and labels report
$componentsLabelsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = "Step execution started at $($stepStartTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = "Step execution completed at $($stepEndTime.ToString("yyyy-MM-dd HH:mm:ss"))"
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$componentsLabelsReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Total Time"
    Value = $durationFormatted
    Details = "Step total time"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Convert to 3-column format for CSV export
$csvReport = @()
foreach ($item in $componentsLabelsReport) {
    $csvReport += [PSCustomObject]@{
        Variable = $item.Name
        Value = $item.Value
        Timestamp = $item.Timestamp
    }
}

# Export components and labels report to CSV
$csvPath = Join-Path $stepExportsDir "04_Components_Report.csv"
$csvReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Components and labels report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($csvReport.Count)" -ForegroundColor Cyan

# --- Receipt ---
$receiptData = @{
    SourceProject           = @{ key=$srcKey; name=$srcProject.name; id=$srcProject.id }
    TargetProject           = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    SourceComponentsFound   = $sourceComponents.Count
    LabelsCaptured          = $allLabels.Count
    CreatedComponents       = $createdComponents.Count
    CreatedFromSource       = $fromSource.Count
    CreatedFromLabels       = $fromLabels.Count
    ExistingComponents      = $existingComponents.Count
    FailedComponents        = $failedComponents.Count
    CreatedComponentDetails = $createdComponents
    ExistingComponentDetails= $existingComponents
    FailedComponentDetails  = $failedComponents
    LabelDetails            = $sortedLabels
    ComponentMapping        = ($createdComponents + $existingComponents) | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            TargetId = $_.TargetId
            Source = $_.Source
            LabelName = $(if ($_.PSObject.Properties.Name -contains 'LabelName') { $_.LabelName } else { $null })
        }
    }
}
Write-StageReceipt -OutDir $stepExportsDir -Stage "04_Components" -Data $receiptData

# Save issues log
Save-IssuesLog -StepName "04_Components"

exit 0

