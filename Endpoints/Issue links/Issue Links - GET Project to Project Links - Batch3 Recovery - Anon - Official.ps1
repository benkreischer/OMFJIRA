# =============================================================================
# ENDPOINT: Issue Links - GET Project to Project Links - Batch 3 Recovery (Official)
# =============================================================================
#
# DESCRIPTION: Recovers the 50 projects that failed in batch 3 by processing
# them in smaller batches of 10 projects each to avoid JQL query length limits.
# Results will be merged with the main analysis.
#
# FAILED PROJECTS FROM BATCH 3:
# MOD, DOC, OBSRV, OBE, SIGN, ONE, OPSAN, ORL, PAN, SRE, PLOS, PLAT, CENG,
# DCI, TOCA, MES, PIE, EDME, POP, PLAQ, POS, PE, CBRE, CAD, HRES, CONT, LAW,
# RC, REM, SCOF, SCON, SE, NOW, SHP, STNRD, STAN, DBEAN, SVCCOL, COL, CTGR,
# MOB, SEN, OAE, TCA, TAM, TOKR, OSO, TOEP, CCT, TO
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


    # =============================================================================
    # DEFINE FAILED BATCH 3 PROJECTS
    # =============================================================================
    $FailedProjectKeys = @(
        "MOD", "DOC", "OBSRV", "OBE", "SIGN", "ONE", "OPSAN", "ORL", "PAN", "SRE",
        "PLOS", "PLAT", "CENG", "DCI", "TOCA", "MES", "PIE", "EDME", "POP", "PLAQ",
        "POS", "PE", "CBRE", "CAD", "HRES", "CONT", "LAW", "RC", "REM", "SCOF",
        "SCON", "SE", "NOW", "SHP", "STNRD", "STAN", "DBEAN", "SVCCOL", "COL", "CTGR",
        "MOB", "SEN", "OAE", "TCA", "TAM", "TOKR", "OSO", "TOEP", "CCT", "TO"
    )

    Write-Output "RECOVERY: Processing $($FailedProjectKeys.Count) failed projects from batch 3..."

    # =============================================================================
    # CREATE SMALLER BATCHES (10 PROJECTS EACH TO AVOID JQL LIMITS)
    # =============================================================================
    $MaxProjectsPerBatch = 10  # Much smaller to avoid JQL query issues
    $ProjectBatches = @()

    for ($i = 0; $i -lt $FailedProjectKeys.Count; $i += $MaxProjectsPerBatch) {
        $end = [Math]::Min($i + $MaxProjectsPerBatch - 1, $FailedProjectKeys.Count - 1)
        $ProjectBatches += ,($FailedProjectKeys[$i..$end])
    }

    Write-Output "RECOVERY: Created $($ProjectBatches.Count) smaller project batches for JQL queries"

    # =============================================================================
    # PHASE 1: GET ISSUE IDs FOR FAILED PROJECTS USING ENHANCED JQL API
    # =============================================================================
    Write-Output "RECOVERY PHASE 1: Getting issue IDs for failed projects..."

    $SearchUrl = "$BaseUrl/rest/api/3/search/jql"
    $AllIssueIds = @()
    $TotalPages = 0

    # Process each batch of projects
    foreach ($batchIndex in 0..($ProjectBatches.Count - 1)) {
        $projectBatch = $ProjectBatches[$batchIndex]
        $JqlQuery = "project in (" + ($projectBatch -join ", ") + ") ORDER BY project ASC, created DESC"

        Write-Output "  Processing recovery batch $($batchIndex + 1)/$($ProjectBatches.Count) with $($projectBatch.Count) projects..."
        Write-Output "    Projects: $($projectBatch -join ', ')"

        $NextPageToken = $null
        $batchPages = 0

        do {
            $TotalPages++
            $batchPages++
            Write-Output "    Fetching page $batchPages for recovery batch $($batchIndex + 1)..."

            # Build payload for Enhanced JQL API
            $Payload = @{
                jql = $JqlQuery
                maxResults = 1000
            }

            if ($NextPageToken) {
                $Payload.nextPageToken = $NextPageToken
            }

            $PayloadJson = $Payload | ConvertTo-Json -Depth 10

            try {
                $Response = Invoke-RestMethod -Uri $SearchUrl -Method Post -Headers $AuthHeader -Body $PayloadJson

                Write-Output "      Retrieved $($Response.issues.Count) issues from page $batchPages"

                # Extract issue IDs
                foreach ($issue in $Response.issues) {
                    $AllIssueIds += $issue.id
                }

                Write-Output "      Total recovery issue IDs collected: $($AllIssueIds.Count)"

                # Check for next page token
                if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
                    $NextPageToken = $Response.nextPageToken
                    Write-Output "      Next page token found, continuing..."
                } else {
                    $NextPageToken = $null
                    Write-Output "      No next page token, batch complete"
                }

            } catch {
                Write-Output "      Failed to fetch page $batchPages for recovery batch $($batchIndex + 1): $($_.Exception.Message)"
                break
            }

        } while ($NextPageToken -ne $null)

        Write-Output "    Recovery batch $($batchIndex + 1) complete: collected $($AllIssueIds.Count) total issues so far"
    }

    Write-Output "RECOVERY PHASE 1 COMPLETE: Collected $($AllIssueIds.Count) issue IDs in $TotalPages pages"

    # =============================================================================
    # PHASE 2: GET ISSUE DETAILS USING BULK FETCH API
    # =============================================================================
    Write-Output "RECOVERY PHASE 2: Getting issue details using Bulk Fetch API..."

    $AllIssueDetails = @()
    $BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"
    $BatchSize = $Params.ApiSettings.BatchSize

    # Create batches of issue IDs
    $IssueBatches = @()
    for ($i = 0; $i -lt $AllIssueIds.Count; $i += $BatchSize) {
        $Batch = $AllIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $AllIssueIds.Count - 1))]
        $IssueBatches += ,$Batch  # Comma to create array of arrays
    }

    Write-Output "  Created $($IssueBatches.Count) batches of up to $BatchSize issues each"

    for ($batchIndex = 0; $batchIndex -lt $IssueBatches.Count; $batchIndex++) {
        $Batch = $IssueBatches[$batchIndex]
        Write-Output "  Processing recovery batch $($batchIndex + 1)/$($IssueBatches.Count) with $($Batch.Count) issues..."

        $BulkPayload = @{
            fields = @("key", "project", "issuelinks")
            issueIdsOrKeys = $Batch
        }

        $BulkPayloadJson = $BulkPayload | ConvertTo-Json -Depth 10

        try {
            $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $AuthHeader -Body $BulkPayloadJson

            Write-Output "    Retrieved $($BulkResponse.issues.Count) issue details from recovery batch $($batchIndex + 1)"

            $AllIssueDetails += $BulkResponse.issues

        } catch {
            Write-Output "    Failed to fetch recovery batch $($batchIndex + 1): $($_.Exception.Message)"
            continue
        }

        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
    }

    Write-Output "RECOVERY PHASE 2 COMPLETE: Retrieved $($AllIssueDetails.Count) issues with links"

    # =============================================================================
    # PHASE 3: PROCESS DATA TO CREATE PROJECT-TO-PROJECT RELATIONSHIPS
    # =============================================================================
    Write-Output "RECOVERY PHASE 3: Processing data to create project-to-project relationships..."

    # Create project-to-project relationship summary
    $ProjectLinks = @{}

    # Initialize failed projects with empty link arrays
    foreach ($projectKey in $FailedProjectKeys) {
        $ProjectLinks[$projectKey] = @()
    }

    # Process issues with links to populate relationships
    if ($AllIssueDetails -and $AllIssueDetails.Count -gt 0) {
        foreach ($issue in $AllIssueDetails) {
            if (-not $issue.fields.issuelinks -or $issue.fields.issuelinks.Count -eq 0) {
                continue
            }

            $IssueProjectKey = if ($issue.fields.project) { $issue.fields.project.key } else { "" }

            if ($issue.fields.issuelinks -and $IssueProjectKey) {
                foreach ($link in $issue.fields.issuelinks) {
                    if ($link.inwardIssue -and $link.inwardIssue.key) {
                        $linkedProjectKey = ($link.inwardIssue.key -split '-')[0]
                        if ($linkedProjectKey -and $linkedProjectKey -ne $IssueProjectKey) {
                            $ProjectLinks[$IssueProjectKey] += $linkedProjectKey
                        }
                    }
                    if ($link.outwardIssue -and $link.outwardIssue.key) {
                        $linkedProjectKey = ($link.outwardIssue.key -split '-')[0]
                        if ($linkedProjectKey -and $linkedProjectKey -ne $IssueProjectKey) {
                            $ProjectLinks[$IssueProjectKey] += $linkedProjectKey
                        }
                    }
                }
            }
        }
    }

    # Create final result for recovery projects
    $RecoveryResult = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    foreach ($projectKey in ($ProjectLinks.Keys | Sort-Object)) {
        $uniqueLinkedProjects = $ProjectLinks[$projectKey] | Sort-Object -Unique | Where-Object { $_ -ne "" }

        $ProjectData = [PSCustomObject]@{
            ProjectKey = $projectKey
            ProjectStatus = "Active"  # All projects in recovery batch are active
            LinkedProjectKeys = if ($uniqueLinkedProjects.Count -gt 0) { ($uniqueLinkedProjects -join "; ") } else { "" }
            LinkCount = $uniqueLinkedProjects.Count
            GeneratedAt = $timestamp
        }
        $RecoveryResult += $ProjectData
    }

    # Export recovery results to separate CSV
    $RecoveryOutputFile = "Issue Links - GET Project to Project Links - Batch3 Recovery - Anon - Official.csv"
    $RecoveryResult | Export-Csv -Path $RecoveryOutputFile -NoTypeInformation -Force

    Write-Output "SUCCESS: Generated recovery CSV file: $(Get-Location)\$RecoveryOutputFile"
    Write-Output ""
    Write-Output "RECOVERY SUMMARY:"
    Write-Output "  - Failed projects processed: $($FailedProjectKeys.Count)"
    Write-Output "  - Recovery project batches: $($ProjectBatches.Count)"
    Write-Output "  - Issues with links retrieved: $($AllIssueDetails.Count)"
    Write-Output "  - Projects in recovery result: $($RecoveryResult.Count)"
    Write-Output "  - Projects with cross-project links: $(($RecoveryResult | Where-Object { $_.LinkCount -gt 0 }).Count)"
    Write-Output "  - Projects with zero links: $(($RecoveryResult | Where-Object { $_.LinkCount -eq 0 }).Count)"

    # Show recovery project-to-project relationships summary
    if ($RecoveryResult.Count -gt 0) {
        Write-Output ""
        Write-Output "Recovery Project-to-Project Links Summary:"
        Write-Output "=========================================="
        $RecoveryResult | Sort-Object LinkCount -Descending | Format-Table -AutoSize

        Write-Output ""
        Write-Output "Recovery projects with most links:"
        Write-Output "================================="
        $TopLinked = $RecoveryResult | Where-Object { $_.LinkCount -gt 0 } | Sort-Object LinkCount -Descending | Select-Object -First 10
        foreach ($p in $TopLinked) {
            Write-Output "  $($p.ProjectKey) ($($p.ProjectStatus)): $($p.LinkCount) links - $($p.LinkedProjectKeys)"
        }
    }

    Write-Output ""
    Write-Output "NEXT STEP: Merge this recovery file with the main results when main analysis completes"

} catch {
    Write-Output "Recovery failed: $($_.Exception.Message)"
    exit 1
}
