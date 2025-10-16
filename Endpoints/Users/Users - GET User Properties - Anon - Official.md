# Endpoint Summary - Users - GET User Properties

## Endpoint Details
- **API Endpoint**: `/rest/api/3/user/properties`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/user/properties?accountId=712020:27226219-226e-4bf3-9d13-545a6e6c9f8c`
- **Method**: GET
- **Purpose**: Returns user properties for a specific user
- **File**: `Users - GET User Properties - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Users - GET User Properties - Anon - Official.csv`
- **Total Records**: 17 properties
- **Total Columns**: 3
- **File Size**: ~4 KB
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | Key | Property key with user account information |
| 2 | Self | API endpoint URL for the property |
| 3 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - user properties retrieved
- **Property Types**: Visual refresh cache properties
- **Environment**: Production

## Sample Data (First 5 Records)

| Key | Property Type | Account ID |
|-----|---------------|------------|
| com.atlassian.jira.frontend.VisualRefreshIconCacheBuster:clear-cache-state | Visual Refresh Cache | 712020:27226219-226e-4bf3-9d13-545a6e6c9f8c |
| com.atlassian.jira.frontend.VisualRefreshIconCacheBuster:clear-cache-state-v2 | Visual Refresh Cache v2 | 712020:27226219-226e-4bf3-9d13-545a6e6c9f8c |
| [Next Property] | Visual Refresh Cache | [Same Account ID] |
| [Next Property] | Visual Refresh Cache | [Same Account ID] |
| [Next Property] | Visual Refresh Cache | [Same Account ID] |

### Detailed Property Information
- **Property Category**: Visual Refresh Icon Cache properties
- **Cache Types**: Multiple cache busting properties (clear-cache-state, clear-cache-state-v2)
- **User Account**: Specific user account (712020:27226219-226e-4bf3-9d13-545a6e6c9f8c)
- **Purpose**: Frontend visual refresh functionality

## Key Insights
- **Total Properties**: 17 user properties
- **Property Focus**: Visual refresh and cache management
- **User Context**: Properties for a specific user account
- **System Integration**: Atlassian frontend visual refresh system
- **Cache Management**: Multiple cache busting mechanisms

---
*Generated: 2025-10-07 18:45:00*  
*Environment: Production (https://onemain.atlassian.net)*
