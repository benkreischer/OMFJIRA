// =============================================================================
// ENDPOINT: Issue Comment Properties - GET Comment property
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comment-properties/#api-rest-api-3-comment-commentid-properties-propertykey-get
//
// DESCRIPTION: Returns the value of a comment property.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'CommentId' and 'PropertyKey' parameters.
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
    CommentId = "10000", // <-- IMPORTANT: Replace with a valid Comment ID
    PropertyKey = "custom.property", // <-- IMPORTANT: Replace with the key of the property to get

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/comment/" & CommentId & "/properties/" & PropertyKey,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Record.ToTable(Response),
    #"Transposed Table" = Table.Transpose(#"Converted to Table"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true])
in
    #"Promoted Headers"

