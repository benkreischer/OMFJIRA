// =============================================================================
// ENDPOINT: Issue Field Configurations - GET Field configuration schemes for projects
// =============================================================================
//
// API DOCUMENTATION: https://developer-stg.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-field-configurations/#api-rest-api-3-fieldconfigurationscheme-project-get
//
// DESCRIPTION: Returns a paginated list of field configuration schemes and, for each scheme, a list of the projects that use it.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'ProjectId' parameter with one or more project IDs.
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
    ProjectId = {10000, 10001}, // <-- IMPORTANT: Replace with a list of valid Project IDs

    // =============================================================================
    // API CALL (with pagination handling)
    // =============================================================================
    GetAllPages = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/fieldconfigurationscheme/project",
            QueryString = Uri.BuildQueryString([
                StartAt = 0,
                projectId = Text.Combine(List.Transform(ProjectId, each Text.From(_)), ",")
            ]),
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
    #"Expanded FieldScheme" = Table.ExpandRecordColumn("fieldConfigurationScheme", "Column1", {"fieldConfigurationScheme", "projectCategory", "lead", "description", "issueTypes", "url", "projectKeys", "permissions", "insight"}, {"Field Scheme", "projectCategory", "lead", "description", "issueTypes", "url", "projectKeys", "permissions", "insight"}),
    #"Expanded Details" = Table.ExpandRecordColumn(#"Expanded FieldScheme", "Field Scheme", 
        {"id", "name", "description"},
        {"ID", "Name", "Description"}
    ),
    #"Added ProjectIds" = Table.AddColumn(#"Expanded Details", "Project IDs", each [Column1][projectIds]),
    #"Removed OriginalColumn" = Table.RemoveColumns(#"Added ProjectIds", {"Column1"}),
    #"Extracted ProjectIds" = Table.TransformColumns(#"Removed OriginalColumn", {"Project IDs", each Text.Combine(List.Transform(_, Text.From), ", "), type text})
in
    #"Extracted ProjectIds"


