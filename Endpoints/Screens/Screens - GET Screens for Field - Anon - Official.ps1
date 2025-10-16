# =============================================================================
# ENDPOINT: Screens - GET Screens for Field
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
#
# DESCRIPTION: Returns screens associated with a specific field using basic authentication.
# This endpoint provides access to field-screen associations.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Update the 'FieldId' parameter with a valid field ID
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
# PARAMETER
# =============================================================================
$FieldId = $Params.CommonParameters.FieldId  # <-- Using valid field ID from available fields

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/field/" + $FieldId + "/screens"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching screens for field: $FieldId..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.error -eq $null -and $Response.values) {
        # Process each screen individually
        foreach ($screen in $Response.values) {
            $ScreenData = [PSCustomObject]@{
                FieldId = $FieldId
                ScreenId = $screen.id
                ScreenName = $screen.name
                ScreenDescription = if ($screen.description) { $screen.description } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ScreenData
        }
    } else {
        # Handle error response or no data
        if ($Response.error) {
            Write-Error "API Error: $($Response.error)"
            # Create empty record for failed endpoint
            $ScreenData = [PSCustomObject]@{
                FieldId = $FieldId
                ScreenId = ""
                ScreenName = ""
                ScreenDescription = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ScreenData
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Screens - GET Screens for Field - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve screens for field data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $ScreenData = [PSCustomObject]@{
        FieldId = $FieldId
        ScreenId = ""
        ScreenName = ""
        ScreenDescription = ""
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($ScreenData)
    
    # Export empty CSV
    $OutputFile = "Screens - GET Screens for Field - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    
    Write-Output "Created empty $OutputFile due to endpoint error"
    exit 0
}

