# Endpoint Summary - Issue Fields - Get Fields

## Endpoint Details
- **API Endpoint**: `/rest/api/3/field`
- **Full URL**: `https://onemain.atlassian.net/rest/api/3/field`
- **Method**: GET
- **Purpose**: Returns system and custom issue fields
- **File**: `Issue Fields - Get Fields - Anon - Official.ps1`

## CSV Output Details
- **Output File**: `Issue Fields - Get Fields - Anon - Official-20251007-181535.csv`
- **Total Records**: 453 (data rows + 1 header row = 454 total lines)
- **Total Columns**: 18
- **Generated**: 2025-10-07 18:15:35

## Column Structure
| Column # | Column Name | Description |
|----------|-------------|-------------|
| 1 | Id | Field ID |
| 2 | Key | Field Key |
| 3 | Name | Field Name |
| 4 | Custom | Whether field is custom |
| 5 | Orderable | Whether field is orderable |
| 6 | Navigable | Whether field is navigable |
| 7 | Searchable | Whether field is searchable |
| 8 | ClauseNames | JQL clause names |
| 9 | SchemaType | Schema type |
| 10 | SchemaItems | Schema items |
| 11 | SchemaSystem | Schema system |
| 12 | SchemaCustom | Schema custom |
| 13 | SchemaCustomId | Schema custom ID |
| 14 | SchemaConfiguration | Schema configuration |
| 15 | ScopeType | Scope type |
| 16 | ScopeProjectId | Scope project ID |
| 17 | ScopeProjectKey | Scope project key |
| 18 | GeneratedAt | Timestamp when data was generated |

## API Response Summary
- **Success**: ✅ API call successful
- **Data Quality**: Good - all expected fields present
- **Custom Fields**: Multiple custom fields detected (10750, 11841, 10752, etc.)
- **System Fields**: Standard Jira fields included (statusCategory, parent, resolution)

## Issues Fixed During Test
1. **Helper Path Issue**: Fixed path to Get-EndpointParameters.ps1 (was looking in current directory, now looks in parent)
2. **Missing BaseUrl**: Added `$BaseUrl = $Params.BaseUrl` assignment
3. **URL Construction**: Now properly constructs full URL from parameters

## Sample Data (First 5 Records)

| Id | Key | Name | Custom | Orderable | Navigable | Searchable | SchemaType | ScopeType |
|----|-----|------|--------|-----------|-----------|------------|------------|-----------|
| statusCategory | statusCategory | Status Category | false | false | true | true | statusCategory |  |
| parent | parent | Parent | false | true | true | true |  |  |
| customfield_10750 | customfield_10750 | Risk Approver (migrated) | true | true | true | true | user |  |
| resolution | resolution | Resolution | false | true | true | true | resolution |  |
| customfield_11841 | customfield_11841 | Impact | true | true | true | true | number | PROJECT |

### Detailed Field Information
- **Record 1**: Status Category - System field for workflow status categorization
- **Record 2**: Parent - System field for issue hierarchy (Epic → Story → Task)
- **Record 3**: Risk Approver (migrated) - Custom user picker field for risk approval workflow
- **Record 4**: Resolution - System field for issue resolution status
- **Record 5**: Impact - Custom rating field with PROJECT scope for impact assessment

---
*Generated: 2025-10-07 18:20:00*  
*Test Environment: Production (https://onemain.atlassian.net)*
