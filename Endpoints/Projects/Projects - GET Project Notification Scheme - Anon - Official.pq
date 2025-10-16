// =============================================================================
// ENDPOINT: Projects - Get Project Notification Scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-notificationscheme-get
//
// DESCRIPTION: Gets the notification scheme associated with a project.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIdOrKey' parameter below.
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
    // PARAMETER - REQUIRED
    // =============================================================================
    ProjectIdOrKey = if Parameters[CommonParameters][ProjectIdOrKey]? <> null then Parameters[CommonParameters][ProjectIdOrKey] else "DEVEX",
