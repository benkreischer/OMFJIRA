# Endpoint Summary - Announcement Banner - GET Announcement Banner

## Endpoint Details
- **API Endpoint**: `/rest/api/3/announcementBanner`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/announcementBanner`
- **Method**: GET
- **Purpose**: Returns the current announcement banner configuration
- **File**: `Announcement Banner - GET Announcement Banner - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Announcement Banner - GET Announcement Banner - Anon - Official.csv`
- **Total Records**: 1 configuration
- **Total Columns**: 5
- **File Size**: ~116 bytes
- **Generated**: 2025-10-07 19:22:37

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | IsDismissible | Whether the banner can be dismissed by users |
| 2 | IsEnabled | Whether the announcement banner is currently enabled |
| 3 | Message | The announcement banner message text |
| 4 | Visibility | Banner visibility setting (public, private, etc.) |
| 5 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - banner configuration retrieved
- **Banner Status**: Currently disabled but dismissible
- **Environment**: Production

## Sample Data (Single Record)

| IsDismissible | IsEnabled | Message | Visibility | GeneratedAt |
|---------------|-----------|---------|------------|-------------|
| true | false | (empty) | public | 2025-10-07 19:22:37 |

### Detailed Banner Information
- **Dismissible**: Banner can be dismissed by users (true)
- **Enabled Status**: Banner is currently disabled (false)
- **Message**: No message currently set (empty)
- **Visibility**: Set to public visibility
- **Configuration**: Banner system is configured but not active

## Key Insights
- **Banner Management**: System supports announcement banners
- **Current Status**: Banner is disabled (no active announcements)
- **User Experience**: When enabled, banner will be dismissible by users
- **Visibility**: Public visibility setting for organization-wide announcements
- **Configuration Ready**: Banner system is properly configured and ready for use

---
*Generated: 2025-10-07 19:22:37*  
*Environment: Production (https://onemain.atlassian.net)*
