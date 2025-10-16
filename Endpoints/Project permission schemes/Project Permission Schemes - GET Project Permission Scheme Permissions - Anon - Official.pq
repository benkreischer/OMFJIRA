// =============================================================================
// ENDPOINT: Project Permission Schemes - GET Project Permission Scheme Permissions
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-permission-schemes/#api-rest-api-3-project-projectidorkey-permissionscheme-permissions-get
//
// DESCRIPTION: Returns the permission scheme permissions for the project.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectIdOrKey' parameter.
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
    // PARAMETERS
    // =============================================================================
    ProjectIdOrKey = Get-CommonParameter("ProjectIdOrKey", Parameters),
