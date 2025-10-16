// =============================================================================
// ADVANCED JIRA VISUALIZATIONS
// =============================================================================

// Advanced visualization queries that create sophisticated charts and dashboards
// These surpass Atlassian Analytics by providing interactive and custom visualizations

// 1. Cumulative Flow Diagram
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for cumulative flow
    JQLQuery = "ORDER BY created DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Create cumulative flow data
    CumulativeFlowData = Table.Group(AddTimeColumns, {"Created Date Only", "Status"}, {
        {"Count", each Table.RowCount(_), type number}
    }),
    
    // Pivot for cumulative flow
    PivotForCumulativeFlow = Table.Pivot(CumulativeFlowData, List.Distinct(CumulativeFlowData[Status]), "Status", "Count", List.Sum),
    
    // Add cumulative columns
    AddCumulativeColumns = Table.AddColumn(PivotForCumulativeFlow, "Cumulative To Do", each 
        if [To Do] <> null then [To Do] else 0, type number),
    
    AddCumulativeColumns2 = Table.AddColumn(AddCumulativeColumns, "Cumulative In Progress", each 
        [Cumulative To Do] + (if [In Progress] <> null then [In Progress] else 0), type number),
    
    AddCumulativeColumns3 = Table.AddColumn(AddCumulativeColumns2, "Cumulative Done", each 
        [Cumulative In Progress] + (if [Done] <> null then [Done] else 0), type number)
    
in
    AddCumulativeColumns3

// 2. Control Chart for Process Stability
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for control chart
    JQLQuery = "status = Done ORDER BY resolutiondate DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Group by week for control chart
    AddWeekColumn = Table.AddColumn(AddTimeColumns, "Week", each Date.WeekOfYear([Resolution Date Only]), type number),
    
    // Calculate weekly averages
    WeeklyAverages = Table.Group(AddWeekColumn, {"Week"}, {
        {"Avg Resolution Time", each List.Average([Resolution Time Days]), type number},
        {"Count", each Table.RowCount(_), type number}
    }),
    
    // Calculate control limits
    OverallAverage = List.Average(WeeklyAverages[Avg Resolution Time]),
    OverallStdDev = List.StandardDeviation(WeeklyAverages[Avg Resolution Time]),
    
    // Add control limits
    AddControlLimits = Table.AddColumn(WeeklyAverages, "Center Line", each OverallAverage, type number),
    AddControlLimits2 = Table.AddColumn(AddControlLimits, "Upper Control Limit", each OverallAverage + (3 * OverallStdDev), type number),
    AddControlLimits3 = Table.AddColumn(AddControlLimits2, "Lower Control Limit", each OverallAverage - (3 * OverallStdDev), type number),
    AddControlLimits4 = Table.AddColumn(AddControlLimits3, "Upper Warning Limit", each OverallAverage + (2 * OverallStdDev), type number),
    AddControlLimits5 = Table.AddColumn(AddControlLimits4, "Lower Warning Limit", each OverallAverage - (2 * OverallStdDev), type number),
    
    // Add control chart status
    AddControlStatus = Table.AddColumn(AddControlLimits5, "Control Status", each 
        if [Avg Resolution Time] > [Upper Control Limit] or [Avg Resolution Time] < [Lower Control Limit] then "Out of Control" else
        if [Avg Resolution Time] > [Upper Warning Limit] or [Avg Resolution Time] < [Lower Warning Limit] then "Warning" else "In Control", type text)
    
in
    AddControlStatus

// 3. Heat Map for Resource Utilization
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for heat map
    JQLQuery = "assignee is not EMPTY ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Add day of week and hour columns
    AddDayOfWeek = Table.AddColumn(AddTimeColumns, "Day of Week", each Date.DayOfWeek([Created]), type number),
    AddHour = Table.AddColumn(AddDayOfWeek, "Hour", each Time.Hour([Created]), type number),
    
    // Create heat map data
    HeatMapData = Table.Group(AddHour, {"Assignee", "Day of Week", "Hour"}, {
        {"Issue Count", each Table.RowCount(_), type number},
        {"Total Resolution Time", each List.Sum([Resolution Time Days]), type number}
    }),
    
    // Add utilization score
    AddUtilizationScore = Table.AddColumn(HeatMapData, "Utilization Score", each 
        [Issue Count] * 10 + [Total Resolution Time], type number),
    
    // Add utilization level
    AddUtilizationLevel = Table.AddColumn(AddUtilizationScore, "Utilization Level", each 
        if [Utilization Score] > 100 then "High" else
        if [Utilization Score] > 50 then "Medium" else "Low", type text)
    
in
    AddUtilizationLevel

// 4. Network Diagram for Issue Relationships
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for network diagram
    JQLQuery = "ORDER BY created DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate", "labels"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date", "Labels"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Create network nodes
    NetworkNodes = Table.SelectColumns(AddTimeColumns, {"Key", "Summary", "Status", "Assignee", "Project", "Issue Type", "Priority"}),
    
    // Create network edges (relationships)
    NetworkEdges = Table.AddColumn(NetworkNodes, "Related Issues", each 
        let
            relatedIssues = List.Combine({
                if [Assignee] <> null then {[Assignee]} else {},
                if [Project] <> null then {[Project]} else {},
                if [Issue Type] <> null then {[Issue Type]} else {}
            })
        in
            relatedIssues, type list),
    
    // Add edge weights
    AddEdgeWeights = Table.AddColumn(NetworkEdges, "Edge Weight", each 
        if [Priority] = "Highest" then 5 else
        if [Priority] = "High" then 4 else
        if [Priority] = "Medium" then 3 else
        if [Priority] = "Low" then 2 else 1, type number)
    
in
    AddEdgeWeights

// 5. Gantt Chart with Dependencies
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for Gantt chart
    JQLQuery = "ORDER BY created DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Add Gantt chart columns
    AddGanttColumns = Table.AddColumn(AddTimeColumns, "Start Date", each [Created Date Only], type date),
    AddGanttColumns2 = Table.AddColumn(AddGanttColumns, "End Date", each 
        if [Resolution Date Only] <> null then [Resolution Date Only] else
        if [Due Date] <> null then DateTime.Date([Due Date]) else [Created Date Only] + 7, type date),
    AddGanttColumns3 = Table.AddColumn(AddGanttColumns2, "Duration Days", each Duration.Days([End Date] - [Start Date]), type number),
    AddGanttColumns4 = Table.AddColumn(AddGanttColumns3, "Progress %", each 
        if [Status] = "Done" then 100 else
        if [Status] = "In Progress" then 50 else
        if [Status] = "To Do" then 0 else 25, type number),
    
    // Add dependency information
    AddDependencies = Table.AddColumn(AddGanttColumns4, "Dependencies", each 
        let
            deps = List.Combine({
                if [Assignee] <> null then {[Assignee]} else {},
                if [Project] <> null then {[Project]} else {}
            })
        in
            Text.Combine(deps, ", "), type text),
    
    // Add critical path indicator
    AddCriticalPath = Table.AddColumn(AddDependencies, "Critical Path", each 
        if [Priority] = "Highest" or [Priority] = "High" then "Yes" else "No", type text)
    
in
    AddCriticalPath

// 6. Kanban Board Analytics
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues for Kanban analytics
    JQLQuery = "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Project", "Due Date", "Resolution Date"}),
    
    // Convert dates
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns2, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number),
    
    // Add Kanban columns
    AddKanbanColumns = Table.AddColumn(AddTimeColumns, "Kanban Column", each [Status], type text),
    AddKanbanColumns2 = Table.AddColumn(AddKanbanColumns, "WIP Limit", each 
        if [Status] = "In Progress" then 5 else null, type number),
    AddKanbanColumns3 = Table.AddColumn(AddKanbanColumns2, "Blocked", each 
        if [Status] = "Blocked" then "Yes" else "No", type text),
    AddKanbanColumns4 = Table.AddColumn(AddKanbanColumns3, "Age in Column", each 
        Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    
    // Add flow metrics
    AddFlowMetrics = Table.AddColumn(AddKanbanColumns4, "Flow Efficiency", each 
        if [Resolution Time Days] <> null then 
            if [Resolution Time Days] < 5 then "High" else
            if [Resolution Time Days] < 10 then "Medium" else "Low"
        else "Unknown", type text),
    
    // Add bottleneck indicator
    AddBottleneckIndicator = Table.AddColumn(AddFlowMetrics, "Bottleneck", each 
        if [Age in Column] > 14 then "Yes" else "No", type text)
    
in
    AddBottleneckIndicator
