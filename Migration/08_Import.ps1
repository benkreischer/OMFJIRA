# 08_Import.ps1 - Create Issues in Target Jira
# 
# PURPOSE: Creates issues in the target Jira project using exported data from Step 07,
# with enhanced ADF processing for complex content structures.
#
# WHAT IT DOES:
# - Creates issues in target Jira using exported source data
# - Handles complex ADF structures, media nodes, inline links, and formatting
# - Processes custom fields with proper mapping and validation
# - Creates parent-child relationships and issue hierarchies
# - Generates detailed error logs and known issues CSV
#
# WHAT IT DOES NOT DO:
# - Does not migrate comments (handled in Step 09)
# - Does not migrate attachments (handled in Step 10)
# - Does not migrate links (handled in Step 11)
#
# NEXT STEP: Run 09_Comments.ps1 to migrate issue comments
#

param(
  [string]$ParametersPath = ".\migration-parameters.json",
  [string]$IssueMapPath = "",
  [switch]$CreateIfMissing,  # optional: create target issues when not found
  [switch]$DebugMode,  # optional: save detailed debug information
  [switch]$DryRun     # optional: simulate without calling Jira APIs
)

# -------------------- Local utilities --------------------

function New-BasicAuthHeader {
  param([Parameter(Mandatory=$true)][string]$Email,[Parameter(Mandatory=$true)][string]$ApiToken)
  $pair = "{0}:{1}" -f $Email, $ApiToken
  $b64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  return @{ Authorization = "Basic $b64"; Accept = "application/json" }
}

function Jira-GET  { param([string]$Uri,[hashtable]$Headers) return Invoke-RestMethod -Method Get  -Uri $Uri -Headers $Headers -ContentType 'application/json' }
function Jira-PUT  { param([string]$Uri,[hashtable]$Headers,$Body) return Invoke-RestMethod -Method Put  -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $Body }
function Jira-POST { param([string]$Uri,[hashtable]$Headers,$Body) return Invoke-RestMethod -Method Post -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $Body }

function Jira-POST-Multipart {
  param([string]$Uri,[hashtable]$Headers,[string]$FilePath)
  $localHeaders = @{"X-Atlassian-Token"="no-check"}
  foreach ($k in $Headers.Keys) { $localHeaders[$k] = $Headers[$k] }
  return Invoke-RestMethod -Method Post -Uri $Uri -Headers $localHeaders -InFile $FilePath -ContentType "multipart/form-data"
}

function Ensure-Folder { param([string]$Path) if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path | Out-Null } }

# -------------------- Enhanced ADF Handling Functions --------------------

# Validate ADF structure
function Validate-AdfStructure {
    param([Parameter(Mandatory=$true)]$Adf)
    
    if ($null -eq $Adf) { return $false }
    
    # Accept both hashtables and PSCustomObjects (from JSON deserialization)
    $isValidType = ($Adf -is [System.Collections.IDictionary]) -or ($Adf -is [PSCustomObject])
    if (-not $isValidType) { return $false }
    
    # Check for required properties (works for both hashtables and PSCustomObjects)
    if (-not $Adf.type -or $Adf.type -ne 'doc') { return $false }
    if (-not $Adf.version -or $Adf.version -ne 1) { return $false }
    if (-not $Adf.content) { return $false }
    
    return $true
}

# Extract text content from ADF for character count validation
function Extract-TextFromAdf {
    param($Adf)
    
    if (-not $Adf -or -not $Adf.content) { return "" }
    
    $text = ""
    foreach ($item in $Adf.content) {
        if ($item.type -eq "paragraph" -and $item.content) {
            foreach ($contentItem in $item.content) {
                if ($contentItem.type -eq "text" -and $contentItem.text) {
                    $text += $contentItem.text
                }
            }
        }
    }
    return $text.Trim()
}

# Clean and normalize ADF content - removes Confluence-specific attributes
function Clean-AdfContent {
    param(
        [Parameter(Mandatory=$true)]$Node,
        [int]$Depth = 0
    )
    
    # Prevent infinite recursion by limiting depth
    if ($Depth -gt 50) {
        Write-Warning "Clean-AdfContent: Maximum recursion depth reached ($Depth), stopping recursion"
        # Return a minimal valid ADF structure instead of null
        return @{
            type = "doc"
            version = 1
            content = @(
                @{
                    type = "paragraph"
                    content = @(
                        @{
                            type = "text"
                            text = "[Content truncated due to complexity]"
                        }
                    )
                }
            )
        }
    }
    
    if ($null -eq $Node) { return $null }
    
    # Handle arrays
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        $cleaned = @()
        foreach ($item in $Node) {
            $cleanedItem = Clean-AdfContent -Node $item -Depth ($Depth + 1)
            if ($null -ne $cleanedItem) {
                $cleaned += $cleanedItem
            }
        }
        return $cleaned
    }
    
    # Handle objects/hashtables
    if ($Node -is [System.Collections.IDictionary]) {
        $cleaned = @{}
        
        # Copy all properties except those that might cause issues
        foreach ($key in $Node.Keys) {
            # Skip internal Confluence properties that don't work in Jira
            if ($key -in @('__typename', '_id', '__confluenceMetadata')) {
                continue
            }
            
            $value = $Node[$key]
            
            # Recursively clean nested content
            if ($key -eq 'content' -or $key -eq 'marks') {
                $cleanedValue = Clean-AdfContent -Node $value -Depth ($Depth + 1)
                if ($null -ne $cleanedValue -and 
                    (-not ($cleanedValue -is [System.Collections.IEnumerable]) -or $cleanedValue.Count -gt 0)) {
                    $cleaned[$key] = $cleanedValue
                }
            }
            # Handle attrs specially
            elseif ($key -eq 'attrs' -and $value -is [System.Collections.IDictionary]) {
                $cleanedAttrs = @{}
                foreach ($attrKey in $value.Keys) {
                    # Skip problematic attributes
                    if ($attrKey -notin @('__confluenceMetadata', '_id', '__typename')) {
                        $cleanedAttrs[$attrKey] = $value[$attrKey]
                    }
                }
                if ($cleanedAttrs.Count -gt 0) {
                    $cleaned[$key] = $cleanedAttrs
                }
            }
            else {
                $cleaned[$key] = $value
            }
        }
        
        return $cleaned
    }
    
    # Return other types as-is
    return $Node
}

# Remove media references from ADF content (attachments handled separately)
function Remove-AdfMediaReferences {
  param(
    [Parameter(Mandatory=$true)]$Node,
    [int]$Depth = 0
  )
  
  # Prevent infinite recursion
  if ($Depth -gt 50) {
    Write-Warning "Remove-AdfMediaReferences: Maximum recursion depth reached ($Depth)"
    return $null
  }
  
  if ($null -eq $Node) { return $null }
  
  # Handle arrays
  if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
    $cleaned = @()
    foreach ($item in $Node) {
      $cleanedItem = Remove-AdfMediaReferences -Node $item -Depth ($Depth + 1)
      if ($null -ne $cleanedItem) {
        $cleaned += $cleanedItem
      }
    }
    return $cleaned
  }
  
  # Handle objects/hashtables
  if ($Node -is [System.Collections.IDictionary]) {
    # Skip mediaSingle and media nodes entirely
    if ($Node.type -eq 'mediaSingle' -or $Node.type -eq 'media') {
      Write-VerboseLog "  🗑️ Removing media reference: $($Node.type)" "Gray"
      return $null
    }
    
    $cleaned = @{}
    foreach ($key in $Node.Keys) {
      $value = $Node[$key]
      $cleanedValue = Remove-AdfMediaReferences -Node $value -Depth ($Depth + 1)
      if ($null -ne $cleanedValue) {
        $cleaned[$key] = $cleanedValue
      }
    }
    return $cleaned
  }
  
  # Return other types as-is
  return $Node
}

# Minimal ADF wrapper for plain text
function Convert-TextToAdf {
  param([string]$Text)
  if ([string]::IsNullOrEmpty($Text)) {
    return @{ version = 1; type = 'doc'; content = @() }
  }
  return @{
    version = 1
    type    = 'doc'
    content = @(
      @{
        type    = 'paragraph'
        content = @(
          @{ type = 'text'; text = $Text }
        )
      }
    )
  }
}

# Enhanced media ID rewriting with better error handling
function Rewrite-AdfMediaIds {
    param(
        [Parameter(Mandatory=$true)]$Node,
        [Parameter(Mandatory=$true)][hashtable]$AttachmentIdMap,
        [string]$DebugPath = ""  # For debugging nested structures
    )
    
    if ($null -eq $Node) { return $Node }
    
    # Handle arrays
    if ($Node -is [System.Collections.IEnumerable] -and -not ($Node -is [string])) {
        $arr = @()
        $index = 0
        foreach ($n in $Node) {
            $arr += ,(Rewrite-AdfMediaIds -Node $n -AttachmentIdMap $AttachmentIdMap -DebugPath "$DebugPath[$index]")
            $index++
        }
        return $arr
    }
    
    # Handle objects
    if ($Node -is [System.Collections.IDictionary]) {
        # Check if this is a media node
        if ($Node.type -eq "media" -or $Node.type -eq "mediaGroup" -or $Node.type -eq "mediaSingle") {
            Write-VerboseLog "    🔍 Found media node at path: $DebugPath" "Cyan"
            Write-VerboseLog "    📋 Node type: $($Node.type)" "Gray"
            
            # Handle mediaGroup and mediaSingle which contain media nodes
            if ($Node.type -eq "mediaGroup" -or $Node.type -eq "mediaSingle") {
                if ($Node.ContainsKey("content") -and $Node.content) {
                    for ($i = 0; $i -lt $Node.content.Count; $i++) {
                        $Node.content[$i] = Rewrite-AdfMediaIds -Node $Node.content[$i] -AttachmentIdMap $AttachmentIdMap -DebugPath "$DebugPath.content[$i]"
                    }
                }
                return $Node
            }
            
            # Handle actual media node
            if ($Node.attrs) {
                $attrs = $Node.attrs
                
                # Handle different media types
                $mediaId = $null
                $mediaType = $null
                
                if ($attrs.id) {
                    $mediaId = [string]$attrs.id
                    $mediaType = if ($attrs.type) { $attrs.type } else { "file" }
                }
                
                if ($mediaId) {
                    Write-VerboseLog "    🔍 Processing media ID: $mediaId (type: $mediaType)" "Gray"
                    
                    # Try direct ID mapping
                    $newId = $null
                    if ($AttachmentIdMap.ContainsKey($mediaId)) {
                        $newId = $AttachmentIdMap[$mediaId]
                        Write-VerboseLog "    ✅ Direct mapping found: $mediaId -> $newId" "Green"
                    }
                    # Try filename-based mapping
                    elseif ($attrs.alt -or $attrs.title -or $attrs.__fileName -or $attrs.filename) {
                        $filename = if ($attrs.__fileName) { $attrs.__fileName } 
                                   elseif ($attrs.filename) { $attrs.filename }
                                   elseif ($attrs.alt) { $attrs.alt } 
                                   else { $attrs.title }
                        
                        # Try different key combinations
                        $possibleKeys = @(
                            $filename,
                            "${filename}_$($attrs.__fileSize)",
                            "${filename}_$($attrs.size)",
                            "${filename}_$($attrs.width)x$($attrs.height)"
                        )
                        
                        foreach ($key in $possibleKeys) {
                            if ($AttachmentIdMap.ContainsKey($key)) {
                                $newId = $AttachmentIdMap[$key]
                                Write-VerboseLog "    ✅ Filename mapping found with key: $key -> $newId" "Green"
                                break
                            }
                        }
                    }
                    
                    if ($newId) {
                        $Node.attrs.id = $newId
                        # Ensure collection is set correctly for Jira
                        if ($mediaType -eq "file" -or -not $attrs.type) {
                            $Node.attrs.collection = "jira-issue-attachments"
                        }
                        # Remove Confluence-specific attributes that might cause issues
                        if ($Node.attrs.ContainsKey('__confluenceMetadata')) {
                            $Node.attrs.Remove('__confluenceMetadata')
                        }
                    } else {
                        Write-VerboseLog "    ⚠️ No mapping found for media ID: $mediaId" "Yellow"
                        
                        # For unmapped media, convert to a text placeholder
                        $altText = if ($attrs.alt) { $attrs.alt } 
                                  elseif ($attrs.title) { $attrs.title } 
                                  elseif ($attrs.filename) { $attrs.filename }
                                  else { "Image" }
                        
                        # Return a paragraph with a placeholder
                        return @{
                            type = "paragraph"
                            content = @(
                                @{
                                    type = "text"
                                    text = "[Missing Media: $altText]"
                                    marks = @(
                                        @{ type = "em" }
                                    )
                                }
                            )
                        }
                    }
                }
            }
        }
        
        # Handle inline links (type = "inlineCard")
        if ($Node.type -eq "inlineCard" -and $Node.attrs -and $Node.attrs.url) {
            Write-VerboseLog "    🔗 Found inline card with URL: $($Node.attrs.url)" "Gray"
            # Remove Confluence-specific attributes
            if ($Node.attrs.ContainsKey('__confluenceMetadata')) {
                $Node.attrs.Remove('__confluenceMetadata')
            }
        }
        
        # Recursively process content and marks
        if ($Node.ContainsKey("content") -and $Node.content) {
            for ($i = 0; $i -lt $Node.content.Count; $i++) {
                $Node.content[$i] = Rewrite-AdfMediaIds -Node $Node.content[$i] -AttachmentIdMap $AttachmentIdMap -DebugPath "$DebugPath.content[$i]"
            }
        }
        
        if ($Node.ContainsKey("marks") -and $Node.marks) {
            for ($i = 0; $i -lt $Node.marks.Count; $i++) {
                # Remove Confluence-specific mark attributes
                if ($Node.marks[$i] -is [System.Collections.IDictionary]) {
                    if ($Node.marks[$i].ContainsKey('__confluenceMetadata')) {
                        $Node.marks[$i].Remove('__confluenceMetadata')
                    }
                }
            }
        }
        
        return $Node
    }
    
    # Return primitives as-is
    return $Node
}

# Enhanced attachment upload with better ID tracking
function Upload-AttachmentWithMapping {
    param(
        [Parameter(Mandatory=$true)]$Attachment,
        [Parameter(Mandatory=$true)][string]$TargetIssueKey,
        [Parameter(Mandatory=$true)][string]$TempPath,
        [Parameter(Mandatory=$true)][hashtable]$Headers,
        [Parameter(Mandatory=$true)][string]$BaseUrl,
        [Parameter(Mandatory=$true)][hashtable]$SourceHeaders
    )
    
    $mapping = @{}
    
    try {
        $downloadPath = Join-Path $TempPath $Attachment.filename
        Write-VerboseLog "    📥 Downloading: $($Attachment.filename)" "Gray"
        
        # Download with better error handling
        Invoke-WebRequest -Uri $Attachment.content -Headers $SourceHeaders -OutFile $downloadPath -UseBasicParsing
        
        Write-VerboseLog "    📤 Uploading to: $TargetIssueKey" "Gray"
        
        # Upload with multipart form data
        $uploadResponse = Jira-POST-Multipart -Uri "$BaseUrl/rest/api/3/issue/$TargetIssueKey/attachments" -Headers $Headers -FilePath $downloadPath
        
        if ($uploadResponse -and $uploadResponse[0] -and $uploadResponse[0].id) {
            $newId = $uploadResponse[0].id.ToString()
            
            # Map by original ID
            $mapping[$Attachment.id.ToString()] = $newId
            
            # Map by filename for fallback
            $mapping[$Attachment.filename] = $newId
            
            # Map by filename + size for better matching
            if ($Attachment.size) {
                $mapping["$($Attachment.filename)_$($Attachment.size)"] = $newId
            }
            
            # If we have mime type, add another mapping
            if ($Attachment.mimeType) {
                $mapping["$($Attachment.filename)_$($Attachment.mimeType)"] = $newId
            }
            
            Write-VerboseLog "    ✅ Upload successful - New ID: $newId" "Green"
            Write-VerboseLog "    📝 Created mappings: $($mapping.Keys -join ', ')" "Gray"
        }
        
        # Clean up temp file
        Remove-Item -Path $downloadPath -Force -ErrorAction SilentlyContinue
        
    } catch {
        Write-VerboseLog "    ❌ Failed to process attachment: $($_.Exception.Message)" "Red"
    }
    
    return $mapping
}

# Safe ADF field update with validation
function Update-IssueAdfFields {
    param(
        [Parameter(Mandatory=$true)][string]$IssueKey,
        [Parameter(Mandatory=$true)][hashtable]$Fields,
        [Parameter(Mandatory=$true)][hashtable]$Headers,
        [Parameter(Mandatory=$true)][string]$BaseUrl
    )
    
    # Clean and validate ADF fields
    $cleanedFields = @{}
    
    foreach ($key in $Fields.Keys) {
        $value = $Fields[$key]
        
        # Check if this looks like ADF content
        if ($value -is [System.Collections.IDictionary] -and $value.ContainsKey('type') -and $value.type -eq 'doc') {
            Write-VerboseLog "  🧹 Cleaning ADF field: $key" "Cyan"
            
            # Clean the ADF content
            $cleaned = Clean-AdfContent -Node $value
            
            # Validate structure
            if (Validate-AdfStructure -Adf $cleaned) {
                $cleanedFields[$key] = $cleaned
                Write-VerboseLog "  ✅ ADF field validated: $key" "Green"
            } else {
                Write-VerboseLog "  ⚠️ Invalid ADF structure for field $key, skipping" "Yellow"
            }
        } else {
            # Non-ADF field, pass through
            $cleanedFields[$key] = $value
        }
    }
    
    if ($cleanedFields.Count -eq 0) {
        Write-VerboseLog "  ⚠️ No valid fields to update" "Yellow"
        return $false
    }
    
    $payload = @{ fields = $cleanedFields } | ConvertTo-Json -Depth 100 -Compress
    
    # Log payload for debugging (truncated)
    $payloadPreview = if ($payload.Length -gt 500) { $payload.Substring(0, 500) + "..." } else { $payload }
    Write-VerboseLog "  📦 Payload preview: $payloadPreview" "Gray"
    
    try {
        Jira-PUT -Uri "$BaseUrl/rest/api/3/issue/$IssueKey" -Headers $Headers -Body $payload | Out-Null
        
        Write-VerboseLog "  ✅ Successfully updated fields for $IssueKey" "Green"
        return $true
        
    } catch {
        $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
        
        if ($errorDetails) {
            Write-VerboseLog "  ❌ Field update failed for $IssueKey" "Red"
            
            if ($errorDetails.errors) {
                foreach ($field in $errorDetails.errors.PSObject.Properties) {
                    Write-VerboseLog "    Field: $($field.Name) - Error: $($field.Value)" "Red"
                }
            }
            
            if ($errorDetails.errorMessages) {
                foreach ($msg in $errorDetails.errorMessages) {
                    Write-VerboseLog "    Error: $msg" "Red"
                }
            }
        } else {
            Write-VerboseLog "  ❌ Field update failed: $($_.Exception.Message)" "Red"
        }
        
        # Save failed payload for debugging if debug mode is on
        if ($DebugMode) {
            $debugFile = Join-Path $script:stepExportsDir "failed_payload_$IssueKey.json"
            $cleanedFields | ConvertTo-Json -Depth 100 | Out-File -FilePath $debugFile -Encoding UTF8
            Write-VerboseLog "  💾 Saved failed payload to: $debugFile" "Yellow"
        }
        
        return $false
    }
}

# Create target issue if requested (keeps summary and issue type name)
function Ensure-Issue {
  param(
    [Parameter(Mandatory=$true)][string]$TargetBaseUrl,
    [Parameter(Mandatory=$true)][hashtable]$TargetHeaders,
    [Parameter(Mandatory=$true)][string]$TargetProjectKey,
    [Parameter(Mandatory=$true)]$SourceIssue,
    [Parameter(Mandatory=$false)]$MigrationConfig,
    [Parameter(Mandatory=$false)][string]$ParentKey
  )
  
  Write-Host "  🔍 DEBUG: Ensure-Issue called with ParentKey = '$ParentKey'" -ForegroundColor Magenta
  $name    = $SourceIssue.fields.issuetype.name
  $summary = $SourceIssue.fields.summary
  $sourceKey = $SourceIssue.key
  
  Write-VerboseLog "  🔍 VERBOSE: Creating issue $sourceKey" "Cyan"
  Write-VerboseLog "  🔍 VERBOSE: Issue type: $name" "Cyan"
  Write-VerboseLog "  🔍 VERBOSE: Summary: $summary" "Cyan"
  
  # Check for parent relationship
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'parent' -and $SourceIssue.fields.parent) {
    $sourceParentKey = $SourceIssue.fields.parent.key
    Write-VerboseLog "  🔍 VERBOSE: This is a SUBTASK with parent: $sourceParentKey" "Yellow"
  } else {
    Write-VerboseLog "  🔍 VERBOSE: This is a TOP-LEVEL issue (no parent)" "Green"
  }

  $types = Jira-GET -Uri "$TargetBaseUrl/rest/api/3/issuetype" -Headers $TargetHeaders
  $type  = $types | Where-Object { $_.name -eq $name } | Select-Object -First 1
  if (-not $type) { throw "Issue type '$name' not found in target." }

  $createPayload = @{
    fields = @{
      project   = @{ key = $TargetProjectKey }
      issuetype = @{ id  = $type.id }
      summary   = $summary
    }
  }

  # Add assignee if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'assignee' -and $SourceIssue.fields.assignee) {
    $createPayload.fields.assignee = @{ id = $SourceIssue.fields.assignee.accountId }
  }

  # Add reporter if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'reporter' -and $SourceIssue.fields.reporter) {
    $createPayload.fields.reporter = @{ id = $SourceIssue.fields.reporter.accountId }
  }

  # Add priority if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'priority' -and $SourceIssue.fields.priority) {
    $createPayload.fields.priority = @{ id = $SourceIssue.fields.priority.id }
  }

  # Add due date if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'duedate' -and $SourceIssue.fields.duedate) {
    $createPayload.fields.duedate = $SourceIssue.fields.duedate
  }

  # Add resolution date if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'resolutiondate' -and $SourceIssue.fields.resolutiondate) {
    $createPayload.fields.resolutiondate = $SourceIssue.fields.resolutiondate
  }

  # Note: timetracking is a read-only field that cannot be set during issue creation
  # Time tracking data is handled separately in worklog migration

  # Add environment if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'environment' -and $SourceIssue.fields.environment) {
    $createPayload.fields.environment = $SourceIssue.fields.environment
  }

  # Add security level if available
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'security' -and $SourceIssue.fields.security) {
    $createPayload.fields.security = @{ id = $SourceIssue.fields.security.id }
  }

  # Note: votes and watches are read-only fields that cannot be set during creation

  # Note: flag field is typically read-only and managed by Jira

  # Note: Sprint and Epic fields are handled separately after issue creation
  # They cannot be set during initial issue creation

  # Add original estimate if available (this field is settable)
  if ($SourceIssue.fields.PSObject.Properties.Name -contains 'originalestimate' -and $SourceIssue.fields.originalestimate) {
    $createPayload.fields.originalestimate = $SourceIssue.fields.originalestimate
  }

  # Note: remainingestimate and timespent are read-only fields that cannot be set during issue creation
  # These are managed by Jira's time tracking system and worklog entries

  # Note: aggregate fields are read-only and calculated by Jira automatically

  # Note: progress, workratio, lastViewed, and creator are read-only fields
  # They cannot be set during issue creation and will be automatically populated by Jira
  
  # Add parent if provided
  if ($ParentKey) {
    $createPayload.fields.parent = @{ key = $ParentKey }
    Write-VerboseLog "  🔗 VERBOSE: Setting parent to: $ParentKey" "Cyan"
  }

  # Add labels if available
  if ($SourceIssue.fields.labels) {
    $createPayload.fields.labels = $SourceIssue.fields.labels
  }

  # Add components if available
  if ($SourceIssue.fields.components) {
    $componentIds = @()
    foreach ($comp in $SourceIssue.fields.components) {
      $componentIds += @{ id = $comp.id }
    }
    $createPayload.fields.components = $componentIds
  }

  # Add parent if available (for subtasks)
  # Use the provided ParentKey parameter if available (this is the target key from our mapping)
  if ($ParentKey) {
    $createPayload.fields.parent = @{ key = $ParentKey }
    Write-VerboseLog "  ✅ VERBOSE: Using provided parent key: $ParentKey" "Green"
  } elseif ($SourceIssue.fields.PSObject.Properties.Name -contains 'parent' -and $SourceIssue.fields.parent) {
    # Fallback: if no ParentKey provided but issue has parent, log warning
    $sourceParentKey = $SourceIssue.fields.parent.key
    Write-VerboseLog "  ⚠️  VERBOSE: Issue has parent $sourceParentKey but no ParentKey parameter provided - creating without parent" "Yellow"
  } else {
    Write-VerboseLog "  🔍 VERBOSE: No parent field found - this is a top-level issue" "Gray"
  }

  # Build initial fields from source to include at creation time (description + mapped custom fields)
  try {
    $initialFields = @{}
    
    # Description (ADF) best-effort without attachment ID rewrite (attachments added later)
    if ($SourceIssue.fields.PSObject.Properties.Name -contains 'description') {
      $descVal = $SourceIssue.fields.description
      if ($null -ne $descVal -and -not ($descVal -is [string] -and [string]::IsNullOrWhiteSpace($descVal))) {
        if ($descVal -is [string]) { $descVal = Convert-TextToAdf -Text $descVal }
        else { if (-not (Validate-AdfStructure -Adf $descVal)) { $descVal = Clean-AdfContent -Node $descVal } }
        $initialFields['description'] = $descVal
      }
    }
    
    # Collect custom field IDs from config
    $adfIds = @(); if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomRichTextFieldIds' -and $MigrationConfig.CustomRichTextFieldIds) { $adfIds = @($MigrationConfig.CustomRichTextFieldIds) }
    $plainIds = @(); if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFields' -and $MigrationConfig.CustomFields) { $plainIds = @($MigrationConfig.CustomFields.PSObject.Properties.Value) }
    
    # ADF custom fields
    foreach ($fid in $adfIds) {
      if ($fid -eq 'description') { continue }
      if ($SourceIssue.fields.PSObject.Properties.Name -contains $fid) {
        $val = $SourceIssue.fields.$fid
        if ($null -ne $val) {
          if ($val -is [string]) { $val = Convert-TextToAdf -Text $val } else { if (-not (Validate-AdfStructure -Adf $val)) { $val = Clean-AdfContent -Node $val } }
          $targetFieldId = $fid
          if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFieldMapping' -and $MigrationConfig.CustomFieldMapping.PSObject.Properties.Name -contains $fid) { $targetFieldId = $MigrationConfig.CustomFieldMapping.$fid }
          $initialFields[$targetFieldId] = $val
        }
      }
    }
    
    # Plain custom fields
    foreach ($fid in $plainIds) {
      if ($SourceIssue.fields.PSObject.Properties.Name -contains $fid) {
        $val = $SourceIssue.fields.$fid
        if ($fid -eq 'customfield_10026' -and $null -eq $val) { $val = 0 }
        $targetFieldId = $fid
        if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFieldMapping' -and $MigrationConfig.CustomFieldMapping.PSObject.Properties.Name -contains $fid) { $targetFieldId = $MigrationConfig.CustomFieldMapping.$fid }
        $initialFields[$targetFieldId] = $val
      }
    }
    
    # Merge initial fields into create payload (avoid overwriting already set keys)
    foreach ($k in $initialFields.Keys) {
      if (-not $createPayload.fields.ContainsKey($k)) { $createPayload.fields[$k] = $initialFields[$k] }
    }
  } catch {
    Write-VerboseLog "  ⚠️  Failed building initial fields for create: $($_.Exception.Message)" "Yellow"
  }

  $createPayload = $createPayload | ConvertTo-Json -Depth 20

  try {
    $resp = Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue" -Headers $TargetHeaders -Body $createPayload
  } catch {
    $errorDetails = $_.ErrorDetails.Message
    Write-VerboseLog "  ❌ Issue creation failed: $errorDetails" "Red"
    Write-VerboseLog "  🔍 Create payload was: $createPayload" "Gray"
    
    # Log known errors to separate files
    if ($errorDetails -match "We don.*t recognise the format of a file") {
      Log-KnownError -SourceKey $SourceIssue.key -ErrorType "ADF_Format_Error" -ErrorMessage "ADF description contains unrecognized media references" -ErrorDetails $errorDetails
    } elseif ($errorDetails -match "assignee.*cannot be assigned") {
      Log-KnownError -SourceKey $SourceIssue.key -ErrorType "Assignee_Error" -ErrorMessage "User cannot be assigned issues" -ErrorDetails $errorDetails
    } else {
      Log-KnownError -SourceKey $SourceIssue.key -ErrorType "Unknown_Error" -ErrorMessage "Issue creation failed" -ErrorDetails $errorDetails
    }
    
    # Check if it's an assignee error and retry without assignee
    if ($errorDetails -match "assignee.*cannot be assigned" -and $SourceIssue.fields.assignee) {
      Write-VerboseLog "  🔄 Retrying without assignee due to assignment error..." "Yellow"
      $retryPayload = $createPayload | ConvertFrom-Json
      $retryPayload.fields.PSObject.Properties.Remove('assignee')
      $retryPayloadJson = $retryPayload | ConvertTo-Json -Depth 20
      
      try {
        $resp = Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue" -Headers $TargetHeaders -Body $retryPayloadJson
        Write-VerboseLog "  ✅ Issue created successfully without assignee" "Green"
      } catch {
        $retryErrorDetails = $_.ErrorDetails.Message
        Write-VerboseLog "  ❌ Retry also failed: $retryErrorDetails" "Red"
        throw
      }
    } else {
      throw
    }
  }
  
  # Handle status transition if needed
  if ($SourceIssue.fields.status -and $MigrationConfig.PSObject.Properties.Name -contains 'StatusMapping' -and $MigrationConfig.StatusMapping) {
    $sourceStatus = $SourceIssue.fields.status.name
    if ($MigrationConfig.StatusMapping.PSObject.Properties.Name -contains $sourceStatus) {
      $targetStatus = $MigrationConfig.StatusMapping.$sourceStatus
      Write-VerboseLog "  🔄 Mapping status: $sourceStatus -> $targetStatus" "Cyan"
      
      # Only transition if the target status is different from the default
      if ($targetStatus -ne "Backlog" -and $targetStatus -ne "To Do") {
        try {
          # Get available transitions for the issue
          $transitions = Jira-GET -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/transitions" -Headers $TargetHeaders
          
          # Try direct transition first
          $targetTransition = $transitions.transitions | Where-Object { $_.to.name -eq $targetStatus }
          
          if ($targetTransition) {
            $transitionPayload = @{
              transition = @{ id = $targetTransition.id }
            } | ConvertTo-Json -Depth 10
            
            Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/transitions" -Headers $TargetHeaders -Body $transitionPayload | Out-Null
            Write-VerboseLog "  ✅ Direct transition to $targetStatus" "Green"
          } else {
            # Try intermediate transition through "Ready for Work" if target is "In Progress"
            if ($targetStatus -eq "In Progress") {
              Write-VerboseLog "  🔄 No direct transition to $targetStatus, trying intermediate transition through Ready for Work" "Yellow"
              
              # First transition to "Ready for Work"
              $readyForWorkTransition = $transitions.transitions | Where-Object { $_.to.name -eq "Ready for Work" }
              if ($readyForWorkTransition) {
                $readyPayload = @{
                  transition = @{ id = $readyForWorkTransition.id }
                } | ConvertTo-Json -Depth 10
                
                Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/transitions" -Headers $TargetHeaders -Body $readyPayload | Out-Null
                Write-VerboseLog "  ✅ Transitioned to Ready for Work" "Green"
                
                # Now try to transition to "In Progress"
                $transitions = Jira-GET -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/transitions" -Headers $TargetHeaders
                $inProgressTransition = $transitions.transitions | Where-Object { $_.to.name -eq "In Progress" }
                
                if ($inProgressTransition) {
                  $inProgressPayload = @{
                    transition = @{ id = $inProgressTransition.id }
                  } | ConvertTo-Json -Depth 10
                  
                  Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/transitions" -Headers $TargetHeaders -Body $inProgressPayload | Out-Null
                  Write-VerboseLog "  ✅ Transitioned to In Progress via Ready for Work" "Green"
                } else {
                  Write-VerboseLog "  ⚠️  Could not transition to In Progress from Ready for Work" "Yellow"
                }
              } else {
                Write-VerboseLog "  ⚠️  No transition to Ready for Work found" "Yellow"
              }
            } else {
              Write-VerboseLog "  ⚠️  No transition found to $targetStatus, keeping current status" "Yellow"
            }
          }
        } catch {
          Write-VerboseLog "  ⚠️  Failed to transition to $targetStatus`: $($_.Exception.Message)" "Yellow"
        }
      }
    }
  }
  
  # STEP 1: Set LegacyKey (alone) immediately after creation
  try {
    $legacyFieldIdToUse = if ($legacyKeyFieldId) { $legacyKeyFieldId } else { 'customfield_10401' }
    $legacyKeyPayload = @{ fields = @{} }
    $legacyKeyPayload.fields[$legacyFieldIdToUse] = $sourceKey
    $legacyKeyPayload = $legacyKeyPayload | ConvertTo-Json -Depth 10
    Jira-PUT -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)" -Headers $TargetHeaders -Body $legacyKeyPayload | Out-Null
    Write-VerboseLog "  ✅ LegacyKey field set to: $sourceKey" "Green"
  } catch {
    Write-VerboseLog "  ⚠️  Failed to set LegacyKey field: $($_.Exception.Message)" "Yellow"
  }

  # STEP 2: Create a real web link back to the source issue (Remote Link)
  try {
    $sourceUrl = "https://onemain.atlassian.net/browse/$sourceKey"
    $remoteLinkPayload = @{
      object = @{
        url = $sourceUrl
        title = $sourceKey
      }
    } | ConvertTo-Json -Depth 10
    Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue/$($resp.key)/remotelink" -Headers $TargetHeaders -Body $remoteLinkPayload | Out-Null
    Write-VerboseLog "  ✅ Added web link to source: $sourceUrl" "Green"
  } catch {
    Write-VerboseLog "  ⚠️  Failed to add web link: $($_.Exception.Message)" "Yellow"
  }
  
  return @{
    Success = $true
    TargetKey = $resp.key
    Error = $null
  }
}

# NEW FUNCTION: Process attachments for an issue
function Process-Attachments {
  param(
    [Parameter(Mandatory=$true)][string]$TargetBaseUrl,
    [Parameter(Mandatory=$true)][hashtable]$TargetHeaders,
    [Parameter(Mandatory=$true)][string]$TargetKey,
    [Parameter(Mandatory=$true)]$Attachments,
    [Parameter(Mandatory=$true)][hashtable]$AttachmentIdMap
  )
  
  if (-not $Attachments -or $Attachments.Count -eq 0) {
    Write-VerboseLog "  📎 No attachments to process" "Gray"
    return @{}
  }
  
  Write-VerboseLog "  📎 Processing $($Attachments.Count) attachments..." "Cyan"
  $attMap = @{}
  
  $tmp = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "jira_mig_" + [System.Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  
  try {
    foreach ($att in $Attachments) {
      $attId = $att.id
      $attName = $att.filename
      Write-VerboseLog "  📎 Processing attachment: $attName (ID: $attId)" "Gray"
      
      try {
        # Download attachment from SOURCE instance using content URL
        $attPath = Join-Path $tmp $attName
        $contentUrl = if ($att.PSObject.Properties.Name -contains 'content') { $att.content } else { $null }
        if (-not $contentUrl) {
          Write-VerboseLog "  ⚠️ No content URL for attachment $attName; skipping" "Yellow"
          continue
        }
        Invoke-WebRequest -Uri $contentUrl -Headers $srcHdrs -OutFile $attPath
        
        # Upload to TARGET issue
        $uploadResult = Jira-POST -Uri "$TargetBaseUrl/rest/api/3/issue/$TargetKey/attachments" -Headers $TargetHeaders -Body $attPath -ContentType "multipart/form-data"
        
        if ($uploadResult -and $uploadResult.Count -gt 0) {
          $newAttId = $uploadResult[0].id
          $attMap[$attId] = $newAttId
          Write-VerboseLog "  ✅ Uploaded: $attName -> $newAttId" "Green"
        }
      } catch {
        Write-VerboseLog "  ❌ Failed to process attachment: $($_.Exception.Message)" "Red"
      }
    }
  } finally {
    if (Test-Path $tmp) {
      Remove-Item -Path $tmp -Recurse -Force
    }
  }
  
  return $attMap
}

# NEW FUNCTION: Update only the Description field (ADF) with attachment ID rewrites
function Process-Description {
  param(
    [Parameter(Mandatory=$true)][string]$TargetBaseUrl,
    [Parameter(Mandatory=$true)][hashtable]$TargetHeaders,
    [Parameter(Mandatory=$true)][string]$TargetKey,
    [Parameter(Mandatory=$true)]$SourceIssue,
    [Parameter(Mandatory=$true)][hashtable]$AttachmentIdMap,
    [Parameter(Mandatory=$false)]$NoFieldExistsData = @()
  )

  if (-not ($SourceIssue.fields.PSObject.Properties.Name -contains 'description')) {
    Write-VerboseLog "  ⚠️ No description on source; skipping" "Gray"
    return $false
  }

  Write-VerboseLog "  📄 Updating description (ADF)" "Cyan"
  $descVal = $SourceIssue.fields.description

  if ($null -eq $descVal -or ($descVal -is [string] -and [string]::IsNullOrWhiteSpace($descVal))) {
    Write-VerboseLog "  ⚠️ Description is null/empty - skipping" "Gray"
    return $false
  }

  if ($descVal -is [string]) {
    $descVal = Convert-TextToAdf -Text $descVal
  } else {
    if (-not (Validate-AdfStructure -Adf $descVal)) {
      $descVal = Clean-AdfContent -Node $descVal
    }
    # Remove media references temporarily - they will be restored after attachments are uploaded
    $descVal = Remove-AdfMediaReferences -Node $descVal
  }

  if ($AttachmentIdMap.Count -gt 0) {
    $descVal = Rewrite-AdfMediaIds -Node $descVal -AttachmentIdMap $AttachmentIdMap -DebugPath "description"
  }

  # Append "No Field Exists" data to description if present
  if ($NoFieldExistsData -and $NoFieldExistsData.Count -gt 0) {
    Write-VerboseLog "  📄 Appending 'No Field Exists' data to description" "Cyan"
    $noFieldExistsSection = @{
      type = "paragraph"
      content = @(
        @{
          type = "text"
          text = "No Field Exists"
          marks = @(@{ type = "strong" })
        }
      )
    }
    
    $noFieldExistsFields = @()
    foreach ($field in $NoFieldExistsData) {
      $fieldText = "$($field.FieldName): $($field.Value)"
      $noFieldExistsFields += @{
        type = "paragraph"
        content = @(
          @{
            type = "text"
            text = $fieldText
          }
        )
      }
    }
    
    # Append to existing description
    if ($descVal.content) {
      $descVal.content += $noFieldExistsSection
      $descVal.content += $noFieldExistsFields
    } else {
      $descVal.content = @($noFieldExistsSection) + $noFieldExistsFields
    }
  }

  $payload = @{ fields = @{ description = $descVal } } | ConvertTo-Json -Depth 100 -Compress
  try {
    Jira-PUT -Uri "$TargetBaseUrl/rest/api/3/issue/$TargetKey" -Headers $TargetHeaders -Body $payload | Out-Null
    Write-VerboseLog "  ✅ Description updated" "Green"
    return $true
  } catch {
    Write-VerboseLog "  ⚠️ Failed to update description: $($_.Exception.Message)" "Yellow"
    return $false
  }
}

# NEW FUNCTION: Process custom fields (incl. ADF) with mapping (excludes description)
function Process-CustomFields {
  param(
    [Parameter(Mandatory=$true)][string]$TargetBaseUrl,
    [Parameter(Mandatory=$true)][hashtable]$TargetHeaders,
    [Parameter(Mandatory=$true)][string]$TargetKey,
    [Parameter(Mandatory=$true)]$SourceIssue,
    [Parameter(Mandatory=$true)]$MigrationConfig,
    [Parameter(Mandatory=$true)][hashtable]$AttachmentIdMap
  )
  
  Write-VerboseLog "  🔧 Processing custom fields with mapping" "Cyan"
  $fields = @{}
  
  # Get field IDs from config
  $adfIds = @()
  if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomRichTextFieldIds' -and $MigrationConfig.CustomRichTextFieldIds) {
    $adfIds = @($MigrationConfig.CustomRichTextFieldIds)
  }
  $plainIds = @()
  if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFields' -and $MigrationConfig.CustomFields) {
    $plainIds = @($MigrationConfig.CustomFields.PSObject.Properties.Value)
  }
  
  # STEP 1: Process ADF custom fields with mapping (excludes description)
  foreach ($fid in $adfIds) {
    if ($fid -eq 'description') { continue }
    if ($SourceIssue.fields.PSObject.Properties.Name -contains $fid) {
      Write-VerboseLog "  📄 Processing custom ADF field: $fid" "Cyan"
      $val = $SourceIssue.fields.$fid
      
      if ($null -ne $val) {
        if ($val -is [string]) {
          $val = Convert-TextToAdf -Text $val
        } else {
          $val = Clean-AdfContent -Node $val
          if ($AttachmentIdMap.Count -gt 0) {
            $val = Rewrite-AdfMediaIds -Node $val -AttachmentIdMap $AttachmentIdMap -DebugPath "customfield_$fid"
          }
          
          if (-not (Validate-AdfStructure -Adf $val)) {
            Write-VerboseLog "  ⚠️ Invalid ADF structure for field $fid, skipping" "Yellow"
            continue
          }
        }
        
        # Apply field mapping
        $targetFieldId = $fid
        if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFieldMapping' -and 
            $MigrationConfig.CustomFieldMapping.PSObject.Properties.Name -contains $fid) {
          $targetFieldId = $MigrationConfig.CustomFieldMapping.$fid
          Write-VerboseLog "  🔄 Mapping ADF field $fid -> $targetFieldId" "Cyan"
        }
        
        $fields[$targetFieldId] = $val
      }
    }
  }
  
  # STEP 2: Process plain custom fields with mapping
  foreach ($fid in $plainIds) {
    if ($SourceIssue.fields.PSObject.Properties.Name -contains $fid) {
      $val = $SourceIssue.fields.$fid
      
      # Handle null Story Points
      if ($fid -eq "customfield_10026" -and $null -eq $val) {
        $val = 0
        Write-VerboseLog "  📊 Setting null Story Points to 0" "Yellow"
      }
      
      # Apply field mapping
      $targetFieldId = $fid
      if ($MigrationConfig.PSObject.Properties.Name -contains 'CustomFieldMapping' -and 
          $MigrationConfig.CustomFieldMapping.PSObject.Properties.Name -contains $fid) {
        $targetFieldId = $MigrationConfig.CustomFieldMapping.$fid
        Write-VerboseLog "  🔄 Mapping field $fid -> $targetFieldId" "Cyan"
      }
      
      $fields[$targetFieldId] = $val
    }
  }
  
  # STEP 3: Update issue with custom fields
  if ($fields.Count -gt 0) {
    Write-VerboseLog "  📤 Updating issue with $($fields.Count) fields..." "Cyan"
    
    $updateSuccess = Update-IssueAdfFields `
      -IssueKey $TargetKey `
      -Fields $fields `
      -Headers $TargetHeaders `
      -BaseUrl $TargetBaseUrl
    
    if ($updateSuccess) {
      Write-VerboseLog "  ✅ Successfully updated all fields for $TargetKey" "Green"
    } else {
      Write-VerboseLog "  ⚠️ Some fields failed to update for $TargetKey" "Yellow"
    }
  } else {
    Write-VerboseLog "  ⚠️ No fields to update" "Yellow"
  }
}

# -------------------- Main Script Start --------------------

# Bootstrap
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonScript = Join-Path $here "_common.ps1"
if (Test-Path $commonScript) {
    . $commonScript
}

# -------------------- Load config & inputs --------------------

if (-not (Test-Path $ParametersPath)) { throw "Config file '$ParametersPath' not found." }
$config = Get-Content $ParametersPath -Raw | ConvertFrom-Json

# Set up step-specific output directory
$outDir = $config.OutputSettings.OutputDirectory
if ([string]::IsNullOrWhiteSpace($outDir)) { $outDir = ".\out" }

# Ensure the base output directory exists
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    Write-Host "Created output directory: $outDir" -ForegroundColor Green
}

# Clean up ONLY files from previous failed attempts of THIS step
$projectKey = $config.ProjectKey
$projectExportDir = Join-Path ".\projects" $projectKey
if (Test-Path $projectExportDir) {
    $projectOutDir = Join-Path $projectExportDir "out"
    if (Test-Path $projectOutDir) {
        $exports08Dir = Join-Path $projectOutDir "exports08"
        if (Test-Path $exports08Dir) {
            Write-Host "Cleaning up previous step 08 exports from failed attempts..." -ForegroundColor Yellow
            Remove-Item -Path $exports08Dir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleaned up previous exports08 folder" -ForegroundColor Green
        }
    }
}

# Create step-specific exports folder
$stepExportsDir = Join-Path $outDir "exports08"
$script:stepExportsDir = $stepExportsDir  # Make available to functions
if (-not (Test-Path $stepExportsDir)) {
    New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null
    Write-Host "Created step exports directory: $stepExportsDir" -ForegroundColor Green
}

# Initialize issues logging if _common.ps1 provides the function
if (Get-Command Initialize-IssuesLog -ErrorAction SilentlyContinue) {
    Initialize-IssuesLog -StepName "08_Import" -OutDir $stepExportsDir
}

# Initialize error logging
$errorLogFile = Join-Path $stepExportsDir "08_Import_Errors.log"
$knownErrorsFile = Join-Path $stepExportsDir "08_Import_Known_Errors.csv"
$knownErrors = @()

# Function to log errors and add to known errors CSV
function Log-KnownError {
  param(
    [string]$SourceKey,
    [string]$ErrorType,
    [string]$ErrorMessage,
    [string]$ErrorDetails
  )
  
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logEntry = "[$timestamp] $SourceKey - $ErrorType`: $ErrorMessage"
  Add-Content -Path $errorLogFile -Value $logEntry
  
  if ($ErrorDetails) {
    Add-Content -Path $errorLogFile -Value "  Details: $ErrorDetails"
  }
  
  # Add to known errors array
  $knownErrors += [PSCustomObject]@{
    Timestamp = $timestamp
    SourceKey = $SourceKey
    ErrorType = $ErrorType
    ErrorMessage = $ErrorMessage
    ErrorDetails = $ErrorDetails
  }
}

# Set up verbose logging to file
$logFile = Join-Path $stepExportsDir "08_Import_Verbose.log"
Write-Host "📝 Verbose logging enabled: $logFile" -ForegroundColor Cyan

function Write-VerboseLog {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

# Create debug directory if debug mode is enabled
if ($DebugMode) {
    $debugDir = Join-Path $stepExportsDir "adf_debug"
    New-Item -ItemType Directory -Path $debugDir -Force | Out-Null
    Write-VerboseLog "🔍 Debug mode enabled. ADF transformations will be saved to: $debugDir" "Yellow"
}

$srcUser = $config.SourceEnvironment.Username
$srcTok  = $config.SourceEnvironment.ApiToken
$srcHdrs = New-BasicAuthHeader -Email $srcUser -ApiToken $srcTok

$tgtBase = $config.TargetEnvironment.BaseUrl.TrimEnd('/')
$tgtUser = $config.TargetEnvironment.Username
$tgtTok  = $config.TargetEnvironment.ApiToken
$tgtHdrs = New-BasicAuthHeader -Email $tgtUser -ApiToken $tgtTok

$targetProjectKey = $config.TargetEnvironment.ProjectKey

$mig = $config.MigrationSettings
$doAttachments = $true; if ($mig -and $mig.MigrateAttachments -eq $false) { $doAttachments = $false }
$doComments    = $true; if ($mig -and $mig.MigrateComments    -eq $false) { $doComments = $false }

$adfIds = @(); if ($config.PSObject.Properties.Name -contains 'CustomRichTextFieldIds' -and $config.CustomRichTextFieldIds) { $adfIds = @($config.CustomRichTextFieldIds) }
$plainIds = @(); if ($config.PSObject.Properties.Name -contains 'CustomFields' -and $config.CustomFields) { $plainIds = @($config.CustomFields.PSObject.Properties.Value) }

# Optionally detect LegacyKey field id for lookup
$legacyKeyFieldId = $null
if ($config.PSObject.Properties.Name -contains 'CustomFields' -and $config.CustomFields) {
  foreach ($p in $config.CustomFields.PSObject.Properties) {
    if ($p.Name -eq "LegacyKey") { $legacyKeyFieldId = $p.Value }
  }
}

# Export file path - look for the JSONL file from step 07
$exportFile = Join-Path $stepExportsDir "07_Export_adf.jsonl"
if (-not (Test-Path $exportFile)) { 
    # Fallback to the exports07 directory
    $exports07Dir = Join-Path $outDir "exports07"
    $exportFile = Join-Path $exports07Dir "07_Export_adf.jsonl"
    if (-not (Test-Path $exportFile)) { 
        # Final fallback to the old location
        $exportFile = Join-Path $outDir "export_adf.jsonl"
        if (-not (Test-Path $exportFile)) { 
            throw "Export file not found. Expected: $exportFile or $exports07Dir/07_Export_adf.jsonl (run 07_Export.ps1 first)." 
        }
    }
}

# Parent mapping file path - look for the CSV file from step 07
$parentMappingFile = Join-Path $stepExportsDir "07_Parent_Mapping.csv"
if (-not (Test-Path $parentMappingFile)) { 
    # Fallback to the exports07 directory
    $exports07Dir = Join-Path $outDir "exports07"
    $parentMappingFile = Join-Path $exports07Dir "07_Parent_Mapping.csv"
    if (-not (Test-Path $parentMappingFile)) { 
        throw "Parent mapping file not found. Expected: $parentMappingFile or $exports07Dir/07_Parent_Mapping.csv (run 07_Export.ps1 first)." 
    }
}

# Load parent mapping file
Write-Host "📋 Loading parent mapping from: $parentMappingFile" -ForegroundColor Cyan
$parentMappings = Import-Csv -Path $parentMappingFile
Write-Host "✅ Loaded $($parentMappings.Count) parent mappings" -ForegroundColor Green

# Function to update parent mapping when an issue is created
function Update-ParentMapping {
  param(
    [string]$SourceKey,
    [string]$TargetKey
  )
  
  # Find the mapping entry for this source key
  $mapping = $parentMappings | Where-Object { $_.SourceKey -eq $SourceKey }
  if ($mapping) {
    $mapping.TargetKey = $TargetKey
    
    # If this issue has a parent, update the target parent key
    if ($mapping.SourceParentKey -ne "N/A") {
      $parentMapping = $parentMappings | Where-Object { $_.SourceKey -eq $mapping.SourceParentKey }
      if ($parentMapping -and $parentMapping.TargetKey -ne "PENDING") {
        $mapping.TargetParentKey = $parentMapping.TargetKey
      }
    }
    
    # Update TargetParentKey for all children of this issue
    $children = $parentMappings | Where-Object { $_.SourceParentKey -eq $SourceKey }
    foreach ($child in $children) {
      $child.TargetParentKey = $TargetKey
      Write-VerboseLog "  📝 Updated child $($child.SourceKey) TargetParentKey to $TargetKey" "Gray"
    }
    
    Write-VerboseLog "  📝 Updated parent mapping: $SourceKey -> $TargetKey" "Gray"
    
    # Save the updated mapping file immediately so subsequent issues can use it
    $parentMappings | Export-Csv -Path $parentMappingFile -NoTypeInformation -Encoding UTF8
    Write-VerboseLog "  💾 Saved updated parent mapping file" "Gray"
  }
}

# Optional source->target map
$map = @{}
if ($IssueMapPath -and (Test-Path $IssueMapPath)) {
  $rows = Import-Csv -Path $IssueMapPath
  foreach ($r in $rows) { if ($r.sourceKey -and $r.targetKey) { $map[$r.sourceKey] = $r.targetKey } }
  Write-Host "Loaded issue map with $($map.Keys.Count) entries."
} elseif (-not $CreateIfMissing -and -not $legacyKeyFieldId) {
  throw "No issue map provided and no LegacyKey field configured for lookup. Provide -IssueMapPath or add CustomFields.LegacyKey."
}

# -------------------- Import pipeline --------------------

Write-VerboseLog "== Import start ==" "Cyan"
Write-VerboseLog "🔍 VERBOSE LOGGING ENABLED - Enhanced ADF handling active" "Yellow"

# Optionally delete all existing issues in target project first (guarded by config flag)
if ($mig -and $mig.DeleteTargetIssuesBeforeImport -eq $true) {
Write-VerboseLog "🗑️  Deleting all existing issues in target project: $targetProjectKey" "Red"
try {
    $deleteJql = "project = $targetProjectKey"
        $searchBody = @{ jql = $deleteJql; maxResults = 1000; fields = @('id','key') } | ConvertTo-Json
        $deleteResponse = Jira-POST -Uri "$tgtBase/rest/api/3/search" -Headers $tgtHdrs -Body $searchBody
    
    if ($deleteResponse.issues -and $deleteResponse.issues.Count -gt 0) {
        Write-VerboseLog "Found $($deleteResponse.issues.Count) existing issues to delete" "Yellow"
        
        foreach ($issue in $deleteResponse.issues) {
            try {
                Write-VerboseLog "Deleting issue: $($issue.key)" "Gray"
                Invoke-RestMethod -Method DELETE -Uri "$tgtBase/rest/api/3/issue/$($issue.key)" -Headers $tgtHdrs -ErrorAction Stop | Out-Null
            } catch {
                Write-VerboseLog "Failed to delete $($issue.key): $($_.Exception.Message)" "Red"
            }
        }
        Write-VerboseLog "✅ Completed deletion of existing issues" "Green"
    } else {
        Write-VerboseLog "No existing issues found in target project" "Green"
    }
} catch {
    Write-VerboseLog "❌ Failed to delete existing issues: $($_.Exception.Message)" "Red"
    Write-Warning "Failed to delete existing issues - import may create duplicates"
    }
} else {
    Write-VerboseLog "🛑 Skipping deletion of target project issues (DeleteTargetIssuesBeforeImport not enabled)" "Yellow"
}

# Initialize tracking variables
$script:StepStartTime = Get-Date
$importReport = @()
$importedIssues = @()
$skippedIssues = @()
$failedIssues = @()
$createdIssues = @()
$attachmentCount = 0
$commentCount = 0

$lines = Get-Content $exportFile -Encoding UTF8
Write-VerboseLog "🔄 Processing $($lines.Count) lines from export file: $exportFile" "Cyan"

# Sort issues by hierarchy
Write-VerboseLog "🔍 VERBOSE: Sorting issues by hierarchy..." "Cyan"
$sortedBundles = @()
$parentIssues = @()
$childIssues = @()
$orphanedChildren = @()
$orphanedIssuesCSV = @()

foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }
  
  try {
    $bundle = $line | ConvertFrom-Json
    $sourceKey = $bundle.issue.key
    $issueType = $bundle.issue.fields.issuetype.name
    
    $hasParent = $false
    if ($bundle.issue.fields.PSObject.Properties.Name -contains 'parent') {
      $hasParent = $null -ne $bundle.issue.fields.parent
    }
    
    Write-VerboseLog "🔍 VERBOSE: Issue $sourceKey - Type: $issueType - Has Parent: $hasParent" "Gray"
  } catch {
    Write-VerboseLog "⚠️ VERBOSE: Failed to parse line: $($line.Substring(0, [Math]::Min(100, $line.Length)))..." "Red"
    Write-VerboseLog "⚠️ VERBOSE: Error details: $($_.Exception.Message)" "Red"
    continue
  }
  
  if ($hasParent) {
    $childIssues += $bundle
  } else {
    $parentIssues += $bundle
  }
}

# Sort parent issues by hierarchy
$hierarchyOrder = @{
  "Theme" = 1
  "Initiative" = 2  
  "Epic" = 3
  "Story" = 4
  "Task" = 4
  "Spike" = 4
  "Bug" = 4
  "Sub-task" = 5
}

$sortedParentIssues = $parentIssues | Sort-Object { 
  $type = $_.issue.fields.issuetype.name
  if ($hierarchyOrder.ContainsKey($type)) { $hierarchyOrder[$type] } else { 99 }
}

# Check for orphaned children
Write-VerboseLog "🔍 VERBOSE: Checking for orphaned children..." "Cyan"
$availableParentKeys = $parentIssues | ForEach-Object { $_.issue.key }

foreach ($child in $childIssues) {
  $parentKey = $child.issue.fields.parent.key
  if ($parentKey -notin $availableParentKeys) {
    $orphanedChildren += $child
    Write-VerboseLog "  ⚠️ Orphaned child: $($child.issue.key) - Parent $parentKey not in export" "Yellow"
  }
}

# Combine sorted parent issues with non-orphaned child issues
$sortedBundles = $sortedParentIssues + ($childIssues | Where-Object { $_ -notin $orphanedChildren })

Write-VerboseLog "🔍 VERBOSE: Processing order:" "Cyan"
foreach ($bundle in $sortedBundles) {
  $sourceKey = $bundle.issue.key
  $issueType = $bundle.issue.fields.issuetype.name
  # Check if parent property exists before accessing it
  $hasParent = $false
  if ($bundle.issue.fields.PSObject.Properties.Name -contains 'parent') {
    $hasParent = $null -ne $bundle.issue.fields.parent
  }
  $parentKey = if ($hasParent -and $bundle.issue.fields.PSObject.Properties.Name -contains 'parent') { $bundle.issue.fields.parent.key } else { "N/A" }
  Write-VerboseLog "  📋 $sourceKey - $issueType - Parent: $parentKey" "Gray"
}

# Process each issue in hierarchical order
foreach ($bundle in $sortedBundles) {
  $sourceKey = $bundle.issue.key
  $issueType = $bundle.issue.fields.issuetype.name
  # Check if parent property exists before accessing it
  $hasParent = $false
  if ($bundle.issue.fields.PSObject.Properties.Name -contains 'parent') {
    $hasParent = $null -ne $bundle.issue.fields.parent
  }
  
  Write-VerboseLog "🎯 Processing issue: $sourceKey (Type: $issueType, Has Parent: $hasParent)" "Green"
  
  # Find the target key of the parent using the parent mapping file
  $targetParentKey = $null
  if ($hasParent -and $bundle.issue.fields.PSObject.Properties.Name -contains 'parent' -and $bundle.issue.fields.parent) {
    $parentKey = $bundle.issue.fields.parent.key
    Write-VerboseLog "  🔍 Looking for target key of parent $parentKey in mapping file..." "Gray"
    
    # Look up this issue's entry in the mapping to get the TargetParentKey
    $currentMapping = $parentMappings | Where-Object { $_.SourceKey -eq $sourceKey }
    if ($currentMapping -and $currentMapping.TargetParentKey -ne "PENDING") {
      $targetParentKey = $currentMapping.TargetParentKey
      Write-VerboseLog "  ✅ Found target parent: $targetParentKey for source parent $parentKey" "Green"
    } else {
      Write-VerboseLog "  ⚠️  Parent $parentKey not found in mapping or not yet created" "Yellow"
    }
  }
  
  # Save original ADF for debugging if debug mode is on
  if ($DebugMode -and $bundle.issue.fields.description) {
    $beforeAdf = $bundle.issue.fields.description | ConvertTo-Json -Depth 100
    $beforeAdf | Out-File "$debugDir\${sourceKey}_original.json" -Encoding UTF8
  }

  # 0) Always create the target issue using mapping (no pre-search)
  try {
    $result = Ensure-Issue -TargetBaseUrl $tgtBase -TargetHeaders $tgtHdrs -TargetProjectKey $targetProjectKey -SourceIssue $bundle.issue -MigrationConfig $config -ParentKey $targetParentKey
    if ($result.Success) {
      $targetKey = $result.TargetKey
      Write-Host "Created $targetKey for source $sourceKey"
      $createdIssues += $sourceKey
      Update-ParentMapping -SourceKey $sourceKey -TargetKey $targetKey
    } else {
      Write-Warning "Create failed for ${sourceKey}: $($result.Error)"
      $failedIssues += $sourceKey
      continue
    }
  } catch {
    Write-Warning "Create failed for ${sourceKey}: $($_.Exception.Message)"
    $failedIssues += $sourceKey
    continue
  }

  # NEW ORGANIZED APPROACH: Process attachments first (use robust uploader to build rich mapping)
  Write-VerboseLog "  📎 STEP 1: Processing attachments..." "Cyan"
  $attMap = @{}
  
  if ($doAttachments -and $bundle.attachments) {
    $tmpDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "jira_mig_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    try {
      foreach ($att in $bundle.attachments) {
        $singleMap = Upload-AttachmentWithMapping -Attachment $att -TargetIssueKey $targetKey -TempPath $tmpDir -Headers $tgtHdrs -BaseUrl $tgtBase -SourceHeaders $srcHdrs
        foreach ($k in $singleMap.Keys) { $attMap[$k] = $singleMap[$k] }
      }
    } finally {
      if (Test-Path $tmpDir) { Remove-Item -Path $tmpDir -Recurse -Force }
    }
  } else {
    Write-VerboseLog "  📎 No attachments to process" "Gray"
  }
  
  # NEW ORGANIZED APPROACH: Update description (ADF) after attachments
  Write-VerboseLog "  📄 STEP 2: Updating description (ADF)..." "Cyan"
  Process-Description -TargetBaseUrl $tgtBase -TargetHeaders $tgtHdrs -TargetKey $targetKey -SourceIssue $bundle.issue -AttachmentIdMap $attMap -NoFieldExistsData $bundle.noFieldExistsData | Out-Null
  
  # NEW ORGANIZED APPROACH: Update mapped custom fields (incl. ADF custom fields)
  Write-VerboseLog "  🔧 STEP 3: Processing custom fields with mapping..." "Cyan"
  Process-CustomFields -TargetBaseUrl $tgtBase -TargetHeaders $tgtHdrs -TargetKey $targetKey -SourceIssue $bundle.issue -MigrationConfig $config -AttachmentIdMap $attMap
  
  Write-Host "✅ Hydrated $targetKey from $sourceKey"
  
  # Track successful import
  $importedIssues += [PSCustomObject]@{
    SourceKey = $sourceKey
    TargetKey = $targetKey
    Status = "Success"
    AttachmentsProcessed = if ($attMap) { $attMap.Count } else { 0 }
    CommentsProcessed = 0
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  }
}

# Removed duplicate orphaned children processing block (handled later once)

# Process orphaned children
Write-VerboseLog "🔍 VERBOSE: Processing orphaned children..." "Cyan"
foreach ($bundle in $orphanedChildren) {
  $sourceKey = $bundle.issue.key
  $issueType = $bundle.issue.fields.issuetype.name
  $parentKey = if ($bundle.issue.fields.PSObject.Properties.Name -contains 'parent') { $bundle.issue.fields.parent.key } else { "N/A" }
  
  Write-VerboseLog "🎯 Processing orphaned child: $sourceKey (Type: $issueType, Missing Parent: $parentKey)" "Yellow"
  
  # Find the target key of the parent using the parent mapping file
  $targetParentKey = $null
  if ($parentKey -and $parentKey -ne "N/A") {
    Write-VerboseLog "  🔍 Looking for target key of parent $parentKey in mapping file..." "Gray"
    $parentMapping = $parentMappings | Where-Object { $_.SourceKey -eq $parentKey }
    if ($parentMapping -and $parentMapping.TargetKey -ne "PENDING") {
      $targetParentKey = $parentMapping.TargetKey
      Write-VerboseLog "  ✅ Found target parent: $targetParentKey for source parent $parentKey" "Green"
    } else {
      Write-VerboseLog "  ⚠️  Parent $parentKey not found in mapping or not yet created" "Yellow"
    }
  }
  
  # Create the issue with parent if found, otherwise as orphaned
  if ($targetParentKey) {
    Write-VerboseLog "  🔗 Creating issue with target parent: $targetParentKey" "Cyan"
    $result = Ensure-Issue -TargetBaseUrl $tgtBase -TargetHeaders $tgtHdrs -TargetProjectKey $targetProjectKey -SourceIssue $bundle.issue -MigrationConfig $config -ParentKey $targetParentKey
  } else {
    Write-VerboseLog "  🚫 Creating orphaned issue (parent not found)" "Yellow"
    $result = Ensure-Issue -TargetBaseUrl $tgtBase -TargetHeaders $tgtHdrs -TargetProjectKey $targetProjectKey -SourceIssue $bundle.issue -MigrationConfig $config
  }
  
  if ($result.Success) {
    Update-ParentMapping -SourceKey $sourceKey -TargetKey $result.TargetKey
    if ($targetParentKey) {
      Write-VerboseLog "✅ Created child with parent: $sourceKey -> $($result.TargetKey) (Parent: $targetParentKey)" "Green"
      $importedIssues += [PSCustomObject]@{
        SourceKey = $sourceKey
        TargetKey = $result.TargetKey
        IssueType = $issueType
        Status = "Created (With Parent)"
        ParentKey = $parentKey
        ParentStatus = "Found in target"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      }
    } else {
      Write-VerboseLog "✅ Created orphaned child: $sourceKey -> $($result.TargetKey)" "Green"
      $importedIssues += [PSCustomObject]@{
        SourceKey = $sourceKey
        TargetKey = $result.TargetKey
        IssueType = $issueType
        Status = "Created (Orphaned)"
        ParentKey = $parentKey
        ParentStatus = "Missing from export"
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      }
    }
    
    # Add to orphaned children details
    $orphanedIssuesCSV += [PSCustomObject]@{
      SourceKey = $sourceKey
      IssueType = $issueType
      Summary = $bundle.issue.fields.summary
      ParentKey = $parentKey
      Status = $bundle.issue.fields.status.name
      Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
  } else {
    Write-VerboseLog "❌ Failed to create orphaned child: $sourceKey - $($result.Error)" "Red"
    $failedIssues += $sourceKey
  }
}

Write-Host "== Import complete =="

# Create import report
$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Processed"
    Value = $importedIssues.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Created"
    Value = $createdIssues.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Skipped"
    Value = $skippedIssues.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Issues Failed"
    Value = $failedIssues.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Orphaned Children"
    Value = $orphanedChildren.Count
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Attachments Processed"
    Value = $attachmentCount
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$importReport += [PSCustomObject]@{
    Type = "Summary"
    Name = "Comments Processed"
    Value = $commentCount
    Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to import report
$importReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Start Time"
    Value = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
    Timestamp = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-dd HH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
}

$importReport += [PSCustomObject]@{
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
$importReport += [PSCustomObject]@{
    Type = "Step"
    Name = "Step Total Time"
    Value = $durationString
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
}

# Export report to CSV
$csvPath = Join-Path $stepExportsDir "08_Import_Report.csv"
$importReport | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Import report saved: $csvPath" -ForegroundColor Green
Write-Host "   Total items: $($importReport.Count)" -ForegroundColor Cyan

# Export detailed import results
$importDetailsPath = Join-Path $stepExportsDir "08_Import_Details.csv"
$importedIssues | Export-Csv -Path $importDetailsPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Import details saved: $importDetailsPath" -ForegroundColor Green
Write-Host "   Total issues: $($importedIssues.Count)" -ForegroundColor Cyan

# Save orphaned children details if any
if ($orphanedChildren.Count -gt 0) {
  $orphanedChildrenDetails = @()
  foreach ($bundle in $orphanedChildren) {
    $orphanedChildrenDetails += [PSCustomObject]@{
      SourceKey = $bundle.issue.key
      IssueType = $bundle.issue.fields.issuetype.name
      Summary = $bundle.issue.fields.summary
      ParentKey = $bundle.issue.fields.parent.key
      Status = $bundle.issue.fields.status.name
      Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
  }
  
  $orphanedChildrenPath = Join-Path $stepExportsDir "08_Import_Orphaned_Children.csv"
  $orphanedChildrenDetails | Export-Csv -Path $orphanedChildrenPath -NoTypeInformation -Encoding UTF8
  Write-Host "✅ Orphaned children details saved: $orphanedChildrenPath" -ForegroundColor Green
}

# Save updated parent mapping file
$updatedParentMappingPath = Join-Path $stepExportsDir "08_Parent_Mapping_Updated.csv"
$parentMappings | Export-Csv -Path $updatedParentMappingPath -NoTypeInformation -Encoding UTF8
Write-Host "✅ Updated parent mapping saved: $updatedParentMappingPath" -ForegroundColor Green
Write-Host "   Total mappings: $($parentMappings.Count)" -ForegroundColor Cyan

# Orphaned issues CSV is already generated above from $orphanedIssuesCSV array

# Create receipt data if Write-StageReceipt function exists
if (Get-Command Write-StageReceipt -ErrorAction SilentlyContinue) {
    $receiptData = @{
        StartTime = if ($script:StepStartTime) { $script:StepStartTime.ToString("yyyy-MM-ddTHH:mm:ss") } else { (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss") }
        EndTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        ImportFile = $exportFile
        IssuesProcessed = $importedIssues.Count
        AttachmentsProcessed = $attachmentCount
        CommentsProcessed = $commentCount
        ProjectKey = $projectKey
        TargetProjectKey = $targetProjectKey
    }
    
    Write-StageReceipt -OutDir $stepExportsDir -Stage "08_Import" -Data $receiptData
}

# Save issues log if function exists
if (Get-Command Save-IssuesLog -ErrorAction SilentlyContinue) {
    Save-IssuesLog -StepName "08_Import"
}

# Generate known errors CSV
if ($knownErrors.Count -gt 0) {
    Write-Host "📊 Generating known errors CSV: $knownErrorsFile" -ForegroundColor Yellow
    $knownErrors | Export-Csv -Path $knownErrorsFile -NoTypeInformation
    Write-Host "✅ Known errors CSV created with $($knownErrors.Count) entries" -ForegroundColor Green
} else {
    Write-Host "✅ No known errors to log" -ForegroundColor Green
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Import completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
