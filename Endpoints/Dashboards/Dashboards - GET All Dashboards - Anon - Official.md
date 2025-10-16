# Endpoint Summary - Dashboards - GET All Dashboards

## Endpoint Details
- **API Endpoint**: `/rest/api/3/dashboard`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/dashboard?startAt=0&maxResults=1000`
- **Method**: GET
- **Purpose**: Returns a paginated list of all dashboards
- **File**: `Dashboards - GET All Dashboards - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Dashboards - GET All Dashboards - Anon - Official.csv`
- **Total Records**: 788 dashboards (successful)
- **Total Columns**: 5
- **File Size**: ~90KB
- **Generated**: 2025-10-08 05:00:00

## API Response Summary
- **Success**: ✅ API call successful
- **Dashboards Retrieved**: 788 total dashboards
- **Pagination**: Working correctly with MaxResults=1000
- **Environment**: Production

## Data Structure
- **ID**: Dashboard ID
- **Name**: Dashboard name
- **Owner_DisplayName**: Dashboard owner's display name
- **SharePermissions**: Share permission details
- **EditPermissions**: Edit permission details
- **GeneratedAt**: Timestamp of data generation

## Key Insights
- **Total Dashboards**: 788 dashboards in the system
- **Pagination**: Successfully retrieves all dashboards in one batch
- **Permissions**: Full permission details captured
- **Data Quality**: All dashboards returned with complete information

## Sample Data
```
ID: 11058
Name: (DRAFT) Dashboard - Cybersecurity Enterprise
Owner: Various users
Permissions: Configured per dashboard
```

---
*Generated: 2025-10-08 05:00:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success - All Dashboards Retrieved*
