// =============================================================================
// ENDPOINT: Issue Notification Schemes - GET Notification scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-notification-schemes/#api-rest-api-3-notificationscheme-id-get
//
// DESCRIPTION: Returns a notification scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'SchemeId' parameter.
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
    SchemeId = "10000", // <-- IMPORTANT: Replace with a valid Scheme ID

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/notificationscheme/" & SchemeId,
    QueryString = Uri.BuildQueryString([expand = "all"]),
    FullUrl = BaseUrl & Endpoint & "?" & QueryString,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Record.ToTable(Response),
    #"Transposed Table" = Table.Transpose(#"Converted to Table"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true])
in
    #"Promoted Headers"

