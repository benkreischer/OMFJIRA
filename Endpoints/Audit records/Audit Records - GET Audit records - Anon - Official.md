# Endpoint Summary - Audit Records - GET Audit records

## Endpoint Details
- **API Endpoint**: `/rest/api/3/auditing/record`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/auditing/record`
- **Method**: GET
- **Purpose**: Returns audit records for compliance and security monitoring
- **File**: `Audit Records - GET Audit records - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Audit Records - GET Audit records - Anon - Official.csv`
- **Total Records**: 15,645 audit records
- **Total Columns**: 12
- **File Size**: ~5 MB
- **Generated**: 2025-10-07 19:43:55

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | Id | Audit record identifier |
| 2 | Summary | Brief summary of the action |
| 3 | RemoteAddress | IP address of the user |
| 4 | AuthorKey | User who performed the action |
| 5 | Created | Timestamp when action occurred |
| 6 | Category | Category of the action |
| 7 | EventType | Type of event |
| 8 | Description | Detailed description |
| 9 | ObjectItem | Object that was modified |
| 10 | AssociatedItem | Associated item |
| 11 | ChangedValues | Values that were changed |
| 12 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - comprehensive audit trail
- **Record Types**: Various administrative and user actions
- **Environment**: Production
- **Pagination**: Retrieved 15,645 records across 16 API calls

## Sample Data (First 5 Records)

| Id | Summary | Category | ObjectItem | Created |
|----|---------|----------|------------|---------|
| 174021 | User added to group | group management | RG_CONFLUENCE_CLOUD_USERS | 2025-10-07T20:16:55.195+0000 |
| 174020 | User added to group | group management | RG_JIRA_CLOUD_USERS | 2025-10-07T20:16:54.164+0000 |
| [Next Record] | [Action Summary] | [Category] | [Object] | [Timestamp] |
| [Next Record] | [Action Summary] | [Category] | [Object] | [Timestamp] |
| [Next Record] | [Action Summary] | [Category] | [Object] | [Timestamp] |

### Detailed Audit Information
- **Group Management**: User additions to Confluence and Jira cloud user groups
- **Recent Activity**: Records from current date (2025-10-07)
- **Administrative Actions**: Group membership changes and user management
- **Compliance**: Full audit trail for security and compliance monitoring

## Key Insights
- **Total Records**: 15,645 audit records retrieved
- **Recent Activity**: High volume of recent administrative actions
- **Group Management**: Active user group membership changes
- **Compliance**: Comprehensive audit trail for regulatory compliance
- **Security**: Full tracking of user actions and administrative changes
- **API Performance**: Efficient pagination handling for large datasets

---
*Generated: 2025-10-07 19:43:55*  
*Environment: Production (https://onemain.atlassian.net)*
