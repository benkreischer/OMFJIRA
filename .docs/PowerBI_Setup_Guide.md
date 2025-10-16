# 🚀 Jira API Power BI Setup Guide

## 📊 **Summary Statistics**
- **Total Endpoints Found**: 120
- **Working Endpoints**: 40
- **Total Records**: 3,979
- **Sandbox Environment**: https://onemain-omfdirty.atlassian.net

## 🎯 **Top 10 Endpoints by Record Count**

| Records | Endpoint |
|---------|----------|
| 451 | Issue Fields - GET Fields paginated (Anon) |
| 451 | Issue Fields - GET All Fields (Anon) |
| 422 | Issue Custom Field Associations - GET Custom Field Associations |
| 422 | Custom Fields - GET Fields |
| 271 | Project Classification Levels - GET Project Classification Levels (Anon) |
| 271 | Project Classification Levels - GET Project Classification Level (Anon) |
| 113 | Status - GET Statuses (Anon) |
| 100 | Issue Search - GET Issue search (Anon) |
| 100 | Issues - GET Issue Changelog (Anon) |
| 100 | Projects - GET Projects Paginated (Anon) |

## 🔧 **Power BI Setup Instructions**

### **Step 1: Open Power BI Desktop**
- Launch Power BI Desktop application

### **Step 2: Create Data Sources**
For each endpoint you want to use:

1. **Home** → **Get Data** → **Blank Query**
2. Click **Advanced Editor**
3. Copy the Power Query code from the corresponding `.pq` file
4. Paste into Advanced Editor
5. Replace `[YOUR_API_TOKEN]` with your actual API token
6. Click **Done**

### **Step 3: Configure Authentication**
- **Base URL**: `https://onemain-omfdirty.atlassian.net`
- **Username**: `ben.kreischer.ce@omf.com`
- **API Token**: [Your existing API token]
- **Authentication**: Basic Auth

### **Step 4: Build Your Dashboard**
- Go to **Report** view
- Drag fields from **Fields** panel to canvas
- Create cards, tables, charts, and other visuals

### **Step 5: Refresh Data**
- Click **Home** → **Refresh** to update all data sources
- Set up automatic refresh in Power BI Service (cloud)

## 📁 **File Structure**

```
.endpoints/
├── [Category]/
│   ├── [Endpoint Name].csv      # Data file
│   ├── [Endpoint Name].pq       # Power Query template
│   └── [Endpoint Name].ps1      # PowerShell script
```

## 🎨 **Recommended Dashboard Layout**

### **Page 1: Overview Dashboard**
- **Cards**: Total Projects, Total Issues, Total Users, Total Fields
- **Table**: Recent Issues with Status, Priority, Assignee
- **Chart**: Issues by Status Distribution
- **Table**: Project List with Lead Information

### **Page 2: Fields & Configuration**
- **Table**: All Custom Fields with Types
- **Table**: Issue Types and Descriptions
- **Table**: Status Categories and Colors
- **Table**: Project Categories

### **Page 3: User & Permission Management**
- **Table**: All Users with Contact Information
- **Table**: Groups and Members
- **Table**: Permissions and Roles
- **Table**: Application Properties

## 🔄 **Live Data Benefits**

✅ **Real-time Updates** - Refresh anytime for current data
✅ **No CSV Files Needed** - Direct API connections
✅ **Professional Dashboards** - Charts, tables, KPIs
✅ **Scheduled Refresh** - Automatic updates via Power BI Service
✅ **Enterprise Ready** - Can publish to Power BI Service

## 📋 **Quick Reference**

### **High-Value Endpoints for Dashboards:**
1. **Issue Fields** (451 records) - All available fields
2. **Custom Fields** (422 records) - Custom field definitions
3. **Issue Search** (100 records) - Recent issues
4. **Projects** (100 records) - All projects
5. **Statuses** (113 records) - All status definitions
6. **Users** (50 records) - User directory
7. **Dashboards** (50 records) - Available dashboards
8. **Issue Types** (64 records) - Issue type definitions

### **Authentication Setup:**
```powerquery
BaseUrl = "https://onemain-omfdirty.atlassian.net",
Username = "ben.kreischer.ce@omf.com",
ApiToken = "[YOUR_API_TOKEN]", // Replace with actual token
```

### **Common Power Query Pattern:**
```powerquery
let
    Source = Json.Document(Web.Contents(BaseUrl & "/rest/api/3/endpoint", [
        Headers = [
            Authorization = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), 0),
            Accept = "application/json"
        ]
    ])),
    // Data transformation steps...
in
    // Final table
```

## 🚨 **Troubleshooting**

**❌ Authentication Error:**
- Verify API token is correct
- Check username: `ben.kreischer.ce@omf.com`

**❌ Network Error:**
- Verify URL: `https://onemain-omfdirty.atlassian.net`
- Check internet connection

**❌ Data Not Loading:**
- Click **Refresh** button
- Check API rate limits
- Verify endpoint permissions

## 📈 **Next Steps**

1. **Start with High-Value Endpoints** - Begin with Issue Fields, Projects, Issues
2. **Create Basic Dashboard** - Build overview page first
3. **Add More Data Sources** - Gradually add more endpoints
4. **Set Up Refresh Schedule** - Configure automatic updates
5. **Publish to Power BI Service** - Share with team

---
**🎉 You're ready to build your Jira API dashboard in Power BI Desktop!**
