# =============================================================================
# ENDPOINT: App Data Policies - GET Get data policy for the workspace
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-data-policies/#api-rest-api-3-data-policy-get
#
# DESCRIPTION: Returns data policy for the workspace using basic authentication.
# This endpoint provides access to workspace data policy management.
#
# ⚠️  IMPORTANT: This endpoint requires JIRA ADMINISTRATOR permissions
#    Ensure your credentials have admin access to retrieve workspace data policies
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Ensure you have admin-level permissions in Jira
# 3. Load the data
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
$Endpoint = "/rest/api/3/data-policy"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching workspace data policy..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        $PolicyData = [PSCustomObject]@{
            Id = if ($Response.id) { $Response.id } else { "" }
            Name = if ($Response.name) { $Response.name } else { "" }
            Description = if ($Response.description) { $Response.description } else { "" }
            Type = if ($Response.type) { $Response.type } else { "" }
            Status = if ($Response.status) { $Response.status } else { "" }
            Created = if ($Response.created) { $Response.created } else { "" }
            Updated = if ($Response.updated) { $Response.updated } else { "" }
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PolicyData
    } else {
        # If no policy data, create a single record with empty data
        $PolicyData = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            Type = ""
            Status = ""
            Created = ""
            Updated = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PolicyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "App Data Policies - GET Get data policy for the workspace - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve workspace data policy: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $PolicyData = [PSCustomObject]@{
        Id = ""
        Name = ""
        Description = ""
        Type = ""
        Status = ""
        Created = ""
        Updated = ""
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($PolicyData)
    
    # Export empty CSV
    $OutputFile = "App Data Policies - GET Get data policy for the workspace - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
    
    Write-Output "Created empty $OutputFile due to endpoint error"
    exit 0
}

