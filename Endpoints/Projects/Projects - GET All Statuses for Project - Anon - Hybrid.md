# Endpoint Summary - Projects - GET All Statuses for Project (Hybrid)

## Endpoint Details
- **API Endpoint**: `/rest/api/3/project/search` + `/rest/api/3/project/{projectKey}/statuses`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/project/search` + individual project status endpoints
- **Method**: GET
- **Purpose**: Returns all projects with their key, name, and all statuses used within each project
- **File**: `Projects - GET All Statuses for Project - Anon - Hybrid.ps1`

## CSV Output Details
- **Output File**: `Projects - GET All Statuses for Project - Anon - Hybrid.csv`
- **Total Records**: 50 (successful)
- **Total Columns**: 4
- **File Size**: ~15KB
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## API Response Summary
- **Success**: ✅ API call successful
- **Projects Retrieved**: 50 projects processed
- **Status Collection**: Successfully collected statuses for all projects
- **Environment**: Production

## Data Structure
- **ProjectKey**: Unique project identifier
- **ProjectName**: Human-readable project name
- **ProjectStatuses**: Semicolon-separated list of all statuses used in the project
- **GeneratedAt**: Timestamp of data generation

## Key Insights
- **Comprehensive Coverage**: Successfully processed all 50 accessible projects
- **Status Aggregation**: Combines data from multiple API endpoints for complete view
- **Performance**: Efficient batch processing with progress indicators
- **Data Quality**: All projects returned valid status information

## Sample Data
```
ProjectKey: ACM (Adobe Campaign Migration)
ProjectName: Adobe Campaign Migration
ProjectStatuses: Acceptance; Achieved; Backlog; Blocked; Done; In Progress; Ready; To Do
```

---
*Generated: 2025-01-27 20:45:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success - All Projects Processed*
