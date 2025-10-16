# =============================================================================
# Generate-ProjectCreationScripts.ps1
# =============================================================================
# Script to generate CreateNewStandardProject.ps1 commands for all projects
# found in the OneMain Financial Migration Sandbox
#
# This script reads the AllProjects_Report.csv and generates the appropriate
# PowerShell commands for each project.
#
# Usage: .\Generate-ProjectCreationScripts.ps1
# =============================================================================

param(
    [string] $InputCsv = ".\AllProjects_Report.csv",
    [string] $OutputScript = ".\CreateAllStandardProjects.ps1",
    [switch] $IncludeComments = $true,
    [switch] $GroupByCategory = $true
)

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

# =============================================================================
# Main Script
# =============================================================================

Write-Header "Generate Project Creation Scripts"

try {
    # Check if input CSV exists
    if (-not (Test-Path $InputCsv)) {
        Write-Error "Input CSV file not found: $InputCsv"
        Write-Info "Please run Get-AllProjects.ps1 first to generate the project list"
        exit 1
    }
    
    Write-Info "Reading project data from: $InputCsv"
    
    # Import the CSV data
    $projects = Import-Csv $InputCsv
    
    Write-Success "Loaded $($projects.Count) projects from CSV"
    
    # Prepare the output script content
    $scriptContent = @()
    
    # Add header comments
    if ($IncludeComments) {
        $scriptContent += "# ============================================================================="
        $scriptContent += "# CreateAllStandardProjects.ps1"
        $scriptContent += "# ============================================================================="
        $scriptContent += "# Generated script to create all standard projects in OneMain Financial Migration Sandbox"
        $scriptContent += "# Generated on: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        $scriptContent += "# Total Projects: $($projects.Count)"
        $scriptContent += "#"
        $scriptContent += "# Usage: .\CreateAllStandardProjects.ps1"
        $scriptContent += "# Note: This script will create projects in the target environment"
        $scriptContent += "# ============================================================================="
        $scriptContent += ""
        $scriptContent += "Write-Host 'Starting creation of all standard projects...' -ForegroundColor Green"
        $scriptContent += "Write-Host 'Total projects to create: $($projects.Count)' -ForegroundColor Blue"
        $scriptContent += ""
    }
    
    # Group projects by category if requested
    if ($GroupByCategory) {
        $groupedProjects = $projects | Group-Object "Project Category" | Sort-Object Name
        
        foreach ($group in $groupedProjects) {
            $categoryName = if ($group.Name -eq "None") { "Uncategorized" } else { $group.Name }
            
            if ($IncludeComments) {
                $scriptContent += "# ============================================================================="
                $scriptContent += "# $categoryName Projects ($($group.Count) projects)"
                $scriptContent += "# ============================================================================="
            }
            
            foreach ($project in $group.Group) {
                $command = ".\CreateNewStandardProject.ps1 -ProjectKey `"$($project.'Project Key')`""
                $scriptContent += $command
            }
            
            if ($IncludeComments) {
                $scriptContent += ""
            }
        }
    } else {
        # Simple alphabetical order
        $sortedProjects = $projects | Sort-Object "Project Key"
        
        foreach ($project in $sortedProjects) {
            $command = ".\CreateNewStandardProject.ps1 -ProjectKey `"$($project.'Project Key')`""
            $scriptContent += $command
        }
    }
    
    # Add footer
    if ($IncludeComments) {
        $scriptContent += ""
        $scriptContent += "# ============================================================================="
        $scriptContent += "# Script completed"
        $scriptContent += "# ============================================================================="
        $scriptContent += ""
        $scriptContent += "Write-Host 'All project creation commands completed!' -ForegroundColor Green"
    }
    
    # Write the script to file
    $scriptContent | Out-File -FilePath $OutputScript -Encoding UTF8
    
    Write-Success "Generated project creation script: $OutputScript"
    Write-Info "📄 Location: $((Resolve-Path $OutputScript).Path)"
    Write-Info "📊 Total commands generated: $($projects.Count)"
    
    # Display summary statistics
    Write-Header "Summary Statistics"
    
    $categories = $projects | Group-Object "Project Category" | Sort-Object Count -Descending
    Write-Host "Projects by Category:" -ForegroundColor White
    foreach ($category in $categories) {
        $categoryName = if ($category.Name -eq "None") { "Uncategorized" } else { $category.Name }
        Write-Host "  $categoryName : $($category.Count)" -ForegroundColor Gray
    }
    
    # Show first few commands as preview
    Write-Header "Preview of Generated Commands"
    $previewCount = [Math]::Min(10, $projects.Count)
    $previewProjects = $projects | Select-Object -First $previewCount
    
    foreach ($project in $previewProjects) {
        Write-Host ".\CreateNewStandardProject.ps1 -ProjectKey `"$($project.'Project Key')`"" -ForegroundColor White
    }
    
    if ($projects.Count -gt $previewCount) {
        Write-Host "... and $($projects.Count - $previewCount) more commands" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Success "Script generation completed successfully!"
    Write-Info "You can now run: .\$OutputScript"
    
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
