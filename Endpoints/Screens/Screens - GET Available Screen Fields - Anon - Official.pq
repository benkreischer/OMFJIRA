// =============================================================================
// ENDPOINT: Screens - GET Available Screen Fields
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
//
// DESCRIPTION: Returns fields available for screens using basic authentication.
// This endpoint provides access to available screen field management.
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
    // PARAMETERS
    // =============================================================================
    ScreenId = "1", // <-- IMPORTANT: Replace with the screen ID you want to query
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/screens/" & ScreenId & "/availableFields",
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
    Fields = if Response[error] = null and Response <> null then
        let
            // Extract fields data (response is an array, not paginated)
            FieldsData = Response,
            
            // Convert to table
            FieldsTable = Table.FromList(FieldsData, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            
            // Expand field records
            ExpandedFields = Table.ExpandRecordColumn(FieldsTable, "Column1", 
                {"id", "name"}, 
                {"FieldId", "FieldName"}),
            
            // Add screen ID and generated timestamp
            WithScreenId = Table.AddColumn(ExpandedFields, "ScreenId", each ScreenId),
            FinalTable = Table.AddColumn(WithScreenId, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss"))
        in
            FinalTable
    else
        #table({"ScreenId", "FieldId", "FieldName", "GeneratedAt"}, {})
    
    // =============================================================================
    // RESULT
    // =============================================================================
    Result = Fields
in
    Result

