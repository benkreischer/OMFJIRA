# Endpoint Summary - Application Roles - GET Application Roles

## Endpoint Details
- **API Endpoint**: `/rest/api/3/applicationrole`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/applicationrole`
- **Method**: GET
- **Purpose**: Returns application roles and their seat information
- **File**: `Application Roles - GET Application Roles - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Application Roles - GET Application Roles - Anon - Official.csv`
- **Total Records**: 2 application roles
- **Total Columns**: 13
- **File Size**: ~674 bytes
- **Generated**: 2025-10-07 19:32:38

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | Key | Application role key |
| 2 | Name | Application role name |
| 3 | Groups | Associated groups |
| 4 | DefaultGroups | Default groups for the role |
| 5 | SelectedByDefault | Whether role is selected by default |
| 6 | Defined | Whether role is defined |
| 7 | NumberOfSeats | Total number of seats |
| 8 | RemainingSeats | Available seats remaining |
| 9 | UserCount | Current number of users |
| 10 | UserCountDescription | Description of user count |
| 11 | HasUnlimitedSeats | Whether role has unlimited seats |
| 12 | Platform | Platform-specific flag |
| 13 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - application role information retrieved
- **Role Types**: Jira Product Discovery and Jira Software roles
- **Environment**: Production

## Sample Data (All Records)

| Key | Name | Groups | NumberOfSeats | RemainingSeats | UserCount |
|-----|------|--------|---------------|----------------|-----------|
| jira-product-discovery | Jira Product Discovery | jira-product-discovery-users-onemain | 35000 | 34994 | 6 |
| jira-software | Jira Software | jira-software-users; atlassian-addons-admin; system-administrators; RG_JIRA_CLOUD_USERS; site-admins; administrators | 1600 | 63 | 1537 |

### Detailed Role Information
- **Jira Product Discovery**: 35,000 seats allocated, 6 users, 34,994 remaining
- **Jira Software**: 1,600 seats allocated, 1,537 users, 63 remaining
- **Group Associations**: Multiple groups per role for access control
- **Seat Management**: Both roles have seat limitations and tracking

## Key Insights
- **Total Roles**: 2 application roles configured
- **Seat Usage**: Jira Software is heavily used (1,537/1,600 seats)
- **Product Discovery**: Large seat allocation (35,000) but minimal usage (6 users)
- **Access Control**: Multiple groups associated with each role
- **Administrative Roles**: System administrators and site admins included
- **Seat Availability**: Jira Software approaching capacity (96% used)

---
*Generated: 2025-10-07 19:32:38*  
*Environment: Production (https://onemain.atlassian.net)*
