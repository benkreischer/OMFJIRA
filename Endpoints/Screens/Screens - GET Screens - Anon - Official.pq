// =============================================================================
// ENDPOINT: Screens - GET Screens
// =============================================================================
//
// API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-screens/
//
// DESCRIPTION: Returns screens using basic authentication.
// This endpoint provides access to screen management.
//
// SETUP: 
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
// 2. Load the data
//
// =============================================================================

let
    // =============================================================================
    // CONFIGURATION SECTION
    // =============================================================================
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // =============================================================================
    // PAGINATION CONFIGURATION
    // =============================================================================
    MaxResults = 100,
    
    // =============================================================================
    // PAGINATION FUNCTION
    // =============================================================================
    GetScreensPage = (StartAt as number) =>
        let
            Endpoint = "/rest/api/3/screens?startAt=" & Number.ToText(StartAt) & "&maxResults=" & Number.ToText(MaxResults),
            FullUrl = BaseUrl & Endpoint,
            
            Response = Json.Document(
                Web.Contents(FullUrl, [
                    Headers = [
                        #"Authorization" = AuthHeader,
                        #"Accept" = "application/json"
                    ]
                ])
            )
        in
            Response,
    
    // =============================================================================
    // PAGINATION LOOP
    // =============================================================================
    GetAllScreens = (StartAt as number, AccumulatedScreens as list) =>
        let
            CurrentPage = GetScreensPage(StartAt),
            CurrentScreens = if CurrentPage[error] = null and CurrentPage[values] <> null then CurrentPage[values] else {},
            NewAccumulatedScreens = List.Combine({AccumulatedScreens, CurrentScreens}),
            IsLastPage = CurrentPage[isLast] = true,
            NextStartAt = StartAt + MaxResults,
            Result = if IsLastPage then NewAccumulatedScreens else GetAllScreens(NextStartAt, NewAccumulatedScreens)
        in
            Result,
    
    // =============================================================================
    // GET ALL SCREENS WITH PAGINATION
    // =============================================================================
    AllScreensData = GetAllScreens(0, {}),
    
    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    Screens = if List.Count(AllScreensData) > 0 then
        let
            // Convert to table
            ScreensTable = Table.FromList(AllScreensData, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            
            // Expand screen records
            ExpandedScreens = Table.ExpandRecordColumn(ScreensTable, "Column1", 
                {"id", "name", "description", "scope"}, 
                {"Id", "Name", "Description", "Scope"}),
            
            // Add generated timestamp
            FinalTable = Table.AddColumn(ExpandedScreens, "GeneratedAt", each DateTime.ToText(DateTime.LocalNow(), "yyyy-MM-dd HH:mm:ss"))
        in
            FinalTable
    else
        #table({"Id", "Name", "Description", "Scope", "GeneratedAt"}, {})
    
    // =============================================================================
    // RESULT
    // =============================================================================
    Result = Screens
in
    Result

