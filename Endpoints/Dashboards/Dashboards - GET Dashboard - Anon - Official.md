# Endpoint Summary - Dashboards - GET Dashboard

## Endpoint Details
- **API Endpoint**: `/rest/api/3/dashboard/{dashboardId}`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/dashboard/11058`
- **Method**: GET
- **Purpose**: Returns details for a specific dashboard by ID
- **File**: `Dashboards - GET Dashboard - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Dashboards - GET Dashboard - Anon - Official.csv`
- **Total Records**: 1 dashboard (successful)
- **Total Columns**: 7
- **File Size**: ~268 bytes
- **Generated**: 2025-10-08 05:00:00

## API Response Summary
- **Success**: ✅ API call successful
- **Dashboard ID Used**: 11058 (from CommonParameters)
- **Response**: Single dashboard object
- **Environment**: Production

## Data Structure
- **Id**: Dashboard ID
- **Name**: Dashboard name
- **Self**: Self-reference URL
- **View**: View URL
- **Owner**: Dashboard owner display name
- **Popularity**: Dashboard popularity score
- **GeneratedAt**: Timestamp of data generation

## Parameter Configuration
- **DashboardId**: Configured in `endpoints-parameters.json`
- **Current Value**: "11058"
- **Customizable**: Yes - update CommonParameters.DashboardId

## Key Insights
- **Parameterized**: Uses DashboardId from configuration file
- **Single Dashboard**: Returns detailed information for one dashboard
- **Owner Information**: Includes dashboard owner details
- **Popularity Metric**: Tracks dashboard usage

## Sample Data
```
ID: 11058
Name: (DRAFT) Dashboard - Cybersecurity Enterprise
Owner: [Owner Name]
View: https://onemain.atlassian.net/jira/dashboards/11058
```

---
*Generated: 2025-10-08 05:00:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Success - Dashboard Retrieved*  
*Parameter: DashboardId = 11058*
