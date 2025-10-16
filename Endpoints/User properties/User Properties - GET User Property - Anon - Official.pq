// =============================================================================
// ENDPOINT: User Properties - GET User Property
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-user-properties/
//
// DESCRIPTION: Returns a specific user property using basic authentication.
// This endpoint provides access to a single user configuration property.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'AccountId' and 'PropertyKey' parameters
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
    PropertyKey = "custom.user.property", // <-- IMPORTANT: Replace with the property key you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/user/properties/" & PropertyKey,
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
    UserProperty = if Response[error] = null then
        let
            // Extract user property data
            PropertyData = [
                Key = Response[key],
                Value = Response[value],
                Self = Response[self]
            ],
            
            // Create structured result
            Result = [
                UserProperty = PropertyData,
                QueryParameters = [
                    AccountId = AccountId,
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
    Result = UserProperty
in
    Result

