// =============================================================================
// ENDPOINT: Priority Schemes - GET Priority Scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-priority-schemes/#api-rest-api-3-priorityscheme-get
//
// DESCRIPTION: Returns all priority schemes visible to the user.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Load the data
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
    Endpoint = "/rest/api/3/priorityscheme",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = [#"Authorization" = AuthHeader, #"Accept" = "application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Values = Response[values],
    #"Converted to Table" = Table.FromList(Values, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"self", "id", "name", "description", "isDefault", "defaultPriorityId"}, 
        {"self", "id", "name", "description", "isDefault", "defaultPriorityId"}
    ),
    #"Rename Columns" = Table.RenameColumns(#"Expanded Columns", {
        {"id", "Id"}, {"name", "Name"}, {"description", "Description"}, 
        {"isDefault", "IsDefault"}, {"defaultPriorityId", "DefaultPriorityId"}, 
        {"self", "Self"}
    })

in
    #"Rename Columns"

