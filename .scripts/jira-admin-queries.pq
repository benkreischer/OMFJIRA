// Comprehensive Jira Admin Power Query Templates
// Copy individual queries as needed for your Excel workbook

// =============================================================================
// CONFIGURATION (Update these values)
// =============================================================================
let
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Helper function for API calls
    CallJiraAPI = (endpoint as text) =>
    let
        Url = BaseUrl & "/" & endpoint,
        Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
        Response = Json.Document(Web.Contents(Url, [Headers = Headers]))
    in
        Response
in
    "Configuration loaded - use individual queries below"
