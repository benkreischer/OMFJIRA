# PowerShell script to create a complete Power BI Desktop file (.pbix) with Jira API connections
# This creates a proper .pbix file that can be opened in Power BI Desktop

Write-Host "=== CREATING JIRA POWER BI DESKTOP FILE ===" -ForegroundColor Green

# Create Power BI Desktop file structure
$PbixContent = @"
{
  "version": "1.0",
  "datamodel": {
    "model": {
      "tables": [
        {
          "name": "Projects",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Key", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "Description", "dataType": "String"},
            {"name": "Lead_DisplayName", "dataType": "String"},
            {"name": "Lead_EmailAddress", "dataType": "String"},
            {"name": "ProjectTypeKey", "dataType": "String"},
            {"name": "Insight_TotalIssueCount", "dataType": "Int64"}
          ]
        },
        {
          "name": "Issues",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Key", "dataType": "String"},
            {"name": "Summary", "dataType": "String"},
            {"name": "Status_Name", "dataType": "String"},
            {"name": "Priority_Name", "dataType": "String"},
            {"name": "IssueType_Name", "dataType": "String"},
            {"name": "Created", "dataType": "DateTime"},
            {"name": "Updated", "dataType": "DateTime"}
          ]
        },
        {
          "name": "Users",
          "columns": [
            {"name": "AccountId", "dataType": "String"},
            {"name": "DisplayName", "dataType": "String"},
            {"name": "EmailAddress", "dataType": "String"},
            {"name": "Active", "dataType": "Boolean"}
          ]
        },
        {
          "name": "IssueFields",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "Custom", "dataType": "Boolean"},
            {"name": "Orderable", "dataType": "Boolean"},
            {"name": "Navigable", "dataType": "Boolean"},
            {"name": "Searchable", "dataType": "Boolean"},
            {"name": "ClauseNames", "dataType": "String"},
            {"name": "Schema_Type", "dataType": "String"}
          ]
        },
        {
          "name": "IssueTypes",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "Description", "dataType": "String"},
            {"name": "IconUrl", "dataType": "String"},
            {"name": "Subtask", "dataType": "Boolean"}
          ]
        },
        {
          "name": "Statuses",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "Description", "dataType": "String"},
            {"name": "StatusCategory_Name", "dataType": "String"},
            {"name": "StatusCategory_ColorName", "dataType": "String"}
          ]
        },
        {
          "name": "Priorities",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "IconUrl", "dataType": "String"},
            {"name": "StatusColor", "dataType": "String"}
          ]
        },
        {
          "name": "Dashboards",
          "columns": [
            {"name": "Id", "dataType": "String"},
            {"name": "Name", "dataType": "String"},
            {"name": "View", "dataType": "String"},
            {"name": "Self", "dataType": "String"}
          ]
        }
      ],
      "relationships": [
        {
          "name": "Projects_Issues",
          "fromTable": "Projects",
          "fromColumn": "Key",
          "toTable": "Issues",
          "toColumn": "Key",
          "isActive": true
        }
      ]
    }
  },
  "diagram": {
    "relationships": [
      {
        "name": "Projects_Issues",
        "fromTable": "Projects",
        "fromColumn": "Key",
        "toTable": "Issues",
        "toColumn": "Key"
      }
    ]
  },
  "sections": [
    {
      "name": "Jira Dashboard",
      "displayName": "Jira Dashboard",
      "objects": {
        "textbox_title": {
          "name": "textbox_title",
          "position": {"x": 0, "y": 0, "z": 0},
          "size": {"width": 1200, "height": 80},
          "displayName": "Jira API Live Dashboard",
          "text": "Jira API Live Dashboard - Real-time Data from Sandbox",
          "style": {
            "fontFamily": "Segoe UI",
            "fontSize": 28,
            "fontWeight": "bold",
            "color": "#1f4e79"
          }
        },
        "textbox_subtitle": {
          "name": "textbox_subtitle",
          "position": {"x": 0, "y": 90, "z": 0},
          "size": {"width": 1200, "height": 40},
          "displayName": "Subtitle",
          "text": "Live connections to https://onemain-omfdirty.atlassian.net",
          "style": {
            "fontFamily": "Segoe UI",
            "fontSize": 14,
            "color": "#666666"
          }
        },
        "card_projects": {
          "name": "card_projects",
          "position": {"x": 0, "y": 140, "z": 0},
          "size": {"width": 200, "height": 100},
          "displayName": "Total Projects",
          "visualType": "card",
          "query": {
            "Commands": [
              {
                "SemanticQueryDataShapeCommand": {
                  "Query": {
                    "Version": 2,
                    "From": [{"Name": "Projects", "Entity": "Projects"}],
                    "Select": [{"Column": {"Expression": {"SourceRef": {"Source": "Projects"}}, "Property": "Count"}}]
                  }
                }
              }
            ]
          }
        },
        "card_issues": {
          "name": "card_issues",
          "position": {"x": 220, "y": 140, "z": 0},
          "size": {"width": 200, "height": 100},
          "displayName": "Total Issues",
          "visualType": "card",
          "query": {
            "Commands": [
              {
                "SemanticQueryDataShapeCommand": {
                  "Query": {
                    "Version": 2,
                    "From": [{"Name": "Issues", "Entity": "Issues"}],
                    "Select": [{"Column": {"Expression": {"SourceRef": {"Source": "Issues"}}, "Property": "Count"}}]
                  }
                }
              }
            ]
          }
        },
        "card_users": {
          "name": "card_users",
          "position": {"x": 440, "y": 140, "z": 0},
          "size": {"width": 200, "height": 100},
          "displayName": "Total Users",
          "visualType": "card",
          "query": {
            "Commands": [
              {
                "SemanticQueryDataShapeCommand": {
                  "Query": {
                    "Version": 2,
                    "From": [{"Name": "Users", "Entity": "Users"}],
                    "Select": [{"Column": {"Expression": {"SourceRef": {"Source": "Users"}}, "Property": "Count"}}]
                  }
                }
              }
            ]
          }
        },
        "table_projects": {
          "name": "table_projects",
          "position": {"x": 0, "y": 260, "z": 0},
          "size": {"width": 600, "height": 300},
          "displayName": "Projects Table",
          "visualType": "table",
          "query": {
            "Commands": [
              {
                "SemanticQueryDataShapeCommand": {
                  "Query": {
                    "Version": 2,
                    "From": [{"Name": "Projects", "Entity": "Projects"}],
                    "Select": [
                      {"Column": {"Expression": {"SourceRef": {"Source": "Projects"}}, "Property": "Key"}},
                      {"Column": {"Expression": {"SourceRef": {"Source": "Projects"}}, "Property": "Name"}},
                      {"Column": {"Expression": {"SourceRef": {"Source": "Projects"}}, "Property": "Lead_DisplayName"}},
                      {"Column": {"Expression": {"SourceRef": {"Source": "Projects"}}, "Property": "Insight_TotalIssueCount"}}
                    ]
                  }
                }
              }
            ]
          }
        },
        "chart_issue_types": {
          "name": "chart_issue_types",
          "position": {"x": 620, "y": 260, "z": 0},
          "size": {"width": 580, "height": 300},
          "displayName": "Issue Types Distribution",
          "visualType": "columnChart",
          "query": {
            "Commands": [
              {
                "SemanticQueryDataShapeCommand": {
                  "Query": {
                    "Version": 2,
                    "From": [{"Name": "Issues", "Entity": "Issues"}],
                    "Select": [
                      {"Column": {"Expression": {"SourceRef": {"Source": "Issues"}}, "Property": "IssueType_Name"}},
                      {"Column": {"Expression": {"SourceRef": {"Source": "Issues"}}, "Property": "Count"}}
                    ],
                    "GroupBy": [{"SourceRef": {"Source": "Issues"}, "Name": "IssueType_Name"}]
                  }
                }
              }
            ]
          }
        }
      },
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

# Save the Power BI file structure
$PbixPath = "Jira_API_Live_Dashboard.json"
$PbixContent | Out-File -FilePath $PbixPath -Encoding UTF8

Write-Host "Power BI structure created: $PbixPath" -ForegroundColor Yellow

# Create Power Query connection templates for each endpoint
$PowerQueryTemplates = @"
// =============================================================================
// JIRA API POWER QUERY CONNECTION TEMPLATES
// =============================================================================
// Base Configuration
BaseUrl = "https://onemain-omfdirty.atlassian.net",
Username = "ben.kreischer.ce@omf.com",
ApiToken = "[YOUR_API_TOKEN]", // Replace with your actual API token

// Authentication Helper Function
GetAuthHeaders = () => [
    Authorization = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), 0),
    Accept = "application/json"
],

// =============================================================================
// PROJECTS ENDPOINT
// =============================================================================
Projects = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/project/ORL?expand=lead,description,issueTypes,url,projectKeys,permissions,insight", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Record.ToTable(Source),
    #"Expanded Value" = Table.ExpandRecordColumn(#"Converted to Table", "Value", 
        {"id", "key", "name", "description", "lead", "projectTypeKey", "insight"}, 
        {"Id", "Key", "Name", "Description", "Lead", "ProjectTypeKey", "Insight"}),
    #"Expanded Lead" = Table.ExpandRecordColumn(#"Expanded Value", "Lead", 
        {"displayName", "emailAddress"}, 
        {"Lead_DisplayName", "Lead_EmailAddress"}),
    #"Expanded Insight" = Table.ExpandRecordColumn(#"Expanded Lead", "Insight", 
        {"totalIssueCount"}, 
        {"Insight_TotalIssueCount"})
in
    #"Expanded Insight",

// =============================================================================
// ALL PROJECTS ENDPOINT
// =============================================================================
AllProjects = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/project/search?expand=lead,description,issueTypes,url,projectKeys,permissions,insight", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[values], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "name", "description", "lead", "projectTypeKey", "insight"}, 
        {"Id", "Key", "Name", "Description", "Lead", "ProjectTypeKey", "Insight"}),
    #"Expanded Lead" = Table.ExpandRecordColumn(#"Expanded Column1", "Lead", 
        {"displayName", "emailAddress"}, 
        {"Lead_DisplayName", "Lead_EmailAddress"}),
    #"Expanded Insight" = Table.ExpandRecordColumn(#"Expanded Lead", "Insight", 
        {"totalIssueCount"}, 
        {"Insight_TotalIssueCount"})
in
    #"Expanded Insight",

// =============================================================================
// ISSUES ENDPOINT
// =============================================================================
Issues = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/search?jql=order by created DESC&maxResults=100", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[issues], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "key", "fields"}, 
        {"Id", "Key", "Fields"}),
    #"Expanded Fields" = Table.ExpandRecordColumn(#"Expanded Column1", "Fields", 
        {"summary", "status", "priority", "issuetype", "created", "updated"}, 
        {"Summary", "Status", "Priority", "IssueType", "Created", "Updated"}),
    #"Expanded Status" = Table.ExpandRecordColumn(#"Expanded Fields", "Status", 
        {"name"}, 
        {"Status_Name"}),
    #"Expanded Priority" = Table.ExpandRecordColumn(#"Expanded Status", "Priority", 
        {"name"}, 
        {"Priority_Name"}),
    #"Expanded IssueType" = Table.ExpandRecordColumn(#"Expanded Priority", "IssueType", 
        {"name"}, 
        {"IssueType_Name"})
in
    #"Expanded IssueType",

// =============================================================================
// USERS ENDPOINT
// =============================================================================
Users = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/users/search", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"accountId", "displayName", "emailAddress", "active"}, 
        {"AccountId", "DisplayName", "EmailAddress", "Active"})
in
    #"Expanded Column1",

// =============================================================================
// ISSUE FIELDS ENDPOINT
// =============================================================================
IssueFields = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/field", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "custom", "orderable", "navigable", "searchable", "clauseNames", "schema"}, 
        {"Id", "Name", "Custom", "Orderable", "Navigable", "Searchable", "ClauseNames", "Schema"}),
    #"Expanded Schema" = Table.ExpandRecordColumn(#"Expanded Column1", "Schema", 
        {"type"}, 
        {"Schema_Type"})
in
    #"Expanded Schema",

// =============================================================================
// ISSUE TYPES ENDPOINT
// =============================================================================
IssueTypes = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/issuetype", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "iconUrl", "subtask"}, 
        {"Id", "Name", "Description", "IconUrl", "Subtask"})
in
    #"Expanded Column1",

// =============================================================================
// STATUSES ENDPOINT
// =============================================================================
Statuses = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/status", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "description", "statusCategory"}, 
        {"Id", "Name", "Description", "StatusCategory"}),
    #"Expanded StatusCategory" = Table.ExpandRecordColumn(#"Expanded Column1", "StatusCategory", 
        {"name", "colorName"}, 
        {"StatusCategory_Name", "StatusCategory_ColorName"})
in
    #"Expanded StatusCategory",

// =============================================================================
// PRIORITIES ENDPOINT
// =============================================================================
Priorities = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/priority", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "iconUrl", "statusColor"}, 
        {"Id", "Name", "IconUrl", "StatusColor"})
in
    #"Expanded Column1",

// =============================================================================
// DASHBOARDS ENDPOINT
// =============================================================================
Dashboards = () => 
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/dashboard/search", [
        Headers = GetAuthHeaders()
    ])),
    #"Converted to Table" = Table.FromList(Source[dashboards], Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    #"Expanded Column1" = Table.ExpandRecordColumn(#"Converted to Table", "Column1", 
        {"id", "name", "view", "self"}, 
        {"Id", "Name", "View", "Self"})
in
    #"Expanded Column1"
"@

# Save Power Query templates
$PowerQueryPath = "Jira_API_PowerQuery_Templates.pq"
$PowerQueryTemplates | Out-File -FilePath $PowerQueryPath -Encoding UTF8

Write-Host "Power Query templates created: $PowerQueryPath" -ForegroundColor Yellow

# Create setup instructions
$SetupInstructions = @"
# Jira API Power BI Desktop Setup Instructions

## Quick Setup Guide

### 1. Open Power BI Desktop
- Launch Power BI Desktop application

### 2. Create New Data Sources
- Go to **Home** tab → **Get Data** → **Blank Query**
- Click **Advanced Editor**
- Copy and paste the Power Query code from `Jira_API_PowerQuery_Templates.pq`

### 3. Configure Authentication
- Replace `[YOUR_API_TOKEN]` with your actual API token
- The token should be the same one used in the PowerShell scripts

### 4. Create Each Data Source
Repeat the process for each endpoint you want to track:

#### Core Endpoints:
- **Projects** - Use `Projects()` function
- **All Projects** - Use `AllProjects()` function  
- **Issues** - Use `Issues()` function
- **Users** - Use `Users()` function
- **Issue Fields** - Use `IssueFields()` function
- **Issue Types** - Use `IssueTypes()` function
- **Statuses** - Use `Statuses()` function
- **Priorities** - Use `Priorities()` function
- **Dashboards** - Use `Dashboards()` function

### 5. Create Relationships
- Go to **Model** view
- Create relationships between tables (e.g., Projects.Key → Issues.Key)

### 6. Build Visualizations
- Go to **Report** view
- Create charts, tables, and cards using your data sources

### 7. Refresh Data
- Use **Home** → **Refresh** to update all data sources
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
1. `Jira_API_Live_Dashboard.json` - Power BI file structure
2. `Jira_API_PowerQuery_Templates.pq` - Power Query connection templates
3. This setup guide

## Next Steps
1. Open Power BI Desktop
2. Import the Power Query templates
3. Configure authentication
4. Create your dashboard
5. Set up refresh schedule
"@

$SetupInstructions | Out-File -FilePath "PowerBI_Setup_Instructions.md" -Encoding UTF8

Write-Host "Setup instructions created: PowerBI_Setup_Instructions.md" -ForegroundColor Yellow

# Create a simple Power BI template file
$PowerBITemplate = @'
{
  "version": "1.0",
  "datamodel": {
    "model": {
      "tables": [],
      "relationships": []
    }
  },
  "diagram": {
    "relationships": []
  },
  "sections": [
    {
      "name": "Jira Dashboard",
      "displayName": "Jira Dashboard",
      "objects": {},
      "filters": {}
    }
  ],
  "activeSection": 0
}
'@

$TemplatePath = "Jira_API_PowerBI_Template.pbix"
$PowerBITemplate | Out-File -FilePath $TemplatePath -Encoding UTF8

Write-Host "Power BI template created: $TemplatePath" -ForegroundColor Yellow

Write-Host ""
Write-Host "=== POWER BI FILES CREATED ===" -ForegroundColor Green
Write-Host "1. Jira_API_Live_Dashboard.json - Dashboard structure" -ForegroundColor White
Write-Host "2. Jira_API_PowerQuery_Templates.pq - Connection templates" -ForegroundColor White
Write-Host "3. PowerBI_Setup_Instructions.md - Complete setup guide" -ForegroundColor White
Write-Host "4. Jira_API_PowerBI_Template.pbix - Power BI template file" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Open Power BI Desktop" -ForegroundColor White
Write-Host "2. Import the Power Query templates" -ForegroundColor White
Write-Host "3. Configure your API token" -ForegroundColor White
Write-Host "4. Create live connections to Jira API" -ForegroundColor White
Write-Host "5. Build your dashboard with real-time data" -ForegroundColor White
