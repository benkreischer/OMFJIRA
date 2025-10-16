// =============================================================================
// ENDPOINT: Issues - GET Issue Edit Meta
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-editmeta-get
//
// DESCRIPTION: Returns the edit screen fields for an issue that are visible to and editable by the user.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'IssueIdOrKey' parameter.
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
    IssueIdOrKey = "ORL-8004", // <-- IMPORTANT: Replace with the ID or key of the issue
    OverrideScreenSecurity = "false", // <-- OPTIONAL: Whether to override screen security
    OverrideEditableFlag = "false", // <-- OPTIONAL: Whether to override editable flag

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueIdOrKey & "/editmeta",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                overrideScreenSecurity = OverrideScreenSecurity,
                overrideEditableFlag = OverrideEditableFlag
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

