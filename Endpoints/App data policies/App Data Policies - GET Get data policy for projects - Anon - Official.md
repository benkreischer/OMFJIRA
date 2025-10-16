# Endpoint Summary - App Data Policies - GET Get data policy for projects

## Endpoint Details
- **API Endpoint**: `/rest/api/3/data-policy/project`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/data-policy/project?ids=10372,10122,10114`
- **Method**: GET
- **Purpose**: Returns data policies for specific projects
- **File**: `App Data Policies - GET Get data policy for projects - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `App Data Policies - GET Get data policy for projects - Anon - Official.csv`
- **Total Records**: 0 (failed)
- **Total Columns**: N/A
- **File Size**: ~76 bytes
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## API Response Summary
- **Success**: ❌ API call failed
- **Error**: 401 Unauthorized
- **Issue**: Endpoint requires specific data policy admin permissions
- **Environment**: Production
- **Authentication**: ✅ Working (Basic auth successful for other endpoints)

## Error Details
- **HTTP Status**: 401 Unauthorized
- **Cause**: Insufficient permissions for data policy access
- **Impact**: Cannot retrieve project data policies
- **Recommendation**: Requires admin-level access or different authentication

## Key Insights
- **Permission Level**: ⚠️ **ADMIN ACCESS REQUIRED** - This endpoint requires Jira Administrator permissions
- **Security**: Data policies are restricted to administrative users only
- **Project Scope**: Endpoint targets specific project IDs (10372, 10122, 10114)
- **Data Sensitivity**: App data policies contain sensitive configuration information
- **Authentication**: Use admin credentials or API token with admin permissions

---
*Generated: 2025-10-07 19:25:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Failed - Permission Required*
