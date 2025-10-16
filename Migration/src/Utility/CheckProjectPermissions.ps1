# CheckProjectPermissions.ps1 - Check permission scheme configuration
#
# PURPOSE: Diagnose permission issues for issue assignment
#
param(
    [string]$Project = "LAS"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CHECKING PROJECT PERMISSIONS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Load common functions
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Load parameters
$projectsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "projects"
$ParametersPath = Join-Path $projectsDir "$Project\parameters.json"
$p = Read-JsonFile -Path $ParametersPath

# Target environment setup
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host "Target: $tgtBase ($tgtKey)" -ForegroundColor Gray
Write-Host ""

# Get project details
Write-Host "Getting project details..." -ForegroundColor Yellow
try {
    $projectUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey"
    $project = Invoke-RestMethod -Method GET -Uri $projectUri -Headers $tgtHdr -ErrorAction Stop
    
    $projectName = if ($project.name) { $project.name } else { "Unknown" }
    $projectId = if ($project.id) { $project.id } else { "Unknown" }
    $projectKey = if ($project.key) { $project.key } else { $tgtKey }
    $projectType = if ($project.projectTypeKey) { $project.projectTypeKey } else { "Unknown" }
    
    Write-Host "✅ Project: $projectName (ID: $projectId)" -ForegroundColor Green
    Write-Host "   Key: $projectKey" -ForegroundColor Gray
    Write-Host "   Type: $projectType" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to get project: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   Response: $($_.ErrorDetails.Message)" -ForegroundColor DarkGray
    exit 1
}

Write-Host ""

# Get permission scheme
Write-Host "Getting permission scheme..." -ForegroundColor Yellow
try {
    $schemeUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$tgtKey/permissionscheme"
    $permissionScheme = Invoke-RestMethod -Method GET -Uri $schemeUri -Headers $tgtHdr -ErrorAction Stop
    Write-Host "✅ Permission Scheme: $($permissionScheme.name)" -ForegroundColor Green
    Write-Host "   ID: $($permissionScheme.id)" -ForegroundColor Gray
    Write-Host "   Description: $($permissionScheme.description)" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to get permission scheme: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Get detailed permission scheme configuration
Write-Host "Getting permission scheme details..." -ForegroundColor Yellow
try {
    $schemeDetailsUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/permissionscheme/$($permissionScheme.id)"
    $schemeDetails = Invoke-RestMethod -Method GET -Uri "$schemeDetailsUri`?expand=permissions" -Headers $tgtHdr -ErrorAction Stop
    
    # Find ASSIGNABLE_USER permission
    $assignablePermission = $schemeDetails.permissions | Where-Object { $_.permission -eq "ASSIGNABLE_USER" }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  ASSIGNABLE USER PERMISSION" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($assignablePermission) {
        Write-Host "✅ ASSIGNABLE_USER permission is configured" -ForegroundColor Green
        Write-Host ""
        Write-Host "Granted to:" -ForegroundColor White
        
        foreach ($perm in $assignablePermission) {
            if ($perm.holder.type -eq "projectRole") {
                Write-Host "  • Project Role: $($perm.holder.parameter)" -ForegroundColor Gray
            } elseif ($perm.holder.type -eq "group") {
                Write-Host "  • Group: $($perm.holder.parameter)" -ForegroundColor Gray
            } elseif ($perm.holder.type -eq "user") {
                Write-Host "  • User: $($perm.holder.parameter)" -ForegroundColor Gray
            } elseif ($perm.holder.type -eq "anyone") {
                Write-Host "  • Anyone (Any logged in user)" -ForegroundColor Gray
            } else {
                Write-Host "  • $($perm.holder.type): $($perm.holder.parameter)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "❌ ASSIGNABLE_USER permission is NOT configured!" -ForegroundColor Red
        Write-Host ""
        Write-Host "This means NO ONE can be assigned to issues in this project!" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to get permission details: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Get project roles
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  PROJECT ROLES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

try {
    $rolesUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/project/$($project.id)/role"
    $roles = Invoke-RestMethod -Method GET -Uri $rolesUri -Headers $tgtHdr -ErrorAction Stop
    
    foreach ($roleName in $roles.PSObject.Properties.Name) {
        $roleUrl = $roles.$roleName
        Write-Host "Role: $roleName" -ForegroundColor White
        
        # Get role details
        try {
            $roleDetails = Invoke-RestMethod -Method GET -Uri $roleUrl -Headers $tgtHdr -ErrorAction Stop
            $actorCount = if ($roleDetails.actors) { $roleDetails.actors.Count } else { 0 }
            Write-Host "  Members: $actorCount" -ForegroundColor Gray
            
            if ($actorCount -gt 0 -and $actorCount -le 10) {
                foreach ($actor in $roleDetails.actors) {
                    if ($actor.actorUser) {
                        Write-Host "    - $($actor.actorUser.displayName)" -ForegroundColor DarkGray
                    } elseif ($actor.actorGroup) {
                        Write-Host "    - Group: $($actor.actorGroup.name)" -ForegroundColor DarkGray
                    }
                }
            }
        } catch {
            Write-Host "  (Could not retrieve details)" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
} catch {
    Write-Host "❌ Failed to get project roles: $($_.Exception.Message)" -ForegroundColor Red
}

# Recommendations
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RECOMMENDATIONS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not $assignablePermission) {
    Write-Host "🔧 TO FIX:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Go to: Jira Settings → Issues → Permission schemes" -ForegroundColor White
    Write-Host "2. Find scheme: '$($permissionScheme.name)'" -ForegroundColor White
    Write-Host "3. Click 'Permissions'" -ForegroundColor White
    Write-Host "4. Find 'Assignable User' row" -ForegroundColor White
    Write-Host "5. Click 'Edit' or 'Add'" -ForegroundColor White
    Write-Host "6. Add: 'Project Role: Administrators'" -ForegroundColor White
    Write-Host "   OR: 'Any Logged in User' (for sandbox testing)" -ForegroundColor White
    Write-Host "7. Save" -ForegroundColor White
    Write-Host ""
    Write-Host "Then re-run: .\src\Utility\UpdateIssueAssignees.ps1 -Project LAS" -ForegroundColor Cyan
} else {
    $hasAdminRole = $false
    foreach ($perm in $assignablePermission) {
        if ($perm.holder.parameter -like "*dministrator*") {
            $hasAdminRole = $true
            break
        }
    }
    
    if (-not $hasAdminRole) {
        Write-Host "⚠️  ISSUE FOUND:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The ASSIGNABLE_USER permission exists, but the 'Administrators' role" -ForegroundColor White
        Write-Host "is not included. Add it to allow admins to be assigned to issues." -ForegroundColor White
        Write-Host ""
        Write-Host "Follow the same steps above to add 'Project Role: Administrators'" -ForegroundColor Cyan
    } else {
        Write-Host "✅ Configuration looks correct!" -ForegroundColor Green
        Write-Host ""
        Write-Host "If assignments are still failing, it might be:" -ForegroundColor White
        Write-Host "  • A user-specific permission issue" -ForegroundColor Gray
        Write-Host "  • Users need to be added to the Administrators role" -ForegroundColor Gray
        Write-Host "  • Try manually assigning an issue in the UI to test" -ForegroundColor Gray
    }
}

Write-Host ""

