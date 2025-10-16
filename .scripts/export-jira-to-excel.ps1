# Simple script to export Jira data to CSV for Excel
# Usage: .\export-jira-to-excel.ps1 -DataType "workflows" -OutputFile "workflows.csv"

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("workflows", "projects", "myself")]
    [string]$DataType,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "jira_data.csv"
)

# Import the Jira API script
. ".\jira-quick-embedded.ps1"

try {
    Write-Host "Exporting $DataType to Excel format..." -ForegroundColor Yellow
    
    # Get data from Jira
    $jsonData = & ".\jira-quick-embedded.ps1" $DataType
    
    # Convert JSON to PowerShell objects
    $data = $jsonData | ConvertFrom-Json
    
    # Prepare data for Excel
    $excelData = @()
    
    if ($data -is [array]) {
        foreach ($item in $data) {
            $excelData += [PSCustomObject]$item
        }
    } else {
        $excelData += [PSCustomObject]$data
    }
    
    # Export to CSV
    $excelData | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host "✅ Data exported successfully to: $OutputFile" -ForegroundColor Green
    Write-Host "📊 You can now open this file in Excel!" -ForegroundColor Cyan
    
    # Optionally open in Excel
    $openInExcel = Read-Host "Open in Excel now? (y/N)"
    if ($openInExcel -eq 'y' -or $openInExcel -eq 'Y') {
        Start-Process excel.exe $OutputFile
    }
    
} catch {
    Write-Error "❌ Failed to export data: $($_.Exception.Message)"
}
