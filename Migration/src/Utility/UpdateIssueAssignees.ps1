# UpdateIssueAssignees.ps1 - Update assignees on existing issues
#
# PURPOSE: Update assignee field on migrated issues after users have been invited
#
param(
    [string]$Project = "LAS",
    [switch]$PreviewOnly
)

$ErrorActionPreference = "Stop"

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  UPDATING ISSUE ASSIGNEES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($PreviewOnly) {
    Write-Host "🔍 PREVIEW MODE - No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

# Load common functions
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path (Split-Path -Parent $here) "_common.ps1")

# Load parameters
$projectsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "projects"
$ParametersPath = Join-Path $projectsDir "$Project\parameters.json"
$p = Read-JsonFile -Path $ParametersPath

$outDir = $p.OutputSettings.OutputDirectory
$exportFile = Join-Path $outDir "exports\source_issues_export.json"
$keyMappingFile = Join-Path $outDir "exports\source_to_target_key_mapping.json"

# Validate files exist
if (-not (Test-Path $exportFile)) {
    Write-Host "❌ Export file not found: $exportFile" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $keyMappingFile)) {
    Write-Host "❌ Key mapping file not found: $keyMappingFile" -ForegroundColor Red
    Write-Host "   Run Step 08 first to create issues" -ForegroundColor Yellow
    exit 1
}

# Target environment setup
$tgtBase = $p.TargetEnvironment.BaseUrl
$tgtEmail = $p.TargetEnvironment.Username
$tgtTok = $p.TargetEnvironment.ApiToken
$tgtKey = $p.TargetEnvironment.ProjectKey
$tgtHdr = New-BasicAuthHeader -Email $tgtEmail -ApiToken $tgtTok

Write-Host "Target: $tgtBase ($tgtKey)" -ForegroundColor Gray
Write-Host ""

# Load data
Write-Host "Loading exported issues..."
$sourceIssues = Get-Content $exportFile -Raw | ConvertFrom-Json
Write-Host "Loaded $($sourceIssues.Count) source issues" -ForegroundColor Green

Write-Host "Loading key mapping..."
$keyMapping = Get-Content $keyMappingFile -Raw | ConvertFrom-Json
$mappingCount = ($keyMapping.PSObject.Properties | Measure-Object).Count
Write-Host "Loaded $mappingCount key mappings" -ForegroundColor Green
Write-Host ""

# Function to get current issue details
function Get-IssueDetails {
    param([string]$IssueKey)
    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$IssueKey"
        $response = Invoke-RestMethod -Method GET -Uri $uri -Headers $tgtHdr -ErrorAction Stop
        return $response
    } catch {
        return $null
    }
}

# Function to update issue assignee
function Update-IssueAssignee {
    param([string]$IssueKey, [string]$AccountId, [string]$DisplayName)
    try {
        $uri = "$($tgtBase.TrimEnd('/'))/rest/api/3/issue/$IssueKey"
        $body = @{
            fields = @{
                assignee = @{
                    accountId = $AccountId
                }
            }
        } | ConvertTo-Json -Depth 5
        
        $response = Invoke-RestMethod -Method PUT -Uri $uri -Headers $tgtHdr -Body $body -ContentType "application/json" -ErrorAction Stop
        return @{ success = $true; error = $null; fullError = $null }
    } catch {
        # Check if it's a permission error
        $errorMsg = $_.Exception.Message
        $fullErrorDetails = $null
        if ($_.ErrorDetails.Message) {
            try {
                $fullErrorDetails = $_.ErrorDetails.Message
                $errorObj = $fullErrorDetails | ConvertFrom-Json
                if ($errorObj.errors -and $errorObj.errors.PSObject.Properties.Name -contains 'assignee') {
                    $errorMsg = $errorObj.errors.assignee
                }
            } catch { }
        }
        return @{ success = $false; error = $errorMsg; fullError = $fullErrorDetails; displayName = $DisplayName; accountId = $AccountId }
    }
}

# Process issues
Write-Host "Processing issues..." -ForegroundColor Yellow
Write-Host ""

$stats = @{
    Total = 0
    Updated = 0
    AlreadyCorrect = 0
    NoAssignee = 0
    PermissionError = 0
    NotFound = 0
    OtherError = 0
}

foreach ($sourceIssue in $sourceIssues) {
    $stats.Total++
    $sourceKey = $sourceIssue.key
    
    # Get target key from mapping
    if (-not ($keyMapping.PSObject.Properties.Name -contains $sourceKey)) {
        Write-Host "  ⚠️  $sourceKey - Not found in mapping (skipped)" -ForegroundColor Yellow
        $stats.NotFound++
        continue
    }
    
    $targetKey = $keyMapping.$sourceKey
    
    # Check if source issue has an assignee
    if (-not $sourceIssue.fields.assignee) {
        Write-Host "  ⏭️  $sourceKey → $targetKey - No assignee in source (skipped)" -ForegroundColor Gray
        $stats.NoAssignee++
        continue
    }
    
    $sourceAssignee = $sourceIssue.fields.assignee
    $sourceAccountId = $sourceAssignee.accountId
    $sourceDisplayName = $sourceAssignee.displayName
    
    # Get current target issue details
    $targetIssue = Get-IssueDetails -IssueKey $targetKey
    if (-not $targetIssue) {
        Write-Host "  ❌ $sourceKey → $targetKey - Target issue not found" -ForegroundColor Red
        $stats.NotFound++
        continue
    }
    
    # Check if already assigned correctly
    if ($targetIssue.fields.assignee -and $targetIssue.fields.assignee.accountId -eq $sourceAccountId) {
        Write-Host "  ✅ $sourceKey → $targetKey - Already assigned to $sourceDisplayName" -ForegroundColor Green
        $stats.AlreadyCorrect++
        continue
    }
    
    # Preview mode - just show what would be done
    if ($PreviewOnly) {
        $currentAssignee = if ($targetIssue.fields.assignee) { $targetIssue.fields.assignee.displayName } else { "Unassigned" }
        Write-Host "  🔍 $sourceKey → $targetKey - Would update: $currentAssignee → $sourceDisplayName" -ForegroundColor Cyan
        continue
    }
    
    # Update assignee
    Write-Host "  🔄 $sourceKey → $targetKey - Updating to $sourceDisplayName..." -NoNewline
    $result = Update-IssueAssignee -IssueKey $targetKey -AccountId $sourceAccountId -DisplayName $sourceDisplayName
    
    if ($result.success) {
        Write-Host " ✅ Updated" -ForegroundColor Green
        $stats.Updated++
    } else {
        if ($result.error -like "*cannot be assigned*") {
            Write-Host " ⚠️  Permission error" -ForegroundColor Yellow
            $stats.PermissionError++
            # Log first error details for debugging
            if ($stats.PermissionError -eq 1) {
                Write-Host ""
                Write-Host "  📋 First permission error details:" -ForegroundColor Magenta
                Write-Host "     User: $sourceDisplayName ($sourceAccountId)" -ForegroundColor Gray
                Write-Host "     Error: $($result.error)" -ForegroundColor Gray
                if ($result.fullError) {
                    Write-Host "     Full error: $($result.fullError)" -ForegroundColor Gray
                }
                Write-Host ""
            }
        } else {
            Write-Host " ❌ Failed: $($result.error)" -ForegroundColor Red
            $stats.OtherError++
        }
    }
    
    # Rate limiting - small delay between updates
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  UPDATE SUMMARY" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host ("Total issues processed:     {0}" -f $stats.Total) -ForegroundColor White
Write-Host ("✅ Updated successfully:     {0}" -f $stats.Updated) -ForegroundColor Green
Write-Host ("✅ Already correct:          {0}" -f $stats.AlreadyCorrect) -ForegroundColor Green
Write-Host ("⏭️  No assignee in source:   {0}" -f $stats.NoAssignee) -ForegroundColor Gray
Write-Host ("⚠️  Permission errors:       {0}" -f $stats.PermissionError) -ForegroundColor Yellow
Write-Host ("❌ Not found in target:      {0}" -f $stats.NotFound) -ForegroundColor Red
Write-Host ("❌ Other errors:             {0}" -f $stats.OtherError) -ForegroundColor Red
Write-Host ""

if ($PreviewOnly) {
    Write-Host "📋 Preview complete. To apply changes, run without -PreviewOnly flag" -ForegroundColor Cyan
} else {
    if ($stats.Updated -gt 0) {
        Write-Host "🎉 Successfully updated $($stats.Updated) assignees!" -ForegroundColor Green
    }
    if ($stats.PermissionError -gt 0) {
        Write-Host "⚠️  $($stats.PermissionError) users don't have assignment permissions - invite them to the project" -ForegroundColor Yellow
    }
}
Write-Host ""

