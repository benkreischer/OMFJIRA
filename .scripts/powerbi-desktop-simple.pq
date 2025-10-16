// =============================================================================
// POWERBI DESKTOP - SIMPLE JIRA CONNECTION
// =============================================================================
// Replace the credentials below with your actual OMF login and API token

let
    // =============================================================================
    // STEP 1: UPDATE YOUR CREDENTIALS HERE
    // =============================================================================
    BaseUrl = "https://onemain.atlassian.net",
    Username = "your.omf.email@onemain.com",  // Replace with your OMF email
    ApiToken = "YOUR_API_TOKEN_HERE",         // Replace with your API token
    
    // =============================================================================
    // STEP 2: CREATE AUTHENTICATION HEADER
    // =============================================================================
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // =============================================================================
    // STEP 3: GET BASIC ISSUES DATA
    // =============================================================================
    IssuesUrl = BaseUrl & "/rest/api/3/search?jql=ORDER BY created DESC&maxResults=999999",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    IssuesResponse = Json.Document(Web.Contents(IssuesUrl, [Headers = Headers])),
    Issues = IssuesResponse[issues],
    
    // =============================================================================
    // STEP 4: CONVERT TO TABLE AND EXPAND FIELDS
    // =============================================================================
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedIssues = Table.ExpandRecordColumn(IssuesTable, "Column1", 
        {"id", "key", "summary", "status", "assignee", "created", "updated", "priority", "project"}, 
        {"Issue ID", "Key", "Summary", "Status", "Assignee", "Created", "Updated", "Priority", "Project"}
    ),
    
    // =============================================================================
    // STEP 5: CLEAN UP THE DATA
    // =============================================================================
    // Expand status field
    ExpandedStatus = Table.ExpandRecordColumn(ExpandedIssues, "Status", {"name"}, {"Status Name"}),
    
    // Expand assignee field
    ExpandedAssignee = Table.ExpandRecordColumn(ExpandedStatus, "Assignee", {"displayName"}, {"Assignee Name"}),
    
    // Expand priority field
    ExpandedPriority = Table.ExpandRecordColumn(ExpandedAssignee, "Priority", {"name"}, {"Priority Name"}),
    
    // Expand project field
    ExpandedProject = Table.ExpandRecordColumn(ExpandedPriority, "Project", {"key", "name"}, {"Project Key", "Project Name"}),
    
    // =============================================================================
    // STEP 6: CONVERT DATES TO PROPER FORMAT
    // =============================================================================
    // Convert Created date
    CreatedDate = Table.TransformColumns(ExpandedProject, {
        {"Created", DateTime.FromText}
    }),
    
    // Convert Updated date
    UpdatedDate = Table.TransformColumns(CreatedDate, {
        {"Updated", DateTime.FromText}
    }),
    
    // Add date-only columns
    FinalTable = Table.AddColumn(UpdatedDate, "Created Date", each DateTime.Date([Created])),
    FinalTable2 = Table.AddColumn(FinalTable, "Updated Date", each DateTime.Date([Updated])),
    
    // =============================================================================
    // STEP 7: FINAL CLEANUP
    // =============================================================================
    // Remove original datetime columns if you only want dates
    CleanTable = Table.RemoveColumns(FinalTable2, {"Created", "Updated"}),
    
    // Rename columns for better display
    RenamedTable = Table.RenameColumns(CleanTable, {
        {"Issue ID", "ID"},
        {"Key", "Issue Key"},
        {"Summary", "Title"},
        {"Status Name", "Status"},
        {"Assignee Name", "Assignee"},
        {"Priority Name", "Priority"},
        {"Project Key", "Project"},
        {"Project Name", "Project Name"},
        {"Created Date", "Created"},
        {"Updated Date", "Updated"}
    })
in
    RenamedTable
