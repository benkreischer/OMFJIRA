# 🚀 Power BI Desktop Quick Setup Guide

## ⚡ **5-Minute Setup Process**

### **Step 1: Open Power BI Desktop**
- Launch Power BI Desktop application
- Click **Get Data** → **Blank Query**

### **Step 2: Import Power Query Code**
- Click **Advanced Editor** button
- **Delete** all existing code
- **Copy** the entire contents of `Jira_API_PowerQuery_Complete.pq`
- **Paste** into Advanced Editor
- Click **Done**

### **Step 3: Configure Authentication**
- Find this line: `ApiToken = "[YOUR_API_TOKEN]"`
- Replace `[YOUR_API_TOKEN]` with your actual API token
- Click **Apply & Close**

### **Step 4: Create Data Sources**
For each endpoint you want, repeat this process:

#### **Create Projects Table:**
1. **Home** → **Get Data** → **Blank Query**
2. **Advanced Editor** → Paste this code:
```powerquery
let
    Source = Project_ORL()
in
    Source
```
3. **Name** the query: "Projects"
4. **Apply & Close**

#### **Create Issues Table:**
1. **Home** → **Get Data** → **Blank Query**
2. **Advanced Editor** → Paste this code:
```powerquery
let
    Source = Recent_Issues()
in
    Source
```
3. **Name** the query: "Issues"
4. **Apply & Close**

#### **Create Users Table:**
1. **Home** → **Get Data** → **Blank Query**
2. **Advanced Editor** → Paste this code:
```powerquery
let
    Source = All_Users()
in
    Source
```
3. **Name** the query: "Users"
4. **Apply & Close**

### **Step 5: Build Dashboard**
- Go to **Report** view
- Drag fields from **Fields** panel to canvas
- Create cards, tables, charts

### **Step 6: Refresh Data**
- Click **Home** → **Refresh** to get live data
- Set up automatic refresh in Power BI Service

## 📊 **Available Data Sources:**

| Function | Description | Records |
|----------|-------------|---------|
| `Project_ORL()` | ORL Project details | 1 |
| `All_Projects()` | All projects | ~10 |
| `Recent_Issues()` | Recent issues | 100 |
| `All_Users()` | All users | ~50 |
| `All_Fields()` | All fields | 451 |
| `All_IssueTypes()` | Issue types | 64 |
| `All_Statuses()` | Statuses | 137 |
| `All_Priorities()` | Priorities | 5 |
| `All_Dashboards()` | Dashboards | 50 |

## 🔧 **Troubleshooting:**

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

## 🎯 **Quick Dashboard Ideas:**

1. **Project Overview Card:**
   - Total Projects count
   - Total Issues count
   - Active Users count

2. **Issues Table:**
   - Issue Key, Summary, Status
   - Assignee, Created Date

3. **Status Distribution Chart:**
   - Status Name vs Count
   - Color by Status Category

4. **User Activity Table:**
   - User Name, Email, Active Status

## 🔄 **Live Data Benefits:**
- ✅ Real-time updates
- ✅ No CSV files needed
- ✅ Automatic refresh
- ✅ Enterprise-ready
- ✅ Cloud publishing

---
**🎉 You're done!** Your Power BI dashboard now has live connections to the Jira API sandbox.
