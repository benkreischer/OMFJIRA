let
    // Load configuration parameters
    Parameters = Load-EndpointParameters(),
    
    // API Configuration from parameters
    BaseUrl = Parameters[BaseUrl],
    AuthHeader = Get-AuthHeader(Parameters),
    
    // API Endpoint
    ApiUrl = BaseUrl & "/rest/api/3/field",
    
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
    
    // Convert to Table
    FieldsTable = Table.FromList(ApiResponse, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    
    // Expand Records
    ExpandedFields = Table.ExpandRecordColumn(
        FieldsTable, 
        "Column1", 
        {
            "id", "key", "name", "custom", "orderable", "navigable", 
            "searchable", "clauseNames", "schema", "scope"
        }, 
        {
            "Id", "Key", "Name", "Custom", "Orderable", "Navigable", 
            "Searchable", "ClauseNames", "Schema", "Scope"
        }
    ),
    
    // Handle Schema Column (Record)
    SchemaExpanded = Table.ExpandRecordColumn(
        ExpandedFields,
        "Schema",
        {"type", "items", "system", "custom", "customId", "configuration"},
        {"SchemaType", "SchemaItems", "SchemaSystem", "SchemaCustom", "SchemaCustomId", "SchemaConfiguration"}
    ),
    
    // Handle Scope Column (Record)
    ScopeExpanded = Table.ExpandRecordColumn(
        SchemaExpanded,
        "Scope",
        {"type", "project"},
        {"ScopeType", "ScopeProject"}
    ),
    
    // Handle ScopeProject Column (Record)
    ScopeProjectExpanded = Table.ExpandRecordColumn(
        ScopeExpanded,
        "ScopeProject",
        {"id", "key"},
        {"ScopeProjectId", "ScopeProjectKey"}
    ),
    
    // Handle ClauseNames Array
    ClauseNamesExpanded = Table.TransformColumns(
        ScopeProjectExpanded,
        {"ClauseNames", each if _ = null then "" else Text.Combine(_, "; ")}
    ),
    
    // Convert Boolean columns to text
    BooleanColumns = {"Custom", "Orderable", "Navigable", "Searchable"},
    ConvertedBooleans = Table.TransformColumns(
        ClauseNamesExpanded,
        List.Transform(
            BooleanColumns,
            each {_, each if _ = null then "false" else Text.Lower(Text.From(_))}
        )
    ),
    
    // Final result
    Result = ConvertedBooleans
in
    Result
