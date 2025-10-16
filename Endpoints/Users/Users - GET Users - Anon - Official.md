# Endpoint Summary - Users - GET Users

## Endpoint Details
- **API Endpoint**: `/rest/api/3/users/search`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/users/search`
- **Method**: GET
- **Purpose**: Returns all users in the system
- **File**: `Users - GET Users - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Users - GET Users - Anon - Official.csv`
- **Total Records**: 13,467 users
- **Total Columns**: 15
- **File Size**: ~13 MB
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
- **Data Quality**: Good - comprehensive user data
- **User Types**: Both human users and app accounts
- **Environment**: Production
- **Pagination**: Retrieved 13,467 users across 14 API calls

## Sample Data (First 5 Records)

| AccountId | AccountType | DisplayName | Active | Locale | TimeZone |
|-----------|-------------|-------------|--------|--------|----------|
| [Account ID] | atlassian | [User Name] | true | en_US | [Timezone] |
| [Account ID] | app | [App Name] | true |  |  |
| [Account ID] | atlassian | [User Name] | true | en_US | [Timezone] |
| [Account ID] | atlassian | [User Name] | true | en_US | [Timezone] |
| [Account ID] | atlassian | [User Name] | true | en_US | [Timezone] |

### Detailed User Information
- **Total Users**: 13,467 user accounts in the system
- **Account Types**: Mix of Atlassian user accounts and application accounts
- **Active Status**: Most accounts are active
- **Locale**: Primarily en_US (English US)
- **Avatar System**: Uses Atlassian avatar management system with multiple sizes
- **Pagination**: Successfully retrieved all users using paginated API calls

## Key Insights
- **Large User Base**: 13,467 total user accounts
- **Mixed Account Types**: Both human users and application accounts
- **Active Users**: Majority of accounts are active
- **International**: Users across multiple timezones
- **Avatar Management**: Professional avatar system with multiple resolution support
- **API Performance**: Efficient pagination handling for large datasets

---
*Generated: 2025-10-07 18:45:00*  
*Environment: Production (https://onemain.atlassian.net)*
