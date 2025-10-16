// =============================================================================
// ENDPOINT: Classification Levels - GET Classification Level
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-classification-levels/
//
// DESCRIPTION: Returns a specific classification level using basic authentication.
// This endpoint provides access to a single data classification level.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ClassificationLevelId' parameter with the desired classification level ID
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
    ClassificationLevelId = "10000", // <-- IMPORTANT: Replace with the classification level ID you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/classification-levels/" & ClassificationLevelId,
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
    ClassificationLevel = if Response[error] = null then
        let
            // Extract classification level data
            LevelData = [
                Id = Response[id],
                Name = Response[name],
                Description = Response[description],
                Color = Response[color],
                Icon = Response[icon],
                Order = Response[order]
            ],
            
            // Create structured result
            Result = [
                ClassificationLevel = LevelData,
                QueryParameters = [
                    ClassificationLevelId = ClassificationLevelId
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
    Result = ClassificationLevel
in
    Result

