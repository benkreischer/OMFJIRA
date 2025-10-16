# =============================================================================
# PowerBI Desktop Connection Script
# =============================================================================
# This script creates a PowerBI Desktop file that connects to all CSV files
# =============================================================================

# Load PowerBI module (if available)
if (Get-Module -ListAvailable -Name "PowerBI") {
    Import-Module PowerBI
} else {
    Write-Host "PowerBI module not available. Please install PowerBI Desktop and use the template file." -ForegroundColor Yellow
    Write-Host "Template file created at: PowerBI_Audit\Jira_Audit_Template.json" -ForegroundColor Green
    exit
}

# Create new PowerBI workspace
$workspace = New-PowerBIWorkspace -Name "Jira Audit Dashboard"

# Get all CSV files
$csvFiles = Get-ChildItem -Path ".endpoints" -Recurse -Filter "*.csv"

Write-Host "Connecting to $($csvFiles.Count) CSV files..." -ForegroundColor Yellow

# Connect each CSV file as a data source
foreach ($csvFile in $csvFiles) {
    try {
        $tableName = ($csvFile.BaseName -replace '[^a-zA-Z0-9_]', '_')
        Write-Host "Connecting: $tableName" -ForegroundColor Green
        
        # Add data source to PowerBI
        Add-PowerBIDataSource -WorkspaceId $workspace.Id -Name $tableName -SourceType "CSV" -SourcePath $csvFile.FullName
        
    } catch {
        Write-Host "Failed to connect $($csvFile.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "
PowerBI workspace created: $($workspace.Name)" -ForegroundColor Green
Write-Host "Workspace ID: $($workspace.Id)" -ForegroundColor Green
