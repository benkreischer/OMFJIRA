# =============================================================================
# ENDPOINT: Issue Priorities - GET Priority
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-get
#
# DESCRIPTION: Returns the priority information for a specific issue (ORL-8004).
#
# SETUP: 
# 1. Run this script in PowerShell
# 2. CSV file will be generated automatically
#
# =============================================================================


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
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETER
# =============================================================================
$IssueKey = "ORL-8004"  # <-- The issue to get priority information from

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/" + $IssueKey
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Host "Calling API endpoint: $FullUrl"
    
    $Headers = Get-RequestHeaders -Parameters $Params
    
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers -ErrorAction Stop
    
    Write-Host "API call successful. Processing response..."
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Results = @()
    
    if ($Response -and $Response.fields -and $Response.fields.priority) {
        # Extract priority information from the issue (matching .pq file logic)
        $PriorityInfo = $Response.fields.priority
        
        $Result = [PSCustomObject]@{
            IssueKey = if ($Response.key) { $Response.key } else { "" }
            PriorityId = if ($PriorityInfo.id) { $PriorityInfo.id } else { "" }
            PriorityName = if ($PriorityInfo.name) { $PriorityInfo.name } else { "" }
            PriorityDescription = if ($PriorityInfo.description) { $PriorityInfo.description } else { "" }
            StatusColor = if ($PriorityInfo.statusColor) { $PriorityInfo.statusColor } else { "" }
            IconUrl = if ($PriorityInfo.iconUrl) { $PriorityInfo.iconUrl } else { "" }
            IsDefault = if ($PriorityInfo.isDefault -ne $null) { $PriorityInfo.isDefault.ToString().ToLower() } else { "false" }
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    } else {
        # Handle empty response or missing priority
        $Result = [PSCustomObject]@{
            IssueKey = if ($Response.key) { $Response.key } else { "" }
            PriorityId = ""
            PriorityName = ""
            PriorityDescription = ""
            StatusColor = ""
            IconUrl = ""
            IsDefault = "false"
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Issue Priorities - GET Priority - Anon - Official.csv"
    $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "CSV file generated successfully: $CsvPath"
    Write-Host "Records exported: $($Results.Count)"
    
    # Display sample data
    if ($Results.Count -gt 0) {
        Write-Host "`nSample data:"
        $Results | Select-Object -First 1 | Format-Table -AutoSize
    }
    
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        ErrorDescription = $_.Exception.ToString()
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Issue Priorities - GET Priority - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}
