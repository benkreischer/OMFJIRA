# 07_ExportIssues_Source.ps1 - Export Issues from Source Project
# 
# PURPOSE: Exports issues from the source project and builds a comprehensive mapping
# of issue keys to IDs for use in the migration process.
#
# EXPORT SCOPE (configured in parameters.json):
# - ALL: Exports all issues including resolved/closed (full historical migration)
# - UNRESOLVED: Exports only unresolved issues (active work migration)
#
# WHAT IT DOES:
# - Reads export scope from IssueExportSettings.Scope in parameters.json
# - Retrieves issues from the source project using optimized JQL queries
# - Exports issue data including fields, relationships, and metadata
# - Builds a key->ID mapping for cross-referencing during migration
# - Handles pagination for large issue sets using Enhanced JQL API
# - Creates detailed export logs and receipts
#
# WHAT IT DOES NOT DO:
# - Does not modify any issues in the source project
# - Does not create issues in the target project
# - Does not migrate attachments or comments yet
#
# NEXT STEP: Run 08_CreateIssues_Target.ps1 to create issues in the target project
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

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$outDir = $p.OutputSettings.OutputDirectory
$searchBatchSize = 1000  # Maximum for search/JQL API
$bulkFetchBatchSize = 100  # Maximum for bulk fetch API

Write-Host "=== EXPORTING ISSUES FROM SOURCE PROJECT ==="
Write-Host "Source Project: $srcKey"
Write-Host ""

# Determine issue scope from parameters
$exportScope = "UNRESOLVED"  # Default
if ($p.PSObject.Properties.Name -contains 'IssueExportSettings') {
    if ($p.IssueExportSettings.PSObject.Properties.Name -contains 'Scope') {
        $exportScope = $p.IssueExportSettings.Scope.ToUpper()
    }
}

# Validate scope and set includeClosedIssues flag
$includeClosedIssues = $false
if ($exportScope -eq "ALL") {
    $includeClosedIssues = $true
    Write-Host "✅ Export Scope: ALL issues (including resolved/closed)" -ForegroundColor Green
} elseif ($exportScope -eq "UNRESOLVED") {
    $includeClosedIssues = $false
    Write-Host "✅ Export Scope: UNRESOLVED issues only" -ForegroundColor Green
} else {
    throw "Invalid IssueExportSettings.Scope: $exportScope. Valid options: ALL, UNRESOLVED"
}

Write-Host "   (Configured in parameters.json: IssueExportSettings.Scope)" -ForegroundColor Gray

Write-Host ""
Write-Host "Search Batch Size: $searchBatchSize (max)"
Write-Host "Bulk Fetch Batch Size: $bulkFetchBatchSize (max)"

# Get source project details
Write-Host "Retrieving source project details..."
try {
    $srcProject = Invoke-Jira -Method GET -BaseUrl $srcBase -Path "rest/api/3/project/$srcKey" -Headers $srcHdr
    Write-Host "Source project: $($srcProject.name) (id=$($srcProject.id))"
} catch {
    throw "Cannot retrieve source project: $($_.Exception.Message)"
}

# Build JQL query based on user choice
$jql = "project = $srcKey"
if (-not $includeClosedIssues) {
    $jql += " AND resolution = Unresolved"
}
if (-not $p.AnalysisSettings.IncludeSubTasks) {
    $jql += " AND issuetype != Sub-task"
}

Write-Host "Using JQL: $jql"

# Define fields to export
$fields = @(
    "summary", "description", "issuetype", "status", "priority", "assignee", "reporter", 
    "created", "updated", "resolution", "resolutiondate", "labels", "components", 
    "fixVersions", "versions", "parent"
)

# Add ALL custom fields from CustomFieldMapping (if available)
if ($p.PSObject.Properties.Name -contains 'CustomFieldMapping') {
    $customFieldCount = 0
    $p.CustomFieldMapping.PSObject.Properties | ForEach-Object {
        $sourceFieldId = $_.Name
        if ($fields -notcontains $sourceFieldId) {
            $fields += $sourceFieldId
            $customFieldCount++
        }
    }
    Write-Host "✅ Added $customFieldCount custom fields from mapping to export" -ForegroundColor Green
} else {
    Write-Host "ℹ️  No CustomFieldMapping in parameters - exporting only standard fields" -ForegroundColor Yellow
}

# Also include common story point fields and legacy fields (if not already added)
$additionalFields = @("customfield_10016", "customfield_10026", "customfield_10104", "customfield_10002", "customfield_11950", "customfield_11951")
foreach ($field in $additionalFields) {
    if ($fields -notcontains $field) {
        $fields += $field
    }
}

# =============================================================================
# PHASE 1: GET ALL ISSUE IDs USING ENHANCED JQL API
# =============================================================================
Write-Host ""
Write-Host "=== PHASE 1: GETTING ALL ISSUE IDs ==="

$EnhancedSearchUrl = "$($srcBase.TrimEnd('/'))/rest/api/3/search/jql"
$AllIssueIds = @()
$keyToIdMap = @{}
$NextPageToken = $null
$TotalPages = 0

do {
    $TotalPages++
    Write-Host "  Fetching page $TotalPages..."
    
    # Build request payload for Enhanced JQL API
    $Payload = @{
        jql = $jql
        maxResults = $searchBatchSize
    }
    
    if ($NextPageToken) {
        $Payload.nextPageToken = $NextPageToken
    }
    
    $JsonPayload = $Payload | ConvertTo-Json -Depth 10
    
    try {
        $Response = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $srcHdr -Body $JsonPayload
        
        Write-Host "    Retrieved $($Response.issues.Count) issues from page $TotalPages"
        
        # Extract issue IDs (Enhanced JQL API returns minimal data for performance)
        foreach ($issue in $Response.issues) {
            $AllIssueIds += $issue.id
        }
        
        Write-Host "    Total issue IDs collected: $($AllIssueIds.Count)"
        
        # Check for next page token
        if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
            $NextPageToken = $Response.nextPageToken
            Write-Host "    Next page token found, continuing..."
        } else {
            $NextPageToken = $null
            Write-Host "    No next page token, pagination complete"
        }
        
    } catch {
        Write-Error "Failed to fetch page $TotalPages`: $($_.Exception.Message)"
        break
    }
    
} while ($NextPageToken -ne $null)

Write-Host "PHASE 1 COMPLETE: Collected $($AllIssueIds.Count) issue IDs in $TotalPages pages"

# =============================================================================
# PHASE 2: GET ISSUE DETAILS USING BULK FETCH API
# =============================================================================
Write-Host ""
Write-Host "=== PHASE 2: GETTING ISSUE DETAILS ==="

$BulkFetchUrl = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/bulkfetch"
$allIssues = @()

# Split issue IDs into batches
$Batches = @()
for ($i = 0; $i -lt $AllIssueIds.Count; $i += $bulkFetchBatchSize) {
    $Batch = $AllIssueIds[$i..([Math]::Min($i + $bulkFetchBatchSize - 1, $AllIssueIds.Count - 1))]
    $Batches += ,$Batch  # Comma to create array of arrays
}

Write-Host "  Created $($Batches.Count) batches of up to $bulkFetchBatchSize issues each"

# Process batches
if ($Batches.Count -eq 0) {
    Write-Host "  No issues to process - skipping batch processing" -ForegroundColor Yellow
} else {
    foreach ($BatchIndex in 0..($Batches.Count - 1)) {
        $Batch = $Batches[$BatchIndex]
        Write-Host "  Processing batch $($BatchIndex + 1)/$($Batches.Count) with $($Batch.Count) issues..."
    
    # Build request payload for Bulk Fetch API
    $BulkPayload = @{
        fields = $fields
        issueIdsOrKeys = $Batch
        expand = @("changelog", "changelog.histories", "changelog.histories.author", "changelog.histories.items")
    }
    
    $BulkJsonPayload = $BulkPayload | ConvertTo-Json -Depth 10
    
    try {
        $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $srcHdr -Body $BulkJsonPayload
        
        Write-Host "    Retrieved $($BulkResponse.issues.Count) issue details from batch $($BatchIndex + 1)"
        
        # Add to exported issues and build key mapping
        if ($BulkResponse.issues -and $BulkResponse.issues.Count -gt 0) {
            $allIssues += $BulkResponse.issues
            
            # Build key to ID mapping from full issue details
            foreach ($issue in $BulkResponse.issues) {
                if ($issue.key) {
                    $keyToIdMap[$issue.key] = $issue.id
                }
            }
        }
        
        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
        
    } catch {
        Write-Error "Failed to fetch batch $($BatchIndex + 1): $($_.Exception.Message)"
    }
    }
}

$totalExported = $allIssues.Count

Write-Host ""
Write-Host "=== PHASE 3: GETTING CHANGELOG DATA ==="

$issuesWithChangelog = @()
$changelogBatchSize = 50  # Smaller batches for individual API calls

Write-Host "  Fetching changelog for $($allIssues.Count) issues in batches of $changelogBatchSize..."

# Split into batches for changelog fetching
for ($i = 0; $i -lt $allIssues.Count; $i += $changelogBatchSize) {
    $batch = $allIssues[$i..([Math]::Min($i + $changelogBatchSize - 1, $allIssues.Count - 1))]
    $batchNum = [Math]::Floor($i / $changelogBatchSize) + 1
    $totalBatches = [Math]::Ceiling($allIssues.Count / $changelogBatchSize)
    
    Write-Host "  Processing changelog batch $batchNum/$totalBatches with $($batch.Count) issues..."
    
    foreach ($issue in $batch) {
        $issueKey = $issue.key
        $issueId = $issue.id
        
        try {
            # Get changelog for this issue
            $changelogUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$issueKey/changelog"
            $changelogResponse = Invoke-RestMethod -Uri $changelogUri -Method Get -Headers $srcHdr -ErrorAction Stop
            
            # Add changelog to the issue object
            $issue | Add-Member -NotePropertyName "changelog" -NotePropertyValue $changelogResponse -Force
            $issuesWithChangelog += $issue
            
            if ($changelogResponse.values.Count -gt 0) {
                Write-Host "    ✅ ${issueKey}: $($changelogResponse.values.Count) history entries"
            }
            
        } catch {
            Write-Host "    ⚠️  ${issueKey}: Failed to get changelog - $($_.Exception.Message)" -ForegroundColor Yellow
            # Add empty changelog to maintain consistency
            $issue | Add-Member -NotePropertyName "changelog" -NotePropertyValue @{ values = @() } -Force
            $issuesWithChangelog += $issue
        }
    }
}

$allIssues = $issuesWithChangelog
Write-Host "  ✅ Changelog fetch complete: $($allIssues.Count) issues processed"

Write-Host ""
Write-Host "=== EXPORT SUMMARY ==="
Write-Host "Total issues exported: $totalExported"
Write-Host "Key->ID mappings created: $($keyToIdMap.Count)"

# Analyze issue types
$issueTypeCounts = @{}
foreach ($issue in $allIssues) {
    $type = $issue.fields.issuetype.name
    if ($issueTypeCounts.ContainsKey($type)) {
        $issueTypeCounts[$type]++
    } else {
        $issueTypeCounts[$type] = 1
    }
}

Write-Host ""
Write-Host "Issue type breakdown:"
foreach ($type in ($issueTypeCounts.Keys | Sort-Object)) {
    Write-Host "  - $type : $($issueTypeCounts[$type]) issues"
}

# Analyze status distribution
$statusCounts = @{}
foreach ($issue in $allIssues) {
    $status = $issue.fields.status.name
    if ($statusCounts.ContainsKey($status)) {
        $statusCounts[$status]++
    } else {
        $statusCounts[$status] = 1
    }
}

Write-Host ""
Write-Host "Status distribution:"
foreach ($status in ($statusCounts.Keys | Sort-Object)) {
    Write-Host "  - $status : $($statusCounts[$status]) issues"
}

# Save export data to files
$exportDir = Join-Path $outDir "exports"
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
}

# Clean up existing export files to ensure fresh start
Write-Host ""
Write-Host "=== CLEANING UP EXISTING EXPORT FILES ===" -ForegroundColor Yellow
$exportFile = Join-Path $exportDir "source_issues_export.json"
$mappingFile = Join-Path $exportDir "key_to_id_mapping.json"

$deletedFiles = 0
if (Test-Path $exportFile) {
    Remove-Item -Path $exportFile -Force
    Write-Host "  ✓ Deleted existing: source_issues_export.json" -ForegroundColor Gray
    $deletedFiles++
}
if (Test-Path $mappingFile) {
    Remove-Item -Path $mappingFile -Force
    Write-Host "  ✓ Deleted existing: key_to_id_mapping.json" -ForegroundColor Gray
    $deletedFiles++
}

if ($deletedFiles -eq 0) {
    Write-Host "  No existing export files to clean up" -ForegroundColor Green
} else {
    Write-Host "  Cleaned up $deletedFiles existing export files" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== SAVING EXPORT DATA ==="
Write-Host "Saving issues to: $exportFile"
Write-Host "Saving mapping to: $mappingFile"

try {
    # Ensure we always write valid JSON, even for empty arrays/objects
    if ($allIssues.Count -eq 0) {
        "[]" | Out-File -FilePath $exportFile -Encoding UTF8
    } else {
        $allIssues | ConvertTo-Json -Depth 20 | Out-File -FilePath $exportFile -Encoding UTF8
    }
    
    if ($keyToIdMap.Count -eq 0) {
        "{}" | Out-File -FilePath $mappingFile -Encoding UTF8
    } else {
        $keyToIdMap | ConvertTo-Json -Depth 3 | Out-File -FilePath $mappingFile -Encoding UTF8
    }
    
    Write-Host "Export data saved successfully"
} catch {
    Write-Warning "Failed to save export data: $($_.Exception.Message)"
}

# Create issue export summary report for CSV export
$issueExportReport = @()

# Add export summary statistics
$issueExportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Export Scope"
    Value = $exportScope
    Details = "Scope of issues exported"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Issues Exported"
    Value = $totalExported
    Details = "Total number of issues exported"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Key to ID Mappings"
    Value = $keyToIdMap.Count
    Details = "Issue key to ID mappings created"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Include Closed Issues"
    Value = $includeClosedIssues
    Details = "Whether closed issues were included"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Include Sub-tasks"
    Value = $p.AnalysisSettings.IncludeSubTasks
    Details = "Whether sub-tasks were included"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add issue type counts
foreach ($issueType in $issueTypeCounts.GetEnumerator()) {
    $issueExportReport += [PSCustomObject]@{
        Type = "Issue Type"
        Name = $issueType.Key
        Value = $issueType.Value
        Details = "Count of issues by type"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add status counts
foreach ($status in $statusCounts.GetEnumerator()) {
    $issueExportReport += [PSCustomObject]@{
        Type = "Status"
        Name = $status.Key
        Value = $status.Value
        Details = "Count of issues by status"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Add export file information
$issueExportReport += [PSCustomObject]@{
    Type = "File"
    Name = "Export File"
    Value = Split-Path $exportFile -Leaf
    Details = "Main export file path"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "File"
    Name = "Mapping File"
    Value = Split-Path $mappingFile -Leaf
    Details = "Key to ID mapping file path"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to issue export report
$issueExportReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$issueExportReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export issue export summary report to CSV
$csvPath = Join-Path $outDir "07_ExportIssues_SummaryReport.csv"
$issueExportReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Issue export summary report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($issueExportReport.Count)" -ForegroundColor Cyan

# Create detailed receipt
Write-StageReceipt -OutDir $outDir -Stage "07_ExportIssues_Source" -Data @{
    SourceProject = @{ key=$srcKey; name=$srcProject.name; id=$srcProject.id }
    ExportScope = $exportScope
    JQLQuery = $jql
    TotalIssuesExported = $totalExported
    KeyToIdMappings = $keyToIdMap.Count
    IssueTypeCounts = $issueTypeCounts
    StatusCounts = $statusCounts
    ExportFile = $exportFile
    MappingFile = $mappingFile
    SearchBatchSize = $searchBatchSize
    BulkFetchBatchSize = $bulkFetchBatchSize
    IncludeClosedIssues = $includeClosedIssues
    IncludeSubTasks = $p.AnalysisSettings.IncludeSubTasks
    ExportedFields = $fields
    KeyToIdMapping = $keyToIdMap
}

exit 0
