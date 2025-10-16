// =============================================================================
// ENDPOINT: Issue Links - GET Project to Project Links (Official)
// =============================================================================
//
// DESCRIPTION: Returns a summary showing each project key and all the project
// keys it's linked to through issue links. Shows one row per project with
// all their linked project keys.
//
// OUTPUT COLUMNS:
// - ProjectKey: The main project key
// - ProjectStatus: Whether the project is Active or Archived
// - LinkedProjectKeys: Semicolon-separated list of project keys linked to this project
// - LinkCount: Number of unique projects this project is linked to
// - GeneratedAt: Timestamp when data was generated
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update authentication credentials below
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION - UPDATE THESE VALUES
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // =============================================================================
    // GET ALL PROJECTS WITH STATUS INFORMATION
    // =============================================================================
    ProjectsEndpoint = "/rest/api/3/project",
    ProjectsUrl = BaseUrl & ProjectsEndpoint,

    // Get all projects to have project status information
    AllProjectsResponse = Json.Document(
        Web.Contents(ProjectsUrl, [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ]
        ])
    ),

    // Convert projects to table for lookup
    ProjectsTable = Table.FromList(AllProjectsResponse, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "archived"}, {"ProjectKey", "Archived"}),
    ProjectsWithStatus = Table.AddColumn(ProjectsExpanded, "ProjectStatus", each if [Archived] = true then "Archived" else "Active"),

    // =============================================================================
    // PAGINATION FUNCTION TO GET ALL ISSUES WITH LINKS
    // =============================================================================
    SearchEndpoint = "/rest/api/3/search",
    SearchUrl = BaseUrl & SearchEndpoint,
    JqlQuery = "issuelinks is not EMPTY ORDER BY project ASC, created DESC",

    // Function to get paginated results - gets ALL issues, no limits
    GetAllIssuesWithLinks = (url as text, jql as text, authHeader as text) =>
        let
            MaxResults = 100, // Use smaller batches for better performance

            // Function to get a single page
            GetPage = (startAt as number) =>
                let
                    PageBody = [
                        jql = jql,
                        maxResults = MaxResults,
                        startAt = startAt,
                        fields = {"key", "project", "issuelinks"}
                    ],

                    PageResponse = Json.Document(
                        Web.Contents(url, [
                            Headers = [
                                #"Authorization" = authHeader,
                                #"Accept" = "application/json",
                                #"Content-Type" = "application/json"
                            ],
                            Content = Text.ToBinary(Json.FromValue(PageBody))
                        ])
                    )
                in
                    [
                        issues = PageResponse[issues],
                        total = PageResponse[total],
                        hasMore = List.Count(PageResponse[issues]) = MaxResults
                    ],

            // Get first page to determine total
            FirstPage = GetPage(0),

            // Generate all start positions needed
            TotalIssues = FirstPage[total],
            AllStartPositions = List.Generate(
                () => 0,
                each _ < TotalIssues,
                each _ + MaxResults
            ),

            // Get all pages
            AllPages = List.Transform(AllStartPositions, each GetPage(_)),
            AllIssues = List.Combine(List.Transform(AllPages, each _[issues]))
        in
            AllIssues,

    // Get all issues with links using pagination
    IssuesList = GetAllIssuesWithLinks(SearchUrl, JqlQuery, AuthHeader),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    // Convert to table and expand issue fields
    IssuesTable = Table.FromList(IssuesList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),

    ExpandedIssues = Table.ExpandRecordColumn(IssuesTable, "Column1",
        {"key", "fields"},
        {"IssueKey", "Fields"}),

    // Expand the fields column to get project and issuelinks
    ExpandedFields = Table.ExpandRecordColumn(ExpandedIssues, "Fields",
        {"project", "issuelinks"},
        {"Project", "IssueLinks"}),

    // Filter out issues without links and extract project keys
    ProcessedData = Table.AddColumn(ExpandedFields, "ProjectData", each
        let
            projectKey = if [Project] = null then null else [Project][key],
            links = [IssueLinks],

            // Extract linked project keys from inward links
            inwardProjectKeys = if links = null then {} else
                List.Transform(
                    List.Select(links, each _ <> null and Record.HasFields(_, "inwardIssue")),
                    each try Text.Split([inwardIssue][key], "-"){0} otherwise null
                ),

            // Extract linked project keys from outward links
            outwardProjectKeys = if links = null then {} else
                List.Transform(
                    List.Select(links, each _ <> null and Record.HasFields(_, "outwardIssue")),
                    each try Text.Split([outwardIssue][key], "-"){0} otherwise null
                ),

            // Combine and clean up linked project keys (exclude self-links)
            allLinkedProjectKeys = List.Combine({inwardProjectKeys, outwardProjectKeys}),
            validLinkedProjectKeys = List.Select(allLinkedProjectKeys, each _ <> null and _ <> projectKey),
            uniqueLinkedProjectKeys = List.Distinct(validLinkedProjectKeys)
        in
            if projectKey = null then null else [
                ProjectKey = projectKey,
                LinkedProjectKeys = uniqueLinkedProjectKeys
            ]
    ),

    // Filter out null project data and expand
    ValidProjectData = Table.SelectRows(ProcessedData, each [ProjectData] <> null),

    ExpandedProjectData = Table.ExpandRecordColumn(ValidProjectData, "ProjectData",
        {"ProjectKey", "LinkedProjectKeys"},
        {"ProjectKey", "LinkedProjectKeys"}),

    // Group by project key to consolidate all linked projects
    GroupedByProject = Table.Group(ExpandedProjectData, {"ProjectKey"}, {
        {"AllLinkedProjects", each List.Distinct(List.Combine([LinkedProjectKeys])), type list}
    }),

    // Format the final output and merge with project status
    FinalData = Table.AddColumn(GroupedByProject, "FormattedData", each
        let
            linkedProjects = [AllLinkedProjects],
            sortedLinkedProjects = List.Sort(linkedProjects),
            // Lookup project status
            projectStatus = try Table.SelectRows(ProjectsWithStatus, each [ProjectKey] = [ProjectKey]){0}[ProjectStatus] otherwise "Active"
        in
            [
                ProjectKey = [ProjectKey],
                ProjectStatus = projectStatus,
                LinkedProjectKeys = if List.Count(sortedLinkedProjects) > 0 then Text.Combine(sortedLinkedProjects, "; ") else "",
                LinkCount = List.Count(sortedLinkedProjects)
            ]
    ),

    // Expand formatted data
    ExpandedFinalData = Table.ExpandRecordColumn(FinalData, "FormattedData",
        {"ProjectKey", "ProjectStatus", "LinkedProjectKeys", "LinkCount"},
        {"ProjectKey", "ProjectStatus", "LinkedProjectKeys", "LinkCount"}),

    // Add generation timestamp and sort by project key
    WithTimestamp = Table.AddColumn(ExpandedFinalData, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")),

    // Sort by project key for consistent output
    SortedResult = Table.Sort(WithTimestamp, {"ProjectKey", Order.Ascending}),

    // Select final columns
    Result = Table.SelectColumns(SortedResult, {"ProjectKey", "ProjectStatus", "LinkedProjectKeys", "LinkCount", "GeneratedAt"})

in
    Result
