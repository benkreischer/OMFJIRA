// =============================================================================
// ENDPOINT: Groups - GET Find groups
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-groups-picker-get
//
// DESCRIPTION: Returns a paginated list of groups matching the search criteria.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'Query' parameter with the text to search for.
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
    Query = "admin", // <-- The string to search for.

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (NextPage as text) =>
        let
            // For the first call, NextPage will be null
            Endpoint = if NextPage = null then "/rest/api/3/groups/picker?query=" & Uri.EscapeDataString(Query) else Text.AfterDelimiter(NextPage, ".net"),
            FullUrl = BaseUrl & Endpoint,

            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[groups],
            
            // Check if there is a next page
            HasNextPage = Record.HasFields(Response, "nextPage"),
            Result = if HasNextPage then Values & @GetAllPages(Response[nextPage]) else Values
        in
            Result,

    AllGroups = GetAllPages(null),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllGroups, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"name", "groupId", "html"},
        {"Name", "Group ID", "HTML"}
    )
in
    #"Expanded Columns"

