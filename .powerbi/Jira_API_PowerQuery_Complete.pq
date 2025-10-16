// =============================================================================
// COMPLETE JIRA API POWER QUERY CONNECTION
// Import this entire file into Power BI Desktop for live Jira API connections
// =============================================================================

// Base Configuration - UPDATE THESE VALUES
BaseUrl = "https://onemain-omfdirty.atlassian.net",
Username = "ben.kreischer.ce@omf.com",
ApiToken = "[YOUR_API_TOKEN]", // Replace with your actual API token

// Authentication Helper Function
GetAuthHeaders = () => [
    Authorization = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), 0),
    Accept = "application/json"
],

// =============================================================================
// PROJECTS - Single Project Details
// =============================================================================
Project_ORL = () => 
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
// ALL PROJECTS - Complete Project List
// =============================================================================
All_Projects = () => 
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
// ISSUES - Recent Issues Search
// =============================================================================
Recent_Issues = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/search?jql=order by created DESC&maxResults=100", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[issues], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "fields"}, 
        {"Id", "Key", "Fields"}),
    #"Expanded Fields" = Table.ExpandRecordColumn(#"Expanded Column1", "Fields", 
        {"summary", "status", "priority", "issuetype", "created", "updated", "assignee", "reporter"}, 
        {"Summary", "Status", "Priority", "IssueType", "Created", "Updated", "Assignee", "Reporter"}),
    #"Expanded Status" = Table.ExpandRecordColumn(#"Expanded Fields", "Status", 
        {"name", "statusCategory"}, 
        {"Status_Name", "StatusCategory"}),
    #"Expanded Priority" = Table.ExpandRecordColumn(#"Expanded Status", "Priority", 
        {"name"}, 
        {"Priority_Name"}),
    #"Expanded IssueType" = Table.ExpandRecordColumn(#"Expanded Priority", "IssueType", 
        {"name"}, 
        {"IssueType_Name"}),
    #"Expanded Assignee" = Table.ExpandRecordColumn(#"Expanded IssueType", "Assignee", 
        {"displayName", "emailAddress"}, 
        {"Assignee_Name", "Assignee_Email"}),
    #"Expanded Reporter" = Table.ExpandRecordColumn(#"Expanded Assignee", "Reporter", 
        {"displayName", "emailAddress"}, 
        {"Reporter_Name", "Reporter_Email"}),
    #"Expanded StatusCategory" = Table.ExpandRecordColumn(#"Expanded Reporter", "StatusCategory", 
        {"name"}, 
        {"StatusCategory_Name"})
in
    #"Expanded StatusCategory",

// =============================================================================
// USERS - All Users
// =============================================================================
All_Users = () => 
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
// ISSUE FIELDS - All Available Fields
// =============================================================================
All_Fields = () => 
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
// ISSUE TYPES - All Issue Types
// =============================================================================
All_IssueTypes = () => 
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
// STATUSES - All Statuses
// =============================================================================
All_Statuses = () => 
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
// PRIORITIES - All Priorities
// =============================================================================
All_Priorities = () => 
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
// DASHBOARDS - All Dashboards
// =============================================================================
All_Dashboards = () => 
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
