# =============================================================================
# ENDPOINT: Issue worklog properties - GET Worklog Properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-worklog-properties/#api-rest-api-3-issue-issueidorkey-worklog-worklogid-properties-get
#
# DESCRIPTION: Returns the properties for a worklog.
#
# SETUP:
# 1. Run this script to generate CSV data
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
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey  # <-- IMPORTANT: Replace with the ID or key of the issue
$WorklogId = "10000"        # <-- IMPORTANT: Replace with the ID of the worklog

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/" + $IssueIdOrKey + "/worklog/" + $WorklogId + "/properties"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching properties for worklog $WorklogId in issue $IssueIdOrKey..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.keys -and $Response.keys.Count -gt 0) {
        foreach ($property in $Response.keys) {
            $PropertyData = [PSCustomObject]@{
                IssueIdOrKey = $IssueIdOrKey
                WorklogId = $WorklogId
                PropertyKey = $property.key
                Self = $property.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        Write-Output "No properties found for worklog $WorklogId in issue $IssueIdOrKey"
        $PropertyData = [PSCustomObject]@{
            IssueIdOrKey = $IssueIdOrKey; WorklogId = $WorklogId; PropertyKey = ""; Self = ""; 
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue worklog properties - GET Worklog Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve worklog properties: $($_.Exception.Message)"
    $PropertyData = [PSCustomObject]@{
        IssueIdOrKey = $IssueIdOrKey; WorklogId = $WorklogId; PropertyKey = ""; Self = ""; 
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($PropertyData)
    $OutputFile = "Issue worklog properties - GET Worklog Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

