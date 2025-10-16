// =============================================================================
// ENDPOINT: Webhooks - GET Webhooks (OAuth2)
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-webhooks/
//
// DESCRIPTION: Returns a paginated list of the webhooks registered by the calling app.
//              This version uses OAuth 2.0 authentication for proper webhook access.
//
// PREREQUISITES:
// 1. OAuth2 Application registered in Atlassian Developer Console
// 2. Valid OAuth2 access token obtained
// 3. Appropriate scopes configured (read:jira-work, manage:jira-webhook)
//
// SETUP:
// 1. Replace the OAuth2 configuration values below
// 2. Ensure your access token is valid and has proper scopes
// 3. Load this query in Power BI / Excel Power Query
//
// =============================================================================

let
    // =============================================================================
    // OAUTH2 CONFIGURATION - Replace with your actual values
    // =============================================================================
    BaseUrl = "https://onemain.atlassian.net",
    AccessToken = "YOUR_OAUTH2_ACCESS_TOKEN_HERE",

    // OAuth2 Configuration Info (for reference)
    RequiredScopes = "read:jira-work manage:jira-webhook",
    AuthUrl = "https://auth.atlassian.com/authorize",
    TokenUrl = "https://auth.atlassian.com/oauth/token",

    // =============================================================================
    // VALIDATION
    // =============================================================================
    IsConfigured = AccessToken <> "YOUR_OAUTH2_ACCESS_TOKEN_HERE",

    // =============================================================================
    // API CALL CONFIGURATION
    // =============================================================================
    Endpoint = "/rest/api/3/webhook",
    FullUrl = BaseUrl & Endpoint,

    // OAuth2 Bearer Token Headers
    Headers = [
        #"Authorization" = "Bearer " & AccessToken,
        #"Accept" = "application/json",
        #"Content-Type" = "application/json"
    ],

    // =============================================================================
    // API CALL OR SETUP INSTRUCTIONS
    // =============================================================================
    Response =
        if not IsConfigured then
            // Return setup instructions if not configured
            [
                Step = "Setup Required",
                Action = "Configure OAuth2",
                Instructions = "Replace YOUR_OAUTH2_ACCESS_TOKEN_HERE with actual token",
                RequiredScopes = RequiredScopes,
                AuthorizeUrl = AuthUrl,
                TokenUrl = TokenUrl,
                Documentation = "https://developer.atlassian.com/cloud/jira/platform/oauth-2-3lo-apps/"
            ]
        else
            // Make API call with OAuth2
            try
                Json.Document(Web.Contents(FullUrl, [Headers=Headers]))
            otherwise
                [
                    Error = "OAuth2 Authentication Failed",
                    PossibleCauses = "Token expired, invalid, or insufficient scopes",
                    RequiredScopes = RequiredScopes,
                    TokenRefresh = "Use OAuth2 refresh token to get new access token",
                    GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
                ],

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result =
        if not IsConfigured then
            // Return setup instructions as table
            Table.FromRecords({Response})
        else if Record.HasFields(Response, "Error") then
            // Return error information as table
            Table.FromRecords({Response})
        else if Value.Is(Response, type list) then
            // Response is a list/array of webhooks
            if List.Count(Response) > 0 then
                Table.FromRecords(Response)
            else
                Table.FromRecords({[
                    Message = "No webhooks found",
                    AuthenticationMethod = "OAuth2",
                    GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
                ]})
        else if Record.HasFields(Response, "values") then
            // Paginated response structure
            if List.Count(Response[values]) > 0 then
                Table.FromRecords(Response[values])
            else
                Table.FromRecords({[
                    Message = "No webhooks found in paginated response",
                    AuthenticationMethod = "OAuth2",
                    GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
                ]})
        else if Value.Is(Response, type record) then
            // Single record response
            Table.FromRecords({Response})
        else
            // Unexpected response format
            Table.FromRecords({[
                Message = "Unexpected response format",
                AuthenticationMethod = "OAuth2",
                GeneratedAt = DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss")
            ]})

in
    Result