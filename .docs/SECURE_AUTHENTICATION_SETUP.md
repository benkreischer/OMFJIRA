# SECURE AUTHENTICATION SETUP INSTRUCTIONS

## For OMF Users:

### 1. Login with OMF Credentials
`powershell
.\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO
`

### 2. Set Up Excel Named Ranges
Create these named ranges in Excel:

| Named Range | Value | Description |
|-------------|-------|-------------|
| JiraBaseUrl | https://onemain.atlassian.net/rest/api/3 | Jira API base URL |
| JiraUsername | [Your OMF Email] | Your OMF email address |
| JiraApiToken | [Auto-generated] | Your API token (auto-generated) |

### 3. How to Create Named Ranges in Excel:
1. Open Excel
2. Go to **Formulas** > **Name Manager**
3. Click **New**
4. Enter the name and value for each range above
5. The JiraApiToken will be automatically populated when you log in

### 4. Load Power Query Files:
1. Copy any query from the updated .pq files
2. Paste into Power Query Editor
3. Refresh to load data with your credentials

## Security Features:
- ✅ **No embedded credentials** in files
- ✅ **OMF SSO Integration** - Use your OMF credentials
- ✅ **Encrypted API tokens** - Stored securely
- ✅ **Role-based permissions** - Access based on your role
- ✅ **Session management** - Automatic refresh
- ✅ **Audit logging** - Track all access

## Files Updated:
- jira-queries-1-basic-info.pq
- jira-queries-10-business-intelligence.pq
- jira-queries-11-custom-metrics.pq
- jira-queries-12-real-time-monitoring.pq
- jira-queries-13-advanced-predictive.pq
- jira-queries-14-advanced-business-intelligence.pq
- jira-queries-15-advanced-custom-metrics.pq
- jira-queries-2-projects.pq
- jira-queries-3-workflows.pq
- jira-queries-4-issues.pq
- jira-queries-5-permissions.pq
- jira-queries-6-fields.pq
- jira-queries-7-reports.pq
- jira-queries-8-advanced.pq
- jira-queries-9-predictive-analytics.pq
- jira-queries-secure-authentication.pq
- jira-queries-secure-template.pq


## Support:
Contact OMF Analytics Team for assistance.

---
*Updated on: 2025-09-07 07:15:20*
