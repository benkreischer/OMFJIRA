# =============================================================================
# ENDPOINT: Project Categories - GET Project Categories
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-categories/
#
# DESCRIPTION: Returns project categories using basic authentication.
# This endpoint provides access to project categorization information.
#
# SETUP: 
# 1. Run this script in PowerShell
# 2. CSV file will be generated automatically
#
# =============================================================================


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
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/projectCategory"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Host "Calling API endpoint: $FullUrl"
    
    $Headers = Get-RequestHeaders -Parameters $Params
    
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers -ErrorAction Stop
    
    Write-Host "API call successful. Processing response..."
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Results = @()
    
    if ($Response -and $Response.Count -gt 0) {
        foreach ($Category in $Response) {
            $Result = [PSCustomObject]@{
                Id = if ($Category.id) { $Category.id.ToString() } else { "" }
                Name = if ($Category.name) { $Category.name } else { "" }
                Description = if ($Category.description) { $Category.description } else { "" }
                Self = if ($Category.self) { $Category.self } else { "" }
                GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
            $Results += $Result
        }
    } else {
        # Handle empty response
        $Result = [PSCustomObject]@{
            Id = ""
            Name = ""
            Description = ""
            Self = ""
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Project Categories - GET Project Categories - Anon - Official.csv"
    $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "CSV file generated successfully: $CsvPath"
    Write-Host "Records exported: $($Results.Count)"
    
    # Display sample data
    if ($Results.Count -gt 0) {
        Write-Host "`nSample data:"
        $Results | Select-Object -First 3 | Format-Table -AutoSize
    }
    
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        ErrorDescription = $_.Exception.ToString()
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Project Categories - GET Project Categories - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}

