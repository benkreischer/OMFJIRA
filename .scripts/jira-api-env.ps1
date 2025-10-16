# Jira REST API PowerShell Script using Environment Variables
# Secure approach - no credentials stored in the script

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint,
    
    [Parameter(Mandatory=$false)]
    [string]$Method = "GET",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = $env:JIRA_USERNAME,
    
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = $env:JIRA_BASE_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$Body = $null
)

# Function to get credentials from environment variables
function Get-JiraCredentials {
    $username = if ($Username) { $Username } else { $env:JIRA_USERNAME }
    $apiToken = $env:JIRA_API_TOKEN
    
    if (-not $username) {
        Write-Error "Jira username not found. Set JIRA_USERNAME environment variable or pass -Username parameter"
        Write-Host "Example: `$env:JIRA_USERNAME = 'your-email@domain.com'" -ForegroundColor Yellow
        exit 1
    }
    
    if (-not $apiToken) {
        Write-Error "Jira API token not found. Set JIRA_API_TOKEN environment variable"
        Write-Host "Example: `$env:JIRA_API_TOKEN = 'your-api-token'" -ForegroundColor Yellow
        Write-Host "Get your token from: https://id.atlassian.com/manage-profile/security/api-tokens" -ForegroundColor Yellow
        exit 1
    }
    
    return @{
        Username = $username
        ApiToken = $apiToken
    }
}

# Function to create authentication header
function Get-AuthHeader {
    param([string]$User, [string]$Token)
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $Token)))
    return @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

try {
    # Get credentials from environment
    $creds = Get-JiraCredentials
    $username = $creds.Username
    $apiToken = $creds.ApiToken
    
    # Set default base URL if not provided
    if (-not $BaseUrl) {
        $BaseUrl = if ($env:JIRA_BASE_URL) { $env:JIRA_BASE_URL } else { "https://onemain.atlassian.net/rest/api/3" }
    }
    
    # Create authentication header
    $headers = Get-AuthHeader -User $username -Token $apiToken
    
    # Build full URL
    $fullUrl = if ($Endpoint.StartsWith("http")) { $Endpoint } else { "$BaseUrl/$Endpoint" }
    
    # Prepare parameters for Invoke-RestMethod
    $params = @{
        Uri = $fullUrl
        Method = $Method
        Headers = $headers
    }
    
    # Add body if provided
    if ($Body) {
        $params.Body = $Body
        $params.ContentType = "application/json"
    }
    
    Write-Host "Making $Method request to: $fullUrl" -ForegroundColor Green
    Write-Host "Using username: $username" -ForegroundColor Gray
    
    # Make the API call
    $result = Invoke-RestMethod @params
    
    # Display results
    Write-Host "`nAPI Response:" -ForegroundColor Yellow
    $result | ConvertTo-Json -Depth 10
    
    return $result
    
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    if ($_.Exception.Response) {
        $statusCode = $_.Exception.Response.StatusCode
        Write-Error "HTTP Status: $statusCode"
    }
    throw
}
