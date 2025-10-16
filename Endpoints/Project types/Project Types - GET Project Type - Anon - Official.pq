// =============================================================================
// ENDPOINT: Project Types - GET Project Type
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-types/
//
// DESCRIPTION: Returns a specific project type using basic authentication.
// This endpoint provides access to a single project type.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectTypeKey' parameter with the desired project type key
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
    ProjectTypeKey = "software", // <-- IMPORTANT: Replace with the project type key you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/project/type/" & ProjectTypeKey,
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
    ProjectType = if Response[error] = null then
        let
            // Extract project type data
            TypeData = [
                Key = Response[key],
                FormattedKey = Response[formattedKey],
                DescriptionI18nKey = Response[descriptionI18nKey],
                Icon = Response[icon],
                Color = Response[color]
            ],
            
            // Create structured result
            Result = [
                ProjectType = TypeData,
                QueryParameters = [
                    ProjectTypeKey = ProjectTypeKey
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
    Result = ProjectType
in
    Result

