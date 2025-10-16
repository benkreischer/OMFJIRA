// =============================================================================
// ENDPOINT: Project Key and Name Validation - GET Validate Project Name
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-key-and-name-validation/
//
// DESCRIPTION: Validates a project name using basic authentication.
// This endpoint provides validation services for project names.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectName' parameter
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
    ProjectName = "OneMain Financial Project", // <-- IMPORTANT: Replace with the project name to validate
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/projectvalidate/validProjectName",
    FullUrl = BaseUrl & Endpoint,
    
    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ],
            Query = [
                name = ProjectName
            ]
        ])
    ),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Transform the response into a structured format
    ProjectNameValidation = if Response[error] = null then
        let
            // Extract project name validation data
            ValidationData = [
                Valid = Response[valid],
                Name = Response[name],
                Errors = Response[errors],
                Warnings = Response[warnings]
            ],
            
            // Create structured result
            Result = [
                ProjectNameValidation = ValidationData,
                QueryParameters = [
                    ProjectName = ProjectName
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
    Result = ProjectNameValidation
in
    Result

