// =============================================================================
// ENDPOINT: Issue Links - GET Simple Links (Hybrid)
// =============================================================================
//
// DESCRIPTION: Returns all issues that have issue links, showing just ID, Key,
// and the keys of linked issues in a simplified format.
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

    // Search for issues with links
    JqlQuery = "project is not EMPTY ORDER BY created DESC",

    SearchBody = [
        jql = JqlQuery,
        maxResults = 1000,
        fields = {"id", "key", "issuelinks"}
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

    // Expand the fields column to get issuelinks
    ExpandedFields = Table.ExpandRecordColumn(ExpandedIssues, "Fields",
        {"issuelinks"},
        {"IssueLinks"}),

    // Filter out issues without links
    IssuesWithLinks = Table.SelectRows(ExpandedFields, each [IssueLinks] <> null and List.Count([IssueLinks]) > 0),

    // Process issue links to extract just the linked keys
    ProcessedLinks = Table.AddColumn(IssuesWithLinks, "ProcessedLinks", each
        let
            links = [IssueLinks],
            inwardKeys = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "inwardIssue")), each
                try [inwardIssue][key] otherwise null
            ),
            outwardKeys = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "outwardIssue")), each
                try [outwardIssue][key] otherwise null
            ),
            allKeys = List.Combine({inwardKeys, outwardKeys}),
            validKeys = List.Select(allKeys, each _ <> null)
        in
            [
                LinkedKeys = if List.Count(validKeys) > 0 then Text.Combine(List.Sort(validKeys), "; ") else "",
                TotalLinks = List.Count(validKeys)
            ]
    ),

    // Expand the processed links
    ExpandedProcessedLinks = Table.ExpandRecordColumn(ProcessedLinks, "ProcessedLinks",
        {"LinkedKeys", "TotalLinks"},
        {"LinkedKeys", "TotalLinks"}),

    // Add generation timestamp
    WithTimestamp = Table.AddColumn(ExpandedProcessedLinks, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Select and rename final columns
    FinalColumns = Table.SelectColumns(WithTimestamp,
        {"IssueId", "IssueKey", "LinkedKeys", "TotalLinks", "GeneratedAt"}),

    Result = Table.RenameColumns(FinalColumns, {
        {"IssueId", "Id"},
        {"IssueKey", "Key"}
    })

in
    Result
