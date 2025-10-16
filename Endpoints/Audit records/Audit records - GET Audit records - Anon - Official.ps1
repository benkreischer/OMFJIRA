# =============================================================================
# ENDPOINT: Audit records - GET Audit records
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-audit-records/#api-rest-api-3-auditing-record-get
#
# DESCRIPTION: Returns a list of audit records. The list can be filtered by date and text.
#
# SETUP:
# 1. Run this script to generate CSV data
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
# PARAMETERS (Optional)
# =============================================================================
$Limit = 1000  # Max number of records to return
$Filter = ""   # Text to filter by
$FromDate = "2023-01-01T00:00:00.000Z"  # Start date/time in ISO 8601 format
$ToDate = ""   # End date/time in ISO 8601 format

# =============================================================================
# API CALL (with pagination handling)
# =============================================================================
$Endpoint = "/rest/api/3/auditing/record"
$Offset = 0
$Result = @()

do {
    try {
        # Build query string
        $QueryParams = @{
            offset = $Offset
            limit = $Limit
        }
        
        if ($Filter) { $QueryParams.filter = $Filter }
        if ($FromDate) { $QueryParams.from = $FromDate }
        if ($ToDate) { $QueryParams.to = $ToDate }
        
        $QueryString = ($QueryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        $FullUrl = $BaseUrl + $Endpoint + "?" + $QueryString
        
        Write-Output "Fetching audit records starting at offset $Offset..."
        $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get
        
        if ($Response -and $Response.records) {
            foreach ($record in $Response.records) {
                $AuditData = [PSCustomObject]@{
                    Id = $record.id
                    Summary = $record.summary
                    RemoteAddress = $record.remoteAddress
                    AuthorKey = $record.authorKey
                    Created = $record.created
                    Category = $record.category
                    EventType = $record.eventType
                    Description = $record.description
                    ObjectItem = if ($record.objectItem) { $record.objectItem.name } else { "" }
                    AssociatedItem = if ($record.associatedItem) { $record.associatedItem.name } else { "" }
                    ChangedValues = if ($record.changedValues) { ($record.changedValues | ConvertTo-Json -Compress) } else { "" }
                    GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $Result += $AuditData
            }
        }
        
        $Offset += $Limit
        Write-Output "Processed $($Response.records.Count) audit records. Total so far: $($Result.Count)"
        
    } catch {
        Write-Error "Failed to retrieve audit records: $($_.Exception.Message)"
        break
    }
} while ($Response -and $Response.records -and $Response.records.Count -eq $Limit)

# =============================================================================
# EXPORT TO CSV
# =============================================================================
$OutputFile = "Audit records - GET Audit records - Anon - Official.csv"
$Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

Write-Output "Wrote $OutputFile with $($Result.Count) audit records."

