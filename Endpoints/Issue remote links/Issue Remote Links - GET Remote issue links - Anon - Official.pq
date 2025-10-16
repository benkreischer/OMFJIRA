// =============================================================================
// ENDPOINT: Issue Remote Links - GET Remote issue links
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-remote-links/#api-rest-api-3-issue-issueidorkey-remotelink-get
//
// DESCRIPTION: Returns the remote issue links for an issue.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'IssueIdOrKey' parameter with a valid issue ID or key.
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
    IssueIdOrKey = "ORL-8004", // <-- IMPORTANT: Replace with a valid Issue ID or Key

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueIdOrKey & "/remotelink",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"id", "globalId", "application", "relationship", "object"},
        {"ID", "Global ID", "Application", "Relationship", "Object"}
    ),
    #"Expanded Object" = Table.ExpandRecordColumn(#"Expanded Columns", "Object",
        {"url", "title", "summary", "icon", "status"},
        {"URL", "Title", "Summary", "Icon", "Status"}
    )
in
    #"Expanded Object"

