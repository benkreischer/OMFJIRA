# 📊 Excel Setup Guide - Jira Integration Analytics

## 🚀 **Quick Start (5 minutes)**

### **Step 1: Get Your Jira API Token**
1. Go to [Atlassian Account Settings](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Click **"Create API token"**
3. Name it: `Excel Analytics`
4. Copy the token (starts with `ATATT3...`)

### **Step 2: Open Excel and Create New Query**
1. Open Excel
2. Go to **Data** → **Get Data** → **From Other Sources** → **Blank Query**
3. Click **"Advanced Editor"**

### **Step 3: Add the Query Code**
1. Copy the entire contents of `jira-queries-16-connected-apps-analytics-excel-ready.pq`
2. Paste it into the Advanced Editor
3. **IMPORTANT**: Replace these three lines with your actual values:

```m
BaseUrl = "https://onemain.atlassian.net",  // Your Jira URL
Username = "your.email@onemain.com",        // Your OMF email
ApiToken = "YOUR_API_TOKEN_HERE",           // Your Jira API token
```

### **Step 4: Test and Load**
1. Click **"Done"**
2. If successful, click **"Close & Load"**
3. Your data will appear in a new worksheet!

## 🎯 **What You'll Get**

### **Integration Analytics Table:**
- **Integration Name**: DrawIO, Jenkins, Confluence, etc.
- **Integration Category**: Diagramming, CI/CD, Documentation, etc.
- **Monthly Cost**: Cost per integration
- **Active Users**: Number of users
- **Cost Per User**: Cost efficiency metric
- **Field Count**: Number of custom fields detected
- **Usage Efficiency**: High/Medium/Low efficiency rating
- **ROI Score**: Return on investment score
- **Utilization Status**: Underutilized/Moderate/Good/Heavy use
- **Recommendation**: Action items for each integration
- **Health Score**: Overall health score (0-100)
- **Annual Cost**: Total yearly cost
- **Potential Savings**: Money you could save

## 🔧 **Troubleshooting**

### **Common Issues:**

1. **"Data source error"**:
   - Check your API token is correct
   - Verify your Jira URL is correct
   - Make sure you have access to the Jira instance

2. **"Authentication failed"**:
   - Double-check your email address
   - Verify your API token is valid
   - Try generating a new API token

3. **"No data returned"**:
   - Check if you have issues in your Jira instance
   - Verify your Jira permissions
   - Try reducing the date range in the query

### **Test Your Connection:**
Before using the full query, test with this simple version:

```m
let
    BaseUrl = "https://onemain.atlassian.net",
    Username = "your.email@onemain.com",
    ApiToken = "YOUR_API_TOKEN_HERE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    TestUrl = BaseUrl & "/rest/api/3/myself",
    TestHeaders = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    TestResponse = Json.Document(Web.Contents(TestUrl, [Headers = TestHeaders]))
in
    TestResponse
```

If this works, you'll see your user information. If not, check your credentials.

## 📈 **Using the Data**

### **Create Charts:**
1. Select your data
2. Go to **Insert** → **Charts**
3. Create:
   - **Pie Chart**: Integration usage by category
   - **Bar Chart**: ROI scores by integration
   - **Scatter Plot**: Cost vs. Usage efficiency

### **Add Filters:**
1. Select your data
2. Go to **Data** → **Filter**
3. Filter by:
   - Integration Category
   - Utilization Status
   - Recommendation

### **Create Pivot Tables:**
1. Select your data
2. Go to **Insert** → **PivotTable**
3. Analyze:
   - Total costs by category
   - Average ROI by status
   - Potential savings summary

## 🔄 **Refreshing Data**

### **Manual Refresh:**
1. Right-click on your data table
2. Select **"Refresh"**

### **Automatic Refresh:**
1. Go to **Data** → **Properties**
2. Check **"Refresh data when opening the file"**
3. Set refresh interval if desired

## 🎨 **Customization**

### **Modify Date Range:**
In the query, change this line:
```m
IssuesUrl = BaseUrl & "/rest/api/3/search?jql=ORDER BY created DESC&maxResults=1000",
```

To include a date filter:
```m
IssuesUrl = BaseUrl & "/rest/api/3/search?jql=created >= '2024-01-01' ORDER BY created DESC&maxResults=1000",
```

### **Add More Integrations:**
In the `IntegrationInventory` section, add more entries:
```m
[Integration="NewApp", Category="New Category", MonthlyCost=50, Users=25, LastUsed="2024-01-15"],
```

### **Adjust Cost Thresholds:**
Modify the efficiency calculations in the `UsageEfficiency` step to match your organization's standards.

## 📊 **Sample Dashboard Layout**

### **Row 1: Summary Cards**
- Total Annual Cost
- Total Potential Savings
- Number of Integrations
- Average Health Score

### **Row 2: Charts**
- Integration Usage by Category (Pie Chart)
- ROI Score by Integration (Bar Chart)
- Cost vs. Efficiency (Scatter Plot)

### **Row 3: Detailed Table**
- Full integration analytics table with filters

## 🚨 **Security Notes**

- **Never share** your API token
- **Store securely** - consider using Excel's password protection
- **Rotate regularly** - change your API token monthly
- **Monitor usage** - check Jira audit logs for unusual activity

---

**🎉 You're now ready to analyze your Jira integrations in Excel!**
