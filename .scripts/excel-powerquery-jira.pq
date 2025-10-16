// Excel Power Query M code for Jira API integration
// Add this as a new query in Excel's Power Query Editor

let
    // Configuration
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    
    // Create authentication header
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Function to call Jira API
    CallJiraAPI = (endpoint as text) =>
    let
        Url = BaseUrl & "/" & endpoint,
        Headers = [
            #"Authorization" = AuthHeader,
            #"Content-Type" = "application/json"
        ],
        Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
        Result = Response
    in
        Result,
    
    // Get workflows
    Workflows = CallJiraAPI("workflow"),
    WorkflowsTable = Table.FromList(Workflows, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    WorkflowsExpanded = Table.ExpandRecordColumn(WorkflowsTable, "Column1", {"name", "description", "steps", "default", "lastModifiedDate"}, {"Name", "Description", "Steps", "Default", "Last Modified"}),
    
    // Get projects
    Projects = CallJiraAPI("project"),
    ProjectsTable = Table.FromList(Projects, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ProjectsExpanded = Table.ExpandRecordColumn(ProjectsTable, "Column1", {"key", "name", "projectTypeKey", "lead"}, {"Key", "Name", "Type", "Lead"})
    
in
    // Return workflows table (you can change this to ProjectsExpanded for projects)
    WorkflowsExpanded
