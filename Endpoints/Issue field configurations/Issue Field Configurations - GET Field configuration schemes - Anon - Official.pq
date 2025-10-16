// =============================================================================
// ENDPOINT: Issue Field Configurations - GET Field configuration schemes
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-field-configurations/#api-rest-api-3-fieldconfigurationscheme-get
//
// DESCRIPTION: Returns a paginated list of field configuration schemes.
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
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/fieldconfigurationscheme",
            QueryString = Uri.BuildQueryString([StartAt = 0,
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],
            
            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllSchemes = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllSchemes, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description"},
        {"ID", "Name", "Description"}
    )
in
    #"Expanded Columns"


