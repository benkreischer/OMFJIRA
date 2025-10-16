// =============================================================================
// ENDPOINT: App Data Policies - GET Get data policy for the workspace
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-data-policies/#api-rest-api-3-data-policy-get
//
// DESCRIPTION: Returns data policy for the workspace.
//
// ⚠️  IMPORTANT: This endpoint requires JIRA ADMINISTRATOR permissions
//    Ensure your credentials have admin access to retrieve workspace data policies
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Ensure you have admin-level permissions in Jira
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
    Endpoint = "/rest/api/3/data-policy",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted Record to Table" = Record.ToTable(Response),
    #"Transposed Table" = Table.Transpose(#"Converted Record to Table"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true])
in
    #"Promoted Headers"


