// =============================================================================
// JIRA DATE CONVERSION FIXES
// =============================================================================

// This file contains Power Query M code to properly convert Jira date fields
// from text strings to proper date/time data types

// =============================================================================
// METHOD 1: BASIC DATE CONVERSION
// =============================================================================

let
    // Your existing Jira API call
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    Url = BaseUrl & "/search?jql=ORDER BY updated DESC&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Due Date", "Resolution Date"}),
    
    // Convert date fields from text to proper date/time
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", DateTime.FromText},
        {"Updated", DateTime.FromText},
        {"Due Date", DateTime.FromText},
        {"Resolution Date", DateTime.FromText}
    })
    
in
    ConvertDates

// =============================================================================
// METHOD 2: ADVANCED DATE CONVERSION WITH ERROR HANDLING
// =============================================================================

let
    // Your existing Jira API call
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    Url = BaseUrl & "/search?jql=ORDER BY updated DESC&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Due Date", "Resolution Date"}),
    
    // Advanced date conversion with error handling
    ConvertDatesAdvanced = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    })
    
in
    ConvertDatesAdvanced

// =============================================================================
// METHOD 3: CUSTOM DATE CONVERSION FUNCTION
// =============================================================================

// Custom function to convert Jira date strings
let
    ConvertJiraDate = (dateText as text) as datetime =>
    let
        // Handle null or empty values
        CleanDate = if dateText = null or dateText = "" then null else dateText,
        // Convert to datetime
        ConvertedDate = if CleanDate = null then null else DateTime.FromText(CleanDate)
    in
        ConvertedDate
in
    ConvertJiraDate

// =============================================================================
// METHOD 4: COMPLETE JIRA QUERY WITH PROPER DATE CONVERSION
// =============================================================================

let
    // Configuration
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Custom date conversion function
    ConvertJiraDate = (dateText as text) as datetime =>
    let
        CleanDate = if dateText = null or dateText = "" then null else dateText,
        ConvertedDate = if CleanDate = null then null else DateTime.FromText(CleanDate)
    in
        ConvertedDate,
    
    // API call
    Url = BaseUrl & "/search?jql=ORDER BY updated DESC&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Due Date", "Resolution Date"}),
    
    // Convert all date fields
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", ConvertJiraDate, type datetime},
        {"Updated", ConvertJiraDate, type datetime},
        {"Due Date", ConvertJiraDate, type datetime},
        {"Resolution Date", ConvertJiraDate, type datetime}
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
