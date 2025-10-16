# Dynamic Jira Excel Integration Setup Guide

This guide shows you how to create dynamic, interactive Jira reports in Excel that can be refreshed with VBA and use cell values as parameters.

## 🚀 **Quick Setup (5 minutes):**

### **Step 1: Set Up Parameters**
1. **Open Excel** and create a new workbook
2. **Press Alt+F11** to open VBA Editor
3. **Insert → Module** and paste the code from `excel-vba-dynamic-jira.vba`
4. **Run the SetupJiraParameters()** function:
   - Press F5 or go to **Run → Run Sub/UserForm**
   - Select `SetupJiraParameters` and click **Run**

### **Step 2: Create Power Query**
1. **Go to Data → Get Data → From Other Sources → Blank Query**
2. **Click Advanced Editor**
3. **Copy and paste** the code from `dynamic-jira-queries.pq`
4. **Click Done**
5. **Click Close & Load**

### **Step 3: Test Dynamic Refresh**
1. **Change the Project Key** in cell B5 (e.g., enter "PROJ")
2. **Click the "Refresh Jira Data" button**
3. **Watch the data update automatically!**

## 📊 **What You Get:**

### **Dynamic Parameters:**
- **Base URL**: Your Jira instance URL
- **Username**: Your Jira username
- **API Token**: Your Jira API token
- **Project Key**: Filter by specific project (leave empty for all)
- **Status**: Filter by status (leave empty for all)
- **Custom JQL**: Override with custom JQL query

### **Automatic Features:**
- **Smart JQL Generation**: Automatically builds JQL based on your parameters
- **One-Click Refresh**: Button to refresh all data
- **Parameter Validation**: Built-in error handling
- **Flexible Filtering**: Mix and match project, status, and custom JQL

## 🔧 **Advanced Usage:**

### **VBA Functions Available:**

```vba
' Quick filter functions
Call ShowOpenIssues()           ' Show only open issues
Call ShowInProgressIssues()     ' Show in-progress issues
Call ShowOverdueIssues()        ' Show overdue issues
Call ShowRecentIssues()         ' Show issues from last 7 days
Call ShowMyIssues()             ' Show issues assigned to you

' Parameter management
Call SetJiraProject("PROJ")     ' Set project filter
Call SetJiraStatus("Open")      ' Set status filter
Call SetJiraJQL("custom query") ' Set custom JQL
Call ClearJiraFilters()         ' Clear all filters

' Automation
Call AutoRefreshJiraData()      ' Enable auto-refresh every 5 minutes
Call StopAutoRefresh()          ' Stop auto-refresh
```

### **Custom JQL Examples:**

```vba
' Issues created in last 30 days
Call SetJiraJQL("created >= -30d ORDER BY created DESC")

' High priority issues
Call SetJiraJQL("priority = High ORDER BY created DESC")

' Issues assigned to specific user
Call SetJiraJQL("assignee = 'john.doe@company.com' ORDER BY updated DESC")

' Issues in multiple projects
Call SetJiraJQL("project in (PROJ1, PROJ2, PROJ3) ORDER BY project ASC")

' Issues with specific labels
Call SetJiraJQL("labels = 'urgent' ORDER BY priority DESC")
```

## 📈 **Creating Dashboards:**

### **Multi-Sheet Dashboard:**
```vba
Call CreateJiraDashboard()  ' Creates 5 sheets with different views
```

### **Custom Dashboard Setup:**
1. **Create multiple sheets** for different views
2. **Set up different Power Queries** on each sheet
3. **Use different parameters** for each sheet
4. **Create summary sheets** with charts and pivot tables

## 🔄 **Automation Options:**

### **Scheduled Refresh:**
```vba
' Auto-refresh every 5 minutes
Call AutoRefreshJiraData()

' Stop auto-refresh
Call StopAutoRefresh()
```

### **Event-Driven Refresh:**
```vba
' Refresh when workbook opens
Private Sub Workbook_Open()
    Call RefreshJiraDataSilent
End Sub

' Refresh when specific cell changes
Private Sub Worksheet_Change(ByVal Target As Range)
    If Not Intersect(Target, Range("B5:B7")) Is Nothing Then
        Call RefreshJiraDataSilent
    End If
End Sub
```

## 🎯 **Use Cases:**

### **Daily Operations:**
- **Morning Standup**: Show yesterday's completed work
- **Sprint Planning**: Show backlog items by priority
- **Issue Triage**: Show new issues that need assignment

### **Weekly Reports:**
- **Project Health**: Show issues by project and status
- **Team Workload**: Show issues by assignee
- **Sprint Progress**: Show sprint issues and completion

### **Monthly Reviews:**
- **Process Analysis**: Show workflow bottlenecks
- **Resource Planning**: Show issue distribution
- **Performance Metrics**: Show resolution times

## ⚙️ **Customization:**

### **Adding New Parameters:**
1. **Add new named range** in VBA setup
2. **Update Power Query** to read the new parameter
3. **Modify JQL generation** logic

### **Adding New Quick Filters:**
```vba
Sub ShowCustomFilter()
    Call SetJiraJQL("your custom JQL here")
    Call RefreshJiraDataSilent
End Sub
```

### **Adding Data Validation:**
```vba
' Add dropdown for project selection
With ActiveSheet.Cells(5, 2).Validation
    .Delete
    .Add Type:=xlValidateList, AlertStyle:=xlValidAlertStop, Formula1:="PROJ1,PROJ2,PROJ3"
End With
```

## 🔒 **Security Best Practices:**

1. **Protect API Token**: Consider using environment variables
2. **Limit Permissions**: Use read-only API tokens
3. **Secure Workbook**: Password protect the workbook
4. **Regular Rotation**: Rotate API tokens regularly

## 🆘 **Troubleshooting:**

### **Common Issues:**

**"Named range not found"**
- Run `SetupJiraParameters()` again
- Check that named ranges exist in Name Manager

**"Power Query refresh fails"**
- Verify API token is correct
- Check network connectivity
- Verify Jira URL is accessible

**"Data not updating"**
- Check parameter values in cells B2-B7
- Verify JQL syntax is correct
- Check for typos in project keys or status names

### **Debug Mode:**
```vba
' Add this to see what JQL is being generated
Sub DebugJiraQuery()
    Dim jql As String
    jql = ActiveSheet.Cells(7, 2).Value
    If jql = "" Then
        ' Show auto-generated JQL
        MsgBox "Auto-generated JQL based on parameters"
    Else
        MsgBox "Custom JQL: " & jql
    End If
End Sub
```

## 📚 **Next Steps:**

1. **Start Simple**: Begin with basic project/status filters
2. **Add Complexity**: Gradually add more parameters and filters
3. **Create Dashboards**: Build multiple views for different stakeholders
4. **Automate**: Set up scheduled refreshes for regular reporting
5. **Share**: Distribute to team members for self-service reporting

---

**Need Help?** Check the VBA code comments and Power Query documentation for more advanced customization options.
