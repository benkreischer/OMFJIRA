// =============================================================================
// ENDPOINT: Issue Comment Properties - GET Comment property keys
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comment-properties/#api-rest-api-3-comment-commentid-properties-get
//
// DESCRIPTION: Returns the keys of all properties for a comment.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'CommentId' parameter with a valid comment ID.
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
    CommentId = "326710", // <-- Valid Comment ID from our tracking document

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/comment/" & CommentId & "/properties",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response[keys], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"key", "self"},
        {"Property Key", "API URL"}
    )
in
    #"Expanded Columns"

