# Custom Field Usage Analysis - Updated Version
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

$AuthHeader = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))
    "Accept" = "application/json"
}

Write-Host "Custom Field Usage Analysis - Testing Approach" -ForegroundColor Cyan

# First, get custom fields that appear on a sample issue to find active ones
Write-Host "Getting sample issue to find active custom fields..." -ForegroundColor Yellow
$SampleIssue = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/issue/ORL-8004" -Headers $AuthHeader -Method Get

# Extract custom field IDs that actually exist on issues
$ActiveCustomFields = $SampleIssue.fields.PSObject.Properties | Where-Object { $_.Name -match "^customfield_" } | Select-Object Name

Write-Host "Found $($ActiveCustomFields.Count) active custom field slots on sample issue" -ForegroundColor Green

# Test a few specific custom fields that have values
$TestFields = @(
    "customfield_11267",  # Health Status (migrated 2) - has value "On Track"
    "customfield_10979",  # Has value "Applications Software"
    "customfield_11139",  # Has value "No"
    "customfield_10605",  # Has value "On Track"
    "customfield_11015",  # Has value "No"
    "customfield_10020"   # Sprint field with data
)

Write-Host "`nTesting specific custom fields for usage counting..." -ForegroundColor Yellow

$Results = @()

foreach ($fieldId in $TestFields) {
    Write-Host "Testing $fieldId..." -ForegroundColor Gray

    try {
        # Try to count issues with this field populated
        $JQL = "$fieldId is not EMPTY"
        $EncodedJQL = [System.Uri]::EscapeDataString($JQL)
        $SearchUrl = "$BaseUrl/rest/api/3/search?jql=$EncodedJQL" + "&maxResults=0"

        $SearchResponse = Invoke-RestMethod -Uri $SearchUrl -Headers $AuthHeader -Method Get
        $UsageCount = $SearchResponse.total

        # Get field metadata
        $AllFields = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/field" -Headers $AuthHeader -Method Get
        $FieldInfo = $AllFields | Where-Object { $_.id -eq $fieldId }

        $MigrationPriority = "LOW"
        if ($UsageCount -gt 100) {
            $MigrationPriority = "HIGH"
        } elseif ($UsageCount -gt 10) {
            $MigrationPriority = "MEDIUM"
        }

        $Results += [PSCustomObject]@{
            FieldId = $fieldId
            FieldName = if ($FieldInfo) { $FieldInfo.name } else { "Unknown" }
            FieldType = if ($FieldInfo -and $FieldInfo.schema) { $FieldInfo.schema.type } else { "Unknown" }
            UsageCount = $UsageCount
            MigrationPriority = $MigrationPriority
            IsSearchable = if ($FieldInfo) { $FieldInfo.searchable } else { $false }
            ClauseNames = if ($FieldInfo) { ($FieldInfo.clauseNames -join "; ") } else { "" }
            SampleValue = $SampleIssue.fields.$fieldId
            Status = "SUCCESS"
        }

        Write-Host "  SUCCESS: $UsageCount issues use this field" -ForegroundColor Green

    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        $Results += [PSCustomObject]@{
            FieldId = $fieldId
            FieldName = "Error"
            FieldType = "Error"
            UsageCount = -1
            MigrationPriority = "UNKNOWN"
            IsSearchable = $false
            ClauseNames = "Error"
            SampleValue = "Error"
            Status = "ERROR: $($_.Exception.Message)"
        }
    }
}

# Export results
$Results | Export-Csv -Path "Custom_Field_Test_Results.csv" -NoTypeInformation -Force

Write-Host "`nTEST RESULTS:" -ForegroundColor Cyan
$Results | Format-Table FieldId, FieldName, UsageCount, MigrationPriority, Status -AutoSize

Write-Host "`nResults exported to: Custom_Field_Test_Results.csv" -ForegroundColor Green
