// =============================================================================
// ENDPOINT: Issue Resolutions - GET Resolutions
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-resolutions/#api-rest-api-3-resolution-get
//
// DESCRIPTION: Returns a list of all issue resolutions.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
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
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/resolution",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"id", "name", "description"},
        {"ID", "Name", "Description"}
    )
in
    #"Expanded Columns"

