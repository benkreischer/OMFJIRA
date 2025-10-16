# =============================================================================
# ENDPOINT: Issue Links - GET Simple Links (Hybrid)
# =============================================================================
#
# DESCRIPTION: Returns all issues that have issue links, showing just ID, Key,
# and the keys of linked issues in a simplified format.
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Load the data
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
# PARAMETERS
# =============================================================================
$JqlQuery = "project is not EMPTY ORDER BY created DESC"
$MaxResults = $Params.ApiSettings.MaxResults  # Maximum batch size for Enhanced JQL API
$BatchSize = $Params.ApiSettings.BatchSize    # Batch size for Bulk Fetch API

try {
    Write-Output "Starting Simple Issue Links data collection..."

    # =============================================================================
    # PHASE 1: GET ALL ISSUE IDs USING ENHANCED JQL API
    # =============================================================================
    Write-Output "PHASE 1: Getting all issue IDs using Enhanced JQL API..."

    $EnhancedSearchUrl = "$BaseUrl/rest/api/3/search/jql"
    $AllIssueIds = @()
    $NextPageToken = $null
    $TotalPages = 0

    do {
        $TotalPages++
        Write-Output "  Fetching page $TotalPages..."

        # Build request payload for Enhanced JQL API
        $Payload = @{
            jql = $JqlQuery
            maxResults = $MaxResults
        }

        if ($NextPageToken) {
            $Payload.nextPageToken = $NextPageToken
        }

        $JsonPayload = $Payload | ConvertTo-Json -Depth 10

        try {
            $Response = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $AuthHeader -Body $JsonPayload

            Write-Output "    Retrieved $($Response.issues.Count) issues from page $TotalPages"

            # Extract issue IDs (Enhanced JQL API returns minimal data for performance)
            foreach ($issue in $Response.issues) {
                $AllIssueIds += $issue.id
            }

            Write-Output "    Total issue IDs collected: $($AllIssueIds.Count)"

            # Check for next page token
            if ($Response.PSObject.Properties.Name -contains "nextPageToken") {
                $NextPageToken = $Response.nextPageToken
                Write-Output "    Next page token found, continuing..."
            } else {
                $NextPageToken = $null
                Write-Output "    No next page token, pagination complete"
            }

        } catch {
            Write-Output "Failed to fetch page $TotalPages`: $($_.Exception.Message)"
            break
        }

    } while ($NextPageToken -ne $null)

    Write-Output "PHASE 1 COMPLETE: Collected $($AllIssueIds.Count) issue IDs in $TotalPages pages"

    # =============================================================================
    # PHASE 2: GET ISSUE DETAILS USING BULK FETCH API IN PARALLEL
    # =============================================================================
    Write-Output "PHASE 2: Getting issue details using Bulk Fetch API..."

    $BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"
    $AllIssueDetails = @()

    if ($AllIssueIds.Count -gt 0) {
        # Split issue IDs into batches
        $Batches = @()
        for ($i = 0; $i -lt $AllIssueIds.Count; $i += $BatchSize) {
            $Batch = $AllIssueIds[$i..([Math]::Min($i + $BatchSize - 1, $AllIssueIds.Count - 1))]
            $Batches += ,$Batch  # Comma to create array of arrays
        }

        Write-Output "  Created $($Batches.Count) batches of up to $BatchSize issues each"

        # Process batches
        foreach ($BatchIndex in 0..($Batches.Count - 1)) {
            $Batch = $Batches[$BatchIndex]
            Write-Output "  Processing batch $($BatchIndex + 1)/$($Batches.Count) with $($Batch.Count) issues..."

            # Build request payload for Bulk Fetch API - only get key and issuelinks fields
            $BulkPayload = @{
                fields = @("key", "issuelinks")
                issueIdsOrKeys = $Batch
            }

            $BulkJsonPayload = $BulkPayload | ConvertTo-Json -Depth 10

            try {
                $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $AuthHeader -Body $BulkJsonPayload

                Write-Output "    Retrieved $($BulkResponse.issues.Count) issue details from batch $($BatchIndex + 1)"
                $AllIssueDetails += $BulkResponse.issues

                # Add small delay to avoid rate limiting
                Start-Sleep -Milliseconds 100

            } catch {
                Write-Output "Failed to fetch batch $($BatchIndex + 1): $($_.Exception.Message)"
            }
        }
    }

    Write-Output "PHASE 2 COMPLETE: Retrieved $($AllIssueDetails.Count) issue details"

    # =============================================================================
    # DATA TRANSFORMATION AND CSV EXPORT
    # =============================================================================
    Write-Output "Transforming data and exporting to CSV..."

    $Result = @()

    if ($AllIssueDetails -and $AllIssueDetails.Count -gt 0) {
        foreach ($issue in $AllIssueDetails) {
            # Skip issues without issue links
            if (-not $issue.fields.issuelinks -or $issue.fields.issuelinks.Count -eq 0) {
                continue
            }

            # Collect all linked keys (both inward and outward)
            $LinkedKeys = @()

            if ($issue.fields.issuelinks) {
                foreach ($link in $issue.fields.issuelinks) {
                    if ($link.inwardIssue) {
                        $LinkedKeys += $link.inwardIssue.key
                    }
                    if ($link.outwardIssue) {
                        $LinkedKeys += $link.outwardIssue.key
                    }
                }
            }

            $IssueData = [PSCustomObject]@{
                Id = $issue.id
                Key = $issue.key
                LinkedKeys = if ($LinkedKeys.Count -gt 0) { ($LinkedKeys | Sort-Object) -join "; " } else { "" }
                TotalLinks = $LinkedKeys.Count
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $IssueData
        }
    } else {
        # Create empty record if no issues found
        $IssueData = [PSCustomObject]@{
            Id = ""
            Key = ""
            LinkedKeys = ""
            TotalLinks = 0
            Message = "No issues with links found"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $IssueData
    }

    # Export to CSV
    $OutputFile = "Issue Links - GET Simple Links - Anon - Hybrid.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "SUCCESS: Generated CSV file: $(Get-Location)\$OutputFile"
    Write-Output ""
    Write-Output "SUMMARY:"
    Write-Output "  - Issue IDs collected: $($AllIssueIds.Count)"
    Write-Output "  - Issue details retrieved: $($AllIssueDetails.Count)"
    Write-Output "  - Issues with links found: $($Result.Count)"
    Write-Output "  - Final CSV rows: $($Result.Count)"
    Write-Output "  - Pages processed: $TotalPages"
    Write-Output "  - Batches processed: $(if ($AllIssueIds.Count -gt 0) { [Math]::Ceiling($AllIssueIds.Count / $BatchSize) } else { 0 })"

    # Show sample data
    if ($Result.Count -gt 0 -and $Result[0].Key -ne "") {
        Write-Output ""
        Write-Output "Sample data:"
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $EmptyData = [PSCustomObject]@{
        Error = $_.Exception.Message
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "Issue Links - GET Simple Links - Anon - Hybrid.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}
