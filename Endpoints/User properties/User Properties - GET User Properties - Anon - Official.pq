// =============================================================================
// ENDPOINT: User Properties - GET User Properties
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-user-properties/
//
// DESCRIPTION: Returns user properties using basic authentication.
// This endpoint provides access to user configuration properties.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'AccountId' parameter
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
    AccountId = "5b10a2844c20165700ede21g", // <-- IMPORTANT: Replace with the user account ID
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/user/properties",
    FullUrl = BaseUrl & Endpoint,
    
    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ],
            Query = [
                accountId = AccountId
            ]
        ])
    ),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Transform the response into a structured format
    UserProperties = if Response[error] = null then
        let
            // Extract user properties data
            PropertiesData = Response,
            
            // Create structured result
            Result = [
                UserProperties = PropertiesData,
                QueryParameters = [
                    AccountId = AccountId
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
    Result = UserProperties
in
    Result

