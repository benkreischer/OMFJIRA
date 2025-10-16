# =============================================================================
# UPDATE OAUTH2 ENDPOINT SCRIPTS
# =============================================================================
# This script updates all OAuth2 endpoint PowerShell scripts to use proper OAuth2 authentication
# instead of basic authentication

Write-Host "=== UPDATING OAUTH2 ENDPOINT SCRIPTS ===" -ForegroundColor Green
Write-Host "This will update all OAuth2 endpoint scripts to use proper OAuth2 authentication" -ForegroundColor Yellow

# Load OAuth2 configuration
$configFile = "oauth2_config.json"
if (-not (Test-Path $configFile)) {
    Write-Error "OAuth2 config file not found: $configFile"
    Write-Host "Please run the OAuth2 setup first: .\OAuth2_Authentication_Manager.ps1 -Action setup" -ForegroundColor Yellow
    exit 1
}

$config = Get-Content $configFile | ConvertFrom-Json

# Check if OAuth2 is properly configured
if (-not $config.oauth2.client_id -or $config.oauth2.client_id -eq "YOUR_OAUTH2_CLIENT_ID") {
    Write-Error "OAuth2 not properly configured. Please update oauth2_config.json with your Client ID and Client Secret"
    Write-Host "See OAUTH2_SETUP_GUIDE.md for detailed instructions" -ForegroundColor Yellow
    exit 1
}

# Get all OAuth2 PowerShell scripts
$oauth2Scripts = Get-ChildItem -Path ".endpoints" -Recurse -Filter "*OAuth2*.ps1" | 
    Where-Object { 
        $_.FullName -like "*OAuth2*" -or
        $_.FullName -like "*Enterprise Features (OAuth2)*" -or
        $_.FullName -like "*Audit & Compliance (OAuth2)*" -or
        $_.FullName -like "*Advanced Workflows (OAuth2)*" -or
        $_.FullName -like "*Advanced Security (OAuth2)*" -or
        $_.FullName -like "*Advanced Permissions (OAuth2)*" -or
        $_.FullName -like "*Advanced Analytics (OAuth2)*" -or
        $_.FullName -like "*Integration Management (OAuth2)*"
    } | 
    Sort-Object FullName

Write-Host "Found $($oauth2Scripts.Count) OAuth2 PowerShell scripts to update" -ForegroundColor Cyan

$updatedCount = 0
$errorCount = 0

foreach ($script in $oauth2Scripts) {
    $scriptName = $script.BaseName
    $scriptPath = $script.FullName
    $scriptNumber = $updatedCount + $errorCount + 1
    
    Write-Host "[$scriptNumber/$($oauth2Scripts.Count)] Updating: $scriptName" -ForegroundColor White
    
    try {
        # Read the current script content
        $scriptContent = Get-Content $scriptPath -Raw
        
        # Create new OAuth2-based script content
        $newScriptContent = @"
# PowerShell script to execute $scriptName endpoint
# This script uses OAuth2 authentication for advanced Jira API endpoints

# Load OAuth2 configuration
`$configFile = "oauth2_config.json"
if (-not (Test-Path `$configFile)) {
    Write-Error "OAuth2 config file not found: `$configFile"
    Write-Host "Please run the OAuth2 setup first: .\OAuth2_Authentication_Manager.ps1 -Action setup" -ForegroundColor Yellow
    exit 1
}

`$config = Get-Content `$configFile | ConvertFrom-Json

# Check if OAuth2 token is available
if (-not `$config.oauth2.access_token) {
    Write-Error "No OAuth2 access token available. Please authorize first:"
    Write-Host ".\OAuth2_Authentication_Manager.ps1 -Action authorize" -ForegroundColor Yellow
    exit 1
}

# Check if token is expired and refresh if needed
`$expiresAt = [DateTime]::Parse(`$config.oauth2.expires_at)
if ((Get-Date) -gt `$expiresAt) {
    Write-Host "Access token expired. Refreshing..." -ForegroundColor Yellow
    .\OAuth2_Authentication_Manager.ps1 -Action refresh
    `$config = Get-Content `$configFile | ConvertFrom-Json
}

# Prepare OAuth2 headers
`$headers = @{
    "Authorization" = "Bearer `$(`$config.oauth2.access_token)"
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

Write-Host "=== `$($scriptName.ToUpper()) ===" -ForegroundColor Green

try {
    Write-Host "Fetching data from `$scriptName endpoint using OAuth2..." -ForegroundColor Yellow
    
    # Determine the appropriate API endpoint based on script name
    `$apiPath = ""
    if (`$scriptName -like "*Enterprise User Management*") { 
        `$apiPath = "/rest/api/3/users/search" 
    }
    elseif (`$scriptName -like "*Enterprise Security*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Enterprise Organization*") { 
        `$apiPath = "/rest/api/3/group/bulk" 
    }
    elseif (`$scriptName -like "*Enterprise License*") { 
        `$apiPath = "/rest/api/3/license" 
    }
    elseif (`$scriptName -like "*Enterprise Data*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Enterprise Compliance*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Regulatory Compliance*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Data Privacy*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Comprehensive Audit*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Compliance Risk*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Compliance Reporting*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Workflow Performance*") { 
        `$apiPath = "/rest/api/3/workflow" 
    }
    elseif (`$scriptName -like "*Workflow Optimization*") { 
        `$apiPath = "/rest/api/3/workflow" 
    }
    elseif (`$scriptName -like "*Workflow Compliance*") { 
        `$apiPath = "/rest/api/3/workflow" 
    }
    elseif (`$scriptName -like "*Workflow Automation*") { 
        `$apiPath = "/rest/api/3/workflow" 
    }
    elseif (`$scriptName -like "*Threat Detection*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Security Risk*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Security Incident*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Security Compliance*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Advanced Security*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Permission Security*") { 
        `$apiPath = "/rest/api/3/permissions" 
    }
    elseif (`$scriptName -like "*Permission Optimization*") { 
        `$apiPath = "/rest/api/3/permissions" 
    }
    elseif (`$scriptName -like "*Permission Compliance*") { 
        `$apiPath = "/rest/api/3/permissions" 
    }
    elseif (`$scriptName -like "*Granular Permission*") { 
        `$apiPath = "/rest/api/3/permissions" 
    }
    elseif (`$scriptName -like "*Team Performance*") { 
        `$apiPath = "/rest/api/3/search" 
    }
    elseif (`$scriptName -like "*Cross-Project*") { 
        `$apiPath = "/rest/api/3/search" 
    }
    elseif (`$scriptName -like "*Advanced Project*") { 
        `$apiPath = "/rest/api/3/project" 
    }
    elseif (`$scriptName -like "*Third-Party Integrations*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Integration Security*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Integration Performance*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Integration Health*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    elseif (`$scriptName -like "*Integration Configuration*") { 
        `$apiPath = "/rest/api/3/audit/auditRecords" 
    }
    else { 
        `$apiPath = "/rest/api/3/myself" # Default fallback
    }
    
    `$endpoint = "`$(`$config.jira.base_url)" + "`$apiPath"
    
    Write-Host "Calling OAuth2 API endpoint: `$endpoint" -ForegroundColor Cyan
    
    # Make the API call with OAuth2 authentication
    `$response = Invoke-RestMethod -Uri `$endpoint -Method GET -Headers `$headers
    
    # Process the response and convert to CSV format
    `$csvData = @()
    
    if (`$response -is [array]) {
        # Handle array responses
        foreach (`$item in `$response) {
            if (`$item -is [PSCustomObject]) {
                `$csvData += `$item
            } else {
                `$csvData += [PSCustomObject]@{ Value = `$item }
            }
        }
    } elseif (`$response -is [PSCustomObject]) {
        # Handle object responses
        `$csvData += `$response
    } else {
        # Handle other response types
        `$csvData += [PSCustomObject]@{ Response = `$response }
    }
    
    # Export to CSV
    `$outputFile = "`$scriptName.csv"
    `$csvData | Export-Csv -Path `$outputFile -NoTypeInformation
    
    Write-Host "✓ SUCCESS: Generated `$outputFile with `$(`$csvData.Count) records" -ForegroundColor Green
    Write-Host "OAuth2 authentication successful!" -ForegroundColor Cyan

} catch {
    Write-Error "Error occurred: `$(`$_.Exception.Message)"
    Write-Host "This OAuth2 endpoint may require specific parameters or may not be available." -ForegroundColor Yellow
    Write-Host "Check OAuth2 token validity: .\OAuth2_Authentication_Manager.ps1 -Action test" -ForegroundColor Gray
}
"@
        
        # Write the updated script content
        Set-Content -Path $scriptPath -Value $newScriptContent -Encoding UTF8
        
        Write-Host "  ✓ UPDATED: $scriptName" -ForegroundColor Green
        $updatedCount++
        
    } catch {
        Write-Host "  ✗ ERROR: $scriptName - $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "=== UPDATE SUMMARY ===" -ForegroundColor Green
Write-Host "Total OAuth2 Scripts: $($oauth2Scripts.Count)" -ForegroundColor White
Write-Host "Successfully Updated: $updatedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red

if ($errorCount -eq 0) {
    Write-Host ""
    Write-Host "✓ All OAuth2 endpoint scripts have been updated!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "1. Ensure OAuth2 is properly configured and authorized" -ForegroundColor Gray
    Write-Host "2. Test OAuth2 authentication: .\OAuth2_Authentication_Manager.ps1 -Action test" -ForegroundColor Gray
    Write-Host "3. Run all endpoints: .\execute_all_get_endpoints.ps1" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "Some scripts failed to update. Please check the errors above." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "OAuth2 endpoint scripts update completed!" -ForegroundColor Green
