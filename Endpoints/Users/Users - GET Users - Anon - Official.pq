// =============================================================================
// ENDPOINT: Users - GET Users
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-users/#api-rest-api-3-users-search-get
//
// DESCRIPTION: Returns a list of users matching a search term.
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
    Query = "", // <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
    Username = "", // <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
    AccountId = "", // <-- OPTIONAL: A query string that is matched against user attributes to find relevant users
    Property = "", // <-- OPTIONAL: A query string used to search properties
    MaxResultsPerPage = 1000, // <-- Maximum results per API call (Jira limit)

    // =============================================================================
    // PAGINATED API CALLS
    // =============================================================================
    Endpoint = "/rest/api/3/users/search",
    FullUrl = BaseUrl & Endpoint,

    // Function to get users with pagination
    GetUsersPage = (startAt as number) as list =>
        let
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
                        startAt = Number.ToText(startAt),
                        maxResults = Number.ToText(MaxResultsPerPage),
                        property = Property
                    ]
                ])
            )
        in
            Response,

    // Get all users with pagination
    GetAllUsers = (startAt as number, allUsers as list) as list =>
        let
            CurrentPage = GetUsersPage(startAt),
            CurrentPageCount = List.Count(CurrentPage),
            UpdatedUsers = List.Combine({allUsers, CurrentPage}),
            NextStartAt = startAt + MaxResultsPerPage,
            Result = if CurrentPageCount < MaxResultsPerPage then UpdatedUsers else GetAllUsers(NextStartAt, UpdatedUsers)
        in
            Result,

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    AllUsers = GetAllUsers(0, {}),
    Result = AllUsers
in
    Result


