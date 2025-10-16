# =============================================================================
# GET WORKSPACE ID USING ORGANIZATION API KEY
# =============================================================================
#
# DESCRIPTION: Retrieves workspace ID using Organization API Key and updates .env
#
# USAGE: .\GetWorkspaceId.ps1
#
# =============================================================================

Write-Host "=== RETRIEVING WORKSPACE ID ===" -ForegroundColor Cyan
Write-Host ""

# Load .env file
if (-not (Test-Path ".env")) {
    Write-Error ".env file not found!"
    exit 1
}

Write-Host "Loading credentials from .env file..." -ForegroundColor Yellow
$envVars = @{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $envVars[$key] = $value
    }
}

$orgApiKey = $envVars['ORGANIZATION_API_KEY']
$orgId = $envVars['ORGANIZATION_ID']

# Validate inputs
if (-not $orgApiKey -or $orgApiKey -eq "PASTE_YOUR_ORG_API_KEY_HERE") {
    Write-Error "Please update ORGANIZATION_API_KEY in .env file!"
    Write-Host ""
    Write-Host "Get it from: https://admin.atlassian.com/ -> Settings -> API keys" -ForegroundColor Yellow
    exit 1
}

if (-not $orgId -or $orgId -eq "PASTE_YOUR_ORG_ID_HERE") {
    Write-Error "Please update ORGANIZATION_ID in .env file!"
    Write-Host ""
    Write-Host "It's shown when you create the API key at admin.atlassian.com" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found Organization API Key" -ForegroundColor Green
Write-Host "✅ Found Organization ID: $orgId" -ForegroundColor Green
Write-Host ""

# Test the Organization API Key
Write-Host "Testing Organization API Key..." -ForegroundColor Cyan
$headers = @{
    "Authorization" = "Bearer $orgApiKey"
    "Accept" = "application/json"
    "Content-Type" = "application/json"
}

try {
    # Get workspaces
    $workspacesUri = "https://api.atlassian.com/admin/v2/orgs/$orgId/workspaces"
    $workspacesBody = @{} | ConvertTo-Json
    
    Write-Host "Retrieving workspaces..." -ForegroundColor Yellow
    $workspaces = Invoke-RestMethod -Method POST -Uri $workspacesUri -Headers $headers -Body $workspacesBody -ErrorAction Stop
    
    if ($workspaces.data -and $workspaces.data.Count -gt 0) {
        Write-Host "✅ SUCCESS! Found $($workspaces.data.Count) workspace(s)" -ForegroundColor Green
        Write-Host ""
        
        # Display all workspaces
        Write-Host "Available Workspaces:" -ForegroundColor Cyan
        $workspaceNumber = 1
        foreach ($workspace in $workspaces.data) {
            $isJira = $workspace.attributes.type -match "jira"
            $color = if ($isJira) { "Green" } else { "Gray" }
            
            Write-Host ""
            Write-Host "[$workspaceNumber] $($workspace.attributes.name)" -ForegroundColor $color
            Write-Host "    Type: $($workspace.attributes.type)" -ForegroundColor White
            Write-Host "    URL: $($workspace.attributes.hostUrl)" -ForegroundColor White
            Write-Host "    ID: $($workspace.id)" -ForegroundColor Yellow
            Write-Host "    Status: $($workspace.attributes.status)" -ForegroundColor White
            
            $workspaceNumber++
        }
        
        Write-Host ""
        Write-Host "=== FINDING TARGET WORKSPACE ===" -ForegroundColor Cyan
        
        # Find the sandbox workspace
        $targetWorkspace = $workspaces.data | Where-Object { 
            $_.attributes.hostUrl -match "onemainfinancial-sandbox-575" 
        } | Select-Object -First 1
        
        if ($targetWorkspace) {
            Write-Host "✅ Found target workspace: $($targetWorkspace.attributes.name)" -ForegroundColor Green
            Write-Host "   URL: $($targetWorkspace.attributes.hostUrl)" -ForegroundColor White
            Write-Host "   ID: $($targetWorkspace.id)" -ForegroundColor Yellow
            Write-Host ""
            
            # Update .env file
            Write-Host "Updating .env file with workspace ID..." -ForegroundColor Cyan
            $envContent = Get-Content ".env"
            $envContent = $envContent -replace 'WORKSPACE_ID=.*', "WORKSPACE_ID=$($targetWorkspace.id)"
            $envContent | Out-File -FilePath ".env" -Encoding UTF8 -Force
            
            Write-Host "✅ Updated .env file!" -ForegroundColor Green
            Write-Host ""
            
            # Generate configuration snippet
            Write-Host "=== CONFIGURATION FOR PARAMETERS.JSON ===" -ForegroundColor Cyan
            Write-Host ""
            Write-Host '"UserInvitation": {' -ForegroundColor White
            Write-Host '  "AutoInvite": true,' -ForegroundColor White
            Write-Host "  `"OrganizationId`": `"$orgId`"," -ForegroundColor Green
            Write-Host "  `"AdminApiToken`": `"$orgApiKey`"," -ForegroundColor Green
            Write-Host "  `"TargetWorkspaceId`": `"$($targetWorkspace.id)`"" -ForegroundColor Green
            Write-Host '}' -ForegroundColor White
            Write-Host ""
            
            Write-Host "=== NEXT STEPS ===" -ForegroundColor Yellow
            Write-Host "1. Copy the configuration above" -ForegroundColor White
            Write-Host "2. Update projects/LAS/parameters.json (replace the UserInvitation section)" -ForegroundColor White
            Write-Host "3. Set 'AutoInvite': true" -ForegroundColor White
            Write-Host "4. Run: .\RunMigration.ps1 -Project LAS -Step 03" -ForegroundColor White
            Write-Host ""
            Write-Host "🎉 This will automatically invite all 1600 users!" -ForegroundColor Green
            
        } else {
            Write-Warning "Could not find workspace matching 'onemainfinancial-sandbox-575'"
            Write-Host ""
            Write-Host "Please select the correct workspace from the list above and update .env manually:" -ForegroundColor Yellow
            Write-Host "  WORKSPACE_ID=<workspace_id_from_above>" -ForegroundColor White
        }
        
    } else {
        Write-Warning "No workspaces found"
    }
    
} catch {
    Write-Error "❌ Failed to retrieve workspaces: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Possible issues:" -ForegroundColor Yellow
    Write-Host "  1. Organization API Key is invalid" -ForegroundColor White
    Write-Host "  2. Organization ID is incorrect" -ForegroundColor White
    Write-Host "  3. API Key doesn't have the right permissions" -ForegroundColor White
    Write-Host ""
    Write-Host "Make sure you created the API Key at:" -ForegroundColor Yellow
    Write-Host "  https://admin.atlassian.com/ -> Settings -> API keys" -ForegroundColor White
}

