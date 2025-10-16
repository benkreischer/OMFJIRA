// =============================================================================
// ENDPOINT: Groups - GET Group members
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-groups/#api-rest-api-3-group-member-get
//
// DESCRIPTION: Returns a paginated list of all users in a group.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'GroupName' parameter with the name of the group.
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
    // PARAMETER
    // =============================================================================
    GroupName = "site-admins", // <-- IMPORTANT: Replace with a valid Group Name

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/group/member",
            QueryString = Uri.BuildQueryString([groupname = GroupName, StartAt = 0,
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],
            
            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllMembers = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllMembers, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"accountId", "displayName", "accountType", "active"},
        {"Account ID", "Display Name", "Account Type", "Is Active"}
    )
in
    #"Expanded Columns"


