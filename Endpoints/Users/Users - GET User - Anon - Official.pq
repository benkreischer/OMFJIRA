// =============================================================================
// ENDPOINT: Users - GET User
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-user-get
//
// DESCRIPTION: Returns a user.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'AccountId' parameter.
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
    AccountId = "5b10a2844c20165700ede21g", // <-- IMPORTANT: Replace with the account ID of the user
    Expand = "groups,applicationRoles", // <-- OPTIONAL: Use expand to include additional information

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/user",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                accountId = AccountId,
                expand = Expand
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

