// =============================================================================
// ENDPOINT: Application Roles - GET Application Role
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-application-roles/#api-rest-api-3-applicationrole-key-get
//
// DESCRIPTION: Returns an application role.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ApplicationRoleKey' parameter.
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
    ApplicationRoleKey = "jira-administrators", // <-- IMPORTANT: Replace with the key of the application role

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/applicationrole/" & ApplicationRoleKey,
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

