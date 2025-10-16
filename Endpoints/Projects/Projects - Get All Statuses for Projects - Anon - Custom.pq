// =============================================================================
// ENDPOINT: Projects - Get All Statuses for All Projects
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-search-get
//                     https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-statuses-get
//
// DESCRIPTION: Gets all valid statuses for all projects. Iterates through all projects 
// and retrieves the statuses for each project, grouped by issue type.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the authentication credentials below.
//
// =============================================================================

let
    // ========= AUTH (replace with PQ Parameters or Credential Store) =========
    BaseUrl   = "https://onemain.atlassian.net",
    Username  = "ben.kreischer.ce@omf.com",
    ApiToken  = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // ========= Helper: GET relative path, return parsed JSON =================
    JiraGetJson = (relativePath as text) as any =>
        let
            url = BaseUrl & relativePath,
            json = Json.Document(
                Web.Contents(
                    url,
                    [
                        Headers = [
                            #"Authorization" = AuthHeader,
                            #"Content-Type" = "application/json"
                        ]
                    ]
                )
            )
        in
            json,

    // ========= Pagination: /rest/api/3/project/search =======================
    // Returns all projects as a single list of project records.
    GetAllProjects = () as list =>
        let
            PageSize = 50,
            Pages =
                List.Generate(
                    () => [StartAt = 0, Page = JiraGetJson("/rest/api/3/project/search?startAt=0&maxResults=" & Number.ToText(PageSize))],
                    each List.Count([Page][values]) > 0,
                    each
                        let
                            NextStart = [StartAt] + PageSize,
                            NextPage  = JiraGetJson("/rest/api/3/project/search?startAt=" & Number.ToText(NextStart) & "&maxResults=" & Number.ToText(PageSize))
                        in
                            [StartAt = NextStart, Page = NextPage],
                    each [Page][values]
                ),
            AllProjects = List.Combine(Pages)
        in
            AllProjects,

    // ========= Transform: project list -> table =============================
    ProjectsList = GetAllProjects(),
    ProjectsTable =
        let
            t = Table.FromList(ProjectsList, Splitter.SplitByNothing(), {"Project"}, null, ExtraValues.Error),
            Expand = Table.ExpandRecordColumn(t, "Project", {"id", "key", "name", "projectTypeKey", "simplified"}, {"Project.id","Project.key","Project.name","Project.projectTypeKey","Project.simplified"})
        in
            Expand,

    // ========= Helper: Given a project key/id, fetch & flatten statuses =====
    GetStatusesForProject = (ProjectIdOrKey as text) as table =>
        let
            relative = "/rest/api/3/project/" & ProjectIdOrKey & "/statuses",
            response = JiraGetJson(relative),

            // If project has no issuetypes or call fails, handle gracefully
            safeList = if response is list then response else {},

            t0 = Table.FromList(safeList, Splitter.SplitByNothing(), {"IssueType"}, null, ExtraValues.Error),

            t1 = Table.ExpandRecordColumn(
                    t0, "IssueType",
                    {"self","id","name","subtask","statuses"},
                    {"IssueType.self","IssueType.id","IssueType.name","IssueType.subtask","statuses"}
                 ),

            t2 = Table.ExpandListColumn(t1, "statuses"),
            t3 = Table.ExpandRecordColumn(
                    t2, "statuses",
                    {"self","description","iconUrl","name","id","statusCategory"},
                    {"Status.self","Status.description","Status.iconUrl","Status.name","Status.id","Status.statusCategory"}
                 ),
            t4 = Table.ExpandRecordColumn(
                    t3, "Status.statusCategory",
                    {"self","id","key","colorName","name"},
                    {"StatusCategory.self","StatusCategory.id","StatusCategory.key","StatusCategory.colorName","StatusCategory.name"}
                 ),
            t5 = Table.AddColumn(t4, "Project.key", each ProjectIdOrKey, type text)
        in
            t5,

    // ========= Iterate all projects (with light error handling) =============
    StatusTables =
        List.Transform(
            Table.ToRecords(ProjectsTable),
            each
                let
                    k   = Text.From([Project.key]),
                    res = try GetStatusesForProject(k) otherwise #table({}, {})
                in
                    res
        ),

    CombinedStatuses = Table.Combine(List.RemoveNulls(StatusTables)),

    // ========= Optional: Join back to project metadata, tidy columns =========
    // Combine with ProjectsTable to also include id/name/type columns alongside key.
    Final =
        let
            // Keep a slim projects lookup
            ProjectsSlim = Table.SelectColumns(ProjectsTable, {"Project.key","Project.id","Project.name","Project.projectTypeKey","Project.simplified"}),
            Merged = Table.NestedJoin(CombinedStatuses, {"Project.key"}, ProjectsSlim, {"Project.key"}, "ProjectMeta", JoinKind.LeftOuter),
            Expanded = Table.ExpandTableColumn(Merged, "ProjectMeta", {"Project.id","Project.name","Project.projectTypeKey","Project.simplified"}, {"Project.id","Project.name","Project.projectTypeKey","Project.simplified"}),
            Reordered = Table.ReorderColumns(
                Expanded,
                {
                    "Project.key","Project.id","Project.name","Project.projectTypeKey","Project.simplified",
                    "IssueType.id","IssueType.name","IssueType.subtask","IssueType.self",
                    "Status.id","Status.name","Status.description","Status.iconUrl","Status.self",
                    "StatusCategory.id","StatusCategory.key","StatusCategory.name","StatusCategory.colorName","StatusCategory.self"
                },
                MissingField.Ignore
            )
        in
            Reordered
in
    Final
