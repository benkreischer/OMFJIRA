// =============================================================================
// ENDPOINT: Issue Custom Field Configuration (Apps) - GET Custom Field Configuration
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-configuration-apps/#api-rest-api-3-issue-issueidorkey-customfield-customfieldid-configuration-get
//
// DESCRIPTION: Returns the configuration for a custom field.
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

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueIdOrKey & "/customfield/" & CustomFieldId & "/configuration",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

