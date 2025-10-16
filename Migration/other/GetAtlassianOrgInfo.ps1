# =============================================================================
# GET ATLASSIAN ORGANIZATION INFO
# =============================================================================
#
# DESCRIPTION: Helper script to retrieve Organization ID and Workspace ID
#              for configuring automatic user invitations
#
# USAGE: .\GetAtlassianOrgInfo.ps1 -AdminApiToken "YOUR_ADMIN_API_TOKEN"
#
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$AdminApiToken,
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspaceUrl = $null
)

Write-Host "=== ATLASSIAN ORGANIZATION INFO RETRIEVAL ===" -ForegroundColor Cyan
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $AdminApiToken"
    "Accept" = "application/json"
}

# =============================================================================
# GET ACCESSIBLE ORGANIZATIONS
# =============================================================================

Write-Host "Step 1: Retrieving accessible organizations..." -ForegroundColor Yellow

try {
    $orgsUri = "https://api.atlassian.com/admin/v1/orgs"
    $orgs = Invoke-RestMethod -Method GET -Uri $orgsUri -Headers $headers -ErrorAction Stop
    
    if ($orgs.data -and $orgs.data.Count -gt 0) {
        Write-Host "✅ Found $($orgs.data.Count) organization(s)" -ForegroundColor Green
        Write-Host ""
        
        foreach ($org in $orgs.data) {
            Write-Host "Organization:" -ForegroundColor Cyan
            Write-Host "  Name: $($org.attributes.name)" -ForegroundColor White
            Write-Host "  ID: $($org.id)" -ForegroundColor Green
            Write-Host "  Type: $($org.type)" -ForegroundColor White
            Write-Host ""
            
            # Store the org ID for workspace lookup
            $orgId = $org.id
            
            # =============================================================================
            # GET WORKSPACES FOR THIS ORGANIZATION
            # =============================================================================
            
            Write-Host "Step 2: Retrieving workspaces for organization: $($org.attributes.name)..." -ForegroundColor Yellow
            
            try {
                $workspacesUri = "https://api.atlassian.com/admin/v2/orgs/$orgId/workspaces"
                $workspacesBody = @{} | ConvertTo-Json
                $workspaces = Invoke-RestMethod -Method POST -Uri $workspacesUri -Headers $headers -Body $workspacesBody -ContentType "application/json" -ErrorAction Stop
                
                if ($workspaces.data -and $workspaces.data.Count -gt 0) {
                    Write-Host "✅ Found $($workspaces.data.Count) workspace(s)" -ForegroundColor Green
                    Write-Host ""
                    
                    foreach ($workspace in $workspaces.data) {
                        $isJira = $workspace.attributes.type -match "jira"
                        $color = if ($isJira) { "Cyan" } else { "Gray" }
                        
                        Write-Host "  Workspace:" -ForegroundColor $color
                        Write-Host "    Name: $($workspace.attributes.name)" -ForegroundColor White
                        Write-Host "    Type: $($workspace.attributes.type)" -ForegroundColor White
                        Write-Host "    ID: $($workspace.id)" -ForegroundColor Green
                        Write-Host "    URL: $($workspace.attributes.hostUrl)" -ForegroundColor White
                        Write-Host "    Status: $($workspace.attributes.status)" -ForegroundColor White
                        
                        # Highlight if this matches the provided URL
                        if ($WorkspaceUrl -and $workspace.attributes.hostUrl -match [regex]::Escape($WorkspaceUrl)) {
                            Write-Host "    >>> THIS IS YOUR TARGET WORKSPACE! <<<" -ForegroundColor Yellow -BackgroundColor DarkGreen
                        }
                        
                        Write-Host ""
                    }
                    
                    # =============================================================================
                    # GENERATE CONFIGURATION SNIPPET
                    # =============================================================================
                    
                    Write-Host "=== CONFIGURATION SNIPPET ===" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Add this to your parameters.json file:" -ForegroundColor Yellow
                    Write-Host ""
                    
                    # Find Jira workspace (prefer the one matching WorkspaceUrl if provided)
                    $targetWorkspace = $null
                    if ($WorkspaceUrl) {
                        $targetWorkspace = $workspaces.data | Where-Object { $_.attributes.hostUrl -match [regex]::Escape($WorkspaceUrl) } | Select-Object -First 1
                    }
                    if (-not $targetWorkspace) {
                        $targetWorkspace = $workspaces.data | Where-Object { $_.attributes.type -match "jira" } | Select-Object -First 1
                    }
                    
                    if ($targetWorkspace) {
                        Write-Host '"UserInvitation": {' -ForegroundColor White
                        Write-Host '  "AutoInvite": true,' -ForegroundColor White
                        Write-Host "  `"OrganizationId`": `"$orgId`"," -ForegroundColor Green
                        Write-Host "  `"AdminApiToken`": `"$AdminApiToken`"," -ForegroundColor Green
                        Write-Host "  `"TargetWorkspaceId`": `"$($targetWorkspace.id)`"" -ForegroundColor Green
                        Write-Host '}' -ForegroundColor White
                        Write-Host ""
                        Write-Host "Target Workspace: $($targetWorkspace.attributes.name) ($($targetWorkspace.attributes.hostUrl))" -ForegroundColor Cyan
                    } else {
                        Write-Host '"UserInvitation": {' -ForegroundColor White
                        Write-Host '  "AutoInvite": true,' -ForegroundColor White
                        Write-Host "  `"OrganizationId`": `"$orgId`"," -ForegroundColor Green
                        Write-Host "  `"AdminApiToken`": `"$AdminApiToken`"," -ForegroundColor Green
                        Write-Host '  "TargetWorkspaceId": "REPLACE_WITH_WORKSPACE_ID_FROM_ABOVE"' -ForegroundColor Yellow
                        Write-Host '}' -ForegroundColor White
                    }
                    
                } else {
                    Write-Warning "No workspaces found for this organization"
                }
                
            } catch {
                Write-Error "Failed to retrieve workspaces: $($_.Exception.Message)"
            }
        }
        
    } else {
        Write-Warning "No organizations found. Make sure your API token has admin permissions."
    }
    
} catch {
    Write-Error "Failed to retrieve organizations: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Make sure:" -ForegroundColor Yellow
    Write-Host "  1. Your API token is valid" -ForegroundColor White
    Write-Host "  2. Your API token has Organization Admin permissions" -ForegroundColor White
    Write-Host "  3. You have access to at least one organization" -ForegroundColor White
}

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Copy the configuration snippet above" -ForegroundColor White
Write-Host "  2. Add it to your project's parameters.json file" -ForegroundColor White
Write-Host "  3. Run Step 03 (Migrate Users and Roles) to automatically invite users" -ForegroundColor White
