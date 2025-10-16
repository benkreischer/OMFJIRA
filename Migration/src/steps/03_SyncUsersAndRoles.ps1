# 03_SyncUsersAndRoles.ps1 - Synchronize Users and Roles
param([string] $ParametersPath)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$p = Read-JsonFile -Path $ParametersPath

# Capture step start time
$stepStartTime = Get-Date

# Initialize UserInvitation settings if not present
if (-not ($p.PSObject.Properties.Name -contains 'UserInvitation')) {
    $p | Add-Member -MemberType NoteProperty -Name 'UserInvitation' -Value ([PSCustomObject]@{
        AutoInvite = $false
    })
}

# Environment setup
$srcBase = $p.SourceEnvironment.BaseUrl
$srcEmail = $p.SourceEnvironment.Username
$srcTok = $p.SourceEnvironment.ApiToken
$srcKey = $p.ProjectKey
$srcHdr = New-BasicAuthHeader -Email $srcEmail -ApiToken $srcTok

$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

$outDir = $p.OutputSettings.OutputDirectory

Write-Host "=== SYNCHRONIZING USERS AND ROLES ==="
Write-Host "Source Project: $srcKey"
Write-Host "Target Project: $tgtKey"

# Helpers
function Get-Project {
    param([string] $Base, [hashtable] $Hdr, [string] $Key)
    Invoke-RestMethod -Method GET -Uri ("{0}/rest/api/3/project/{1}" -f $Base.TrimEnd('/'), $Key) -Headers $Hdr -ErrorAction Stop
}
function Get-ProjectRoles {
    param([string] $Base, [hashtable] $Hdr, [string] $ProjectId)
    $uri = "{0}/rest/api/3/project/{1}/role" -f $Base.TrimEnd('/'), $ProjectId
    Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
}
function Get-RoleDetails {
    param([hashtable] $Hdr, [string] $RoleUrl)
    Invoke-RestMethod -Method GET -Uri $RoleUrl -Headers $Hdr -ErrorAction Stop
}
function Get-UserByAccountId {
    param([string] $Base, [hashtable] $Hdr, [string] $AccountId)
    $uri = "{0}/rest/api/3/user?accountId={1}" -f $Base.TrimEnd('/'), [uri]::EscapeDataString($AccountId)
    Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
}
function Resolve-AccountId-ByEmail {
    param([string] $Base, [hashtable] $Hdr, [string] $Email)
    $q = [uri]::EscapeDataString($Email)
    $uri = "{0}/rest/api/3/user/search?query={1}&maxResults=5" -f $Base.TrimEnd('/'), $q
    $users = Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
    if ($users -and $users.Count -gt 0) { return $users[0].accountId } else { return $null }
}
function Add-User-To-Role {
    param([hashtable] $Hdr, [string] $RoleUrl, [string] $AccountId)
    try {
        # Try the old API format first
        $baseUrl = $RoleUrl.Split('/rest/')[0]
        $projectId = $RoleUrl -match '/project/(\d+)/role' | Out-Null
        $projectId = $matches[1]
        $roleId = $RoleUrl.Split('/')[-1]

        $addUserUrl = "{0}/rest/api/3/project/{1}/role/{2}/actors" -f $baseUrl, $projectId, $roleId
        $body = @{
            user = @( $AccountId )
        } | ConvertTo-Json -Depth 3

        Invoke-RestMethod -Method POST -Uri $addUserUrl -Headers $Hdr -Body $body -ContentType "application/json" -ErrorAction Stop
        return @{ ok=$true; status="added"; msg=$null }
    } catch {
        # Treat "already exists" as success
        $msg = $_.Exception.Message
        try {
            $resp = $_.Exception.Response
            if ($resp -and $resp.GetResponseStream()) {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $details = $reader.ReadToEnd()
                $msg = "$msg`nResponse: $details"
                if ($details -match 'already' -or $details -match 'exists' -or ([int]$resp.StatusCode -eq 409)) {
                    return @{ ok=$true; status="exists"; msg=$msg }
                }
            }
        } catch { }
        return @{ ok=$false; status="error"; msg=$msg }
    }
}
function Add-Group-To-Role {
    param([hashtable] $Hdr, [string] $RoleUrl, [string] $GroupName)
    $body = @{ group = @($GroupName) } | ConvertTo-Json -Depth 3
    try {
        Invoke-RestMethod -Method POST -Uri $RoleUrl -Headers $Hdr -Body $body -ContentType "application/json" -ErrorAction Stop
        return @{ ok=$true; status="added"; msg=$null }
    } catch {
        $msg = $_.Exception.Message
        try {
            $resp = $_.Exception.Response
            if ($resp -and $resp.GetResponseStream()) {
                $reader = New-Object System.IO.StreamReader($resp.GetResponseStream())
                $details = $reader.ReadToEnd()
                $msg = "$msg`nResponse: $details"
                if ($details -match 'already' -or $details -match 'exists' -or ([int]$resp.StatusCode -eq 409)) {
                    return @{ ok=$true; status="exists"; msg=$msg }
                }
            }
        } catch { }
        return @{ ok=$false; status="error"; msg=$msg }
    }
}

# Get source & target projects
Write-Host "Retrieving source project details..."
$srcProject = Get-Project -Base $srcBase -Hdr $srcHdr -Key $srcKey
Write-Host "Source project: $($srcProject.name) (id=$($srcProject.id))"

Write-Host "Retrieving target project details..."
$tgtProject = Get-Project -Base $tgtBase -Hdr $tgtHdr -Key $tgtKey
Write-Host "Target project: $($tgtProject.name) (id=$($tgtProject.id))"

# Resolve fallback lead (for substitution if user not found in target)
$fallbackLeadAccountId = $null
try {
    if ($p.PSObject.Properties.Name -contains 'UserMapping' -and $p.UserMapping.PSObject.Properties.Name -contains 'ProjectLeadEmail' -and $p.UserMapping.ProjectLeadEmail) {
        $fallbackLeadAccountId = Resolve-AccountId-ByEmail -Base $tgtBase -Hdr $tgtHdr -Email $p.UserMapping.ProjectLeadEmail
        if ($fallbackLeadAccountId) { Write-Host "Resolved fallback project lead: $($p.UserMapping.ProjectLeadEmail) -> $fallbackLeadAccountId" }
    }
} catch { }

# Build source role actor sets (users + groups) - MODIFIED: Make everyone an administrator
Write-Host "Enumerating source project roles and actors..."
$srcRoleMap = @{}  # roleName => @{ users=[accountIds]; groups=[names] }
$srcRoles = Get-ProjectRoles -Base $srcBase -Hdr $srcHdr -ProjectId $srcProject.id

# Collect all unique users from all roles
$allUserIds = [System.Collections.Generic.HashSet[string]]::new()
$allGroupNames = [System.Collections.Generic.HashSet[string]]::new()

foreach ($roleName in $srcRoles.PSObject.Properties.Name) {
    $roleUrl = $srcRoles.$roleName
    $roleDetails = Get-RoleDetails -Hdr $srcHdr -RoleUrl $roleUrl

    foreach ($actor in $roleDetails.actors) {
        $type = $actor.type
        if ($type -eq 'atlassian-user-role-actor') {
            # Try multiple shapes (actorUser.accountId OR accountId directly)
            $acct = $null
            if ($actor.PSObject.Properties.Name -contains 'actorUser' -and $actor.actorUser -and $actor.actorUser.PSObject.Properties.Name -contains 'accountId') {
                $acct = $actor.actorUser.accountId
            } elseif ($actor.PSObject.Properties.Name -contains 'accountId') {
                $acct = $actor.accountId
            }
            if ($acct) { [void]$allUserIds.Add($acct) }
        } elseif ($type -eq 'atlassian-group-role-actor') {
            # Prefer name; fall back to groupId is not supported by this endpoint for add (expects names)
            $gn = $null
            if ($actor.PSObject.Properties.Name -contains 'actorGroup' -and $actor.actorGroup) {
                if ($actor.actorGroup.PSObject.Properties.Name -contains 'name')   { $gn = $actor.actorGroup.name }
                elseif ($actor.actorGroup.PSObject.Properties.Name -contains 'groupId') { $gn = $actor.actorGroup.groupId } # last resort
            }
            if ($gn -and $gn -ne "atlassian-addons-project-access") { [void]$allGroupNames.Add($gn) } # skip managed add-ons group
        }
    }
}

# Create a simplified role map where everyone gets administrator access ONLY
# Only assign to the Administrators/Administrator role
$tgtRoles = Get-ProjectRoles -Base $tgtBase -Hdr $tgtHdr -ProjectId $tgtProject.id

# Find the admin role (could be "Administrators" or "Administrator")
$adminRoleName = $null
if ($tgtRoles.PSObject.Properties.Name -contains 'Administrators') {
    $adminRoleName = 'Administrators'
} elseif ($tgtRoles.PSObject.Properties.Name -contains 'Administrator') {
    $adminRoleName = 'Administrator'
}

if ($adminRoleName) {
    $srcRoleMap[$adminRoleName] = @{
        users  = @($allUserIds | ForEach-Object { $_ })
        groups = @($allGroupNames | ForEach-Object { $_ })
    }
    Write-Host "Will assign all users to $adminRoleName role only."
} else {
    Write-Warning "No Administrators/Administrator role found in target project!"
}

if ($adminRoleName) {
    Write-Host ("Discovered {0} roles in source, will assign all users to $adminRoleName role only." -f $srcRoles.PSObject.Properties.Name.Count)
} else {
    Write-Host ("Discovered {0} roles in source." -f $srcRoles.PSObject.Properties.Name.Count)
}

# Target roles already retrieved above
Write-Host "Target roles: $($tgtRoles.PSObject.Properties.Name -join ', ')"

# Stats & logs
$succeededUsers = New-Object System.Collections.Generic.List[object]
$failedUsers    = New-Object System.Collections.Generic.List[object]
$skippedUsers   = New-Object System.Collections.Generic.List[object]

$succeededGroups = New-Object System.Collections.Generic.List[object]
$failedGroups    = New-Object System.Collections.Generic.List[object]
$skippedGroups   = New-Object System.Collections.Generic.List[object]

$useFallback = $false
if ($p.PSObject.Properties.Name -contains 'UserMapping' -and $p.UserMapping.PSObject.Properties.Name -contains 'FallbackToProjectLead') {
    $useFallback = [bool]$p.UserMapping.FallbackToProjectLead
}

Write-Host ""
Write-Host "=== APPLYING ACTORS TO TARGET ROLES ==="
foreach ($roleName in $srcRoleMap.Keys) {
    if (-not ($tgtRoles.PSObject.Properties.Name -contains $roleName)) {
        Write-Warning "Target does not have role '$roleName' - skipping role."
        continue
    }
    $tgtRoleUrl = $tgtRoles.$roleName
    $actors = $srcRoleMap[$roleName]

    # Users
    foreach ($acct in $actors.users) {
        Write-Host ("User actor -> role '{0}': {1}" -f $roleName, $acct)
        $targetAcct = $null
        $userExistsInTarget = $false

        # Try same accountId in target
        try {
            $null = Get-UserByAccountId -Base $tgtBase -Hdr $tgtHdr -AccountId $acct
            $targetAcct = $acct
            $userExistsInTarget = $true
        } catch {
            # Not visible/doesn't exist in target; fallback?
            if ($useFallback -and $fallbackLeadAccountId) {
                $targetAcct = $fallbackLeadAccountId
                Write-Warning ("  User {0} not found in target; using fallback lead {1}" -f $acct, $targetAcct)
            } else {
                Write-Warning ("  User {0} not found in target and no fallback enabled." -f $acct)
                $skippedUsers.Add(@{ Role=$roleName; SourceAccountId=$acct; Reason="NotFound" }) | Out-Null
                continue
            }
        }

        $res = Add-User-To-Role -Hdr $tgtHdr -RoleUrl $tgtRoleUrl -AccountId $targetAcct
        
        # Handle case where function returns an array (take the last element which should be the result)
        if ($res -is [array]) {
            $res = $res[-1]
        }
        
        if ($res -and $res.ok) {
            $succeededUsers.Add(@{ Role=$roleName; AccountId=$targetAcct; SourceAccountId=$acct; Status=$res.status }) | Out-Null
            Write-Host ("  SUCCESS: {0}" -f $res.status)
        } else {
            $errorMsg = if ($res -and $res.msg) { $res.msg } else { "Unknown error" }
            # Store the ORIGINAL source account ID, not the fallback lead's ID
            $failedUsers.Add(@{ Role=$roleName; AccountId=$targetAcct; SourceAccountId=$acct; Error=$errorMsg; UserExistsInTarget=$userExistsInTarget }) | Out-Null
            Write-Warning ("  FAILED: {0}" -f $errorMsg)
        }
    }

    # Groups
    foreach ($g in $actors.groups) {
        Write-Host ("Group actor -> role '{0}': {1}" -f $roleName, $g)
        if ($g -eq "atlassian-addons-project-access") {
            $skippedGroups.Add(@{ Role=$roleName; Group=$g; Reason="ManagedBySystem" }) | Out-Null
            Write-Host "  INFO: Skipping managed add-ons group."
            continue
        }
        $gres = Add-Group-To-Role -Hdr $tgtHdr -RoleUrl $tgtRoleUrl -GroupName $g
        
        # Handle case where function returns an array (take the last element which should be the result)
        if ($gres -is [array]) {
            $gres = $gres[-1]
        }
        
        if ($gres -and $gres.ok) {
            $succeededGroups.Add(@{ Role=$roleName; Group=$g; Status=$gres.status }) | Out-Null
            Write-Host ("  SUCCESS: {0}" -f $gres.status)
        } else {
            $errorMsg = if ($gres -and $gres.msg) { $gres.msg } else { "Unknown error" }
            $failedGroups.Add(@{ Role=$roleName; Group=$g; Error=$errorMsg }) | Out-Null
            Write-Warning ("  FAILED: {0}" -f $gres.msg)
        }
    }
}

Write-Host ""
Write-Host "=== SYNCHRONIZATION SUMMARY ==="

# Count unique users (not role assignments)
$uniqueSucceededUsers = if ($succeededUsers -and $succeededUsers.Count -gt 0) { ($succeededUsers | Select-Object -Property SourceAccountId -Unique).Count } else { 0 }
$uniqueFailedUsers = if ($failedUsers -and $failedUsers.Count -gt 0) { ($failedUsers | Select-Object -Property SourceAccountId -Unique).Count } else { 0 }
$uniqueSkippedUsers = if ($skippedUsers -and $skippedUsers.Count -gt 0) { ($skippedUsers | Select-Object -Property SourceAccountId -Unique).Count } else { 0 }

Write-Host ("Unique Users: added/exists={0}  failed={1}  skipped={2}" -f $uniqueSucceededUsers, $uniqueFailedUsers, $uniqueSkippedUsers)
Write-Host ("Role Assignments: succeeded={0}  failed={1}  skipped={2}" -f $succeededUsers.Count, $failedUsers.Count, $skippedUsers.Count)
Write-Host ("Groups:  added/exists={0}  failed={1}  skipped={2}" -f $succeededGroups.Count, $failedGroups.Count, $skippedGroups.Count)

# =============================================================================
# COMPREHENSIVE USER ACTIVITY ANALYSIS
# =============================================================================
Write-Host ""
Write-Host "=== ANALYZING ALL PROJECT USERS (Including Succeeded) ===" -ForegroundColor Cyan

# Get ALL users from source project (succeeded + failed + skipped)
$allProjectUsers = @{}

# Add succeeded users
if ($succeededUsers -and $succeededUsers.Count -gt 0) {
    foreach ($user in $succeededUsers) {
        $accountId = if ($user.SourceAccountId) { $user.SourceAccountId } else { $user.AccountId }
        if ($accountId -and -not $allProjectUsers.ContainsKey($accountId)) {
            $allProjectUsers[$accountId] = @{
                Role = $user.Role
                SyncStatus = "Successfully Added"
            }
        }
    }
}

# Add failed users
if ($failedUsers -and $failedUsers.Count -gt 0) {
    foreach ($user in $failedUsers) {
        $accountId = if ($user.SourceAccountId) { $user.SourceAccountId } else { $user.AccountId }
        if ($accountId -and -not $allProjectUsers.ContainsKey($accountId)) {
            $allProjectUsers[$accountId] = @{
                Role = $user.Role
                SyncStatus = "Failed: $($user.Error)"
            }
        }
    }
}

# Add skipped users
if ($skippedUsers -and $skippedUsers.Count -gt 0) {
    foreach ($user in $skippedUsers) {
        $accountId = if ($user.SourceAccountId) { $user.SourceAccountId } else { $user.AccountId }
        if ($accountId -and -not $allProjectUsers.ContainsKey($accountId)) {
            $allProjectUsers[$accountId] = @{
                Role = $user.Role
                SyncStatus = "Skipped: $($user.Reason)"
            }
        }
    }
}

Write-Host "Analyzing $($allProjectUsers.Keys.Count) total users in source project..."
Write-Host ""

# Analyze activity for ALL users
$allUsersActivityData = @()
$processedCount = 0
foreach ($accountId in $allProjectUsers.Keys) {
    $processedCount++
    Write-Host "  [$processedCount/$($allProjectUsers.Keys.Count)] Analyzing: $accountId..." -NoNewline
    
    # Try to get user details from source
    $userDetails = $null
    try {
        $userDetails = Get-UserByAccountId -Base $srcBase -Hdr $srcHdr -AccountId $accountId
    } catch {
        Write-Host " ❌ (user not accessible)" -ForegroundColor Yellow
        continue
    }
    
    # Filter out app/integration accounts (not real users)
    $accountType = if ($userDetails.PSObject.Properties['accountType']) { $userDetails.accountType } else { "Unknown" }
    if ($accountType -eq "app" -or $accountType -eq "customer") {
        Write-Host " ⏭️  (skipped: $accountType)" -ForegroundColor Gray
        continue
    }
    
    Write-Host " ✅" -ForegroundColor Green
    
    # Get user info safely
    $email = if ($userDetails.PSObject.Properties['emailAddress']) { $userDetails.emailAddress } else { "Unknown" }
    $displayName = if ($userDetails.PSObject.Properties['displayName']) { $userDetails.displayName } else { "Unknown" }
    $active = if ($userDetails.PSObject.Properties['active']) { $userDetails.active } else { $false }
    
    $item = $allProjectUsers[$accountId]
    
    # Simple 5-column output: Name, Email, Active, Role, Timestamp
    # (AccountId kept for internal lookups but not shown prominently in CSV)
    $allUsersActivityData += [PSCustomObject]@{
        Name = $displayName
        Email = $email
        Active = $active
        Role = $item.Role
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        AccountId = $accountId
    }
}

# Capture step end time
$stepEndTime = Get-Date

# Add step timing information to user data
$allUsersActivityData += [PSCustomObject]@{
    Name = "Step Start Time"
    Email = "N/A"
    Active = "N/A"
    Role = "INFO"
    Timestamp = $stepStartTime.ToString("yyyy-MM-dd HH:mm:ss")
    AccountId = "N/A"
}

$allUsersActivityData += [PSCustomObject]@{
    Name = "Step End Time"
    Email = "N/A"
    Active = "N/A"
    Role = "INFO"
    Timestamp = $stepEndTime.ToString("yyyy-MM-dd HH:mm:ss")
    AccountId = "N/A"
}

# Export user report (5 columns: Name, Email, Active, Role, Timestamp)
$userActivityReportFile = $null
if ($allUsersActivityData.Count -gt 0) {
    $userActivityReportFile = Join-Path $outDir "03_UsersAndRoles_Report.csv"
    $allUsersActivityData | Select-Object Name, Email, Active, Role, Timestamp | Sort-Object Name | Export-Csv -Path $userActivityReportFile -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host "✅ User report saved: $userActivityReportFile" -ForegroundColor Green
    Write-Host "   Total users: $($allUsersActivityData.Count)" -ForegroundColor Cyan
    Write-Host "   Columns: Name, Email, Active, Role, Timestamp" -ForegroundColor Cyan
}

# =============================================================================
# CREATE USER INVITATION LIST (from failed/skipped users)
# =============================================================================
Write-Host ""
Write-Host "=== CREATING USER INVITATION LIST ===" -ForegroundColor Cyan

# Combine failed and skipped users for invitation list
$usersToInvite = @()
$uniqueFailedAccounts = @{}

# Collect unique failed users
if ($failedUsers -and $failedUsers.Count -gt 0) {
    foreach ($user in $failedUsers) {
        $acctId = if ($user.SourceAccountId) { $user.SourceAccountId } else { $user.AccountId }
        if ($acctId -and -not $uniqueFailedAccounts.ContainsKey($acctId)) {
            $uniqueFailedAccounts[$acctId] = $user
        }
    }
}

# Collect unique skipped users
if ($skippedUsers -and $skippedUsers.Count -gt 0) {
    foreach ($user in $skippedUsers) {
        $acctId = if ($user.SourceAccountId) { $user.SourceAccountId } else { $user.AccountId }
        if ($acctId -and -not $uniqueFailedAccounts.ContainsKey($acctId)) {
            $uniqueFailedAccounts[$acctId] = $user
        }
    }
}

# Match with user details from our report
if ($uniqueFailedAccounts.Count -gt 0) {
    foreach ($acctId in $uniqueFailedAccounts.Keys) {
        $userInfo = $allUsersActivityData | Where-Object { $_.AccountId -eq $acctId } | Select-Object -First 1
        if ($userInfo) {
            $usersToInvite += $userInfo
        }
    }
    
    Write-Host "Found $($usersToInvite.Count) users that need to be invited:" -ForegroundColor Yellow
    foreach ($user in $usersToInvite) {
        Write-Host "  $($user.Name) ($($user.Email)) - Role: $($user.Role)" -ForegroundColor White
    }
} else {
    Write-Host "✅ No users need invites - all successfully synced!" -ForegroundColor Green
}


# Check if auto-invite is enabled
$autoInviteEnabled = $false
$orgId = $null
$adminApiToken = $null
$workspaceId = $null

if ($p.UserInvitation -and $p.UserInvitation.AutoInvite -eq $true) {
    $autoInviteEnabled = $true
    
    # Try to load credentials from .env file first
    $envFile = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) ".env"
    if (Test-Path $envFile) {
        Write-Host "Loading Organization API credentials from .env file..." -ForegroundColor Cyan
        $envVars = @{}
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
                $envVars[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
        
        # Use .env values if available, otherwise fall back to parameters.json
        $orgId = if ($envVars['ORGANIZATION_ID']) { $envVars['ORGANIZATION_ID'] } else { $p.UserInvitation.OrganizationId }
        $adminApiToken = if ($envVars['ORGANIZATION_API_KEY']) { $envVars['ORGANIZATION_API_KEY'] } else { $p.UserInvitation.AdminApiToken }
        $workspaceId = if ($envVars['WORKSPACE_ID']) { $envVars['WORKSPACE_ID'] } else { $p.UserInvitation.TargetWorkspaceId }
    } else {
        # Fall back to parameters.json if .env doesn't exist
        Write-Host "No .env file found, using credentials from parameters.json..." -ForegroundColor Yellow
        $orgId = $p.UserInvitation.OrganizationId
        $adminApiToken = $p.UserInvitation.AdminApiToken
        $workspaceId = $p.UserInvitation.TargetWorkspaceId
    }
    
    # Validate required credentials
    if (-not $orgId -or $orgId -eq "REPLACE_WITH_ORG_ID") {
        Write-Warning "AutoInvite enabled but OrganizationId not configured. Falling back to CSV export."
        $autoInviteEnabled = $false
    }
    if (-not $adminApiToken -or $adminApiToken -eq "REPLACE_WITH_ADMIN_API_TOKEN") {
        Write-Warning "AutoInvite enabled but AdminApiToken not configured. Falling back to CSV export."
        $autoInviteEnabled = $false
    }
    if (-not $workspaceId -or $workspaceId -eq "REPLACE_WITH_WORKSPACE_ID") {
        Write-Warning "AutoInvite enabled but TargetWorkspaceId not configured. Falling back to CSV export."
        $autoInviteEnabled = $false
    }
}

$invitedUsers = New-Object System.Collections.Generic.List[object]
$failedInvitations = New-Object System.Collections.Generic.List[object]
$inviteFile = $null

if ($usersToInvite -and $usersToInvite.Count -gt 0) {
    $inviteFile = Join-Path $outDir "users_to_invite.csv"
    $usersToInvite | Export-Csv -Path $inviteFile -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Created user invitation list: $inviteFile" -ForegroundColor Green
    Write-Host "   Top users to invite: $($usersToInvite.Count) (sorted by issue count)" -ForegroundColor Yellow
    Write-Host "   Total users analyzed: $(if ($allUsersActivityData) { $allUsersActivityData.Count } else { 0 })" -ForegroundColor Cyan
    Write-Host ""
    
    if ($autoInviteEnabled) {
        Write-Host "=== AUTOMATIC USER INVITATION (via Admin API) ===" -ForegroundColor Cyan
        Write-Host "Organization ID: $orgId"
        Write-Host "Workspace ID: $workspaceId"
        Write-Host ""
        
        $adminHeaders = @{
            "Authorization" = "Bearer $adminApiToken"
            "Accept" = "application/json"
            "Content-Type" = "application/json"
        }
        
        foreach ($user in $usersToInvite) {
            if ($user.Email -eq "Unknown" -or -not $user.Email) {
                Write-Warning "  Skipping user with unknown email: $($user.Name)"
                $failedInvitations.Add([PSCustomObject]@{
                    Name = $user.Name
                    Email = $user.Email
                    Reason = "Email address unknown"
                }) | Out-Null
                continue
            }
            
            Write-Host "  Inviting: $($user.Name) ($($user.Email))..." -NoNewline
            
            try {
                # Invite user to organization and provision to workspace
                $inviteBody = @{
                    email = $user.Email
                    products = @(
                        @{
                            id = $workspaceId
                        }
                    )
                } | ConvertTo-Json -Depth 5
                
                $inviteUri = "https://api.atlassian.com/admin/v2/orgs/$orgId/users"
                $inviteResponse = Invoke-RestMethod -Method POST -Uri $inviteUri -Headers $adminHeaders -Body $inviteBody -ErrorAction Stop
                
                $invitedUsers.Add([PSCustomObject]@{
                    Name = $user.Name
                    Email = $user.Email
                    AccountId = if ($inviteResponse.accountId) { $inviteResponse.accountId } else { "Pending" }
                    Status = "Invited"
                }) | Out-Null
                
                Write-Host " ✅ SUCCESS" -ForegroundColor Green
                Start-Sleep -Milliseconds 500  # Rate limiting
                
            } catch {
                $errorMsg = $_.Exception.Message
                
                # Check if user already exists
                if ($errorMsg -match "already exists" -or $errorMsg -match "already a member") {
                    Write-Host " ℹ️  Already exists" -ForegroundColor Yellow
                    $invitedUsers.Add([PSCustomObject]@{
                        Name = $user.Name
                        Email = $user.Email
                        AccountId = "Existing"
                        Status = "AlreadyExists"
                    }) | Out-Null
                } else {
                    Write-Host " ❌ FAILED" -ForegroundColor Red
                    Write-Warning "    Error: $errorMsg"
                    $failedInvitations.Add([PSCustomObject]@{
                        Name = $user.Name
                        Email = $user.Email
                        Reason = $errorMsg
                    }) | Out-Null
                }
            }
        }
        
        Write-Host ""
        Write-Host "=== INVITATION SUMMARY ===" -ForegroundColor Cyan
        Write-Host "  Successfully invited: $(if ($invitedUsers) { $invitedUsers.Count } else { 0 })" -ForegroundColor Green
        Write-Host "  Failed invitations: $(if ($failedInvitations) { $failedInvitations.Count } else { 0 })" -ForegroundColor $(if ($failedInvitations -and $failedInvitations.Count -gt 0) { "Red" } else { "Green" })
        
        if ($failedInvitations -and $failedInvitations.Count -gt 0) {
            $failedInviteFile = Join-Path $outDir "failed_invitations.csv"
            $failedInvitations | Export-Csv -Path $failedInviteFile -NoTypeInformation -Encoding UTF8
            Write-Host "  Failed invitations saved to: $failedInviteFile" -ForegroundColor Yellow
        }
        
        if ($invitedUsers -and $invitedUsers.Count -gt 0) {
            $successInviteFile = Join-Path $outDir "invited_users.csv"
            $invitedUsers | Export-Csv -Path $successInviteFile -NoTypeInformation -Encoding UTF8
            Write-Host "  Invited users saved to: $successInviteFile" -ForegroundColor Green
        }
        
        # ============================================================
        # AUTOMATIC PROJECT ASSIGNMENT AFTER INVITATION
        # ============================================================
        if ($invitedUsers -and $invitedUsers.Count -gt 0) {
            Write-Host ""
            Write-Host "=== ADDING INVITED USERS TO TARGET PROJECT ===" -ForegroundColor Cyan
            Write-Host "Waiting 5 seconds for user provisioning to complete..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            Write-Host ""
            
            $addedToProject = 0
            $failedToAdd = 0
            
            # Get the target project again
            $tgtProj = Get-Project -Base $tgtBase -Hdr $tgtHdr -Key $tgtKey
            $tgtRoles = Get-ProjectRoles -Base $tgtBase -Hdr $tgtHdr -ProjectId $tgtProj.id
            
            foreach ($invitedUser in $invitedUsers) {
                # Skip if user already existed
                if ($invitedUser.Status -eq "AlreadyExists") {
                    continue
                }
                
                # Find original user info to get their role
                $originalUser = $usersToInvite | Where-Object { $_.Email -eq $invitedUser.Email } | Select-Object -First 1
                if (-not $originalUser) {
                    Write-Warning "  Could not find original role info for $($invitedUser.Email)"
                    continue
                }
                
                $roleName = $originalUser.Role
                Write-Host "  Adding $($invitedUser.Name) to role: $roleName..." -NoNewline
                
                # Get target role URL
                $tgtRoleUrl = $tgtRoles.$roleName
                if (-not $tgtRoleUrl) {
                    Write-Host " ⚠️  Role not found in target" -ForegroundColor Yellow
                    $failedToAdd++
                    continue
                }
                
                # Try to get the user's account ID in target
                try {
                    # Wait a bit before each user lookup
                    Start-Sleep -Milliseconds 500
                    
                    # Search for user by email
                    $searchUri = "{0}/rest/api/3/user/search?query={1}" -f $tgtBase.TrimEnd('/'), [uri]::EscapeDataString($invitedUser.Email)
                    $foundUsers = Invoke-RestMethod -Method GET -Uri $searchUri -Headers $tgtHdr -ErrorAction Stop
                    
                    if ($foundUsers -and $foundUsers.Count -gt 0) {
                        $targetAccountId = $foundUsers[0].accountId
                        
                        # Add user to role
                        $res = Add-User-To-Role -Hdr $tgtHdr -RoleUrl $tgtRoleUrl -AccountId $targetAccountId
                        
                        # Handle case where function returns an array
                        if ($res -is [array]) {
                            $res = $res[-1]
                        }
                        
                        if ($res -and $res.ok) {
                            Write-Host " ✅ SUCCESS" -ForegroundColor Green
                            $addedToProject++
                        } else {
                            $errorMsg = if ($res -and $res.msg) { $res.msg } else { "Unknown error" }
                            # Check if already in role
                            if ($errorMsg -match "already" -or $errorMsg -match "duplicate") {
                                Write-Host " ℹ️  Already in role" -ForegroundColor Yellow
                                $addedToProject++
                            } else {
                                Write-Host " ❌ $errorMsg" -ForegroundColor Red
                                $failedToAdd++
                            }
                        }
                    } else {
                        Write-Host " ⏳ Not yet provisioned" -ForegroundColor Yellow
                        $failedToAdd++
                    }
                    
                } catch {
                    Write-Host " ❌ $($_.Exception.Message)" -ForegroundColor Red
                    $failedToAdd++
                }
            }
            
            Write-Host ""
            Write-Host "=== PROJECT ASSIGNMENT SUMMARY ===" -ForegroundColor Cyan
            Write-Host "  Added to project: $addedToProject" -ForegroundColor Green
            Write-Host "  Failed to add: $failedToAdd" -ForegroundColor $(if ($failedToAdd -gt 0) { "Yellow" } else { "Green" })
            
            if ($failedToAdd -gt 0) {
                Write-Host ""
                Write-Host "  💡 Some users may not be provisioned yet." -ForegroundColor Yellow
                Write-Host "     Re-run Step 03 after a few minutes to retry." -ForegroundColor Yellow
            }
        }
        
    } else {
        Write-Host "   Top 10 users to invite:" -ForegroundColor Cyan
        $usersToInvite | Select-Object -First 10 | ForEach-Object {
            Write-Host "     - $($_.Name) ($($_.Email))"
        }
        Write-Host ""
        Write-Host "   💡 TIP: Enable automatic invitation by setting 'AutoInvite: true' in parameters.json" -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ No users need to be invited - all users successfully synced!" -ForegroundColor Green
}

# Create simple receipt with just timestamps
$startTime = Get-Date
$receiptData = @{
    StartTime = $startTime.ToString("yyyy-MM-ddTHH:mm:ss")
    EndTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    UserReportFile = if ($userActivityReportFile) { $userActivityReportFile } else { $null }
    UsersAnalyzed = if ($allUsersActivityData) { $allUsersActivityData.Count } else { 0 }
}

# Write receipt
$receiptPath = Join-Path $outDir "03_SyncUsersAndRoles_receipt.json"
try {
    $receiptData | ConvertTo-Json -Depth 3 | Out-File -FilePath $receiptPath -Encoding UTF8
    Write-Host "✅ Receipt written: $receiptPath" -ForegroundColor Green
} catch {
    Write-Warning "Failed to write receipt: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "✅ Step 03 completed successfully!" -ForegroundColor Green
exit 0
