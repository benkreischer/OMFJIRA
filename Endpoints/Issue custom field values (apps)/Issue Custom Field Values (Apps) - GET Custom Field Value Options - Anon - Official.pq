// =============================================================================
// ENDPOINT: Issue Custom Field Values (Apps) - GET Custom Field Value Options
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-values-apps/#api-rest-api-3-issue-issueidorkey-customfield-customfieldid-value-options-get
//
// DESCRIPTION: Returns the available options for a custom field.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'IssueIdOrKey' and 'CustomFieldId' parameters.
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
    CustomFieldId = "customfield_10000", // <-- IMPORTANT: Replace with the ID of the custom field
    StartAt = 0, // <-- OPTIONAL: The index of the first item to return (default: 0)
    , // <-- OPTIONAL: The maximum number of items to return (default: 50)

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueIdOrKey & "/customfield/" & CustomFieldId & "/value/options",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                StartAt = 0,
                MaxResults = 2147483647
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result


