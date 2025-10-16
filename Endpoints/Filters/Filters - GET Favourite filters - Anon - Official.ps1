# =============================================================================
# ENDPOINT: Filters - GET Favourite filters
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-filters/#api-rest-api-3-filter-favourite-get
#
# DESCRIPTION: Returns a paginated list of the user's favorite filters.
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
$Endpoint = "/rest/api/3/filter/favourite"
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
            # Response is already an array - expand complex objects
            foreach ($item in $Response) {
                $FilterData = [PSCustomObject]@{
                    Self = if ($item.self) { $item.self } else { "" }
                    Id = if ($item.id) { $item.id } else { "" }
                    Name = if ($item.name) { $item.name } else { "" }
                    Description = if ($item.description) { $item.description } else { "" }
                    Owner = if ($item.owner) { $item.owner.displayName } else { "" }
                    Jql = if ($item.jql) { $item.jql } else { "" }
                    ViewUrl = if ($item.viewUrl) { $item.viewUrl } else { "" }
                    SearchUrl = if ($item.searchUrl) { $item.searchUrl } else { "" }
                    Favourite = if ($item.favourite) { $item.favourite.ToString().ToLower() } else { "" }
                    FavouritedCount = if ($item.favouritedCount) { $item.favouritedCount } else { 0 }
                    SharePermissions = if ($item.sharePermissions) { ($item.sharePermissions | ForEach-Object { "$($_.type): $($_.id)" }) -join "; " } else { "" }
                    EditPermissions = if ($item.editPermissions) { ($item.editPermissions | ForEach-Object { "$($_.type): $($_.id)" }) -join "; " } else { "" }
                    IsWritable = if ($item.isWritable) { $item.isWritable.ToString().ToLower() } else { "" }
                    SharedUsersCount = if ($item.sharedUsers -and $item.sharedUsers.size) { $item.sharedUsers.size } else { 0 }
                    SubscriptionsCount = if ($item.subscriptions -and $item.subscriptions.size) { $item.subscriptions.size } else { 0 }
                    ApproximateLastUsed = if ($item.approximateLastUsed) { $item.approximateLastUsed } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $FilterData
            }
        } elseif ($Response.values) {
            # Response has paginated structure with 'values' property
            foreach ($item in $Response.values) {
                $FilterData = [PSCustomObject]@{
                    Self = if ($item.self) { $item.self } else { "" }
                    Id = if ($item.id) { $item.id } else { "" }
                    Name = if ($item.name) { $item.name } else { "" }
                    Description = if ($item.description) { $item.description } else { "" }
                    Owner = if ($item.owner) { $item.owner.displayName } else { "" }
                    Jql = if ($item.jql) { $item.jql } else { "" }
                    ViewUrl = if ($item.viewUrl) { $item.viewUrl } else { "" }
                    SearchUrl = if ($item.searchUrl) { $item.searchUrl } else { "" }
                    Favourite = if ($item.favourite) { $item.favourite.ToString().ToLower() } else { "" }
                    FavouritedCount = if ($item.favouritedCount) { $item.favouritedCount } else { 0 }
                    SharePermissions = if ($item.sharePermissions) { ($item.sharePermissions | ForEach-Object { "$($_.type): $($_.id)" }) -join "; " } else { "" }
                    EditPermissions = if ($item.editPermissions) { ($item.editPermissions | ForEach-Object { "$($_.type): $($_.id)" }) -join "; " } else { "" }
                    IsWritable = if ($item.isWritable) { $item.isWritable.ToString().ToLower() } else { "" }
                    SharedUsersCount = if ($item.sharedUsers -and $item.sharedUsers.size) { $item.sharedUsers.size } else { 0 }
                    SubscriptionsCount = if ($item.subscriptions -and $item.subscriptions.size) { $item.subscriptions.size } else { 0 }
                    ApproximateLastUsed = if ($item.approximateLastUsed) { $item.approximateLastUsed } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $FilterData
            }
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
    $OutputFile = "Filters - GET Favourite filters - Anon - Official.csv"
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
    $OutputFile = "Filters - GET Favourite filters - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

