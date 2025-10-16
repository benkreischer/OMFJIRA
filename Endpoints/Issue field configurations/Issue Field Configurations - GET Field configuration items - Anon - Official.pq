// =============================================================================
// ENDPOINT: Issue Field Configurations - GET Field configuration items
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-field-configurations/#api-rest-api-3-fieldconfiguration-id-fields-get
//
// DESCRIPTION: Returns a paginated list of all fields for a configuration.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ConfigurationId' parameter.
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // =============================================================================
    // PARAMETER
    // =============================================================================
    ConfigurationId = 10000, // <-- IMPORTANT: Replace with a valid Configuration ID

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/fieldconfiguration/" & Text.From(ConfigurationId) & "/fields",
            QueryString = Uri.BuildQueryString([StartAt = 0,
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],
            
            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllFields = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllFields, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "isHidden", "isRequired"},
        {"ID", "Name", "Description", "Is Hidden", "Is Required"}
    )
in
    #"Expanded Columns"


