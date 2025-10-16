# Endpoint Summary - Application Roles - GET Application Role

## Endpoint Details
- **API Endpoint**: `/rest/api/3/applicationrole`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/applicationrole`
- **Method**: GET
- **Purpose**: Returns individual application role details
- **File**: `Application Roles - GET Application Role - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Application Roles - GET Application Role - Anon - Official.csv`
- **Total Records**: 2 application roles
- **Total Columns**: 14
- **File Size**: ~579 bytes
- **Generated**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | key | Application role key |
| 2 | groups | Associated groups (array) |
| 3 | groupDetails | Group details (array) |
| 4 | name | Application role name |
| 5 | defaultGroups | Default groups (array) |
| 6 | defaultGroupsDetails | Default group details (array) |
| 7 | selectedByDefault | Whether role is selected by default |
| 8 | defined | Whether role is defined |
| 9 | numberOfSeats | Total number of seats |
| 10 | remainingSeats | Available seats remaining |
| 11 | userCount | Current number of users |
| 12 | userCountDescription | Description of user count |
| 13 | hasUnlimitedSeats | Whether role has unlimited seats |
| 14 | platform | Platform-specific flag |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - detailed role information
- **Role Types**: Jira Product Discovery and Jira Software
- **Environment**: Production

## Sample Data (All Records)

| Key | Name | NumberOfSeats | RemainingSeats | UserCount |
|-----|------|---------------|----------------|-----------|
| jira-product-discovery | Jira Product Discovery | 35000 | 34996 | 4 |
| jira-software | Jira Software | 1600 | 61 | 1539 |

### Detailed Role Information
- **Jira Product Discovery**: 35,000 seats, 4 users, 34,996 remaining
- **Jira Software**: 1,600 seats, 1,539 users, 61 remaining
- **Group Arrays**: Detailed group information stored as arrays
- **Seat Tracking**: Real-time seat usage monitoring

---
*Generated: 2025-10-07 19:32:38*  
*Environment: Production (https://onemain.atlassian.net)*
