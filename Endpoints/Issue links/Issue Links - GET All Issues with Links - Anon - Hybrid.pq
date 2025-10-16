// =============================================================================
// ENDPOINT: Issue Links - GET All Issues with Links (Hybrid)
// =============================================================================
//
// DESCRIPTION: Returns all issues that have issue links, including details about
// the links themselves. Uses Enhanced JQL API for performance.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. No additional parameters required.
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // =============================================================================
    // JQL SEARCH FOR ISSUES WITH LINKS
    // =============================================================================
    SearchEndpoint = "/rest/api/3/search",
    SearchUrl = BaseUrl & SearchEndpoint,

    // Search for issues with links, including the issuelinks field
    JqlQuery = "issueLink is not EMPTY ORDER BY created DESC",

    SearchBody = [
        jql = JqlQuery,
        maxResults = 1000,
        fields = {"id", "key", "summary", "status", "priority", "assignee", "reporter", "created", "updated", "project", "issuetype", "issuelinks"}
    ],

    SearchResponse = Json.Document(
        Web.Contents(SearchUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json",
                #"Content-Type" = "application/json"
            ],
            Content = Text.ToBinary(Json.FromValue(SearchBody))
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    IssuesList = SearchResponse[issues],

    // Convert to table and expand issue fields
    IssuesTable = Table.FromList(IssuesList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

    ExpandedIssues = Table.ExpandRecordColumn(IssuesTable, "Column1",
        {"id", "key", "fields"},
        {"IssueId", "IssueKey", "Fields"}),

    // Expand the fields column
    ExpandedFields = Table.ExpandRecordColumn(ExpandedIssues, "Fields",
        {"summary", "status", "priority", "assignee", "reporter", "created", "updated", "project", "issuetype", "issuelinks"},
        {"Summary", "Status", "Priority", "Assignee", "Reporter", "Created", "Updated", "Project", "IssueType", "IssueLinks"}),

    // Process issue links
    ProcessedLinks = Table.AddColumn(ExpandedFields, "ProcessedLinks", each
        let
            links = [IssueLinks],
            inwardLinks = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "inwardIssue")), each
                try [type][inward] & ": " & [inwardIssue][key] & " - " & [inwardIssue][fields][summary] otherwise "Link info unavailable"
            ),
            outwardLinks = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "outwardIssue")), each
                try [type][outward] & ": " & [outwardIssue][key] & " - " & [outwardIssue][fields][summary] otherwise "Link info unavailable"
            ),
            allLinks = List.Combine({inwardLinks, outwardLinks})
        in
            [
                InwardLinks = if List.Count(inwardLinks) > 0 then Text.Combine(inwardLinks, "; ") else "",
                OutwardLinks = if List.Count(outwardLinks) > 0 then Text.Combine(outwardLinks, "; ") else "",
                TotalLinks = List.Count(allLinks)
            ]
    ),

    // Expand the processed links
    ExpandedProcessedLinks = Table.ExpandRecordColumn(ProcessedLinks, "ProcessedLinks",
        {"InwardLinks", "OutwardLinks", "TotalLinks"},
        {"InwardLinks", "OutwardLinks", "TotalLinks"}),

    // Clean up and format the data
    FormattedData = Table.TransformColumns(ExpandedProcessedLinks, {
        {"Summary", each if _ = null then "" else _},
        {"Status", each if _ = null then "" else [name]},
        {"Priority", each if _ = null then "" else [name]},
        {"Assignee", each if _ = null then "" else [displayName]},
        {"Reporter", each if _ = null then "" else [displayName]},
        {"Created", each if _ = null then "" else DateTime.ToText(DateTime.FromText(_), "MM/dd/yyyy HH:mm:ss")},
        {"Updated", each if _ = null then "" else DateTime.ToText(DateTime.FromText(_), "MM/dd/yyyy HH:mm:ss")},
        {"Project", each if _ = null then "" else [name]},
        {"IssueType", each if _ = null then "" else [name]}
    }),

    // Add generation timestamp
    WithTimestamp = Table.AddColumn(FormattedData, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Select and rename final columns
    FinalColumns = Table.SelectColumns(WithTimestamp,
        {"IssueId", "IssueKey", "Summary", "Status", "Priority", "Assignee", "Reporter", "Created", "Updated", "Project", "IssueType", "InwardLinks", "OutwardLinks", "TotalLinks", "GeneratedAt"}),

    Result = Table.RenameColumns(FinalColumns, {
        {"IssueId", "Id"},
        {"IssueKey", "Key"}
    })

in
    Result
