// =============================================================================
// ENDPOINT: Audit Records - GET Audit records
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-audit-records/#api-rest-api-3-auditing-record-get
//
// DESCRIPTION: Returns a list of audit records. The list can be filtered by date and text.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Adjust the optional parameters (Limit, Filter, FromDate, ToDate) as needed.
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
    // PARAMETERS (Optional)
    // =============================================================================
    Limit = 2147483647, // Max number of records to return
    Filter = "", // Text to filter by
    FromDate = "2023-01-01T00:00:00.000Z", // Start date/time in ISO 8601 format
    ToDate = "", // End date/time in ISO 8601 format

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (Offset as number) =>
        let
            Endpoint = "/rest/api/3/auditing/record",
            QueryString = Uri.BuildQueryString([
                offset = Text.From(Offset),
                Limit = 2147483647,
                filter = Filter,
                from = FromDate,
                to = ToDate
            ]),
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Records = Response[records],
            
            // Check if there are more records to fetch
            Total = Response[total],
            NextOffset = Offset + Limit,
            Result = if NextOffset < Total then Records & @GetAllPages(NextOffset) else Records
        in
            Result,

    AllRecords = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllRecords, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "summary", "remoteAddress", "authorKey", "created", "category", "eventSource", "description", "objectItem", "changedValues", "associatedItems"},
        {"ID", "Summary", "Remote Address", "Author Key", "Created", "Category", "Event Source", "Description", "Object Item", "Changed Values", "Associated Items"}
    ),
    #"Expanded Object Item" = Table.ExpandRecordColumn(#"Expanded Columns", "Object Item", {"name", "id", "typeName"}, {"Object Name", "Object ID", "Object Type"}),
    #"Expanded Changed Values" = Table.ExpandListColumn(#"Expanded Object Item", "Changed Values"),
    #"Expanded Changed Values Record" = Table.ExpandRecordColumn(#"Expanded Changed Values", "Changed Values", {"fieldName", "changedFrom", "changedTo"}, {"Field Name", "Changed From", "Changed To"}),
    #"Expanded Associated Items" = Table.ExpandListColumn(#"Expanded Changed Values Record", "Associated Items"),
    #"Expanded Associated Items Record" = Table.ExpandRecordColumn(#"Expanded Associated Items", "Associated Items", {"name", "id", "typeName", "parentId", "parentName"}, {"Associated Item Name", "Associated Item ID", "Associated Item Type", "Parent ID", "Parent Name"})
in
    #"Expanded Associated Items Record"


