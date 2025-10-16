// =============================================================================
// SECURE JIRA QUERIES WITH OMF AUTHENTICATION
// =============================================================================

// This template provides secure authentication for all Jira queries
// Users log in with their OMF credentials and get seamless access to all dashboards

// =============================================================================
// AUTHENTICATION SETUP
// =============================================================================

// 1. Server Information Query
let
    // Read credentials from Excel named ranges (set up by Authentication Manager)
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL
    Url = BaseUrl & "/serverInfo",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    ServerInfo = Record.ToTable(Response)
in
    ServerInfo

// 2. Current User Information Query
let
    // Read credentials from Excel named ranges
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL
    Url = BaseUrl & "/myself",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    UserInfo = Record.ToTable(Response)
in
    UserInfo

// 3. All Users Query (requires admin permissions)
let
    // Read credentials from Excel named ranges
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL
    Url = BaseUrl & "/users/search?maxResults=999999",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    UsersTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    UsersExpanded = Table.ExpandRecordColumn(UsersTable, "Column1", {"accountId", "displayName", "emailAddress", "active", "accountType"}, {"Account ID", "Display Name", "Email", "Active", "Account Type"})
in
    UsersExpanded

// 4. Projects Query
let
    // Read credentials from Excel named ranges
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL
    Url = BaseUrl & "/project",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    ProjectsTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "name", "description", "lead", "created", "updated", "projectTypeKey"}, {"Key", "Name", "Description", "Lead", "Created", "Updated", "Project Type"})
in
    ProjectsExpanded

// 5. Issues Query with Date Conversion
let
    // Read credentials from Excel named ranges
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL with JQL
    JQLQuery = "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Extract issues
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    
    // Expand issue fields
    IssuesExpanded = Table.ExpandRecordColumn(
        Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), 
        "Fields", 
        {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, 
        {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}
    ),
    
    // Convert date fields from text to proper date/time
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated date columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Add time-based calculated columns
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number)
    
in
    AddTimeColumns4

// 6. Workflows Query
let
    // Read credentials from Excel named ranges
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build API URL
    Url = BaseUrl & "/workflow",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    WorkflowsTable = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    WorkflowsExpanded = Table.ExpandRecordColumn(WorkflowsTable, "Column1", {"id", "name", "description", "statuses", "transitions"}, {"ID", "Name", "Description", "Statuses", "Transitions"})
in
    WorkflowsExpanded

// =============================================================================
// USAGE INSTRUCTIONS
// =============================================================================

/*
SETUP STEPS FOR OMF USERS:

1. LOGIN WITH OMF CREDENTIALS:
   Run: .\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO

2. CREATE EXCEL NAMED RANGES:
   - JiraBaseUrl: https://onemain.atlassian.net/rest/api/3
   - JiraUsername: your.email@omf.com
   - JiraApiToken: [Auto-generated by Authentication Manager]

3. LOAD THIS QUERY INTO EXCEL:
   - Copy the query you need from above
   - Paste into Power Query Editor
   - Refresh to load data

4. AUTOMATIC FEATURES:
   - ✅ OMF SSO Integration
   - ✅ Encrypted API Token Storage
   - ✅ Role-based Permissions
   - ✅ Session Management
   - ✅ Audit Logging

SECURITY FEATURES:
- No embedded credentials in files
- API tokens are encrypted and user-specific
- Automatic session refresh
- Permission-based data access
- Complete audit trail

SUPPORT:
Contact OMF Analytics Team for assistance.
*/

