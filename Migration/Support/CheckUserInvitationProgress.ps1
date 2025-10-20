# CheckUserInvitationProgress.ps1 - Track user invitation progress
#
# PURPOSE: Check which users from the invitation list exist in the target Jira instance
#
param(
    [string]$Project = "LAS"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CHECKING USER INVITATION PROGRESS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Load common functions
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Load parameters
$projectsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "projects"
$ParametersPath = Join-Path $projectsDir "$Project\parameters.json"
$p = Read-JsonFile -Path $ParametersPath

$outDir = $p.OutputSettings.OutputDirectory
$inviteFile = Join-Path $outDir "users_to_invite.csv"

if (-not (Test-Path $inviteFile)) {
    Write-Host "❌ Invitation list not found: $inviteFile" -ForegroundColor Red
    Write-Host "   Run .\src\Utility\CreateUserInvitationList.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Target environment setup
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host "Target: $tgtBase" -ForegroundColor Gray
Write-Host ""

# Load users to check
$usersToCheck = Import-Csv $inviteFile
Write-Host "Loaded $($usersToCheck.Count) users from invitation list" -ForegroundColor White
Write-Host ""
Write-Host "Checking user status in target Jira..." -ForegroundColor Yellow
Write-Host ""

# Function to check if user exists
function Test-UserExists {
    param([string] $Base, [hashtable] $Hdr, [string] $AccountId)
    try {
        $uri = "{0}/rest/api/3/user?accountId={1}" -f $Base.TrimEnd('/'), [uri]::EscapeDataString($AccountId)
        $null = Invoke-RestMethod -Method GET -Uri $uri -Headers $Hdr -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Check each user
$existingUsers = @()
$missingUsers = @()
$checkErrors = @()

$i = 0
foreach ($user in $usersToCheck) {
    $i++
    Write-Progress -Activity "Checking users" -Status "Checking $($user.DisplayName)..." -PercentComplete (($i / $usersToCheck.Count) * 100)
    
    try {
        $exists = Test-UserExists -Base $tgtBase -Hdr $tgtHdr -AccountId $user.AccountId
        
        if ($exists) {
            $existingUsers += $user
            Write-Host ("  ✅ {0,-40} {1}" -f $user.DisplayName, $user.Email) -ForegroundColor Green
        } else {
            $missingUsers += $user
            Write-Host ("  ❌ {0,-40} {1}" -f $user.DisplayName, $user.Email) -ForegroundColor Red
        }
    } catch {
        $checkErrors += $user
        Write-Host ("  ⚠️  {0,-40} {1} (check failed)" -f $user.DisplayName, $user.Email) -ForegroundColor Yellow
    }
}

Write-Progress -Activity "Checking users" -Completed

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  INVITATION PROGRESS SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Total users:              {0}" -f $usersToCheck.Count) -ForegroundColor White
Write-Host ("✅ Already invited:        {0}  ({1:P0})" -f $existingUsers.Count, ($existingUsers.Count / $usersToCheck.Count)) -ForegroundColor Green
Write-Host ("❌ Still need invitation:  {0}  ({1:P0})" -f $missingUsers.Count, ($missingUsers.Count / $usersToCheck.Count)) -ForegroundColor Red
if ($checkErrors.Count -gt 0) {
    Write-Host ("⚠️  Check errors:          {0}" -f $checkErrors.Count) -ForegroundColor Yellow
}
Write-Host ""

# Save detailed results
$resultsFile = Join-Path $outDir "user_invitation_progress.json"
$results = @{
    CheckedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    TotalUsers = $usersToCheck.Count
    ExistingUsers = @($existingUsers | ForEach-Object { 
        @{
            DisplayName = $_.DisplayName
            Email = $_.Email
            AccountId = $_.AccountId
            IssueCount = $_.IssueCount
        }
    })
    MissingUsers = @($missingUsers | ForEach-Object { 
        @{
            DisplayName = $_.DisplayName
            Email = $_.Email
            AccountId = $_.AccountId
            IssueCount = $_.IssueCount
        }
    })
    CheckErrors = @($checkErrors | ForEach-Object { 
        @{
            DisplayName = $_.DisplayName
            Email = $_.Email
            AccountId = $_.AccountId
        }
    })
}
$results | ConvertTo-Json -Depth 10 | Set-Content $resultsFile -Encoding UTF8
Write-Host "💾 Detailed results saved: $resultsFile" -ForegroundColor Cyan
Write-Host ""

# Show next steps
if ($missingUsers.Count -eq 0) {
    Write-Host "🎉 ALL USERS INVITED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Ready to run Step 03 to add users as Administrators:" -ForegroundColor Green
    Write-Host "   .\RunMigration.ps1 -Project LAS -Step 03" -ForegroundColor White
} else {
    Write-Host "📋 NEXT STEPS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Invite the missing users (see list above)" -ForegroundColor White
    Write-Host "   • Option A: Atlassian Admin Console - https://admin.atlassian.com" -ForegroundColor Gray
    Write-Host "   • Option B: LAS1 Project Settings → People → Add people" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Re-run this script to check progress:" -ForegroundColor White
    Write-Host "   .\src\Utility\CheckUserInvitationProgress.ps1 -Project LAS" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. When all users are invited, run Step 03:" -ForegroundColor White
    Write-Host "   .\RunMigration.ps1 -Project LAS -Step 03" -ForegroundColor Gray
    Write-Host ""
    
    # Show top priority missing users
    if ($missingUsers.Count -gt 0) {
        Write-Host "🔥 TOP PRIORITY MISSING USERS (by issue count):" -ForegroundColor Yellow
        $missingUsers | Sort-Object { [int]$_.IssueCount } -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host ("   • {0,-40} {1,-45} ({2} issues)" -f $_.DisplayName, $_.Email, $_.IssueCount) -ForegroundColor Gray
        }
    }
}

Write-Host ""

