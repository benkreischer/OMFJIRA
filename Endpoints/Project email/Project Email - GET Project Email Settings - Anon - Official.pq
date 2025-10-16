// =============================================================================
// ENDPOINT: Project Email - GET Project Email Settings
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-email/
//
// DESCRIPTION: Returns project email settings using basic authentication.
// This endpoint provides access to project email integration settings.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIdOrKey' parameter with "ORL" for project key
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
    ProjectIdOrKey = Get-CommonParameter("ProjectIdOrKey", Parameters),
