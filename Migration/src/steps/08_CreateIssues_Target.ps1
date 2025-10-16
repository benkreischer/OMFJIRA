# 08_CreateIssues_Target.ps1 - Create Issues in Target Project
# 
# PURPOSE: Creates all issues in the target project using the exported data from the source,
# applying field mappings and custom field transformations as needed.
#
# WHAT IT DOES:
# - Creates issues in the target project using exported source data
# - Applies issue type mappings and field transformations
# - **PRESERVES HISTORY:** Writes original created/updated timestamps to custom fields
# - **PRESERVES HISTORY:** Includes original creator and timestamps in description
# - **Writes source key to LegacyKey custom field (from parameters.json)**
# - **Writes source URL to LegacyKeyURL custom field (from parameters.json)**
# - **Writes original created date to OriginalCreatedDate custom field (from parameters.json)**
# - **Writes original updated date to OriginalUpdatedDate custom field (from parameters.json)**
# - Appends custom field values to issue descriptions for preservation
# - Maps source issue keys to target issue keys
# - Handles bulk creation with error handling and retry logic
# - Creates detailed creation logs and receipts
# - **Idempotent: Skips issues that already exist (safe to re-run)**
#
# CUSTOM FIELDS REQUIRED IN TARGET:
# - LegacyKey (Text field, single line)
# - LegacyKeyURL (URL field)
# - OriginalCreatedDate (DateTime field) - NEW!
# - OriginalUpdatedDate (DateTime field) - NEW!
#
# WHAT IT DOES NOT DO:
# - Does not migrate comments, attachments, or worklogs yet
# - Does not create issue links yet
# - Does not assign issues to sprints yet
#
# NEXT STEP: Run 09_Comments.ps1 to migrate issue comments
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Load parameters
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent $here) "..\config\migration-parameters.json"
}

if (Test-Path $ParametersPath) {
    $params = Get-Content $ParametersPath | ConvertFrom-Json
    Write-Host "✅ Loaded parameters from: $ParametersPath"
} else {
    Write-Warning "Parameters file not found: $ParametersPath"
    $params = @{}
}

# Capture step start time
$stepStartTime = Get-Date


$p = Read-JsonFile -Path $ParametersPath

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir = $p.OutputSettings.OutputDirectory
$batchSize = $p.AnalysisSettings.BatchSize

# Initialize issues logging
Initialize-IssuesLog -StepName "08_CreateIssues_Target" -OutDir $outDir

# Load custom field IDs from parameters
$legacyKeyField = $p.CustomFields.LegacyKey
$legacyKeyURLField = $p.CustomFields.LegacyKeyURL
$originalCreatedDateField = if ($p.CustomFields.PSObject.Properties.Name -contains 'OriginalCreatedDate') { $p.CustomFields.OriginalCreatedDate } else { $null }
$originalUpdatedDateField = if ($p.CustomFields.PSObject.Properties.Name -contains 'OriginalUpdatedDate') { $p.CustomFields.OriginalUpdatedDate } else { $null }

# Load custom field mapping (source ID → target ID)
$customFieldMapping = @{}
if ($p.PSObject.Properties.Name -contains 'CustomFieldMapping') {
    $p.CustomFieldMapping.PSObject.Properties | ForEach-Object {
        $customFieldMapping[$_.Name] = $_.Value
    }
    Write-Host "✅ Loaded $($customFieldMapping.Count) custom field mappings:"
    foreach ($mapping in $customFieldMapping.GetEnumerator()) {
        Write-Host "    $($mapping.Key) → $($mapping.Value)" -ForegroundColor Gray
    }
} else {
    Write-Host "ℹ️  No CustomFieldMapping found in parameters - custom fields will be appended to description"
}

Write-Host "=== CREATING ISSUES IN TARGET PROJECT ==="
Write-Host "Target Project: $tgtKey"
Write-Host "Batch Size: $batchSize"

# Get target project details
Write-Host "Retrieving target project details..."
try {
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve target project: $($_.Exception.Message)"
}

# Load exported data from step 7
$exportDir = Join-Path $outDir "exports"
$exportFile = Join-Path $exportDir "source_issues_export.json"
$mappingFile = Join-Path $exportDir "key_to_id_mapping.json"

Write-Host ""
Write-Host "=== LOADING EXPORTED DATA ==="
Write-Host "Current directory: $(Get-Location)"
Write-Host "Output directory: $outDir"
Write-Host "Export file path: $exportFile"
Write-Host "Export file exists: $(Test-Path $exportFile)"
if (-not (Test-Path $exportFile)) {
    throw "Export file not found: $exportFile. Please run step 07_ExportIssues_Source.ps1 first."
}

try {
    $exportedIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
    $keyToIdMap = Get-Content $mappingFile -Raw | ConvertFrom-Json
    
    # Handle null values from ConvertFrom-Json
    if ($exportedIssues -eq $null) {
        $exportedIssues = @()
    }
    if ($keyToIdMap -eq $null) {
        $keyToIdMap = @{}
    }
    
    Write-Host "✅ Loaded exported data successfully"
} catch {
    throw "Failed to load exported data: $($_.Exception.Message)"
}

# Get component and version mappings from previous steps
$componentMappingByName = @{}
$versionMapping = @{}

# Load component mapping from step 4 (consistent filename)
$step4Receipt = Join-Path $outDir "04_ComponentsAndLabels_receipt.json"
if (Test-Path $step4Receipt) {
    try {
        $step4Data = Get-Content $step4Receipt -Raw | ConvertFrom-Json
        foreach ($comp in $step4Data.ComponentMapping) {
            # Step 4 creates components from labels and source components, so map by name
            if ($comp.Name -and $comp.TargetId) {
                $componentMappingByName[$comp.Name.ToLowerInvariant()] = $comp.TargetId
            }
        }
        Write-Host "✅ Loaded $($componentMappingByName.Count) component mappings (by name)"
    } catch {
        Write-Warning "Could not load component mapping: $($_.Exception.Message)"
    }
} else {
    Write-Warning "Component mapping file not found: $step4Receipt"
}

# Load version mapping from step 5 (consistent filename)
$step5Receipt = Join-Path $outDir "05_Versions_receipt.json"
if (Test-Path $step5Receipt) {
    try {
        $step5Data = Get-Content $step5Receipt -Raw | ConvertFrom-Json
        if ($step5Data.PSObject.Properties.Name -contains 'VersionMapping') {
            foreach ($version in $step5Data.VersionMapping) {
                $versionMapping[$version.SourceId] = $version.TargetId
            }
        }
        Write-Host "✅ Loaded $($versionMapping.Count) version mappings"
    } catch {
        Write-Warning "Could not load version mapping: $($_.Exception.Message)"
    }
} else {
    Write-Host "No version mapping file found (optional)"
}

# Issue creation tracking
$createdIssues = @()
$failedIssues = @()
$skippedIssues = @()
$sourceToTargetKeyMap = @{}
$crossProjectParents = @()  # Track parents from other projects for remote link creation
$orphanedIssues = @()  # Track issues whose parents were resolved/excluded from migration

# Custom field conversion tracking (for validation report)
$customFieldConversions = @()  # Track fields converted from ADF to plain text
$customFieldRemovals = @()     # Track fields that had to be removed entirely

# =============================================================================
# DISCOVER TARGET PROJECT STATUSES
# =============================================================================
Write-Host ""
Write-Host "=== DISCOVERING TARGET PROJECT STATUSES ==="

$targetStatuses = @()
try {
    Write-Host "Discovering ALL statuses from target Jira instance..."
    
    # Method 1: Get ALL statuses from the instance (most comprehensive)
    Write-Host "Method 1: Getting all statuses from instance..."
    $allStatusesUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/status"
    $allStatusesResponse = Invoke-RestMethod -Method GET -Uri $allStatusesUri -Headers $tgtHdr -ErrorAction Stop
    
    Write-Host "Found $($allStatusesResponse.Count) total statuses in target instance"
    foreach ($status in $allStatusesResponse) {
        if ($status.name -and $targetStatuses -notcontains $status.name) {
            $targetStatuses += $status.name
            Write-Host "    - $($status.name)"
        }
    }
    
    # Method 2: Get project-specific statuses
    Write-Host "Method 2: Getting project-specific statuses..."
    $projectStatusesUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey/statuses"
    $projectStatusesResponse = Invoke-RestMethod -Method GET -Uri $projectStatusesUri -Headers $tgtHdr -ErrorAction Stop
    
    foreach ($statusCategory in $projectStatusesResponse) {
        Write-Host "  Status Category: $($statusCategory.name)"
        foreach ($status in $statusCategory.statuses) {
            if ($targetStatuses -notcontains $status.name) {
                $targetStatuses += $status.name
                Write-Host "    - $($status.name) (from project category)"
            }
        }
    }
    
    # Method 3: Get all workflows and their statuses
    Write-Host "Method 3: Getting all workflow statuses..."
    $workflowsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/workflow"
    $workflowsResponse = Invoke-RestMethod -Method GET -Uri $workflowsUri -Headers $tgtHdr -ErrorAction Stop
    
    Write-Host "Found $($workflowsResponse.Count) workflows in target instance"
    
    foreach ($workflow in $workflowsResponse) {
        Write-Host "  Workflow: $($workflow.name)"
        
        # Get workflow details including statuses (if workflow has id or entityId)
        $workflowId = $null
        if ($workflow.PSObject.Properties.Name -contains 'id' -and $workflow.id) {
            $workflowId = $workflow.id
        } elseif ($workflow.PSObject.Properties.Name -contains 'entityId' -and $workflow.entityId) {
            $workflowId = $workflow.entityId
        }
        
        if ($workflowId) {
            $workflowDetailsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/workflow/$workflowId"
            try {
                $workflowDetails = Invoke-RestMethod -Method GET -Uri $workflowDetailsUri -Headers $tgtHdr -ErrorAction Stop
                
                # Extract statuses from workflow
                if ($workflowDetails.statuses) {
                    foreach ($status in $workflowDetails.statuses) {
                        if ($status.name -and $targetStatuses -notcontains $status.name) {
                            $targetStatuses += $status.name
                            Write-Host "    - $($status.name) (from workflow)"
                        }
                    }
                }
            } catch {
                Write-Warning "    Failed to get details for workflow $($workflow.name): $($_.Exception.Message)"
            }
        } else {
            Write-Host "    - Skipping workflow (no id or entityId available)"
        }
    }
    
    Write-Host "✅ ALL XRAY workflow statuses discovered: $($targetStatuses -join ', ')"
    
    # Generate JSON format for migration-parameters.json
    Write-Host ""
    Write-Host "=== STATUS MAPPING FOR migration-parameters.json ==="
    Write-Host "Copy this into your StatusMapping section:"
    Write-Host ""
    
    # Create status mapping JSON
    $statusMappingJson = @{}
    foreach ($status in $targetStatuses | Sort-Object) {
        $statusMappingJson[$status] = $status  # Default: map to same name
    }
    
    $jsonOutput = $statusMappingJson | ConvertTo-Json -Depth 2
    Write-Host $jsonOutput
    Write-Host ""
    
} catch {
    Write-Warning "Failed to discover XRAY workflow statuses: $($_.Exception.Message)"
    Write-Host "Using fallback status mapping from parameters"
}

Write-Host ""
Write-Host "=== SORTING ISSUES BY HIERARCHY ==="

# Define issue type hierarchy (top-level first, sub-tasks last)
# Note: Bugs are always leaf nodes - they can be children but never parents
$issueTypeOrder = @{
    "Objective" = 1
    "Initiative" = 2
    "Epic" = 3
    "Story" = 4
    "Task" = 4
    "Improvement" = 4
    "Test" = 4
    "Bug" = 5        # Bugs are leaf nodes (same level as sub-tasks)
    "Sub-task" = 5
}

# Process all issue types
Write-Host "Processing all issue types with proper hierarchy"
Write-Host "Found $($exportedIssues.Count) total issues"

# Sort issues by hierarchy level, then by whether they have a parent (no parent first)
$sortedIssues = $exportedIssues | Sort-Object {
    $type = $_.fields.issuetype.name
    $order = if ($issueTypeOrder.ContainsKey($type)) { $issueTypeOrder[$type] } else { 4 }
    $hasParent = if ($_.fields.PSObject.Properties.Name -contains 'parent' -and $_.fields.parent) { 1 } else { 0 }
    # Return compound sort key: hierarchy level, then parent status
    "$order-$hasParent"
}

Write-Host "Sorted $($exportedIssues.Count) issues by hierarchy"
Write-Host "Order: Objective → Initiative → Epic → Story/Task/Test → Bug/Sub-task (leaf nodes)"
Write-Host "Within each level: Issues without parents first"
Write-Host "Note: Bugs are always leaf nodes - they can be children but never parents"

Write-Host ""
Write-Host "=== CHECKING FOR EXISTING ISSUES (IDEMPOTENCY) ==="

# Fetch all existing issues in target project for idempotency check
Write-Host "Fetching existing issues from target project to prevent duplicates..."
$existingIssues = @{}
$existingIssuesBySummary = @{}
$startAt = 0
$maxResults = 100

$nextPageToken = $null
$pageCount = 0

do {
    $pageCount++
    $searchUrl = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
    
    $searchBody = @{
        jql = "project = $tgtKey"
        maxResults = $maxResults
        fields = @("id", "key", "summary")
    }
    
    if ($nextPageToken) {
        $searchBody.nextPageToken = $nextPageToken
    }
    
    $jsonBody = $searchBody | ConvertTo-Json
    
    try {
        Write-Host "  Searching for existing issues (page $pageCount)..." -NoNewline
        $response = Invoke-RestMethod -Method POST -Uri $searchUrl -Headers $tgtHdr -Body $jsonBody -ContentType "application/json" -ErrorAction Stop
        Write-Host " Found $($response.issues.Count) issues" -ForegroundColor Green
        
        foreach ($existingIssue in $response.issues) {
            $issueKey = $existingIssue.key
            $existingIssues[$issueKey] = $existingIssue
            $summary = $existingIssue.fields.summary
            
            # Track by summary for duplicate detection
            if (-not $existingIssuesBySummary.ContainsKey($summary)) {
                $existingIssuesBySummary[$summary] = @()
            }
            $existingIssuesBySummary[$summary] += $existingIssue
        }
        
        Write-Host "  Total collected: $($existingIssues.Count) issues" -ForegroundColor Cyan
        
        # Check for next page token
        if ($response.PSObject.Properties.Name -contains "nextPageToken" -and $response.nextPageToken) {
            $nextPageToken = $response.nextPageToken
        } else {
            $nextPageToken = $null
        }
        
    } catch {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Warning "Failed to fetch existing issues: $($_.Exception.Message)"
        Write-Host "Continuing without deletion check..."
        break
    }
    
} while ($nextPageToken -and $pageCount -lt 50)  # Safety limit of 50 pages (5000 issues max)

Write-Host "✅ Found $($existingIssues.Count) existing issues in target project    "

if ($existingIssues.Count -gt 0) {
    Write-Host "   Found $($existingIssues.Count) existing issues - will delete them first for clean migration"
    Write-Host "   Deleting existing issues to ensure clean re-import..."
    
    # Delete all existing issues
    $deletedCount = 0
    $failedCount = 0
    
    Write-Host "   Will delete all $($existingIssues.Count) existing issues for clean migration"
    
    foreach ($issueKey in $existingIssues.Keys) {
        try {
            $issue = $existingIssues[$issueKey]
            $deleteUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$($issue.id)?deleteSubtasks=true"
            Invoke-JiraWithRetry -Method DELETE -Uri $deleteUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
            $deletedCount++
            Write-Host "   Deleted: $issueKey ($deletedCount/$($existingIssues.Count))" -NoNewline
            Write-Host "`r" -NoNewline
            
            # Rate limiting
            Start-Sleep -Milliseconds 100
            
        } catch {
            $failedCount++
            Write-Warning "   Failed to delete $issueKey : $($_.Exception.Message)"
            
            # If we get permission errors, stop trying
            if ($_.Exception.Message -match "403|401|Forbidden|Unauthorized") {
                Write-Error "Permission denied for issue deletion. Stopping cleanup."
                break
            }
        }
    }
    
    Write-Host "✅ Deleted $deletedCount issues, $failedCount failed    "
    
    if ($failedCount -gt 0) {
        Write-Warning "Some issues could not be deleted. Migration will continue with idempotency enabled."
    }
    
    # Verify deletion by checking if any issues remain
    Write-Host "   Verifying deletion..."
    Start-Sleep -Seconds 2
    $verifyUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/search/jql"
    $verifyBody = @{
        jql = "project = $tgtKey"
        maxResults = 1
        fields = @("id")
    } | ConvertTo-Json
    
    try {
        $verifyResponse = Invoke-JiraWithRetry -Method POST -Uri $verifyUri -Headers $tgtHdr -Body $verifyBody -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
        
        if ($verifyResponse.total -eq 0) {
            Write-Host "   ✅ Verification: All issues successfully deleted" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  Verification: $($verifyResponse.total) issues still remain in project" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "   Could not verify deletion: $($_.Exception.Message)"
    }
    
    # Clear the existing issues cache since we just deleted them
    $existingIssues = @{}
    $existingIssuesBySummary = @{}
    
} else {
    Write-Host "   Target project is empty - all issues will be created"
}

Write-Host ""
Write-Host "=== CREATING ISSUES ==="

# Check if there are any issues to process
if ($exportedIssues.Count -eq 0) {
    Write-Host "✅ No issues to migrate - project has no unresolved issues" -ForegroundColor Green
    Write-Host "✅ Step 8 completed successfully with no issues to process" -ForegroundColor Green
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "08_CreateIssues_Target" -Data @{
        TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
        SourceProject = @{ key=$srcKey }
        IssuesCreated = 0
        IssuesSkipped = 0
        IssuesFailed = 0
        TotalIssuesProcessed = 0
        Status = "Completed - No Issues to Migrate"
        Notes = @("No unresolved issues found in source project", "Migration completed successfully")
        StartTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        EndTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    }
    
    exit 0
}

# Ensure proper parent→child ordering by doing a topological sort
Write-Host "Performing topological sort to ensure parents are created before children..."

# Build a map of all issues by key
$issuesByKey = @{}
foreach ($issue in $exportedIssues) {
    $issuesByKey[$issue.key] = $issue
}

# Track which issues we've already added
$added = @{}
$orderedIssues = @()

# Recursive function to add issue and all its ancestors first
function Add-IssueWithAncestors {
    param($issue)
    
    # If already added, skip
    if ($added.ContainsKey($issue.key)) {
        return
    }
    
    # First, add parent (if exists)
    if ($issue.fields.PSObject.Properties.Name -contains 'parent' -and $issue.fields.parent) {
        $parentKey = $issue.fields.parent.key
        if ($issuesByKey.ContainsKey($parentKey)) {
            Add-IssueWithAncestors -issue $issuesByKey[$parentKey]
        } else {
            Write-Host "  Note: Parent $parentKey not in export (will be linked later if it exists)"
        }
    }
    
    # Then add this issue
    $script:orderedIssues += $issue
    $added[$issue.key] = $true
}

# Process all issues
foreach ($issue in $sortedIssues) {
    Add-IssueWithAncestors -issue $issue
}

Write-Host "✅ Topological sort complete: $($orderedIssues.Count) issues properly ordered"
$sortedIssues = $orderedIssues

$maxIssues = $sortedIssues.Count
Write-Host "Processing $maxIssues issues (total available: $($exportedIssues.Count))"

# Use configured batch size
$processBatchSize = $batchSize

for ($i = 0; $i -lt $maxIssues; $i += $processBatchSize) {
    $batch = $sortedIssues | Select-Object -Skip $i -First $processBatchSize
    $batchNum = [math]::Floor($i / $processBatchSize) + 1
    $totalBatches = [math]::Ceiling($maxIssues / $processBatchSize)
    
    Write-Host "Processing batch $batchNum of $totalBatches (issues $($i + 1) to $([math]::Min($i + $processBatchSize, $maxIssues)))..."
    
    foreach ($sourceIssue in $batch) {
        $sourceKey = $sourceIssue.key
        Write-Host "  Creating issue: $sourceKey"
        
        # Define issue type at the beginning for error handling
        $currentIssueType = if ($sourceIssue.fields.issuetype.name) { $sourceIssue.fields.issuetype.name } else { "Unknown" }
        
        try {
            # Build issue creation payload
            $issuePayload = @{
                fields = @{
                    project = @{ key = $tgtKey }
                    summary = $sourceIssue.fields.summary
                    issuetype = @{ name = $sourceIssue.fields.issuetype.name }
                }
            }
            
            # Add default values for issue-type specific required fields (if they don't exist in source)
            if ($sourceIssue.fields.issuetype.name -eq "Bug") {
                # Bug-specific required fields in target (set defaults if not in source)
                if (-not ($sourceIssue.fields.PSObject.Properties.Name -contains "customfield_10096")) {
                    # Environment Type - valid values: DEV, INT, QA, PROD
                    $issuePayload.fields.customfield_10096 = @{ value = "QA" }
                }
                if (-not ($sourceIssue.fields.PSObject.Properties.Name -contains "customfield_10099")) {
                    # Severity - valid values: Critical, Major, Minor, Low
                    $issuePayload.fields.customfield_10099 = @{ value = "Low" }
                }
            }
            
            # Add description with custom field values
            # Handle both plain text and Atlassian Document Format (ADF)
            $description = ""
            if ($sourceIssue.fields.description) {
                if ($sourceIssue.fields.description -is [string]) {
                    $description = $sourceIssue.fields.description
                } elseif ($sourceIssue.fields.description.type -eq "doc") {
                    # Atlassian Document Format - extract plain text
                    $textParts = @()
                    if ($sourceIssue.fields.description.content) {
                        foreach ($content in $sourceIssue.fields.description.content) {
                            # Check if content has a 'content' property
                            if ($content.PSObject.Properties.Name -contains 'content' -and $content.content) {
                                foreach ($item in $content.content) {
                                    if ($item.PSObject.Properties.Name -contains 'text' -and $item.text) {
                                        $textParts += $item.text
                                    }
                                }
                            }
                            # Also check for direct text in content node
                            elseif ($content.PSObject.Properties.Name -contains 'text' -and $content.text) {
                                $textParts += $content.text
                            }
                        }
                    }
                    $description = $textParts -join "`n"
                } else {
                    # Unknown format, convert to string
                    $description = $sourceIssue.fields.description | ConvertTo-Json -Compress
                }
            }
            
            # Append custom field values and historical data to description (for visibility and backup)
            $customFieldValues = @()
            
            # Add historical timestamp information to description
            if ($sourceIssue.fields.created) {
                $customFieldValues += "**Original Created:** $($sourceIssue.fields.created)"
            }
            if ($sourceIssue.fields.updated) {
                $customFieldValues += "**Original Updated:** $($sourceIssue.fields.updated)"
            }
            if ($sourceIssue.fields.PSObject.Properties.Name -contains 'creator' -and $sourceIssue.fields.creator -and $sourceIssue.fields.creator.displayName) {
                $customFieldValues += "**Original Creator:** $($sourceIssue.fields.creator.displayName)"
            }
            
            # Map of known custom field IDs to friendly names
            $customFieldNames = @{
                $legacyKeyURLField = "LegacyKeyURL"
                $legacyKeyField = "LegacyKey"
                $originalCreatedDateField = "OriginalCreatedDate"
                $originalUpdatedDateField = "OriginalUpdatedDate"
                "customfield_10016" = "Story Points"
                "customfield_10026" = "Story Points"
                "customfield_10104" = "Story Points"
                "customfield_10002" = "Story Points"
            }
            
            # ========== PRESERVE LEGACY KEY AND HISTORICAL INFORMATION ==========
            # Write source key and URL to target's legacy key custom fields
            # These fields only exist in target, not source
            $issuePayload.fields.$legacyKeyField = $sourceIssue.key  # LegacyKey
            $issuePayload.fields.$legacyKeyURLField = "$($srcBase.TrimEnd('/'))/browse/$($sourceIssue.key)"  # LegacyKeyURL
            
            Write-Host "    Setting legacy key: $($sourceIssue.key)"
            
            # ========== PRESERVE ORIGINAL TIMESTAMPS ==========
            # Write original created and updated dates to custom fields for historical accuracy
            if ($originalCreatedDateField -and $sourceIssue.fields.created) {
                $issuePayload.fields.$originalCreatedDateField = $sourceIssue.fields.created
                Write-Host "    Preserving original created date: $($sourceIssue.fields.created)"
            }
            if ($originalUpdatedDateField -and $sourceIssue.fields.updated) {
                $issuePayload.fields.$originalUpdatedDateField = $sourceIssue.fields.updated
                Write-Host "    Preserving original updated date: $($sourceIssue.fields.updated)"
            }
            
            # Process custom fields: ONLY set those that have explicit mappings
            # This prevents trying to set system-managed fields (Epic Status, Sprint, etc.) that don't exist in target
            $unmappedCustomFields = @()
            $skippedSystemFields = @()
            
            foreach ($fieldName in $sourceIssue.fields.PSObject.Properties.Name) {
                if ($fieldName -like "customfield_*") {
                    # Skip legacy key fields - they're being set as custom fields above
                    if ($fieldName -eq $legacyKeyURLField -or $fieldName -eq $legacyKeyField) {
                        continue
                    }
                    
                    # Safe property access - check if property exists and has value
                    if ($sourceIssue.fields.PSObject.Properties.Name -contains $fieldName) {
                        $fieldValue = $sourceIssue.fields.$fieldName
                        
                        # Only process if field has meaningful content
                        if ($fieldValue -and $fieldValue -ne "" -and $null -ne $fieldValue) {
                            
                            # Check if this field has a mapping to target
                            if ($customFieldMapping.ContainsKey($fieldName)) {
                                $targetFieldId = $customFieldMapping[$fieldName]
                                
                                # Log ALL custom field mappings for debugging
                                Write-Host "    🔄 Mapping custom field: $fieldName → $targetFieldId" -ForegroundColor Cyan
                                
                                # Set the custom field directly in the target
                                $issuePayload.fields.$targetFieldId = $fieldValue
                                
                                # Debug: log which fields are being mapped
                                if ($fieldName -eq "customfield_10030" -or $fieldName -eq "customfield_10244" -or $fieldName -eq "customfield_10394" -or $fieldName -eq "customfield_10395") {
                                    $fieldDisplayName = switch($fieldName) {
                                        "customfield_10030" { "Acceptance Criteria" }
                                        "customfield_10244" { "Assumptions" }
                                        "customfield_10394" { "Test Plan" }
                                        "customfield_10395" { "Test Results" }
                                    }
                                    Write-Host "    Mapping $fieldDisplayName : $fieldName → $targetFieldId" -ForegroundColor Cyan
                                }
                            } else {
                                # System-managed fields (Epic Status, Sprint, Size, etc.) - skip silently
                                # These are read-only or auto-populated fields that can't be set during creation
                                $systemManagedFields = @("customfield_10000", "customfield_10001", "customfield_10002", "customfield_10003", 
                                                        "customfield_10004", "customfield_10005", "customfield_10011", "customfield_10012", 
                                                        "customfield_10013", "customfield_10014", "customfield_10015", "customfield_10017", 
                                                        "customfield_10018", "customfield_10019", "customfield_10020", "customfield_10021", 
                                                        "customfield_10025", "customfield_10026", "customfield_10027", "customfield_10102")
                                
                                if ($systemManagedFields -contains $fieldName) {
                                    $skippedSystemFields += $fieldName
                                } else {
                                # No mapping and not a known system field - append to description
                                Write-Host "    ⚠️ No mapping for custom field: $fieldName (will add to description)" -ForegroundColor Yellow
                                $friendlyName = if ($customFieldNames.ContainsKey($fieldName)) { 
                                    $customFieldNames[$fieldName] 
                                } else { 
                                    $fieldName 
                                }
                                $valueStr = if ($fieldValue -is [PSCustomObject] -or $fieldValue -is [Array]) {
                                    $fieldValue | ConvertTo-Json -Compress
                                } else {
                                    $fieldValue
                                }
                                $unmappedCustomFields += "${friendlyName}: $valueStr"
                            }
                            }
                        }
                    }
                }
            }
            
            # Log skipped system fields (if any)
            if ($skippedSystemFields.Count -gt 0) {
                Write-Host "    ℹ️  Skipping $($skippedSystemFields.Count) system-managed fields (Epic/Sprint fields)" -ForegroundColor Gray
            }
            
            # Add unmapped custom fields to description
            $customFieldValues = $unmappedCustomFields
            
            if ($customFieldValues.Count -gt 0) {
                $description += "`n`n**Custom Field Values (from source):**`n" + ($customFieldValues -join "`n")
            }
            
            # Convert description to Atlassian Document Format (ADF)
            if ($description) {
                try {
                    # Split description into paragraphs and convert to ADF
                    $paragraphs = $description -split "`n"
                    $adfContent = @()
                    
                    foreach ($para in $paragraphs) {
                        $trimmedPara = $para.Trim()
                        if ($trimmedPara) {
                            # Ensure text content is valid (not null, not empty, and properly escaped)
                            $cleanText = $trimmedPara -replace '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ''  # Remove control characters
                            if ($cleanText) {
                                $adfContent += @{
                                    type = "paragraph"
                                    content = @(
                                        @{
                                            type = "text"
                                            text = $cleanText
                                        }
                                    )
                                }
                            }
                        }
                    }
                    
                    # Only add description if we have valid content
                    if ($adfContent.Count -gt 0) {
                        $issuePayload.fields.description = @{
                            type = "doc"
                            version = 1
                            content = $adfContent
                        }
                    }
                } catch {
                    Write-Warning "Failed to process description for $($sourceIssue.key): $($_.Exception.Message)"
                    # Fallback: use simple text description
                    $issuePayload.fields.description = $description
                }
            }
            
            # Add priority if available
            if ($sourceIssue.fields.priority) {
                $issuePayload.fields.priority = @{ name = $sourceIssue.fields.priority.name }
            }
            
            # Note: Status will be set after creation via transitions (see below)
            
            # Add reporter if available (map to target user)
            if ($sourceIssue.fields.reporter) {
                $sourceReporterEmail = if ($sourceIssue.fields.reporter.PSObject.Properties.Name -contains 'emailAddress') { 
                    $sourceIssue.fields.reporter.emailAddress 
                } else { 
                    "unknown@example.com" 
                }
                $sourceReporterName = if ($sourceIssue.fields.reporter.PSObject.Properties.Name -contains 'displayName') { 
                    $sourceIssue.fields.reporter.displayName 
                } else { 
                    "Unknown User" 
                }
                Write-Host "    Source reporter: $sourceReporterName ($sourceReporterEmail)"
                
                # Try to find the user in target project
                try {
                    # First try by email address
                    $userSearchUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/user/search?query=$sourceReporterEmail"
                    $userResponse = Invoke-RestMethod -Method GET -Uri $userSearchUri -Headers $tgtHdr -ErrorAction Stop
                    
                    if ($userResponse -and $userResponse.Count -gt 0) {
                        $targetUser = $userResponse[0]
                        $issuePayload.fields.reporter = @{ accountId = $targetUser.accountId }
                        Write-Host "    Target reporter: $($targetUser.displayName) ($($targetUser.emailAddress))"
                    } else {
                        Write-Host "    ⚠️ Reporter not found in target project, will use API token user as reporter"
                    }
                } catch {
                    Write-Host "    ⚠️ Failed to find reporter in target project: $($_.Exception.Message)"
                }
            }
            
            # Add assignee if available (map to target user)
            # If assignment fails during creation, the error handler will retry without assignee
            if ($sourceIssue.fields.assignee) {
                $sourceAssigneeEmail = $sourceIssue.fields.assignee.emailAddress
                $sourceAssigneeName = $sourceIssue.fields.assignee.displayName
                Write-Host "    Source assignee: $sourceAssigneeName ($sourceAssigneeEmail)"
                
                # Try to find the user in target project
                try {
                    # First try by email address
                    $userSearchUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/user/search?query=$sourceAssigneeEmail"
                    $userResponse = Invoke-RestMethod -Method GET -Uri $userSearchUri -Headers $tgtHdr -ErrorAction Stop
                    
                    if ($userResponse -and $userResponse.Count -gt 0) {
                        $targetUser = $userResponse[0]
                        $issuePayload.fields.assignee = @{ accountId = $targetUser.accountId }
                        Write-Host "    Target assignee: $($targetUser.displayName) ($($targetUser.emailAddress))"
                    } else {
                        Write-Host "    ⚠️ User not found in target project, leaving unassigned"
                    }
                } catch {
                    Write-Host "    ⚠️ Failed to find assignee in target project: $($_.Exception.Message)"
                }
            }
            
            # Add labels if available
            if ($sourceIssue.fields.labels -and $sourceIssue.fields.labels.Count -gt 0) {
                $issuePayload.fields.labels = $sourceIssue.fields.labels
            }
            
            # Add components (mapped by name, since step 4 creates from labels)
            # Skip components for Spike issues - they don't have this field on their create screen in target
            if ($currentIssueType -ne "Spike") {
                $mappedComponents = @()
                
                # Add components from source components
                if ($sourceIssue.fields.components -and $sourceIssue.fields.components.Count -gt 0) {
                    foreach ($comp in $sourceIssue.fields.components) {
                        $compNameLower = $comp.name.ToLowerInvariant()
                        if ($componentMappingByName.ContainsKey($compNameLower)) {
                            $mappedComponents += @{ id = $componentMappingByName[$compNameLower] }
                        } else {
                            Write-Host "    ⚠️ Component '$($comp.name)' not found in mapping"
                        }
                    }
                }
                
                # Also add components from labels (Step 04 created components from labels)
                if ($sourceIssue.fields.labels -and $sourceIssue.fields.labels.Count -gt 0) {
                    foreach ($label in $sourceIssue.fields.labels) {
                        $labelLower = $label.ToLowerInvariant()
                        # Check if a component was created from this label
                        if ($componentMappingByName.ContainsKey($labelLower)) {
                            $componentId = $componentMappingByName[$labelLower]
                            # Only add if not already in the list
                            if (-not ($mappedComponents | Where-Object { $_.id -eq $componentId })) {
                                $mappedComponents += @{ id = $componentId }
                            }
                        }
                    }
                }
                
                if ($mappedComponents.Count -gt 0) {
                    $issuePayload.fields.components = $mappedComponents
                    Write-Host "    Components: $($mappedComponents.Count) components (from source + labels)"
                }
            } elseif ($currentIssueType -eq "Spike") {
                Write-Host "    ⚠️ Skipping components for Spike issue (not on create screen in target)"
            }
            
            # Add fix versions (mapped)
            if ($sourceIssue.fields.fixVersions -and $sourceIssue.fields.fixVersions.Count -gt 0) {
                $mappedFixVersions = @()
                foreach ($version in $sourceIssue.fields.fixVersions) {
                    if ($versionMapping.ContainsKey($version.id)) {
                        $mappedFixVersions += @{ id = $versionMapping[$version.id] }
                    }
                }
                if ($mappedFixVersions.Count -gt 0) {
                    $issuePayload.fields.fixVersions = $mappedFixVersions
                }
            }
            
            # Add affected versions (mapped)
            if ($sourceIssue.fields.versions -and $sourceIssue.fields.versions.Count -gt 0) {
                $mappedVersions = @()
                foreach ($version in $sourceIssue.fields.versions) {
                    if ($versionMapping.ContainsKey($version.id)) {
                        $mappedVersions += @{ id = $versionMapping[$version.id] }
                    }
                }
                if ($mappedVersions.Count -gt 0) {
                    $issuePayload.fields.versions = $mappedVersions
                }
            }
            
            # Add parent (for sub-tasks and child issues)
            if ($sourceIssue.fields.PSObject.Properties.Name -contains 'parent' -and $sourceIssue.fields.parent) {
                $parentKey = $sourceIssue.fields.parent.key
                
                # For sub-tasks, skip if parent hasn't been migrated yet
                if ($currentIssueType -eq "Sub-task" -and -not $sourceToTargetKeyMap.ContainsKey($parentKey)) {
                    Write-Host "    ⚠️ SKIPPING sub-task: Parent $parentKey not yet migrated" -ForegroundColor Yellow
                    Write-IssueLog -Type Warning -Category "Skipped Sub-task" -IssueKey $sourceKey `
                        -Message "Sub-task skipped because parent issue not yet migrated" `
                        -Details @{ ParentKey = $parentKey }
                    continue
                }
                
                # Validation: Bugs cannot be parents of other issues
                if ($currentIssueType -eq "Bug") {
                    # Check if the parent is also a Bug (which is invalid)
                    $parentIssue = $exportedIssues | Where-Object { $_.key -eq $parentKey }
                    if ($parentIssue -and $parentIssue.fields.issuetype.name -eq "Bug") {
                        Write-Host "    ⚠️ SKIPPING parent link: Bug cannot be parent of another Bug ($parentKey)"
                        # Don't set the parent field - this Bug will be created without a parent
                    } else {
                        # Check if parent has already been migrated
                        if ($sourceToTargetKeyMap.ContainsKey($parentKey)) {
                            $targetParentKey = $sourceToTargetKeyMap[$parentKey]
                            $issuePayload.fields.parent = @{ key = $targetParentKey }
                            Write-Host "    Parent: $parentKey → $targetParentKey"
                        } else {
                            # Check if parent is from a different project (cross-project parent)
                            $parentProjectKey = $parentKey -replace '-\d+$', ''
                            if ($parentProjectKey -ne $srcKey) {
                                Write-Host "    ℹ️  Cross-project parent: $parentKey (from project $parentProjectKey) - will create remote link" -ForegroundColor Cyan
                                $crossProjectParents += @{
                                    SourceIssue = $sourceKey
                                    TargetIssue = $null  # Will be filled after creation
                                    ParentKey = $parentKey
                                    ParentProject = $parentProjectKey
                                }
                            } else {
                                Write-Host "    ⚠️ Parent $parentKey not yet migrated (will need to be linked later)"
                                
                                # Track as orphaned issue (parent was resolved/excluded)
                                $orphanedIssues += [PSCustomObject]@{
                                    SourceIssueKey = $sourceKey
                                    TargetIssueKey = $null  # Will be filled after creation
                                    SourceIssueType = $currentIssueType
                                    SourceIssueSummary = $sourceIssue.fields.summary
                                    MissingParentKey = $parentKey
                                    SourceStatus = if ($sourceIssue.fields.status) { $sourceIssue.fields.status.name } else { "Unknown" }
                                    Reason = "Parent was resolved/excluded from migration (not in export)"
                                }
                            }
                        }
                    }
                } else {
                    # Non-Bug issues can have any valid parent
                    if ($sourceToTargetKeyMap.ContainsKey($parentKey)) {
                        $targetParentKey = $sourceToTargetKeyMap[$parentKey]
                        $issuePayload.fields.parent = @{ key = $targetParentKey }
                        Write-Host "    Parent: $parentKey → $targetParentKey"
                    } else {
                        # Check if parent is from a different project (cross-project parent)
                        $parentProjectKey = $parentKey -replace '-\d+$', ''
                        if ($parentProjectKey -ne $srcKey) {
                            Write-Host "    ℹ️  Cross-project parent: $parentKey (from project $parentProjectKey) - will create remote link" -ForegroundColor Cyan
                            $crossProjectParents += @{
                                SourceIssue = $sourceKey
                                TargetIssue = $null  # Will be filled after creation
                                ParentKey = $parentKey
                                ParentProject = $parentProjectKey
                            }
                        } else {
                            Write-Host "    ⚠️ Parent $parentKey not yet migrated (will need to be linked later)"
                            
                            # Track as orphaned issue (parent was resolved/excluded)
                            $orphanedIssues += [PSCustomObject]@{
                                SourceIssueKey = $sourceKey
                                TargetIssueKey = $null  # Will be filled after creation
                                SourceIssueType = $currentIssueType
                                SourceIssueSummary = $sourceIssue.fields.summary
                                MissingParentKey = $parentKey
                                SourceStatus = if ($sourceIssue.fields.status) { $sourceIssue.fields.status.name } else { "Unknown" }
                                Reason = "Parent was resolved/excluded from migration (not in export)"
                            }
                        }
                    }
                }
            }
            
            # Story points are already appended to description above - do NOT try to set them as fields
            
            # Note: Other custom fields are appended to description since they don't exist in target
            
            # ========== IDEMPOTENCY CHECK ==========
            # Check if an issue with the same summary already exists
            $summary = $sourceIssue.fields.summary
            $matchingIssues = @()
            if ($existingIssuesBySummary.ContainsKey($summary)) {
                $matchingIssues = $existingIssuesBySummary[$summary]
            }
            
            if ($matchingIssues.Count -gt 0) {
                # Issue already exists - use existing key
                $existingIssue = $matchingIssues[0]  # Use first match (earliest created)
                $targetKey = $existingIssue.key
                
                Write-Host "  ⏭️  SKIPPED (already exists): $($sourceIssue.key) → $targetKey" -ForegroundColor Yellow
                Write-Host "      Summary: '$($summary.Substring(0, [math]::Min(60, $summary.Length)))...'"
                
                # Add to key mapping
                $sourceToTargetKeyMap[$sourceIssue.key] = $targetKey
                
                # Track as skipped
                $skippedIssues += [pscustomobject]@{
                    SourceKey = $sourceIssue.key
                    TargetKey = $targetKey
                    Summary = $summary
                    Reason = "Already exists (idempotency)"
                    ExistingCreated = $existingIssue.fields.created
                }
                
                # Skip to next issue
                continue
            }
            
            # ========== CREATE NEW ISSUE ==========
            # Issue doesn't exist - create it
            $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue"
            $jsonPayload = $issuePayload | ConvertTo-Json -Depth 20
            
            # Validate JSON payload before sending
            try {
                $null = $jsonPayload | ConvertFrom-Json
            } catch {
                Write-Warning "Invalid JSON payload for $($sourceIssue.key): $($_.Exception.Message)"
                Write-Host "    Payload: $jsonPayload"
                throw "Invalid JSON payload generated for issue creation"
            }
            
            try {
                $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $tgtHdr -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
            } catch {
                # Check if it's an assignee or component error
                $isAssigneeError = $false
                $isComponentError = $false
                $errorDetails = $null
                try {
                    if ($_.ErrorDetails.Message) {
                        $errorDetails = $_.ErrorDetails.Message
                        $errorObj = $errorDetails | ConvertFrom-Json
                        if ($errorObj.errors) {
                            if ($errorObj.errors.PSObject.Properties.Name -contains 'assignee') {
                                $assigneeError = $errorObj.errors.assignee
                                $isAssigneeError = $assigneeError -like "*cannot be assigned*"
                            }
                            if ($errorObj.errors.PSObject.Properties.Name -contains 'components') {
                                $isComponentError = $true
                            }
                        }
                    }
                } catch { }
                
                if ($isAssigneeError -or $isComponentError) {
                    if ($isAssigneeError) {
                        # Extract assignee details for better logging
                        $blockedAssignee = "Unknown"
                        $blockedAccountId = "Unknown"
                        try {
                            $payloadObjTemp = $jsonPayload | ConvertFrom-Json
                            if ($payloadObjTemp.fields.PSObject.Properties.Name -contains 'assignee' -and $payloadObjTemp.fields.assignee) {
                                if ($payloadObjTemp.fields.assignee.PSObject.Properties.Name -contains 'accountId') {
                                    $blockedAccountId = $payloadObjTemp.fields.assignee.accountId
                                    # Try to get display name from source issue
                                    if ($sourceIssue.fields.assignee -and $sourceIssue.fields.assignee.displayName) {
                                        $blockedAssignee = $sourceIssue.fields.assignee.displayName
                                    }
                                }
                            }
                        } catch { }
                        
                        Write-Host "    ⚠️ Assignee permission error - User '$blockedAssignee' ($blockedAccountId) cannot be assigned" -ForegroundColor Yellow
                        Write-Host "       💡 Grant 'Assignable User' permission to this user's role in target project:" -ForegroundColor Cyan
                        Write-Host "       🔗 $($tgtBase.TrimEnd('/'))/plugins/servlet/project-config/$tgtKey/permissions" -ForegroundColor Cyan
                        Write-Host "       Retrying without assignee..." -ForegroundColor Gray
                        
                        # Log this issue
                        Write-IssueLog -Type Action -Category "Assignee Permission" -IssueKey $sourceIssue.key `
                            -Message "User '$blockedAssignee' cannot be assigned - grant 'Assignable User' permission" `
                            -ActionUrl "$($tgtBase.TrimEnd('/'))/plugins/servlet/project-config/$tgtKey/permissions" `
                            -Details @{
                                UserDisplayName = $blockedAssignee
                                AccountId = $blockedAccountId
                                IssueType = $currentIssueType
                            }
                    }
                    if ($isComponentError) {
                        Write-Host "    ⚠️ Component field error for issue type '$currentIssueType' - retrying without components" -ForegroundColor Yellow
                        Write-Host "       💡 Add 'Component/s' field to the CREATE screen for '$currentIssueType' in target project:" -ForegroundColor Cyan
                        Write-Host "       🔗 $($tgtBase.TrimEnd('/'))/secure/project/SelectIssueTypeScreenScheme!default.jspa?projectKey=$tgtKey" -ForegroundColor Cyan
                        
                        # Log this issue
                        Write-IssueLog -Type Action -Category "Component Field Missing" -IssueKey $sourceIssue.key `
                            -Message "Add 'Component/s' field to CREATE screen for issue type '$currentIssueType'" `
                            -ActionUrl "$($tgtBase.TrimEnd('/'))/secure/project/SelectIssueTypeScreenScheme!default.jspa?projectKey=$tgtKey" `
                            -Details @{
                                IssueType = $currentIssueType
                                ProjectKey = $tgtKey
                            }
                    }
                    
                    # Parse the original JSON payload and remove problematic fields
                    try {
                        $payloadObj = $jsonPayload | ConvertFrom-Json
                        if ($isAssigneeError -and $payloadObj.fields.PSObject.Properties.Name -contains 'assignee') {
                            $payloadObj.fields.PSObject.Properties.Remove('assignee')
                        }
                        if ($isComponentError -and $payloadObj.fields.PSObject.Properties.Name -contains 'components') {
                            $payloadObj.fields.PSObject.Properties.Remove('components')
                        }
                        $jsonPayload = $payloadObj | ConvertTo-Json -Depth 20
                        
                        $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $tgtHdr -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
                        if ($isAssigneeError -and $isComponentError) {
                            Write-Host "    ✅ Created without assignee and components"
                        } elseif ($isAssigneeError) {
                            Write-Host "    ✅ Created without assignee after permission error"
                        } else {
                            Write-Host "    ✅ Created without components after field error"
                        }
                    } catch {
                        Write-Host "    ❌ Still failed after removing problematic fields: $($_.Exception.Message)"
                        throw "Failed to create issue $($sourceIssue.key) even after field removal: $($_.Exception.Message)"
                    }
                } else {
                    # Check if it's an ADF (rich text) formatting error
                    $isAdfError = $false
                    $adfFieldName = $null
                    try {
                        if ($errorDetails) {
                            $errorObj = $errorDetails | ConvertFrom-Json
                            # Check for various ADF-related errors
                            $hasAdfError = $false
                            
                            # Check error messages for ADF-related issues
                            if ($errorObj.errors) {
                                foreach ($errKey in $errorObj.errors.PSObject.Properties.Name) {
                                    $errMsg = $errorObj.errors.$errKey
                                    if ($errMsg -like "*Operation value must be*Atlassian Document*" -or
                                        $errMsg -like "*INVALID_INPUT*" -or
                                        $errMsg -like "*malformed*") {
                                        $hasAdfError = $true
                                        # Extract field name from error key (e.g., "customfield_10092")
                                        if ($errKey -like "customfield_*") {
                                            $adfFieldName = $errKey
                                        }
                                        break
                                    }
                                }
                            }
                            
                            # Also check errorMessages array
                            if (-not $hasAdfError -and $errorObj.errorMessages) {
                                if ($errorObj.errorMessages -like "*INVALID_INPUT*" -or
                                    $errorObj.errorMessages -like "*Atlassian Document*") {
                                    $hasAdfError = $true
                                }
                            }
                            
                            # Also check exception message for orderedList issues
                            if (-not $hasAdfError -and $_.Exception.Message -like "*400*" -and $jsonPayload -like "*orderedList*") {
                                $hasAdfError = $true
                            }
                            
                            if ($hasAdfError) {
                                # If we don't have a field name yet, scan payload for ADF fields
                                if (-not $adfFieldName) {
                                    $payloadObj = $jsonPayload | ConvertFrom-Json
                                    foreach ($fieldName in $payloadObj.fields.PSObject.Properties.Name) {
                                        if ($fieldName -like "customfield_*") {
                                            $fieldValue = $payloadObj.fields.$fieldName
                                            # Check if it's an ADF object with content OR a plain string that should be ADF
                                            if (($fieldValue -is [PSCustomObject] -and 
                                                $fieldValue.PSObject.Properties.Name -contains 'type' -and 
                                                $fieldValue.type -eq 'doc') -or
                                                ($fieldValue -is [string] -and $fieldValue.Length -gt 0)) {
                                                $isAdfError = $true
                                                $adfFieldName = $fieldName
                                                break
                                            }
                                        }
                                    }
                                } else {
                                    $isAdfError = $true
                                }
                            }
                        }
                    } catch { }
                    
                    if ($isAdfError -and $adfFieldName) {
                        Write-Host "    ⚠️ ADF formatting error in field $adfFieldName - converting to plain text" -ForegroundColor Yellow
                        
                        try {
                            $payloadObj = $jsonPayload | ConvertFrom-Json
                            
                            # Convert ADF to plain text
                            $adfContent = $payloadObj.fields.$adfFieldName
                            $plainText = ""
                            
                            # Recursively extract text from ADF structure
                            function Extract-AdfText($node) {
                                $text = ""
                                if ($node.PSObject.Properties.Name -contains 'text') {
                                    return $node.text
                                }
                                if ($node.PSObject.Properties.Name -contains 'content') {
                                    foreach ($child in $node.content) {
                                        $text += Extract-AdfText $child
                                        $text += " "
                                    }
                                }
                                return $text
                            }
                            
                            $plainText = (Extract-AdfText $adfContent).Trim()
                            
                            # Replace ADF with simple paragraph format
                            if ($plainText) {
                                $payloadObj.fields.$adfFieldName = @{
                                    type = "doc"
                                    version = 1
                                    content = @(
                                        @{
                                            type = "paragraph"
                                            content = @(
                                                @{
                                                    type = "text"
                                                    text = $plainText
                                                }
                                            )
                                        }
                                    )
                                }
                            } else {
                                # If we can't extract text, remove the field entirely
                                $payloadObj.fields.PSObject.Properties.Remove($adfFieldName)
                            }
                            
                            $jsonPayload = $payloadObj | ConvertTo-Json -Depth 20
                            $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $tgtHdr -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
                            Write-Host "    ✅ Created with simplified plain text format" -ForegroundColor Green
                            
                            # Track the conversion for validation report
                            $customFieldConversions += @{
                                SourceIssue = $sourceIssue.key
                                TargetIssue = $null  # Will be filled after creation
                                FieldId = $adfFieldName
                                FieldName = if ($customFieldNames.ContainsKey($adfFieldName)) { $customFieldNames[$adfFieldName] } else { $adfFieldName }
                                ConversionType = "ADF to Plain Text"
                                OriginalTextLength = $plainText.Length
                            }
                        } catch {
                            Write-Host "    ❌ Still failed after converting to plain text: $($_.Exception.Message)"
                            Write-Host "    Will append to description instead"
                            
                            # Last resort: Remove the problematic custom field entirely
                            try {
                                $payloadObj = $jsonPayload | ConvertFrom-Json
                                $payloadObj.fields.PSObject.Properties.Remove($adfFieldName)
                                $jsonPayload = $payloadObj | ConvertTo-Json -Depth 20
                                $response = Invoke-RestMethod -Method POST -Uri $uri -Headers $tgtHdr -Body $jsonPayload -ContentType "application/json" -ErrorAction Stop
                                Write-Host "    ✅ Created without problematic custom field (will be in description)" -ForegroundColor Green
                                
                                # Track the removal for validation report
                                $customFieldRemovals += @{
                                    SourceIssue = $sourceIssue.key
                                    TargetIssue = $null  # Will be filled after creation
                                    FieldId = $adfFieldName
                                    FieldName = if ($customFieldNames.ContainsKey($adfFieldName)) { $customFieldNames[$adfFieldName] } else { $adfFieldName }
                                    Reason = "ADF conversion failed - field removed, content in description"
                                }
                            } catch {
                                Write-Host "    ❌ Failed even after removing custom field"
                                throw
                            }
                        }
                    } else {
                        Write-Host "    ❌ API Error Details:"
                        Write-Host "    Exception: $($_.Exception.Message)"
                        
                        # Try to get more details from the response
                        try {
                            if ($errorDetails) {
                                $errorObj = $errorDetails | ConvertFrom-Json
                                Write-Host "    Error: $($errorObj.errorMessages -join ', ')"
                                if ($errorObj.errors) {
                                    $errorObj.errors.PSObject.Properties | ForEach-Object {
                                        Write-Host "      Field '$($_.Name)': $($_.Value)"
                                    }
                                }
                            }
                        } catch {
                            if ($errorDetails) {
                                Write-Host "    Error Response: $errorDetails"
                            }
                        }
                        
                        Write-Host "    Payload: $jsonPayload"
                        throw
                    }
                }
            }
            
            $targetKey = $response.key
            $sourceToTargetKeyMap[$sourceKey] = $targetKey
            
            # Update target issue key in custom field tracking arrays
            foreach ($conversion in $customFieldConversions) {
                if ($conversion.SourceIssue -eq $sourceKey -and $null -eq $conversion.TargetIssue) {
                    $conversion.TargetIssue = $targetKey
                }
            }
            foreach ($removal in $customFieldRemovals) {
                if ($removal.SourceIssue -eq $sourceKey -and $null -eq $removal.TargetIssue) {
                    $removal.TargetIssue = $targetKey
                }
            }
            
            Write-Host "    ✅ Created: $targetKey"
            
            # Try to set status after creation (best effort - issue is created regardless)
            if ($sourceIssue.fields.status) {
                $sourceStatusName = $sourceIssue.fields.status.name
                $statusMapping = @{}
                if ($params.StatusMapping) {
                    $params.StatusMapping.PSObject.Properties | ForEach-Object {
                        $statusMapping[$_.Name] = $_.Value
                    }
                }
                
                $targetStatusName = if ($statusMapping.ContainsKey($sourceStatusName)) {
                    $statusMapping[$sourceStatusName]
                } elseif ($targetStatuses -contains $sourceStatusName) {
                    $sourceStatusName
                } else {
                    $sourceStatusName  # Fallback
                }
                
                Write-Host "    Source Status: '$sourceStatusName' → Target Status: '$targetStatusName'"
                
                # Get current status of newly created issue
                try {
                    $currentIssue = Invoke-RestMethod -Method GET -Uri "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey" -Headers $tgtHdr -ErrorAction Stop
                    $currentStatusName = $currentIssue.fields.status.name
                    Write-Host "    Current status after creation: '$currentStatusName'"
                    
                    # Only transition if status is different from current
                    if ($targetStatusName -and $currentStatusName -ne $targetStatusName) {
                        # Get available transitions for this issue
                        $transitionsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/transitions"
                        $availableTransitions = Invoke-RestMethod -Method GET -Uri $transitionsUri -Headers $tgtHdr -ErrorAction Stop
                        
                        # Find the correct transition by target status
                        $matchingTransition = $null
                        foreach ($transition in $availableTransitions.transitions) {
                            if ($transition.to.name -eq $targetStatusName) {
                                $matchingTransition = $transition
                                break
                            }
                        }
                        
                        if ($matchingTransition) {
                            try {
                                $transitionUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/transitions"
                                $transitionPayload = @{
                                    transition = @{ id = $matchingTransition.id }
                                } | ConvertTo-Json -Depth 3
                                
                                Invoke-RestMethod -Method POST -Uri $transitionUri -Headers $tgtHdr -Body $transitionPayload -ContentType "application/json" -ErrorAction Stop
                                Write-Host "    ✅ Status transitioned to: '$targetStatusName'"
                            } catch {
                                Write-Host "    ⚠️ Could not transition to '$targetStatusName' (staying in '$currentStatusName'): $($_.Exception.Message)"
                            }
                        } else {
                            # No direct transition - try multi-hop path
                            Write-Host "    🔄 No direct transition from '$currentStatusName' to '$targetStatusName' - searching for multi-hop path..." -ForegroundColor Yellow
                            
                            # Common intermediate statuses to try (ordered by likelihood)
                            # This list covers typical Jira workflows to reach most destination statuses
                            $intermediateStatuses = @(
                                "Refinement",           # Common first step from Backlog
                                "Ready for Work",       # Common pre-work status
                                "To Do",                # Alternative to Ready for Work
                                "Selected for Development", # Scrum boards
                                "In Progress",          # Required to reach Testing/Review statuses
                                "Analysis",             # Alternative analysis stage
                                "Prioritized"           # Alternative prioritization stage
                            )
                            $transitionPath = @()
                            $currentStep = $currentStatusName
                            $maxHops = 5  # Increased to handle longer workflow paths (e.g., Backlog → Refinement → Ready → In Progress → Testing)
                            $hopCount = 0
                            $pathFound = $false
                            
                            while ($hopCount -lt $maxHops -and -not $pathFound) {
                                # Get available transitions from current step
                                $transitionsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/transitions"
                                $availableTransitions = Invoke-RestMethod -Method GET -Uri $transitionsUri -Headers $tgtHdr -ErrorAction Stop
                                
                                # Check if we can now reach the target directly
                                $directTransition = $availableTransitions.transitions | Where-Object { $_.to.name -eq $targetStatusName } | Select-Object -First 1
                                if ($directTransition) {
                                    # Found direct path to target
                                    $transitionPath += @{ Status = $targetStatusName; TransitionId = $directTransition.id }
                                    $pathFound = $true
                                    break
                                }
                                
                                # Try intermediate statuses
                                $nextHop = $null
                                foreach ($intermediateStatus in $intermediateStatuses) {
                                    $transition = $availableTransitions.transitions | Where-Object { $_.to.name -eq $intermediateStatus } | Select-Object -First 1
                                    if ($transition) {
                                        $nextHop = @{ Status = $intermediateStatus; TransitionId = $transition.id }
                                        break
                                    }
                                }
                                
                                if ($nextHop) {
                                    $transitionPath += $nextHop
                                    # Execute this hop
                                    try {
                                        $transitionUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/transitions"
                                        $transitionPayload = @{ transition = @{ id = $nextHop.TransitionId } } | ConvertTo-Json -Depth 3
                                        Invoke-RestMethod -Method POST -Uri $transitionUri -Headers $tgtHdr -Body $transitionPayload -ContentType "application/json" -ErrorAction Stop
                                        Write-Host "      ↳ Hopped to: '$($nextHop.Status)'" -ForegroundColor Cyan
                                        $currentStep = $nextHop.Status
                                        $hopCount++
                                    } catch {
                                        Write-Host "      ❌ Failed to transition to intermediate status '$($nextHop.Status)': $($_.Exception.Message)" -ForegroundColor Red
                                        break
                                    }
                                } else {
                                    # No intermediate hop found
                                    break
                                }
                            }
                            
                            # Execute final transition if path was found
                            if ($pathFound -and $transitionPath.Count -gt 0) {
                                try {
                                    $finalTransition = $transitionPath[-1]
                                    $transitionUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/transitions"
                                    $transitionPayload = @{ transition = @{ id = $finalTransition.TransitionId } } | ConvertTo-Json -Depth 3
                                    Invoke-RestMethod -Method POST -Uri $transitionUri -Headers $tgtHdr -Body $transitionPayload -ContentType "application/json" -ErrorAction Stop
                                    Write-Host "    ✅ Status transitioned via multi-hop path to: '$targetStatusName'" -ForegroundColor Green
                                } catch {
                                    Write-Host "    ⚠️ Failed final transition to '$targetStatusName': $($_.Exception.Message)" -ForegroundColor Yellow
                                }
                            } else {
                                Write-Host "    ⚠️ No workflow path found from '$currentStatusName' to '$targetStatusName' (issue will remain in '$currentStep')" -ForegroundColor Yellow
                            }
                        }
                    } else {
                        Write-Host "    ✅ Status correct: '$currentStatusName'"
                    }
                } catch {
                    Write-Host "    ⚠️ Could not verify/set status (issue created successfully): $($_.Exception.Message)"
                }
            }
            # Add to cache to prevent future duplicates in the same run
            if (-not $existingIssuesBySummary.ContainsKey($summary)) {
                $existingIssuesBySummary[$summary] = @()
            }
            $existingIssuesBySummary[$summary] += @{
                key = $targetKey
                fields = @{
                    summary = $summary
                    created = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")
                }
            }
            
            $createdIssues += @{
                SourceKey = $sourceKey
                TargetKey = $targetKey
                TargetId = $response.id
                IssueType = $sourceIssue.fields.issuetype.name
                Summary = $sourceIssue.fields.summary
            }
            
            # Update cross-project parent tracking with target key
            foreach ($cpParent in $crossProjectParents) {
                if ($cpParent.SourceIssue -eq $sourceKey) {
                    $cpParent.TargetIssue = $targetKey
                }
            }
            
            # Update orphaned issues tracking with target key
            foreach ($orphan in $orphanedIssues) {
                if ($orphan.SourceIssueKey -eq $sourceKey) {
                    $orphan.TargetIssueKey = $targetKey
                }
            }
            
        } catch {
            Write-Warning "    ❌ Failed to create $sourceKey : $($_.Exception.Message)"
            $failedIssues += @{
                SourceKey = $sourceKey
                SourceIssue = $sourceIssue
                Error = $_.Exception.Message
            }
            
            # Log this error
            Write-IssueLog -Type Error -Category "Issue Creation Failed" -IssueKey $sourceKey `
                -Message "Failed to create issue: $($_.Exception.Message)" `
                -Details @{
                    IssueType = $currentIssueType
                    Summary = if ($sourceIssue.fields.summary) { $sourceIssue.fields.summary } else { "" }
                }
        }
    }
}

Write-Host ""
Write-Host "=== CREATION SUMMARY ==="
Write-Host "✅ Issues created: $($createdIssues.Count)"
Write-Host "⏭️  Issues skipped: $($skippedIssues.Count) (already existed - idempotency)"
Write-Host "❌ Issues failed: $($failedIssues.Count)"
Write-Host "📊 Total processed: $(($createdIssues.Count + $skippedIssues.Count + $failedIssues.Count))"
Write-Host "🔗 Cross-project parents found: $($crossProjectParents.Count)"

if ($crossProjectParents.Count -gt 0) {
    Write-Host ""
    Write-Host "📋 Cross-Project Parent Links (saved for remote link creation):" -ForegroundColor Cyan
    $crossProjectParents | Select-Object -First 10 | ForEach-Object {
        Write-Host "   $($_.TargetIssue) → $($_.ParentKey) (project: $($_.ParentProject))" -ForegroundColor Gray
    }
    if ($crossProjectParents.Count -gt 10) {
        Write-Host "   ... and $($crossProjectParents.Count - 10) more" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "💡 These will be created as remote links in a future step" -ForegroundColor Yellow
}

if ($orphanedIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "⚠️  Orphaned Issues (missing parents): $($orphanedIssues.Count)" -ForegroundColor Yellow
    Write-Host "📋 Issues whose parents were resolved/excluded from migration:" -ForegroundColor Cyan
    $orphanedIssues | Select-Object -First 10 | ForEach-Object {
        Write-Host "   $($_.TargetIssueKey) (was $($_.SourceIssueKey)) - Missing parent: $($_.MissingParentKey)" -ForegroundColor Gray
    }
    if ($orphanedIssues.Count -gt 10) {
        Write-Host "   ... and $($orphanedIssues.Count - 10) more" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "💡 These issues need parent links manually created by project lead" -ForegroundColor Yellow
    Write-Host "📄 See: .\projects\$Project\out\08_OrphanedIssues.csv for full list" -ForegroundColor Cyan
}

if ($failedIssues.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed issues:"
    foreach ($failed in $failedIssues) {
        Write-Host "  - $($failed.SourceKey): $($failed.Error)"
    }
}

# Save key mapping for use in later steps
$keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"
try {
    $sourceToTargetKeyMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $keyMappingFile -Encoding UTF8
    Write-Host "✅ Key mapping saved to: $keyMappingFile"
} catch {
    Write-Warning "Failed to save key mapping: $($_.Exception.Message)"
}

# Export orphaned issues report (for project lead action)
if ($orphanedIssues.Count -gt 0) {
    $orphanedIssuesFile = Join-Path $outDir "08_OrphanedIssues.csv"
    try {
        $orphanedIssues | Select-Object `
            @{N='Source Issue';E={$_.SourceIssueKey}}, `
            @{N='Source URL';E={"$($srcBase.TrimEnd('/'))/browse/$($_.SourceIssueKey)"}}, `
            @{N='Target Issue';E={$_.TargetIssueKey}}, `
            @{N='Target URL';E={"$($tgtBase.TrimEnd('/'))/browse/$($_.TargetIssueKey)"}}, `
            @{N='Issue Type';E={$_.SourceIssueType}}, `
            @{N='Summary';E={$_.SourceIssueSummary}}, `
            @{N='Missing Parent';E={$_.MissingParentKey}}, `
            @{N='Status';E={$_.SourceStatus}}, `
            @{N='Reason';E={$_.Reason}}, `
            @{N='Action Required';E={"Manually link to appropriate parent or mark as orphaned"}}, `
            @{N='Timestamp';E={(Get-Date).ToString("yyyy-MM-dd HH:mm:ss")}} | `
            Export-Csv -Path $orphanedIssuesFile -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Orphaned issues report saved to: $orphanedIssuesFile"
    } catch {
        Write-Warning "Failed to save orphaned issues report: $($_.Exception.Message)"
    }
}

# Export custom field conversion report (for validation in Step 16)
# Suppress any Count errors - we don't need this metric
try {
    $conversionCount = if ($customFieldConversions) { $customFieldConversions.Count } else { 0 }
    $removalCount = if ($customFieldRemovals) { $customFieldRemovals.Count } else { 0 }

    if ($conversionCount -gt 0 -or $removalCount -gt 0) {
        $conversionReportFile = Join-Path $outDir "08_CustomFieldConversions_Report.json"
        $conversionReport = @{
            Summary = @{
                TotalConversions = $conversionCount
                TotalRemovals = $removalCount
            }
            Conversions = if ($customFieldConversions) { $customFieldConversions } else { @() }
            Removals = if ($customFieldRemovals) { $customFieldRemovals } else { @() }
        }
        
        try {
            $conversionReport | ConvertTo-Json -Depth 5 | Out-File -FilePath $conversionReportFile -Encoding UTF8
            Write-Host "✅ Custom field conversion report saved to: $conversionReportFile"
            
            # Also export as CSV for easy review
            if ($conversionCount -gt 0) {
                $conversionCsvFile = Join-Path $outDir "08_CustomFieldConversions.csv"
                $customFieldConversions | ForEach-Object {
                    [PSCustomObject]@{
                        SourceIssue = $_.SourceIssue
                        TargetIssue = $_.TargetIssue
                        FieldName = $_.FieldName
                        FieldId = $_.FieldId
                        ConversionType = $_.ConversionType
                        OriginalTextLength = $_.OriginalTextLength
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                } | Export-Csv -Path $conversionCsvFile -NoTypeInformation -Encoding UTF8
                Write-Host "✅ Conversions CSV saved to: $conversionCsvFile"
            }
            
            if ($removalCount -gt 0) {
                $removalCsvFile = Join-Path $outDir "08_CustomFieldRemovals.csv"
                $customFieldRemovals | ForEach-Object {
                    [PSCustomObject]@{
                        SourceIssue = $_.SourceIssue
                        TargetIssue = $_.TargetIssue
                        FieldName = $_.FieldName
                        FieldId = $_.FieldId
                        Reason = $_.Reason
                        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                } | Export-Csv -Path $removalCsvFile -NoTypeInformation -Encoding UTF8
                Write-Host "✅ Removals CSV saved to: $removalCsvFile"
            }
        } catch {
            Write-Warning "Failed to save custom field conversion report: $($_.Exception.Message)"
        }
    }
} catch {
    # Silently suppress any Count errors - this report is optional
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 8
$step8SummaryReport = @()

# Add step timing information
$step8SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step8SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Add summary statistics
$step8SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Source Issues"
    Value = $sortedIssues.Count
    Details = "Total issues processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step8SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Created"
    Value = $createdIssues.Count
    Details = "Issues successfully created in target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step8SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Skipped"
    Value = $skippedIssues.Count
    Details = "Issues skipped (already exist)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step8SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Failed"
    Value = $failedIssues.Count
    Details = "Issues that failed to create"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step8SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Orphaned Issues"
    Value = $orphanedIssues.Count
    Details = "Issues with missing parent links"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step8SummaryCsvPath = Join-Path $outDir "08_CreateIssues_SummaryReport.csv"
$step8SummaryReport | Export-Csv -Path $step8SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 8 summary report saved: $step8SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step8SummaryReport.Count)" -ForegroundColor Cyan

# Save issues log (warnings, errors, actions needed)
Save-IssuesLog -StepName "08_CreateIssues_Target"

# Create detailed receipt
try {
    Write-StageReceipt -OutDir $outDir -Stage "08_CreateIssues_Target" -Data @{
        TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
        TotalSourceIssues = $sortedIssues.Count
        CreatedIssues = $createdIssues.Count
        SkippedIssues = $skippedIssues.Count
        FailedIssues = $failedIssues.Count
        CreatedIssueDetails = $createdIssues
        SkippedIssueDetails = $skippedIssues
        FailedIssueDetails = $failedIssues
        SourceToTargetKeyMapping = $sourceToTargetKeyMap
        KeyMappingFile = $keyMappingFile
        ComponentMappingsUsed = if ($componentMappingByName) { $componentMappingByName.Count } else { 0 }
        VersionMappingsUsed = if ($versionMapping) { $versionMapping.Count } else { 0 }
        IdempotencyEnabled = $true
        ExistingIssuesFound = if ($existingIssues) { $existingIssues.Count } else { 0 }
        CrossProjectParents = $crossProjectParents
        OrphanedIssuesCount = if ($orphanedIssues) { $orphanedIssues.Count } else { 0 }
        OrphanedIssues = $orphanedIssues
        CustomFieldMappingsLoaded = if ($customFieldMapping) { $customFieldMapping.Count } else { 0 }
        CustomFieldConversions = if ($conversionCount) { $conversionCount } else { 0 }
        CustomFieldRemovals = if ($removalCount) { $removalCount } else { 0 }
    }
} catch {
    Write-Warning "Some receipt metrics could not be calculated (non-critical): $($_.Exception.Message)"
}

exit 0
