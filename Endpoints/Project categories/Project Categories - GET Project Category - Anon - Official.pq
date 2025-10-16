// =============================================================================
// ENDPOINT: Project Categories - GET Project Category
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-categories/
//
// DESCRIPTION: Returns a specific project category using basic authentication.
// This endpoint provides access to a single project category.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'CategoryId' parameter with the desired category ID
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
    CategoryId = "10000", // <-- IMPORTANT: Replace with the category ID you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/projectCategory/" & CategoryId,
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
    ProjectCategory = if Response[error] = null then
        let
            // Extract project category data
            CategoryData = [
                Id = Response[id],
                Name = Response[name],
                Description = Response[description],
                Self = Response[self]
            ],
            
            // Create structured result
            Result = [
                ProjectCategory = CategoryData,
                QueryParameters = [
                    CategoryId = CategoryId
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
    Result = ProjectCategory
in
    Result

