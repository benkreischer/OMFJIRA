// =============================================================================
// ENDPOINT: Dashboards - GET All Dashboards
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-get
//
// DESCRIPTION: Returns a paginated list of dashboards.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Optionally, adjust the 'Filter' parameter. Valid values are "my", "favourite".
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
    // PARAMETER (Optional)
    // =============================================================================
    Filter = "", // "my", "favourite", or "" (for all)

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/dashboard",
            QueryString = Uri.BuildQueryString([
                filter = Filter,
                StartAt = 0,
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[dashboards],
            
            // Check if there are more records to fetch
            IsLast = try Response[isLast] otherwise true, // The 'isLast' property is not always present
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllDashboards = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllDashboards, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "owner", "sharePermissions", "editPermissions"},
        {"ID", "Name", "Owner", "Share Permissions", "Edit Permissions"}
    ),
    #"Expanded Owner" = Table.ExpandRecordColumn(#"Expanded Columns", "Owner", {"displayName"}, {"Owner Name"})
in
    #"Expanded Owner"


