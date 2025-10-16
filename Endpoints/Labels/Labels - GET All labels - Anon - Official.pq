// =============================================================================
// ENDPOINT: Labels - GET All labels
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-labels/#api-rest-api-3-label-get
//
// DESCRIPTION: Returns a paginated list of labels.
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
            Endpoint = "/rest/api/3/label",
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

    AllLabels = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllLabels, Splitter.SplitByNothing(), {"Label"}, null, ExtraValues.Error)
in
    #"Converted to Table"


