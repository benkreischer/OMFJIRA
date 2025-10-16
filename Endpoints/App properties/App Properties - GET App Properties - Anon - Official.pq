// =============================================================================
// ENDPOINT: App Properties - GET Application Properties
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-properties/
//
// DESCRIPTION: Returns application properties using basic authentication.
// This endpoint provides access to application-level configuration properties.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'PropertyKey' parameter with the desired property key
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
    PropertyKey = "jira.lf.time.tracking", // <-- OPTIONAL: Property key to retrieve (default: jira.lf.time.tracking)
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/application-properties",
    FullUrl = BaseUrl & Endpoint,
    
    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ],
            Query = [
                key = PropertyKey
            ]
        ])
    ),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Transform the response into a structured format
    ApplicationProperties = if Response[error] = null then
        let
            // Extract properties data
            PropertiesData = Response,
            
            // Create structured result
            Result = [
                Properties = PropertiesData,
                QueryParameters = [
                    PropertyKey = PropertyKey
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
    Result = ApplicationProperties
in
    Result

