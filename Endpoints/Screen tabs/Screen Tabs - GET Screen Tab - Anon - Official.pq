// =============================================================================
// ENDPOINT: Screen Tabs - GET Screen Tab
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screen-tabs/
//
// DESCRIPTION: Returns a specific screen tab using basic authentication.
// This endpoint provides access to a single screen tab.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ScreenId' and 'TabId' parameters
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
    ScreenId = "10000", // <-- IMPORTANT: Replace with the screen ID
    TabId = "10000", // <-- IMPORTANT: Replace with the tab ID
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/screens/" & ScreenId & "/tabs/" & TabId,
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
    ScreenTab = if Response[error] = null then
        let
            // Extract screen tab data
            TabData = [
                Id = Response[id],
                Name = Response[name],
                Fields = Response[fields]
            ],
            
            // Create structured result
            Result = [
                ScreenTab = TabData,
                QueryParameters = [
                    ScreenId = ScreenId,
                    TabId = TabId
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
    Result = ScreenTab
in
    Result

