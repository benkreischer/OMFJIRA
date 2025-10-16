// =============================================================================
// ENHANCED LABELS WITH ISSUE CONTEXT - USING WORKING ENHANCED JQL API
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-labels/#api-rest-api-3-label-get
//
// DESCRIPTION: Returns all labels with issue context using Enhanced JQL API approach.
// Based on the working Issue Search Enhanced JQL API implementation.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
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
    // GET ALL LABELS
    // =============================================================================
    GetAllLabels = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/label",
            QueryString = Uri.BuildQueryString([startAt = StartAt, maxResults = 1000]),
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,

            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],

            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = StartAt + List.Count(Values),
            Result = if IsLast = false then Values & @GetAllLabels(NextStartAt) else Values
        in
            Result,

    AllLabels = GetAllLabels(0),

    // =============================================================================
    // FOR EACH LABEL, GET ISSUE CONTEXT USING ENHANCED JQL API
    // =============================================================================
    GetLabelWithIssueContext = (Label as text) =>
        let
            // Search for issues with this label using Enhanced JQL API
            JqlQuery = "labels = '" & Label & "' ORDER BY created DESC, id ASC",
            SearchUrl = BaseUrl & "/rest/api/3/search/jql",
            SearchPayload = [
                jql = JqlQuery,
                maxResults = 5000
            ],
            SearchJsonPayload = Json.FromValue(SearchPayload),
            
            SearchResponse = Json.Document(Web.Contents(SearchUrl, [
                Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"],
                Content=SearchJsonPayload
            ])),
            
            IssueIds = if SearchResponse[issues] <> null then 
                List.Transform(SearchResponse[issues], each [id]) 
            else 
                {},
            
            IssueCount = List.Count(IssueIds),
            
            // Get issue details using Bulk Fetch API if issues found
            IssueKeys = if IssueCount > 0 then
                let
                    BulkFetchUrl = BaseUrl & "/rest/api/3/issue/bulkfetch",
                    BulkPayload = [
                        fields = {"summary", "status", "priority", "assignee", "reporter", "created", "updated", "project", "issuetype"},
                        issueIdsOrKeys = IssueIds
                    ],
                    BulkJsonPayload = Json.FromValue(BulkPayload),
                    BulkResponse = Json.Document(Web.Contents(BulkFetchUrl, [
                        Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"],
                        Content=BulkJsonPayload
                    ])),
                    Keys = if BulkResponse[issues] <> null then 
                        List.Transform(BulkResponse[issues], each [key])
                    else 
                        {}
                in
                    Text.Combine(Keys, "; ")
            else
                "",
            
            Result = [
                Label = Label,
                IssueCount = IssueCount,
                IssueKeys = IssueKeys,
                GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
            ]
        in
            Result,

    // =============================================================================
    // PROCESS ALL LABELS
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllLabels, Splitter.SplitByNothing(), {"Label"}, null, ExtraValues.Error),
    #"Added Issue Context" = Table.AddColumn(#"Converted to Table", "IssueContext", each GetLabelWithIssueContext([Label])),
    #"Expanded Issue Context" = Table.ExpandRecordColumn(#"Added Issue Context", "IssueContext", {"IssueCount", "IssueKeys", "GeneratedAt"}, {"IssueCount", "IssueKeys", "GeneratedAt"})
in
    #"Expanded Issue Context"

