# =============================================================================
# ENHANCED LABELS WITH ISSUE CONTEXT - USING WORKING ENHANCED JQL API
# =============================================================================
# Based on the working Issue Search Enhanced JQL API approach
# This implements the two-phase approach for labels with issue context:
# 1. Get all labels from the labels API
# 2. For each label, search for issues using Enhanced JQL API
# 3. Use Bulk Fetch API to get issue details in parallel batches
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$MaxResults = $Params.ApiSettings.MaxResults  # Maximum batch size for Enhanced JQL API
$BatchSize = $Params.ApiSettings.BatchSize    # Batch size for Bulk Fetch API

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================
function Format-JiraDate {
    param([string]$DateString)
    
    if ([string]::IsNullOrEmpty($DateString)) {
        return ""
    }
    
    try {
        $Date = [DateTime]::Parse($DateString)
        return $Date.ToString("yyyy-MM-dd HH:mm:ss")
    } catch {
        return $DateString
    }
}

# =============================================================================
# PHASE 1: GET ALL LABELS
# =============================================================================
Write-Output "PHASE 1: Getting all labels..."

$LabelsEndpoint = "/rest/api/3/label"
$LabelsUrl = $BaseUrl + $LabelsEndpoint
$AllLabels = @()
$StartAt = 0
$MaxResultsLabels = 1000

do {
    $QueryString = "startAt=" + $StartAt + "&maxResults=" + $MaxResultsLabels
    $LabelsUrlWithQuery = $LabelsUrl + "?" + $QueryString

    $LabelsResponse = Invoke-RestMethod -Uri $LabelsUrlWithQuery -Headers $AuthHeader -Method Get

    if ($LabelsResponse -and $LabelsResponse.values.Count -gt 0) {
        $AllLabels += $LabelsResponse.values
        $StartAt += $LabelsResponse.values.Count
        Write-Output "Retrieved $($LabelsResponse.values.Count) labels (Total so far: $($AllLabels.Count))"
    } else {
        break
    }
} while ($LabelsResponse.isLast -eq $false)

Write-Output "PHASE 1 COMPLETE: Collected $($AllLabels.Count) labels"

# =============================================================================
# PHASE 2: FOR EACH LABEL, GET ISSUE CONTEXT USING ENHANCED JQL API
# =============================================================================
Write-Output "PHASE 2: Getting issue context for each label..."

$EnhancedSearchUrl = "$BaseUrl/rest/api/3/search/jql"
$BulkFetchUrl = "$BaseUrl/rest/api/3/issue/bulkfetch"
$Result = @()

foreach ($label in $AllLabels) {
    Write-Output "Processing label: '$label'"
    
    try {
        # Search for issues with this label using Enhanced JQL API
        $JqlQuery = "labels = '$label' ORDER BY created DESC, id ASC"
        
        $SearchPayload = @{
            jql = $JqlQuery
            maxResults = $MaxResults
        }
        
        $SearchJsonPayload = $SearchPayload | ConvertTo-Json -Depth 10
        
        $SearchResponse = Invoke-RestMethod -Uri $EnhancedSearchUrl -Method Post -Headers $AuthHeader -Body $SearchJsonPayload
        
        $IssueIds = @()
        if ($SearchResponse.issues) {
            foreach ($issue in $SearchResponse.issues) {
                $IssueIds += $issue.id
            }
        }
        
        Write-Output "  Found $($IssueIds.Count) issues with label '$label'"
        
        if ($IssueIds.Count -gt 0) {
            # Get issue details using Bulk Fetch API
            $BulkPayload = @{
                fields = @("summary", "status", "priority", "assignee", "reporter", "created", "updated", "project", "issuetype")
                issueIdsOrKeys = $IssueIds
            }
            
            $BulkJsonPayload = $BulkPayload | ConvertTo-Json -Depth 10
            $BulkResponse = Invoke-RestMethod -Uri $BulkFetchUrl -Method Post -Headers $AuthHeader -Body $BulkJsonPayload
            
            # Extract issue keys
            $IssueKeys = @()
            
            if ($BulkResponse.issues) {
                foreach ($issue in $BulkResponse.issues) {
                    $IssueKeys += $issue.key
                }
            }
            
            $IssueKeysString = $IssueKeys -join "; "
            
        } else {
            $IssueKeysString = ""
        }
        
        # Create enhanced label data
        $LabelData = [PSCustomObject]@{
            Label = $label
            IssueCount = $IssueIds.Count
            IssueKeys = $IssueKeysString
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $LabelData
        
        # Add small delay to avoid rate limiting
        Start-Sleep -Milliseconds 200
        
    } catch {
        Write-Warning "Failed to process label '$label': $($_.Exception.Message)"
        
        # Create label data with error note
        $LabelData = [PSCustomObject]@{
            Label = $label
            IssueCount = "Error"
            IssueKeys = "Error: $($_.Exception.Message)"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $LabelData
    }
}

# =============================================================================
# EXPORT TO CSV
# =============================================================================
$OutputFile = "Labels - GET All labels by Project - Anon - Hybrid.csv"
$Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

Write-Output "SUCCESS: Wrote $OutputFile with $($Result.Count) rows"
Write-Output ""
Write-Output "SUMMARY:"
Write-Output "  - Labels processed: $($AllLabels.Count)"
Write-Output "  - Final CSV rows: $($Result.Count)"
Write-Output "  - Enhanced JQL API approach working successfully"
