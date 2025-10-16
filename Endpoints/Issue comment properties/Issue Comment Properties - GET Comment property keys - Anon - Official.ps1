# =============================================================================
# ENDPOINT: Issue Comment Properties - GET Comment property keys
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comment-properties/#api-rest-api-3-comment-commentid-properties-get
#
# DESCRIPTION: Returns the keys of all properties for a comment.
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
# PARAMETER - REQUIRED
# =============================================================================
$CommentId = "326710" # <-- IMPORTANT: Replace with valid Comment ID

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/comment/$CommentId/properties"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.keys) {
        # Response has property keys - expand the keys array
        if ($Response.keys.Count -gt 0) {
            foreach ($key in $Response.keys) {
                $PropertyData = [PSCustomObject]@{
                    Key = if ($key.key) { $key.key } else { $key }
                    Self = if ($key.self) { $key.self } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $PropertyData
            }
        } else {
            # No property keys found
            $Result += [PSCustomObject]@{
                Key = ""
                Self = ""
                Message = "No comment properties found"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        # No response data or keys property
        $Result += [PSCustomObject]@{
            Key = ""
            Self = ""
            Message = "No data returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Comment Properties - GET Comment property keys - Anon - Official.csv"
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
    $OutputFile = "Issue Comment Properties - GET Comment property keys - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}

