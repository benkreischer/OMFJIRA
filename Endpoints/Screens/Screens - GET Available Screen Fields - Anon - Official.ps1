# =============================================================================
# ENDPOINT: Screens - GET Available Screen Fields
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
#
# DESCRIPTION: Returns fields available for screens using basic authentication.
# This endpoint provides access to available screen field management.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Load the data
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
$ScreenId = $Params.CommonParameters.ScreenId  # <-- Using valid screen ID from bulk endpoint

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/screens/" + $ScreenId + "/availableFields"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching available screen fields for screen ID: $ScreenId..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.error -eq $null) {
        # Process each field individually (response is an array, not paginated)
        foreach ($field in $Response) {
            $FieldData = [PSCustomObject]@{
                ScreenId = $ScreenId
                FieldId = $field.id
                FieldName = $field.name
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $FieldData
        }
    } else {
        # Handle error response or no data
        if ($Response.error) {
            Write-Error "API Error: $($Response.error)"
            # Create empty record for failed endpoint
            $FieldData = [PSCustomObject]@{
                ScreenId = $ScreenId
                FieldId = ""
                FieldName = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $FieldData
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Screens - GET Available Screen Fields - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve available screen fields data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $FieldData = [PSCustomObject]@{
        ScreenId = $ScreenId
        FieldId = ""
        FieldName = ""
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($FieldData)
    
    # Export empty CSV
    $OutputFile = "Screens - GET Available Screen Fields - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    
    Write-Output "Created empty $OutputFile due to endpoint error"
    exit 0
}

