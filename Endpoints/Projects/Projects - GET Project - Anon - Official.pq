// =============================================================================
// ENDPOINT: Projects - Get Project
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-get
//
// DESCRIPTION: Returns the details for a project.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIdOrKey' parameter below.
//
// =============================================================================

let
    // Load configuration parameters
    Parameters = Load-EndpointParameters(),
    
    // =============================================================================
    // API Configuration from parameters
    // =============================================================================
    BaseUrl = Parameters[BaseUrl],
    AuthHeader = Get-AuthHeader(Parameters),
    ProjectIdOrKey = Get-CommonParameter("ProjectIdOrKey", Parameters),

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/project/" & ProjectIdOrKey,
    QueryString = Get-QueryString([expand = Parameters[DefaultExpand]], Parameters),
    FullUrl = BaseUrl & Endpoint & QueryString,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromRecords({Response}),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"self", "id", "key", "name", "projectTypeKey", "simplified", "style", "isPrivate", "lead", "description", "issueTypes", "url", "projectKeys", "insight"}, 
        {"self", "id", "key", "name", "projectTypeKey", "simplified", "style", "isPrivate", "lead", "description", "issueTypes", "url", "projectKeys", "insight"}
    )
in
    #"Expanded Columns"
