// =============================================================================
// ENDPOINT: Avatars - GET System Avatars by Type
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-avatars/#api-rest-api-3-avatar-type-system-get
//
// DESCRIPTION: Returns a list of system avatars of a given type.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'AvatarType' parameter. Valid values are "project" or "user".
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
    // PARAMETER
    // =============================================================================
    AvatarType = "project", // <-- IMPORTANT: Replace with a valid avatar type: "project" or "user"

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/avatar/" & AvatarType & "/system",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Avatars = Response[system],
    #"Converted to Table" = Table.FromList(Avatars, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "isSystemAvatar", "isSelected", "isDeletable", "urls"},
        {"ID", "Is System Avatar", "Is Selected", "Is Deletable", "URLs"}
    ),
    #"Expanded URLs" = Table.ExpandRecordColumn(#"Expanded Columns", "URLs", 
        {"16x16", "24x24", "32x32", "48x48"},
        {"URL 16x16", "URL 24x24", "URL 32x32", "URL 48x48"}
    )
in
    #"Expanded URLs"

