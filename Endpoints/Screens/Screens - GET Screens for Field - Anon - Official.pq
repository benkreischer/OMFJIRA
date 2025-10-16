// =============================================================================
// ENDPOINT: Screens - GET Screens for Field
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
//
// DESCRIPTION: Returns screens associated with a specific field using basic authentication.
// This endpoint provides access to field-screen associations.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'FieldId' parameter with a valid field ID
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
    FieldId = "summary", // <-- IMPORTANT: Replace with the field ID you want to query
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/field/" & FieldId & "/screens",
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
    Screens = if Response[error] = null and Response[values] <> null then
        let
            // Extract screens data
            ScreensData = Response[values],
            
            // Convert to table
            ScreensTable = Table.FromList(ScreensData, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            
            // Expand screen records
            ExpandedScreens = Table.ExpandRecordColumn(ScreensTable, "Column1", 
                {"id", "name", "description"}, 
                {"ScreenId", "ScreenName", "ScreenDescription"}),
            
            // Add field ID and generated timestamp
            WithFieldId = Table.AddColumn(ExpandedScreens, "FieldId", each FieldId),
            FinalTable = Table.AddColumn(WithFieldId, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss"))
        in
            FinalTable
    else
        #table({"FieldId", "ScreenId", "ScreenName", "ScreenDescription", "GeneratedAt"}, {})
    
    // =============================================================================
    // RESULT
    // =============================================================================
    Result = Screens
in
    Result

