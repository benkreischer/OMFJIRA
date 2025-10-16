# =============================================================================
# GET CROSS-PROJECT LINK COUNTS - UNRESOLVED ISSUES
# =============================================================================
#
# PURPOSE: Get count of unresolved issues with cross-project links
# OUTPUT: SourceProject, LinkedProject, UnresolvedCount, ResolvedCount (bonus)
#
# =============================================================================

# Load helper functions
$HelperPath = Join-Path $PSScriptRoot "..\Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

# Get parameters
$Params = Get-EndpointParameters -ParametersPath (Join-Path $PSScriptRoot "..\endpoints-parameters.json")
$BaseUrl = $Params.BaseUrl
$Headers = Get-RequestHeaders -Parameters $Params
$Headers["Accept"] = "application/json"

Write-Host "=== CROSS-PROJECT LINK ANALYSIS - UNRESOLVED ISSUES ===" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host ""

try {
    # =============================================================================
    # PHASE 1: GET ALL ACTIVE PROJECTS
    # =============================================================================
    Write-Host "PHASE 1: Getting active projects..." -ForegroundColor Cyan
    
    $ProjectsUrl = "$BaseUrl/rest/api/3/project"
    $AllProjects = @()
    $StartAt = 0
    $MaxResults = 100
    
    do {
        $ProjectUrlWithParams = "${ProjectsUrl}?maxResults=$MaxResults&startAt=$StartAt"
        $ProjectResponse = Invoke-RestMethod -Uri $ProjectUrlWithParams -Method Get -Headers $Headers
        
        if ($ProjectResponse -is [array]) {
            $AllProjects += $ProjectResponse
            $HasMore = $ProjectResponse.Count -eq $MaxResults
        } else {
            $HasMore = $false
        }
        
        $StartAt += $MaxResults
    } while ($HasMore)
    
    $ActiveProjects = $AllProjects | Where-Object { -not $_.archived }
    Write-Host "  Found $($ActiveProjects.Count) active projects" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 2: GET UNRESOLVED ISSUES WITH LINKS (Enhanced JQL + Bulk Fetch)
    # =============================================================================
    Write-Host "PHASE 2: Getting unresolved issues with links..." -ForegroundColor Cyan
    
    $SearchUrl = "$BaseUrl/rest/api/3/search/jql"
    $JqlQuery = 'resolution IS EMPTY AND issueLink IS NOT EMPTY AND created >= "2020-01-01" ORDER BY created DESC'
    
    Write-Host "  JQL: $JqlQuery" -ForegroundColor Gray
    
    $AllIssueIds = @()
    $NextPageToken = $null
    $PageCount = 0
    
    do {
        $PageCount++
        Write-Host "  Fetching page $PageCount..." -ForegroundColor Gray
        
        $Payload = @{
            jql = $JqlQuery
            maxResults = 100
        }
        
        if ($NextPageToken) {
            $Payload.nextPageToken = $NextPageToken
        }
        
        $PayloadJson = $Payload | ConvertTo-Json -Depth 10
        $Response = Invoke-RestMethod -Uri $SearchUrl -Method Post -Headers $Headers -Body $PayloadJson -ContentType "application/json"
        
        Write-Host "    Retrieved $($Response.issues.Count) issues" -ForegroundColor Gray
        
        foreach ($issue in $Response.issues) {
            $AllIssueIds += $issue.id
        }
        
        if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
            $NextPageToken = $Response.nextPageToken
        } else {
            $NextPageToken = $null
        }
        
    } while ($NextPageToken -ne $null)
    
    Write-Host "  Collected $($AllIssueIds.Count) unresolved issue IDs with links" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 3: GET ISSUE DETAILS USING BULK FETCH API
    # =============================================================================
    Write-Host "PHASE 3: Getting issue details with links..." -ForegroundColor Cyan
    
    $BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"
    $BatchSize = 100
    
    # Create batches
    $IssueBatches = @()
    for ($i = 0; $i -lt $AllIssueIds.Count; $i += $BatchSize) {
        $Batch = $AllIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $AllIssueIds.Count - 1))]
        $IssueBatches += ,$Batch
    }
    
    Write-Host "  Processing $($IssueBatches.Count) batches of $BatchSize issues each..." -ForegroundColor Gray
    
    $AllIssueDetails = @()
    
    for ($batchIndex = 0; $batchIndex -lt $IssueBatches.Count; $batchIndex++) {
        $Batch = $IssueBatches[$batchIndex]
        Write-Host "  Processing batch $($batchIndex + 1)/$($IssueBatches.Count)..." -ForegroundColor Gray
        
        $BulkPayload = @{
            fields = @("key", "project", "issuelinks", "status")
            issueIdsOrKeys = $Batch
        }
        
        $BulkPayloadJson = $BulkPayload | ConvertTo-Json -Depth 10
        
        try {
            $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $Headers -Body $BulkPayloadJson -ContentType "application/json"
            $AllIssueDetails += $BulkResponse.issues
        } catch {
            Write-Warning "  Failed to fetch batch $($batchIndex + 1): $($_.Exception.Message)"
            continue
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host "  Retrieved $($AllIssueDetails.Count) issue details" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 4: PROCESS CROSS-PROJECT LINKS
    # =============================================================================
    Write-Host "PHASE 4: Analyzing cross-project links..." -ForegroundColor Cyan
    
    $CrossProjectLinks = @()
    
    foreach ($issue in $AllIssueDetails) {
        if (-not $issue.fields.issuelinks -or $issue.fields.issuelinks.Count -eq 0) {
            continue
        }
        
        $SourceProject = if ($issue.fields.project) { $issue.fields.project.key } else { "" }
        if (-not $SourceProject) { continue }
        
        foreach ($link in $issue.fields.issuelinks) {
            $LinkedIssueKey = $null
            
            if ($link.inwardIssue -and $link.inwardIssue.key) {
                $LinkedIssueKey = $link.inwardIssue.key
            } elseif ($link.outwardIssue -and $link.outwardIssue.key) {
                $LinkedIssueKey = $link.outwardIssue.key
            }
            
            if ($LinkedIssueKey) {
                $LinkedProject = ($LinkedIssueKey -split '-')[0]
                
                # Only count cross-project links
                if ($LinkedProject -and $LinkedProject -ne $SourceProject) {
                    $CrossProjectLinks += [PSCustomObject]@{
                        SourceProject = $SourceProject
                        LinkedProject = $LinkedProject
                        IssueKey = $issue.key
                        LinkedIssueKey = $LinkedIssueKey
                        Status = if ($issue.fields.status) { $issue.fields.status.name } else { "Unknown" }
                    }
                }
            }
        }
    }
    
    Write-Host "  Found $($CrossProjectLinks.Count) cross-project link relationships" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 5: AGGREGATE COUNTS BY PROJECT PAIR
    # =============================================================================
    Write-Host "PHASE 5: Aggregating counts..." -ForegroundColor Cyan
    
    $AggregatedLinks = $CrossProjectLinks | 
        Group-Object @{Expression={"{0}|{1}" -f $_.SourceProject, $_.LinkedProject}} |
        ForEach-Object {
            $parts = $_.Name -split '\|'
            [PSCustomObject]@{
                SourceProject = $parts[0]
                LinkedProject = $parts[1]
                UnresolvedCount = $_.Count
            }
        } | Sort-Object SourceProject, LinkedProject
    
    Write-Host "  Created $($AggregatedLinks.Count) unique project-pair relationships" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 6: GET RESOLVED COUNTS (BONUS DATA)
    # =============================================================================
    Write-Host "PHASE 6: Getting resolved counts (bonus)..." -ForegroundColor Cyan
    
    $ResolvedJqlQuery = 'resolution IS NOT EMPTY AND issueLink IS NOT EMPTY AND created >= "2020-01-01" ORDER BY created DESC'
    Write-Host "  JQL: $ResolvedJqlQuery" -ForegroundColor Gray
    
    $ResolvedIssueIds = @()
    $NextPageToken = $null
    $PageCount = 0
    
    do {
        $PageCount++
        Write-Host "  Fetching page $PageCount..." -ForegroundColor Gray
        
        $Payload = @{
            jql = $ResolvedJqlQuery
            maxResults = 100
        }
        
        if ($NextPageToken) {
            $Payload.nextPageToken = $NextPageToken
        }
        
        $PayloadJson = $Payload | ConvertTo-Json -Depth 10
        $Response = Invoke-RestMethod -Uri $SearchUrl -Method Post -Headers $Headers -Body $PayloadJson -ContentType "application/json"
        
        Write-Host "    Retrieved $($Response.issues.Count) issues" -ForegroundColor Gray
        
        foreach ($issue in $Response.issues) {
            $ResolvedIssueIds += $issue.id
        }
        
        if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
            $NextPageToken = $Response.nextPageToken
        } else {
            $NextPageToken = $null
        }
        
    } while ($NextPageToken -ne $null)
    
    Write-Host "  Collected $($ResolvedIssueIds.Count) resolved issue IDs with links" -ForegroundColor Green
    
    # Get resolved issue details
    $ResolvedBatches = @()
    for ($i = 0; $i -lt $ResolvedIssueIds.Count; $i += $BatchSize) {
        $Batch = $ResolvedIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $ResolvedIssueIds.Count - 1))]
        $ResolvedBatches += ,$Batch
    }
    
    Write-Host "  Processing $($ResolvedBatches.Count) batches..." -ForegroundColor Gray
    
    $ResolvedIssueDetails = @()
    
    for ($batchIndex = 0; $batchIndex -lt $ResolvedBatches.Count; $batchIndex++) {
        $Batch = $ResolvedBatches[$batchIndex]
        Write-Host "  Processing batch $($batchIndex + 1)/$($ResolvedBatches.Count)..." -ForegroundColor Gray
        
        $BulkPayload = @{
            fields = @("key", "project", "issuelinks")
            issueIdsOrKeys = $Batch
        }
        
        $BulkPayloadJson = $BulkPayload | ConvertTo-Json -Depth 10
        
        try {
            $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $Headers -Body $BulkPayloadJson -ContentType "application/json"
            $ResolvedIssueDetails += $BulkResponse.issues
        } catch {
            Write-Warning "  Failed to fetch batch $($batchIndex + 1): $($_.Exception.Message)"
            continue
        }
        
        Start-Sleep -Milliseconds 100
    }
    
    # Process resolved links
    $ResolvedCrossProjectLinks = @()
    
    foreach ($issue in $ResolvedIssueDetails) {
        if (-not $issue.fields.issuelinks -or $issue.fields.issuelinks.Count -eq 0) {
            continue
        }
        
        $SourceProject = if ($issue.fields.project) { $issue.fields.project.key } else { "" }
        if (-not $SourceProject) { continue }
        
        foreach ($link in $issue.fields.issuelinks) {
            $LinkedIssueKey = $null
            
            if ($link.inwardIssue -and $link.inwardIssue.key) {
                $LinkedIssueKey = $link.inwardIssue.key
            } elseif ($link.outwardIssue -and $link.outwardIssue.key) {
                $LinkedIssueKey = $link.outwardIssue.key
            }
            
            if ($LinkedIssueKey) {
                $LinkedProject = ($LinkedIssueKey -split '-')[0]
                
                if ($LinkedProject -and $LinkedProject -ne $SourceProject) {
                    $ResolvedCrossProjectLinks += [PSCustomObject]@{
                        SourceProject = $SourceProject
                        LinkedProject = $LinkedProject
                    }
                }
            }
        }
    }
    
    # Aggregate resolved counts
    $ResolvedCounts = @{}
    foreach ($link in $ResolvedCrossProjectLinks) {
        $key = "$($link.SourceProject)|$($link.LinkedProject)"
        if (-not $ResolvedCounts.ContainsKey($key)) {
            $ResolvedCounts[$key] = 0
        }
        $ResolvedCounts[$key]++
    }
    
    # =============================================================================
    # PHASE 7: COMBINE RESULTS
    # =============================================================================
    Write-Host "PHASE 7: Combining results..." -ForegroundColor Cyan
    
    $FinalResults = @()
    
    foreach ($link in $AggregatedLinks) {
        $key = "$($link.SourceProject)|$($link.LinkedProject)"
        $resolvedCount = if ($ResolvedCounts.ContainsKey($key)) { $ResolvedCounts[$key] } else { 0 }
        
        $FinalResults += [PSCustomObject]@{
            SourceProject = $link.SourceProject
            LinkedProject = $link.LinkedProject
            UnresolvedCount = $link.UnresolvedCount
            ResolvedCount = $resolvedCount
            TotalLinks = $link.UnresolvedCount + $resolvedCount
        }
    }
    
    # Also add any resolved-only pairs
    foreach ($key in $ResolvedCounts.Keys) {
        $parts = $key -split '\|'
        $existingLink = $FinalResults | Where-Object { $_.SourceProject -eq $parts[0] -and $_.LinkedProject -eq $parts[1] }
        
        if (-not $existingLink) {
            $FinalResults += [PSCustomObject]@{
                SourceProject = $parts[0]
                LinkedProject = $parts[1]
                UnresolvedCount = 0
                ResolvedCount = $ResolvedCounts[$key]
                TotalLinks = $ResolvedCounts[$key]
            }
        }
    }
    
    $FinalResults = $FinalResults | Sort-Object SourceProject, LinkedProject
    
    # =============================================================================
    # EXPORT RESULTS
    # =============================================================================
    Write-Host "PHASE 8: Exporting results..." -ForegroundColor Cyan
    
    $OutputFile = "Cross-Project-Link-Counts.csv"
    $FinalResults | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Results exported to: $((Get-Location).Path)\$OutputFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Total active projects: $($ActiveProjects.Count)" -ForegroundColor White
    Write-Host "Unresolved issues with links: $($AllIssueDetails.Count)" -ForegroundColor White
    Write-Host "Resolved issues with links: $($ResolvedIssueDetails.Count)" -ForegroundColor White
    Write-Host "Unique cross-project relationships: $($FinalResults.Count)" -ForegroundColor White
    Write-Host "Total unresolved cross-project links: $(($FinalResults | Measure-Object -Property UnresolvedCount -Sum).Sum)" -ForegroundColor Yellow
    Write-Host "Total resolved cross-project links: $(($FinalResults | Measure-Object -Property ResolvedCount -Sum).Sum)" -ForegroundColor Green
    Write-Host ""
    Write-Host "=== TOP 20 CROSS-PROJECT RELATIONSHIPS (by unresolved count) ===" -ForegroundColor Cyan
    $FinalResults | Sort-Object UnresolvedCount -Descending | Select-Object -First 20 | Format-Table -AutoSize
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

