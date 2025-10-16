# CreateUserInvitationList.ps1 - Generate list of users to invite based on exported issues
#
# PURPOSE: Extract unique users from exported issues and create an invitation list
#
param(
    [string]$Project = "LAS"
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CREATING USER INVITATION LIST" -ForegroundColor Cyan
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
$exportFile = Join-Path $outDir "exports\source_issues_export.json"

if (-not (Test-Path $exportFile)) {
    Write-Host "❌ Export file not found: $exportFile" -ForegroundColor Red
    Write-Host "   Run Step 07 first to export issues" -ForegroundColor Yellow
    exit 1
}

Write-Host "Loading exported issues..."
$exportedIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
Write-Host "Loaded $($exportedIssues.Count) issues" -ForegroundColor Green
Write-Host ""

# Extract unique users from exported issues
Write-Host "Extracting unique users from issues..."
$uniqueUsers = @{}

foreach ($issue in $exportedIssues) {
    # Get assignee
    if ($issue.fields.assignee) {
        $accountId = $issue.fields.assignee.accountId
        if (-not $uniqueUsers.ContainsKey($accountId)) {
            $uniqueUsers[$accountId] = [PSCustomObject]@{
                DisplayName = $issue.fields.assignee.displayName
                Email = $issue.fields.assignee.emailAddress
                AccountId = $accountId
                IssueCount = 1
            }
        } else {
            $uniqueUsers[$accountId].IssueCount++
        }
    }
    
    # Get reporter
    if ($issue.fields.reporter) {
        $accountId = $issue.fields.reporter.accountId
        if (-not $uniqueUsers.ContainsKey($accountId)) {
            $uniqueUsers[$accountId] = [PSCustomObject]@{
                DisplayName = $issue.fields.reporter.displayName
                Email = $issue.fields.reporter.emailAddress
                AccountId = $accountId
                IssueCount = 0
            }
        }
    }
}

Write-Host "Found $($uniqueUsers.Count) unique users" -ForegroundColor Yellow
Write-Host ""

# Convert to array and sort by issue count
$userList = $uniqueUsers.Values | Sort-Object -Property IssueCount -Descending

# Save to CSV
$inviteFile = Join-Path $outDir "users_to_invite.csv"
$userList | Select-Object DisplayName, Email, AccountId, IssueCount | Export-Csv -Path $inviteFile -NoTypeInformation -Encoding UTF8

Write-Host "✅ Created user invitation list: $inviteFile" -ForegroundColor Green
Write-Host ""
Write-Host "Top 20 users by issue count:" -ForegroundColor Cyan
$userList | Select-Object -First 20 | ForEach-Object {
    Write-Host ("  {0,-40} {1,-45} ({2} issues)" -f $_.DisplayName, $_.Email, $_.IssueCount) -ForegroundColor Gray
}

Write-Host ""
Write-Host "📧 Invite these users to the LAS1 project in Jira" -ForegroundColor Yellow
Write-Host "   File: $inviteFile" -ForegroundColor White

