// =============================================================================
// ENDPOINT: Webhooks - GET Webhooks
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-webhooks/
//
// DESCRIPTION: Returns a paginated list of the webhooks registered by the calling app.
//
// NOTE: This endpoint requires OAuth 2.0 authentication and app-specific permissions.
//       It will return 403 Forbidden with Basic Auth as webhooks are app-scoped.
//       Only the app that created webhooks can access them.
//
// SETUP:
// 1. Replace the authentication values below with your actual credentials
// 2. Load this query in Power BI / Excel Power Query
// 3. Note: Will show authentication limitation with Basic Auth
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION - Replace with your actual values
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),

    // =============================================================================
    // API CALL CONFIGURATION
    // =============================================================================
    Endpoint = "/rest/api/3/webhook",
    FullUrl = BaseUrl & Endpoint,

    // Create authentication header
    AuthString = Username & ":" & ApiToken,
    AuthBytes = Text.ToBinary(AuthString),
    AuthEncoded = Binary.ToText(AuthBytes, BinaryEncoding.Base64),

    Headers = [
        #"Authorization" = "Basic " & AuthEncoded,
        #"Accept" = "application/json",
        #"Content-Type" = "application/json"
    ],

    // =============================================================================
    // API CALL
    // =============================================================================
    Response =
        try
            Json.Document(Web.Contents(FullUrl, [Headers=Headers]))
        otherwise
            [
                Error = "Authentication Error - This endpoint requires OAuth 2.0",
                Reason = "Webhooks endpoint is app-scoped and requires app-specific permissions",
                Authentication = "OAuth 2.0 required (Basic Auth not supported)",
                GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
            ],

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result =
        if Record.HasFields(Response, "Error") then
            // Return error information as table
            Table.FromRecords({Response})
        else if Value.Is(Response, type list) then
            // Response is a list/array
            if List.Count(Response) > 0 then
                Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
            else
                Table.FromRecords({[Message = "No webhooks found", GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")]})
        else if Record.HasFields(Response, "values") then
            // Paginated response structure
            if List.Count(Response[values]) > 0 then
                Table.FromRecords(Response[values])
            else
                Table.FromRecords({[Message = "No webhooks found", GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")]})
        else if Value.Is(Response, type record) then
            // Single record response
            Table.FromRecords({Response})
        else
            // Unexpected response format
            Table.FromRecords({[Message = "Unexpected response format", GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")]})

in
    Result
