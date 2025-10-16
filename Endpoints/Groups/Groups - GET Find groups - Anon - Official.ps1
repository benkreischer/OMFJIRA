# =============================================================================
# ENDPOINT: Groups - GET Find groups
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-groups-picker-get
#
# DESCRIPTION: Returns a paginated list of groups matching the search criteria.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Update the 'Query' parameter with the text to search for.
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
$Query = "admin" # <-- The string to search for.

# =============================================================================
# API CALL (with pagination handling)
# =============================================================================
$Endpoint = "/rest/api/3/groups/picker"
$FullUrl = $BaseUrl + $Endpoint
$AllGroups = @()
$NextPage = $null

try {
    do {
        if ($NextPage -eq $null) {
            Write-Output "Fetching groups with query: $Query"
            $QueryString = "query=" + [System.Uri]::EscapeDataString($Query)
            $FullUrlWithQuery = $FullUrl + "?" + $QueryString
        } else {
            Write-Output "Fetching next page: $NextPage"
            $FullUrlWithQuery = $BaseUrl + $NextPage
        }

        $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

        if ($Response -and $Response.groups.Count -gt 0) {
            $AllGroups += $Response.groups
            Write-Output "Retrieved $($Response.groups.Count) groups (Total so far: $($AllGroups.Count))"
            
            # Check for next page
            if ($Response.nextPage) {
                $NextPage = $Response.nextPage
            } else {
                $NextPage = $null
            }
        } else {
            break
        }
    } while ($NextPage -ne $null)

    Write-Output "Pagination complete. Total groups retrieved: $($AllGroups.Count)"

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($AllGroups -and $AllGroups.Count -gt 0) {
        foreach ($group in $AllGroups) {
            $GroupData = [PSCustomObject]@{
                Name = $group.name
                GroupId = $group.groupId
                HTML = $group.html
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $GroupData
        }
    } else {
        # If no groups, create a single record with empty data
        $GroupData = [PSCustomObject]@{
            Name = ""
            GroupId = ""
            HTML = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $GroupData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Groups - GET Find groups - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve groups data: $($_.Exception.Message)"
    exit 1
}
