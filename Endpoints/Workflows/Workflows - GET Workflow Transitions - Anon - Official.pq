// =============================================================================
// ENDPOINT: Workflows - GET Workflow Transitions
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflows/#api-rest-api-3-workflow-id-transitions-get
//
// DESCRIPTION: Returns the transitions for a workflow.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Update the 'WorkflowId' parameter.
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
    WorkflowId = "10000", // <-- IMPORTANT: Replace with the ID of the workflow
    TransitionId = "", // <-- OPTIONAL: The ID of the transition
    Expand = "transitions.fields", // <-- OPTIONAL: Use expand to include additional information

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "/rest/api/3/workflow/" & WorkflowId & "/transitions",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(
        Web.Contents(FullUrl, [
            Headers = [
                #"Authorization" = AuthHeader, 
                #"Accept" = "application/json"
            ],
            Query = [
                transitionId = TransitionId,
                expand = Expand
            ]
        ])
    ),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Result = Response
in
    Result

