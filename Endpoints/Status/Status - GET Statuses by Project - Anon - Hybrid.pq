// =============================================================================
// ENDPOINT: Status - GET Statuses by Project (Hybrid)
// =============================================================================
//
// DESCRIPTION: Returns all statuses with their ID, Name, Description and the
// project keys that use each status. This combines data from the Statuses API
// and Projects API to provide a comprehensive view of status usage.
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. No additional parameters required.
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
    // GET ALL STATUSES
    // =============================================================================
    StatusesEndpoint = "/rest/api/3/status",
    StatusesUrl = BaseUrl & StatusesEndpoint,

    StatusesResponse = Json.Document(
        Web.Contents(StatusesUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ]
        ])
    ),

    // Transform statuses data - keep only ID, Name
    StatusesTable = Table.FromList(StatusesResponse, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    StatusesExpanded = Table.ExpandRecordColumn(StatusesTable, "Column1", {"id", "name"}, {"StatusId", "StatusName"}),

    // =============================================================================
    // GET ALL PROJECTS WITH PAGINATION
    // =============================================================================
    GetAllProjects = () =>
        let
            GetProjectsPage = (startAt as number) =>
                let
                    ProjectsEndpoint = "/rest/api/3/project/search?maxResults=100&startAt=" & Number.ToText(startAt),
                    ProjectsUrl = BaseUrl & ProjectsEndpoint,

                    ProjectsResponse = Json.Document(
                        Web.Contents(ProjectsUrl, [
                            Headers = [
                                #"Authorization" = AuthHeader,
                                #"Accept" = "application/json"
                            ]
                        ])
                    )
                in
                    ProjectsResponse,

            // Get all pages using List.Generate
            AllPages = List.Generate(
                () => [Page = GetProjectsPage(0), StartAt = 0],
                each List.Count([Page][values]) = 100,
                each [Page = GetProjectsPage([StartAt] + 100), StartAt = [StartAt] + 100],
                each [Page][values]
            ),

            // Combine all pages
            AllProjects = List.Combine(AllPages)
        in
            AllProjects,

    // Get all projects
    ProjectsList = GetAllProjects(),
    ProjectsTable = Table.FromList(ProjectsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "id"}, {"ProjectKey", "ProjectId"}),

    // =============================================================================
    // GET STATUSES FOR EACH PROJECT
    // =============================================================================
    GetProjectStatuses = (projectKey as text) =>
        let
            ProjectStatusEndpoint = "/rest/api/3/project/" & projectKey & "/statuses",
            ProjectStatusUrl = BaseUrl & ProjectStatusEndpoint,

            ProjectStatusResponse = try Json.Document(
                Web.Contents(ProjectStatusUrl, [
                    Headers = [
                        #"Authorization" = AuthHeader,
                        #"Accept" = "application/json"
                    ]
                ])
            ) otherwise null,

            // Extract all statuses from all issue types for this project
            StatusesFromProject = if ProjectStatusResponse = null then {}
                else List.Distinct(
                    List.Transform(
                        ProjectStatusResponse,
                        each List.Transform([statuses], (status) => status[id])
                    )
                ),

            FlattenedStatuses = List.Combine(StatusesFromProject)
        in
            FlattenedStatuses,

    // Add project statuses to projects table
    ProjectsWithStatuses = Table.AddColumn(ProjectsExpanded, "StatusIds", each GetProjectStatuses([ProjectKey])),

    // Expand the status IDs into separate rows
    ProjectStatusRows = Table.ExpandListColumn(ProjectsWithStatuses, "StatusIds"),

    // =============================================================================
    // COMBINE DATA
    // =============================================================================
    // Join statuses with project usage
    JoinedData = Table.NestedJoin(StatusesExpanded, {"StatusId"}, ProjectStatusRows, {"StatusIds"}, "ProjectUsage", JoinKind.LeftOuter),

    // Expand project usage and group by status
    ExpandedUsage = Table.ExpandTableColumn(JoinedData, "ProjectUsage", {"ProjectKey"}, {"ProjectKey"}),

    // Group by status and concatenate project keys
    GroupedByStatus = Table.Group(ExpandedUsage, {"StatusId", "StatusName"}, {
        {"ProjectKeys", each Text.Combine(List.Distinct([ProjectKey]), "; "), type text}
    }),

    // Clean up project keys (remove nulls)
    CleanedProjectKeys = Table.TransformColumns(GroupedByStatus, {{"ProjectKeys", each if _ = null or _ = "" then "No projects found" else _}}),

    // Add generation timestamp
    WithTimestamp = Table.AddColumn(CleanedProjectKeys, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Final column ordering and naming
    Result = Table.SelectColumns(WithTimestamp, {"StatusId", "StatusName", "ProjectKeys", "GeneratedAt"}),
    FinalResult = Table.RenameColumns(Result, {{"StatusId", "ID"}, {"StatusName", "Name"}})

in
    FinalResult
