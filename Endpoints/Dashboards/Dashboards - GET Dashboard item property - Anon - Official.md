# Endpoint Summary - Dashboards - GET Dashboard item property

## Endpoint Details
- **API Endpoint**: `/rest/api/3/dashboard/{dashboardId}/items/{itemId}/properties/{propertyKey}`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/dashboard/11058/items/item1/properties/property1`
- **Method**: GET
- **Purpose**: Returns the value of a property for a dashboard item
- **File**: `Dashboards - GET Dashboard item property - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Dashboards - GET Dashboard item property - Anon - Official.csv`
- **Total Records**: Varies (depends on property existence)
- **Total Columns**: Varies based on property structure
- **File Size**: ~164 bytes
- **Generated**: 2025-10-08 05:00:00

## API Response Summary
- **Success**: ⚠️ Requires valid dashboard item and property
- **Dashboard ID Used**: 11058 (from CommonParameters)
- **Item ID**: item1 (placeholder - needs valid item ID)
- **Property Key**: property1 (placeholder - needs valid property key)
- **Environment**: Production

## Parameter Configuration
- **DashboardId**: Configured in `endpoints-parameters.json`
- **ItemId**: Hardcoded in script (needs to be parameterized)
- **PropertyKey**: Hardcoded in script (needs to be parameterized)
- **Customizable**: Partially - DashboardId is configurable

## Data Structure
- **Property Value**: Depends on the specific property
- **Key-Value Pairs**: Property metadata
- **GeneratedAt**: Timestamp of data generation

## Key Insights
- **Granular Access**: Retrieves specific properties of dashboard items
- **Requires Valid IDs**: Needs actual dashboard item ID and property key
- **Advanced Feature**: For detailed dashboard item configuration
- **Use Case**: Retrieving custom properties or metadata

## Notes
⚠️ **Configuration Required**: 
- This endpoint requires valid `itemId` and `propertyKey` values
- Currently using placeholder values that may not exist
- Needs to be configured with actual dashboard item IDs

---
*Generated: 2025-10-08 05:00:00*  
*Environment: Production (https://onemain.atlassian.net)*  
*Status: Configured - Requires Valid Item/Property IDs*  
*Parameters: DashboardId = 11058, ItemId = item1, PropertyKey = property1*
