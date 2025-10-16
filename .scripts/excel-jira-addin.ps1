# Excel Jira Integration PowerShell Script
# This script can be called from Excel VBA or used as a standalone tool

param(
    [Parameter(Mandatory=$true)]
    [string]$Action,
    
    [Parameter(Mandatory=$false)]
    [string]$IssueKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "jira_data.csv"
)

# Import the Jira API script
. ".\jira-quick-embedded.ps1"

function Export-JiraDataToCSV {
    param(
        [string]$Endpoint,
        [string]$OutputPath
    )
    
    try {
        # Get data from Jira
        $data = & ".\jira-quick-embedded.ps1" $Endpoint
        
        # Convert JSON to PowerShell objects
        $jsonData = $data | ConvertFrom-Json
        
        # Convert to CSV format
        if ($jsonData -is [array]) {
            $jsonData | Export-Csv -Path $OutputPath -NoTypeInformation
        } else {
            $jsonData | Export-Csv -Path $OutputPath -NoTypeInformation
        }
        
        Write-Host "Data exported to: $OutputPath" -ForegroundColor Green
        return $OutputPath
        
    } catch {
        Write-Error "Failed to export data: $($_.Exception.Message)"
        return $null
    }
}

function Get-JiraDataForExcel {
    param(
        [string]$Endpoint,
        [string]$OutputPath
    )
    
    try {
        # Get data from Jira
        $data = & ".\jira-quick-embedded.ps1" $Endpoint
        
        # Convert JSON to PowerShell objects
        $jsonData = $data | ConvertFrom-Json
        
        # Create Excel-friendly format
        $excelData = @()
        
        if ($jsonData -is [array]) {
            foreach ($item in $jsonData) {
                $excelData += [PSCustomObject]$item
            }
        } else {
            $excelData += [PSCustomObject]$jsonData
        }
        
        # Export to CSV
        $excelData | Export-Csv -Path $OutputPath -NoTypeInformation
        
        Write-Host "Excel-ready data exported to: $OutputPath" -ForegroundColor Green
        return $OutputPath
        
    } catch {
        Write-Error "Failed to prepare data for Excel: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
switch ($Action.ToLower()) {
    "workflows" {
        $result = Get-JiraDataForExcel -Endpoint "workflow" -OutputPath $OutputFile
        if ($result) {
            Write-Host "Workflows exported successfully!" -ForegroundColor Green
        }
    }
    
    "projects" {
        $result = Get-JiraDataForExcel -Endpoint "project" -OutputPath $OutputFile
        if ($result) {
            Write-Host "Projects exported successfully!" -ForegroundColor Green
        }
    }
    
    "issue" {
        if ($IssueKey) {
            $result = Get-JiraDataForExcel -Endpoint "issue/$IssueKey" -OutputPath $OutputFile
            if ($result) {
                Write-Host "Issue $IssueKey exported successfully!" -ForegroundColor Green
            }
        } else {
            Write-Error "IssueKey parameter is required for 'issue' action"
        }
    }
    
    "myself" {
        $result = Get-JiraDataForExcel -Endpoint "myself" -OutputPath $OutputFile
        if ($result) {
            Write-Host "User info exported successfully!" -ForegroundColor Green
        }
    }
    
    default {
        Write-Error "Invalid action. Use: workflows, projects, issue, or myself"
    }
}
