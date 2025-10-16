// =============================================================================
// DYNAMIC JIRA QUERIES - Excel Cell Integration (SECURE VERSION)
// =============================================================================

// This query reads parameters from Excel cells and uses them in Jira API calls
// Set up named ranges in Excel for the parameters, then use VBA to refresh
// NO EMBEDDED CREDENTIALS - All credentials come from Excel cells

let
    // Read parameters from Excel cells using named ranges
    // Create these named ranges in Excel: JiraBaseUrl, JiraUsername, JiraApiToken, JiraProjectKey, JiraStatus, JiraJQL
    
    BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    ProjectKey = Excel.CurrentWorkbook(){[Name="JiraProjectKey"]}[Content]{0}[Column1],
    StatusFilter = Excel.CurrentWorkbook(){[Name="JiraStatus"]}[Content]{0}[Column1],
    CustomJQL = Excel.CurrentWorkbook(){[Name="JiraJQL"]}[Content]{0}[Column1],
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Build dynamic JQL query based on parameters
    JQLQuery = if CustomJQL <> "" then CustomJQL else 
               if ProjectKey <> "" and StatusFilter <> "" then "project = " & ProjectKey & " AND status = """ & StatusFilter & """ ORDER BY updated DESC" else
               if ProjectKey <> "" then "project = " & ProjectKey & " ORDER BY updated DESC" else
               if StatusFilter <> "" then "status = """ & StatusFilter & """ ORDER BY updated DESC" else
               "ORDER BY updated DESC",
    
    // Encode JQL for URL
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    
    // Build API URL
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
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Add query parameters as columns for reference
    AddParameters = Table.AddColumn(AddTimeColumns4, "Query Used", each JQLQuery),
    AddProjectFilter = Table.AddColumn(AddParameters, "Project Filter", each ProjectKey),
    AddStatusFilter = Table.AddColumn(AddProjectFilter, "Status Filter", each StatusFilter)
    
in
    AddStatusFilter
