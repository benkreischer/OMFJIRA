# =============================================================================
# ENDPOINT: Issue Custom Field Configuration (Apps) - GET Custom Field Configuration
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-configuration-apps/#api-rest-api-3-issue-issueidorkey-customfield-customfieldid-configuration-get
#
# DESCRIPTION: Returns the configuration for a custom field.
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
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/"
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
    $OutputFile = "Issue Custom Field Configuration (Apps) - GET Custom Field Configuration - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "CSV file generated successfully: $(Get-Location)\$OutputFile"
    Write-Output "Records exported: $($Result.Count)"

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Output "
Sample data:"
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $EmptyData = [PSCustomObject]@{
        Error = $_.Exception.Message
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "Issue Custom Field Configuration (Apps) - GET Custom Field Configuration - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

