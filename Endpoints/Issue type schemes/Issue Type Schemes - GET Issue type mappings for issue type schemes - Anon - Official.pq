// =============================================================================
// ENDPOINT: Issue Type Schemes - GET Issue type mappings for issue type schemes
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-type-schemes/#api-rest-api-3-issuetypescheme-mapping-get
//
// DESCRIPTION: Returns a paginated list of issue type scheme mappings.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Optionally, update the 'IssueTypeSchemeIds' parameter with a comma-separated list of issue type scheme IDs.
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
    // PARAMETER (Optional)
    // =============================================================================
    IssueTypeSchemeIds = "10000,10001", // <-- Replace with a comma-separated list of Issue Type Scheme IDs, or leave blank

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/issuetypescheme/mapping",
            QueryString = Uri.BuildQueryString([StartAt = 0, issueTypeSchemeId = IssueTypeSchemeIds]),
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,

            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],

            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllMappings = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllMappings, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"issueTypeSchemeId", "issueTypeId"},
        {"Issue Type Scheme ID", "Issue Type ID"}
    )
in
    #"Expanded Columns"


