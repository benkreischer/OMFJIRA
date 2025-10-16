// =============================================================================
// ENDPOINT: Project Templates - GET Project Template
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-templates/
//
// DESCRIPTION: Returns a specific project template using basic authentication.
// This endpoint provides access to a single project template.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'TemplateKey' parameter with the desired template key
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
    TemplateKey = "com.pyxis.greenhopper.jira:gh-simplified-scrum-classic", // <-- IMPORTANT: Replace with the template key you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/project-template/" & TemplateKey,
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
    ProjectTemplate = if Response[error] = null then
        let
            // Extract project template data
            TemplateData = [
                Id = Response[id],
                Key = Response[key],
                Name = Response[name],
                Description = Response[description],
                ProjectTypeKey = Response[projectTypeKey],
                Lead = Response[lead],
                LeadAccountId = Response[leadAccountId],
                AssigneeType = Response[assigneeType],
                AvatarUrls = Response[avatarUrls],
                ProjectKeys = Response[projectKeys],
                ProjectCategory = Response[projectCategory],
                ProjectConfiguration = Response[projectConfiguration]
            ],
            
            // Create structured result
            Result = [
                ProjectTemplate = TemplateData,
                QueryParameters = [
                    TemplateKey = TemplateKey
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
    Result = ProjectTemplate
in
    Result

