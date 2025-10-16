# =============================================================================
# Fix All Endpoint PowerShell Scripts - Comprehensive Version
# =============================================================================
# This script fixes all .ps1 files in the .endpoints directory to use the
# correct API endpoints based on the comprehensive mapping extracted from
# Power Query files
# =============================================================================

$endpointsDir = ".endpoints"
$fixedCount = 0
$errorCount = 0

# Comprehensive API endpoint mappings extracted from Power Query files
$apiMappings = @{
    "Advanced Analytics" = @{
        "GET" = "/rest/api/3/analytics/team/"
    }
    "Advanced Permissions" = @{
        "GET" = "/rest/api/3/advanced-permissions/security-analytics/"
    }
    "Advanced Security" = @{
        "GET" = "/rest/api/3/advanced-security/threat-detection/"
    }
    "Advanced Workflows" = @{
        "GET" = "/rest/api/3/advanced-workflows/performance-analytics/"
    }
    "Announcement Banner" = @{
        "GET" = "/rest/api/3/announcementBanner"
        "PUT" = "/rest/api/3/announcementBanner"
    }
    "App Data Policies" = @{
        "GET" = "/rest/api/3/data-policy"
    }
    "App Migration" = @{
        "GET" = "/rest/atlassian-connect/1/migration/workflow/rule/search"
    }
    "App Properties" = @{
        "GET" = "/rest/api/3/application-properties/"
        "PUT" = "/rest/api/3/application-properties/"
    }
    "Application Roles" = @{
        "GET" = "/rest/api/3/applicationrole"
        "PUT" = "/rest/api/3/applicationrole/"
    }
    "Attachment Content" = @{
        "GET" = "/rest/api/3/attachment/thumbnail/"
    }
    "Attachments" = @{
        "DEL" = "/rest/api/3/attachment/"
        "GET" = "/rest/api/3/attachment/meta"
        "POST" = "/rest/api/3/issue/"
    }
    "Audit & Compliance" = @{
        "GET" = "/rest/api/3/audit-compliance/regulatory-analytics/"
    }
    "Audit Records" = @{
        "GET" = "/rest/api/3/auditing/record"
    }
    "Avatars" = @{
        "GET" = "/rest/api/3/avatar/"
    }
    "Bulk Permissions" = @{
        "GET" = "/rest/api/3/permissions/project"
    }
    "Classification Levels" = @{
        "GET" = "/rest/api/3/classification-levels"
        "POST" = "/rest/api/3/classification-levels"
        "PUT" = "/rest/api/3/classification-levels/"
    }
    "Comments" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/comment/list"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Component" = @{
        "DEL" = "/rest/api/3/component/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/component"
        "PUT" = "/rest/api/3/component/"
    }
    "Configuration" = @{
        "GET" = "/rest/api/3/configuration"
    }
    "Custom Field Contexts" = @{
        "DEL" = "/rest/api/3/field/"
        "GET" = "/rest/api/3/field/"
        "POST" = "/rest/api/3/field/"
        "PUT" = "/rest/api/3/field/"
    }
    "Custom Field Options" = @{
        "DEL" = "/rest/api/3/field/"
        "GET" = "/rest/api/3/field/"
        "POST" = "/rest/api/3/field/"
        "PUT" = "/rest/api/3/field/"
    }
    "Custom Fields" = @{
        "GET" = "/rest/api/3/field/search"
        "POST" = "/rest/api/3/field"
        "PUT" = "/rest/api/3/field/"
    }
    "Custom Reports" = @{
        "GET" = "/rest/api/3/search"
    }
    "Dashboards" = @{
        "DEL" = "/rest/api/3/dashboard/"
        "GET" = "/rest/api/3/dashboard/search"
        "POST" = "/rest/api/3/dashboard"
        "PUT" = "/rest/api/3/dashboard/"
    }
    "Dynamic Modules" = @{
        "GET" = "/rest/api/3/dynamic-modules"
        "POST" = "/rest/api/3/dynamic-modules"
    }
    "Enterprise Features" = @{
        "GET" = "/rest/api/3/enterprise/user-management/organization/"
    }
    "Filter Sharing" = @{
        "GET" = "/rest/api/3/filter/defaultShareScope"
        "PUT" = "/rest/api/3/filter/defaultShareScope"
    }
    "Filters" = @{
        "DEL" = "/rest/api/3/filter/"
        "GET" = "/rest/api/3/filter/"
        "POST" = "/rest/api/3/filter"
        "PUT" = "/rest/api/3/filter/"
    }
    "Group and User Pickers" = @{
        "GET" = "/rest/api/3/groupuserpicker"
    }
    "Groups" = @{
        "DEL" = "/rest/api/3/group/user"
        "GET" = "/rest/api/3/group/member"
        "POST" = "/rest/api/3/group"
    }
    "Integration Management" = @{
        "GET" = "/rest/api/3/integration-management/third-party/"
    }
    "Issue Attachments" = @{
        "GET" = "/rest/api/3/attachment/meta"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Bulk Operations" = @{
        "POST" = "/rest/api/3/issue/bulk"
    }
    "Issue Comment Properties" = @{
        "DEL" = "/rest/api/3/comment/"
        "GET" = "/rest/api/3/comment/"
        "PUT" = "/rest/api/3/comment/"
    }
    "Issue Custom Field Associations" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Custom Field Configuration (Apps)" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Issue Custom Field Values (Apps)" = @{
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Issue Field Configurations" = @{
        "GET" = "/rest/api/3/fieldconfigurationscheme/project"
    }
    "Issue Fields" = @{
        "GET" = "/rest/api/3/field/"
        "POST" = "/rest/api/3/field"
    }
    "Issue Link Types" = @{
        "DEL" = "/rest/api/3/issueLinkType/"
        "GET" = "/rest/api/3/issueLinkType"
        "POST" = "/rest/api/3/issueLinkType"
        "PUT" = "/rest/api/3/issueLinkType/"
    }
    "Issue Links" = @{
        "DEL" = "/rest/api/3/issueLink/"
        "GET" = "/rest/api/3/issueLink/"
        "POST" = "/rest/api/3/issueLink"
    }
    "Issue Navigator" = @{
        "GET" = "/rest/api/3/issue/picker"
    }
    "Issue Navigator Settings" = @{
        "GET" = "/rest/api/3/settings/columns"
        "PUT" = "/rest/api/3/settings/columns"
    }
    "Issue Notification Schemes" = @{
        "GET" = "/rest/api/3/notificationscheme"
        "POST" = "/rest/api/3/notificationscheme"
    }
    "Issue Priorities" = @{
        "GET" = "/rest/api/3/priority/"
    }
    "Issue Properties" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Issue Redaction" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Remote Links" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Issue Resolutions" = @{
        "GET" = "/rest/api/3/resolution"
    }
    "Issue Search" = @{
        "GET" = "/rest/api/3/search"
        "POST" = "/rest/api/3/search"
    }
    "Issue Security Level" = @{
        "GET" = "/rest/api/3/issuesecurityschemes"
        "POST" = "/rest/api/3/issuesecurityschemes"
    }
    "Issue Security Schemes" = @{
        "GET" = "/rest/api/3/issuesecurityschemes"
    }
    "Issue Type Properties" = @{
        "DEL" = "/rest/api/3/issuetype/"
        "GET" = "/rest/api/3/issuetype/"
        "POST" = "/rest/api/3/issuetype/"
    }
    "Issue Type Schemes" = @{
        "DEL" = "/rest/api/3/issuetypescheme/"
        "GET" = "/rest/api/3/issuetypescheme/project"
        "POST" = "/rest/api/3/issuetypescheme"
        "PUT" = "/rest/api/3/issuetypescheme/"
    }
    "Issue Type Screen Schemes" = @{
        "DEL" = "/rest/api/3/issuetypescreenscheme/"
        "GET" = "/rest/api/3/issuetypescreenscheme/project"
        "POST" = "/rest/api/3/issuetypescreenscheme"
        "PUT" = "/rest/api/3/issuetypescreenscheme/"
    }
    "Issue Types" = @{
        "DEL" = "/rest/api/3/issuetype/"
        "GET" = "/rest/api/3/issuetype/project"
        "POST" = "/rest/api/3/issuetype"
        "PUT" = "/rest/api/3/issuetype/"
    }
    "Issue Votes" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Watchers" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Worklog Properties" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
    }
    "Issue Worklogs" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Issues" = @{
        "DEL" = "/rest/api/3/issue/"
        "GET" = "/rest/api/3/issue/"
        "POST" = "/rest/api/3/issue/"
        "PUT" = "/rest/api/3/issue/"
    }
    "Jira Expressions" = @{
        "POST" = "/rest/api/3/expression/eval"
    }
    "Jira Settings" = @{
        "GET" = "/rest/api/3/application-properties"
        "PUT" = "/rest/api/3/application-properties/"
    }
    "JQL" = @{
        "GET" = "/rest/api/3/jql/function/search"
        "POST" = "/rest/api/3/jql/parse"
    }
    "JQL Functions (Apps)" = @{
        "GET" = "/rest/api/3/jql/functions"
        "POST" = "/rest/api/3/jql/functions/"
    }
    "Labels" = @{
        "GET" = "/rest/api/3/label"
    }
    "License Metrics" = @{
        "GET" = "/rest/api/3/license-metrics/usage"
    }
    "Myself" = @{
        "GET" = "/rest/api/3/myself"
    }
    "Permission Schemes" = @{
        "DEL" = "/rest/api/3/permissionscheme/"
        "GET" = "/rest/api/3/permissionscheme"
        "POST" = "/rest/api/3/permissionscheme"
        "PUT" = "/rest/api/3/permissionscheme/"
    }
    "Permissions" = @{
        "GET" = "/rest/api/3/permissions"
    }
    "Plans" = @{
        "DEL" = "/rest/api/3/plan/"
        "GET" = "/rest/api/3/plan"
        "POST" = "/rest/api/3/plan"
        "PUT" = "/rest/api/3/plan/"
    }
    "Priority Schemes" = @{
        "GET" = "/rest/api/3/priorityschemes"
    }
    "Project Avatars" = @{
        "DEL" = "/rest/api/3/project/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Project Categories" = @{
        "DEL" = "/rest/api/3/projectCategory/"
        "GET" = "/rest/api/3/projectCategory/"
        "POST" = "/rest/api/3/projectCategory"
        "PUT" = "/rest/api/3/projectCategory/"
    }
    "Project Classification Levels" = @{
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/project/"
    }
    "Project Components" = @{
        "DEL" = "/rest/api/3/component/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/component"
        "PUT" = "/rest/api/3/component/"
    }
    "Project Email" = @{
        "GET" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Project Features" = @{
        "GET" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Project Key and Name Validation" = @{
        "GET" = "/rest/api/3/projectvalidate/validProjectName"
    }
    "Project Permission Schemes" = @{
        "GET" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Project Properties" = @{
        "DEL" = "/rest/api/3/project/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Project Roles" = @{
        "DEL" = "/rest/api/3/role/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/role"
        "PUT" = "/rest/api/3/role/"
    }
    "Project Templates" = @{
        "GET" = "/rest/api/3/project-template"
        "POST" = "/rest/api/3/project"
    }
    "Project Types" = @{
        "GET" = "/rest/api/3/project/type"
    }
    "Project Versions" = @{
        "DEL" = "/rest/api/3/version/"
        "GET" = "/rest/api/3/project/"
        "POST" = "/rest/api/3/version"
        "PUT" = "/rest/api/3/version/"
    }
    "Projects" = @{
        "DEL" = "/rest/api/3/project/"
        "GET" = "/rest/api/3/project/recent"
        "POST" = "/rest/api/3/project/"
        "PUT" = "/rest/api/3/project/"
    }
    "Screen Schemes" = @{
        "DEL" = "/rest/api/3/screenscheme/"
        "GET" = "/rest/api/3/screenscheme"
        "POST" = "/rest/api/3/screenscheme"
        "PUT" = "/rest/api/3/screenscheme/"
    }
    "Screen Tab Fields" = @{
        "DEL" = "/rest/api/3/screens/"
        "GET" = "/rest/api/3/screens/"
        "POST" = "/rest/api/3/screens/"
    }
    "Screen Tabs" = @{
        "DEL" = "/rest/api/3/screens/"
        "GET" = "/rest/api/3/screens/"
        "POST" = "/rest/api/3/screens/"
        "PUT" = "/rest/api/3/screens/"
    }
    "Screens" = @{
        "DEL" = "/rest/api/3/screens/"
        "GET" = "/rest/api/3/screens"
        "POST" = "/rest/api/3/screens"
        "PUT" = "/rest/api/3/screens/"
    }
    "Server Info" = @{
        "GET" = "/rest/api/3/serverInfo"
    }
    "Service Registry" = @{
        "GET" = "/rest/api/3/service-registry/"
    }
    "Status" = @{
        "GET" = "/rest/api/3/status"
        "POST" = "/rest/api/3/status"
        "PUT" = "/rest/api/3/status/"
    }
    "Time Tracking" = @{
        "GET" = "/rest/api/3/configuration/timetracking/list"
        "PUT" = "/rest/api/3/configuration/timetracking"
    }
    "UI Modifications (Apps)" = @{
        "GET" = "/rest/api/3/ui-modifications"
        "POST" = "/rest/api/3/ui-modifications"
    }
    "User Properties" = @{
        "DEL" = "/rest/api/3/user/properties/"
        "GET" = "/rest/api/3/user/properties/"
        "POST" = "/rest/api/3/user/properties/"
        "PUT" = "/rest/api/3/user/properties/"
    }
    "User Search" = @{
        "GET" = "/rest/api/3/user/search/username"
    }
    "Users" = @{
        "DEL" = "/rest/api/3/user"
        "GET" = "/rest/api/3/users/search"
        "POST" = "/rest/api/3/user"
        "PUT" = "/rest/api/3/user"
    }
    "Workflows" = @{
        "GET" = "/rest/api/3/workflow"
    }
}

Write-Host "Starting comprehensive fix of all endpoint PowerShell scripts..." -ForegroundColor Green
Write-Host "Scanning directory: $endpointsDir" -ForegroundColor Cyan

# Get all .ps1 files in the endpoints directory
$ps1Files = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1"

foreach ($file in $ps1Files) {
    try {
        Write-Host "Processing: $($file.FullName)" -ForegroundColor Yellow
        
        # Read the file content
        $content = Get-Content -Path $file.FullName -Raw
        
        # Extract category and HTTP method from filename
        $fileName = $file.BaseName
        $category = ""
        $httpMethod = ""
        
        # Parse filename to extract category and method
        if ($fileName -match "^([^-]+)\s*-\s*(GET|POST|PUT|DEL|DELETE)\s+(.+)$") {
            $category = $matches[1].Trim()
            $httpMethod = $matches[2].Trim()
        }
        
        # Skip if we can't parse the filename
        if (-not $category -or -not $httpMethod) {
            Write-Host "Skipping $fileName - cannot parse category/method" -ForegroundColor Yellow
            continue
        }
        
        # Get the correct API endpoint
        $correctEndpoint = ""
        if ($apiMappings.ContainsKey($category) -and $apiMappings[$category].ContainsKey($httpMethod)) {
            $correctEndpoint = $apiMappings[$category][$httpMethod]
        } else {
            # Try to find a partial match
            foreach ($key in $apiMappings.Keys) {
                if ($category -like "*$key*" -or $key -like "*$category*") {
                    if ($apiMappings[$key].ContainsKey($httpMethod)) {
                        $correctEndpoint = $apiMappings[$key][$httpMethod]
                        break
                    }
                }
            }
        }
        
        if (-not $correctEndpoint) {
            Write-Host "No mapping found for $category - $httpMethod" -ForegroundColor Yellow
            continue
        }
        
        # Replace the generic endpoint with the correct one
        $oldPattern = '\$apiPath = "/rest/api/3/field"'
        $newPattern = "`$apiPath = `"$correctEndpoint`""
        
        if ($content -match $oldPattern) {
            $content = $content -replace [regex]::Escape($oldPattern), $newPattern
            Write-Host "Fixed endpoint for $category - $httpMethod : $correctEndpoint" -ForegroundColor Green
            
            # Write the updated content back to the file
            Set-Content -Path $file.FullName -Value $content -NoNewline
            $fixedCount++
        } else {
            Write-Host "No generic endpoint found in $fileName" -ForegroundColor Blue
        }
        
    } catch {
        Write-Host "Error processing $($file.FullName): $($_.Exception.Message)" -ForegroundColor Red
        $errorCount++
    }
}

Write-Host ""
Write-Host "Comprehensive fix completed!" -ForegroundColor Green
Write-Host "Files fixed: $fixedCount" -ForegroundColor Green
Write-Host "Errors: $errorCount" -ForegroundColor Red
Write-Host "Total files processed: $($ps1Files.Count)" -ForegroundColor Cyan
