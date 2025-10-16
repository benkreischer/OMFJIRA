# PowerShell script to create Excel file with live endpoint connections
# Each endpoint will be on its own tab with embedded Power Query data source

Write-Host "=== CREATING EXCEL FILE WITH LIVE ENDPOINT CONNECTIONS ===" -ForegroundColor Green

# Load Excel COM object
try {
    $Excel = New-Object -ComObject Excel.Application
    $Excel.Visible = $false
    $Excel.DisplayAlerts = $false
    
    # Create new workbook
    $Workbook = $Excel.Workbooks.Add()
    
    Write-Host "Excel application loaded successfully" -ForegroundColor Yellow
    
    # Define the working endpoints with their Power Query files
    $Endpoints = @(
        @{
            Name = "Projects"
            PqFile = ".endpoints\Projects\Projects - GET Project (Anon).pq"
            TabName = "Project Details"
        },
        @{
            Name = "Projects Paginated"
            PqFile = ".endpoints\Projects\Projects - GET Projects Paginated (Anon).pq"
            TabName = "All Projects"
        },
        @{
            Name = "Issues"
            PqFile = ".endpoints\Issues\Issues - GET Issue (Anon).pq"
            TabName = "Issue Details"
        },
        @{
            Name = "Filters"
            PqFile = ".endpoints\Filters\Filters - GET Filters (Anon).pq"
            TabName = "Filters"
        },
        @{
            Name = "Issue Fields"
            PqFile = ".endpoints\Issue Fields\Issue Fields - GET All Fields (Anon).pq"
            TabName = "Issue Fields"
        },
        @{
            Name = "Issue Types"
            PqFile = ".endpoints\Issue Types\Issue Types - GET All issue types (Anon).pq"
            TabName = "Issue Types"
        },
        @{
            Name = "Dashboards"
            PqFile = ".endpoints\Dashboards\Dashboards - GET Search for dashboards (Anon).pq"
            TabName = "Dashboards"
        },
        @{
            Name = "Custom Field Contexts"
            PqFile = ".endpoints\Custom Field Contexts\Custom Field Contexts - GET Contexts for a field (Anon).pq"
            TabName = "Custom Field Contexts"
        },
        @{
            Name = "Workflows"
            PqFile = ".endpoints\Workflows\Workflows - GET Workflow Schemes (Anon).pq"
            TabName = "Workflows"
        },
        @{
            Name = "Users"
            PqFile = ".endpoints\Users\Users - GET Users (Anon).pq"
            TabName = "Users"
        },
        @{
            Name = "Permissions"
            PqFile = ".endpoints\Permissions\Permissions - GET All permissions (Anon).pq"
            TabName = "Permissions"
        },
        @{
            Name = "Groups"
            PqFile = ".endpoints\Groups\Groups - GET Group members (Anon).pq"
            TabName = "Groups"
        },
        @{
            Name = "Status"
            PqFile = ".endpoints\Status\Status - GET Statuses (Anon).pq"
            TabName = "Statuses"
        },
        @{
            Name = "Issue Priorities"
            PqFile = ".endpoints\Issue Priorities\Issue Priorities - GET Priorities (Anon).pq"
            TabName = "Issue Priorities"
        },
        @{
            Name = "Issue Resolutions"
            PqFile = ".endpoints\Issue Resolutions\Issue Resolutions - GET Resolutions (Anon).pq"
            TabName = "Issue Resolutions"
        },
        @{
            Name = "Issue Link Types"
            PqFile = ".endpoints\Issue Link Types\Issue Link Types - GET Issue link types (Anon).pq"
            TabName = "Issue Link Types"
        },
        @{
            Name = "Project Versions"
            PqFile = ".endpoints\Project Versions\Project Versions - GET Versions (Anon).pq"
            TabName = "Project Versions"
        },
        @{
            Name = "Project Components"
            PqFile = ".endpoints\Project Components\Project Components - GET Components (Anon).pq"
            TabName = "Project Components"
        },
        @{
            Name = "Issue Search"
            PqFile = ".endpoints\Issue Search\Issue Search - GET Issue search (Anon).pq"
            TabName = "Issue Search"
        },
        @{
            Name = "Comments"
            PqFile = ".endpoints\Comments\Comments - GET Comments (Anon).pq"
            TabName = "Comments"
        },
        @{
            Name = "Issue Worklogs"
            PqFile = ".endpoints\Issue Worklogs\Issue Worklogs - GET Worklogs (Anon).pq"
            TabName = "Issue Worklogs"
        },
        @{
            Name = "Attachments"
            PqFile = ".endpoints\Attachments\Attachments - GET Attachment Metadata (Anon).pq"
            TabName = "Attachments"
        },
        @{
            Name = "Issue Links"
            PqFile = ".endpoints\Issue Links\Issue Links - GET Issue link (Anon).pq"
            TabName = "Issue Links"
        },
        @{
            Name = "Issue Watchers"
            PqFile = ".endpoints\Issue Watchers\Issue Watchers - GET Watchers (Anon).pq"
            TabName = "Issue Watchers"
        },
        @{
            Name = "Issue Properties"
            PqFile = ".endpoints\Issue Properties\Issue Properties - GET Issue property keys (Anon).pq"
            TabName = "Issue Properties"
        },
        @{
            Name = "Jira Settings"
            PqFile = ".endpoints\Jira Settings\Jira Settings - GET Application properties (Anon).pq"
            TabName = "Jira Settings"
        },
        @{
            Name = "Server Info"
            PqFile = ".endpoints\Server Info\Server Info - GET Server Info (Anon).pq"
            TabName = "Server Info"
        },
        @{
            Name = "Time Tracking"
            PqFile = ".endpoints\Time Tracking\Time Tracking - GET Time Tracking Configuration (Anon).pq"
            TabName = "Time Tracking"
        },
        @{
            Name = "Project Categories"
            PqFile = ".endpoints\Project Categories\Project Categories - GET Project Categories (Anon).pq"
            TabName = "Project Categories"
        },
        @{
            Name = "Project Types"
            PqFile = ".endpoints\Project Types\Project Types - GET Project Types (Anon).pq"
            TabName = "Project Types"
        },
        @{
            Name = "Issue Type Schemes"
            PqFile = ".endpoints\Issue Type Schemes\Issue Type Schemes - GET All issue type schemes (Anon).pq"
            TabName = "Issue Type Schemes"
        },
        @{
            Name = "Priority Schemes"
            PqFile = ".endpoints\Priority Schemes\Priority Schemes - GET Priority Schemes (Anon).pq"
            TabName = "Priority Schemes"
        },
        @{
            Name = "Screen Schemes"
            PqFile = ".endpoints\Screen Schemes\Screen Schemes - GET Screen Schemes (Anon).pq"
            TabName = "Screen Schemes"
        },
        @{
            Name = "Issue Type Screen Schemes"
            PqFile = ".endpoints\Issue Type Screen Schemes\Issue Type Screen Schemes - GET Issue type screen schemes (Anon).pq"
            TabName = "Issue Type Screen Schemes"
        },
        @{
            Name = "Screens"
            PqFile = ".endpoints\Screens\Screens - GET Screens (Anon).pq"
            TabName = "Screens"
        },
        @{
            Name = "Project Permission Schemes"
            PqFile = ".endpoints\Project Permission Schemes\Project Permission Schemes - GET Project Permission Schemes (Anon).pq"
            TabName = "Project Permission Schemes"
        },
        @{
            Name = "Project Properties"
            PqFile = ".endpoints\Project Properties\Project Properties - GET Project Properties (Anon).pq"
            TabName = "Project Properties"
        },
        @{
            Name = "Project Features"
            PqFile = ".endpoints\Project Features\Project Features - GET Project Features (Anon).pq"
            TabName = "Project Features"
        },
        @{
            Name = "Project Avatars"
            PqFile = ".endpoints\Project Avatars\Project Avatars - GET Project Avatars (Anon).pq"
            TabName = "Project Avatars"
        },
        @{
            Name = "Avatars"
            PqFile = ".endpoints\Avatars\Avatars - GET System Avatars by Type (Anon).pq"
            TabName = "Avatars"
        },
        @{
            Name = "Configuration"
            PqFile = ".endpoints\Configuration\Configuration - GET Configuration (Anon).pq"
            TabName = "Configuration"
        },
        @{
            Name = "Custom Field Options"
            PqFile = ".endpoints\Custom Field Options\Custom Field Options - GET Custom field option (Anon).pq"
            TabName = "Custom Field Options"
        },
        @{
            Name = "Custom Fields"
            PqFile = ".endpoints\Custom Fields\Custom Fields - GET Fields (Anon).pq"
            TabName = "Custom Fields"
        },
        @{
            Name = "Filter Sharing"
            PqFile = ".endpoints\Filter Sharing\Filter Sharing - GET Default share scope (Anon).pq"
            TabName = "Filter Sharing"
        },
        @{
            Name = "Issue Attachments"
            PqFile = ".endpoints\Issue Attachments\Issue Attachments - GET Attachment meta (Anon).pq"
            TabName = "Issue Attachments"
        }
    )
    
    Write-Host "Processing $($Endpoints.Count) endpoints..." -ForegroundColor Yellow
    
    # Rename default sheet to Summary first
    $Workbook.Sheets.Item(1).Name = "Summary"
    
    $ProcessedCount = 0
    
    foreach ($Endpoint in $Endpoints) {
        try {
            Write-Host "Processing: $($Endpoint.Name)" -ForegroundColor Cyan
            
            # Check if Power Query file exists
            if (Test-Path $Endpoint.PqFile) {
                # Create new worksheet
                $Worksheet = $Workbook.Worksheets.Add()
                $Worksheet.Name = $Endpoint.TabName
                
                # Read Power Query file content
                $PqContent = Get-Content $Endpoint.PqFile -Raw
                
                # Create a simple table structure for now
                # In a real implementation, you would need to execute the Power Query
                $Worksheet.Cells.Item(1, 1) = "Data Source: $($Endpoint.Name)"
                $Worksheet.Cells.Item(2, 1) = "Power Query File: $($Endpoint.PqFile)"
                $Worksheet.Cells.Item(3, 1) = "Status: Ready for Power Query Import"
                $Worksheet.Cells.Item(4, 1) = "Instructions:"
                $Worksheet.Cells.Item(5, 1) = "1. Go to Data tab in Excel"
                $Worksheet.Cells.Item(6, 1) = "2. Click 'Get Data' > 'From Other Sources' > 'Blank Query'"
                $Worksheet.Cells.Item(7, 1) = "3. Copy the Power Query code from: $($Endpoint.PqFile)"
                $Worksheet.Cells.Item(8, 1) = "4. Paste into Advanced Editor and click Done"
                $Worksheet.Cells.Item(9, 1) = "5. Click 'Close & Load' to create live connection"
                
                # Add Power Query content as comments
                $PqLines = $PqContent -split "`n"
                $Row = 11
                foreach ($Line in $PqLines) {
                    if ($Row -lt 100) { # Limit to avoid too many rows
                        $Worksheet.Cells.Item($Row, 1) = "// $Line"
                        $Row++
                    }
                }
                
                # Format the header
                $HeaderRange = $Worksheet.Range("A1:A9")
                $HeaderRange.Font.Bold = $true
                $HeaderRange.Interior.Color = 0xCCCCCC
                
                $ProcessedCount++
            } else {
                Write-Host "  Warning: Power Query file not found: $($Endpoint.PqFile)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "  Error processing $($Endpoint.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Use existing summary sheet
    $SummarySheet = $Workbook.Sheets.Item("Summary")
    
    $SummarySheet.Cells.Item(1, 1) = "Jira API Endpoints - Live Data Connections"
    $SummarySheet.Cells.Item(2, 1) = "Generated: $(Get-Date)"
    $SummarySheet.Cells.Item(3, 1) = "Total Endpoints: $($Endpoints.Count)"
    $SummarySheet.Cells.Item(4, 1) = "Processed: $ProcessedCount"
    $SummarySheet.Cells.Item(6, 1) = "Instructions:"
    $SummarySheet.Cells.Item(7, 1) = "1. Each tab represents a different Jira API endpoint"
    $SummarySheet.Cells.Item(8, 1) = "2. To create live connections, follow the instructions on each tab"
    $SummarySheet.Cells.Item(9, 1) = "3. Power Query files are located in .endpoints folder"
    $SummarySheet.Cells.Item(10, 1) = "4. After setting up connections, you can refresh data anytime"
    $SummarySheet.Cells.Item(11, 1) = "5. Use 'Data' > 'Refresh All' to update all connections"
    
    # Add endpoint list
    $Row = 13
    $SummarySheet.Cells.Item($Row, 1) = "Endpoint List:"
    $Row++
    
    foreach ($Endpoint in $Endpoints) {
        $SummarySheet.Cells.Item($Row, 1) = $Endpoint.TabName
        $SummarySheet.Cells.Item($Row, 2) = $Endpoint.PqFile
        $Row++
    }
    
    # Format summary sheet
    $SummaryRange = $SummarySheet.Range("A1:A11")
    $SummaryRange.Font.Bold = $true
    $SummaryRange.Interior.Color = 0xCCCCCC
    
    # Save workbook
    $OutputPath = "Jira_API_Endpoints_Live_Connections.xlsx"
    $Workbook.SaveAs((Resolve-Path ".").Path + "\" + $OutputPath)
    
    Write-Host "Excel file created successfully: $OutputPath" -ForegroundColor Green
    Write-Host "Processed $ProcessedCount out of $($Endpoints.Count) endpoints" -ForegroundColor Green
    
    # Close Excel
    $Workbook.Close()
    $Excel.Quit()
    
    Write-Host "Excel application closed" -ForegroundColor Yellow
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($Excel) {
        $Excel.Quit()
    }
}

Write-Host "=== EXCEL FILE CREATION COMPLETED ===" -ForegroundColor Green
