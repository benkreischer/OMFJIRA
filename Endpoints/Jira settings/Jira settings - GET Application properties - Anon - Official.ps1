# =============================================================================
# ENDPOINT: Jira settings - GET Application properties
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-jira-settings/#api-rest-api-3-application-properties-get
#
# DESCRIPTION: Returns all application properties.
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
$Endpoint = "/rest/api/3/application-properties"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching application properties..."
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.Count -gt 0) {
        foreach ($property in $Response) {
            $PropertyData = [PSCustomObject]@{
                Id = $property.id
                Key = $property.key
                Name = $property.name
                Description = if ($property.desc) { $property.desc } else { "" }
                Type = $property.type
                DefaultValue = if ($property.defaultValue) { $property.defaultValue } else { "" }
                Value = if ($property.value) { $property.value } else { "" }
                AllowedValues = if ($property.allowedValues) { ($property.allowedValues | ForEach-Object { $_.value }) -join "; " } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $PropertyData
        }
    } else {
        Write-Output "No application properties found"
        $PropertyData = [PSCustomObject]@{
            Id = ""; Key = ""; Name = ""; Description = ""; Type = ""; 
            DefaultValue = ""; Value = ""; AllowedValues = ""; 
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $PropertyData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Jira settings - GET Application properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Output "Failed to retrieve application properties: $($_.Exception.Message)"
    $PropertyData = [PSCustomObject]@{
        Id = ""; Key = ""; Name = ""; Description = ""; Type = ""; 
        DefaultValue = ""; Value = ""; AllowedValues = ""; 
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($PropertyData)
    $OutputFile = "Jira settings - GET Application properties - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force
}

