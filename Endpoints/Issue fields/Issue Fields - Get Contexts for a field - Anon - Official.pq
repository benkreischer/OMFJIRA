let
    // API Configuration
    // Load configuration parameters
Parameters = Load-EndpointParameters(),

// API Configuration from parameters
BaseUrl = Parameters[BaseUrl],
AuthHeader = Get-AuthHeader(Parameters),
    
    // Create Basic Auth Header
    AuthString = Username & ":" & ApiToken,
    AuthBytes = Text.ToBinary(AuthString, TextEncoding.Ascii),
    AuthHeader = "Basic " & Binary.ToText(AuthBytes, BinaryEncoding.Base64),
    
    // Use a known custom field ID (customfield_10612 - Category dropdown field)
    FieldId = "customfield_10612",
    
    // API Endpoint
    ApiUrl = BaseUrl & "/rest/api/3/field/" & FieldId & "/context",
    
    // Make API Call
    ApiResponse = Json.Document(
        Web.Contents(
            ApiUrl,
            [
                Headers = [
                    #"Authorization" = AuthHeader,
                    #"Accept" = "application/json"
                ]
            ]
        )
    ),
    
    // Extract values array from response
    Values = ApiResponse[values],
    
    // Convert to Table
    ContextsTable = Table.FromList(Values, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    
    // Expand Records
    ExpandedContexts = Table.ExpandRecordColumn(
        ContextsTable, 
        "Column1", 
        {
            "id", "name", "description", "isGlobalContext", "isAnyIssueType", "isDefaultContext"
        }, 
        {
            "Id", "Name", "Description", "IsGlobalContext", "IsAnyIssueType", "IsDefaultContext"
        }
    ),
    
    // Convert Boolean columns to text
    BooleanColumns = {"IsGlobalContext", "IsAnyIssueType", "IsDefaultContext"},
    ConvertedBooleans = Table.TransformColumns(
        ExpandedContexts,
        List.Transform(
            BooleanColumns,
            each {_, each if _ = null then "false" else Text.Lower(Text.From(_))}
        )
    ),
    
    // Final result
    Result = ConvertedBooleans
in
    Result

