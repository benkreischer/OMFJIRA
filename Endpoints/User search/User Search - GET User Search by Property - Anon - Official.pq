// =============================================================================
// ENDPOINT: User Search - GET User Search by Property
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-user-search/#api-rest-api-3-user-search-property-get
//
// DESCRIPTION: Returns a list of users that match the search string and property.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'PropertyKey' and 'Query' parameters.
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
    PropertyKey = "email", // <-- IMPORTANT: Replace with the property key
    Query = "john", // <-- IMPORTANT: Replace with the search string
    StartAt = 0, // <-- OPTIONAL: The index of the first item to return (default: 0)
    , // <-- OPTIONAL: The maximum number of items to return (default: 50)

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/user/search/property",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                propertyKey = PropertyKey,
                query = Query,
                StartAt = 0,
                MaxResults = 2147483647
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result


