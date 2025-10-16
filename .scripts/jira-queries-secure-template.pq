// =============================================================================
// JIRA QUERIES - SECURE TEMPLATE
// =============================================================================

// This template shows how to create secure Jira queries without embedded credentials
// Replace the placeholder values with your actual configuration

let
    // Read credentials from Excel named ranges (set up by Authentication Manager)`n    // =============================================================================
    // CONFIGURATION SECTION - MODIFY THESE VALUES
    // =============================================================================
    
    // Option 1: Direct configuration (for personal use)
    BaseUrl = "https://YOUR-DOMAIN.atlassian.net",  // Replace with your Jira domain
    Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],            // Replace with your email
    ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],               // Replace with your API token
    
    // Option 2: Environment variables (recommended for team use)
    // BaseUrl = Environment.GetEnvironmentVariable("JIRA_BASE_URL"),
    // Username = Environment.GetEnvironmentVariable("JIRA_USERNAME"),
    // ApiToken = Environment.GetEnvironmentVariable("JIRA_API_TOKEN"),
    
    // Option 3: Excel cell references (for dynamic queries)
    // BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
    // Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
    // ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
    
    // =============================================================================
    // API CONFIGURATION
    // =============================================================================
    
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64) & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // =============================================================================
    // EXAMPLE QUERY - SEARCH ISSUES
    // =============================================================================
    
    // Modify this JQL query as needed
    JQLQuery = "ORDER BY updated DESC",
    EncodedJQL = Uri.EscapeDataString(JQLQuery),
    Url = BaseUrl & "/search?jql=" & EncodedJQL & "&maxResults=999999",
    
    // Make API call
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    
    // Extract and process issues
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(
        Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), 
        "Fields", 
        {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "duedate", "resolutiondate"}, 
        {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Due Date", "Resolution Date"}
    ),
    
    // =============================================================================
    // DATE CONVERSION (ALWAYS INCLUDE THIS)
    // =============================================================================
    
    // Convert date fields from text to proper date/time
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
        {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
    }),
    
    // Add calculated date columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Add time-based calculated columns
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number)
    
in
    AddTimeColumns4

// =============================================================================
// SETUP INSTRUCTIONS
// =============================================================================

// 1. Choose your configuration method:
//    - Option 1: Direct configuration (easiest for personal use)
//    - Option 2: Environment variables (best for team use)
//    - Option 3: Excel cell references (best for dynamic queries)

// 2. Replace the placeholder values with your actual Jira configuration

// 3. Modify the JQL query to match your needs

// 4. Test the query and adjust as needed

// 5. For team sharing, use Option 2 or 3 to avoid embedding credentials

