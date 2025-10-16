# Endpoint Summary - Dashboards - GET Search for dashboards

## Endpoint Details
- **API Endpoint**: `/rest/api/3/dashboard/search`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/dashboard/search`
- **Method**: GET
- **Purpose**: Returns a paginated list of dashboards matching search criteria
- **File**: `Dashboards - GET Search for dashboards - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Dashboards - GET Search for dashboards - Anon - Official.csv`
- **Total Records**: 788 dashboards (all pages)
- **Total Columns**: Multiple (varies based on response)
- **File Size**: ~77KB
- **Generated**: 2025-10-08 05:00:00

## API Response Summary
- **Success**: ✅ API call successful
- **Dashboards Retrieved**: 788 dashboards (all pages via pagination)
- **Search Capability**: Supports filtering and searching
- **Environment**: Production
- **Pagination**: Automatically fetches all pages (50 records per page, 16 pages total)

## Data Structure
- **id**: Dashboard ID
- **name**: Dashboard name
- **Additional fields**: Varies based on response structure

## Key Insights
- **Complete Dataset**: Now fetches all 788 dashboards automatically
- **Search Functionality**: Provides dashboard search capabilities
- **Pagination Implemented**: Automatically handles all pages (50 per page)
- **Flexible**: Can be extended with search parameters
- **Discovery**: Useful for finding specific dashboards

## Search Capabilities
- Can be extended to search by:
  - Dashboard name
  - Owner
  - Favorite status
  - Other criteria

## Sample Data
```
ID: 11058 - (DRAFT) Dashboard - Cybersecurity Enterprise
ID: 11387 - 2024 Automation Dashboard
ID: 11489 - 2025 Campaigns
```

---
*Generated: 2025-10-08 05:00:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success - Search Results Retrieved*
