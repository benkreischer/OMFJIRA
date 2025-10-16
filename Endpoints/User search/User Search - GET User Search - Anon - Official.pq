// =============================================================================
// ENDPOINT: User Search - GET User Search
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-user-search/#api-rest-api-3-user-search-get
//
// DESCRIPTION: Returns a list of users that match the search string.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'Query' parameter.
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
    Query = "john", // <-- IMPORTANT: Replace with the search string
    Username = "", // <-- OPTIONAL: A query string that is matched against user attributes
    AccountId = "", // <-- OPTIONAL: A query string that is matched against user attributes
    StartAt = 0, // <-- OPTIONAL: The index of the first item to return (default: 0)
    , // <-- OPTIONAL: The maximum number of items to return (default: 50)
    Property = "", // <-- OPTIONAL: A query string used to search properties

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/user/search",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                query = Query,
                username = Username,
                accountId = AccountId,
                StartAt = 0,
                MaxResults = 2147483647,
                property = Property
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result


