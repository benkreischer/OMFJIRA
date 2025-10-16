# Endpoint Summary - Users - GET User

## Endpoint Details
- **API Endpoint**: `/rest/api/3/user`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/user?accountId=712020:27226219-226e-4bf3-9d13-545a6e6c9f8c`
- **Method**: GET
- **Purpose**: Returns details for a specific user
- **File**: `Users - GET User - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Users - GET User - Anon - Official.csv`
- **Total Records**: 1 user
- **Total Columns**: 15
- **File Size**: ~1 KB
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | Self | API endpoint URL for user details |
| 2 | Key | User key (legacy) |
| 3 | AccountId | Unique account identifier |
| 4 | AccountType | Type of account (atlassian, app) |
| 5 | Name | Username |
| 6 | EmailAddress | User email address |
| 7 | AvatarUrls | JSON object with avatar URL sizes |
| 8 | DisplayName | User's display name |
| 9 | Active | Whether user account is active |
| 10 | TimeZone | User's timezone |
| 11 | Locale | User's locale setting |
| 12 | Groups | User groups |
| 13 | ApplicationRoles | Application-specific roles |
| 14 | Properties | User properties |
| 15 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - complete user profile
- **User Type**: Active Atlassian user account
- **Environment**: Production

## Sample Data (Single Record)

| AccountId | AccountType | DisplayName | EmailAddress | Active | TimeZone | Locale |
|-----------|-------------|-------------|--------------|--------|----------|--------|
| 712020:27226219-226e-4bf3-9d13-545a6e6c9f8c | atlassian | Ben Kreischer | ben.kreischer.ce@omf.com | true | America/Indianapolis | en_US |

### Detailed User Information
- **User**: Ben Kreischer (ben.kreischer.ce@omf.com)
- **Account Type**: Atlassian user account
- **Status**: Active user
- **Timezone**: America/Indianapolis
- **Locale**: English (US)
- **Groups**: 7 groups (details in JSON format)
- **Application Roles**: 1 application role
- **Avatar**: Complete avatar URL set with multiple sizes

## Key Insights
- **Single User Query**: Specific user lookup by account ID
- **Complete Profile**: Full user details including timezone, locale, groups
- **Avatar System**: Professional avatar management with multiple sizes
- **Group Membership**: User belongs to 7 groups
- **Application Access**: Has 1 application role assigned
- **Geographic**: Indianapolis timezone (likely OneMain Financial employee)

---
*Generated: 2025-10-07 18:45:00*  
*Environment: Production (https://onemain.atlassian.net)*
