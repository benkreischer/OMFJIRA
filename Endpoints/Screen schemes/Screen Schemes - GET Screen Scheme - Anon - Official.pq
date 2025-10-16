// =============================================================================
// ENDPOINT: Screen Schemes - GET Screen Scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screen-schemes/
//
// DESCRIPTION: Returns a specific screen scheme using basic authentication.
// This endpoint provides access to a single screen configuration scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ScreenSchemeId' parameter with the desired screen scheme ID
// 3. Load the data
//
// =============================================================================

let
    // =============================================================================
    // CONFIGURATION SECTION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // =============================================================================
    // PARAMETERS
    // =============================================================================
    ScreenSchemeId = "10003", // <-- Using MOB: Scrum Default Screen Scheme ID from the working data
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/screenscheme/" & ScreenSchemeId,
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
    // Transform the response into a structured format
    ScreenScheme = if Response[error] = null then
        let
            // Extract screen scheme data
            SchemeData = [
                Id = Response[id],
                Name = Response[name],
                Description = Response[description],
                Screens = Response[screens]
            ],
            
            // Create structured result
            Result = [
                ScreenScheme = SchemeData,
                QueryParameters = [
                    ScreenSchemeId = ScreenSchemeId
                ],
                GeneratedAt = DateTimeZone.ToText(DateTimeZone.UtcNow())
            ]
        in
            Result
    else
        [
            Error = Response[error],
            ErrorDescription = Response[error_description],
            Timestamp = DateTimeZone.ToText(DateTimeZone.UtcNow())
        ],
    
    // =============================================================================
    // RESULT
    // =============================================================================
    Result = ScreenScheme
in
    Result

