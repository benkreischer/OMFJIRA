// =============================================================================
// EXCEL MASTER ANALYTICS - POWER QUERY CONNECTIONS
// =============================================================================

// This file contains all Power Query connections for the Excel Master Analytics file
// Copy these queries into your Excel workbook for full functionality

// =============================================================================
// MAIN DATA CONNECTION - ALL ISSUES
// =============================================================================

let
    // Configuration (read from Excel cells)
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Authentication
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call - Get all issues
    JQLQuery = "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Issues
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(
        Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), 
        "Fields", 
        {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate", "labels", "components", "fixVersions", "customfield_10020"}, 
        {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date", "Labels", "Components", "Fix Versions", "Sprint"}
    ),
    
    // Date Conversion
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add Calculated Columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Time Calculations
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Status Categories
    AddStatusCategory = Table.AddColumn(AddTimeColumns4, "Status Category", each 
        if [Status] = "Done" then "Completed" else
        if [Status] = "In Progress" then "Active" else
        if [Status] = "To Do" then "Backlog" else "Other", type text),
    
    // Priority Categories
    AddPriorityCategory = Table.AddColumn(AddStatusCategory, "Priority Category", each 
        if [Priority] = "Highest" then "Critical" else
        if [Priority] = "High" then "High" else
        if [Priority] = "Medium" then "Medium" else
        if [Priority] = "Low" then "Low" else "Unknown", type text),
    
    // Week and Month Calculations
    AddWeekCalculations = Table.AddColumn(AddPriorityCategory, "Created Week", each Date.WeekOfYear([Created Date Only]), type number),
    AddMonthCalculations = Table.AddColumn(AddWeekCalculations, "Created Month", each Date.Month([Created Date Only]), type number),
    AddYearCalculations = Table.AddColumn(AddMonthCalculations, "Created Year", each Date.Year([Created Date Only]), type number),
    
    // Quarter Calculations
    AddQuarterCalculations = Table.AddColumn(AddYearCalculations, "Created Quarter", each Date.QuarterOfYear([Created Date Only]), type number)
    
in
    AddQuarterCalculations

// =============================================================================
// PROJECTS CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/project",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Projects
    ProjectsTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "name", "projectTypeKey", "lead", "description"}, {"Key", "Name", "Type", "Lead", "Description"})
    
in
    ProjectsExpanded

// =============================================================================
// USERS CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/users/search?maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Users
    UsersTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    UsersExpanded = Table.ExpandRecordColumn(UsersTable, "Column1", {"accountId", "displayName", "emailAddress", "active", "accountType"}, {"Account ID", "Display Name", "Email", "Active", "Account Type"})
    
in
    UsersExpanded

// =============================================================================
// STATUSES CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/status",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Statuses
    StatusesTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    StatusesExpanded = Table.ExpandRecordColumn(StatusesTable, "Column1", {"id", "name", "description", "statusCategory"}, {"ID", "Name", "Description", "Status Category"})
    
in
    StatusesExpanded

// =============================================================================
// PRIORITIES CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/priority",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Priorities
    PrioritiesTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    PrioritiesExpanded = Table.ExpandRecordColumn(PrioritiesTable, "Column1", {"id", "name", "description", "statusColor"}, {"ID", "Name", "Description", "Status Color"})
    
in
    PrioritiesExpanded

// =============================================================================
// ISSUE TYPES CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/issuetype",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Issue Types
    IssueTypesTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssueTypesExpanded = Table.ExpandRecordColumn(IssueTypesTable, "Column1", {"id", "name", "description", "iconUrl"}, {"ID", "Name", "Description", "Icon URL"})
    
in
    IssueTypesExpanded

// =============================================================================
// WORKFLOWS CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call
    Url = BaseUrl & "/workflow",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Workflows
    WorkflowsTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    WorkflowsExpanded = Table.ExpandRecordColumn(WorkflowsTable, "Column1", {"name", "description", "steps", "default", "lastModifiedDate"}, {"Name", "Description", "Steps", "Default", "Last Modified"})
    
in
    WorkflowsExpanded

// =============================================================================
// CUSTOM JQL QUERY CONNECTION
// =============================================================================

let
    // Configuration
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    CustomJQL = Excel.CurrentWorkbook(){[Name="CustomJQL"]}[Content]{0}[Column1],
    
    // Authentication
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // API Call with custom JQL
    JQLQuery = if CustomJQL <> "" then CustomJQL else "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Process Issues (same as main connection)
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(
        Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), 
        "Fields", 
        {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, 
        {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}
    ),
    
    // Date Conversion
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add Calculated Columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Time Calculations
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number)
    
in
    AddTimeColumns4
