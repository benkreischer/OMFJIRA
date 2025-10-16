# =============================================================================
# ENDPOINT: Issue type properties - GET Issue Type Properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-type-properties/#api-rest-api-3-issuetype-issuetypeid-properties-get
#
# DESCRIPTION: Returns the properties for an issue type.
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
$IssueTypeId = "10000"  # <-- IMPORTANT: Replace with the ID of the issue type

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issuetype/" + $IssueTypeId + "/properties"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching properties for issue type: $IssueTypeId..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.keys -and $Response.keys.Count -gt 0) {
        foreach ($property in $Response.keys) {
            $PropertyData = [PSCustomObject]@{
                IssueTypeId = $IssueTypeId
                PropertyKey = $property.key
                Self = $property.self
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        Write-Output "No properties found for issue type: $IssueTypeId"
        $PropertyData = [PSCustomObject]@{
            IssueTypeId = $IssueTypeId; PropertyKey = ""; Self = ""; 
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue type properties - GET Issue Type Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve issue type properties: $($_.Exception.Message)"
    $PropertyData = [PSCustomObject]@{
        IssueTypeId = $IssueTypeId; PropertyKey = ""; Self = ""; 
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($PropertyData)
    $OutputFile = "Issue type properties - GET Issue Type Properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

