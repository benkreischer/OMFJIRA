// =============================================================================
// JIRA API POWER QUERY CONNECTION TEMPLATES
// =============================================================================
// Base Configuration
BaseUrl = "https://onemain-omfdirty.atlassian.net",
Username = "ben.kreischer.ce@omf.com",
ApiToken = "[YOUR_API_TOKEN]", // Replace with your actual API token

// Authentication Helper Function
GetAuthHeaders = () => [
    Authorization = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), 0),
    Accept = "application/json"
],

// =============================================================================
// PROJECTS ENDPOINT
// =============================================================================
Projects = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/project/ORL?expand=lead,description,issueTypes,url,projectKeys,permissions,insight", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Record.ToTable(Source),
    #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", 
        {"id", "key", "name", "description", "lead", "projectTypeKey", "insight"}, 
        {"Id", "Key", "Name", "Description", "Lead", "ProjectTypeKey", "Insight"}),
    #"Expanded Lead" = Table.ExpandRecordColumn(#"Expanded Value", "Lead", 
        {"displayName", "emailAddress"}, 
        {"Lead_DisplayName", "Lead_EmailAddress"}),
    #"Expanded Insight" = Table.ExpandRecordColumn(#"Expanded Lead", "Insight", 
        {"totalIssueCount"}, 
        {"Insight_TotalIssueCount"})
in
    #"Expanded Insight",

// =============================================================================
// ALL PROJECTS ENDPOINT
// =============================================================================
AllProjects = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/project/search?expand=lead,description,issueTypes,url,projectKeys,permissions,insight", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[values], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "name", "description", "lead", "projectTypeKey", "insight"}, 
        {"Id", "Key", "Name", "Description", "Lead", "ProjectTypeKey", "Insight"}),
    #"Expanded Lead" = Table.ExpandRecordColumn(#"Expanded Column1", "Lead", 
        {"displayName", "emailAddress"}, 
        {"Lead_DisplayName", "Lead_EmailAddress"}),
    #"Expanded Insight" = Table.ExpandRecordColumn(#"Expanded Lead", "Insight", 
        {"totalIssueCount"}, 
        {"Insight_TotalIssueCount"})
in
    #"Expanded Insight",

// =============================================================================
// ISSUES ENDPOINT
// =============================================================================
Issues = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/search?jql=order by created DESC&maxResults=100", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[issues], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "fields"}, 
        {"Id", "Key", "Fields"}),
    #"Expanded Fields" = Table.ExpandRecordColumn(#"Expanded Column1", "Fields", 
        {"summary", "status", "priority", "issuetype", "created", "updated"}, 
        {"Summary", "Status", "Priority", "IssueType", "Created", "Updated"}),
    #"Expanded Status" = Table.ExpandRecordColumn(#"Expanded Fields", "Status", 
        {"name"}, 
        {"Status_Name"}),
    #"Expanded Priority" = Table.ExpandRecordColumn(#"Expanded Status", "Priority", 
        {"name"}, 
        {"Priority_Name"}),
    #"Expanded IssueType" = Table.ExpandRecordColumn(#"Expanded Priority", "IssueType", 
        {"name"}, 
        {"IssueType_Name"})
in
    #"Expanded IssueType",

// =============================================================================
// USERS ENDPOINT
// =============================================================================
Users = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/users/search", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"accountId", "displayName", "emailAddress", "active"}, 
        {"AccountId", "DisplayName", "EmailAddress", "Active"})
in
    #"Expanded Column1",

// =============================================================================
// ISSUE FIELDS ENDPOINT
// =============================================================================
IssueFields = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/field", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "custom", "orderable", "navigable", "searchable", "clauseNames", "schema"}, 
        {"Id", "Name", "Custom", "Orderable", "Navigable", "Searchable", "ClauseNames", "Schema"}),
    #"Expanded Schema" = Table.ExpandRecordColumn(#"Expanded Column1", "Schema", 
        {"type"}, 
        {"Schema_Type"})
in
    #"Expanded Schema",

// =============================================================================
// ISSUE TYPES ENDPOINT
// =============================================================================
IssueTypes = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/issuetype", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "iconUrl", "subtask"}, 
        {"Id", "Name", "Description", "IconUrl", "Subtask"})
in
    #"Expanded Column1",

// =============================================================================
// STATUSES ENDPOINT
// =============================================================================
Statuses = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/status", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "statusCategory"}, 
        {"Id", "Name", "Description", "StatusCategory"}),
    #"Expanded StatusCategory" = Table.ExpandRecordColumn(#"Expanded Column1", "StatusCategory", 
        {"name", "colorName"}, 
        {"StatusCategory_Name", "StatusCategory_ColorName"})
in
    #"Expanded StatusCategory",

// =============================================================================
// PRIORITIES ENDPOINT
// =============================================================================
Priorities = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/priority", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "iconUrl", "statusColor"}, 
        {"Id", "Name", "IconUrl", "StatusColor"})
in
    #"Expanded Column1",

// =============================================================================
// DASHBOARDS ENDPOINT
// =============================================================================
Dashboards = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/dashboard/search", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[dashboards], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "view", "self"}, 
        {"Id", "Name", "View", "Self"})
in
    #"Expanded Column1"
