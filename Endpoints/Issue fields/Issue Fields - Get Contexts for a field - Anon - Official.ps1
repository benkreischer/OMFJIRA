# PowerShell script to execute Issue Fields - Get Contexts for a field endpoint
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

$AuthString = "$Username" + ":" + "$ApiToken"
$AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
$AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)

Write-Host "=== ISSUE FIELDS - GET CONTEXTS FOR A FIELD ===" -ForegroundColor Green

try {
    Write-Host "Fetching data from Issue Fields - Get Contexts for a field endpoint..." -ForegroundColor Yellow
    
    # Use a known custom field ID (customfield_10612 - Category dropdown field) to test the endpoint
    $FieldId = $Params.CommonParameters.FieldId
    $fullUrl = "$BaseUrl/rest/api/3/field/$fieldId/context"
    Write-Host "Calling API endpoint: $fullUrl" -ForegroundColor Cyan
    
    $response = Invoke-RestMethod -Uri $fullUrl -Method GET -Headers @{
        "Authorization" = $AuthHeader
        "Accept" = "application/json"
    }
    
    Write-Host "Processing response data..." -ForegroundColor Yellow
    
    # Process contexts response - should be an array of context objects
    $TransformedData = @()
    
    if ($response -is [array]) {
        foreach ($context in $response) {
            $id = if ($context.id) { $context.id } else { "" }
            $name = if ($context.name) { $context.name } else { "" }
            $description = if ($context.description) { $context.description } else { "" }
            $isGlobalContext = if ($context.isGlobalContext -ne $null) { $context.isGlobalContext.ToString().ToLower() } else { "false" }
            $isAnyIssueType = if ($context.isAnyIssueType -ne $null) { $context.isAnyIssueType.ToString().ToLower() } else { "false" }
            $self = if ($context.self) { $context.self } else { "" }
            
            $record = [PSCustomObject]@{
                Id = $id
                Name = $name
                Description = $description
                IsGlobalContext = $isGlobalContext
                IsAnyIssueType = $isAnyIssueType
                Self = $self
            }
            $TransformedData += $record
        }
    }
    
    # Export to CSV
    $csvPath = "$PSScriptRoot\Issue Fields - Get Contexts for a field - Anon.csv"
    $TransformedData | Export-Csv -Path $csvPath -NoTypeInformation
    
    Write-Host "Data exported to: $csvPath" -ForegroundColor Green
    Write-Host "Total records found: $($TransformedData.Count)" -ForegroundColor Cyan
    
} catch {
    Write-Host "Error occurred: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

