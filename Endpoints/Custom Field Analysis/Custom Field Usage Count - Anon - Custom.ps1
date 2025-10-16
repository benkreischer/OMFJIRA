# =============================================================================
# ENDPOINT: Custom Field Usage Count Analysis
# =============================================================================
#
# PURPOSE: Count how many times each custom field is used across all issues
# USE CASE: Migration planning - identify which custom fields to migrate to standard fields
#
# APPROACH:
# 1. Get all custom fields from the fields endpoint
# 2. For each custom field, search issues that have that field populated
# 3. Count the usage and analyze field types
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# STEP 1: GET ALL CUSTOM FIELDS
# =============================================================================
Write-Host "`n1. Getting all custom fields..." -ForegroundColor Yellow

try {
    $FieldsResponse = Invoke-RestMethod -Uri "$BaseUrl/rest/api/3/field" -Headers $AuthHeader -Method Get
    $CustomFields = $FieldsResponse | Where-Object { $_.custom -eq $true }

    Write-Host "   Found $($CustomFields.Count) custom fields" -ForegroundColor Green

    # =============================================================================
    # STEP 2: ANALYZE EACH CUSTOM FIELD USAGE
    # =============================================================================
    Write-Host "`n2. Analyzing custom field usage..." -ForegroundColor Yellow

    $Results = @()
    $Counter = 0

    foreach ($field in $CustomFields) {
        $Counter++
        Write-Host "   [$Counter/$($CustomFields.Count)] Analyzing: $($field.name)" -ForegroundColor Gray

        try {
            # Use JQL to count issues where this field is not empty
            $JQL = "$($field.id) is not EMPTY"
            $EncodedJQL = [System.Uri]::EscapeDataString($JQL)
            $SearchUrl = "$BaseUrl/rest/api/3/search?jql=$EncodedJQL" + "`&maxResults=0"

            $SearchResponse = Invoke-RestMethod -Uri $SearchUrl -Headers $AuthHeader -Method Get
            $UsageCount = $SearchResponse.total

            # Get field schema information
            $FieldType = "Unknown"
            if ($field.schema -and $field.schema.type) {
                $FieldType = $field.schema.type
            }

            $FieldSystem = "Unknown"
            if ($field.schema -and $field.schema.system) {
                $FieldSystem = $field.schema.system
            }

            # Determine migration priority
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
                FieldSystem = $FieldSystem
                UsageCount = $UsageCount
                IsSearchable = $field.searchable
                IsOrderable = $field.orderable
                NavigableKey = $field.navigable
                ClauseNames = ($field.clauseNames -join "; ")
                MigrationPriority = $MigrationPriority
            }

            # Determine color based on usage count
            $Color = "Green"
            if ($UsageCount -gt 50) {
                $Color = "Red"
            } elseif ($UsageCount -gt 10) {
                $Color = "Yellow"
            }

            Write-Host "     Usage count: $UsageCount issues" -ForegroundColor $Color

        }
        catch {
            Write-Host "     Error analyzing field: $($_.Exception.Message)" -ForegroundColor Red
            $Results += [PSCustomObject]@{
                FieldId = $field.id
                FieldName = $field.name
                FieldType = "Error"
                FieldSystem = "Error"
                UsageCount = -1
                IsSearchable = $false
                IsOrderable = $false
                NavigableKey = $false
                ClauseNames = "Error: $($_.Exception.Message)"
                MigrationPriority = "UNKNOWN"
            }
        }

        # Small delay to avoid overwhelming the API
        Start-Sleep -Milliseconds 100
    }

    # =============================================================================
    # STEP 3: GENERATE ANALYSIS REPORT
    # =============================================================================
    Write-Host "`n3. Generating analysis report..." -ForegroundColor Yellow

    # Sort by usage count (highest first)
    $Results = $Results | Sort-Object UsageCount -Descending

    # Export detailed results
    $Results | Export-Csv -Path "Custom_Field_Usage_Analysis.csv" -NoTypeInformation -Force

    # =============================================================================
    # STEP 4: SUMMARY REPORT
    # =============================================================================
    Write-Host "`n📊 CUSTOM FIELD USAGE SUMMARY:" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan

    $TotalFields = $Results.Count
    $HighUsage = ($Results | Where-Object { $_.UsageCount -gt 100 }).Count
    $MediumUsage = ($Results | Where-Object { $_.UsageCount -gt 10 -and $_.UsageCount -le 100 }).Count
    $LowUsage = ($Results | Where-Object { $_.UsageCount -le 10 -and $_.UsageCount -ge 0 }).Count
    $UnusedFields = ($Results | Where-Object { $_.UsageCount -eq 0 }).Count

    Write-Host "Total Custom Fields: $TotalFields" -ForegroundColor White
    Write-Host "High Usage (>100 issues): $HighUsage fields" -ForegroundColor Red
    Write-Host "Medium Usage (11-100 issues): $MediumUsage fields" -ForegroundColor Yellow
    Write-Host "Low Usage (1-10 issues): $LowUsage fields" -ForegroundColor Green
    Write-Host "Unused Fields (0 issues): $UnusedFields fields" -ForegroundColor Gray

    Write-Host "`n🎯 TOP 10 MOST USED CUSTOM FIELDS:" -ForegroundColor Cyan
    $Results | Where-Object { $_.UsageCount -ge 0 } | Select-Object -First 10 | Format-Table FieldName, FieldType, UsageCount, MigrationPriority -AutoSize

    Write-Host "`n💡 MIGRATION RECOMMENDATIONS:" -ForegroundColor Green
    Write-Host "HIGH Priority (>100 uses): Consider keeping or mapping to standard fields" -ForegroundColor Red
    Write-Host "MEDIUM Priority (11-100 uses): Evaluate case-by-case for migration" -ForegroundColor Yellow
    Write-Host "LOW Priority (1-10 uses): Good candidates for elimination or consolidation" -ForegroundColor Green
    Write-Host "UNUSED (0 uses): Safe to remove after verification" -ForegroundColor Gray

    Write-Host "`n📁 Detailed report saved to: Custom_Field_Usage_Analysis.csv" -ForegroundColor Green

} catch {
    Write-Host "Error getting custom fields: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
