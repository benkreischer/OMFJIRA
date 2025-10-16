// =============================================================================
// 17. ADMIN & ORGANIZATION MANAGEMENT ANALYTICS
// =============================================================================
// Comprehensive admin analytics for user management, permissions, and organizational insights

let
    // =============================================================================
    // AUTHENTICATION - HARDCODED FOR BEN KREISCHER
    // =============================================================================
    BaseUrl = "https://onemain.atlassian.net",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    // =============================================================================
    // 17.1 USER MANAGEMENT ANALYTICS
    // =============================================================================
    UsersUrl = BaseUrl & "/rest/api/3/users/search?maxResults=999999",
    UsersHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    UsersResponse = Json.Document(Web.Contents(UsersUrl, [Headers = UsersHeaders])),
    
    UsersTable = Table.FromList(UsersResponse, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedUsers = Table.ExpandRecordColumn(UsersTable, "Column1", 
        {"accountId", "accountType", "displayName", "emailAddress", "active", "timeZone", "locale", "groups"}, 
        {"Account ID", "Account Type", "Display Name", "Email", "Active", "Time Zone", "Locale", "Groups"}
    ),

    // =============================================================================
    // 17.2 GROUP MANAGEMENT ANALYTICS
    // =============================================================================
    GroupsUrl = BaseUrl & "/rest/api/3/group?maxResults=999999",
    GroupsHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    GroupsResponse = Json.Document(Web.Contents(GroupsUrl, [Headers = GroupsHeaders])),
    GroupsList = GroupsResponse[values],
    
    GroupsTable = Table.FromList(GroupsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedGroups = Table.ExpandRecordColumn(GroupsTable, "Column1", 
        {"name", "self", "users"}, 
        {"Group Name", "Group URL", "Users"}
    ),

    // =============================================================================
    // 17.3 PERMISSION ANALYSIS
    // =============================================================================
    PermissionsUrl = BaseUrl & "/rest/api/3/permissions",
    PermissionsHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    PermissionsResponse = Json.Document(Web.Contents(PermissionsUrl, [Headers = PermissionsHeaders])),
    PermissionsList = PermissionsResponse[permissions],
    
    PermissionsTable = Table.FromList(PermissionsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedPermissions = Table.ExpandRecordColumn(PermissionsTable, "Column1", 
        {"id", "key", "name", "type", "description", "havePermission"}, 
        {"Permission ID", "Permission Key", "Permission Name", "Type", "Description", "Have Permission"}
    ),

    // =============================================================================
    // 17.4 PROJECT PERMISSION SCHEMES
    // =============================================================================
    ProjectPermissionsUrl = BaseUrl & "/rest/api/3/permissionscheme?expand=permissions,user,group",
    ProjectPermissionsHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    ProjectPermissionsResponse = Json.Document(Web.Contents(ProjectPermissionsUrl, [Headers = ProjectPermissionsHeaders])),
    ProjectPermissionsList = ProjectPermissionsResponse[permissionSchemes],
    
    ProjectPermissionsTable = Table.FromList(ProjectPermissionsList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedProjectPermissions = Table.ExpandRecordColumn(ProjectPermissionsTable, "Column1", 
        {"id", "name", "description", "permissions"}, 
        {"Scheme ID", "Scheme Name", "Description", "Permissions"}
    ),

    // =============================================================================
    // 17.5 LICENSE USAGE TRACKING
    // =============================================================================
    LicenseUrl = BaseUrl & "/rest/api/3/license",
    LicenseHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    LicenseResponse = Json.Document(Web.Contents(LicenseUrl, [Headers = LicenseHeaders])),
    
    LicenseTable = Table.FromList({LicenseResponse}, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedLicense = Table.ExpandRecordColumn(LicenseTable, "Column1", 
        {"applications", "licenseType", "maxUsers", "unlimitedUsers"}, 
        {"Applications", "License Type", "Max Users", "Unlimited Users"}
    ),

    // =============================================================================
    // 17.6 AUDIT LOG ANALYSIS
    // =============================================================================
    AuditUrl = BaseUrl & "/rest/api/3/audit/records?from=2024-01-01&to=2024-12-31&limit=999999",
    AuditHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    AuditResponse = Json.Document(Web.Contents(AuditUrl, [Headers = AuditHeaders])),
    AuditRecords = AuditResponse[records],
    
    AuditTable = Table.FromList(AuditRecords, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedAudit = Table.ExpandRecordColumn(AuditTable, "Column1", 
        {"id", "summary", "category", "objectItem", "associatedItem", "created", "remoteAddress", "authorKey"}, 
        {"Audit ID", "Summary", "Category", "Object Item", "Associated Item", "Created", "Remote Address", "Author Key"}
    ),

    // =============================================================================
    // 17.7 SECURITY COMPLIANCE ANALYSIS
    // =============================================================================
    SecurityAnalysis = Table.AddColumn(ExpandedAudit, "Security Risk", each 
        if Text.Contains([Summary], "login") then "Authentication"
        else if Text.Contains([Summary], "permission") then "Authorization"
        else if Text.Contains([Summary], "delete") then "Data Modification"
        else if Text.Contains([Summary], "admin") then "Administrative"
        else "General"
    ),

    // =============================================================================
    // 17.8 USER ACTIVITY ANALYSIS
    // =============================================================================
    UserActivity = Table.Group(ExpandedAudit, {"Author Key"}, {
        {"Activity Count", each Table.RowCount(_), Int64.Type},
        {"Last Activity", each List.Max([Created]), type datetime},
        {"Categories", each Text.Combine(List.Distinct([Category]), ", "), type text}
    }),

    // =============================================================================
    // 17.9 INACTIVE USER DETECTION
    // =============================================================================
    InactiveUsers = Table.AddColumn(UserActivity, "User Status", each 
        if [Last Activity] < DateTime.AddDays(DateTime.LocalNow(), -30) then "Inactive"
        else if [Last Activity] < DateTime.AddDays(DateTime.LocalNow(), -7) then "Low Activity"
        else "Active"
    ),

    // =============================================================================
    // 17.10 PERMISSION OVERUSE ANALYSIS
    // =============================================================================
    PermissionOveruse = Table.AddColumn(ExpandedPermissions, "Permission Risk", each 
        if [Have Permission] = true and Text.Contains([Permission Name], "Admin") then "High Risk"
        else if [Have Permission] = true and Text.Contains([Permission Name], "Delete") then "Medium Risk"
        else if [Have Permission] = true then "Low Risk"
        else "No Access"
    ),

    // =============================================================================
    // 17.11 COST OPTIMIZATION RECOMMENDATIONS
    // =============================================================================
    CostOptimization = Table.AddColumn(InactiveUsers, "Cost Recommendation", each 
        if [User Status] = "Inactive" then "Consider deactivating user"
        else if [User Status] = "Low Activity" then "Monitor usage"
        else "User is active and valuable"
    ),

    // =============================================================================
    // 17.12 FINAL CLEANUP AND FORMATTING
    // =============================================================================
    // Convert dates
    DateConverted = Table.TransformColumns(CostOptimization, {
        {"Last Activity", DateTime.FromText}
    }),

    // Add date-only column
    FinalTable = Table.AddColumn(DateConverted, "Last Activity Date", each DateTime.Date([Last Activity])),

    // Remove original datetime column
    CleanTable = Table.RemoveColumns(FinalTable, {"Last Activity"}),

    // Sort by activity count descending
    SortedTable = Table.Sort(CleanTable, {{"Activity Count", Order.Descending}}),

    // Rename columns for better display
    RenamedTable = Table.RenameColumns(SortedTable, {
        {"Author Key", "User"},
        {"Activity Count", "Activity Count"},
        {"Categories", "Activity Categories"},
        {"User Status", "User Status"},
        {"Cost Recommendation", "Recommendation"},
        {"Last Activity Date", "Last Activity"}
    })
in
    RenamedTable
