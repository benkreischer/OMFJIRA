// =============================================================================
// ENDPOINT: App Data Policies - GET Get data policy for projects
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-data-policies/#api-rest-api-3-data-policy-project-get
//
// DESCRIPTION: Returns data policies for the projects specified in the request.
//
// ⚠️  IMPORTANT: This endpoint requires JIRA ADMINISTRATOR permissions
//    Ensure your credentials have admin access to retrieve data policies
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIds' parameter with a comma-separated list of project IDs
// 3. Ensure you have admin-level permissions in Jira
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
    // PARAMETER
    // =============================================================================
    ProjectIds = "10372,10122,10114", // <-- 🔴🔴🔴 IMPORTANT: Replace with a comma-separated list of numeric Project IDs from your Jira instance.

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/data-policy/project",
    QueryString = "?ids=" & ProjectIds,
    FullUrl = BaseUrl & Endpoint & QueryString,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Values = Response[projectDataPolicies],
    #"Converted to Table" = Table.FromList(Values, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "dataPolicy"}, 
        {"Project ID", "Data Policy"}
    ),
    #"Expanded Data Policy" = Table.ExpandRecordColumn(#"Expanded Columns", "Data Policy",
        {"anyContentBlocked"},
        {"Any Content Blocked"}
    )
in
    #"Expanded Data Policy"

