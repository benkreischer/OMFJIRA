# =============================================================================
# GET ALL ISSUES WITH THEIR LINKS - SIMPLE FORMAT
# =============================================================================
#
# OUTPUT FORMAT:
# IssueKey, IssueStatus, LinkedIssueKey, LinkedIssueStatus
# AUTO-123, Unresolved, TRIM-456, Unresolved
# AUTO-123, Unresolved, TRIM-457, Resolved
# AUTO-200, Unresolved, (no link), NA
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

# Force TLS 1.2/1.3 for SSL connections
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Write-Host "=== GETTING ALL ISSUES WITH LINKS ===" -ForegroundColor Green
Write-Host "Base URL: $BaseUrl" -ForegroundColor Yellow
Write-Host ""

try {
    # =============================================================================
    # PHASE 1: GET ALL ISSUE IDS
    # =============================================================================
    Write-Host "PHASE 1: Getting all issue IDs..." -ForegroundColor Cyan
    
    $SearchUrl = "$BaseUrl/rest/api/3/search/jql"
    $JqlQuery = 'created >= "2020-01-01" ORDER BY created DESC'
    
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
        
        # Retry logic for SSL errors
        $maxRetries = 3
        $retryCount = 0
        $success = $false
        
        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                $Response = Invoke-RestMethod -Uri $SearchUrl -Method Post -Headers $Headers -Body $PayloadJson -ContentType "application/json" -TimeoutSec 60
                $success = $true
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "    Retry $retryCount/$maxRetries after error: $($_.Exception.Message)" -ForegroundColor Yellow
                    Start-Sleep -Seconds (5 * $retryCount)
                } else {
                    throw
                }
            }
        }
        
        Write-Host "    Retrieved $($Response.issues.Count) issues (Total: $($AllIssueIds.Count + $Response.issues.Count))" -ForegroundColor Gray
        
        foreach ($issue in $Response.issues) {
            $AllIssueIds += $issue.id
        }
        
        if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
            $NextPageToken = $Response.nextPageToken
        } else {
            $NextPageToken = $null
        }
        
        # Stop after getting enough for testing
        if ($AllIssueIds.Count -ge 10000 -and $PageCount % 10 -eq 0) {
            Write-Host "    Progress check: Collected $($AllIssueIds.Count) issues so far..." -ForegroundColor Yellow
        }
        
    } while ($NextPageToken -ne $null)
    
    Write-Host "  Collected $($AllIssueIds.Count) total issue IDs" -ForegroundColor Green
    
    # =============================================================================
    # PHASE 2: GET ISSUE DETAILS USING BULK FETCH API
    # =============================================================================
    Write-Host "PHASE 2: Getting issue details with Bulk Fetch API..." -ForegroundColor Cyan
    
    $BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"
    $BatchSize = 100
    
    # Create batches
    $IssueBatches = @()
    for ($i = 0; $i -lt $AllIssueIds.Count; $i += $BatchSize) {
        $Batch = $AllIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $AllIssueIds.Count - 1))]
        $IssueBatches += ,$Batch
    }
    
    Write-Host "  Processing $($IssueBatches.Count) batches..." -ForegroundColor Gray
    
    $Results = @()
    $OutputFile = "All-Issues-With-Links.csv"
    $TempOutputFile = "All-Issues-With-Links-TEMP.csv"
    
    # Remove old temp file if exists
    if (Test-Path $TempOutputFile) {
        Remove-Item $TempOutputFile -Force
    }
    
    for ($batchIndex = 0; $batchIndex -lt $IssueBatches.Count; $batchIndex++) {
        $Batch = $IssueBatches[$batchIndex]
        
        if ($batchIndex % 10 -eq 0) {
            Write-Host "  Processing batch $($batchIndex + 1)/$($IssueBatches.Count) - $(($Results.Count)) rows so far..." -ForegroundColor Yellow
        }
        
        $BulkPayload = @{
            fields = @("key", "status", "resolution", "issuelinks")
            issueIdsOrKeys = $Batch
        }
        
        $BulkPayloadJson = $BulkPayload | ConvertTo-Json -Depth 10
        
        # Retry logic for bulk fetch
        $maxRetries = 3
        $retryCount = 0
        $success = $false
        $BulkResponse = $null
        
        while (-not $success -and $retryCount -lt $maxRetries) {
            try {
                $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $Headers -Body $BulkPayloadJson -ContentType "application/json" -TimeoutSec 60
                $success = $true
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "    Batch $($batchIndex + 1) - Retry $retryCount/$maxRetries after error" -ForegroundColor Yellow
                    Start-Sleep -Seconds (10 * $retryCount)
                } else {
                    Write-Warning "  Failed to fetch batch $($batchIndex + 1) after $maxRetries retries: $($_.Exception.Message)"
                    continue
                }
            }
        }
        
        if ($BulkResponse) {
            
            # Process each issue immediately
            foreach ($issue in $BulkResponse.issues) {
                $issueKey = $issue.key
                $issueStatus = if ($issue.fields.resolution) { "Resolved" } else { "Unresolved" }
                
                # Check if issue has links
                if ($issue.fields.issuelinks -and $issue.fields.issuelinks.Count -gt 0) {
                    foreach ($link in $issue.fields.issuelinks) {
                        $linkedIssueKey = $null
                        $linkedIssueStatus = "Unknown"
                        
                        if ($link.inwardIssue) {
                            $linkedIssueKey = $link.inwardIssue.key
                            # Check if linked issue has status info
                            if ($link.inwardIssue.fields -and $link.inwardIssue.fields.status) {
                                $linkedIssueStatus = if ($link.inwardIssue.fields.status.statusCategory.key -eq "done") { "Resolved" } else { "Unresolved" }
                            }
                        } elseif ($link.outwardIssue) {
                            $linkedIssueKey = $link.outwardIssue.key
                            # Check if linked issue has status info
                            if ($link.outwardIssue.fields -and $link.outwardIssue.fields.status) {
                                $linkedIssueStatus = if ($link.outwardIssue.fields.status.statusCategory.key -eq "done") { "Resolved" } else { "Unresolved" }
                            }
                        }
                        
                        if ($linkedIssueKey) {
                            $Results += [PSCustomObject]@{
                                IssueKey = $issueKey
                                IssueStatus = $issueStatus
                                LinkedIssueKey = $linkedIssueKey
                                LinkedIssueStatus = $linkedIssueStatus
                            }
                        }
                    }
                } else {
                    # Issue has no links
                    $Results += [PSCustomObject]@{
                        IssueKey = $issueKey
                        IssueStatus = $issueStatus
                        LinkedIssueKey = "(no link)"
                        LinkedIssueStatus = "NA"
                    }
                }
            }
        }
        
        # Save progress every 100 batches
        if (($batchIndex + 1) % 100 -eq 0) {
            Write-Host "  Saving progress at batch $($batchIndex + 1)..." -ForegroundColor Cyan
            if ($Results.Count -gt 0) {
                if ($batchIndex -eq 99) {
                    # First save - create new file
                    $Results | Export-Csv -Path $TempOutputFile -NoTypeInformation
                } else {
                    # Subsequent saves - append
                    $Results | Export-Csv -Path $TempOutputFile -NoTypeInformation -Append
                }
                Write-Host "    Saved $($Results.Count) rows to temp file" -ForegroundColor Green
                $Results = @()  # Clear results to free memory
            }
        }
        
        # Small delay to avoid rate limiting
        Start-Sleep -Milliseconds 100
    }
    
    # Save any remaining results
    if ($Results.Count -gt 0) {
        Write-Host "  Saving final batch..." -ForegroundColor Cyan
        if (Test-Path $TempOutputFile) {
            $Results | Export-Csv -Path $TempOutputFile -NoTypeInformation -Append
        } else {
            $Results | Export-Csv -Path $TempOutputFile -NoTypeInformation
        }
        Write-Host "    Saved $($Results.Count) rows" -ForegroundColor Green
    }
    
    # =============================================================================
    # EXPORT RESULTS
    # =============================================================================
    Write-Host "PHASE 3: Finalizing results..." -ForegroundColor Cyan
    
    # Rename temp file to final file
    if (Test-Path $TempOutputFile) {
        if (Test-Path $OutputFile) {
            Remove-Item $OutputFile -Force
        }
        Rename-Item -Path $TempOutputFile -NewName $OutputFile
        Write-Host "  Renamed temp file to final output" -ForegroundColor Green
    }
    
    # Count total rows
    $TotalRows = 0
    if (Test-Path $OutputFile) {
        $TotalRows = (Import-Csv $OutputFile).Count
    }
    
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Results exported to: $((Get-Location).Path)\$OutputFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Total issues processed: $($AllIssueIds.Count)" -ForegroundColor White
    Write-Host "Total rows in output: $TotalRows" -ForegroundColor White
    Write-Host ""
    Write-Host "=== SAMPLE DATA (First 20 rows) ===" -ForegroundColor Cyan
    if (Test-Path $OutputFile) {
        Import-Csv $OutputFile | Select-Object -First 20 | Format-Table -AutoSize
    }
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

