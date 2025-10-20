# Get-JiraProjects.ps1 - Fetch Projects from Jira for Web Launcher
#
# PURPOSE: Fetch available projects from a Jira environment and return as JSON
# USAGE: .\Get-JiraProjects.ps1 -Environment "onemain-sandbox"
#
# This script is called by MigrationLauncher.html to populate the project list

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('onemain', 'onemain-sandbox', 'omf-sandbox', 'omf-migration-sandbox')]
    [string]$Environment
)

$ErrorActionPreference = 'Stop'

# Load common functions
. (Join-Path $PSScriptRoot "src\_common.ps1")

# Environment mappings
$envUrls = @{
    'onemain' = 'https://onemain.atlassian.net'
    'onemain-sandbox' = 'https://onemain-migrationsandbox.atlassian.net'
    'omf-sandbox' = 'https://onemainfinancial-sandbox-575.atlassian.net'
    'omf-migration-sandbox' = 'https://onemainfinancial-migrationsandbox.atlassian.net'
}

$baseUrl = $envUrls[$Environment]

# Load credentials from .env
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found at: $envFile"
    exit 1
}

$email = $null
$apiToken = $null
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*USERNAME\s*=\s*(.*)$') {
        $email = $matches[1].Trim()
    }
    if ($_ -match '^\s*JIRA_API_TOKEN\s*=\s*(.*)$') {
        $apiToken = $matches[1].Trim()
    }
}

if (-not $email -or -not $apiToken) {
    Write-Error "USERNAME or JIRA_API_TOKEN not found in .env file"
    exit 1
}

# Create auth header
$hdr = New-BasicAuthHeader -Email $email -ApiToken $apiToken

# Fetch projects
try {
    $uri = "$($baseUrl.TrimEnd('/'))/rest/api/3/project/search?maxResults=100&orderBy=name"
    $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $hdr -ErrorAction Stop
    
    # Extract project list
    $projects = $response.values | Select-Object -Property @{
        Name='key'; Expression={$_.key}
    }, @{
        Name='name'; Expression={$_.name}
    }, @{
        Name='projectTypeKey'; Expression={$_.projectTypeKey}
    }, @{
        Name='id'; Expression={$_.id}
    }
    
    # Return as JSON
    $projects | ConvertTo-Json -Depth 3
    
} catch {
    # Return error as JSON
    @{
        error = $true
        message = $_.Exception.Message
    } | ConvertTo-Json
}

