# =============================================================================
# ENDPOINT: Issue Security Schemes - GET Issue security schemes
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-security-schemes/#api-rest-api-3-issuesecurityschemes-get
#
# DESCRIPTION: Returns all issue security schemes.
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
$Endpoint = "/rest/api/3/issuesecurityschemes"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.issueSecuritySchemes) {
        # Response has security schemes - expand each scheme
        foreach ($scheme in $Response.issueSecuritySchemes) {
            $SchemeData = [PSCustomObject]@{
                Self = if ($scheme.self) { $scheme.self } else { "" }
                Id = if ($scheme.id) { $scheme.id } else { "" }
                Name = if ($scheme.name) { $scheme.name } else { "" }
                Description = if ($scheme.description) { $scheme.description } else { "" }
                Levels = if ($scheme.levels) { ($scheme.levels | ForEach-Object { "$($_.name) ($($_.id))" }) -join "; " } else { "" }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $SchemeData
        }
    } else {
        # No response data or schemes
        $Result += [PSCustomObject]@{
            Message = "No data returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Security Schemes - GET Issue security schemes - Anon - Official.csv"
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
    $OutputFile = "Issue Security Schemes - GET Issue security schemes - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

