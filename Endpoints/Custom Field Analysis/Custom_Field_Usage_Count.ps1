# Custom Field Usage Analysis
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

$AuthHeader = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))
    "Accept" = "application/json"
}

Write-Host "Getting all custom fields..." -ForegroundColor Yellow

try {
    $FieldsResponse = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/field" -Headers $AuthHeader -Method Get
    $CustomFields = $FieldsResponse | Where-Object { $_.custom -eq $true }

    Write-Host "Found $($CustomFields.Count) custom fields" -ForegroundColor Green

    $Results = @()
    $Counter = 0

    foreach ($field in $CustomFields) {
        $Counter++
        Write-Host "[$Counter/$($CustomFields.Count)] Analyzing: $($field.name)" -ForegroundColor Gray

        try {
            $JQL = "$($field.id) is not EMPTY"
            $EncodedJQL = [System.Uri]::EscapeDataString($JQL)
            $SearchUrl = "$BaseUrl/rest/api/3/search?jql=$EncodedJQL&maxResults=0"

            $SearchResponse = Invoke-RestMethod -Uri $SearchUrl -Headers $AuthHeader -Method Get
            $UsageCount = $SearchResponse.total

            $FieldType = if ($field.schema -and $field.schema.type) { $field.schema.type } else { "Unknown" }

            $MigrationPriority = "LOW"
            if ($UsageCount -gt 100) {
                $MigrationPriority = "HIGH"
            } elseif ($UsageCount -gt 10) {
                $MigrationPriority = "MEDIUM"
            }

            $Results += [PSCustomObject]@{
                FieldId = $field.id
                FieldName = $field.name
                FieldType = $FieldType
                UsageCount = $UsageCount
                MigrationPriority = $MigrationPriority
                IsSearchable = $field.searchable
                ClauseNames = ($field.clauseNames -join "; ")
            }

            Write-Host "  Usage count: $UsageCount issues" -ForegroundColor Green

        }
        catch {
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            $Results += [PSCustomObject]@{
                FieldId = $field.id
                FieldName = $field.name
                FieldType = "Error"
                UsageCount = -1
                MigrationPriority = "UNKNOWN"
                IsSearchable = $false
                ClauseNames = "Error"
            }
        }

        Start-Sleep -Milliseconds 100
    }

    $Results = $Results | Sort-Object UsageCount -Descending
    $Results | Export-Csv -Path "Custom_Field_Usage_Analysis.csv" -NoTypeInformation -Force

    Write-Host "`nCUSTOM FIELD USAGE SUMMARY:" -ForegroundColor Cyan
    $TotalFields = $Results.Count
    $HighUsage = ($Results | Where-Object { $_.UsageCount -gt 100 }).Count
    $MediumUsage = ($Results | Where-Object { $_.UsageCount -gt 10 -and $_.UsageCount -le 100 }).Count
    $LowUsage = ($Results | Where-Object { $_.UsageCount -le 10 -and $_.UsageCount -ge 0 }).Count
    $UnusedFields = ($Results | Where-Object { $_.UsageCount -eq 0 }).Count

    Write-Host "Total Custom Fields: $TotalFields"
    Write-Host "High Usage (>100): $HighUsage fields"
    Write-Host "Medium Usage (11-100): $MediumUsage fields"
    Write-Host "Low Usage (1-10): $LowUsage fields"
    Write-Host "Unused (0): $UnusedFields fields"

    Write-Host "`nTOP 10 MOST USED CUSTOM FIELDS:" -ForegroundColor Cyan
    $Results | Where-Object { $_.UsageCount -ge 0 } | Select-Object -First 10 | Format-Table FieldName, FieldType, UsageCount, MigrationPriority -AutoSize

    Write-Host "Report saved to: Custom_Field_Usage_Analysis.csv" -ForegroundColor Green

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
