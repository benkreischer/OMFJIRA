// =============================================================================
// ENDPOINT: Dashboards - GET Dashboard item property
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-dashboardid-item-itemid-properties-get
//
// DESCRIPTION: Returns the keys of all properties for a dashboard item.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'DashboardId' and 'ItemId' parameters.
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
    // PARAMETERS
    // =============================================================================
    DashboardId = "10000", // <-- IMPORTANT: Replace with a valid Dashboard ID
    ItemId = "10001", // <-- IMPORTANT: Replace with a valid Dashboard Item (gadget) ID

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/dashboard/" & DashboardId & "/item/" & ItemId & "/properties",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response[keys], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"key", "self"},
        {"Property Key", "API URL"}
    )
in
    #"Expanded Columns"

