// =============================================================================
// ENDPOINT: Permission Schemes - GET Permission Scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-permission-schemes/#api-rest-api-3-permissionscheme-id-get
//
// DESCRIPTION: Returns a permission scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'PermissionSchemeId' parameter.
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
    PermissionSchemeId = "10000", // <-- IMPORTANT: Replace with the ID of the permission scheme
    Expand = "all", // <-- OPTIONAL: Use expand to include additional information

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/permissionscheme/" & PermissionSchemeId,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                expand = Expand
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

