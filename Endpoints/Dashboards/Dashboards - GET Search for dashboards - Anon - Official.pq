// =============================================================================
// ENDPOINT: Dashboards - GET Search for dashboards
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-dashboards/#api-rest-api-3-dashboard-search-get
//
// DESCRIPTION: Returns a paginated list of dashboards matching the search criteria.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Optionally, adjust the parameters to filter the search results.
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
    // PARAMETERS (Optional)
    // =============================================================================
    DashboardName = "", // Text to search in the dashboard name
    GroupName = "", // Name of a group to filter by
    ProjectId = "", // ID of a project to filter by
    OrderBy = "name", // "-name", "+name", "name", "-favorite_count", "+favorite_count", "favorite_count"
    Expand = "description,owner,sharePermissions",

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    MaxResults = 50,
    
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/dashboard/search",
            QueryString = Uri.BuildQueryString([
                dashboardName = DashboardName,
                groupname = GroupName,
                projectId = ProjectId,
                orderBy = OrderBy,
                startAt = Number.ToText(StartAt),
                maxResults = Number.ToText(MaxResults),
                expand = Expand
            ]),
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],
            
            // Check if there are more records to fetch
            IsLast = try Response[isLast] otherwise (List.Count(Values) < MaxResults),
            NextStartAt = StartAt + List.Count(Values),
            
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllDashboards = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllDashboards, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "owner", "sharePermissions"},
        {"ID", "Name", "Description", "Owner", "Share Permissions"}
    ),
    #"Expanded Owner" = Table.ExpandRecordColumn(#"Expanded Columns", "Owner", {"displayName"}, {"Owner Name"})
in
    #"Expanded Owner"


