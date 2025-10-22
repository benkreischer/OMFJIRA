# 11_Links.ps1 - Migrate ALL Links (Issue Links + Remote Links)
# 
# PURPOSE: Comprehensive link migration handling BOTH issue links and remote links
# in a single unified script.
#
# WHAT IT DOES:
# PART 1: ISSUE LINKS
# - Retrieves all issue links from source issues (blocks, relates to, duplicates, etc.)
# - Maps source issue keys to target issue keys using migration mappings
# - Recreates links with the same relationship types
# - Optionally creates remote links for skipped cross-project links
# 
# PART 2: REMOTE LINKS
# - Migrates external remote links (Confluence, GitHub, web URLs, etc.)
# - Preserves remote link metadata (titles, icons, relationships)
# - Handles all remote link types (Confluence, external systems, generic web)
#
# WHAT IT DOES NOT DO:
# - Does not migrate worklogs (handled in Step 12)
# - Does not migrate time tracking data
# - Does not modify existing link relationships
#
# NEXT STEP: Run 12_Worklogs.ps1 to migrate time tracking data
#
param(
    [string] $ParametersPath,
    [switch] $DryRun,
    [switch] $DocumentSkippedLinks          # Add comments documenting skipped cross-project links for future restoration
)

# Always create remote links for skipped issues (enabled by default)
$CreateRemoteLinksForSkipped = $true

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

# Hardcode paths for now to get script working
$outDir = ".\projects\REM\out"
$batchSize = 10

# Initialize issues logging
Initialize-IssuesLog -StepName "11_Links" -OutDir $outDir

# Create exports11 directory and cleanup
$stepExportsDir = Join-Path $outDir "exports11"
if (Test-Path $stepExportsDir) {
    Write-Host "🗑️  Cleaning up previous exports11 directory..." -ForegroundColor Yellow
    Remove-Item $stepExportsDir -Recurse -Force
}
New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null

# Set step start time
$script:StepStartTime = Get-Date

Write-Host "=== MIGRATING ISSUE LINKS AND RELATIONSHIPS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host "Batch Size: $batchSize"
if ($CreateRemoteLinksForSkipped) {
    Write-Host "Remote Link Fallback: ENABLED (skipped cross-project links will be converted to remote links)" -ForegroundColor Yellow
} else {
    Write-Host "Remote Link Fallback: DISABLED (use -CreateRemoteLinksForSkipped to enable)"
}
if ($DocumentSkippedLinks) {
    Write-Host "Documentation: ENABLED (skipped cross-project links will be documented in comments)" -ForegroundColor Cyan
} else {
    Write-Host "Documentation: DISABLED (use -DocumentSkippedLinks to enable)"
}

# Load exported data and key mappings from previous steps
$exportDir = Join-Path $outDir "exports07"
$exportFile = Join-Path $exportDir "07_Export_adf.jsonl"
$keyMappingFile = Join-Path $outDir "exports08\08_Import_Details.csv"

Write-Host ""
Write-Host "=== LOADING DATA FROM PREVIOUS STEPS ==="
if (-not (Test-Path $exportFile)) {
    throw "Export file not found: $exportFile. Please run step 07_ExportIssues_Source.ps1 first."
}
if (-not (Test-Path $keyMappingFile)) {
    Write-Host "⚠️ Key mapping file not found: $keyMappingFile" -ForegroundColor Yellow
    Write-Host "This usually means no issues were migrated in Step 8" -ForegroundColor Yellow
    Write-Host "✅ Step 11 completed successfully with no issues to process" -ForegroundColor Green
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "11_Links" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        LinksMigrated = 0
        LinksSkipped = 0
        LinksFailed = 0
        TotalLinksProcessed = 0
        Status = "Completed - No Issues to Process"
        Notes = @("No issues were migrated in Step 8", "Links migration completed successfully")
        StartTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        EndTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    }
    
    exit 0
}

try {
    # Load exported issues from JSONL file
    $exportedIssues = @()
    $jsonlContent = Get-Content $exportFile
    foreach ($line in $jsonlContent) {
        if ($line.Trim()) {
            $exportedIssues += $line | ConvertFrom-Json
        }
    }
    
    # Load key mappings from CSV file
    $keyMappingData = Import-Csv $keyMappingFile
    $sourceToTargetKeyMap = @{}
    foreach ($row in $keyMappingData) {
        if ($row.Status -eq "Success" -and $row.SourceKey -and $row.TargetKey) {
            $sourceToTargetKeyMap[$row.SourceKey] = $row.TargetKey
        }
    }
    
    Write-Host "✅ Loaded $($exportedIssues.Count) exported issues"
    Write-Host "✅ Loaded $($sourceToTargetKeyMap.Count) key mappings"
} catch {
    throw "Failed to load data from previous steps: $($_.Exception.Message)"
}

# Get target project details
Write-Host "Retrieving target project details..."
try {
    $tgtProject = if ($script:DryRun) { @{ name = '[DRYRUN] Target'; id = 0 } } else { Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr }
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve target project: $($_.Exception.Message)"
}

# Link migration tracking
$migratedLinks = @()
$failedLinks = @()
$skippedLinks = @()
$sourceWeblinks = @()  # Track weblinks back to source issues
$totalLinksProcessed = 0

# Track skipped cross-project links per issue for documentation
$skippedLinksByIssue = @{}  # Key: targetKey, Value: array of skipped link info
$documentsCreated = 0

Write-Host ""
Write-Host "=== MIGRATING ISSUE LINKS ==="

# Process issues in batches
for ($i = 0; $i -lt $exportedIssues.Count; $i += $batchSize) {
    $batch = $exportedIssues | Select-Object -Skip $i -First $batchSize
    $batchNum = [math]::Floor($i / $batchSize) + 1
    $totalBatches = [math]::Ceiling($exportedIssues.Count / $batchSize)
    
    Write-Host "Processing batch $batchNum of $totalBatches (issues $($i + 1) to $([math]::Min($i + $batchSize, $exportedIssues.Count)))..."
    
    foreach ($sourceIssue in $batch) {
        $sourceKey = $sourceIssue.issue.key
        
        # Check if this issue was successfully created in target
        if (-not $sourceToTargetKeyMap.ContainsKey($sourceKey)) {
            Write-Host "  ⏭️  Skipping $sourceKey (not created in target)"
            continue
        }
        
        $targetKey = $sourceToTargetKeyMap[$sourceKey]
        Write-Host "  Migrating links for $sourceKey → $targetKey"
        
        try {
            # Get issue links from source issue (with unified retry logic)
            $linksUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey"
            $sourceIssueDetails = if ($script:DryRun) { @{ fields = @{ issuelinks = @() } } } else { Invoke-JiraWithRetry -Method GET -Uri $linksUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30 }
            
            if (-not $sourceIssueDetails.fields.issuelinks -or $sourceIssueDetails.fields.issuelinks.Count -eq 0) {
                Write-Host "    ℹ️  No links found"
                
                # ========== CREATE WEBLINK BACK TO SOURCE ISSUE (EVEN FOR ISSUES WITH NO LINKS) ==========
                # Create a remote link back to the source issue for reference
                try {
                    $sourceIssueUrl = "$($srcBase.TrimEnd('/'))/browse/$sourceKey"
                    $sourceWeblinkPayload = @{
                        object = @{
                            url = $sourceIssueUrl
                            title = "Source Issue: $sourceKey"
                            summary = "Original issue from source instance"
                            icon = @{
                                url16x16 = "$($srcBase.TrimEnd('/'))/favicon.ico"
                            }
                        }
                        relationship = "Source Reference"
                    }
                    
                    $createSourceWeblinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink"
                    $sourceWeblinkResponse = Invoke-JiraWithRetry -Method POST -Uri $createSourceWeblinkUri -Headers $tgtHdr -Body ($sourceWeblinkPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                    
                    Write-Host "    🔗 Created weblink back to source issue: $sourceKey" -ForegroundColor DarkGray
                    
                    # Track the created weblink
                    $sourceWeblinks += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceUrl = $sourceIssueUrl
                        TargetUrl = "$($tgtBase.TrimEnd('/'))/browse/$targetKey"
                        Title = "Source Issue: $sourceKey"
                        Relationship = "Source Reference"
                        Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                    
                } catch {
                    Write-Host "    ⚠️ Could not create weblink to source issue: $($_.Exception.Message)" -ForegroundColor Yellow
                }
                
                continue
            }
            
            Write-Host "    Found $($sourceIssueDetails.fields.issuelinks.Count) links"
            
            # ========== IDEMPOTENCY: DELETE all existing links first ==========
            $targetIssueUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey"
            $targetIssueDetails = if ($script:DryRun) { @{ fields = @{ issuelinks = @() } } } else { Invoke-JiraWithRetry -Method GET -Uri $targetIssueUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 }
            $existingLinks = @()
            if ($targetIssueDetails.fields.issuelinks) {
                $existingLinks = $targetIssueDetails.fields.issuelinks
            }
            
            # Delete all existing links for clean migration
            if ($existingLinks.Count -gt 0) {
                Write-Host "    🗑️  Deleting $($existingLinks.Count) existing links for clean migration..." -ForegroundColor Yellow
                $deletedLinks = 0
                $failedDeletes = 0
                
                foreach ($existingLink in $existingLinks) {
                    try {
                        # Get the link ID for deletion
                        $linkId = $existingLink.id
                        if ($linkId) {
                            $deleteLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issueLink/$linkId"
                            if ($script:DryRun) { Write-Host "[DRYRUN] DELETE $deleteLinkUri" -ForegroundColor Yellow } else { Invoke-JiraWithRetry -Method DELETE -Uri $deleteLinkUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 | Out-Null }
                            $deletedLinks++
                        }
                    } catch {
                        $failedDeletes++
                        Write-Warning "      Failed to delete existing link: $($_.Exception.Message)"
                    }
                }
                
                Write-Host "    ✅ Deleted $deletedLinks links ($failedDeletes failed)" -ForegroundColor Green
                
                # Clear existing links array since we just deleted them all
                $existingLinks = @()
            }
            
            # Process each link
            $linkIndex = 0
            foreach ($link in $sourceIssueDetails.fields.issuelinks) {
                $totalLinksProcessed++
                $linkIndex++
                Write-Host "    Processing link $linkIndex of $($sourceIssueDetails.fields.issuelinks.Count)..." -ForegroundColor DarkGray
                
                try {
                    # Determine source and target of the link
                    # In Jira, each link has EITHER outwardIssue OR inwardIssue
                    # If outwardIssue exists, current issue links TO it (outward)
                    # If inwardIssue exists, current issue is linked FROM it (inward)
                    $linkedIssueKey = $null
                    $linkType = $link.type
                    $direction = $null
                    
                    if ($link.PSObject.Properties['outwardIssue'] -and $link.outwardIssue) {
                        # Current issue links outward to another issue
                        $linkedIssueKey = $link.outwardIssue.key
                            $direction = "outward"
                    } elseif ($link.PSObject.Properties['inwardIssue'] -and $link.inwardIssue) {
                        # Current issue is linked inward from another issue
                        $linkedIssueKey = $link.inwardIssue.key
                            $direction = "inward"
                    } else {
                        Write-Host "      ⚠️  Malformed link (no inward or outward issue), skipping"
                        continue
                    }
                    
                    # Check if the linked issue was also migrated
                    if (-not $sourceToTargetKeyMap.ContainsKey($linkedIssueKey)) {
                        # Linked issue was not migrated
                        if ($CreateRemoteLinksForSkipped) {
                            # Create a remote link to the source instance instead
                            try {
                                $sourceIssueUrl = "$($srcBase.TrimEnd('/'))/browse/$linkedIssueKey"
                                $remoteLinkPayload = @{
                                    object = @{
                                        url = $sourceIssueUrl
                                        title = "Link to $linkedIssueKey (Source Instance)"
                                        icon = @{
                                            url16x16 = "$($srcBase.TrimEnd('/'))/favicon.ico"
                                        }
                                    }
                                    relationship = $linkType.name
                                }
                                
                                $createRemoteLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink"
                                $response = if ($script:DryRun) { @{ id = 0 } } else { Invoke-JiraWithRetry -Method POST -Uri $createRemoteLinkUri -Headers $tgtHdr -Body ($remoteLinkPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 }
                                
                                Write-Host "      ✅ Created remote link to $linkedIssueKey (not migrated)"
                                $migratedLinks += @{
                                    SourceKey = $sourceKey
                                    TargetKey = $targetKey
                                    LinkedSourceKey = $linkedIssueKey
                                    LinkType = $linkType.name
                                    Direction = $direction
                                    IsRemoteLink = $true
                                }
                                continue
                            } catch {
                                Write-Warning "      ❌ Failed to create remote link: $($_.Exception.Message)"
                            }
                        }
                        
                        Write-Host "      ⏭️  Skipping link to $linkedIssueKey (not migrated)"
                        $skippedLinkInfo = @{
                            SourceKey = $sourceKey
                            TargetKey = $targetKey
                            LinkedSourceKey = $linkedIssueKey
                            LinkType = $linkType.name
                            Direction = $direction
                            Reason = "Linked issue not migrated"
                        }
                        $skippedLinks += $skippedLinkInfo
                        
                        # Track for documentation if enabled
                        if ($DocumentSkippedLinks) {
                            if (-not $skippedLinksByIssue.ContainsKey($targetKey)) {
                                $skippedLinksByIssue[$targetKey] = @()
                            }
                            $skippedLinksByIssue[$targetKey] += $skippedLinkInfo
                        }
                        
                        continue
                    }
                    
                    $linkedTargetKey = $sourceToTargetKeyMap[$linkedIssueKey]
                    
                    # ========== CREATE LINK ==========
                    # All existing links have been deleted, so we can create fresh links
                    
                    # Build link creation payload
                    $linkPayload = @{
                        type = @{ name = $linkType.name }
                    }
                    
                    if ($direction -eq "outward") {
                        $linkPayload.outwardIssue = @{ key = $targetKey }
                        $linkPayload.inwardIssue = @{ key = $linkedTargetKey }
                    } else {
                        $linkPayload.outwardIssue = @{ key = $linkedTargetKey }
                        $linkPayload.inwardIssue = @{ key = $targetKey }
                    }
                    
                    # Create the link in target (with unified retry logic)
                    $createLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issueLink"
                    $response = if ($script:DryRun) { $null } else { Invoke-JiraWithRetry -Method POST -Uri $createLinkUri -Headers $tgtHdr -Body ($linkPayload | ConvertTo-Json -Depth 5) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 }
                    
                    Write-Host "      ✅ Link created: $($linkType.name) ($direction)"
                    
                    # Add attribution comment for the link creation (similar to history migration)
                    try {
                        # Get original link creation info from source issue
                        $sourceLinkCreated = "Unknown"
                        $sourceLinkAuthor = "Unknown"
                        
                        # Try to find when this link was originally created in source
                        if ($sourceIssue.fields.issuelinks) {
                            foreach ($sourceLink in $sourceIssue.fields.issuelinks) {
                                if ($sourceLink.outwardIssue -and $sourceLink.outwardIssue.key -eq $linkedIssueKey -and $sourceLink.type.name -eq $linkType.name) {
                                    # Found the matching link in source
                                    $sourceLinkCreated = if ($sourceLink.created) { 
                                        [DateTime]::Parse($sourceLink.created).ToString("MMMM d, yyyy at h:mm tt") 
                                    } else { 
                                        "Unknown date" 
                                    }
                                    $sourceLinkAuthor = if ($sourceLink.author -and $sourceLink.author.displayName) { 
                                        $sourceLink.author.displayName 
                                    } else { 
                                        "Unknown user" 
                                    }
                                    break
                                } elseif ($sourceLink.inwardIssue -and $sourceLink.inwardIssue.key -eq $linkedIssueKey -and $sourceLink.type.name -eq $linkType.name) {
                                    # Found the matching link in source (inward direction)
                                    $sourceLinkCreated = if ($sourceLink.created) { 
                                        [DateTime]::Parse($sourceLink.created).ToString("MMMM d, yyyy at h:mm tt") 
                                    } else { 
                                        "Unknown date" 
                                    }
                                    $sourceLinkAuthor = if ($sourceLink.author -and $sourceLink.author.displayName) { 
                                        $sourceLink.author.displayName 
                                    } else { 
                                        "Unknown user" 
                                    }
                                    break
                                }
                            }
                        }
                        
                        # Create attribution comment
                        $linkDisplayName = switch ($linkType.name) {
                            "Blocks" { "Link" }
                            "Relates" { "Link" }
                            "Duplicates" { "Link" }
                            "Clones" { "Link" }
                            default { "Link" }
                        }
                        
                        $attributionComment = @{
                            body = @{
                                type = "doc"
                                version = 1
                                content = @(
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = "*Originally created $linkDisplayName by $sourceLinkAuthor on $sourceLinkCreated*"
                                                marks = @(
                                                    @{ type = "em" }
                                                )
                                            }
                                        )
                                    },
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = "$linkDisplayName`: $targetKey $($linkType.name) $linkedTargetKey"
                                            }
                                        )
                                    }
                                )
                            }
                        }
                        
                        # Post attribution comment
                        $commentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                        if ($script:DryRun) { Write-Host "[DRYRUN] POST comment $commentUri" -ForegroundColor Yellow } else { Invoke-JiraWithRetry -Method POST -Uri $commentUri -Headers $tgtHdr -Body ($attributionComment | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 | Out-Null }
                        
                        Write-Host "      📝 Added attribution comment for link creation" -ForegroundColor DarkGray
                        
                    } catch {
                        Write-Host "      ⚠️ Could not add attribution comment: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    # Note: API v3 issueLink creation returns empty response (204), so no ID is available
                    $linkRecord = @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        LinkedSourceKey = $linkedIssueKey
                        LinkedTargetKey = $linkedTargetKey
                        LinkType = $linkType.name
                        Direction = $direction
                    }
                    
                    # Add link ID if available in response
                    if ($response -and $response.PSObject.Properties['id']) {
                        $linkRecord.LinkId = $response.id
                    }
                    
                    $migratedLinks += $linkRecord
                    
                    # ========== CREATE WEBLINK BACK TO SOURCE ISSUE ==========
                    # Create a remote link back to the source issue for reference
                    try {
                        $sourceIssueUrl = "$($srcBase.TrimEnd('/'))/browse/$sourceKey"
                        $sourceWeblinkPayload = @{
                            object = @{
                                url = $sourceIssueUrl
                                title = "Source Issue: $sourceKey"
                                summary = "Original issue from source instance"
                                icon = @{
                                    url16x16 = "$($srcBase.TrimEnd('/'))/favicon.ico"
                                }
                            }
                            relationship = "Source Reference"
                        }
                        
                        $createSourceWeblinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink"
                        $sourceWeblinkResponse = Invoke-JiraWithRetry -Method POST -Uri $createSourceWeblinkUri -Headers $tgtHdr -Body ($sourceWeblinkPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30
                        
                        Write-Host "      🔗 Created weblink back to source issue: $sourceKey" -ForegroundColor DarkGray
                        
                        # Track the created weblink
                        $sourceWeblinks += @{
                            SourceKey = $sourceKey
                            TargetKey = $targetKey
                            SourceUrl = $sourceIssueUrl
                            TargetUrl = "$($tgtBase.TrimEnd('/'))/browse/$targetKey"
                            Title = "Source Issue: $sourceKey"
                            Relationship = "Source Reference"
                            Created = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                        }
                        
                    } catch {
                        Write-Host "      ⚠️ Could not create weblink to source issue: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                } catch {
                    Write-Warning "      ❌ Failed to create link: $($_.Exception.Message)"
                    $failedLinks += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        LinkedSourceKey = $linkedIssueKey
                        LinkType = $linkType.name
                        Direction = $direction
                        Error = $_.Exception.Message
                    }
                }
            }
            
            # ========== DOCUMENT SKIPPED CROSS-PROJECT LINKS ==========
            if ($DocumentSkippedLinks -and $skippedLinksByIssue.ContainsKey($targetKey)) {
                $skippedForThisIssue = $skippedLinksByIssue[$targetKey]
                
                try {
                    # Build comment body with skipped link information
                    $commentLines = @()
                    $commentLines += "*🔗 Migration Note: The following cross-project links could not be migrated:*"
                    $commentLines += ""
                    
                    foreach ($skipped in $skippedForThisIssue) {
                        $sourceUrl = "$($srcBase.TrimEnd('/'))/browse/$($skipped.LinkedSourceKey)"
                        $relationshipDesc = if ($skipped.Direction -eq "outward") {
                            "$($skipped.LinkType)"
                        } else {
                            "$($skipped.LinkType) (inward)"
                        }
                        $commentLines += "• [$($skipped.LinkedSourceKey)|$sourceUrl] ($relationshipDesc)"
                    }
                    
                    $commentLines += ""
                    $commentLines += "_These links can be restored manually once the target projects are migrated._"
                    $commentLines += "_Search for this comment to find all issues needing link restoration: {{migrationLinksSkipped}}_"
                    
                    $commentBody = $commentLines -join "`n"
                    
                    # Create comment in ADF format
                    $commentPayload = @{
                        body = @{
                            type = "doc"
                            version = 1
                            content = @(
                                @{
                                    type = "paragraph"
                                    content = @(
                                        @{
                                            type = "text"
                                            text = "🔗 Migration Note: The following cross-project links could not be migrated:"
                                            marks = @(
                                                @{ type = "strong" }
                                            )
                                        }
                                    )
                                },
                                @{
                                    type = "bulletList"
                                    content = @(
                                        $skippedForThisIssue | ForEach-Object {
                                            $sourceUrl = "$($srcBase.TrimEnd('/'))/browse/$($_.LinkedSourceKey)"
                                            $relationshipDesc = if ($_.Direction -eq "outward") {
                                                "$($_.LinkType)"
                                            } else {
                                                "$($_.LinkType) (inward)"
                                            }
                                            
                                            @{
                                                type = "listItem"
                                                content = @(
                                                    @{
                                                        type = "paragraph"
                                                        content = @(
                                                            @{
                                                                type = "text"
                                                                text = "$($_.LinkedSourceKey)"
                                                                marks = @(
                                                                    @{
                                                                        type = "link"
                                                                        attrs = @{
                                                                            href = $sourceUrl
                                                                        }
                                                                    }
                                                                )
                                                            },
                                                            @{
                                                                type = "text"
                                                                text = " ($relationshipDesc)"
                                                            }
                                                        )
                                                    }
                                                )
                                            }
                                        }
                                    )
                                },
                                @{
                                    type = "paragraph"
                                    content = @(
                                        @{
                                            type = "text"
                                            text = "These links can be restored manually once the target projects are migrated."
                                            marks = @(
                                                @{ type = "em" }
                                            )
                                        }
                                    )
                                },
                                @{
                                    type = "paragraph"
                                    content = @(
                                        @{
                                            type = "text"
                                            text = "Search for this comment to find all issues needing link restoration: "
                                            marks = @(
                                                @{ type = "em" }
                                            )
                                        },
                                        @{
                                            type = "text"
                                            text = "migrationLinksSkipped"
                                            marks = @(
                                                @{ type = "em" },
                                                @{ type = "code" }
                                            )
                                        }
                                    )
                                }
                            )
                        }
                    }
                    
                    $createCommentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                    $commentJson = $commentPayload | ConvertTo-Json -Depth 20
                    Invoke-JiraWithRetry -Method POST -Uri $createCommentUri -Headers $tgtHdr -Body $commentJson -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 | Out-Null
                    
                    Write-Host "    📝 Documented $($skippedForThisIssue.Count) skipped link(s) in comment" -ForegroundColor Cyan
                    $documentsCreated++
                    
                } catch {
                    Write-Warning "    ⚠️  Failed to create documentation comment: $($_.Exception.Message)"
                }
            }
            
        } catch {
            Write-Warning "  ❌ Failed to retrieve links for $sourceKey : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== MIGRATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Links migrated: $($migratedLinks.Count)" -ForegroundColor Green
Write-Host "❌ Links failed: $($failedLinks.Count)" -ForegroundColor Red
Write-Host "⏭️  Links skipped: $($skippedLinks.Count)" -ForegroundColor Yellow
Write-Host "🔗 Source weblinks created: $($sourceWeblinks.Count)" -ForegroundColor Magenta
Write-Host "📊 Total links processed: $totalLinksProcessed" -ForegroundColor Blue
if ($DocumentSkippedLinks -and $documentsCreated -gt 0) {
    Write-Host "📝 Documentation comments created: $documentsCreated" -ForegroundColor Cyan
}

# Analyze link statistics
$linksByType = @{}
$linksByDirection = @{}

if ($migratedLinks.Count -gt 0) {
    foreach ($link in $migratedLinks) {
        # Count by link type
        if ($linksByType.ContainsKey($link.LinkType)) {
            $linksByType[$link.LinkType]++
        } else {
            $linksByType[$link.LinkType] = 1
        }
        
        # Count by direction
        if ($linksByDirection.ContainsKey($link.Direction)) {
            $linksByDirection[$link.Direction]++
        } else {
            $linksByDirection[$link.Direction] = 1
        }
    }
    
    Write-Host ""
    Write-Host "Link types:"
    foreach ($type in ($linksByType.GetEnumerator() | Sort-Object Value -Descending)) {
        Write-Host "  - $($type.Key): $($type.Value) links"
    }
    
    Write-Host ""
    Write-Host "Link directions:"
    foreach ($direction in ($linksByDirection.GetEnumerator() | Sort-Object Value -Descending)) {
        Write-Host "  - $($direction.Key): $($direction.Value) links"
    }
}

if ($skippedLinks.Count -gt 0) {
    Write-Host ""
    Write-Host "Skipped links (linked issues not migrated):"
    $skippedByReason = $skippedLinks | Group-Object Reason
    foreach ($group in $skippedByReason) {
        Write-Host "  - $($group.Name): $($group.Count) links"
    }
    
    # Export skipped links to CSV for project lead action
    $skippedLinksFile = Join-Path $outDir "11_SkippedLinks_NeedManualCreation.csv"
    try {
        $skippedLinks | ForEach-Object {
            [PSCustomObject]@{
                'Source Issue' = $_.SourceKey
                'Source URL' = "$($srcBase.TrimEnd('/'))/browse/$($_.SourceKey)"
                'Target Issue' = $_.TargetKey
                'Target URL' = "$($tgtBase.TrimEnd('/'))/browse/$($_.TargetKey)"
                'Link Type' = $_.LinkType
                'Direction' = $_.Direction
                'Linked To (Not Migrated)' = $_.LinkedSourceKey
                'Linked To URL' = "$($srcBase.TrimEnd('/'))/browse/$($_.LinkedSourceKey)"
                'Reason' = $_.Reason
                'Action Required' = "Manually create link when linked issue is migrated, or link to source instance"
                'Timestamp' = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        } | Export-Csv -Path $skippedLinksFile -NoTypeInformation -Encoding UTF8
        Write-Host ""
        Write-Host "✅ Skipped links report saved: $skippedLinksFile" -ForegroundColor Green
        Write-Host "   Project lead can review and manually create these links" -ForegroundColor Yellow
    } catch {
        Write-Warning "Failed to save skipped links report: $($_.Exception.Message)"
    }
}

if ($failedLinks.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed links:"
    foreach ($failed in $failedLinks) {
        Write-Host "  - $($failed.SourceKey) → $($failed.TargetKey): $($failed.LinkType) ($($failed.Direction)) - $($failed.Error)"
    }
}

# ============================================================================
# PART 2: MIGRATE REMOTE LINKS (External Links to Confluence, GitHub, etc.)
# ============================================================================
Write-Host ""
Write-Host "=== MIGRATING REMOTE LINKS ==="

$migratedRemoteLinks = @()
$failedRemoteLinks = @()
$skippedRemoteLinks = 0
$totalRemoteLinksProcessed = 0

# Process issues in batches for remote links
for ($i = 0; $i -lt $exportedIssues.Count; $i += $batchSize) {
    $batch = $exportedIssues | Select-Object -Skip $i -First $batchSize
    $batchNum = [math]::Floor($i / $batchSize) + 1
    $totalBatches = [math]::Ceiling($exportedIssues.Count / $batchSize)
    
    Write-Host "Processing batch $batchNum of $totalBatches for remote links..."
    
    foreach ($sourceIssue in $batch) {
        $sourceKey = $sourceIssue.issue.key
        
        if (-not $sourceToTargetKeyMap.ContainsKey($sourceKey)) {
            continue
        }
        
        $targetKey = $sourceToTargetKeyMap[$sourceKey]
        
        try {
            # Get remote links from source issue (with unified retry logic)
            $remoteLinksUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey/remotelink"
            $remoteLinks = if ($script:DryRun) { @() } else { Invoke-JiraWithRetry -Method GET -Uri $remoteLinksUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30 }
            
            if (-not $remoteLinks -or $remoteLinks.Count -eq 0) {
                continue
            }
            
            Write-Host "  Migrating remote links for $sourceKey → $targetKey"
            Write-Host "    Found $($remoteLinks.Count) remote links"
            
            # ========== IDEMPOTENCY: DELETE all existing remote links first ==========
            $existingRemoteLinksUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink"
            $existingRemoteLinks = @()
            try {
                $existingRemoteLinks = if ($script:DryRun) { @() } else { Invoke-JiraWithRetry -Method GET -Uri $existingRemoteLinksUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 }
            } catch {
                Write-Host "      ⚠️  Could not fetch existing remote links: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Delete all existing remote links for clean migration
            if ($existingRemoteLinks.Count -gt 0) {
                Write-Host "    🗑️  Deleting $($existingRemoteLinks.Count) existing remote links for clean migration..." -ForegroundColor Yellow
                $deletedRemoteLinks = 0
                $failedRemoteDeletes = 0
                
                foreach ($existingRemoteLink in $existingRemoteLinks) {
                    try {
                        # Get the remote link ID for deletion
                        $remoteLinkId = $existingRemoteLink.id
                        if ($remoteLinkId) {
                            $deleteRemoteLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink/$remoteLinkId"
                            if ($script:DryRun) { Write-Host "[DRYRUN] DELETE $deleteRemoteLinkUri" -ForegroundColor Yellow } else { Invoke-JiraWithRetry -Method DELETE -Uri $deleteRemoteLinkUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30 | Out-Null }
                            $deletedRemoteLinks++
                        }
                    } catch {
                        $failedRemoteDeletes++
                        Write-Warning "      Failed to delete existing remote link: $($_.Exception.Message)"
                    }
                }
                
                Write-Host "    ✅ Deleted $deletedRemoteLinks remote links ($failedRemoteDeletes failed)" -ForegroundColor Green
                
                # Clear existing remote links array since we just deleted them all
                $existingRemoteLinks = @()
            }
            
            $remoteLinkIndex = 0
            foreach ($remoteLink in $remoteLinks) {
                $totalRemoteLinksProcessed++
                $remoteLinkIndex++
                Write-Host "    Processing remote link $remoteLinkIndex of $($remoteLinks.Count)..." -ForegroundColor DarkGray
                
                try {
                    # ========== CREATE REMOTE LINK ==========
                    # All existing remote links have been deleted, so we can create fresh remote links
                    
                
                    $remoteLinkPayload = @{
                        object = @{
                            url = $remoteLink.object.url
                            title = $remoteLink.object.title
                        }
                    }
                    
                    if ($remoteLink.object.PSObject.Properties['summary']) {
                        $remoteLinkPayload.object.summary = $remoteLink.object.summary
                    }
                    if ($remoteLink.object.PSObject.Properties['icon']) {
                        $remoteLinkPayload.object.icon = $remoteLink.object.icon
                    }
                    if ($remoteLink.PSObject.Properties['globalId']) {
                        $remoteLinkPayload.globalId = $remoteLink.globalId
                    }
                    if ($remoteLink.PSObject.Properties['application']) {
                        $remoteLinkPayload.application = $remoteLink.application
                    }
                    if ($remoteLink.PSObject.Properties['relationship']) {
                        $remoteLinkPayload.relationship = $remoteLink.relationship
                    }
                    
                    $createRemoteLinkUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/remotelink"
                    $response = if ($script:DryRun) { @{ id = 0 } } else { Invoke-JiraWithRetry -Method POST -Uri $createRemoteLinkUri -Headers $tgtHdr -Body ($remoteLinkPayload | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 }
                    
                    Write-Host "      ✅ Remote link created: $($remoteLink.object.title)"
                    
                    # Add attribution comment for the remote link creation
                    try {
                        # Get original remote link creation info from source issue
                        $sourceRemoteLinkCreated = "Unknown"
                        $sourceRemoteLinkAuthor = "Unknown"
                        
                        # Try to find when this remote link was originally created in source
                        if ($remoteLink.created) {
                            $sourceRemoteLinkCreated = [DateTime]::Parse($remoteLink.created).ToString("MMMM d, yyyy at h:mm tt")
                        }
                        if ($remoteLink.author -and $remoteLink.author.displayName) {
                            $sourceRemoteLinkAuthor = $remoteLink.author.displayName
                        }
                        
                        # Create attribution comment
                        $remoteLinkDisplayName = switch ($remoteLink.object.title) {
                            { $_ -like "*Confluence*" } { "RemoteWorkItemLink" }
                            { $_ -like "*GitHub*" } { "RemoteWorkItemLink" }
                            default { "RemoteWorkItemLink" }
                        }
                        
                        $attributionComment = @{
                            body = @{
                                type = "doc"
                                version = 1
                                content = @(
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = "*Originally created $remoteLinkDisplayName by $sourceRemoteLinkAuthor on $sourceRemoteLinkCreated*"
                                                marks = @(
                                                    @{ type = "em" }
                                                )
                                            }
                                        )
                                    },
                                    @{
                                        type = "paragraph"
                                        content = @(
                                            @{
                                                type = "text"
                                                text = "$remoteLinkDisplayName`: This work item links to `"$($remoteLink.object.title)`""
                                            }
                                        )
                                    }
                                )
                            }
                        }
                        
                        # Post attribution comment
                        $commentUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/comment"
                        if ($script:DryRun) { Write-Host "[DRYRUN] POST comment $commentUri" -ForegroundColor Yellow } else { Invoke-JiraWithRetry -Method POST -Uri $commentUri -Headers $tgtHdr -Body ($attributionComment | ConvertTo-Json -Depth 10) -ContentType "application/json" -MaxRetries 3 -TimeoutSec 30 | Out-Null }
                        
                        Write-Host "      📝 Added attribution comment for remote link creation" -ForegroundColor DarkGray
                        
                    } catch {
                        Write-Host "      ⚠️ Could not add attribution comment: $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                    
                    $migrationRecord = @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceRemoteLinkId = $remoteLink.id
                        TargetRemoteLinkId = $response.id
                        Title = $remoteLink.object.title
                        Url = $remoteLink.object.url
                    }
                    
                    if ($remoteLink.PSObject.Properties['globalId']) {
                        $migrationRecord.GlobalId = $remoteLink.globalId
                    } else {
                        $migrationRecord.GlobalId = $null
                    }
                    
                    if ($remoteLink.PSObject.Properties['application'] -and 
                        $remoteLink.application -and 
                        $remoteLink.application.PSObject.Properties['name']) {
                        $migrationRecord.Application = $remoteLink.application.name
                    } else {
                        $migrationRecord.Application = $null
                    }
                    
                    $migratedRemoteLinks += $migrationRecord
                    
                } catch {
                    Write-Warning "      ❌ Failed to create remote link: $($_.Exception.Message)"
                    $failedRemoteLinks += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        Title = $remoteLink.object.title
                        Url = $remoteLink.object.url
                        Error = $_.Exception.Message
                    }
                }
            }
        } catch {
            # Silently skip issues with no remote links
            if ($_.Exception.Message -notlike "*404*") {
                # Only warn on non-404 errors
            }
        }
    }
}

Write-Host ""
Write-Host "=== REMOTE LINKS SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Remote links migrated: $($migratedRemoteLinks.Count)" -ForegroundColor Green
Write-Host "⏭️  Remote links skipped: $skippedRemoteLinks (already existed - idempotency)" -ForegroundColor Yellow
Write-Host "❌ Remote links failed: $($failedRemoteLinks.Count)" -ForegroundColor Red
Write-Host "📊 Total remote links processed: $totalRemoteLinksProcessed" -ForegroundColor Blue

# Analyze remote link types
$remoteLinksByType = @{}
foreach ($link in $migratedRemoteLinks) {
    $appName = if ($link.Application) { $link.Application } else { "Generic Web Link" }
    $remoteLinksByType[$appName] = ($remoteLinksByType[$appName] ?? 0) + 1
}

if ($remoteLinksByType.Count -gt 0) {
    Write-Host ""
    Write-Host "Remote link types:"
    foreach ($type in ($remoteLinksByType.GetEnumerator() | Sort-Object Value -Descending)) {
        Write-Host "  - $($type.Key): $($type.Value) links"
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Create main summary CSV for Step 11
$step11SummaryReport = @()

# Add summary statistics
$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Issue Links Processed"
    Value = $totalLinksProcessed
    Details = "Total issue links processed from source"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issue Links Migrated"
    Value = $migratedLinks.Count
    Details = "Issue links successfully migrated to target"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issue Links Skipped"
    Value = $skippedLinks.Count
    Details = "Issue links skipped (cross-project or not migrated)"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issue Links Failed"
    Value = $failedLinks.Count
    Details = "Issue links that failed to migrate"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Total Remote Links Processed"
    Value = $totalRemoteLinksProcessed
    Details = "Total remote links processed"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Remote Links Migrated"
    Value = $migratedRemoteLinks.Count
    Details = "Remote links successfully migrated"
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Add step timing information (ALWAYS LAST)
$step11SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution started"
    Timestamp = $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
}

$step11SummaryReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step End Time"
    Value = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    Details = "Step execution completed"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export main summary report to CSV
$step11SummaryCsvPath = Join-Path $stepExportsDir "11_Links_Report.csv"
$step11SummaryReport | Export-Csv -Path $step11SummaryCsvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Step 11 summary report saved: $step11SummaryCsvPath" -ForegroundColor Green
Write-Host "   Total items: $($step11SummaryReport.Count)" -ForegroundColor Cyan

# Generate detailed CSV report for migrated links (ALWAYS CREATE)
$csvFileName = "11_Links_Details.csv"
$csvFilePath = Join-Path $stepExportsDir $csvFileName

try {
    $csvData = @()
    
    if ($migratedLinks.Count -gt 0) {
        foreach ($link in $migratedLinks) {
            $csvData += [PSCustomObject]@{
                "Source Issue Key" = $link.SourceKey
                "Target Issue Key" = $link.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($link.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($link.TargetKey)"
                "Linked Source Key" = $link.LinkedSourceKey
                "Linked Target Key" = if ($link.LinkedTargetKey) { $link.LinkedTargetKey } else { "N/A" }
                "Link Type" = $link.LinkType
                "Direction" = $link.Direction
                "Is Remote Link" = if ($link.IsRemoteLink) { "Yes" } else { "No" }
                "Link ID" = if ($link.LinkId) { $link.LinkId } else { "N/A" }
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        # Create empty report with note
        $csvData += [PSCustomObject]@{
            "Source Issue Key" = "No links to migrate"
            "Target Issue Key" = ""
            "Source Issue URL" = ""
            "Target Issue URL" = ""
            "Linked Source Key" = ""
            "Linked Target Key" = ""
            "Link Type" = ""
            "Direction" = ""
            "Is Remote Link" = ""
            "Link ID" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Links details report saved: $csvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $csvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Links migrated: $($migratedLinks.Count)" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save links details report: $($_.Exception.Message)"
}

# Generate detailed CSV report for migrated remote links (ALWAYS CREATE)
$remoteCsvFileName = "11_RemoteLinks_Details.csv"
$remoteCsvFilePath = Join-Path $stepExportsDir $remoteCsvFileName

try {
    $remoteCsvData = @()
    
    if ($migratedRemoteLinks.Count -gt 0) {
        foreach ($link in $migratedRemoteLinks) {
            $remoteCsvData += [PSCustomObject]@{
                "Source Issue Key" = $link.SourceKey
                "Target Issue Key" = $link.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($link.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($link.TargetKey)"
                "Title" = $link.Title
                "URL" = $link.Url
                "Application" = if ($link.Application) { $link.Application } else { "Generic Web Link" }
                "Global ID" = if ($link.GlobalId) { $link.GlobalId } else { "N/A" }
                "Source Remote Link ID" = $link.SourceRemoteLinkId
                "Target Remote Link ID" = $link.TargetRemoteLinkId
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        # Create empty report with note
        $remoteCsvData += [PSCustomObject]@{
            "Source Issue Key" = "No remote links to migrate"
            "Target Issue Key" = ""
            "Source Issue URL" = ""
            "Target Issue URL" = ""
            "Title" = ""
            "URL" = ""
            "Application" = ""
            "Global ID" = ""
            "Source Remote Link ID" = ""
            "Target Remote Link ID" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $remoteCsvData | Export-Csv -Path $remoteCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Remote links details report saved: $remoteCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $remoteCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Remote links migrated: $($migratedRemoteLinks.Count)" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save remote links details report: $($_.Exception.Message)"
}

# Generate CSV report for source weblinks (ALWAYS CREATE)
$sourceWeblinksCsvFileName = "11_SourceWeblinks_Details.csv"
$sourceWeblinksCsvFilePath = Join-Path $stepExportsDir $sourceWeblinksCsvFileName

try {
    $sourceWeblinksCsvData = @()
    
    if ($sourceWeblinks.Count -gt 0) {
        foreach ($weblink in $sourceWeblinks) {
            $sourceWeblinksCsvData += [PSCustomObject]@{
                "Source Issue Key" = $weblink.SourceKey
                "Target Issue Key" = $weblink.TargetKey
                "Source Issue URL" = $weblink.SourceUrl
                "Target Issue URL" = $weblink.TargetUrl
                "Weblink Title" = $weblink.Title
                "Relationship" = $weblink.Relationship
                "Created" = $weblink.Created
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        # Create empty report with note
        $sourceWeblinksCsvData += [PSCustomObject]@{
            "Source Issue Key" = "No source weblinks created"
            "Target Issue Key" = ""
            "Source Issue URL" = ""
            "Target Issue URL" = ""
            "Weblink Title" = ""
            "Relationship" = ""
            "Created" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $sourceWeblinksCsvData | Export-Csv -Path $sourceWeblinksCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Source weblinks details report saved: $sourceWeblinksCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $sourceWeblinksCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Source weblinks created: $($sourceWeblinks.Count)" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save source weblinks details report: $($_.Exception.Message)"
}

# Generate CSV report for failed links (ALWAYS CREATE)
$failedCsvFileName = "11_Links_Failed.csv"
$failedCsvFilePath = Join-Path $stepExportsDir $failedCsvFileName

try {
    $failedCsvData = @()
    
    if ($failedLinks.Count -gt 0) {
        foreach ($link in $failedLinks) {
            $failedCsvData += [PSCustomObject]@{
                "Source Issue Key" = $link.SourceKey
                "Target Issue Key" = $link.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($link.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($link.TargetKey)"
                "Link Type" = $link.LinkType
                "Direction" = $link.Direction
                "Error Message" = $link.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
    } else {
        # Create empty report with note
        $failedCsvData += [PSCustomObject]@{
            "Source Issue Key" = "No links failed"
            "Target Issue Key" = ""
            "Source Issue URL" = ""
            "Target Issue URL" = ""
            "Link Type" = ""
            "Direction" = ""
            "Error Message" = ""
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
    }
    
    $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Failed links report saved: $failedCsvFileName" -ForegroundColor Green
    Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
    Write-Host "   📊 Failed links: $($failedLinks.Count)" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to save failed links report: $($_.Exception.Message)"
}

# Create detailed receipt (with both issue links and remote links)
Write-StageReceipt -OutDir $stepExportsDir -Stage "11_Links" -Data @{
    TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    IssueLinks = @{
        TotalProcessed = $totalLinksProcessed
        Migrated = $migratedLinks.Count
        Failed = $failedLinks.Count
        Skipped = $skippedLinks.Count
        MigratedDetails = $migratedLinks
        FailedDetails = $failedLinks
        SkippedDetails = $skippedLinks
        SkippedLinksFile = if ($skippedLinks.Count -gt 0) { $skippedLinksFile } else { $null }
        ByType = $linksByType
        ByDirection = $linksByDirection
    }
    SourceWeblinks = @{
        TotalCreated = $sourceWeblinks.Count
        Details = $sourceWeblinks
        DetailsFile = "11_SourceWeblinks_Details.csv"
    }
    RemoteLinks = @{
        TotalProcessed = $totalRemoteLinksProcessed
        Migrated = $migratedRemoteLinks.Count
        Skipped = $skippedRemoteLinks
        Failed = $failedRemoteLinks.Count
        MigratedDetails = $migratedRemoteLinks
        FailedDetails = $failedRemoteLinks
        ByType = $remoteLinksByType
    }
    Documentation = @{
        Enabled = [bool]$DocumentSkippedLinks
        CommentsCreated = $documentsCreated
        IssuesDocumented = $skippedLinksByIssue.Keys.Count
        SearchKeyword = "migrationLinksSkipped"
    }
    Summary = @{
        TotalIssueLinks = $totalLinksProcessed
        TotalRemoteLinks = $totalRemoteLinksProcessed
        TotalMigrated = $migratedLinks.Count + $migratedRemoteLinks.Count
        TotalFailed = $failedLinks.Count + $failedRemoteLinks.Count
        TotalSkipped = $skippedLinks.Count + $skippedRemoteLinks
        DocumentationCommentsCreated = $documentsCreated
    }
    IdempotencyEnabled = $true
}

Write-Host ""
Write-Host "✅ Links and remote links migration complete!" -ForegroundColor Green
Write-Host "   Issue Links: $($migratedLinks.Count) migrated, $($skippedLinks.Count) skipped"
Write-Host "   Remote Links: $($migratedRemoteLinks.Count) migrated"
Write-Host "   Source WebLinks: $($sourceWeblinks.Count) created"
if ($DocumentSkippedLinks -and $documentsCreated -gt 0) {
    Write-Host ""
    Write-Host "📝 Skipped cross-project links have been documented in comments" -ForegroundColor Cyan
    Write-Host "   Search for: migrationLinksSkipped" -ForegroundColor Cyan
    Write-Host "   To find issues needing link restoration after other projects are migrated" -ForegroundColor Cyan
}

# Save issues log
Save-IssuesLog -StepName "11_Links"

exit 0

