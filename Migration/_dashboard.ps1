# _dashboard.ps1 - Shared Dashboard Functions for Interactive and Auto-Run Modes
#
# This file contains the unified dashboard generation and update logic
# used by both RunMigration.ps1 (Interactive) and Run-All.ps1 (Auto-Run)

# Load System.Web for HTML encoding
Add-Type -AssemblyName System.Web

# Define all migration steps (shared)
$script:AllMigrationSteps = [ordered]@{
    "01" = "Preflight Validation"
    "02" = "Create Target Project"
    "03" = "Migrate Users and Roles"
    "04" = "Components and Labels"
    "05" = "Versions"
    "06" = "Boards"
    "07" = "Export Issues from Source"
    "08" = "Create Issues in Target"
    "09" = "Migrate Attachments"
    "10" = "Migrate Comments"
    "11" = "Migrate Links"
    "12" = "Migrate Worklogs"
    "13" = "Migrate Sprints"
    "14" = "History Migration"
    "15" = "Review Migration"
    "16" = "Push to Confluence"
}

function Get-StepStatus {
    param([string]$StepNumber, [string]$OutDir)
    
    # Check if receipt file exists for this step
    # Pattern matches files like: 01_Preflight_receipt.json
    $receiptPattern = "${StepNumber}_*_receipt.json"
    
    # Look in step-specific subdirectories (exports01, exports02, etc.)
    $stepExportsDir = Join-Path $OutDir "exports$StepNumber"
    $receipts = Get-ChildItem -Path $stepExportsDir -Filter $receiptPattern -ErrorAction SilentlyContinue
    
    if ($receipts) {
        return "completed"
    } else {
        return "pending"
    }
}

function Format-ReceiptSummary {
    param(
        $Receipt, 
        $StepNumber,
        $SourceBase = "",
        $TargetBase = "",
        $SourceProjectKey = "",
        $TargetProjectKey = "",
        $ReceiptPath = ""
    )
    
    $html = ""
    
    # Helper to extract project keys from receipt if not provided
    $sourceKey = $SourceProjectKey
    $targetKey = $TargetProjectKey
    
    if (-not $sourceKey -and $Receipt.PSObject.Properties['SourceProject']) {
        if ($Receipt.SourceProject.PSObject.Properties['key']) { $sourceKey = $Receipt.SourceProject.key }
    }
    if (-not $sourceKey -and $Receipt.PSObject.Properties['SourceProjectKey']) {
        $sourceKey = $Receipt.SourceProjectKey
    }
    
    if (-not $targetKey -and $Receipt.PSObject.Properties['TargetProject']) {
        if ($Receipt.TargetProject.PSObject.Properties['key']) { $targetKey = $Receipt.TargetProject.key }
    }
    if (-not $targetKey -and $Receipt.PSObject.Properties['TargetProjectKey']) {
        $targetKey = $Receipt.TargetProjectKey
    }
    
    # Use provided base URLs (loaded from parameters.json)
    $sourceBase = $SourceBase -replace '/$', ''
    $targetBase = $TargetBase -replace '/$', ''
    
    # Create a formatted summary based on step type
    switch ($StepNumber) {
        "01" {
            # Preflight
            if ($Receipt.PSObject.Properties['Ok']) {
                $html += "<div class='summary-success'>✅ Preflight validation passed</div>"
            }
            
            # Extract URLs from base parameters
            $sourceUrl = $SourceBase -replace '/$', ''
            $targetUrl = $TargetBase -replace '/$', ''
            
            # Format as requested: URL -> source -> target
            if ($sourceUrl -and $targetUrl) {
                $html += "<div class='summary-item'><strong>URL:</strong> $([System.Web.HttpUtility]::HtmlEncode($sourceUrl)) → $([System.Web.HttpUtility]::HtmlEncode($targetUrl))</div>"
            }
            
            # Format as requested: Project Key: DEP -> DEP1
            if ($Receipt.PSObject.Properties['SourceProjectKey'] -and $Receipt.PSObject.Properties['TargetProjectKey']) {
                $html += "<div class='summary-item'><strong>Project Key:</strong> $([System.Web.HttpUtility]::HtmlEncode($Receipt.SourceProjectKey)) → $([System.Web.HttpUtility]::HtmlEncode($Receipt.TargetProjectKey))</div>"
            }
            
            # Format as requested: Project Name: source -> target
            if ($Receipt.PSObject.Properties['SourceProjectName'] -and $Receipt.PSObject.Properties['TargetProjectName']) {
                $html += "<div class='summary-item'><strong>Project Name:</strong> $([System.Web.HttpUtility]::HtmlEncode($Receipt.SourceProjectName)) → $([System.Web.HttpUtility]::HtmlEncode($Receipt.TargetProjectName))</div>"
            }
            
            # Format TimeUtc properly
            if ($Receipt.PSObject.Properties['TimeUtc']) {
                $timeUtc = $Receipt.TimeUtc
                if ($timeUtc -eq "DateTime" -or $timeUtc -like "*DateTime*") {
                    $timeUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                $html += "<div class='summary-item'><strong>TimeUtc:</strong> $([System.Web.HttpUtility]::HtmlEncode($timeUtc))</div>"
            }
        }
        
        "02" {
            # Create Project
            if ($Receipt.PSObject.Properties['ProjectCreated']) {
                if ($Receipt.ProjectCreated) {
                    $html += "<div class='summary-success'>✅ Project created successfully</div>"
                } else {
                    $html += "<div class='summary-info'>ℹ️ Project already existed (using existing)</div>"
                }
            }
            if ($Receipt.PSObject.Properties['TargetProjectKey']) {
                $html += "<div class='summary-item'><strong>Project Key:</strong> $($Receipt.TargetProjectKey)</div>"
            }
            if ($Receipt.PSObject.Properties['TargetProjectName']) {
                $html += "<div class='summary-item'><strong>Project Name:</strong> $([System.Web.HttpUtility]::HtmlEncode($Receipt.TargetProjectName))</div>"
            }
            
            # Project verification links - both source and target
            if (($sourceBase -and $sourceKey) -or ($targetBase -and $targetKey)) {
                $html += "<div class='summary-section' style='margin-top: 20px;'><strong>🔍 Project Access:</strong></div>"
                $html += "<div style='margin-top: 15px; display: flex; gap: 12px; flex-wrap: wrap;'>"
                
                # Source Project buttons (Royal Blue - same color)
                if ($sourceBase -and $sourceKey) {
                    $html += "<a href='$sourceBase/browse/$sourceKey' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #1e40af; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>📁 Source Project ↗</a>"
                    $html += "<a href='$sourceBase/plugins/servlet/project-config/$sourceKey/summary' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #1e40af; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>⚙️ Source Settings ↗</a>"
                }
                
                # Target Project buttons (Green - same color)
                if ($targetBase -and $targetKey) {
                    $html += "<a href='$targetBase/browse/$targetKey' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #059669; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>📁 Target Project ↗</a>"
                    $html += "<a href='$targetBase/plugins/servlet/project-config/$targetKey/summary' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #059669; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>⚙️ Target Settings ↗</a>"
                }
                
                $html += "</div>"
            }
        }
        
        "03" {
            # Sync Users - use unique counts if available, fallback to role assignment counts
            $succeeded = if ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['UniqueCounts'] -and $Receipt.Users.UniqueCounts.PSObject.Properties['Succeeded']) { 
                $Receipt.Users.UniqueCounts.Succeeded 
            } elseif ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['Succeeded']) { 
                $Receipt.Users.Succeeded.Count 
            } else { 0 }
            
            $failed = if ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['UniqueCounts'] -and $Receipt.Users.UniqueCounts.PSObject.Properties['Failed']) { 
                $Receipt.Users.UniqueCounts.Failed 
            } elseif ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['Failed']) { 
                $Receipt.Users.Failed.Count 
            } else { 0 }
            
            $skipped = if ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['UniqueCounts'] -and $Receipt.Users.UniqueCounts.PSObject.Properties['Skipped']) { 
                $Receipt.Users.UniqueCounts.Skipped 
            } elseif ($Receipt.PSObject.Properties['Users'] -and $Receipt.Users.PSObject.Properties['Skipped']) { 
                $Receipt.Users.Skipped.Count 
            } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$succeeded</div><div class='stat-label'>Users Synced</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-warning'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            if ($skipped -gt 0) {
                $html += "<div class='stat-box stat-info'><div class='stat-number'>$skipped</div><div class='stat-label'>Skipped</div></div>"
            }
            $html += "</div>"
            
            # Show detailed user lists
            if ($Receipt.PSObject.Properties['Users']) {
                if ($Receipt.Users.PSObject.Properties['Succeeded'] -and $Receipt.Users.Succeeded.Count -gt 0) {
                    $html += "<div class='summary-section' style='margin-top: 15px;'><strong>✅ Users Successfully Added:</strong></div>"
                    $html += "<div style='margin-top: 8px; padding: 10px; background: #f0f9ff; border-radius: 4px; font-family: monospace; font-size: 12px; max-height: 120px; overflow-y: auto;'>"
                    foreach ($user in $Receipt.Users.Succeeded) {
                        $displayName = if ($user.PSObject.Properties['DisplayName']) { $user.DisplayName } elseif ($user.PSObject.Properties['displayName']) { $user.displayName } else { $user.AccountId }
                        $email = if ($user.PSObject.Properties['EmailAddress']) { $user.EmailAddress } elseif ($user.PSObject.Properties['emailAddress']) { $user.emailAddress } else { "N/A" }
                        $html += "<div style='margin-bottom: 4px;'>• $([System.Web.HttpUtility]::HtmlEncode($displayName)) ($([System.Web.HttpUtility]::HtmlEncode($email)))</div>"
                    }
                    $html += "</div>"
                }
                
                if ($Receipt.Users.PSObject.Properties['Failed'] -and $Receipt.Users.Failed.Count -gt 0) {
                    $html += "<div class='summary-section' style='margin-top: 15px;'><strong>❌ Users Failed to Add:</strong></div>"
                    $html += "<div style='margin-top: 8px; padding: 10px; background: #fef2f2; border-radius: 4px; font-family: monospace; font-size: 12px; max-height: 120px; overflow-y: auto;'>"
                    foreach ($user in $Receipt.Users.Failed) {
                        $displayName = if ($user.PSObject.Properties['DisplayName']) { $user.DisplayName } elseif ($user.PSObject.Properties['displayName']) { $user.displayName } else { $user.AccountId }
                        $email = if ($user.PSObject.Properties['EmailAddress']) { $user.EmailAddress } elseif ($user.PSObject.Properties['emailAddress']) { $user.emailAddress } else { "N/A" }
                        $reason = if ($user.PSObject.Properties['Error']) { $user.Error } elseif ($user.PSObject.Properties['Reason']) { $user.Reason } else { "Unknown error" }
                        $html += "<div style='margin-bottom: 4px;'>• $([System.Web.HttpUtility]::HtmlEncode($displayName)) ($([System.Web.HttpUtility]::HtmlEncode($email))) - $([System.Web.HttpUtility]::HtmlEncode($reason))</div>"
                    }
                    $html += "</div>"
                }
                
                if ($Receipt.Users.PSObject.Properties['Skipped'] -and $Receipt.Users.Skipped.Count -gt 0) {
                    $html += "<div class='summary-section' style='margin-top: 15px;'><strong>⏭️ Users Skipped:</strong></div>"
                    $html += "<div style='margin-top: 8px; padding: 10px; background: #f9fafb; border-radius: 4px; font-family: monospace; font-size: 12px; max-height: 120px; overflow-y: auto;'>"
                    foreach ($user in $Receipt.Users.Skipped) {
                        $displayName = if ($user.PSObject.Properties['DisplayName']) { $user.DisplayName } elseif ($user.PSObject.Properties['displayName']) { $user.displayName } else { $user.AccountId }
                        $email = if ($user.PSObject.Properties['EmailAddress']) { $user.EmailAddress } elseif ($user.PSObject.Properties['emailAddress']) { $user.emailAddress } else { "N/A" }
                        $reason = if ($user.PSObject.Properties['Reason']) { $user.Reason } else { "Already exists" }
                        $html += "<div style='margin-bottom: 4px;'>• $([System.Web.HttpUtility]::HtmlEncode($displayName)) ($([System.Web.HttpUtility]::HtmlEncode($email))) - $([System.Web.HttpUtility]::HtmlEncode($reason))</div>"
                    }
                    $html += "</div>"
                }
            }
            
            if ($failed -gt 0 -and $Receipt.PSObject.Properties['UsersToInvite']) {
                $inviteCount = if ($Receipt.UsersToInvite -is [array]) { $Receipt.UsersToInvite.Count } else { 0 }
                $html += "<div class='summary-warning' style='margin-top: 15px;'>⚠️ $failed users need to be invited to target instance</div>"
                $html += "<div class='summary-item'><strong>Invitation list created:</strong> $inviteCount users</div>"
            }
            
            # Verification links
            if ($sourceBase -and $sourceKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Verify Configuration:</strong></div>"
                $html += "<div style='margin-top: 10px;'>"
                $html += "<a href='$sourceBase/plugins/servlet/project-config/$sourceKey/people' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #6b7280; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; margin-right: 8px;'>👥 Source Project Roles ↗</a>"
                if ($targetBase -and $targetKey) {
                    $html += "<a href='$targetBase/plugins/servlet/project-config/$targetKey/people' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #0052CC; color: white; border-radius: 4px; text-decoration: none; font-size: 13px;'>👥 Target Project Roles ↗</a>"
                }
                $html += "</div>"
            }
        }
        
        "04" {
            # Components
            $created = if ($Receipt.PSObject.Properties['CreatedComponents']) { $Receipt.CreatedComponents } else { 0 }
            $existing = if ($Receipt.PSObject.Properties['ExistingComponents']) { $Receipt.ExistingComponents } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedComponents']) { $Receipt.FailedComponents } else { 0 }
            $labels = if ($Receipt.PSObject.Properties['UniqueLabels']) { $Receipt.UniqueLabels } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$created</div><div class='stat-label'>Components Created</div></div>"
            $html += "<div class='stat-box stat-info'><div class='stat-number'>$labels</div><div class='stat-label'>Unique Labels</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
            
            # Verification links
            if ($sourceBase -and $sourceKey -and $targetBase -and $targetKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Verify Components Match:</strong></div>"
                $html += "<div style='margin-top: 10px;'>"
                $html += "<a href='$sourceBase/plugins/servlet/project-config/$sourceKey/administer-components' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #6b7280; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; margin-right: 8px;'>📦 Source Components ↗</a>"
                $html += "<a href='$targetBase/plugins/servlet/project-config/$targetKey/administer-components' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #0052CC; color: white; border-radius: 4px; text-decoration: none; font-size: 13px;'>📦 Target Components ↗</a>"
                $html += "</div>"
            }
        }
        
        "08" {
            # Create Issues
            $created = if ($Receipt.PSObject.Properties['CreatedIssues']) { $Receipt.CreatedIssues } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedIssues']) { $Receipt.FailedIssues } else { 0 }
            $skipped = if ($Receipt.PSObject.Properties['SkippedIssues']) { $Receipt.SkippedIssues } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$created</div><div class='stat-label'>Issues Created</div></div>"
            if ($skipped -gt 0) {
                $html += "<div class='stat-box stat-info'><div class='stat-number'>$skipped</div><div class='stat-label'>Skipped (Existing)</div></div>"
            }
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
            
            # Orphaned Issues Warning
            $orphanedCount = if ($Receipt.PSObject.Properties['OrphanedIssuesCount']) { $Receipt.OrphanedIssuesCount } else { 0 }
            if ($orphanedCount -gt 0) {
                $html += "<div class='summary-section' style='margin-top: 15px; padding: 12px; background: #fef3c7; border-left: 4px solid #f59e0b; border-radius: 4px;'>"
                $html += "<strong style='color: #92400e;'>⚠️ Action Required: $orphanedCount Orphaned Issues</strong>"
                $html += "<div style='margin-top: 8px; color: #78350f; font-size: 13px;'>"
                $html += "These issues have parents that were resolved/excluded from migration.<br>"
                $html += "Project lead needs to manually link these to appropriate parents or mark as orphaned."
                $html += "</div>"
                $html += "<div style='margin-top: 10px;'>"
                $orphanedCsvPath = Join-Path $ReceiptPath "..\08_OrphanedIssues.csv" | Resolve-Path -ErrorAction SilentlyContinue
                if ($orphanedCsvPath) {
                    $html += "<a href='file:///$($orphanedCsvPath -replace '\\', '/')' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #f59e0b; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; font-weight: bold;'>📄 View Orphaned Issues CSV ↗</a>"
                }
                $html += "</div>"
                $html += "</div>"
            }
            
            # Verification links
            if ($sourceBase -and $sourceKey -and $targetBase -and $targetKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Compare Issues:</strong></div>"
                $html += "<div style='margin-top: 10px;'>"
                $html += "<a href='$sourceBase/browse/$sourceKey' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #6b7280; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; margin-right: 8px;'>🎫 Source Issues ↗</a>"
                $html += "<a href='$targetBase/browse/$targetKey' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #0052CC; color: white; border-radius: 4px; text-decoration: none; font-size: 13px;'>🎫 Target Issues ↗</a>"
                $html += "</div>"
            }
        }
        
        "09" {
            # Comments
            $migrated = if ($Receipt.PSObject.Properties['MigratedComments']) { $Receipt.MigratedComments } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedComments']) { $Receipt.FailedComments } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$migrated</div><div class='stat-label'>Comments Migrated</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
        }
        
        "10" {
            # Attachments
            $migrated = if ($Receipt.PSObject.Properties['MigratedAttachments']) { $Receipt.MigratedAttachments } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedAttachments']) { $Receipt.FailedAttachments } else { 0 }
            $bytes = if ($Receipt.PSObject.Properties['TotalBytesUploaded']) { [math]::Round($Receipt.TotalBytesUploaded / 1MB, 2) } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$migrated</div><div class='stat-label'>Attachments Migrated</div></div>"
            $html += "<div class='stat-box stat-info'><div class='stat-number'>$bytes MB</div><div class='stat-label'>Data Transferred</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
        }
        
        "11" {
            # Links
            $migrated = if ($Receipt.PSObject.Properties['MigratedLinks'] -or ($Receipt.PSObject.Properties['IssueLinks'] -and $Receipt.IssueLinks.PSObject.Properties['Created'])) { 
                if ($Receipt.PSObject.Properties['MigratedLinks']) { $Receipt.MigratedLinks } else { $Receipt.IssueLinks.Created }
            } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedLinks'] -or ($Receipt.PSObject.Properties['IssueLinks'] -and $Receipt.IssueLinks.PSObject.Properties['Failed'])) { 
                if ($Receipt.PSObject.Properties['FailedLinks']) { $Receipt.FailedLinks } else { $Receipt.IssueLinks.Failed }
            } else { 0 }
            $skipped = if ($Receipt.PSObject.Properties['SkippedLinks'] -or ($Receipt.PSObject.Properties['IssueLinks'] -and $Receipt.IssueLinks.PSObject.Properties['Skipped'])) { 
                if ($Receipt.PSObject.Properties['SkippedLinks']) { $Receipt.SkippedLinks } else { $Receipt.IssueLinks.Skipped }
            } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$migrated</div><div class='stat-label'>Links Migrated</div></div>"
            if ($skipped -gt 0) {
                $html += "<div class='stat-box stat-warning'><div class='stat-number'>$skipped</div><div class='stat-label'>Skipped (Cross-Project)</div></div>"
            }
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
            
            if ($skipped -gt 0) {
                $html += "<div class='summary-warning'>⚠️ $skipped cross-project links were skipped (link to non-migrated projects)</div>"
            }
        }
        
        "12" {
            # Worklogs
            $migrated = if ($Receipt.PSObject.Properties['MigratedWorklogs']) { $Receipt.MigratedWorklogs } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedWorklogs']) { $Receipt.FailedWorklogs } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$migrated</div><div class='stat-label'>Worklogs Migrated</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
        }
        
        "05" {
            # Versions
            $created = if ($Receipt.PSObject.Properties['CreatedVersions']) { $Receipt.CreatedVersions } else { 0 }
            $existing = if ($Receipt.PSObject.Properties['ExistingVersions']) { $Receipt.ExistingVersions } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedVersions']) { $Receipt.FailedVersions } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$created</div><div class='stat-label'>Versions Created</div></div>"
            if ($existing -gt 0) {
                $html += "<div class='stat-box stat-info'><div class='stat-number'>$existing</div><div class='stat-label'>Already Existed</div></div>"
            }
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
            
            # Verification links
            if ($sourceBase -and $sourceKey -and $targetBase -and $targetKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Verify Versions Match:</strong></div>"
                $html += "<div style='margin-top: 10px;'>"
                $html += "<a href='$sourceBase/plugins/servlet/project-config/$sourceKey/administer-versions' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #6b7280; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; margin-right: 8px;'>🏷️ Source Versions ↗</a>"
                $html += "<a href='$targetBase/plugins/servlet/project-config/$targetKey/administer-versions' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #0052CC; color: white; border-radius: 4px; text-decoration: none; font-size: 13px;'>🏷️ Target Versions ↗</a>"
                $html += "</div>"
            }
        }
        
        "06" {
            # Boards
            $created = if ($Receipt.PSObject.Properties['CreatedBoards']) { $Receipt.CreatedBoards } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedBoards']) { $Receipt.FailedBoards } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$created</div><div class='stat-label'>Boards Created</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            $html += "</div>"
            
            # Verification links
            if ($sourceBase -and $sourceKey -and $targetBase -and $targetKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Verify Boards Match:</strong></div>"
                $html += "<div style='margin-top: 10px; display: flex; gap: 12px; flex-wrap: wrap;'>"
                $html += "<a href='$sourceBase/jira/software/projects/$sourceKey/boards' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #1e40af; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>📊 Source Boards ↗</a>"
                $html += "<a href='$targetBase/jira/software/projects/$targetKey/boards' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 12px 20px; background: #059669; color: white; border-radius: 6px; text-decoration: none; font-size: 14px; font-weight: bold; min-width: 160px; text-align: center; box-shadow: 0 2px 4px rgba(0,0,0,0.1);'>📊 Target Boards ↗</a>"
                $html += "</div>"
            }
        }
        
        "07" {
            # Export Issues
            $exported = if ($Receipt.PSObject.Properties['TotalIssuesExported']) { 
                $Receipt.TotalIssuesExported 
            } elseif ($Receipt.PSObject.Properties['ExportedIssues']) { 
                $Receipt.ExportedIssues 
            } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$exported</div><div class='stat-label'>Issues Exported</div></div>"
            $html += "</div>"
        }
        
        "13" {
            # Sprints (moved from 15)
            $created = if ($Receipt.PSObject.Properties['CreatedSprints']) { $Receipt.CreatedSprints } else { 0 }
            $skipped = if ($Receipt.PSObject.Properties['SkippedSprints']) { $Receipt.SkippedSprints } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$created</div><div class='stat-label'>Sprints Created</div></div>"
            if ($skipped -gt 0) {
                $html += "<div class='stat-box stat-info'><div class='stat-number'>$skipped</div><div class='stat-label'>Skipped (Existing)</div></div>"
            }
            $html += "</div>"
            
            # Verification links - Open boards to see sprints
            if ($sourceBase -and $sourceKey -and $targetBase -and $targetKey) {
                $html += "<div class='summary-section' style='margin-top: 15px;'><strong>🔍 Verify Sprints (Check Boards):</strong></div>"
                $html += "<div style='margin-top: 10px;'>"
                $html += "<a href='$sourceBase/jira/software/c/projects/$sourceKey/boards' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #6b7280; color: white; border-radius: 4px; text-decoration: none; font-size: 13px; margin-right: 8px;'>🏃 Source Sprints ↗</a>"
                $html += "<a href='$targetBase/jira/software/c/projects/$targetKey/boards' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 6px 12px; background: #0052CC; color: white; border-radius: 4px; text-decoration: none; font-size: 13px;'>🏃 Target Sprints ↗</a>"
                $html += "</div>"
                $html += "<div style='margin-top: 5px; font-size: 12px; color: #6b7280;'>💡 Select a board, then view sprints backlog/reports</div>"
            }
        }
        
        "14" {
            # Automation Guide (moved from 13)
            $html += "<div class='summary-info'>⚠️ Automation rules must be manually recreated (no Jira API available)</div>"
            
            # Get URLs and key mappings from receipt
            $sourceUrl = if ($Receipt.PSObject.Properties['SourceProject'] -and $Receipt.SourceProject.PSObject.Properties['url']) { 
                $Receipt.SourceProject.url 
            } else { "" }
            $targetUrl = if ($Receipt.PSObject.Properties['TargetProject'] -and $Receipt.TargetProject.PSObject.Properties['url']) { 
                $Receipt.TargetProject.url 
            } else { "" }
            $keyMappingsCount = if ($Receipt.PSObject.Properties['KeyMappingsCount']) { $Receipt.KeyMappingsCount } else { 0 }
            
            # Stats
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-info'><div class='stat-number'>$keyMappingsCount</div><div class='stat-label'>Key Mappings</div></div>"
            $html += "</div>"
            
            # Create interactive automation checklist embedded in dashboard
            $html += "<div class='summary-section' style='margin-top: 20px;'><strong>📋 Interactive Automation Migration Checklist</strong></div>"
            $html += "<div style='background: #f0fdf4; border: 1px solid #10b981; border-radius: 8px; padding: 15px; margin: 10px 0;'>"
            $html += "<div style='margin-bottom: 10px;'><strong>Progress:</strong> <span id='automation-progress'>0/16</span> completed</div>"
            $html += "</div>"
            $html += "<div style='background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 20px; margin: 10px 0;'>"
            
            # Phase 1
            $html += "<div style='background: #f0fdf4; border-left: 4px solid #10b981; padding: 12px; border-radius: 6px; margin-bottom: 15px;'>"
            $html += "<strong style='color: #065f46;'>Phase 1: Preparation</strong>"
            $html += "<ul class='automation-checklist' id='auto-phase1' style='margin-top: 10px; padding-left: 20px;'>"
            if ($sourceUrl) {
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> <a href='$sourceUrl' target='_blank' onclick='event.stopPropagation();'>Open source automation rules ↗</a></li>"
            }
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Take screenshots of all automation rules</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Document each rule's trigger, conditions, and actions</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Note any rules that reference specific issue keys</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Identify rules using components, versions, or labels</li>"
            $html += "</ul>"
            $html += "</div>"
            
            # Phase 2
            $html += "<div style='background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px; border-radius: 6px; margin-bottom: 15px;'>"
            $html += "<strong style='color: #92400e;'>Phase 2: Recreation</strong>"
            $html += "<ul class='automation-checklist' id='auto-phase2' style='margin-top: 10px; padding-left: 20px;'>"
            if ($targetUrl) {
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> <a href='$targetUrl' target='_blank' onclick='event.stopPropagation();'>Open target automation settings ↗</a></li>"
            }
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> For each rule: Click 'Create rule' in target project</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Recreate trigger configuration</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Recreate conditions (update issue keys using mappings below)</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Recreate actions (update issue keys using mappings below)</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Update JQL queries with new project key</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Test each rule before enabling</li>"
            $html += "</ul>"
            $html += "</div>"
            
            # Phase 3
            $html += "<div style='background: #dbeafe; border-left: 4px solid #3b82f6; padding: 12px; border-radius: 6px;'>"
            $html += "<strong style='color: #1e40af;'>Phase 3: Validation</strong>"
            $html += "<ul class='automation-checklist' id='auto-phase3' style='margin-top: 10px; padding-left: 20px;'>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Verify all automation rules created in target</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Check rule counts match (source vs target)</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Test each rule with sample data</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Monitor audit log for execution</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Enable all validated rules</li>"
            $html += "<li><input type='checkbox' onclick='event.stopPropagation(); saveAutomationProgress();'> Document any differences or limitations</li>"
            $html += "</ul>"
            $html += "</div>"
            $html += "</div>"
            
            # Resource links
            if ($Receipt.PSObject.Properties['CsvExport']) {
                $html += "<div class='summary-item' style='margin-top: 15px;'>"
                $html += "<a href='file:///$($Receipt.CsvExport)' target='_blank' onclick='event.stopPropagation();' style='display: inline-block; padding: 8px 16px; background: #0052CC; color: white; border-radius: 6px; text-decoration: none; font-weight: 600;'>📊 Download Key Mappings CSV ↗</a>"
                $html += "</div>"
            }
        }
        
        "15" {
            # Permissions Guide (moved from 14)
            $testsRun = if ($Receipt.PSObject.Properties['AutomatedTestsRun']) { $Receipt.AutomatedTestsRun } else { $false }
            $apiValidations = if ($Receipt.PSObject.Properties['APIValidations']) { $Receipt.APIValidations } else { 0 }
            $automatedTests = if ($Receipt.PSObject.Properties['AutomatedTests']) { $Receipt.AutomatedTests } else { 0 }
            $manualChecks = if ($Receipt.PSObject.Properties['ManualChecks']) { $Receipt.ManualChecks } else { 0 }
            
            # Stats
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$apiValidations</div><div class='stat-label'>API Checks</div></div>"
            if ($testsRun) {
                $html += "<div class='stat-box stat-info'><div class='stat-number'>$automatedTests</div><div class='stat-label'>Auto Tests</div></div>"
            }
            $html += "<div class='stat-box stat-warning'><div class='stat-number'>$manualChecks</div><div class='stat-label'>Manual Checks</div></div>"
            $html += "</div>"
            
            if ($testsRun) {
                $html += "<div class='summary-success'>✅ Automated tests completed - test issue cleaned up</div>"
            } else {
                $html += "<div class='summary-info'>ℹ️ Manual validation only (automated tests skipped)</div>"
            }
            
            # Embedded manual validation checklist
            if ($manualChecks -gt 0) {
                $html += "<div class='summary-section' style='margin-top: 20px;'><strong>✅ Interactive Manual Validation Checklist</strong></div>"
                $html += "<div style='background: #f0fdf4; border: 1px solid #10b981; border-radius: 8px; padding: 15px; margin: 10px 0;'>"
                $html += "<div style='margin-bottom: 10px;'><strong>Progress:</strong> <span id='permissions-progress'>0/11</span> completed</div>"
                $html += "</div>"
                $html += "<div style='background: white; border: 1px solid #e5e7eb; border-radius: 8px; padding: 20px; margin: 10px 0;'>"
                
                # Permission checks
                $html += "<div style='background: #fee2e2; border-left: 4px solid #ef4444; padding: 12px; border-radius: 6px; margin-bottom: 15px;'>"
                $html += "<strong style='color: #991b1b;'>Permission Scheme (CRITICAL)</strong>"
                $html += "<ul class='permissions-checklist' id='perm-perms' style='margin-top: 10px; padding-left: 20px;'>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify Browse Projects permission</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify Create Issues permission</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify Edit Issues permission</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify Assignable User permission</li>"
                $html += "</ul>"
                $html += "</div>"
                
                # Workflow checks
                $html += "<div style='background: #fef3c7; border-left: 4px solid #f59e0b; padding: 12px; border-radius: 6px; margin-bottom: 15px;'>"
                $html += "<strong style='color: #92400e;'>Workflow Scheme (HIGH)</strong>"
                $html += "<ul class='permissions-checklist' id='perm-workflow' style='margin-top: 10px; padding-left: 20px;'>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Test transitioning issue from Open to In Progress</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Test transitioning issue to Done status</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify all required statuses exist</li>"
                $html += "</ul>"
                $html += "</div>"
                
                # Screen/Field checks
                $html += "<div style='background: #dbeafe; border-left: 4px solid #3b82f6; padding: 12px; border-radius: 6px;'>"
                $html += "<strong style='color: #1e40af;'>Screens & Fields (MEDIUM)</strong>"
                $html += "<ul class='permissions-checklist' id='perm-screens' style='margin-top: 10px; padding-left: 20px;'>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify required fields on Create screen</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify required fields on Edit screen</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Verify Component/s field is available</li>"
                $html += "<li><input type='checkbox' onclick='event.stopPropagation(); savePermissionsProgress();'> Check field configurations</li>"
                $html += "</ul>"
                $html += "</div>"
                
                $html += "</div>"
            }
            
            # Test issue cleanup warning
            if ($Receipt.PSObject.Properties['TestIssueCreated']) {
                $testIssue = $Receipt.TestIssueCreated
                if ($testIssue -like "*(NOT deleted*") {
                    $html += "<div class='summary-warning' style='margin-top: 10px;'>⚠️ Test issue $testIssue requires manual cleanup</div>"
                }
            }
        }
        
        "16" {
            # QA Validation (unchanged)
            $passed = if ($Receipt.PSObject.Properties['PassedValidations']) { $Receipt.PassedValidations } else { 0 }
            $failed = if ($Receipt.PSObject.Properties['FailedValidations']) { $Receipt.FailedValidations } else { 0 }
            $warnings = if ($Receipt.PSObject.Properties['Warnings']) { $Receipt.Warnings.Count } else { 0 }
            
            $html += "<div class='summary-stats'>"
            $html += "<div class='stat-box stat-success'><div class='stat-number'>$passed</div><div class='stat-label'>Validations Passed</div></div>"
            if ($failed -gt 0) {
                $html += "<div class='stat-box stat-error'><div class='stat-number'>$failed</div><div class='stat-label'>Failed</div></div>"
            }
            if ($warnings -gt 0) {
                $html += "<div class='stat-box stat-warning'><div class='stat-number'>$warnings</div><div class='stat-label'>Warnings</div></div>"
            }
            $html += "</div>"
            
            if ($failed -gt 0) {
                $html += "<div class='summary-warning'>⚠️ Some validations failed - review details below</div>"
            }
        }
        
        "17" {
            # Finalize
            $html += "<div class='summary-success'>✅ Migration finalized</div>"
            if ($Receipt.PSObject.Properties['MigratedIssues']) {
                $html += "<div class='summary-item'><strong>Total Issues Migrated:</strong> $($Receipt.MigratedIssues)</div>"
            }
        }
        
        "14" {
            # Review Migration (consolidated QA, permissions, automation, reports)
            $html += "<div class='summary-success'>✅ Migration review and validation complete</div>"
            if ($Receipt.PSObject.Properties['QualityScore']) {
                $html += "<div class='summary-item'><strong>Quality Score:</strong> $($Receipt.QualityScore)%</div>"
            }
            if ($Receipt.PSObject.Properties['MigratedIssues']) {
                $html += "<div class='summary-item'><strong>Total Migrated:</strong> $($Receipt.MigratedIssues) issues</div>"
            }
        }
    }
    
    # Always show notes if present
    if ($Receipt.PSObject.Properties['Notes'] -and $Receipt.Notes) {
        $html += "<div class='summary-section'><strong>Notes:</strong></div>"
        $html += "<ul class='summary-notes'>"
        if ($Receipt.Notes -is [array]) {
            foreach ($note in $Receipt.Notes) {
                $html += "<li>" + [System.Web.HttpUtility]::HtmlEncode($note) + "</li>"
            }
        } else {
            $html += "<li>" + [System.Web.HttpUtility]::HtmlEncode($Receipt.Notes) + "</li>"
        }
        $html += "</ul>"
    }
    
    # If no custom summary was generated, show a collapsible "Full Receipt Data" section
    if (-not $html) {
        $html += "<div class='summary-info'>ℹ️ Step completed successfully</div>"
    }
    
    # Add collapsible full receipt data at the end
    $html += "<details style='margin-top: 20px;' onclick='event.stopPropagation();'>"
    $html += "<summary style='cursor: pointer; padding: 10px; background: #f3f4f6; border-radius: 6px; font-weight: 600;' onclick='event.stopPropagation();'>📄 View Full Receipt Data</summary>"
    $html += "<div style='margin-top: 10px; padding: 15px; background: #f9fafb; border-radius: 6px; font-family: monospace; font-size: 12px;'>"
    
    # Recursively render all receipt properties
    foreach ($prop in $Receipt.PSObject.Properties) {
        $name = [System.Web.HttpUtility]::HtmlEncode($prop.Name)
        $value = $prop.Value
        
        if ($null -eq $value) {
            $html += "<div><strong>${name}:</strong> null</div>"
        }
        elseif ($value -is [bool]) {
            $html += "<div><strong>${name}:</strong> $value</div>"
        }
        elseif ($value -is [int] -or $value -is [long] -or $value -is [double] -or $value -is [string]) {
            $displayValue = [System.Web.HttpUtility]::HtmlEncode($value)
            $html += "<div><strong>${name}:</strong> $displayValue</div>"
        }
        elseif ($value -is [array]) {
            $html += "<div><strong>${name}:</strong> Array ($($value.Count) items)</div>"
        }
        else {
            $html += "<div><strong>${name}:</strong> $($value.GetType().Name)</div>"
        }
    }
    
    $html += "</div></details>"
    
    return $html
}

function New-UnifiedDashboard {
    param($ProjectName, $ProjectKey, $Mode = "Interactive")
    
    $modeBadge = if ($Mode -eq "Auto-Run") { "🚀 Auto-Run Mode" } else { "📋 Interactive Mode" }
    
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Migration Progress - $ProjectName</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 12px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }
        .header h1 { font-size: 2em; margin-bottom: 10px; }
        .header p { opacity: 0.9; font-size: 1.1em; }
        .mode-badge {
            display: inline-block;
            background: rgba(255,255,255,0.2);
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-top: 10px;
        }
        .progress-bar {
            height: 8px;
            background: rgba(255,255,255,0.3);
            margin: 20px 30px;
            border-radius: 4px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: #10b981;
            transition: width 0.5s ease;
        }
        .stats {
            display: flex;
            justify-content: space-around;
            padding: 20px 30px;
            background: #f9fafb;
            border-bottom: 1px solid #e5e7eb;
        }
        .stat { text-align: center; }
        .stat-value {
            font-size: 2em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-label {
            color: #6b7280;
            font-size: 0.9em;
            margin-top: 5px;
        }
        .steps {
            padding: 30px;
        }
        .step {
            background: #f9fafb;
            border: 1px solid #e5e7eb;
            border-radius: 8px;
            margin-bottom: 15px;
            overflow: hidden;
            transition: all 0.3s ease;
        }
        .step.completed { border-color: #10b981; background: #f0fdf4; }
        .step.running { border-color: #3b82f6; animation: pulse 2s infinite; }
        .step.failed { border-color: #ef4444; background: #fef2f2; }
        @keyframes pulse {
            0%, 100% { box-shadow: 0 0 0 0 rgba(59, 130, 246, 0.4); }
            50% { box-shadow: 0 0 0 8px rgba(59, 130, 246, 0); }
        }
        .step-header {
            padding: 20px;
            display: flex;
            align-items: center;
            cursor: pointer;
            user-select: none;
        }
        .step-header:hover {
            background: rgba(0,0,0,0.02);
        }
        .checkbox {
            width: 24px;
            height: 24px;
            border: 2px solid #d1d5db;
            border-radius: 4px;
            margin-right: 15px;
            display: flex;
            align-items: center;
            justify-content: center;
            flex-shrink: 0;
        }
        .step.completed .checkbox {
            background: #10b981;
            border-color: #10b981;
        }
        .step.running .checkbox {
            background: #3b82f6;
            border-color: #3b82f6;
        }
        .step.failed .checkbox {
            background: #ef4444;
            border-color: #ef4444;
        }
        .checkbox::after {
            content: '✓';
            color: white;
            font-weight: bold;
            display: none;
        }
        .step.completed .checkbox::after { display: block; }
        .step.running .checkbox::after {
            content: '⟳';
            display: block;
            animation: spin 1s linear infinite;
        }
        .step.failed .checkbox::after {
            content: '✗';
            display: block;
        }
        @keyframes spin {
            to { transform: rotate(360deg); }
        }
        .step-title {
            flex: 1;
            font-weight: 600;
            color: #1f2937;
        }
        .step-number {
            color: #667eea;
            font-weight: bold;
            margin-right: 10px;
        }
        .step-status {
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
        }
        .status-pending { background: #e5e7eb; color: #6b7280; }
        .status-running { background: #dbeafe; color: #1e40af; }
        .status-completed { background: #d1fae5; color: #065f46; }
        .status-failed { background: #fee2e2; color: #991b1b; }
        .step-details {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.5s ease-out;
            background: white;
            border-top: 1px solid #e5e7eb;
        }
        .step.expanded .step-details {
            max-height: 5000px;
            overflow-y: auto;
        }
        .step-summary {
            padding: 20px;
            font-size: 14px;
            line-height: 1.8;
            color: #374151;
        }
        .summary-stats {
            display: flex;
            gap: 15px;
            margin: 15px 0;
            flex-wrap: wrap;
        }
        .stat-box {
            flex: 1;
            min-width: 120px;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-box.stat-success { background: #d1fae5; border-left: 4px solid #10b981; }
        .stat-box.stat-warning { background: #fef3c7; border-left: 4px solid #f59e0b; }
        .stat-box.stat-error { background: #fee2e2; border-left: 4px solid #ef4444; }
        .stat-box.stat-info { background: #dbeafe; border-left: 4px solid #3b82f6; }
        .stat-box .stat-number {
            font-size: 24px;
            font-weight: bold;
            color: #1f2937;
        }
        .stat-box .stat-label {
            font-size: 12px;
            color: #6b7280;
            margin-top: 5px;
        }
        .summary-success {
            background: #d1fae5;
            color: #065f46;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #10b981;
        }
        .summary-warning {
            background: #fef3c7;
            color: #92400e;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #f59e0b;
        }
        .summary-info {
            background: #dbeafe;
            color: #1e40af;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #3b82f6;
        }
        .summary-item {
            margin: 8px 0;
            padding: 5px 0;
        }
        .summary-section {
            margin-top: 15px;
            margin-bottom: 5px;
            color: #1f2937;
            font-weight: 600;
        }
        .summary-notes {
            list-style-type: disc;
            margin-left: 20px;
            color: #374151;
        }
        .summary-notes li {
            margin: 5px 0;
        }
        .step-summary a {
            color: #0052CC;
            text-decoration: none;
        }
        .step-summary a:hover {
            text-decoration: underline;
        }
        .summary-stats {
            display: flex;
            gap: 15px;
            margin: 15px 0;
            flex-wrap: wrap;
        }
        .stat-box {
            flex: 1;
            min-width: 120px;
            padding: 15px;
            border-radius: 8px;
            text-align: center;
        }
        .stat-box.stat-success { background: #d1fae5; border-left: 4px solid #10b981; }
        .stat-box.stat-warning { background: #fef3c7; border-left: 4px solid #f59e0b; }
        .stat-box.stat-error { background: #fee2e2; border-left: 4px solid #ef4444; }
        .stat-box.stat-info { background: #dbeafe; border-left: 4px solid #3b82f6; }
        .stat-box .stat-number {
            font-size: 24px;
            font-weight: bold;
            color: #1f2937;
        }
        .stat-box .stat-label {
            font-size: 12px;
            color: #6b7280;
            margin-top: 5px;
        }
        .summary-success {
            background: #d1fae5;
            color: #065f46;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #10b981;
        }
        .summary-warning {
            background: #fef3c7;
            color: #92400e;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #f59e0b;
        }
        .summary-info {
            background: #dbeafe;
            color: #1e40af;
            padding: 10px 15px;
            border-radius: 6px;
            margin: 10px 0;
            border-left: 4px solid #3b82f6;
        }
        .summary-item {
            margin: 8px 0;
            padding: 5px 0;
        }
        .summary-section {
            margin-top: 15px;
            margin-bottom: 5px;
            color: #1f2937;
            font-weight: 600;
        }
        .summary-notes {
            list-style-type: disc;
            margin-left: 20px;
            color: #374151;
        }
        .summary-notes li {
            margin: 5px 0;
        }
        .automation-checklist li,
        .permissions-checklist li {
            margin: 8px 0;
            cursor: pointer;
            transition: all 0.2s;
        }
        .automation-checklist input[type="checkbox"],
        .permissions-checklist input[type="checkbox"] {
            margin-right: 8px;
            cursor: pointer;
            width: 16px;
            height: 16px;
        }
        .automation-checklist li:has(input:checked),
        .permissions-checklist li:has(input:checked) {
            opacity: 0.6;
            text-decoration: line-through;
        }
        .expand-icon {
            margin-left: auto;
            padding-left: 10px;
            color: #9ca3af;
            font-size: 12px;
            transition: transform 0.3s ease;
        }
        .step.expanded .expand-icon {
            transform: rotate(180deg);
        }
        .footer {
            padding: 20px;
            text-align: center;
            color: #6b7280;
            border-top: 1px solid #e5e7eb;
        }
        .refresh-button {
            padding: 10px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
        }
        .refresh-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.5);
        }
        .refresh-button:active {
            transform: translateY(0);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div style="display: flex; justify-content: space-between; align-items: center; width: 100%;">
                <div>
                    <h1>🎯 Migration Progress</h1>
                    <p>Project: $ProjectName ($ProjectKey)</p>
                    <div class="mode-badge">$modeBadge</div>
                </div>
                <button class="refresh-button" onclick="location.reload();" title="Refresh Dashboard">
                    🔄 Refresh
                </button>
            </div>
        </div>
        <div class="progress-bar">
            <div class="progress-fill" id="progressFill" style="width: 0%"></div>
        </div>
        <div class="stats">
            <div class="stat">
                <div class="stat-value" id="completedCount">0</div>
                <div class="stat-label">Completed</div>
            </div>
            <div class="stat">
                <div class="stat-value" id="pendingCount">16</div>
                <div class="stat-label">Pending</div>
            </div>
            <div class="stat">
                <div class="stat-value" id="percentComplete">0%</div>
                <div class="stat-label">Progress</div>
            </div>
        </div>
        <div class="steps" id="stepsList">
            <!-- Steps will be inserted here -->
        </div>
        <div class="footer">
            <p style="font-size: 0.9em;">Last updated: <span id="lastUpdate">--</span></p>
            <p style="margin-top: 8px; font-size: 0.85em; color: #9ca3af;">💡 Click the Refresh button to check for updates</p>
        </div>
    </div>
    <script>
        // Update last update time
        document.getElementById('lastUpdate').textContent = new Date().toLocaleTimeString();
        
        // Toggle step details expansion
        function toggleStepDetails(stepElement) {
            // Don't toggle if clicking on interactive elements
            if (event.target.tagName === 'A' || 
                event.target.tagName === 'BUTTON' || 
                event.target.tagName === 'SUMMARY' ||
                event.target.tagName === 'DETAILS' ||
                event.target.tagName === 'INPUT' ||
                event.target.closest('details') ||
                event.target.closest('input')) {
                return;
            }
            
            stepElement.classList.toggle('expanded');
        }
        
        // Save automation checklist progress to localStorage
        function saveAutomationProgress() {
            const phase1Checkboxes = document.querySelectorAll('#auto-phase1 input[type="checkbox"]');
            const phase2Checkboxes = document.querySelectorAll('#auto-phase2 input[type="checkbox"]');
            const phase3Checkboxes = document.querySelectorAll('#auto-phase3 input[type="checkbox"]');
            
            const progress = {
                phase1: Array.from(phase1Checkboxes).map(cb => cb.checked),
                phase2: Array.from(phase2Checkboxes).map(cb => cb.checked),
                phase3: Array.from(phase3Checkboxes).map(cb => cb.checked)
            };
            
            localStorage.setItem('migration_automation_progress', JSON.stringify(progress));
            
            // Update progress counter
            const allCheckboxes = [...phase1Checkboxes, ...phase2Checkboxes, ...phase3Checkboxes];
            const checkedCount = allCheckboxes.filter(cb => cb.checked).length;
            const progressEl = document.getElementById('automation-progress');
            if (progressEl) {
                progressEl.textContent = checkedCount + '/' + allCheckboxes.length;
            }
        }
        
        // Load automation checklist progress from localStorage
        function loadAutomationProgress() {
            const saved = localStorage.getItem('migration_automation_progress');
            if (!saved) return;
            
            try {
                const progress = JSON.parse(saved);
                
                const phase1Checkboxes = document.querySelectorAll('#auto-phase1 input[type="checkbox"]');
                const phase2Checkboxes = document.querySelectorAll('#auto-phase2 input[type="checkbox"]');
                const phase3Checkboxes = document.querySelectorAll('#auto-phase3 input[type="checkbox"]');
                
                if (progress.phase1) {
                    phase1Checkboxes.forEach((cb, i) => {
                        if (progress.phase1[i]) cb.checked = true;
                    });
                }
                if (progress.phase2) {
                    phase2Checkboxes.forEach((cb, i) => {
                        if (progress.phase2[i]) cb.checked = true;
                    });
                }
                if (progress.phase3) {
                    phase3Checkboxes.forEach((cb, i) => {
                        if (progress.phase3[i]) cb.checked = true;
                    });
                }
                
                // Update progress counter after loading
                const allCheckboxes = [...phase1Checkboxes, ...phase2Checkboxes, ...phase3Checkboxes];
                const checkedCount = allCheckboxes.filter(cb => cb.checked).length;
                const progressEl = document.getElementById('automation-progress');
                if (progressEl) {
                    progressEl.textContent = checkedCount + '/' + allCheckboxes.length;
                }
            } catch (e) {
                console.error('Failed to load automation progress:', e);
            }
        }
        
        // Save permissions checklist progress to localStorage
        function savePermissionsProgress() {
            const permCheckboxes = document.querySelectorAll('#perm-perms input[type="checkbox"]');
            const workflowCheckboxes = document.querySelectorAll('#perm-workflow input[type="checkbox"]');
            const screenCheckboxes = document.querySelectorAll('#perm-screens input[type="checkbox"]');
            
            const progress = {
                permissions: Array.from(permCheckboxes).map(cb => cb.checked),
                workflow: Array.from(workflowCheckboxes).map(cb => cb.checked),
                screens: Array.from(screenCheckboxes).map(cb => cb.checked)
            };
            
            localStorage.setItem('migration_permissions_progress', JSON.stringify(progress));
            
            // Update progress counter
            const allCheckboxes = [...permCheckboxes, ...workflowCheckboxes, ...screenCheckboxes];
            const checkedCount = allCheckboxes.filter(cb => cb.checked).length;
            const progressEl = document.getElementById('permissions-progress');
            if (progressEl) {
                progressEl.textContent = checkedCount + '/' + allCheckboxes.length;
            }
        }
        
        // Load permissions checklist progress from localStorage
        function loadPermissionsProgress() {
            const saved = localStorage.getItem('migration_permissions_progress');
            if (!saved) return;
            
            try {
                const progress = JSON.parse(saved);
                
                const permCheckboxes = document.querySelectorAll('#perm-perms input[type="checkbox"]');
                const workflowCheckboxes = document.querySelectorAll('#perm-workflow input[type="checkbox"]');
                const screenCheckboxes = document.querySelectorAll('#perm-screens input[type="checkbox"]');
                
                if (progress.permissions) {
                    permCheckboxes.forEach((cb, i) => {
                        if (progress.permissions[i]) cb.checked = true;
                    });
                }
                if (progress.workflow) {
                    workflowCheckboxes.forEach((cb, i) => {
                        if (progress.workflow[i]) cb.checked = true;
                    });
                }
                if (progress.screens) {
                    screenCheckboxes.forEach((cb, i) => {
                        if (progress.screens[i]) cb.checked = true;
                    });
                }
                
                // Update progress counter after loading
                const allCheckboxes = [...permCheckboxes, ...workflowCheckboxes, ...screenCheckboxes];
                const checkedCount = allCheckboxes.filter(cb => cb.checked).length;
                const progressEl = document.getElementById('permissions-progress');
                if (progressEl) {
                    progressEl.textContent = checkedCount + '/' + allCheckboxes.length;
                }
            } catch (e) {
                console.error('Failed to load permissions progress:', e);
            }
        }
        
        // Load all checklist progress on page load
        setTimeout(function() {
            loadAutomationProgress();
            loadPermissionsProgress();
        }, 100);
    </script>
</body>
</html>
"@
    
    return $html
}

function Update-UnifiedDashboard {
    param(
        [string]$ProjectKey,
        [string]$ProjectName,
        [string]$DashboardPath,
        [string]$OutDir,
        [string]$Mode = "Interactive"
    )
    
    # Load parameters.json to get Jira base URLs
    $sourceBase = ""
    $targetBase = ""
    $sourceProjectKey = ""
    $targetProjectKey = ""
    
    $projectDir = Split-Path $OutDir -Parent
    $paramsFile = Join-Path $projectDir "parameters.json"
    
    if (Test-Path $paramsFile) {
        try {
            $params = Get-Content $paramsFile -Raw | ConvertFrom-Json
            if ($params.PSObject.Properties['SourceEnvironment'] -and $params.SourceEnvironment.PSObject.Properties['BaseUrl']) {
                $sourceBase = $params.SourceEnvironment.BaseUrl -replace '/$', ''
            }
            if ($params.PSObject.Properties['TargetEnvironment'] -and $params.TargetEnvironment.PSObject.Properties['BaseUrl']) {
                $targetBase = $params.TargetEnvironment.BaseUrl -replace '/$', ''
            }
            if ($params.PSObject.Properties['ProjectKey']) {
                $sourceProjectKey = $params.ProjectKey
            }
            if ($params.PSObject.Properties['TargetEnvironment'] -and $params.TargetEnvironment.PSObject.Properties['ProjectKey']) {
                $targetProjectKey = $params.TargetEnvironment.ProjectKey
            }
        } catch {
            Write-Warning "Could not load parameters.json: $_"
        }
    }
    
    # Scan for completed steps
    $stepStatuses = @{}
    $stepReceipts = @{}
    $stepReceiptPaths = @{}
    foreach ($stepNum in $script:AllMigrationSteps.Keys) {
        $stepStatuses[$stepNum] = Get-StepStatus -StepNumber $stepNum -OutDir $OutDir
        
        # Load receipt data for completed steps
        if ($stepStatuses[$stepNum] -eq "completed") {
            $receiptPattern = "${stepNum}_*_receipt.json"
            $receiptFiles = Get-ChildItem -Path $OutDir -Filter $receiptPattern -ErrorAction SilentlyContinue
            if ($receiptFiles) {
                try {
                    $receiptContent = Get-Content $receiptFiles[0].FullName -Raw | ConvertFrom-Json
                    $stepReceipts[$stepNum] = $receiptContent
                    $stepReceiptPaths[$stepNum] = $receiptFiles[0].FullName
                } catch {
                    # If receipt can't be loaded, ignore
                }
            }
        }
    }
    
    # Count stats
    $totalSteps = $script:AllMigrationSteps.Keys.Count
    $completed = ($stepStatuses.Values | Where-Object { $_ -eq "completed" }).Count
    $pending = $totalSteps - $completed
    $progress = [math]::Round(($completed / $totalSteps) * 100)
    
    # Build steps HTML with expandable sections
    $stepsHtml = ""
    foreach ($stepNum in $script:AllMigrationSteps.Keys) {
        $stepName = $script:AllMigrationSteps[$stepNum]
        $status = $stepStatuses[$stepNum]
        
        $stepClass = $status
        $statusLabel = switch ($status) {
            "completed" { "Completed ✓" }
            "running" { "Running..." }
            "failed" { "Failed ✗" }
            default { "Pending" }
        }
        $statusClass = "status-$status"
        
        # Build expandable details section if step is completed
        $detailsHtml = ""
        if ($status -eq "completed" -and $stepReceipts.Contains($stepNum)) {
            $receipt = $stepReceipts[$stepNum]
            $receiptPath = if ($stepReceiptPaths.Contains($stepNum)) { $stepReceiptPaths[$stepNum] } else { "" }
            
            # Generate formatted summary with Jira URLs
            $summaryHtml = Format-ReceiptSummary -Receipt $receipt -StepNumber $stepNum `
                -SourceBase $sourceBase -TargetBase $targetBase `
                -SourceProjectKey $sourceProjectKey -TargetProjectKey $targetProjectKey `
                -ReceiptPath $receiptPath
            
            if ($summaryHtml) {
                $detailsHtml = @"
                <div class="step-details">
                    <div class="step-summary">
                        $summaryHtml
                    </div>
                </div>
"@
            }
        }
        
        # Add expand icon if there are details
        $expandIcon = if ($detailsHtml) { '<span class="expand-icon">▼</span>' } else { '' }
        
        $stepsHtml += @"
            <div class="step $stepClass" onclick="toggleStepDetails(this)">
                <div class="step-header">
                    <div class="checkbox"></div>
                    <span class="step-number">Step $stepNum</span>
                    <span class="step-title">$stepName</span>
                    <span class="step-status $statusClass">$statusLabel</span>
                    $expandIcon
                </div>
                $detailsHtml
            </div>
"@
    }
    
    # Create or update dashboard
    $html = New-UnifiedDashboard -ProjectName $ProjectName -ProjectKey $ProjectKey -Mode $Mode
    
    # Replace placeholders
    $html = $html -replace '<div class="steps" id="stepsList">[\s\S]*?</div>\s*<div class="footer">', @"
<div class="steps" id="stepsList">
$stepsHtml
        </div>
        <div class="footer">
"@
    
    $html = $html -replace 'style="width: [-\d]+%"', "style=`"width: $progress%`""
    $html = $html -replace '<div class="stat-value" id="completedCount">[-\d]+</div>', "<div class=`"stat-value`" id=`"completedCount`">$completed</div>"
    $html = $html -replace '<div class="stat-value" id="pendingCount">[-\d]+</div>', "<div class=`"stat-value`" id=`"pendingCount`">$pending</div>"
    $html = $html -replace '<div class="stat-value" id="percentComplete">[-\d]+%</div>', "<div class=`"stat-value`" id=`"percentComplete`">$progress%</div>"
    
    # Ensure output directory exists
    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    
    # Write dashboard
    $html | Out-File -FilePath $DashboardPath -Encoding UTF8 -Force
}

