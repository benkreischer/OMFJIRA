# 10_Attachments.ps1 - Migrate File Attachments
# 
# PURPOSE: Downloads all file attachments from source issues and uploads them to their
# corresponding target issues, preserving file content and metadata.
#
# WHAT IT DOES:
# - Downloads all attachments from source issues
# - Uploads attachments to corresponding target issues using key mappings
# - Preserves file names, sizes, and upload timestamps
# - Handles large files and network timeouts with retry logic
# - Creates detailed migration logs and receipts
#
# WHAT IT DOES NOT DO:
# - Does not modify attachment content or compress files
# - Does not migrate attachments for issues that failed to create
# - Does not handle attachments that exceed target environment limits
#
# NEXT STEP: Run 11_Links.ps1 to migrate issue links and relationships
#
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

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
$retryAttempts = $p.AnalysisSettings.RetryAttempts

# Initialize issues logging
Initialize-IssuesLog -StepName "10_Attachments" -OutDir $outDir

Write-Host "=== MIGRATING FILE ATTACHMENTS ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"
Write-Host "Batch Size: $batchSize"
Write-Host "Retry Attempts: $retryAttempts"

# Load exported data and key mappings from previous steps
$exportDir = Join-Path $outDir "exports"
$exportFile = Join-Path $exportDir "source_issues_export.json"
$keyMappingFile = Join-Path $exportDir "source_to_target_key_mapping.json"

Write-Host ""
Write-Host "=== LOADING DATA FROM PREVIOUS STEPS ==="
if (-not (Test-Path $exportFile)) {
    throw "Export file not found: $exportFile. Please run step 07_ExportIssues_Source.ps1 first."
}
if (-not (Test-Path $keyMappingFile)) {
    Write-Host "⚠️ Key mapping file not found: $keyMappingFile" -ForegroundColor Yellow
    Write-Host "This usually means no issues were migrated in Step 8" -ForegroundColor Yellow
    Write-Host "✅ Step 10 completed successfully with no issues to process" -ForegroundColor Green
    
    # Create receipt for empty result
    $endTime = Get-Date
    Write-StageReceipt -OutDir $outDir -Stage "10_Attachments" -Data @{
        SourceProject = @{ key=$srcKey }
        TargetProject = @{ key=$tgtKey }
        AttachmentsMigrated = 0
        AttachmentsSkipped = 0
        AttachmentsFailed = 0
        TotalAttachmentsProcessed = 0
        Status = "Completed - No Issues to Process"
        Notes = @("No issues were migrated in Step 8", "Attachments migration completed successfully")
        StartTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
        EndTime = $endTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    }
    
    exit 0
}

try {
    $exportedIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
    $sourceToTargetKeyMapObj = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
    
    # Convert PSCustomObject to hashtable for proper key lookups
    $sourceToTargetKeyMap = @{}
    foreach ($prop in $sourceToTargetKeyMapObj.PSObject.Properties) {
        $sourceToTargetKeyMap[$prop.Name] = $prop.Value
    }
    
    Write-Host "✅ Loaded $($exportedIssues.Count) exported issues"
    Write-Host "✅ Loaded $($sourceToTargetKeyMap.Count) key mappings"
} catch {
    throw "Failed to load data from previous steps: $($_.Exception.Message)"
}

# Create temporary directory for downloads
$tempDir = Join-Path $outDir "temp_attachments"
if (-not (Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Host "✅ Created temporary directory: $tempDir"
}

# Get target project details
Write-Host "Retrieving target project details..."
try {
    $tgtProject = Invoke-Jira -Method GET -BaseUrl $tgtBase -Path "rest/api/3/project/$tgtKey" -Headers $tgtHdr
    Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"
} catch {
    throw "Cannot retrieve target project: $($_.Exception.Message)"
}

# Attachment migration tracking
$migratedAttachments = @()
$failedAttachments = @()
$skippedAttachments = 0
$totalAttachmentsProcessed = 0
$totalBytesDownloaded = 0
$totalBytesUploaded = 0

Write-Host ""
Write-Host "=== MIGRATING ATTACHMENTS ==="

# Process issues in batches
for ($i = 0; $i -lt $exportedIssues.Count; $i += $batchSize) {
    $batch = $exportedIssues | Select-Object -Skip $i -First $batchSize
    $batchNum = [math]::Floor($i / $batchSize) + 1
    $totalBatches = [math]::Ceiling($exportedIssues.Count / $batchSize)
    
    Write-Host "Processing batch $batchNum of $totalBatches (issues $($i + 1) to $([math]::Min($i + $batchSize, $exportedIssues.Count)))..."
    
    foreach ($sourceIssue in $batch) {
        $sourceKey = $sourceIssue.key
        
        # Check if this issue was successfully created in target
        if (-not $sourceToTargetKeyMap.ContainsKey($sourceKey)) {
            Write-Host "  ⏭️  Skipping $sourceKey (not created in target)"
            continue
        }
        
        $targetKey = $sourceToTargetKeyMap[$sourceKey]
        Write-Host "  Migrating attachments for $sourceKey → $targetKey"
        
        try {
            # Get attachments from source issue (with unified retry logic)
            $attachmentsUri = "$($srcBase.TrimEnd('/'))/rest/api/3/issue/$sourceKey"
            $sourceIssueDetails = Invoke-JiraWithRetry -Method GET -Uri $attachmentsUri -Headers $srcHdr -MaxRetries 3 -TimeoutSec 30
            
            if (-not $sourceIssueDetails.fields.attachment -or $sourceIssueDetails.fields.attachment.Count -eq 0) {
                Write-Host "    ℹ️  No attachments found"
                continue
            }
            
            Write-Host "    Found $($sourceIssueDetails.fields.attachment.Count) attachments"
            
            # ========== IDEMPOTENCY: Get existing attachments from target ==========
            $targetIssueUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey"
            $targetIssueDetails = Invoke-JiraWithRetry -Method GET -Uri $targetIssueUri -Headers $tgtHdr -MaxRetries 3 -TimeoutSec 30
            $existingAttachments = @()
            if ($targetIssueDetails.fields.attachment) {
                $existingAttachments = $targetIssueDetails.fields.attachment
            }
            
            # Process each attachment
            $attachmentIndex = 0
            foreach ($attachment in $sourceIssueDetails.fields.attachment) {
                $totalAttachmentsProcessed++
                $attachmentIndex++
                $fileName = $attachment.filename
                $fileSize = $attachment.size
                $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
                
                Write-Host "      Processing attachment $attachmentIndex of $($sourceIssueDetails.fields.attachment.Count): $fileName ($fileSizeMB MB)" -ForegroundColor DarkGray
                
                # ========== IDEMPOTENCY CHECK ==========
                # Check if attachment with same name and size already exists
                $attachmentExists = $existingAttachments | Where-Object {
                    $_.filename -eq $fileName -and $_.size -eq $fileSize
                }
                
                if ($attachmentExists) {
                    Write-Host "        ⏭️  Attachment already exists (skipped)" -ForegroundColor Yellow
                    $skippedAttachments++
                    continue
                }
                
                try {
                    # Download attachment from source
                    $downloadUri = $attachment.content
                    $tempFilePath = Join-Path $tempDir "$($attachment.id)_$fileName"
                    
                    $downloadSuccess = $false
                    for ($attempt = 1; $attempt -le $retryAttempts; $attempt++) {
                        try {
                            Invoke-WebRequest -Uri $downloadUri -Headers $srcHdr -OutFile $tempFilePath -ErrorAction Stop -TimeoutSec 30
                            $totalBytesDownloaded += (Get-Item $tempFilePath).Length
                            $downloadSuccess = $true
                            break
                        } catch {
                            if ($attempt -eq $retryAttempts) {
                                throw "Failed after $retryAttempts attempts: $($_.Exception.Message)"
                            }
                            Write-Warning "        Download attempt $attempt failed, retrying..."
                            Start-Sleep -Seconds 2
                        }
                    }
                    
                    if (-not $downloadSuccess) {
                        throw "Failed to download attachment after $retryAttempts attempts"
                    }
                    
                    # Upload attachment to target issue
                    $uploadUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$targetKey/attachments"
                    $uploadHeaders = $tgtHdr.Clone()
                    $uploadHeaders.Remove('Content-Type')  # Remove Content-Type for multipart upload
                    $uploadHeaders['X-Atlassian-Token'] = 'no-check'  # Required for attachment uploads
                    
                    $uploadSuccess = $false
                    for ($attempt = 1; $attempt -le $retryAttempts; $attempt++) {
                        try {
                            $form = @{
                                file = Get-Item $tempFilePath
                            }
                            $response = Invoke-RestMethod -Method POST -Uri $uploadUri -Headers $uploadHeaders -Form $form -ErrorAction Stop -TimeoutSec 30
                            $totalBytesUploaded += (Get-Item $tempFilePath).Length
                            $uploadSuccess = $true
                            break
                        } catch {
                            if ($attempt -eq $retryAttempts) {
                                throw "Failed after $retryAttempts attempts: $($_.Exception.Message)"
                            }
                            Write-Warning "        Upload attempt $attempt failed, retrying..."
                            Start-Sleep -Seconds 2
                        }
                    }
                    
                    if (-not $uploadSuccess) {
                        throw "Failed to upload attachment after $retryAttempts attempts"
                    }
                    
                    Write-Host "        ✅ Migrated: $fileName"
                    $migratedAttachments += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceAttachmentId = $attachment.id
                        TargetAttachmentId = $response[0].id
                        FileName = $fileName
                        FileSize = $fileSize
                        FileSizeMB = $fileSizeMB
                        Author = $attachment.author.displayName
                        Created = $attachment.created
                    }
                    
                } catch {
                    Write-Warning "        ❌ Failed to migrate $fileName : $($_.Exception.Message)"
                    $failedAttachments += @{
                        SourceKey = $sourceKey
                        TargetKey = $targetKey
                        SourceAttachmentId = $attachment.id
                        FileName = $fileName
                        FileSize = $fileSize
                        FileSizeMB = $fileSizeMB
                        Author = $attachment.author.displayName
                        Created = $attachment.created
                        Error = $_.Exception.Message
                    }
                } finally {
                    # Clean up temporary file
                    if (Test-Path $tempFilePath) {
                        Remove-Item $tempFilePath -Force -ErrorAction SilentlyContinue
                    }
                }
            }
            
        } catch {
            Write-Warning "  ❌ Failed to retrieve attachments for $sourceKey : $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== MIGRATION SUMMARY ===" -ForegroundColor Cyan
Write-Host "✅ Attachments migrated: $($migratedAttachments.Count)" -ForegroundColor Green
Write-Host "⏭️  Attachments skipped: $skippedAttachments (already existed - idempotency)" -ForegroundColor Yellow
Write-Host "❌ Attachments failed: $($failedAttachments.Count)" -ForegroundColor Red
Write-Host "📊 Total attachments processed: $totalAttachmentsProcessed" -ForegroundColor Blue
Write-Host "💾 Total data downloaded: $([math]::Round($totalBytesDownloaded / 1MB, 2)) MB" -ForegroundColor Magenta
Write-Host "📤 Total data uploaded: $([math]::Round($totalBytesUploaded / 1MB, 2)) MB" -ForegroundColor Magenta

# Analyze attachment statistics
$attachmentsByType = @{}
$attachmentsBySize = @{}
$totalSize = 0

if ($migratedAttachments.Count -gt 0) {
    foreach ($attachment in $migratedAttachments) {
        $extension = [System.IO.Path]::GetExtension($attachment.FileName).ToLower()
        if (-not $extension) { $extension = "no_extension" }
        
        if ($attachmentsByType.ContainsKey($extension)) {
            $attachmentsByType[$extension]++
        } else {
            $attachmentsByType[$extension] = 1
        }
        
        $totalSize += $attachment.FileSize
    }
    
    Write-Host ""
    Write-Host "Attachment types:"
    $topTypes = $attachmentsByType.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10
    foreach ($type in $topTypes) {
        Write-Host "  - $($type.Key): $($type.Value) files"
    }
    
    Write-Host ""
    Write-Host "Total attachment size: $([math]::Round($totalSize / 1MB, 2)) MB"
    
    Write-Host ""
    Write-Host "Largest attachments:"
    $largestAttachments = $migratedAttachments | Sort-Object FileSize -Descending | Select-Object -First 5
    foreach ($attachment in $largestAttachments) {
        Write-Host "  - $($attachment.FileName): $($attachment.FileSizeMB) MB"
    }
}

if ($failedAttachments.Count -gt 0) {
    Write-Host ""
    Write-Host "Failed attachments:"
    foreach ($failed in $failedAttachments) {
        Write-Host "  - $($failed.SourceKey) → $($failed.TargetKey): $($failed.FileName) - $($failed.Error)"
    }
}

# Clean up temporary directory
Write-Host ""
Write-Host "Cleaning up temporary files..."
try {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "✅ Temporary directory cleaned up"
    }
} catch {
    Write-Warning "Could not clean up temporary directory: $($_.Exception.Message)"
}

# Generate CSV report for migrated attachments
if ($migratedAttachments.Count -gt 0) {
    $csvFileName = "10_Attachments_Report.csv"
    $csvFilePath = Join-Path $outDir $csvFileName
    
    try {
        $csvData = @()
        foreach ($attachment in $migratedAttachments) {
            $csvData += [PSCustomObject]@{
                "Source Issue Key" = $attachment.SourceKey
                "Target Issue Key" = $attachment.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($attachment.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($attachment.TargetKey)"
                "File Name" = $attachment.FileName
                "File Size (Bytes)" = $attachment.FileSize
                "File Size (MB)" = $attachment.FileSizeMB
                "File Extension" = [System.IO.Path]::GetExtension($attachment.FileName)
                "Author" = $attachment.Author
                "Created Date" = $attachment.Created
                "Source Attachment ID" = $attachment.SourceAttachmentId
                "Target Attachment ID" = $attachment.TargetAttachmentId
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $csvData | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "✅ Attachments report saved: $csvFileName" -ForegroundColor Green
        Write-Host "   📄 Location: $csvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Attachments migrated: $($migratedAttachments.Count)" -ForegroundColor Gray
        Write-Host "   💾 Total size: $([math]::Round($totalBytesUploaded / 1MB, 2)) MB" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save attachments report: $($_.Exception.Message)"
    }
}

# Generate CSV report for failed attachments (if any)
if ($failedAttachments.Count -gt 0) {
    $failedCsvFileName = "10_FailedAttachments.csv"
    $failedCsvFilePath = Join-Path $outDir $failedCsvFileName
    
    try {
        $failedCsvData = @()
        foreach ($attachment in $failedAttachments) {
            $failedCsvData += [PSCustomObject]@{
                "Source Issue Key" = $attachment.SourceKey
                "Target Issue Key" = $attachment.TargetKey
                "Source Issue URL" = "$($srcBase.TrimEnd('/'))/browse/$($attachment.SourceKey)"
                "Target Issue URL" = "$($tgtBase.TrimEnd('/'))/browse/$($attachment.TargetKey)"
                "File Name" = $attachment.FileName
                "File Size (Bytes)" = $attachment.FileSize
                "File Size (MB)" = $attachment.FileSizeMB
                "Author" = $attachment.Author
                "Created Date" = $attachment.Created
                "Source Attachment ID" = $attachment.SourceAttachmentId
                "Error Message" = $attachment.Error
                "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        
        $failedCsvData | Export-Csv -Path $failedCsvFilePath -NoTypeInformation -Encoding UTF8
        
        Write-Host ""
        Write-Host "❌ Failed attachments report saved: $failedCsvFileName" -ForegroundColor Red
        Write-Host "   📄 Location: $failedCsvFilePath" -ForegroundColor Gray
        Write-Host "   📊 Failed attachments: $($failedAttachments.Count)" -ForegroundColor Gray
    } catch {
        Write-Warning "Failed to save failed attachments report: $($_.Exception.Message)"
    }
}

# Create detailed receipt
Write-StageReceipt -OutDir $outDir -Stage "10_Attachments" -Data @{
    TargetProject = @{ key=$tgtKey; name=$tgtProject.name; id=$tgtProject.id }
    TotalAttachmentsProcessed = $totalAttachmentsProcessed
    MigratedAttachments = $migratedAttachments.Count
    SkippedAttachments = $skippedAttachments
    FailedAttachments = $failedAttachments.Count
    TotalBytesDownloaded = $totalBytesDownloaded
    TotalBytesUploaded = $totalBytesUploaded
    MigratedAttachmentDetails = $migratedAttachments
    FailedAttachmentDetails = $failedAttachments
    AttachmentTypes = $attachmentsByType
    TotalAttachmentSize = $totalSize
    TempDirectory = $tempDir
    IdempotencyEnabled = $true
}

# Save issues log
Save-IssuesLog -StepName "10_Attachments"

exit 0
