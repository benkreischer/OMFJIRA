// =============================================================================
// ENDPOINT: Issue Type Schemes - GET Issue type scheme for projects
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-type-schemes/#api-rest-api-3-issuetypescheme-project-get
//
// DESCRIPTION: Returns a paginated list of issue type schemes for projects.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIds' parameter with a comma-separated list of project IDs.
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
    // PARAMETER
    // =============================================================================
    ProjectIds = "10000,10001", // <-- IMPORTANT: Replace with a comma-separated list of Project IDs

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/issuetypescheme/project",
            QueryString = Uri.BuildQueryString([StartAt = 0, projectId = ProjectIds]),
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,

            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],

            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllSchemes = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllSchemes, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"issueTypeScheme", "projectIds"},
        {"Issue Type Scheme", "Project IDs"}
    ),
    #"Expanded Scheme" = Table.ExpandRecordColumn(#"Expanded Columns", "Issue Type Scheme",
        {"id", "name", "description", "isDefault"},
        {"Scheme ID", "Scheme Name", "Scheme Description", "Is Default"}
    )
in
    #"Expanded Scheme"


