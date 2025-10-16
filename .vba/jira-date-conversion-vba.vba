' =============================================================================
' JIRA DATE CONVERSION VBA FUNCTIONS
' =============================================================================

' VBA functions to help with date conversion and validation in Excel

' =============================================================================
' DATE CONVERSION FUNCTIONS
' =============================================================================

Function ConvertJiraDate(jiraDateString As String) As Date
    ' Converts Jira date string to Excel date
    ' Input: "2024-01-15T10:30:00.000+0000"
    ' Output: Excel date/time
    
    On Error GoTo ErrorHandler
    
    If jiraDateString = "" Or jiraDateString = "null" Then
        ConvertJiraDate = 0
        Exit Function
    End If
    
    ' Remove timezone info and milliseconds for simpler parsing
    Dim cleanDate As String
    cleanDate = Left(jiraDateString, 19) ' Get "2024-01-15T10:30:00"
    
    ' Convert to Excel date/time
    ConvertJiraDate = CDate(cleanDate)
    Exit Function
    
ErrorHandler:
    ConvertJiraDate = 0
End Function

Function ConvertJiraDateToLocal(jiraDateString As String) As Date
    ' Converts Jira date string to local time
    ' Handles timezone conversion
    
    On Error GoTo ErrorHandler
    
    If jiraDateString = "" Or jiraDateString = "null" Then
        ConvertJiraDateToLocal = 0
        Exit Function
    End If
    
    ' Parse the date string
    Dim datePart As String
    Dim timePart As String
    Dim timezonePart As String
    
    ' Extract date part (before T)
    datePart = Left(jiraDateString, InStr(jiraDateString, "T") - 1)
    
    ' Extract time part (between T and .)
    timePart = Mid(jiraDateString, InStr(jiraDateString, "T") + 1, InStr(jiraDateString, ".") - InStr(jiraDateString, "T") - 1)
    
    ' Extract timezone part (after + or -)
    If InStr(jiraDateString, "+") > 0 Then
        timezonePart = Mid(jiraDateString, InStr(jiraDateString, "+"))
    ElseIf InStr(jiraDateString, "-") > InStr(jiraDateString, "T") Then
        timezonePart = Mid(jiraDateString, InStr(jiraDateString, "-", InStr(jiraDateString, "T")))
    End If
    
    ' Convert to Excel date/time (simplified - assumes UTC)
    ConvertJiraDateToLocal = CDate(datePart & " " & timePart)
    Exit Function
    
ErrorHandler:
    ConvertJiraDateToLocal = 0
End Function

' =============================================================================
' DATE VALIDATION FUNCTIONS
' =============================================================================

Function IsValidJiraDate(jiraDateString As String) As Boolean
    ' Validates if a string is a valid Jira date format
    
    On Error GoTo ErrorHandler
    
    If jiraDateString = "" Or jiraDateString = "null" Then
        IsValidJiraDate = False
        Exit Function
    End If
    
    ' Check if it contains T (ISO 8601 format)
    If InStr(jiraDateString, "T") = 0 Then
        IsValidJiraDate = False
        Exit Function
    End If
    
    ' Try to convert it
    Dim testDate As Date
    testDate = ConvertJiraDate(jiraDateString)
    
    IsValidJiraDate = (testDate > 0)
    Exit Function
    
ErrorHandler:
    IsValidJiraDate = False
End Function

Function GetDateFieldType(jiraDateString As String) As String
    ' Determines the type of date field based on the string
    
    If jiraDateString = "" Or jiraDateString = "null" Then
        GetDateFieldType = "Null"
        Exit Function
    End If
    
    If InStr(jiraDateString, "T") > 0 Then
        GetDateFieldType = "DateTime"
    ElseIf InStr(jiraDateString, "-") > 0 Then
        GetDateFieldType = "Date"
    Else
        GetDateFieldType = "Unknown"
    End If
End Function

' =============================================================================
' DATE CALCULATION FUNCTIONS
' =============================================================================

Function DaysSinceCreated(createdDate As String) As Long
    ' Calculates days since issue was created
    
    On Error GoTo ErrorHandler
    
    Dim created As Date
    created = ConvertJiraDate(createdDate)
    
    If created = 0 Then
        DaysSinceCreated = 0
        Exit Function
    End If
    
    DaysSinceCreated = DateDiff("d", created, Now())
    Exit Function
    
ErrorHandler:
    DaysSinceCreated = 0
End Function

Function DaysUntilDue(dueDate As String) As Long
    ' Calculates days until due date
    
    On Error GoTo ErrorHandler
    
    Dim due As Date
    due = ConvertJiraDate(dueDate)
    
    If due = 0 Then
        DaysUntilDue = 0
        Exit Function
    End If
    
    DaysUntilDue = DateDiff("d", Now(), due)
    Exit Function
    
ErrorHandler:
    DaysUntilDue = 0
End Function

Function ResolutionTimeDays(createdDate As String, resolvedDate As String) As Long
    ' Calculates resolution time in days
    
    On Error GoTo ErrorHandler
    
    Dim created As Date
    Dim resolved As Date
    
    created = ConvertJiraDate(createdDate)
    resolved = ConvertJiraDate(resolvedDate)
    
    If created = 0 Or resolved = 0 Then
        ResolutionTimeDays = 0
        Exit Function
    End If
    
    ResolutionTimeDays = DateDiff("d", created, resolved)
    Exit Function
    
ErrorHandler:
    ResolutionTimeDays = 0
End Function

' =============================================================================
' DATE FORMATTING FUNCTIONS
' =============================================================================

Function FormatJiraDate(jiraDateString As String, formatType As String) As String
    ' Formats Jira date string for display
    
    On Error GoTo ErrorHandler
    
    Dim dateValue As Date
    dateValue = ConvertJiraDate(jiraDateString)
    
    If dateValue = 0 Then
        FormatJiraDate = "No Date"
        Exit Function
    End If
    
    Select Case formatType
        Case "Short"
            FormatJiraDate = Format(dateValue, "mm/dd/yyyy")
        Case "Long"
            FormatJiraDate = Format(dateValue, "mmmm dd, yyyy")
        Case "Time"
            FormatJiraDate = Format(dateValue, "hh:mm AM/PM")
        Case "DateTime"
            FormatJiraDate = Format(dateValue, "mm/dd/yyyy hh:mm AM/PM")
        Case "Relative"
            FormatJiraDate = GetRelativeDate(dateValue)
        Case Else
            FormatJiraDate = Format(dateValue, "mm/dd/yyyy")
    End Select
    
    Exit Function
    
ErrorHandler:
    FormatJiraDate = "Invalid Date"
End Function

Function GetRelativeDate(dateValue As Date) As String
    ' Returns relative date string (e.g., "2 days ago", "in 3 days")
    
    On Error GoTo ErrorHandler
    
    Dim daysDiff As Long
    daysDiff = DateDiff("d", dateValue, Now())
    
    If daysDiff = 0 Then
        GetRelativeDate = "Today"
    ElseIf daysDiff = 1 Then
        GetRelativeDate = "Yesterday"
    ElseIf daysDiff > 1 Then
        GetRelativeDate = daysDiff & " days ago"
    ElseIf daysDiff = -1 Then
        GetRelativeDate = "Tomorrow"
    Else
        GetRelativeDate = "in " & Abs(daysDiff) & " days"
    End If
    
    Exit Function
    
ErrorHandler:
    GetRelativeDate = "Unknown"
End Function

' =============================================================================
' BULK DATE CONVERSION FUNCTIONS
' =============================================================================

Sub ConvertJiraDatesInRange()
    ' Converts Jira date strings in a selected range to proper Excel dates
    
    Dim rng As Range
    Dim cell As Range
    Dim convertedCount As Long
    
    Set rng = Selection
    
    If rng Is Nothing Then
        MsgBox "Please select a range of cells containing Jira date strings"
        Exit Sub
    End If
    
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    
    For Each cell In rng
        If cell.Value <> "" And cell.Value <> "null" Then
            Dim originalValue As String
            originalValue = cell.Value
            
            Dim convertedDate As Date
            convertedDate = ConvertJiraDate(originalValue)
            
            If convertedDate > 0 Then
                cell.Value = convertedDate
                cell.NumberFormat = "mm/dd/yyyy hh:mm AM/PM"
                convertedCount = convertedCount + 1
            End If
        End If
    Next cell
    
    Application.ScreenUpdating = True
    Application.Calculation = xlCalculationAutomatic
    
    MsgBox "Converted " & convertedCount & " date strings to Excel dates"
End Sub

Sub AddDateCalculations()
    ' Adds calculated date columns to Jira data
    
    Dim ws As Worksheet
    Set ws = ActiveSheet
    
    ' Find the last row with data
    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    
    ' Add calculated columns
    ws.Cells(1, ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column + 1).Value = "Days Since Created"
    ws.Cells(1, ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column + 1).Value = "Days Until Due"
    ws.Cells(1, ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column + 1).Value = "Resolution Time Days"
    
    ' Add formulas
    Dim createdCol As Long
    Dim dueCol As Long
    Dim resolvedCol As Long
    
    ' Find column numbers (adjust based on your data structure)
    createdCol = 5  ' Adjust to match your Created column
    dueCol = 6      ' Adjust to match your Due Date column
    resolvedCol = 7 ' Adjust to match your Resolution Date column
    
    Dim calcCol1 As Long
    Dim calcCol2 As Long
    Dim calcCol3 As Long
    
    calcCol1 = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column - 2
    calcCol2 = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column - 1
    calcCol3 = ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
    
    ' Add formulas
    For i = 2 To lastRow
        ws.Cells(i, calcCol1).Formula = "=DaysSinceCreated(" & ws.Cells(i, createdCol).Address & ")"
        ws.Cells(i, calcCol2).Formula = "=DaysUntilDue(" & ws.Cells(i, dueCol).Address & ")"
        ws.Cells(i, calcCol3).Formula = "=ResolutionTimeDays(" & ws.Cells(i, createdCol).Address & "," & ws.Cells(i, resolvedCol).Address & ")"
    Next i
    
    MsgBox "Added calculated date columns"
End Sub

' =============================================================================
' DATE VALIDATION AND TESTING
' =============================================================================

Sub TestDateConversion()
    ' Tests date conversion functions with sample data
    
    Dim testDates As Variant
    testDates = Array( _
        "2024-01-15T10:30:00.000+0000", _
        "2024-01-16T14:45:00.000+0000", _
        "2024-01-20T17:00:00.000+0000", _
        "2024-01-18T16:20:00.000+0000", _
        "", _
        "null" _
    )
    
    Dim i As Integer
    For i = 0 To UBound(testDates)
        Dim testDate As String
        testDate = testDates(i)
        
        Debug.Print "Original: " & testDate
        Debug.Print "Converted: " & ConvertJiraDate(testDate)
        Debug.Print "Valid: " & IsValidJiraDate(testDate)
        Debug.Print "Type: " & GetDateFieldType(testDate)
        Debug.Print "Formatted: " & FormatJiraDate(testDate, "DateTime")
        Debug.Print "---"
    Next i
End Sub

Sub ValidateDateFields()
    ' Validates date fields in the current worksheet
    
    Dim ws As Worksheet
    Set ws = ActiveSheet
    
    Dim lastRow As Long
    lastRow = ws.Cells(ws.Rows.Count, 1).End(xlUp).Row
    
    Dim invalidCount As Long
    Dim totalCount As Long
    
    ' Check each row for invalid dates
    For i = 2 To lastRow
        For j = 1 To ws.Cells(1, ws.Columns.Count).End(xlToLeft).Column
            Dim cellValue As String
            cellValue = ws.Cells(i, j).Value
            
            ' Check if this looks like a date field
            If InStr(cellValue, "T") > 0 And InStr(cellValue, "-") > 0 Then
                totalCount = totalCount + 1
                If Not IsValidJiraDate(cellValue) Then
                    invalidCount = invalidCount + 1
                    ws.Cells(i, j).Interior.Color = RGB(255, 200, 200) ' Light red
                End If
            End If
        Next j
    Next i
    
    MsgBox "Validation complete. Found " & invalidCount & " invalid dates out of " & totalCount & " total date fields."
End Sub
