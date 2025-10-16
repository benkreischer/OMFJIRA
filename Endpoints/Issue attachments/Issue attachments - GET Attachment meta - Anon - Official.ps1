# =============================================================================
# ENDPOINT: Issue attachments - GET Attachment meta
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-attachments/#api-rest-api-3-attachment-meta-get
#
# DESCRIPTION: Returns the attachment settings.
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
$Endpoint = "/rest/api/3/attachment/meta"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching attachment meta settings..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Convert the response object to key-value pairs
        $Response.PSObject.Properties | ForEach-Object {
            $MetaData = [PSCustomObject]@{
                Key = $_.Name
                Value = $_.Value
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $MetaData
        }
    } else {
        Write-Output "No attachment meta settings found"
        $MetaData = [PSCustomObject]@{ Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
        $Result += $MetaData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue attachments - GET Attachment meta - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve attachment meta settings: $($_.Exception.Message)"
    $MetaData = [PSCustomObject]@{ Key = ""; Value = ""; GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss" }
    $Result = @($MetaData)
    $OutputFile = "Issue attachments - GET Attachment meta - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

