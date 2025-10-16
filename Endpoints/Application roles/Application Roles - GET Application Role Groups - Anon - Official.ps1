# =============================================================================
# ENDPOINT: Application Roles - GET Application Roles
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-application-roles/#api-rest-api-3-applicationrole-get
#
# DESCRIPTION: Returns all application roles.
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Load the data
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
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
$BaseUrl = $Params.BaseUrl

# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/applicationrole"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Handle different response structures
        if ($Response -is [Array]) {
            # Response is already an array - expand complex objects
            foreach ($item in $Response) {
                $RoleData = [PSCustomObject]@{
                    Key = $item.key
                    Name = $item.name
                    Groups = if ($item.groups) { ($item.groups -join "; ") } else { "" }
                    DefaultGroups = if ($item.defaultGroups) { ($item.defaultGroups -join "; ") } else { "" }
                    SelectedByDefault = $item.selectedByDefault
                    Defined = $item.defined
                    NumberOfSeats = $item.numberOfSeats
                    RemainingSeats = $item.remainingSeats
                    UserCount = $item.userCount
                    UserCountDescription = $item.userCountDescription
                    HasUnlimitedSeats = $item.hasUnlimitedSeats
                    Platform = $item.platform
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $RoleData
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
    $OutputFile = "Application Roles - GET Application Roles - Anon - Official.csv"
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
    $OutputFile = "Application Roles - GET Application Roles - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

