# =============================================================================
# ENDPOINT: Issue Links - GET Issue link
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-links/#api-rest-api-3-issuelink-linkid-get
#
# DESCRIPTION: Returns an issue link.
#
# SETUP: 
# 1. Update the 'LinkId' parameter with a valid Issue Link ID.
# 2. Run this script to generate CSV data
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
$LinkId = "304254"  # <-- Using real Issue Link ID from ORL-8004

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issueLink/" + $LinkId
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching issue link with ID: $LinkId"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $LinkData = [PSCustomObject]@{
            Id = $Response.id
            Self = $Response.self
            Type = if ($Response.type) { "$($Response.type.name) ($($Response.type.inward) / $($Response.type.outward))" } else { "" }
            InwardIssue = if ($Response.inwardIssue) { "$($Response.inwardIssue.key): $($Response.inwardIssue.fields.summary)" } else { "" }
            OutwardIssue = if ($Response.outwardIssue) { "$($Response.outwardIssue.key): $($Response.outwardIssue.fields.summary)" } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $LinkData
    } else {
        # If no link data, create a single record with empty data
        $LinkData = [PSCustomObject]@{
            Id = ""
            Self = ""
            Type = ""
            InwardIssue = ""
            OutwardIssue = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $LinkData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Links - GET Issue link - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve issue link data: $($_.Exception.Message)"
    exit 1
}

