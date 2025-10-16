// =============================================================================
// ENDPOINT: Issue Types - GET Alternative issue types
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-types/#api-rest-api-3-issuetype-id-alternatives-get
//
// DESCRIPTION: Returns a list of issue types that can be used to replace an issue type.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'IssueTypeId' parameter with a valid issue type ID.
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
    IssueTypeId = "10000", // <-- IMPORTANT: Replace with a valid Issue Type ID

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issuetype/" & IssueTypeId & "/alternatives",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"id", "name", "description", "subtask", "avatarId", "hierarchyLevel"},
        {"ID", "Name", "Description", "Is Subtask", "Avatar ID", "Hierarchy Level"}
    )
in
    #"Expanded Columns"

