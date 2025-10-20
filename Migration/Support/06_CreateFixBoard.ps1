# CreateFixBoard.ps1 - Create the missing FIX - LAS Online DSU board
#
# PURPOSE: Manually create the board that couldn't be created due to JQL issues
#
param(
    [string]$Project = "LAS"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating FIX - LAS Online DSU board for project $Project" -ForegroundColor Yellow

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

Write-Host "Target Project: $tgtKey" -ForegroundColor Cyan

# Create the filter first
$filterName = "LAS1 - FIX - LAS Online DSU (manual creation)"
$filterJql = "project = $tgtKey ORDER BY Rank ASC"
$filterDesc = "Manual creation for LAS Online DSU board - JQL needs to be updated to match original assignee-based filter"

$filterPayload = @{
    name             = $filterName
    jql              = $filterJql
    description      = $filterDesc
    favourite        = $false
    sharePermissions = @(@{ type="project"; project=@{ id=[int]10597 } })
} | ConvertTo-Json -Depth 10

try {
    Write-Host "Creating filter..." -ForegroundColor Yellow
    $createFilterUri = "$($tgtBase.TrimEnd('/'))/rest/api/3/filter"
    $filterResp = Invoke-RestMethod -Method POST -Uri $createFilterUri -Headers $tgtHdr -Body $filterPayload -ContentType "application/json" -ErrorAction Stop
    $filterId = $filterResp.id
    Write-Host "✅ Created filter '$filterName' (id: $filterId)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create filter: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create the board
$boardName = "FIX - LAS Online DSU"
$boardPayload = @{
    name      = $boardName
    type      = "kanban"
    filterId  = [int]$filterId
    location  = @{ type = "project"; projectKeyOrId = $tgtKey }
} | ConvertTo-Json -Depth 8

try {
    Write-Host "Creating board..." -ForegroundColor Yellow
    $createBoardUri = "$($tgtBase.TrimEnd('/'))/rest/agile/1.0/board"
    $boardResp = Invoke-RestMethod -Method POST -Uri $createBoardUri -Headers $tgtHdr -Body $boardPayload -ContentType "application/json" -ErrorAction Stop
    $boardId = $boardResp.id
    Write-Host "✅ Created board '$boardName' (id: $boardId)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to create board: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "🎉 Successfully created FIX - LAS Online DSU board!" -ForegroundColor Green
Write-Host "   Board ID: $boardId" -ForegroundColor Cyan
Write-Host "   Filter ID: $filterId" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  NOTE: The JQL filter needs to be manually updated to match the original assignee-based filter" -ForegroundColor Yellow
Write-Host "   Original JQL was: assignee IN (list of user IDs) ORDER BY Rank ASC" -ForegroundColor Gray
