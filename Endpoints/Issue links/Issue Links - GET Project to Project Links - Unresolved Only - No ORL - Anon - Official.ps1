# =============================================================================
# ENDPOINT: Issue Links - GET Project to Project Links (Unresolved Only, No ORL)
# =============================================================================
#
# DESCRIPTION: Returns a summary showing EVERY project key and all the project
# keys it's linked to through issue links, but ONLY for unresolved issues.
# Excludes ORL project and all its links. Shows ALL projects, including
# those with 0 links, plus their active/archived status.
#
# OUTPUT COLUMNS:
# - ProjectKey: The main project key
# - ProjectStatus: Whether the project is Active or Archived
# - LinkedProjectKeys: Semicolon-separated list of project keys linked to this project
# - LinkCount: Number of unique projects this project is linked to
# - GeneratedAt: Timestamp when data was generated
#
# SETUP:
# 1. Run this script in PowerShell
# 2. Ensure you have internet connectivity to reach Jira
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path $PSScriptRoot "Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

# =============================================================================
# LOAD CONFIGURATION PARAMETERS
# =============================================================================
$Params = Get-EndpointParameters

# =============================================================================

# =============================================================================
# LOAD REQUIRED ASSEMBLIES
# =============================================================================
Add-Type -AssemblyName System.Web


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


    # =============================================================================
    # PHASE 1: GET ALL PROJECTS FROM JIRA WITH STATUS
    # =============================================================================
    Write-Output "PHASE 1: Getting ALL projects from Jira with status..."

    $ProjectsUrl = "$BaseUrl/rest/api/3/project"
    $AllProjects = @()
    $ProjectStartAt = 0
    $ProjectMaxResults = 100

    do {
        Write-Output "  Fetching projects batch starting at $ProjectStartAt..."

        $ProjectUrlWithParams = "$ProjectsUrl" + "?maxResults=$ProjectMaxResults&startAt=$ProjectStartAt"

        try {
            $ProjectResponse = Invoke-RestMethod -Uri $ProjectUrlWithParams -Method Get -Headers $AuthHeader

            if ($ProjectResponse -is [array]) {
                Write-Output "    Retrieved $($ProjectResponse.Count) projects"
                $AllProjects += $ProjectResponse
                $HasMoreProjects = $ProjectResponse.Count -eq $ProjectMaxResults
            } else {
                Write-Output "    Retrieved 0 projects (unexpected response format)"
                $HasMoreProjects = $false
            }

            $ProjectStartAt += $ProjectMaxResults

        } catch {
            Write-Output "    Failed to fetch projects batch: $($_.Exception.Message)"
            break
        }

    } while ($HasMoreProjects)

    Write-Output "PHASE 1 COMPLETE: Found $($AllProjects.Count) total projects"

    # =============================================================================
    # PHASE 1.5: BUILD JQL QUERY FOR ALL ACTIVE PROJECTS (EXCLUDING ORL)
    # =============================================================================
    Write-Output "PHASE 1.5: Building JQL query for all active projects (excluding ORL)..."

    # Get only active projects for the query, excluding ORL
    $ActiveProjects = $AllProjects | Where-Object { -not $_.archived -and $_.key -ne "ORL" }
    $ActiveProjectKeys = $ActiveProjects | ForEach-Object { $_.key }

    Write-Output "  Found $($ActiveProjects.Count) active projects to analyze (ORL excluded)"
    Write-Output "  Excluded ORL project from analysis"

    # Build JQL query with all active project keys (JQL has limits, so we may need to batch)
    $MaxProjectsPerQuery = 50  # Conservative limit to avoid JQL query length issues

    # =============================================================================
    # PHASE 2: GET UNRESOLVED ISSUE IDS USING ENHANCED JQL API
    # =============================================================================
    Write-Output "PHASE 2: Getting UNRESOLVED issue IDs using Enhanced JQL API..."

    $SearchUrl = "$BaseUrl/rest/api/3/search/jql"
    $AllIssueIds = @()
    $NextPageToken = $null
    $MaxResults = $Params.ApiSettings.MaxResults

    # Create batches of projects for JQL queries
    $ProjectBatches = @()
    for ($i = 0; $i -lt $ActiveProjectKeys.Count; $i += $MaxProjectsPerQuery) {
        $end = [Math]::Min($i + $MaxProjectsPerQuery - 1, $ActiveProjectKeys.Count - 1)
        $ProjectBatches += ,($ActiveProjectKeys[$i..$end])
    }

    Write-Output "  Created $($ProjectBatches.Count) project batches for JQL queries"

    $TotalPages = 0

    # Process each batch of projects
    foreach ($batchIndex in 0..($ProjectBatches.Count - 1)) {
        $projectBatch = $ProjectBatches[$batchIndex]
        # Modified JQL to only get unresolved issues
        $JqlQuery = "project in (" + ($projectBatch -join ", ") + ") AND resolution is EMPTY ORDER BY project ASC, created DESC"

        Write-Output "  Processing project batch $($batchIndex + 1)/$($ProjectBatches.Count) with $($projectBatch.Count) projects..."
        Write-Output "    Projects: $($projectBatch -join ', ')"

        $NextPageToken = $null
        $batchPages = 0

        do {
            $TotalPages++
            $batchPages++
            Write-Output "    Fetching page $batchPages for batch $($batchIndex + 1) (unresolved issues only)..."

            # Build payload for Enhanced JQL API - get IDs for bulk fetch
            $Payload = @{
                jql = $JqlQuery
                maxResults = $MaxResults
            }

            if ($NextPageToken) {
                $Payload.nextPageToken = $NextPageToken
            }

            $PayloadJson = $Payload | ConvertTo-Json -Depth 10

            try {
                $Response = Invoke-RestMethod -Uri $SearchUrl -Method Post -Headers $AuthHeader -Body $PayloadJson

                Write-Output "      Retrieved $($Response.issues.Count) unresolved issues from page $batchPages"

                # Extract issue IDs (Enhanced JQL API returns minimal data for performance)
                foreach ($issue in $Response.issues) {
                    $AllIssueIds += $issue.id
                }

                Write-Output "      Total unresolved issue IDs collected: $($AllIssueIds.Count)"

                # Check for next page token
                if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
                    $NextPageToken = $Response.nextPageToken
                    Write-Output "      Next page token found, continuing..."
                } else {
                    $NextPageToken = $null
                    Write-Output "      No next page token, batch complete"
                }

            } catch {
                Write-Output "      Failed to fetch page $batchPages for batch $($batchIndex + 1): $($_.Exception.Message)"
                break
            }

        } while ($NextPageToken -ne $null)

        Write-Output "    Batch $($batchIndex + 1) complete: collected $($AllIssueIds.Count) total unresolved issues so far"
    }

    Write-Output "PHASE 2 COMPLETE: Collected $($AllIssueIds.Count) unresolved issue IDs in $TotalPages pages"

    # =============================================================================
    # PHASE 3: GET ISSUE DETAILS USING BULK FETCH API
    # =============================================================================
    Write-Output "PHASE 3: Getting issue details using Bulk Fetch API..."

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
        Write-Output "  Processing batch $($batchIndex + 1)/$($IssueBatches.Count) with $($Batch.Count) issues..."

        $BulkPayload = @{
            fields = @("key", "project", "issuelinks")
            issueIdsOrKeys = $Batch
        }

        $BulkPayloadJson = $BulkPayload | ConvertTo-Json -Depth 10

        try {
            $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $AuthHeader -Body $BulkPayloadJson

            Write-Output "    Retrieved $($BulkResponse.issues.Count) issue details from batch $($batchIndex + 1)"

            $AllIssueDetails += $BulkResponse.issues

        } catch {
            Write-Output "    Failed to fetch batch $($batchIndex + 1): $($_.Exception.Message)"
            # Continue with next batch instead of breaking
            continue
        }

        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
    }

    Write-Output "PHASE 3 COMPLETE: Retrieved $($AllIssueDetails.Count) unresolved issues with links"

    # =============================================================================
    # PHASE 4: PROCESS DATA TO CREATE PROJECT-TO-PROJECT RELATIONSHIPS
    # =============================================================================
    Write-Output "PHASE 4: Processing data to create project-to-project relationships..."

    # Create project-to-project relationship summary
    $ProjectLinks = @{}

    # Initialize only ACTIVE projects with empty link arrays (excluding ORL)
    foreach ($project in $ActiveProjects) {
        $ProjectLinks[$project.key] = @()
    }

    # Process issues with links to populate relationships
    if ($AllIssueDetails -and $AllIssueDetails.Count -gt 0) {
        foreach ($issue in $AllIssueDetails) {
            if (-not $issue.fields.issuelinks -or $issue.fields.issuelinks.Count -eq 0) {
                continue
            }

            $IssueProjectKey = if ($issue.fields.project) { $issue.fields.project.key } else { "" }

            # Skip if this issue is from ORL project
            if ($IssueProjectKey -eq "ORL") {
                continue
            }

            if ($issue.fields.issuelinks -and $IssueProjectKey) {
                foreach ($link in $issue.fields.issuelinks) {
                    if ($link.inwardIssue -and $link.inwardIssue.key) {
                        $linkedProjectKey = ($link.inwardIssue.key -split '-')[0]
                        # Skip ORL links and self-links
                        if ($linkedProjectKey -and $linkedProjectKey -ne $IssueProjectKey -and $linkedProjectKey -ne "ORL") {
                            $ProjectLinks[$IssueProjectKey] += $linkedProjectKey
                        }
                    }
                    if ($link.outwardIssue -and $link.outwardIssue.key) {
                        $linkedProjectKey = ($link.outwardIssue.key -split '-')[0]
                        # Skip ORL links and self-links
                        if ($linkedProjectKey -and $linkedProjectKey -ne $IssueProjectKey -and $linkedProjectKey -ne "ORL") {
                            $ProjectLinks[$IssueProjectKey] += $linkedProjectKey
                        }
                    }
                }
            }
        }
    }

    # Create final result with ALL projects including status
    $Result = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    foreach ($projectKey in ($ProjectLinks.Keys | Sort-Object)) {
        $uniqueLinkedProjects = $ProjectLinks[$projectKey] | Sort-Object -Unique | Where-Object { $_ -ne "" -and $_ -ne "ORL" }

        # All projects in this result are active (we only initialized active projects, excluding ORL)
        $ProjectData = [PSCustomObject]@{
            ProjectKey = $projectKey
            ProjectStatus = "Active"
            LinkedProjectKeys = if ($uniqueLinkedProjects.Count -gt 0) { ($uniqueLinkedProjects -join "; ") } else { "" }
            LinkCount = $uniqueLinkedProjects.Count
            GeneratedAt = $timestamp
        }
        $Result += $ProjectData
    }

    # Export to CSV
    $OutputFile = "Issue Links - GET Project to Project Links - Unresolved Only - No ORL - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "SUCCESS: Generated CSV file: $(Get-Location)\$OutputFile"
    Write-Output ""
    Write-Output "SUMMARY:"
    Write-Output "  - Total projects in Jira: $($AllProjects.Count)"
    Write-Output "  - Active projects analyzed: $($ActiveProjects.Count) (ORL excluded)"
    Write-Output "  - Archived projects (excluded): $(($AllProjects | Where-Object { $_.archived }).Count)"
    Write-Output "  - ORL project (excluded): 1"
    Write-Output "  - Unresolved issues with links retrieved: $($AllIssueDetails.Count)"
    Write-Output "  - Active projects in final result: $($Result.Count)"
    Write-Output "  - Active projects with cross-project links: $(($Result | Where-Object { $_.LinkCount -gt 0 }).Count)"
    Write-Output "  - Active projects with zero links: $(($Result | Where-Object { $_.LinkCount -eq 0 }).Count)"
    Write-Output "  - Project batches processed: $($ProjectBatches.Count)"
    Write-Output "  - Pages processed for IDs: $TotalPages"
    Write-Output "  - Batches processed for details: $($IssueBatches.Count)"

    # Show project-to-project relationships summary
    if ($Result.Count -gt 0) {
        Write-Output ""
        Write-Output "Project-to-Project Links Summary (Unresolved Issues Only, No ORL) - Top 20:"
        Write-Output "=================================================================================="
        $Result | Sort-Object LinkCount -Descending | Select-Object -First 20 | Format-Table -AutoSize

        Write-Output ""
        Write-Output "Projects with most links (unresolved issues only, no ORL):"
        Write-Output "=========================================================="
        $TopLinked = $Result | Where-Object { $_.LinkCount -gt 0 } | Sort-Object LinkCount -Descending | Select-Object -First 10
        foreach ($p in $TopLinked) {
            Write-Output "  $($p.ProjectKey) ($($p.ProjectStatus)): $($p.LinkCount) links - $($p.LinkedProjectKeys)"
        }
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    exit 1
}

