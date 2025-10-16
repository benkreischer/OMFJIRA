// =============================================================================
// POWERBI OAUTH SETUP FOR OMF JIRA ANALYTICS
// =============================================================================

// This uses OAuth authentication - users just log in with their OMF credentials
// No API tokens needed!

let
    // Jira OAuth configuration
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    
    // OAuth authentication - user will be prompted to log in
    AuthUrl = "https://onemain.atlassian.net/rest/api/3/myself",
    
    // Get basic issues data
    JQLQuery = "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    
    // Make API call with OAuth
    Headers = [#"Content-Type" = "application/json"],
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
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Add time-based calculated columns
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Clean up the data
    FinalData = Table.SelectColumns(AddTimeColumns4, {
        "Key", "Summary", "Status", "Assignee", "Reporter", "Created", "Updated", 
        "Priority", "Issue Type", "Project", "Due Date", "Resolution Date",
        "Created Date Only", "Updated Date Only", "Due Date Only", "Resolution Date Only",
        "Days Since Created", "Days Since Updated", "Days Until Due", "Resolution Time Days"
    })
    
in
    FinalData
