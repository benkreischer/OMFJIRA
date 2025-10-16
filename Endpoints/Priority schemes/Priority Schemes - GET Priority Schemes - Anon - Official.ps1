# =============================================================================
# ENDPOINT: Priority Schemes - GET Priority Schemes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-priority-schemes/
#
# DESCRIPTION: Returns priority schemes using basic authentication.
# This endpoint provides access to priority scheme management.
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
$Endpoint = "/rest/api/3/priorityscheme"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching priority schemes..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.error -eq $null) {
        # Extract individual priority schemes from the values array
        if ($Response.values -and $Response.values.Count -gt 0) {
            foreach ($scheme in $Response.values) {
                $SchemeData = [PSCustomObject]@{
                    Id = if ($scheme.id) { $scheme.id } else { "" }
                    Name = if ($scheme.name) { $scheme.name } else { "" }
                    Description = if ($scheme.description) { $scheme.description } else { "" }
                    IsDefault = if ($scheme.isDefault) { $scheme.isDefault.ToString().ToLower() } else { "false" }
                    DefaultPriorityId = if ($scheme.defaultPriorityId) { $scheme.defaultPriorityId } else { "" }
                    Self = if ($scheme.self) { $scheme.self } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $SchemeData
            }
        } else {
            # No schemes found
            $SchemeData = [PSCustomObject]@{
                Id = ""
                Name = "No priority schemes found"
                Description = ""
                IsDefault = ""
                DefaultPriorityId = ""
                Self = ""
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $SchemeData
        }
    } else {
        # Handle error response
        $ErrorData = [PSCustomObject]@{
            Error = if ($Response.error) { $Response.error } else { "" }
            ErrorDescription = if ($Response.error_description) { $Response.error_description } else { "" }
            Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $ErrorData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Priority Schemes - GET Priority Schemes - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve priority schemes data: $($_.Exception.Message)"
    exit 1
}

