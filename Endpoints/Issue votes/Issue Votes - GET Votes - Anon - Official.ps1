# =============================================================================
# ENDPOINT: Issue Votes - GET Votes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-votes/#api-rest-api-3-issue-issueidorkey-votes-get
#
# DESCRIPTION: Returns details about the votes on an issue.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Update the 'IssueIdOrKey' parameter.
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
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey # <-- IMPORTANT: Replace with the ID or key of the issue

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/" + $IssueIdOrKey + "/votes"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching votes for issue $IssueIdOrKey..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $VotesData = [PSCustomObject]@{
            Self = $Response.self
            Votes = $Response.votes
            HasVoted = if ($Response.hasVoted) { $Response.hasVoted.ToString().ToLower() } else { "" }
            Voters = if ($Response.voters) { ($Response.voters | ConvertTo-Json -Compress) } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $VotesData
    } else {
        # If no votes data, create a single record with empty data
        $VotesData = [PSCustomObject]@{
            Self = ""
            Votes = ""
            HasVoted = ""
            Voters = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $VotesData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Votes - GET Votes - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve votes data: $($_.Exception.Message)"
    exit 1
}
