' =============================================================================
' EXCEL VBA CODE FOR DYNAMIC JIRA INTEGRATION
' =============================================================================

' This VBA code creates named ranges, sets up dynamic parameters, and refreshes Power Query

Option Explicit

' =============================================================================
' SETUP FUNCTIONS
' =============================================================================

Sub SetupJiraParameters()
    ' Creates named ranges for Jira parameters
    ' Run this once to set up the dynamic parameters
    
    Dim ws As Worksheet
    Set ws = ActiveSheet
    
    ' Clear existing named ranges if they exist
    On Error Resume Next
    ActiveWorkbook.Names("JiraBaseUrl").Delete
    ActiveWorkbook.Names("JiraUsername").Delete
    ActiveWorkbook.Names("JiraApiToken").Delete
    ActiveWorkbook.Names("JiraProjectKey").Delete
    ActiveWorkbook.Names("JiraStatus").Delete
    ActiveWorkbook.Names("JiraJQL").Delete
    On Error GoTo 0
    
    ' Create parameter input area (top of sheet)
    ws.Cells(1, 1).Value = "Jira Parameters"
    ws.Cells(1, 1).Font.Bold = True
    ws.Cells(1, 1).Font.Size = 14
    
    ' Set up parameter labels and input cells
    ws.Cells(2, 1).Value = "Base URL:"
    ws.Cells(3, 1).Value = "Username:"
    ws.Cells(4, 1).Value = "API Token:"
    ws.Cells(5, 1).Value = "Project Key:"
    ws.Cells(6, 1).Value = "Status:"
    ws.Cells(7, 1).Value = "Custom JQL:"
    
    ' Set default values
    ws.Cells(2, 2).Value = "https://onemain.atlassian.net/rest/api/3"
    ws.Cells(3, 2).Value = "ben.kreischer.ce@omf.com"
    ws.Cells(4, 2).Value = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"
    ws.Cells(5, 2).Value = ""  ' Leave empty for all projects
    ws.Cells(6, 2).Value = ""  ' Leave empty for all statuses
    ws.Cells(7, 2).Value = ""  ' Leave empty to use auto-generated JQL
    
    ' Create named ranges
    ActiveWorkbook.Names.Add Name:="JiraBaseUrl", RefersTo:="=" & ws.Name & "!$B$2"
    ActiveWorkbook.Names.Add Name:="JiraUsername", RefersTo:="=" & ws.Name & "!$B$3"
    ActiveWorkbook.Names.Add Name:="JiraApiToken", RefersTo:="=" & ws.Name & "!$B$4"
    ActiveWorkbook.Names.Add Name:="JiraProjectKey", RefersTo:="=" & ws.Name & "!$B$5"
    ActiveWorkbook.Names.Add Name:="JiraStatus", RefersTo:="=" & ws.Name & "!$B$6"
    ActiveWorkbook.Names.Add Name:="JiraJQL", RefersTo:="=" & ws.Name & "!$B$7"
    
    ' Format the parameter area
    ws.Range("A1:B7").Borders.LineStyle = xlContinuous
    ws.Range("A1:B1").Interior.Color = RGB(200, 200, 200)
    ws.Columns("A:B").AutoFit
    
    ' Add refresh button
    Dim btn As Button
    Set btn = ws.Buttons.Add(ws.Cells(8, 1).Left, ws.Cells(8, 1).Top, 100, 25)
    btn.Caption = "Refresh Jira Data"
    btn.OnAction = "RefreshJiraData"
    
    MsgBox "Jira parameters set up successfully!" & vbCrLf & vbCrLf & _
           "Now create a Power Query using the dynamic-jira-queries.pq template." & vbCrLf & _
           "The query will automatically read from these parameter cells."
End Sub

' =============================================================================
' REFRESH FUNCTIONS
' =============================================================================

Sub RefreshJiraData()
    ' Refreshes all Jira-related Power Query connections
    ' This is called when the refresh button is clicked
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    On Error GoTo ErrorHandler
    
    ' Refresh all Power Query connections
    ActiveWorkbook.RefreshAll
    
    ' Wait for refresh to complete
    Do While Application.CalculationState <> xlDone
        DoEvents
    Loop
    
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    
    MsgBox "Jira data refreshed successfully!"
    Exit Sub
    
ErrorHandler:
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    MsgBox "Error refreshing data: " & Err.Description
End Sub

Sub RefreshJiraDataSilent()
    ' Silent refresh without user prompts
    ' Use this for automated refreshes
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    On Error GoTo ErrorHandler
    
    ActiveWorkbook.RefreshAll
    
    Do While Application.CalculationState <> xlDone
        DoEvents
    Loop
    
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    Exit Sub
    
ErrorHandler:
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    ' Silent error handling
End Sub

' =============================================================================
' PARAMETER MANAGEMENT FUNCTIONS
' =============================================================================

Sub SetJiraProject(projectKey As String)
    ' Sets the project key parameter
    ActiveWorkbook.Names("JiraProjectKey").RefersTo = "=" & ActiveSheet.Name & "!$B$5"
    ActiveSheet.Cells(5, 2).Value = projectKey
End Sub

Sub SetJiraStatus(statusName As String)
    ' Sets the status parameter
    ActiveWorkbook.Names("JiraStatus").RefersTo = "=" & ActiveSheet.Name & "!$B$6"
    ActiveSheet.Cells(6, 2).Value = statusName
End Sub

Sub SetJiraJQL(jqlQuery As String)
    ' Sets a custom JQL query
    ActiveWorkbook.Names("JiraJQL").RefersTo = "=" & ActiveSheet.Name & "!$B$7"
    ActiveSheet.Cells(7, 2).Value = jqlQuery
End Sub

Sub ClearJiraFilters()
    ' Clears all filter parameters
    ActiveSheet.Cells(5, 2).Value = ""  ' Project
    ActiveSheet.Cells(6, 2).Value = ""  ' Status
    ActiveSheet.Cells(7, 2).Value = ""  ' JQL
End Sub

' =============================================================================
' QUICK FILTER FUNCTIONS
' =============================================================================

Sub ShowOpenIssues()
    ' Quick filter for open issues
    Call SetJiraStatus("Open")
    Call RefreshJiraDataSilent
End Sub

Sub ShowInProgressIssues()
    ' Quick filter for in-progress issues
    Call SetJiraStatus("In Progress")
    Call RefreshJiraDataSilent
End Sub

Sub ShowOverdueIssues()
    ' Quick filter for overdue issues
    Call SetJiraJQL("duedate < now() AND duedate is not EMPTY ORDER BY duedate ASC")
    Call RefreshJiraDataSilent
End Sub

Sub ShowRecentIssues()
    ' Quick filter for recent issues (last 7 days)
    Call SetJiraJQL("created >= -7d ORDER BY created DESC")
    Call RefreshJiraDataSilent
End Sub

Sub ShowMyIssues()
    ' Quick filter for issues assigned to current user
    Call SetJiraJQL("assignee = currentUser() ORDER BY updated DESC")
    Call RefreshJiraDataSilent
End Sub

' =============================================================================
' AUTOMATION FUNCTIONS
' =============================================================================

Sub AutoRefreshJiraData()
    ' Sets up automatic refresh every 5 minutes
    ' Call this once to enable auto-refresh
    
    Application.OnTime Now + TimeValue("00:05:00"), "AutoRefreshJiraData"
    Call RefreshJiraDataSilent
End Sub

Sub StopAutoRefresh()
    ' Stops automatic refresh
    On Error Resume Next
    Application.OnTime Now + TimeValue("00:05:00"), "AutoRefreshJiraData", , False
    On Error GoTo 0
End Sub

' =============================================================================
' UTILITY FUNCTIONS
' =============================================================================

Sub CreateJiraDashboard()
    ' Creates a simple dashboard with multiple Jira queries
    ' This creates separate sheets for different views
    
    Dim ws As Worksheet
    Dim i As Integer
    
    ' Create dashboard sheets
    Dim sheetNames As Variant
    sheetNames = Array("All Issues", "Open Issues", "In Progress", "Overdue", "Recent")
    
    For i = 0 To UBound(sheetNames)
        Set ws = Worksheets.Add
        ws.Name = sheetNames(i)
        
        ' Add parameter references to each sheet
        ActiveWorkbook.Names.Add Name:="JiraBaseUrl_" & i, RefersTo:="=Parameters!$B$2"
        ActiveWorkbook.Names.Add Name:="JiraUsername_" & i, RefersTo:="=Parameters!$B$3"
        ActiveWorkbook.Names.Add Name:="JiraApiToken_" & i, RefersTo:="=Parameters!$B$4"
        ActiveWorkbook.Names.Add Name:="JiraProjectKey_" & i, RefersTo:="=Parameters!$B$5"
        ActiveWorkbook.Names.Add Name:="JiraStatus_" & i, RefersTo:="=Parameters!$B$6"
        ActiveWorkbook.Names.Add Name:="JiraJQL_" & i, RefersTo:="=Parameters!$B$7"
    Next i
    
    MsgBox "Dashboard created with " & (UBound(sheetNames) + 1) & " sheets!"
End Sub

Sub ExportJiraData()
    ' Exports current Jira data to CSV
    Dim ws As Worksheet
    Set ws = ActiveSheet
    
    Dim fileName As String
    fileName = "Jira_Export_" & Format(Now, "yyyy-mm-dd_hh-mm-ss") & ".csv"
    
    ' Find the data range (assuming it starts at row 10)
    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    
    If lastRow > 10 Then
        ws.Range("A10:Z" & lastRow).Copy
        Workbooks.Add
        ActiveSheet.Paste
        ActiveWorkbook.SaveAs fileName, xlCSV
        ActiveWorkbook.Close
        MsgBox "Data exported to: " & fileName
    Else
        MsgBox "No data found to export."
    End If
End Sub
