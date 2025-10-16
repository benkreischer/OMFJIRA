// =============================================================================
// ENDPOINT: Project Types - GET Project Types
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-types/
//
// DESCRIPTION: Returns project types using basic authentication.
// This endpoint provides access to available project types.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Load the data
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
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/project/type",
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
    ProjectTypes = if Response[error] = null then
        let
            // Extract project types data
            TypesData = Response,
            
            // Create structured result
            Result = [
                ProjectTypes = TypesData,
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
    Result = ProjectTypes
in
    Result

