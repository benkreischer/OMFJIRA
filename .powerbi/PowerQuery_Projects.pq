// =============================================================================
// PROJECTS - Single Project Details
// Import this into Power BI Desktop as a new query
// =============================================================================

let
    // Base Configuration - UPDATE THESE VALUES
    BaseUrl = "https://onemain-omfdirty.atlassian.net",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "[YOUR_API_TOKEN]", // Replace with your actual API token

    // Authentication Helper Function
    GetAuthHeaders = () => [
        Authorization = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), 0),
        Accept = "application/json"
    ],

    // Get ORL Project Data
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
    #"Expanded Insight"
