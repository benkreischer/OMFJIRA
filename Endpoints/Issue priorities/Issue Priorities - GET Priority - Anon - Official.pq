// =============================================================================
// ENDPOINT: Issue Priorities - GET Priority
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-get
//
// DESCRIPTION: Returns the priority information for a specific issue (ORL-8004).
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. This will get the priority assigned to issue ORL-8004.
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
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken, TextEncoding.Ascii), BinaryEncoding.Base64),

    // =============================================================================
    // PARAMETER
    // =============================================================================
    IssueKey = "ORL-8004", // <-- The issue to get priority information from

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/issue/" & IssueKey,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers = [#"Authorization" = AuthHeader, #"Accept" = "application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Extract priority information from the issue
    PriorityInfo = Response[fields][priority],
    
    // Create a record with issue context and priority details
    PriorityRecord = [
        IssueKey = Response[key],
        PriorityId = PriorityInfo[id],
        PriorityName = PriorityInfo[name],
        PriorityDescription = PriorityInfo[description],
        StatusColor = PriorityInfo[statusColor],
        IconUrl = PriorityInfo[iconUrl],
        IsDefault = PriorityInfo[isDefault]
    ],
    
    // Convert to table
    #"Converted to Table" = #table(
        {"IssueKey", "PriorityId", "PriorityName", "PriorityDescription", "StatusColor", "IconUrl", "IsDefault"},
        {{PriorityRecord[IssueKey], PriorityRecord[PriorityId], PriorityRecord[PriorityName], PriorityRecord[PriorityDescription], PriorityRecord[StatusColor], PriorityRecord[IconUrl], PriorityRecord[IsDefault]}}
    )
in
    #"Converted to Table"
