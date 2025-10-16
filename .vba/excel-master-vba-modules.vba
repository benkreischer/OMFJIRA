' =============================================================================
' EXCEL MASTER ANALYTICS - VBA MODULES
' =============================================================================

' This file contains VBA code for the Excel Master Analytics file
' Copy these modules into your Excel workbook for full functionality

' =============================================================================
' MODULE 1: DATA REFRESH AND MANAGEMENT
' =============================================================================

Sub RefreshAllData()
    ' Refreshes all Power Query connections and updates charts
    On Error GoTo ErrorHandler
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    ' Show progress
    Call ShowProgress("Refreshing data...", 0, 100)
    
    ' Refresh Power Query connections
    Call ShowProgress("Refreshing Power Query connections...", 20, 100)
    ThisWorkbook.RefreshAll
    
    ' Update charts
    Call ShowProgress("Updating charts...", 60, 100)
    Call UpdateCharts
    
    ' Update pivot tables
    Call ShowProgress("Updating pivot tables...", 80, 100)
    Call UpdatePivotTables
    
    ' Final calculations
    Call ShowProgress("Finalizing...", 100, 100)
    Application.Calculate
    
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    
    ' Hide progress
    Call HideProgress
    
    MsgBox "Data refresh completed successfully!", vbInformation, "Refresh Complete"
    Exit Sub
    
ErrorHandler:
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    Call HideProgress
    MsgBox "Error during data refresh: " & Err.Description, vbCritical, "Refresh Error"
End Sub

Sub UpdateCharts()
    ' Updates all charts in the workbook
    Dim ws As Worksheet
    Dim chrt As ChartObject
    
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name <> "Data Sources" And ws.Name <> "Config" Then
            For Each chrt In ws.ChartObjects
                chrt.Chart.Refresh
            Next chrt
        End If
    Next ws
End Sub

Sub UpdatePivotTables()
    ' Updates all pivot tables in the workbook
    Dim ws As Worksheet
    Dim pt As PivotTable
    
    For Each ws In ThisWorkbook.Worksheets
        If ws.Name <> "Data Sources" And ws.Name <> "Config" Then
            For Each pt In ws.PivotTables
                pt.RefreshTable
            Next pt
        End If
    Next ws
End Sub

' =============================================================================
' MODULE 2: FILTERING AND ANALYSIS
' =============================================================================

Sub ApplyDateFilter(StartDate As Date, EndDate As Date)
    ' Applies date filter to all relevant data
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    ' Clear existing filters
    If ws.AutoFilterMode Then ws.AutoFilterMode = False
    
    ' Apply date filter
    ws.Range("A:Z").AutoFilter Field:=5, Criteria1:=">=" & StartDate, Operator:=xlAnd, Criteria2:="<=" & EndDate
    
    ' Refresh dependent sheets
    Call RefreshAllData
    
    MsgBox "Date filter applied: " & Format(StartDate, "mm/dd/yyyy") & " to " & Format(EndDate, "mm/dd/yyyy"), vbInformation
End Sub

Sub ApplyProjectFilter(ProjectKey As String)
    ' Applies project filter to all relevant data
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    ' Clear existing filters
    If ws.AutoFilterMode Then ws.AutoFilterMode = False
    
    ' Apply project filter
    ws.Range("A:Z").AutoFilter Field:=9, Criteria1:=ProjectKey
    
    ' Refresh dependent sheets
    Call RefreshAllData
    
    MsgBox "Project filter applied: " & ProjectKey, vbInformation
End Sub

Sub ApplyStatusFilter(StatusName As String)
    ' Applies status filter to all relevant data
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    ' Clear existing filters
    If ws.AutoFilterMode Then ws.AutoFilterMode = False
    
    ' Apply status filter
    ws.Range("A:Z").AutoFilter Field:=2, Criteria1:=StatusName
    
    ' Refresh dependent sheets
    Call RefreshAllData
    
    MsgBox "Status filter applied: " & StatusName, vbInformation
End Sub

Sub ClearAllFilters()
    ' Clears all filters and shows all data
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    If ws.AutoFilterMode Then ws.AutoFilterMode = False
    
    Call RefreshAllData
    
    MsgBox "All filters cleared", vbInformation
End Sub

' =============================================================================
' MODULE 3: EXPORT AND REPORTING
' =============================================================================

Sub ExportDashboardToPDF()
    ' Exports the dashboard to PDF
    On Error GoTo ErrorHandler
    
    Dim fileName As String
    fileName = "Jira_Analytics_Dashboard_" & Format(Now, "yyyy-mm-dd_hh-mm") & ".pdf"
    
    ThisWorkbook.Worksheets("Dashboard").ExportAsFixedFormat _
        Type:=xlTypePDF, _
        Filename:=ThisWorkbook.Path & "\" & fileName, _
        Quality:=xlQualityStandard, _
        IncludeDocProps:=True, _
        IgnorePrintAreas:=False
    
    MsgBox "Dashboard exported to: " & fileName, vbInformation, "Export Complete"
    Exit Sub
    
ErrorHandler:
    MsgBox "Error exporting dashboard: " & Err.Description, vbCritical, "Export Error"
End Sub

Sub ExportDataToCSV()
    ' Exports data sources to CSV
    On Error GoTo ErrorHandler
    
    Dim fileName As String
    fileName = "Jira_Data_Export_" & Format(Now, "yyyy-mm-dd_hh-mm") & ".csv"
    
    ' Create a copy of the data sources sheet
    ThisWorkbook.Worksheets("Data Sources").Copy
    
    ' Save as CSV
    ActiveWorkbook.SaveAs Filename:=ThisWorkbook.Path & "\" & fileName, FileFormat:=xlCSV
    ActiveWorkbook.Close
    
    MsgBox "Data exported to: " & fileName, vbInformation, "Export Complete"
    Exit Sub
    
ErrorHandler:
    MsgBox "Error exporting data: " & Err.Description, vbCritical, "Export Error"
End Sub

Sub GenerateWeeklyReport()
    ' Generates a weekly status report
    On Error GoTo ErrorHandler
    
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Custom Reports")
    
    ' Clear existing report
    ws.Cells.Clear
    
    ' Add report header
    ws.Range("A1").Value = "Weekly Jira Analytics Report"
    ws.Range("A2").Value = "Generated: " & Format(Now, "mmmm dd, yyyy hh:mm AM/PM")
    ws.Range("A3").Value = "Week of: " & Format(Date - Weekday(Date) + 1, "mmmm dd, yyyy")
    
    ' Add key metrics
    ws.Range("A5").Value = "Key Metrics:"
    ws.Range("A6").Value = "Total Issues: " & GetTotalIssues()
    ws.Range("A7").Value = "Open Issues: " & GetOpenIssues()
    ws.Range("A8").Value = "Resolved This Week: " & GetResolvedThisWeek()
    ws.Range("A9").Value = "Average Resolution Time: " & GetAverageResolutionTime() & " days"
    
    ' Add charts
    Call AddWeeklyCharts(ws)
    
    ' Export to PDF
    Call ExportWeeklyReportToPDF(ws)
    
    MsgBox "Weekly report generated successfully!", vbInformation, "Report Complete"
    Exit Sub
    
ErrorHandler:
    MsgBox "Error generating weekly report: " & Err.Description, vbCritical, "Report Error"
End Sub

' =============================================================================
' MODULE 4: KPI CALCULATIONS
' =============================================================================

Function GetTotalIssues() As Long
    ' Returns total number of issues
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    GetTotalIssues = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row - 1
End Function

Function GetOpenIssues() As Long
    ' Returns number of open issues
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    GetOpenIssues = Application.WorksheetFunction.CountIfs(ws.Range("B:B"), "<>Done")
End Function

Function GetResolvedThisWeek() As Long
    ' Returns number of issues resolved this week
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    Dim weekStart As Date
    weekStart = Date - Weekday(Date) + 1
    
    GetResolvedThisWeek = Application.WorksheetFunction.CountIfs(ws.Range("H:H"), ">=" & weekStart, ws.Range("B:B"), "Done")
End Function

Function GetAverageResolutionTime() As Double
    ' Returns average resolution time in days
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    GetAverageResolutionTime = Application.WorksheetFunction.AverageIfs(ws.Range("M:M"), ws.Range("M:M"), ">0")
End Function

Function GetIssuesByProject(ProjectKey As String) As Long
    ' Returns number of issues for a specific project
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    GetIssuesByProject = Application.WorksheetFunction.CountIf(ws.Range("I:I"), ProjectKey)
End Function

Function GetIssuesByAssignee(AssigneeName As String) As Long
    ' Returns number of issues assigned to a specific person
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    GetIssuesByAssignee = Application.WorksheetFunction.CountIf(ws.Range("C:C"), AssigneeName)
End Function

' =============================================================================
' MODULE 5: CHART CREATION AND MANAGEMENT
' =============================================================================

Sub AddWeeklyCharts(ws As Worksheet)
    ' Adds charts to the weekly report
    Dim chartRange As Range
    Dim chartObj As ChartObject
    
    ' Issues by Status Chart
    Set chartRange = ws.Range("A12:B20")
    Set chartObj = ws.ChartObjects.Add(Left:=chartRange.Left, Top:=chartRange.Top, Width:=400, Height:=300)
    
    With chartObj.Chart
        .ChartType = xlPie
        .SetSourceData ws.Range("A12:B20")
        .HasTitle = True
        .ChartTitle.Text = "Issues by Status"
    End With
    
    ' Issues by Project Chart
    Set chartRange = ws.Range("D12:E20")
    Set chartObj = ws.ChartObjects.Add(Left:=chartRange.Left, Top:=chartRange.Top, Width:=400, Height:=300)
    
    With chartObj.Chart
        .ChartType = xlColumnClustered
        .SetSourceData ws.Range("D12:E20")
        .HasTitle = True
        .ChartTitle.Text = "Issues by Project"
    End With
End Sub

Sub CreateDynamicChart(ws As Worksheet, chartType As XlChartType, dataRange As Range, chartTitle As String)
    ' Creates a dynamic chart with specified parameters
    Dim chartObj As ChartObject
    
    Set chartObj = ws.ChartObjects.Add(Left:=dataRange.Left, Top:=dataRange.Top, Width:=400, Height:=300)
    
    With chartObj.Chart
        .ChartType = chartType
        .SetSourceData dataRange
        .HasTitle = True
        .ChartTitle.Text = chartTitle
        .HasLegend = True
    End With
End Sub

' =============================================================================
' MODULE 6: PROGRESS AND STATUS INDICATORS
' =============================================================================

Sub ShowProgress(message As String, current As Long, total As Long)
    ' Shows progress bar during long operations
    Dim progress As Double
    progress = (current / total) * 100
    
    ' Create or update progress bar
    If Not ProgressBarExists() Then
        Call CreateProgressBar
    End If
    
    ' Update progress
    ThisWorkbook.Worksheets("Config").Range("ProgressMessage").Value = message
    ThisWorkbook.Worksheets("Config").Range("ProgressValue").Value = progress
    ThisWorkbook.Worksheets("Config").Range("ProgressBar").Value = progress
    
    Application.ScreenUpdating = True
    DoEvents
End Sub

Sub HideProgress()
    ' Hides the progress bar
    ThisWorkbook.Worksheets("Config").Range("ProgressMessage").Value = ""
    ThisWorkbook.Worksheets("Config").Range("ProgressValue").Value = 0
    ThisWorkbook.Worksheets("Config").Range("ProgressBar").Value = 0
End Sub

Function ProgressBarExists() As Boolean
    ' Checks if progress bar exists
    On Error Resume Next
    ProgressBarExists = (ThisWorkbook.Worksheets("Config").Range("ProgressBar").Address <> "")
    On Error GoTo 0
End Function

Sub CreateProgressBar()
    ' Creates a progress bar in the Config sheet
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Config")
    
    ' Add progress bar elements
    ws.Range("A1").Value = "Progress:"
    ws.Range("A2").Value = "Message:"
    ws.Range("B2").Name = "ProgressMessage"
    ws.Range("A3").Value = "Progress:"
    ws.Range("B3").Name = "ProgressValue"
    ws.Range("A4").Value = "Bar:"
    ws.Range("B4").Name = "ProgressBar"
    
    ' Format progress bar
    ws.Range("B4").NumberFormat = "0%"
End Sub

' =============================================================================
' MODULE 7: UTILITY FUNCTIONS
' =============================================================================

Sub ExportWeeklyReportToPDF(ws As Worksheet)
    ' Exports weekly report to PDF
    Dim fileName As String
    fileName = "Weekly_Report_" & Format(Now, "yyyy-mm-dd") & ".pdf"
    
    ws.ExportAsFixedFormat _
        Type:=xlTypePDF, _
        Filename:=ThisWorkbook.Path & "\" & fileName, _
        Quality:=xlQualityStandard, _
        IncludeDocProps:=True, _
        IgnorePrintAreas:=False
End Sub

Sub SendReportViaEmail()
    ' Sends report via email (requires Outlook)
    On Error GoTo ErrorHandler
    
    Dim outlookApp As Object
    Dim outlookMail As Object
    
    Set outlookApp = CreateObject("Outlook.Application")
    Set outlookMail = outlookApp.CreateItem(0)
    
    With outlookMail
        .To = "team@company.com"  ' Update with your team email
        .Subject = "Weekly Jira Analytics Report - " & Format(Now, "mmmm dd, yyyy")
        .Body = "Please find attached the weekly Jira analytics report."
        .Attachments.Add ThisWorkbook.Path & "\Weekly_Report_" & Format(Now, "yyyy-mm-dd") & ".pdf"
        .Send
    End With
    
    MsgBox "Report sent via email successfully!", vbInformation, "Email Sent"
    Exit Sub
    
ErrorHandler:
    MsgBox "Error sending email: " & Err.Description, vbCritical, "Email Error"
End Sub

Sub BackupWorkbook()
    ' Creates a backup of the workbook
    Dim fileName As String
    fileName = "Jira_Analytics_Backup_" & Format(Now, "yyyy-mm-dd_hh-mm") & ".xlsx"
    
    ThisWorkbook.SaveCopyAs ThisWorkbook.Path & "\" & fileName
    
    MsgBox "Backup created: " & fileName, vbInformation, "Backup Complete"
End Sub

' =============================================================================
' MODULE 8: AUTOMATION AND SCHEDULING
' =============================================================================

Sub AutoRefreshOnOpen()
    ' Automatically refreshes data when workbook opens
    Call RefreshAllData
End Sub

Sub ScheduleRefresh()
    ' Schedules automatic refresh (requires Windows Task Scheduler)
    MsgBox "To schedule automatic refresh, use Windows Task Scheduler to run this workbook every hour.", vbInformation, "Scheduling Info"
End Sub

Sub CheckDataQuality()
    ' Checks data quality and reports issues
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Data Sources")
    
    Dim issues As String
    issues = ""
    
    ' Check for missing data
    If GetTotalIssues() = 0 Then
        issues = issues & "• No issues found in data source" & vbCrLf
    End If
    
    ' Check for date issues
    If Application.WorksheetFunction.CountBlank(ws.Range("E:E")) > 0 Then
        issues = issues & "• Missing created dates found" & vbCrLf
    End If
    
    ' Report issues
    If issues <> "" Then
        MsgBox "Data Quality Issues Found:" & vbCrLf & vbCrLf & issues, vbExclamation, "Data Quality Check"
    Else
        MsgBox "Data quality check passed - no issues found!", vbInformation, "Data Quality Check"
    End If
End Sub
