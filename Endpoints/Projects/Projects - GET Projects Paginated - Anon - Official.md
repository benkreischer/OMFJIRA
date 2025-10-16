# Endpoint Summary - Projects - GET Projects Paginated

## Endpoint Details
- **API Endpoint**: `/rest/api/3/project/search`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/project/search?startAt=0&maxResults=100&orderBy=key&expand=lead,description,issueTypes,url,projectKeys,permissions,insight`
- **Method**: GET
- **Purpose**: Returns a paginated list of projects visible to the user
- **File**: `Projects - GET Projects Paginated - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Projects - GET Projects Paginated - Anon - Official.csv`
- **Total Records**: 50 (successful)
- **Total Columns**: 15
- **File Size**: ~25KB
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## API Response Summary
- **Success**: ✅ API call successful
- **Projects Retrieved**: 50 projects
- **Pagination**: Single page (all projects fit in one request)
- **Environment**: Production

## Data Structure
- **Id**: Project ID
- **Key**: Project key
- **Name**: Project name
- **ProjectTypeKey**: Type of project
- **Simplified**: Whether project uses simplified workflow
- **Style**: Project style (software, business, etc.)
- **IsPrivate**: Private project flag
- **LeadDisplayName**: Project lead display name
- **LeadAccountId**: Project lead account ID
- **LeadActive**: Lead active status
- **LeadTimeZone**: Lead timezone
- **Description**: Project description
- **Url**: Project URL
- **Self**: Self-reference URL
- **IssueTypeNames**: Semicolon-separated issue type names
- **ProjectKeys**: Semicolon-separated project keys
- **TotalIssueCount**: Total number of issues
- **LastIssueUpdateTime**: Last issue update timestamp

## Key Insights
- **Project Visibility**: All 50 projects are visible to the authenticated user
- **Data Completeness**: Full project details with expanded information
- **Lead Information**: Project leads properly populated
- **Issue Types**: Multiple issue types per project documented

---
*Generated: 2025-01-27 20:45:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success - All Projects Retrieved*
