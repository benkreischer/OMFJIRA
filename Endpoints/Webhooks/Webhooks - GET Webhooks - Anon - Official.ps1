# =============================================================================
# ENDPOINT: Webhooks - GET Webhooks
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-webhooks/
#
# DESCRIPTION: Returns a paginated list of the webhooks registered by the calling app.
#
# NOTE: This endpoint requires OAuth 2.0 authentication and app-specific permissions.
#       It will return 403 Forbidden with Basic Auth as webhooks are app-scoped.
#       Only the app that created webhooks can access them.
#
# SETUP:
# 1. Run this script to generate CSV data (will show authentication limitation)
# 2. For actual webhook access, use OAuth 2.0 with appropriate app permissions
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
$Endpoint = "/rest/api/3/webhook"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Handle different response structures
        if ($Response -is [Array]) {
            # Response is already an array
            foreach ($item in $Response) {
                $Result += $item
            }
        } elseif ($Response.values) {
            # Response has paginated structure with 'values' property
            $Result += $Response.values
        } elseif ($Response.PSObject.Properties.Count -gt 0) {
            # Response is a single object
            $Result += $Response
        } else {
            # Empty or unexpected response
            $Result += [PSCustomObject]@{
                Message = "No data returned"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        # No response data
        $Result += [PSCustomObject]@{
            Message = "No data returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Webhooks - GET Webhooks - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "CSV file generated successfully: $(Get-Location)\$OutputFile"
    Write-Output "Records exported: $($Result.Count)"

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Output "`nSample data:"
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    $ErrorMessage = $_.Exception.Message

    if ($ErrorMessage -match "403|Forbidden") {
        Write-Output "Authentication Error: This endpoint requires OAuth 2.0 authentication with app-specific permissions."
        Write-Output "Webhooks are scoped to the app that created them and cannot be accessed via Basic Auth."
        Write-Output "Original error: $ErrorMessage"

        # Create informative record for authentication limitation
        $EmptyData = [PSCustomObject]@{
            Error = "403 Forbidden - Requires OAuth 2.0 authentication"
            Reason = "Webhooks endpoint is app-scoped and requires app-specific permissions"
            Authentication = "OAuth 2.0 required (Basic Auth not supported)"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    } else {
        Write-Output "Failed to retrieve data: $ErrorMessage"

        # Create generic error record
        $EmptyData = [PSCustomObject]@{
            Error = $ErrorMessage
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "Webhooks - GET Webhooks - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}
