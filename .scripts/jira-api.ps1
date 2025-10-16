# Jira REST API PowerShell Script
# Usage: .\jira-api.ps1 -Endpoint "workflow" -Method "GET"
#        .\jira-api.ps1 -Endpoint "issue/PROJ-123" -Method "GET"

param(
    [Parameter(Mandatory=$true)]
    [string]$Endpoint,
    
    [Parameter(Mandatory=$false)]
    [string]$Method = "GET",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "ben.kreischer.ce@omf.com",
    
    [Parameter(Mandatory=$false)]
    [string]$BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    
    [Parameter(Mandatory=$false)]
    [string]$Body = $null
)

# Function to get API token securely
function Get-ApiToken {
    $token = Read-Host "Enter your Jira API token" -AsSecureString
    $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
    return $plainToken
}

# Function to create authentication header
function Get-AuthHeader {
    param([string]$User, [string]$Token)
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User, $Token)))
    return @{Authorization=("Basic {0}" -f $base64AuthInfo)}
}

try {
    # Get API token
    $apiToken = Get-ApiToken
    
    # Create authentication header
    $headers = Get-AuthHeader -User $Username -Token $apiToken
    
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
