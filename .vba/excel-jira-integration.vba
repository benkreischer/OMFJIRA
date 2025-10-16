' Excel VBA code to call Jira API PowerShell scripts
' Add this to a VBA module in Excel

Sub GetJiraWorkflows()
    ' Call the PowerShell script and get workflows
    Dim result As String
    result = RunPowerShellScript(".\jira-quick-embedded.ps1", "workflow")
    
    ' Parse JSON and populate Excel sheet
    Call ParseJiraDataToExcel(result, "Workflows")
End Sub

Sub GetJiraProjects()
    ' Call the PowerShell script and get projects
    Dim result As String
    result = RunPowerShellScript(".\jira-quick-embedded.ps1", "project")
    
    ' Parse JSON and populate Excel sheet
    Call ParseJiraDataToExcel(result, "Projects")
End Sub

Sub GetJiraIssue(issueKey As String)
    ' Get specific issue details
    Dim result As String
    result = RunPowerShellScript(".\jira-quick-embedded.ps1", "issue/" & issueKey)
    
    ' Parse JSON and populate Excel sheet
    Call ParseJiraDataToExcel(result, "Issue_" & issueKey)
End Sub

Function RunPowerShellScript(scriptPath As String, endpoint As String) As String
    ' Execute PowerShell script and return result
    Dim shell As Object
    Dim command As String
    Dim result As String
    
    Set shell = CreateObject("WScript.Shell")
    
    ' Build PowerShell command
    command = "powershell.exe -ExecutionPolicy Bypass -File """ & scriptPath & """ """ & endpoint & """"
    
    ' Execute command and capture output
    result = shell.Exec(command).StdOut.ReadAll
    
    RunPowerShellScript = result
End Function

Sub ParseJiraDataToExcel(jsonData As String, sheetName As String)
    ' Parse JSON data and populate Excel sheet
    ' This is a simplified version - you might want to use a JSON parser library
    
    Dim ws As Worksheet
    Dim jsonArray As Object
    Dim i As Integer
    Dim j As Integer
    
    ' Create or select worksheet
    On Error Resume Next
    Set ws = Worksheets(sheetName)
    On Error GoTo 0
    
    If ws Is Nothing Then
        Set ws = Worksheets.Add
        ws.Name = sheetName
    End If
    
    ' Clear existing data
    ws.Cells.Clear
    
    ' Add headers
    ws.Cells(1, 1).Value = "Name"
    ws.Cells(1, 2).Value = "Description"
    ws.Cells(1, 3).Value = "Steps"
    ws.Cells(1, 4).Value = "Default"
    ws.Cells(1, 5).Value = "Last Modified"
    
    ' Note: For full JSON parsing, you'd need a JSON parser library
    ' This is a basic example - you might want to use VBA-JSON or similar
    
    MsgBox "JSON data received. Consider using a JSON parser library for full functionality."
End Sub

' Example usage functions
Sub TestJiraConnection()
    ' Test if Jira API is working
    Dim result As String
    result = RunPowerShellScript(".\jira-quick-embedded.ps1", "myself")
    
    If InStr(result, "displayName") > 0 Then
        MsgBox "Jira connection successful!"
    Else
        MsgBox "Jira connection failed. Check your API token."
    End If
End Sub
