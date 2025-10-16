// =============================================================================
// ENDPOINT: Issue Security Level - GET Security Level
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-security-level/#api-rest-api-3-issuesecurityschemes-id-get
//
// DESCRIPTION: Returns an issue security scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'SecuritySchemeId' parameter.
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
    SecuritySchemeId = "10000", // <-- IMPORTANT: Replace with the ID of the security scheme

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issuesecurityschemes/" & SecuritySchemeId,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

