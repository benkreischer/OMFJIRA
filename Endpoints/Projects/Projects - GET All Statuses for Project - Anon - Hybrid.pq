// =============================================================================
// ENDPOINT: Projects - GET All Statuses for Project (Hybrid)
// =============================================================================
//
// DESCRIPTION: Returns all projects with their key, name, and all the statuses
// used within each project. This combines data from the Projects API and the
// Project Statuses API to provide a comprehensive view of status usage per project.
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
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "name", "id"}, {"ProjectKey", "ProjectName", "ProjectId"}),

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

            // Extract all status names from all issue types for this project
            StatusesFromProject = if ProjectStatusResponse = null then {}
                else List.Distinct(
                    List.Combine(
                        List.Transform(
                            ProjectStatusResponse,
                            each List.Transform([statuses], (status) => status[name])
                        )
                    )
                )
        in
            StatusesFromProject,

    // Add project statuses to projects table
    ProjectsWithStatuses = Table.AddColumn(ProjectsExpanded, "StatusNames", each GetProjectStatuses([ProjectKey])),

    // Convert status names list to semicolon-separated string
    ProjectsWithStatusString = Table.TransformColumns(ProjectsWithStatuses, {{"StatusNames", each if List.Count(_) > 0 then Text.Combine(List.Sort(_), "; ") else "No statuses found"}}),

    // Add generation timestamp
    WithTimestamp = Table.AddColumn(ProjectsWithStatusString, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Final column ordering and naming
    Result = Table.SelectColumns(WithTimestamp, {"ProjectKey", "ProjectName", "StatusNames", "GeneratedAt"}),
    FinalResult = Table.RenameColumns(Result, {{"ProjectKey", "ProjectKey"}, {"ProjectName", "ProjectName"}, {"StatusNames", "ProjectStatuses"}})

in
    FinalResult
