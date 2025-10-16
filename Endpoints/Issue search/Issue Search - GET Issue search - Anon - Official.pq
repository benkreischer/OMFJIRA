// =============================================================================
// ENDPOINT: Issue Search - GET Issue search
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-search/#api-rest-api-3-search-jql-get
//
// DESCRIPTION: Searches for issues using JQL enhanced search.
// IMPLEMENTATION: Enhanced JQL API with two-phase approach (get IDs, then bulk fetch details)
// BASED ON: https://community.atlassian.com/forums/Jira-articles/Avoiding-Pitfalls-A-Guide-to-Smooth-Migration-to-Enhanced-JQL/ba-p/2985433
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'JqlQuery' parameter with your JQL string.
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
    // PARAMETERS
    // =============================================================================
    RangeStart = "2000-01-01",
    RangeEnd = "2025-12-31",
    JqlQuery = "created >= '" & RangeStart & "' AND created <= '" & RangeEnd & "' ORDER BY created DESC, id ASC", // <-- JQL with date range filter and stable sorting for 2000-2025, all projects
    Fields = "summary,status,priority,assignee,reporter,created,updated,resolutiondate,project,issuetype,issuelinks", // <-- Fields to retrieve including linked issues
    MaxResults = 5000, // <-- Maximum batch size for Enhanced JQL API
    BatchSize = 100,   // <-- Batch size for Bulk Fetch API

    // =============================================================================
    // HELPER FUNCTIONS
    // =============================================================================
    FormatJiraDate = (DateString as text) =>
        if DateString = null or DateString = "" then
            ""
        else
            try
                DateTime.ToText(DateTime.From(DateString), "MM/dd/yyyy HH:mm:ss")
            otherwise
                DateString,

    // =============================================================================
    // PHASE 1: GET ALL ISSUE IDs USING ENHANCED JQL API
    // =============================================================================
    GetIssueIdsPage = (NextPageToken as text) =>
        let
            Endpoint = "/rest/api/3/search/jql",
            Payload = Json.FromValue([
                jql = JqlQuery,
                maxResults = MaxResults,
                nextPageToken = NextPageToken
            ]),
            FullUrl = BaseUrl & Endpoint,
            
            Response = Json.Document(Web.Contents(FullUrl, [
                Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"],
                Content=Payload
            ]))
        in
            Response,
    
    GetAllIssueIds = (NextPageToken as text, AccumulatedIds as list) =>
        let
            CurrentPage = GetIssueIdsPage(NextPageToken),
            CurrentIssues = if CurrentPage[issues] <> null then CurrentPage[issues] else {},
            CurrentIds = List.Transform(CurrentIssues, each Record.Field(_, "id")),
            NewAccumulatedIds = List.Combine({AccumulatedIds, CurrentIds}),
            HasNextPage = Record.HasFields(CurrentPage, "nextPageToken"),
            NextToken = if HasNextPage then Record.Field(CurrentPage, "nextPageToken") else null,
            Result = if NextToken = null then NewAccumulatedIds else GetAllIssueIds(NextToken, NewAccumulatedIds)
        in
            Result,

    AllIssueIds = GetAllIssueIds(null, {}),

    // =============================================================================
    // PHASE 2: GET ISSUE DETAILS USING BULK FETCH API
    // =============================================================================
    GetBulkIssueDetails = (IssueIds as list) =>
        let
            Endpoint = "/rest/api/3/issue/bulkfetch",
            Payload = Json.FromValue([
                fields = Text.Split(Fields, ","),
                issueIdsOrKeys = IssueIds
            ]),
            FullUrl = BaseUrl & Endpoint,
            
            Response = Json.Document(Web.Contents(FullUrl, [
                Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"],
                Content=Payload
            ]))
        in
            Response,

    // Split issue IDs into batches and get details for each batch
    SplitIntoBatches = (List as list, BatchSize as number) =>
        let
            BatchCount = Number.RoundUp(List.Count(List) / BatchSize),
            Batches = List.Generate(
                () => 0,
                each _ < BatchCount,
                each _ + 1,
                each List.Range(List, _ * BatchSize, BatchSize)
            )
        in
            Batches,

    Batches = SplitIntoBatches(AllIssueIds, BatchSize),
    BulkResponses = List.Transform(Batches, each GetBulkIssueDetails(_)),
    AllIssueDetails = List.Combine(List.Transform(BulkResponses, each if _[issues] <> null then _[issues] else {})),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllIssueDetails, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "fields"},
        {"Id", "Key", "Fields"}
    ),
    #"Expanded Fields" = Table.ExpandRecordColumn(#"Expanded Columns", "Fields", 
        {"summary", "status", "priority", "assignee", "reporter", "created", "updated", "resolutiondate", "project", "issuetype", "issuelinks"}, 
        {"Summary", "Status", "Priority", "Assignee", "Reporter", "Created", "Updated", "Resolved", "Project", "IssueType", "IssueLinks"}),
    
    // =============================================================================
    // EXTRACT LINKED ISSUES
    // =============================================================================
    #"Extract Linked Issues" = Table.AddColumn(#"Expanded Fields", "LinkedIssues", each 
        if [IssueLinks] <> null then
            let
                Links = [IssueLinks],
                OutwardIssues = List.Transform(Links, each try Record.Field(_, "outwardIssue") otherwise null),
                InwardIssues = List.Transform(Links, each try Record.Field(_, "inwardIssue") otherwise null),
                AllLinkedIssues = List.Combine({
                    List.Select(OutwardIssues, each _ <> null),
                    List.Select(InwardIssues, each _ <> null)
                }),
                LinkedKeys = List.Transform(AllLinkedIssues, each try Record.Field(_, "key") otherwise ""),
                LinkedStatuses = List.Transform(AllLinkedIssues, each try Record.Field(Record.Field(_, "fields"), "status") otherwise null),
                LinkedStatusNames = List.Transform(LinkedStatuses, each try Record.Field(_, "name") otherwise "Unknown"),
                LinkedIssuesText = Text.Combine(LinkedKeys, ";"),
                LinkedStatusesText = Text.Combine(LinkedStatusNames, ";")
            in
                [LinkedIssues = LinkedIssuesText, LinkedStatuses = LinkedStatusesText, LinkedIssueCount = List.Count(LinkedKeys)]
        else
            [LinkedIssues = "", LinkedStatuses = "", LinkedIssueCount = 0]
    ),
    
    #"Expanded Linked Issues" = Table.ExpandRecordColumn(#"Extract Linked Issues", "LinkedIssues", 
        {"LinkedIssues", "LinkedStatuses", "LinkedIssueCount"}, 
        {"LinkedIssues", "LinkedStatuses", "LinkedIssueCount"}),
    
    // =============================================================================
    // DATE FORMATTING
    // =============================================================================
    #"Formatted Created" = Table.TransformColumns(#"Expanded Linked Issues", {{"Created", FormatJiraDate}}),
    #"Formatted Updated" = Table.TransformColumns(#"Formatted Created", {{"Updated", FormatJiraDate}}),
    #"Formatted Resolved" = Table.TransformColumns(#"Formatted Updated", {{"Resolved", FormatJiraDate}}),

    // =============================================================================
    // CLEAN UP AND FINALIZE
    // =============================================================================
    #"Removed IssueLinks Column" = Table.RemoveColumns(#"Formatted Resolved", {"IssueLinks"}),
    #"Final Result" = #"Removed IssueLinks Column"
in
    #"Final Result"
