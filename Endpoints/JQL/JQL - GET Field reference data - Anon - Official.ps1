# =============================================================================
# ENDPOINT: JQL - GET Field reference data
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-jql/#api-rest-api-3-field-search-get
#
# DESCRIPTION: Returns reference data for JQL searches, including visible field names and types.
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
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/field/search"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching JQL field reference data..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.values.Count -gt 0) {
        foreach ($field in $Response.values) {
            $FieldData = [PSCustomObject]@{
                Value = $field.value
                DisplayName = $field.displayName
                Types = if ($field.types) { ($field.types | ConvertTo-Json -Compress) } else { "" }
                Orderable = if ($field.orderable) { $field.orderable.ToString().ToLower() } else { "" }
                Searchable = if ($field.searchable) { $field.searchable.ToString().ToLower() } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $FieldData
        }
    } else {
        # If no field reference data, create a single record with empty data
        $FieldData = [PSCustomObject]@{
            Value = ""
            DisplayName = ""
            Types = ""
            Orderable = ""
            Searchable = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $FieldData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "JQL - GET Field reference data - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve JQL field reference data: $($_.Exception.Message)"
    exit 1
}

