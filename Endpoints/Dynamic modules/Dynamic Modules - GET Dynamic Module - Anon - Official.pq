// =============================================================================
// ENDPOINT: Dynamic Modules - GET Dynamic Module
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dynamic-modules/
//
// DESCRIPTION: Returns a specific dynamic module using basic authentication.
// This endpoint provides access to a single dynamic module.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ModuleKey' parameter with the desired module key
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
    ModuleKey = "com.atlassian.jira.plugin.system.customfieldtypes:textsearcher", // <-- IMPORTANT: Replace with the module key you want to retrieve
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/dynamic-modules/" & ModuleKey,
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
    DynamicModule = if Response[error] = null then
        let
            // Extract dynamic module data
            ModuleData = [
                Key = Response[key],
                Name = Response[name],
                Description = Response[description],
                Type = Response[type],
                Version = Response[version],
                Status = Response[status]
            ],
            
            // Create structured result
            Result = [
                DynamicModule = ModuleData,
                QueryParameters = [
                    ModuleKey = ModuleKey
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
    Result = DynamicModule
in
    Result

