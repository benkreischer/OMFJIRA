// =============================================================================
// ENDPOINT: Issue Types - GET Issue types for project
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-types/#api-rest-api-3-issuetype-project-get
//
// DESCRIPTION: Returns a paginated list of issue types for a project.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectId' parameter.
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
    ProjectId = 10000, // <-- IMPORTANT: Replace with a valid Project ID

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/issuetype/project",
            QueryString = Uri.BuildQueryString([
                projectId = Text.From(ProjectId),
                StartAt = 0,
            FullUrl = BaseUrl & Endpoint & "?" & QueryString,
            
            Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),
            Values = Response[values],
            
            // Check if there are more records to fetch
            IsLast = Response[isLast],
            NextStartAt = 0,
            Result = if IsLast = false then Values & @GetAllPages(NextStartAt) else Values
        in
            Result,

    AllIssueTypes = GetAllPages(0),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = Table.FromList(AllIssueTypes, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Columns" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "subtask", "scope"},
        {"ID", "Name", "Description", "Is Subtask", "Scope"}
    ),
    #"Expanded Scope" = Table.ExpandRecordColumn(#"Expanded Columns", "Scope", {"project"}, {"Project"}),
    #"Expanded Project" = Table.ExpandRecordColumn(#"Expanded Scope", "Project", {"name"}, {"Project Name"})
in
    #"Expanded Project"


