# =============================================================================
# ENDPOINT: Webhooks - GET Webhooks (OAuth2)
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-webhooks/
#
# DESCRIPTION: Returns a paginated list of the webhooks registered by the calling app.
#              This version uses OAuth 2.0 authentication for proper webhook access.
#
# PREREQUISITES:
# 1. OAuth2 Application registered in Atlassian Developer Console
# 2. Client ID and Client Secret obtained
# 3. Authorization Code flow completed to get access token
# 4. Appropriate scopes configured (read:jira-work)
#
# SETUP STEPS:
# 1. Update OAuth2 configuration below with your values
# 2. Run the OAuth2 authorization flow first
# 3. Execute this script with valid access token
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
# OAUTH2 CONFIGURATION - UPDATE THESE VALUES
# =============================================================================
$ClientId = "YOUR_CLIENT_ID"
$ClientSecret = "YOUR_CLIENT_SECRET"
$AccessToken = "YOUR_ACCESS_TOKEN"
$BaseUrl = $Params.BaseUrl

# OAuth2 Authorization URL (for reference)
$AuthUrl = "https://auth.atlassian.com/authorize"
$TokenUrl = "https://auth.atlassian.com/oauth/token"
$Scope = "read:jira-work manage:jira-webhook"

# =============================================================================
# OAUTH2 SETUP VALIDATION
# =============================================================================
function Test-OAuth2Configuration {
    $missingConfig = @()

    if ($ClientId -eq "YOUR_CLIENT_ID") { $missingConfig += "ClientId" }
    if ($ClientSecret -eq "YOUR_CLIENT_SECRET") { $missingConfig += "ClientSecret" }
    if ($AccessToken -eq "YOUR_ACCESS_TOKEN") { $missingConfig += "AccessToken" }

    if ($missingConfig.Count -gt 0) {
        Write-Host "OAuth2 Configuration Incomplete!" -ForegroundColor Red
        Write-Host "Missing configuration: $($missingConfig -join ', ')" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "SETUP INSTRUCTIONS:" -ForegroundColor Cyan
        Write-Host "1. Register OAuth2 app at: https://developer.atlassian.com/console/myapps/" -ForegroundColor Gray
        Write-Host "2. Configure scopes: $Scope" -ForegroundColor Gray
        Write-Host "3. Get authorization code from: $AuthUrl" -ForegroundColor Gray
        Write-Host "4. Exchange code for access token at: $TokenUrl" -ForegroundColor Gray
        Write-Host "5. Update the configuration variables in this script" -ForegroundColor Gray

        return $false
    }

    Write-Host "OAuth2 Configuration Complete" -ForegroundColor Green
    return $true
}

# =============================================================================
# OAUTH2 AUTHORIZATION FLOW HELPER
# =============================================================================
function Show-OAuth2Instructions {
    Write-Host "=== OAUTH2 SETUP INSTRUCTIONS ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Step 1: Register OAuth2 Application" -ForegroundColor Yellow
    Write-Host "Visit: https://developer.atlassian.com/console/myapps/" -ForegroundColor Gray
    Write-Host "Create new app and configure OAuth2 settings" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Step 2: Configure Scopes" -ForegroundColor Yellow
    Write-Host "Required scopes: $Scope" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Step 3: Authorization URL" -ForegroundColor Yellow
    Write-Host "$AuthUrl" -ForegroundColor Gray
    Write-Host "?audience=api.atlassian.com" -ForegroundColor Gray
    Write-Host "&client_id=$ClientId" -ForegroundColor Gray
    Write-Host "&scope=$([uri]::EscapeDataString($Scope))" -ForegroundColor Gray
    Write-Host "&redirect_uri=YOUR_REDIRECT_URI" -ForegroundColor Gray
    Write-Host "&state=YOUR_STATE" -ForegroundColor Gray
    Write-Host "&response_type=code" -ForegroundColor Gray
    Write-Host "&prompt=consent" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Step 4: Exchange Code for Token" -ForegroundColor Yellow
    Write-Host "POST to: $TokenUrl" -ForegroundColor Gray
    Write-Host "Body: grant_type=authorization_code&client_id=CLIENT_ID&client_secret=CLIENT_SECRET&code=AUTH_CODE&redirect_uri=REDIRECT_URI" -ForegroundColor Gray
}

# =============================================================================
# VALIDATE CONFIGURATION
# =============================================================================
if (-not (Test-OAuth2Configuration)) {
    Show-OAuth2Instructions

    # Create setup instructions CSV
    $SetupData = @(
        [PSCustomObject]@{
            Step = "1"
            Action = "Register OAuth2 Application"
            URL = "https://developer.atlassian.com/console/myapps/"
            Description = "Create new OAuth2 app"
        },
        [PSCustomObject]@{
            Step = "2"
            Action = "Configure Scopes"
            URL = $Scope
            Description = "Set required API permissions"
        },
        [PSCustomObject]@{
            Step = "3"
            Action = "Get Authorization Code"
            URL = $AuthUrl
            Description = "User authorization flow"
        },
        [PSCustomObject]@{
            Step = "4"
            Action = "Exchange for Access Token"
            URL = $TokenUrl
            Description = "Get OAuth2 access token"
        },
        [PSCustomObject]@{
            Step = "5"
            Action = "Update Script Configuration"
            URL = "This file"
            Description = "Set ClientId, ClientSecret, AccessToken"
        }
    )

    $SetupData | Export-Csv -Path "Webhooks - OAuth2 Setup Instructions.csv" -NoTypeInformation
    Write-Host "Setup instructions exported to: Webhooks - OAuth2 Setup Instructions.csv" -ForegroundColor Green
    exit 1
}

# =============================================================================
# API CALL WITH OAUTH2
# =============================================================================
$Endpoint = "/rest/api/3/webhook"
$FullUrl = $BaseUrl + $Endpoint

$Headers = @{
    "Authorization" = "Bearer $AccessToken"
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

try {
    Write-Host "Using OAuth2 Authentication" -ForegroundColor Green
    Write-Host "Calling API endpoint: $FullUrl" -ForegroundColor Cyan

    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $Headers -Method Get

    Write-Host "API call successful. Processing response..." -ForegroundColor Green

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Handle different response structures
        if ($Response -is [Array]) {
            foreach ($item in $Response) {
                $Result += $item
            }
        } elseif ($Response.values) {
            $Result += $Response.values
        } elseif ($Response.PSObject.Properties.Count -gt 0) {
            $Result += $Response
        } else {
            $Result += [PSCustomObject]@{
                Message = "No webhooks found"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                AuthenticationMethod = "OAuth2"
            }
        }
    } else {
        $Result += [PSCustomObject]@{
            Message = "No webhooks returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            AuthenticationMethod = "OAuth2"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Webhooks - GET Webhooks - OAuth2 - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Host "CSV file generated successfully: $(Get-Location)\$OutputFile" -ForegroundColor Green
    Write-Host "Records exported: $($Result.Count)" -ForegroundColor Cyan

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Host "`nSample data:" -ForegroundColor Cyan
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    $ErrorMessage = $_.Exception.Message
    Write-Host "Failed to retrieve webhooks: $ErrorMessage" -ForegroundColor Red

    if ($ErrorMessage -match "401|Unauthorized") {
        Write-Host "Token may be expired or invalid. Please refresh your OAuth2 access token." -ForegroundColor Yellow
    } elseif ($ErrorMessage -match "403|Forbidden") {
        Write-Host "Insufficient permissions. Ensure your OAuth2 app has webhook management scopes." -ForegroundColor Yellow
    } elseif ($ErrorMessage -match "400|Bad Request") {
        Write-Host "Check your OAuth2 configuration and token format." -ForegroundColor Yellow
    }

    # Create error record
    $ErrorData = [PSCustomObject]@{
        Error = $ErrorMessage
        AuthenticationMethod = "OAuth2"
        TokenStatus = "Check token validity"
        ScopeRequired = $Scope
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    $OutputFile = "Webhooks - GET Webhooks - OAuth2 - Official.csv"
    @($ErrorData) | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Host "Error details exported to: $OutputFile" -ForegroundColor Yellow
    exit 1
}
