// =============================================================================
// ENDPOINT: Group and User Pickers - GET Find users and groups
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-group-and-user-pickers/#api-rest-api-3-groupuserpicker-get
//
// DESCRIPTION: Returns a paginated list of users and groups matching the search criteria.
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
    Query = "admin", // <-- IMPORTANT: The string to search for.
    ,
    ShowAvatar = true,
    FieldId = "", // e.g., "assignee"
    ProjectId = "", // e.g., "10000"
    IssueTypeId = "", // e.g., "10001"
    AvatarSize = "xsmall",

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/groupuserpicker",
    QueryString = Uri.BuildQueryString([
        query = Query,
        MaxResults = 2147483647,
        showAvatar = ShowAvatar,
        fieldId = FieldId,
        projectId = ProjectId,
        issueTypeId = IssueTypeId,
        avatarSize = AvatarSize
    ]),
    FullUrl = BaseUrl & Endpoint & "?" & QueryString,

    Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    UsersList = Response[users][users],
    GroupsList = Response[groups][groups],

    UsersTable = Table.FromList(UsersList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    GroupsTable = Table.FromList(GroupsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

    ExpandedUsers = Table.ExpandRecordColumn(UsersTable, "Column1", 
        {"name", "displayName", "accountId"}, 
        {"User Name", "User Display Name", "Account ID"}
    ),
    ExpandedGroups = Table.ExpandRecordColumn(GroupsTable, "Column1", 
        {"name", "groupId"},
        {"Group Name", "Group ID"}
    ),

    // Combine the two tables
    // For simplicity, this example just returns the users table. You can adjust this to return groups or a combined table.
    ResultTable = ExpandedUsers 
in
    ResultTable


