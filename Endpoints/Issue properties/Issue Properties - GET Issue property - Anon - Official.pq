// =============================================================================
// ENDPOINT: Issue Properties - GET Issue property
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-properties/#api-rest-api-3-issue-issueidorkey-properties-propertykey-get
//
// DESCRIPTION: Returns the value of an issue's property.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'IssueIdOrKey' and 'PropertyKey' parameters.
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
    IssueIdOrKey = "ORL-8004", // <-- IMPORTANT: Replace with a valid Issue ID or Key
    PropertyKey = "my.custom.property", // <-- IMPORTANT: Replace with a valid Property Key

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueIdOrKey & "/properties/" & PropertyKey,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Value = Response[value],
    #"Converted to Table" = Record.ToTable(Value),
    #"Transposed Table" = Table.Transpose(#"Converted to Table"),
    #"Promoted Headers" = Table.PromoteHeaders(#"Transposed Table", [PromoteAllScalars=true])
in
    #"Promoted Headers"

