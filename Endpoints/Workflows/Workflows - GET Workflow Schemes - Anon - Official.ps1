# =============================================================================
# ENDPOINT: Workflows - GET Workflow Schemes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflows/#api-rest-api-3-workflowscheme-get
#
# DESCRIPTION: Returns all workflow schemes.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. No additional parameters required.
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
$StartAt = 0 # <-- OPTIONAL: The index of the first item to return (default: 0)
$MaxResults = $Params.ApiSettings.MaxResults # <-- OPTIONAL: The maximum number of items to return (default: 50)

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/workflowscheme"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching workflow schemes..."
    $QueryString = "startAt=" + $StartAt + "&maxResults=" + $MaxResults
    $FullUrlWithQuery = $FullUrl + "?" + $QueryString

    $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.values -and $Response.values.Count -gt 0) {
        # Extract individual workflow schemes from the values array
        foreach ($scheme in $Response.values) {
            $SchemeData = [PSCustomObject]@{
                Id = if ($scheme.id) { $scheme.id } else { "" }
                Name = if ($scheme.name) { $scheme.name } else { "" }
                Description = if ($scheme.description) { $scheme.description } else { "" }
                DefaultWorkflow = if ($scheme.defaultWorkflow) { $scheme.defaultWorkflow } else { "" }
                IssueTypeMappingsCount = if ($scheme.issueTypeMappings) {
                    if ($scheme.issueTypeMappings -is [hashtable]) { $scheme.issueTypeMappings.Count }
                    elseif ($scheme.issueTypeMappings -is [string] -and $scheme.issueTypeMappings -ne "") { "Multiple" }
                    else { 0 }
                } else { 0 }
                Self = if ($scheme.self) { $scheme.self } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $SchemeData
        }
    } else {
        # If no workflow schemes, create a single record with empty data
        $SchemeData = [PSCustomObject]@{
            Id = ""
            Name = "No workflow schemes found"
            Description = ""
            DefaultWorkflow = ""
            IssueTypeMappingsCount = 0
            Self = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $SchemeData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Workflows - GET Workflow Schemes - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve workflow schemes data: $($_.Exception.Message)"
    exit 1
}

