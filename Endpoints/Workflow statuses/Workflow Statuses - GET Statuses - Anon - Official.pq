// =============================================================================
// ENDPOINT: Workflow Statuses - GET Statuses
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-statuses/
//
// DESCRIPTION: Returns a list of the statuses.
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
    Endpoint = "/rest/api/3/status",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = if Response is list then
        Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    else if Record.HasFields(Response, "values") then
        Table.FromList(Response[values], Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    else
        Table.FromRecords({Response})

in
    #"Converted to Table"
