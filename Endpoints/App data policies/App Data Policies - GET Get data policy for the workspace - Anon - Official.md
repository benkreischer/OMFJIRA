# Endpoint Summary - App Data Policies - GET Get data policy for the workspace

## Endpoint Details
- **API Endpoint**: `/rest/api/3/data-policy`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/data-policy`
- **Method**: GET
- **Purpose**: Returns workspace-level data policy
- **File**: `App Data Policies - GET Get data policy for the workspace - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `App Data Policies - GET Get data policy for the workspace - Anon - Official.csv`
- **Total Records**: 0 (failed)
- **Total Columns**: N/A
- **File Size**: ~121 bytes
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## API Response Summary
- **Success**: ❌ API call failed
- **Error**: 401 Unauthorized
- **Issue**: Endpoint requires specific data policy admin permissions
- **Environment**: Production
- **Authentication**: ✅ Working (Basic auth successful for other endpoints)

## Error Details
- **HTTP Status**: 401 Unauthorized
- **Cause**: Insufficient permissions for workspace data policy access
- **Impact**: Cannot retrieve workspace data policy
- **Recommendation**: Requires admin-level access or different authentication

## Key Insights
- **Permission Level**: ⚠️ **ADMIN ACCESS REQUIRED** - This endpoint requires Jira Administrator permissions
- **Security**: Workspace data policies are restricted to administrative users only
- **Scope**: Endpoint targets workspace-level data policy configuration
- **Data Sensitivity**: Workspace data policies contain sensitive configuration information
- **Authentication**: Use admin credentials or API token with admin permissions

---
*Generated: 2025-10-07 19:25:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Failed - Permission Required*
