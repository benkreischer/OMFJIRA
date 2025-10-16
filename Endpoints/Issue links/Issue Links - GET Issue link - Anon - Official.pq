// =-============================================================================
// ENDPOINT: Issue Links - GET Issue link
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-links/#api-rest-api-3-issuelink-linkid-get
//
// DESCRIPTION: Returns an issue link.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'LinkId' parameter with a valid issue link ID.
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
    LinkId = "10000", // <-- IMPORTANT: Replace with a valid Issue Link ID

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issueLink/" & LinkId,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Record.ToTable(Response),
    #"Transposed Table" = Table.Transpose(#"Converted to Table"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true])
in
    #"Promoted Headers"

