# =============================================================================
# ENDPOINT: Issue redaction - GET Redaction Rules
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-redaction/#api-rest-api-3-issue-issueidorkey-redaction-rules-get
#
# DESCRIPTION: Returns the redaction rules for an issue.
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

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/" + $IssueIdOrKey + "/redaction/rules"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching redaction rules for issue: $IssueIdOrKey..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.rules -and $Response.rules.Count -gt 0) {
        foreach ($rule in $Response.rules) {
            $RuleData = [PSCustomObject]@{
                IssueIdOrKey = $IssueIdOrKey
                RuleId = $rule.id
                RuleName = $rule.name
                Description = if ($rule.description) { $rule.description } else { "" }
                IsEnabled = $rule.isEnabled
                Created = if ($rule.created) { $rule.created } else { "" }
                CreatedBy = if ($rule.createdBy -and $rule.createdBy.displayName) { $rule.createdBy.displayName } else { "" }
                Updated = if ($rule.updated) { $rule.updated } else { "" }
                UpdatedBy = if ($rule.updatedBy -and $rule.updatedBy.displayName) { $rule.updatedBy.displayName } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $RuleData
        }
    } else {
        Write-Output "No redaction rules found for issue: $IssueIdOrKey"
        $RuleData = [PSCustomObject]@{
            IssueIdOrKey = $IssueIdOrKey; RuleId = ""; RuleName = ""; Description = ""; 
            IsEnabled = ""; Created = ""; CreatedBy = ""; Updated = ""; UpdatedBy = ""; 
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $RuleData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue redaction - GET Redaction Rules - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve redaction rules: $($_.Exception.Message)"
    $RuleData = [PSCustomObject]@{
        IssueIdOrKey = $IssueIdOrKey; RuleId = ""; RuleName = ""; Description = ""; 
        IsEnabled = ""; Created = ""; CreatedBy = ""; Updated = ""; UpdatedBy = ""; 
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($RuleData)
    $OutputFile = "Issue redaction - GET Redaction Rules - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

