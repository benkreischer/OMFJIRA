# Jira API Power BI Desktop Setup Instructions

## Quick Setup Guide

### 1. Open Power BI Desktop
- Launch Power BI Desktop application

### 2. Create New Data Sources
- Go to **Home** tab â†’ **Get Data** â†’ **Blank Query**
- Click **Advanced Editor**
- Copy and paste the Power Query code from Jira_API_PowerQuery_Templates.pq

### 3. Configure Authentication
- Replace [YOUR_API_TOKEN] with your actual API token
- The token should be the same one used in the PowerShell scripts

### 4. Create Each Data Source
Repeat the process for each endpoint you want to track:

#### Core Endpoints:
- **Projects** - Use Projects() function
- **All Projects** - Use AllProjects() function  
- **Issues** - Use Issues() function
- **Users** - Use Users() function
- **Issue Fields** - Use IssueFields() function
- **Issue Types** - Use IssueTypes() function
- **Statuses** - Use Statuses() function
- **Priorities** - Use Priorities() function
- **Dashboards** - Use Dashboards() function

### 5. Create Relationships
- Go to **Model** view
- Create relationships between tables (e.g., Projects.Key â†’ Issues.Key)

### 6. Build Visualizations
- Go to **Report** view
- Create charts, tables, and cards using your data sources

### 7. Refresh Data
- Use **Home** â†’ **Refresh** to update all data sources
- Set up automatic refresh in Power BI Service (cloud)

## Authentication Details
- **Base URL**: https://onemain-omfdirty.atlassian.net
- **Username**: ben.kreischer.ce@omf.com
- **API Token**: [Your existing API token]
- **Authentication**: Basic Auth

## Troubleshooting
- Verify API token is correct
- Check network connectivity to Atlassian
- Ensure API rate limits aren't exceeded
- Use Power BI Gateway for enterprise deployments

## Files Created
1. Jira_API_Live_Dashboard.json - Power BI file structure
2. Jira_API_PowerQuery_Templates.pq - Power Query connection templates
3. This setup guide

## Next Steps
1. Open Power BI Desktop
2. Import the Power Query templates
3. Configure authentication
4. Create your dashboard
5. Set up refresh schedule
