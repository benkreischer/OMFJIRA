# =============================================================================
# Get-AllProjects.ps1
# =============================================================================
# Script to list all projects in the OneMain Financial Migration Sandbox
# 
# This script queries the Jira API to retrieve all projects and their details
# from the onemainfinancial-migrationsandbox.atlassian.net instance.
#
# Usage: .\Get-AllProjects.ps1
# =============================================================================

param(
    [string] $OutputFile = ".\AllProjects_Report.csv",
    [switch] $ShowDetails = $false,
    [switch] $ExportToCsv = $true
)

# =============================================================================
# Configuration
# =============================================================================

# Target environment configuration (from existing parameters)
$targetEnvironment = @{
    BaseUrl = "https://onemainfinancial-migrationsandbox.atlassian.net/"
    Username = "ben.kreischer.ce@omf.com"
    ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"
}

# =============================================================================
# Helper Functions
# =============================================================================

function Write-Header {
    param([string] $Title)
    
    Write-Host ""
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
}

function Write-Success {
    param([string] $Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string] $Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Warning {
    param([string] $Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string] $Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Invoke-JiraWithRetry {
    param(
        [string] $Uri,
        [hashtable] $Headers,
        [int] $MaxRetries = 3,
        [int] $RetryDelaySeconds = 2
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            $response = Invoke-RestMethod -Method GET -Uri $Uri -Headers $Headers -ErrorAction Stop
            return $response
        }
        catch {
            if ($attempt -eq $MaxRetries) {
                throw "Failed after $MaxRetries attempts: $($_.Exception.Message)"
            }
            
            Write-Warning "Attempt $attempt failed: $($_.Exception.Message). Retrying in $RetryDelaySeconds seconds..."
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }
}

# =============================================================================
# Main Script
# =============================================================================

Write-Header "OneMain Financial Migration Sandbox - Project List"

try {
    # Prepare authentication headers
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $targetEnvironment.Username, $targetEnvironment.ApiToken)))
    $headers = @{
        Authorization = "Basic $base64AuthInfo"
        Accept = "application/json"
        "Content-Type" = "application/json"
    }
    
    Write-Info "Connecting to: $($targetEnvironment.BaseUrl)"
    Write-Info "Username: $($targetEnvironment.Username)"
    
    # Get all projects
    $projectsUri = "$($targetEnvironment.BaseUrl.TrimEnd('/'))/rest/api/3/project"
    Write-Info "Fetching all projects from API..."
    
    $allProjects = Invoke-JiraWithRetry -Uri $projectsUri -Headers $headers
    
    Write-Success "Retrieved $($allProjects.Count) projects from the migration sandbox"
    
    # Display summary
    Write-Header "Project Summary"
    Write-Host "Total Projects: $($allProjects.Count)" -ForegroundColor White
    Write-Host ""
    
    # Prepare data for display and export
    $projectData = @()
    $projectCounter = 0
    
    foreach ($project in $allProjects) {
        $projectCounter++
        
        # Get additional project details
        try {
            $projectDetailsUri = "$($targetEnvironment.BaseUrl.TrimEnd('/'))/rest/api/3/project/$($project.key)"
            $projectDetails = Invoke-JiraWithRetry -Uri $projectDetailsUri -Headers $headers
            
            # Extract key information
            $projectInfo = [PSCustomObject]@{
                "Project Key" = $project.key
                "Project Name" = $project.name
                "Project Type" = $project.projectTypeKey
                "Project Category" = if ($projectDetails.projectCategory) { $projectDetails.projectCategory.name } else { "None" }
                "Project Lead" = if ($projectDetails.lead) { $projectDetails.lead.displayName } else { "None" }
                "Project Lead Email" = if ($projectDetails.lead) { $projectDetails.lead.emailAddress } else { "None" }
                "Description" = if ($projectDetails.description) { $projectDetails.description } else { "None" }
                "URL" = $project.self
                "Avatar URL" = if ($project.avatarUrls) { $project.avatarUrls.'48x48' } else { "None" }
                "Issue Types Count" = if ($projectDetails.issueTypes) { $projectDetails.issueTypes.Count } else { 0 }
                "Components Count" = if ($projectDetails.components) { $projectDetails.components.Count } else { 0 }
                "Versions Count" = if ($projectDetails.versions) { $projectDetails.versions.Count } else { 0 }
                "Roles Count" = if ($projectDetails.roles) { $projectDetails.roles.Count } else { 0 }
                "Created" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            
            $projectData += $projectInfo
            
            # Display project info
            if ($ShowDetails) {
                Write-Host "[$projectCounter] $($project.key) - $($project.name)" -ForegroundColor White
                Write-Host "    Type: $($project.projectTypeKey)" -ForegroundColor Gray
                Write-Host "    Category: $(if ($projectDetails.projectCategory) { $projectDetails.projectCategory.name } else { 'None' })" -ForegroundColor Gray
                Write-Host "    Lead: $(if ($projectDetails.lead) { $projectDetails.lead.displayName } else { 'None' })" -ForegroundColor Gray
                Write-Host "    Issue Types: $(if ($projectDetails.issueTypes) { $projectDetails.issueTypes.Count } else { 0 })" -ForegroundColor Gray
                Write-Host "    Components: $(if ($projectDetails.components) { $projectDetails.components.Count } else { 0 })" -ForegroundColor Gray
                Write-Host "    Versions: $(if ($projectDetails.versions) { $projectDetails.versions.Count } else { 0 })" -ForegroundColor Gray
                Write-Host ""
            } else {
                Write-Host "[$projectCounter] $($project.key) - $($project.name)" -ForegroundColor White
            }
            
        } catch {
            Write-Warning "Failed to get details for project $($project.key): $($_.Exception.Message)"
            
            # Add basic project info even if details fail
            $projectInfo = [PSCustomObject]@{
                "Project Key" = $project.key
                "Project Name" = $project.name
                "Project Type" = $project.projectTypeKey
                "Project Category" = "Error"
                "Project Lead" = "Error"
                "Project Lead Email" = "Error"
                "Description" = "Error retrieving details"
                "URL" = $project.self
                "Avatar URL" = "None"
                "Issue Types Count" = 0
                "Components Count" = 0
                "Versions Count" = 0
                "Roles Count" = 0
                "Created" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            
            $projectData += $projectInfo
        }
    }
    
    # Export to CSV if requested
    if ($ExportToCsv) {
        try {
            $projectData | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
            Write-Success "Project data exported to: $OutputFile"
            Write-Info "📄 Location: $((Resolve-Path $OutputFile).Path)"
            Write-Info "📊 Total projects exported: $($projectData.Count)"
        } catch {
            Write-Error "Failed to export CSV: $($_.Exception.Message)"
        }
    }
    
    # Display summary statistics
    Write-Header "Summary Statistics"
    
    $projectTypes = $projectData | Group-Object "Project Type" | Sort-Object Count -Descending
    Write-Host "Project Types:" -ForegroundColor White
    foreach ($type in $projectTypes) {
        Write-Host "  $($type.Name): $($type.Count)" -ForegroundColor Gray
    }
    
    Write-Host ""
    $categories = $projectData | Where-Object { $_.'Project Category' -ne "None" -and $_.'Project Category' -ne "Error" } | Group-Object "Project Category" | Sort-Object Count -Descending
    if ($categories.Count -gt 0) {
        Write-Host "Project Categories:" -ForegroundColor White
        foreach ($category in $categories) {
            Write-Host "  $($category.Name): $($category.Count)" -ForegroundColor Gray
        }
    } else {
        Write-Host "No project categories found" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Success "Project listing completed successfully!"
    
    if (-not $ShowDetails) {
        Write-Info "Use -ShowDetails switch to see detailed information for each project"
    }
    
    if (-not $ExportToCsv) {
        Write-Info "Use -ExportToCsv switch to export data to CSV file"
    }
    
} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Host "Stack Trace:" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host " Script completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
