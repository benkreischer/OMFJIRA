// =============================================================================
// ENDPOINT: Issue Links - GET Project Links (Hybrid)
// =============================================================================
//
// DESCRIPTION: Returns all issues that have issue links, showing the issue's
// project key and all unique project keys of linked issues.
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
        fields = {"id", "key", "project", "issuelinks"}
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

    // Expand the fields column to get project and issuelinks
    ExpandedFields = Table.ExpandRecordColumn(ExpandedIssues, "Fields",
        {"project", "issuelinks"},
        {"Project", "IssueLinks"}),

    // Filter out issues without links
    IssuesWithLinks = Table.SelectRows(ExpandedFields, each [IssueLinks] <> null and List.Count([IssueLinks]) > 0),

    // Process issue links to extract project keys
    ProcessedLinks = Table.AddColumn(IssuesWithLinks, "ProcessedLinks", each
        let
            links = [IssueLinks],
            issueProjectKey = if [Project] = null then "" else [Project][key],
            inwardProjectKeys = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "inwardIssue")), each
                try Text.Split([inwardIssue][key], "-"){0} otherwise null
            ),
            outwardProjectKeys = if links = null then {} else List.Transform(List.Select(links, each _ <> null and Record.HasFields(_, "outwardIssue")), each
                try Text.Split([outwardIssue][key], "-"){0} otherwise null
            ),
            allLinkedProjectKeys = List.Combine({inwardProjectKeys, outwardProjectKeys}),
            validLinkedProjectKeys = List.Select(allLinkedProjectKeys, each _ <> null),
            uniqueLinkedProjectKeys = List.Distinct(validLinkedProjectKeys),
            allProjectKeys = List.Distinct(List.Combine({if issueProjectKey = "" then {} else {issueProjectKey}, uniqueLinkedProjectKeys}))
        in
            [
                ProjectKey = issueProjectKey,
                LinkedProjectKeys = if List.Count(uniqueLinkedProjectKeys) > 0 then Text.Combine(List.Sort(uniqueLinkedProjectKeys), "; ") else "",
                AllProjectKeys = if List.Count(allProjectKeys) > 0 then Text.Combine(List.Sort(allProjectKeys), "; ") else "",
                UniqueProjectCount = List.Count(allProjectKeys),
                TotalLinks = List.Count(validLinkedProjectKeys)
            ]
    ),

    // Expand the processed links
    ExpandedProcessedLinks = Table.ExpandRecordColumn(ProcessedLinks, "ProcessedLinks",
        {"ProjectKey", "LinkedProjectKeys", "AllProjectKeys", "UniqueProjectCount", "TotalLinks"},
        {"ProjectKey", "LinkedProjectKeys", "AllProjectKeys", "UniqueProjectCount", "TotalLinks"}),

    // Add generation timestamp
    WithTimestamp = Table.AddColumn(ExpandedProcessedLinks, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Select and rename final columns
    FinalColumns = Table.SelectColumns(WithTimestamp,
        {"IssueId", "IssueKey", "ProjectKey", "LinkedProjectKeys", "AllProjectKeys", "UniqueProjectCount", "TotalLinks", "GeneratedAt"}),

    Result = Table.RenameColumns(FinalColumns, {
        {"IssueId", "Id"},
        {"IssueKey", "Key"}
    })

in
    Result
