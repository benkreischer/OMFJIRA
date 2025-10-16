// =============================================================================
// ENDPOINT: Priority Schemes - GET Priority Scheme Projects
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-priority-schemes/
//
// DESCRIPTION: Returns projects using a specific priority scheme using basic authentication.
// This endpoint provides access to projects associated with a priority scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'SchemeId' parameter
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
    SchemeId = "10000", // <-- IMPORTANT: Replace with the priority scheme ID
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/priorityschemes/" & SchemeId & "/project",
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
    PrioritySchemeProjects = if Response[error] = null then
        let
            // Extract priority scheme projects data
            ProjectsData = Response,
            
            // Create structured result
            Result = [
                PrioritySchemeProjects = ProjectsData,
                QueryParameters = [
                    SchemeId = SchemeId
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
    Result = PrioritySchemeProjects
in
    Result

