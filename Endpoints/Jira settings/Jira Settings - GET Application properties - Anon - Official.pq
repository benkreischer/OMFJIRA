// =============================================================================
// ENDPOINT: Jira Settings - GET Application properties
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-jira-settings/#api-rest-api-3-application-properties-get
//
// DESCRIPTION: Returns all application properties.
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
    Endpoint = "/rest/api/3/application-properties",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = Get-RequestHeaders(Parameters)])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1",
        {"id", "key", "name", "desc", "type", "defaultValue", "value", "allowedValues"},
        {"ID", "Key", "Name", "Description", "Type", "Default Value", "Value", "Allowed Values"}
    )
in
    #"Expanded Columns"

