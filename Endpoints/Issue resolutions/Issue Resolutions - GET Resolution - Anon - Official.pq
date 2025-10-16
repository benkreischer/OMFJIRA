// =============================================================================
// ENDPOINT: Issue Resolutions - GET Resolution
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-resolutions/#api-rest-api-3-resolution-id-get
//
// DESCRIPTION: Returns an issue resolution.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ResolutionId' parameter with a valid issue resolution ID.
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
    ResolutionId = "10000", // <-- IMPORTANT: Replace with a valid Issue Resolution ID

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/resolution/" & ResolutionId,
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

