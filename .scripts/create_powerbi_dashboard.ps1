# PowerShell script to create Power BI Desktop file with embedded connections
# Power BI Desktop can handle live connections much better than Excel

Write-Host "=== CREATING POWER BI DASHBOARD WITH LIVE CONNECTIONS ===" -ForegroundColor Green

# Create Power BI template file
$PbixTemplate = @"
{
  "version": "1.0",
  "datamodel": {},
  "diagram": {},
  "sections": [
    {
      "name": "ReportSection",
      "displayName": "ReportSection",
      "objects": {},
      "filters": {}
    }
  ],
  "activeSection": 0,
  "sectionsAppBarColor": {
    "solid": {
      "color": {
        "r": 240,
        "g": 240,
        "b": 240
      }
    }
  },
  "sectionsOutlineColor": {
    "solid": {
      "color": {
        "r": 0,
        "g": 0,
        "b": 0
      }
    }
  }
}
"@

# Create a comprehensive Power BI template with all endpoints
$PowerBITemplate = @"
{
  "version": "1.0",
  "datamodel": {
    "model": {
      "tables": []
    }
  },
  "diagram": {
    "relationships": []
  },
  "sections": [
    {
      "name": "Jira API Dashboard",
      "displayName": "Jira API Dashboard", 
      "objects": {
        "textbox_1": {
          "name": "textbox_1",
          "position": {
            "x": 0,
            "y": 0,
            "z": 0
          },
          "size": {
            "width": 1200,
            "height": 100
          },
          "displayName": "Jira API Live Connections Dashboard",
          "text": "Jira API Live Connections Dashboard",
          "style": {
            "fontFamily": "Segoe UI",
            "fontSize": 24,
            "fontWeight": "bold",
            "color": "#1f4e79"
          }
        }
      },
      "filters": {}
    }
  ],
  "activeSection": 0
}
"@

# Save Power BI template
$TemplatePath = "Jira_API_Dashboard_Template.json"
$PowerBITemplate | Out-File -FilePath $TemplatePath -Encoding UTF8

Write-Host "Power BI template created: $TemplatePath" -ForegroundColor Yellow

# Create a comprehensive README with instructions
$ReadmeContent = @"
# Jira API Live Connections - Power BI Dashboard

## Overview
This dashboard provides live connections to Jira API endpoints for real-time data analysis.

## Base Configuration
- **Base URL**: https://onemain-omfdirty.atlassian.net
- **Authentication**: Basic Auth (Username + API Token)
- **Username**: ben.kreischer.ce@omf.com
- **API Token**: [Use your existing API token]

## Available Endpoints

### Core Data Sources
1. **Projects** - `/rest/api/3/project/ORL?expand=lead,description,issueTypes,url,projectKeys,permissions,insight`
2. **All Projects** - `/rest/api/3/project/search?expand=lead,description,issueTypes,url,projectKeys,permissions,insight`
3. **Issues** - `/rest/api/3/issue/ORL-8004`
4. **Issue Search** - `/rest/api/3/search?jql=order by created DESC&maxResults=100`
5. **Issue Fields** - `/rest/api/3/field`
6. **Issue Types** - `/rest/api/3/issuetype`
7. **Statuses** - `/rest/api/3/status`
8. **Priorities** - `/rest/api/3/priority`
9. **Resolutions** - `/rest/api/3/resolution`
10. **Users** - `/rest/api/3/users/search`

### Project Management
11. **Project Categories** - `/rest/api/3/projectCategory`
12. **Project Types** - `/rest/api/3/project/type`
13. **Project Versions** - `/rest/api/3/project/ORL/version`
14. **Project Components** - `/rest/api/3/project/ORL/component`
15. **Project Properties** - `/rest/api/3/project/ORL/properties`
16. **Project Features** - `/rest/api/3/project/ORL/features`
17. **Project Avatars** - `/rest/api/3/project/ORL/avatars`

### Workflow & Configuration
18. **Workflows** - `/rest/api/3/workflowscheme`
19. **Issue Type Schemes** - `/rest/api/3/issuetypescheme`
20. **Priority Schemes** - `/rest/api/3/priorityscheme`
21. **Screen Schemes** - `/rest/api/3/screenscheme`
22. **Issue Type Screen Schemes** - `/rest/api/3/issuetypescreenscheme`
23. **Screens** - `/rest/api/3/screens`
24. **Issue Link Types** - `/rest/api/3/issueLinkType`

### System Information
25. **Server Info** - `/rest/api/3/serverInfo`
26. **Jira Settings** - `/rest/api/3/application-properties`
27. **Time Tracking** - `/rest/api/3/configuration/timetracking`
28. **Configuration** - `/rest/api/3/configuration`

### Custom Fields & Extensions
29. **Custom Fields** - `/rest/api/3/field`
30. **Custom Field Options** - `/rest/api/3/customFieldOption/10000`
31. **Custom Field Contexts** - `/rest/api/3/field/customfield_10000/context`
32. **Filters** - `/rest/api/3/filter/search`
33. **Filter Sharing** - `/rest/api/3/filter/defaultShareScope`

### Issue Details
34. **Comments** - `/rest/api/3/issue/ORL-8004/comment`
35. **Attachments** - `/rest/api/3/attachment/meta`
36. **Issue Properties** - `/rest/api/3/issue/ORL-8004/properties`
37. **Issue Attachments** - `/rest/api/3/attachment/meta`

## Setup Instructions

### Method 1: Power BI Desktop (Recommended)
1. Open Power BI Desktop
2. Go to Home → Get Data → Web
3. Enter the API URL: https://onemain-omfdirty.atlassian.net/rest/api/3/[endpoint]
4. Select "Basic" authentication
5. Enter username and API token
6. Click "OK" to create live connection
7. Repeat for each endpoint you want to track

### Method 2: Excel Power Query
1. Open Excel
2. Go to Data → Get Data → From Other Sources → Blank Query
3. Click Advanced Editor
4. Use the Power Query code from the .pq files in .endpoints folder
5. Click Done → Close & Load
6. Use Data → Refresh All to update

### Method 3: Direct API Calls
Use the PowerShell scripts in the .endpoints folder for one-time data exports.

## Power Query Template

Here's a basic Power Query template for any Jira API endpoint:

```powerquery
let
    Source = Json.Document(Web.Contents("https://onemain-omfdirty.atlassian.net/rest/api/3/[ENDPOINT]", [
        Headers = [
            Authorization = "Basic " & Binary.ToText(Text.ToBinary("ben.kreischer.ce@omf.com:[YOUR_API_TOKEN]"), 0)
        ]
    ])),
    // Process the JSON response here
    ProcessedData = Source
in
    ProcessedData
```

## Refresh Schedule
- **Manual Refresh**: Use "Refresh All" button
- **Automatic Refresh**: Set up in Power BI Service (cloud)
- **Scheduled Refresh**: Configure in Power BI Gateway (on-premises)

## Security Notes
- This dashboard uses the sandbox environment (onemain-omfdirty.atlassian.net)
- API token is required for authentication
- Keep credentials secure and don't share API tokens
- Use Power BI Gateway for enterprise deployments

## Troubleshooting
- Check API endpoint URLs are correct
- Verify authentication credentials
- Ensure network connectivity to Atlassian
- Check API rate limits and quotas

## Support
- Jira REST API Documentation: https://developer.atlassian.com/cloud/jira/platform/rest/v3/
- Power BI Documentation: https://docs.microsoft.com/en-us/power-bi/
- Power Query Documentation: https://docs.microsoft.com/en-us/powerquery/
"@

$ReadmeContent | Out-File -FilePath "Jira_API_Dashboard_README.md" -Encoding UTF8

Write-Host "README created: Jira_API_Dashboard_README.md" -ForegroundColor Yellow

# Create a simple Power BI connection script
$PowerBIConnectionScript = @"
# Power BI Connection Script
# This script helps you create Power BI connections to Jira API endpoints

Write-Host "=== POWER BI JIRA API CONNECTIONS ===" -ForegroundColor Green

# Define endpoints
`$Endpoints = @(
    @{Name="Projects"; URL="/rest/api/3/project/ORL?expand=lead,description,issueTypes,url,projectKeys,permissions,insight"},
    @{Name="All Projects"; URL="/rest/api/3/project/search?expand=lead,description,issueTypes,url,projectKeys,permissions,insight"},
    @{Name="Issues"; URL="/rest/api/3/issue/ORL-8004"},
    @{Name="Issue Fields"; URL="/rest/api/3/field"},
    @{Name="Users"; URL="/rest/api/3/users/search"},
    @{Name="Statuses"; URL="/rest/api/3/status"},
    @{Name="Priorities"; URL="/rest/api/3/priority"}
)

`$BaseUrl = "https://onemain-omfdirty.atlassian.net"
`$Username = "ben.kreischer.ce@omf.com"
`$ApiToken = "[YOUR_API_TOKEN]"

Write-Host "Base URL: `$BaseUrl" -ForegroundColor Yellow
Write-Host "Username: `$Username" -ForegroundColor Yellow
Write-Host ""
Write-Host "Power BI Connection URLs:" -ForegroundColor Cyan

foreach (`$Endpoint in `$Endpoints) {
    `$FullUrl = `$BaseUrl + `$Endpoint.URL
    Write-Host "`$Endpoint.Name : `$FullUrl" -ForegroundColor White
}

Write-Host ""
Write-Host "Instructions:" -ForegroundColor Green
Write-Host "1. Open Power BI Desktop" -ForegroundColor White
Write-Host "2. Go to Home → Get Data → Web" -ForegroundColor White
Write-Host "3. Enter any of the URLs above" -ForegroundColor White
Write-Host "4. Select 'Basic' authentication" -ForegroundColor White
Write-Host "5. Enter username and API token" -ForegroundColor White
Write-Host "6. Click OK to create live connection" -ForegroundColor White
"@

$PowerBIConnectionScript | Out-File -FilePath "PowerBI_Connection_Helper.ps1" -Encoding UTF8

Write-Host "Power BI connection helper created: PowerBI_Connection_Helper.ps1" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== FILES CREATED ===" -ForegroundColor Green
Write-Host "1. Jira_API_Dashboard_Template.json - Power BI template" -ForegroundColor White
Write-Host "2. Jira_API_Dashboard_README.md - Complete setup guide" -ForegroundColor White
Write-Host "3. PowerBI_Connection_Helper.ps1 - Connection helper script" -ForegroundColor White
Write-Host ""
Write-Host "RECOMMENDATION: Use Power BI Desktop for live connections instead of Excel" -ForegroundColor Yellow
Write-Host "Power BI Desktop handles live API connections much better than Excel" -ForegroundColor Yellow
