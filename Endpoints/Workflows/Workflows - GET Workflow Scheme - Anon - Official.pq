// =============================================================================
// ENDPOINT: Workflows - GET Workflow Scheme
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflows/#api-rest-api-3-workflowscheme-id-get
//
// DESCRIPTION: Returns a workflow scheme.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'WorkflowSchemeId' parameter.
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // =============================================================================
    // PARAMETERS
    // =============================================================================
    WorkflowSchemeId = "10000", // <-- IMPORTANT: Replace with the ID of the workflow scheme
    ReturnDraftIfExists = "false", // <-- OPTIONAL: Whether to return the draft workflow scheme if it exists

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/workflowscheme/" & WorkflowSchemeId,
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                returnDraftIfExists = ReturnDraftIfExists
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

