# =============================================================================
# ENDPOINT: Issue Fields - Get Fields in Trash Paginated
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-fields/#api-rest-api-3-field-search-get
#
# DESCRIPTION: Returns a paginated list of fields in the trash. The list may be restricted to fields whose field name or description partially match a string.
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
$Endpoint = "/rest/api/3/field/search?isInTrash=true"
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
    
    # Extract values array from response (matching .pq file logic)
    $Values = if ($Response.values) { $Response.values } else { @() }
    
    if ($Values -and $Values.Count -gt 0) {
        foreach ($Field in $Values) {
            # Handle schema object
            $SchemaType = if ($Field.schema -and $Field.schema.type) { $Field.schema.type } else { "" }
            $SchemaItems = if ($Field.schema -and $Field.schema.items) { $Field.schema.items } else { "" }
            $SchemaSystem = if ($Field.schema -and $Field.schema.system) { $Field.schema.system } else { "" }
            $SchemaCustom = if ($Field.schema -and $Field.schema.custom) { $Field.schema.custom } else { "" }
            $SchemaCustomId = if ($Field.schema -and $Field.schema.customId) { $Field.schema.customId } else { "" }
            $SchemaConfiguration = if ($Field.schema -and $Field.schema.configuration) { $Field.schema.configuration } else { "" }
            
            # Handle scope object
            $ScopeType = if ($Field.scope -and $Field.scope.type) { $Field.scope.type } else { "" }
            $ScopeProjectId = if ($Field.scope -and $Field.scope.project -and $Field.scope.project.id) { $Field.scope.project.id } else { "" }
            $ScopeProjectKey = if ($Field.scope -and $Field.scope.project -and $Field.scope.project.key) { $Field.scope.project.key } else { "" }
            
            # Handle clauseNames array
            $ClauseNames = if ($Field.clauseNames -and $Field.clauseNames.Count -gt 0) { ($Field.clauseNames -join "; ") } else { "" }
            
            $Result = [PSCustomObject]@{
                Id = if ($Field.id) { $Field.id } else { "" }
                Key = if ($Field.key) { $Field.key } else { "" }
                Name = if ($Field.name) { $Field.name } else { "" }
                Custom = if ($Field.custom -ne $null) { $Field.custom.ToString().ToLower() } else { "false" }
                Orderable = if ($Field.orderable -ne $null) { $Field.orderable.ToString().ToLower() } else { "false" }
                Navigable = if ($Field.navigable -ne $null) { $Field.navigable.ToString().ToLower() } else { "false" }
                Searchable = if ($Field.searchable -ne $null) { $Field.searchable.ToString().ToLower() } else { "false" }
                ClauseNames = $ClauseNames
                SchemaType = $SchemaType
                SchemaItems = $SchemaItems
                SchemaSystem = $SchemaSystem
                SchemaCustom = $SchemaCustom
                SchemaCustomId = $SchemaCustomId
                SchemaConfiguration = $SchemaConfiguration
                ScopeType = $ScopeType
                ScopeProjectId = $ScopeProjectId
                ScopeProjectKey = $ScopeProjectKey
                GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            }
            $Results += $Result
        }
    } else {
        # Handle empty response
        $Result = [PSCustomObject]@{
            Id = ""
            Key = ""
            Name = ""
            Custom = "false"
            Orderable = "false"
            Navigable = "false"
            Searchable = "false"
            ClauseNames = ""
            SchemaType = ""
            SchemaItems = ""
            SchemaSystem = ""
            SchemaCustom = ""
            SchemaCustomId = ""
            SchemaConfiguration = ""
            ScopeType = ""
            ScopeProjectId = ""
            ScopeProjectKey = ""
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Issue Fields - Get Fields in Trash Paginated - Anon - Official.csv"
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
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Issue Fields - Get Fields in Trash Paginated - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}
