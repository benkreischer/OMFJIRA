// =============================================================================
// ENDPOINT: Dashboards - GET Available Gadgets
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-gadgets-get
//
// DESCRIPTION: Gets a list of all available gadgets that can be added to a dashboard.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
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

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/dashboard/gadgets",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Gadgets = Response[gadgets],
    #"Converted to Table" = Table.FromList(Gadgets, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"title", "moduleKey", "uri"},
        {"Title", "Module Key", "URI"}
    )
in
    #"Expanded Columns"

