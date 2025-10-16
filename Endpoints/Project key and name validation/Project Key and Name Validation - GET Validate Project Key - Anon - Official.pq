// =============================================================================
// ENDPOINT: Project Key and Name Validation - GET Validate Project Key
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-key-and-name-validation/
//
// DESCRIPTION: Validates a project key using basic authentication.
// This endpoint provides validation services for project keys.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectKey' parameter
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
    ProjectKey = "ORL", // <-- IMPORTANT: Replace with the project key to validate
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/projectvalidate/key",
    FullUrl = BaseUrl & Endpoint,
    
    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ],
            Query = [
                key = ProjectKey
            ]
        ])
    ),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Transform the response into a structured format
    ProjectKeyValidation = if Response[error] = null then
        let
            // Extract project key validation data
            ValidationData = [
                Valid = Response[valid],
                Key = Response[key],
                Errors = Response[errors],
                Warnings = Response[warnings]
            ],
            
            // Create structured result
            Result = [
                ProjectKeyValidation = ValidationData,
                QueryParameters = [
                    ProjectKey = ProjectKey
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
    Result = ProjectKeyValidation
in
    Result

