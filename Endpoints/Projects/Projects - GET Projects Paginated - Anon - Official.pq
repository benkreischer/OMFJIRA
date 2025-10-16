// =============================================================================
// ENDPOINT: Projects - GET Projects Paginated
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-search-get
//
// DESCRIPTION: Returns a paginated list of projects visible to the user.
//
// =============================================================================

let
    // =============================================================================
    // CONFIGURATION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/project/search",
    QueryString = "?startAt=0&maxResults=1000&orderBy=key&expand=lead,description,issueTypes,url,projectKeys,permissions,insight",
    FullUrl = BaseUrl & Endpoint & QueryString,
    
    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ]
        ])
    ),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Values = Response[values],
    #"Converted to Table" = Table.FromList(Values, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "name", "projectTypeKey", "simplified", "style", "isPrivate", "lead", "description", "issueTypes", "url", "projectKeys", "insight", "self"}, 
        {"Id", "Key", "Name", "ProjectTypeKey", "Simplified", "Style", "IsPrivate", "Lead", "Description", "IssueTypes", "Url", "ProjectKeys", "Insight", "Self"}
    ),
    #"Expanded Lead" = Table.ExpandRecordColumn(#"Expanded Columns", "Lead", 
        {"displayName", "accountId", "active", "timeZone"}, 
        {"LeadDisplayName", "LeadAccountId", "LeadActive", "LeadTimeZone"}
    ),
    #"Extract Issue Types" = Table.AddColumn(#"Expanded Lead", "IssueTypeNames", each 
        if [IssueTypes] = null then ""
        else Text.Combine(List.Transform([IssueTypes], each _[name]), "; ")
    ),
    #"Extract Project Keys" = Table.AddColumn(#"Extract Issue Types", "ProjectKeysCombined", each 
        if [ProjectKeys] = null then ""
        else Text.Combine([ProjectKeys], "; ")
    ),
    #"Extract Insight Data" = Table.AddColumn(#"Extract Project Keys", "TotalIssueCount", each 
        if [Insight] = null then 0
        else if Record.HasFields([Insight], {"totalIssueCount"}) then [Insight][totalIssueCount]
        else 0
    ),
    #"Extract Last Issue Update" = Table.AddColumn(#"Extract Insight Data", "LastIssueUpdateTime", each 
        if [Insight] = null then ""
        else if Record.HasFields([Insight], {"lastIssueUpdateTime"}) then [Insight][lastIssueUpdateTime]
        else ""
    ),
    #"Select Final Columns" = Table.SelectColumns(#"Extract Last Issue Update", {
        "Id", "Key", "Name", "ProjectTypeKey", "Simplified", "Style", "IsPrivate", 
        "LeadDisplayName", "LeadAccountId", "LeadActive", "LeadTimeZone",
        "Description", "Url", "Self", "IssueTypeNames", "ProjectKeysCombined", 
        "TotalIssueCount", "LastIssueUpdateTime"
    }),
    #"Rename Project Keys" = Table.RenameColumns(#"Select Final Columns", {
        {"ProjectKeysCombined", "ProjectKeys"}
    })

in
    #"Rename Project Keys"


