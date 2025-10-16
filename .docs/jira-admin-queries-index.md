# Jira Admin Power Query Templates

This collection contains comprehensive Power Query templates for Jira administrators. Each file contains multiple queries organized by category.

## 📁 **Query Files:**

### **1. Basic Information** (`jira-queries-1-basic-info.pq`)
- **Server Information**: Jira server details, version, build info
- **Current User Information**: Your user profile and permissions
- **All Users**: Complete user directory (requires admin permissions)

### **2. Project Management** (`jira-queries-2-projects.pq`)
- **All Projects**: Complete project listing with details
- **Project Components**: Components for specific projects
- **Project Versions**: Release versions and milestones
- **Project Roles**: Role assignments and permissions

### **3. Workflow Management** (`jira-queries-3-workflows.pq`)
- **All Workflows**: Complete workflow inventory
- **Workflow Schemes**: Workflow scheme configurations
- **Issue Types**: All issue types and their properties
- **Issue Type Schemes**: Issue type scheme configurations

### **4. Issue Management** (`jira-queries-4-issues.pq`)
- **Search Issues**: Custom JQL queries for issue searches
- **Recent Issues**: Issues created in last 30 days
- **Overdue Issues**: Issues past their due date
- **Issues by Status**: Issues filtered by specific status

### **5. Permissions & Security** (`jira-queries-5-permissions.pq`)
- **Permission Schemes**: Permission scheme configurations
- **Notification Schemes**: Notification scheme settings
- **Groups**: All user groups in Jira
- **Group Members**: Members of specific groups

### **6. Field Management** (`jira-queries-6-fields.pq`)
- **Custom Fields**: All custom fields and their properties
- **Field Configuration Schemes**: Field configuration schemes
- **Field Configuration Items**: Specific field configurations
- **Screen Schemes**: Screen scheme configurations

### **7. Reporting & Analytics** (`jira-queries-7-reports.pq`)
- **Issues by Project**: Project-wise issue summaries
- **Issues by Status**: Status-wise issue breakdowns
- **Issues by Assignee**: Assignee-wise issue distribution
- **Issues by Priority**: Priority-wise issue analysis
- **Issues by Issue Type**: Issue type distribution

### **8. Advanced Admin** (`jira-queries-8-advanced.pq`)
- **Audit Log**: System audit records (admin only)
- **System Information**: Application properties and settings
- **Add-ons/Apps**: Installed add-ons and their status
- **Webhooks**: Webhook configurations
- **Filters**: Saved search filters

## 🚀 **How to Use:**

1. **Open Excel** and go to **Data** → **Get Data** → **From Other Sources** → **Blank Query**
2. **Click Advanced Editor** in the Power Query Editor
3. **Copy the desired query** from any of the files above
4. **Paste into Advanced Editor** and click **Done**
5. **Click Close & Load** to import data into Excel

## ⚙️ **Configuration:**

Before using any query, update these values in the query:
- `BaseUrl`: Your Jira instance URL
- `Username`: Your Jira username/email
- `ApiToken`: Your Jira API token

## 🔧 **Customization:**

### **Modify JQL Queries:**
In the issue management queries, you can customize the JQL (Jira Query Language) to filter data as needed:

```m
JQLQuery = "project = PROJ AND status = Open ORDER BY created DESC"
```

### **Change Project Keys:**
Replace `PROJECT_KEY` with actual project keys in project-specific queries.

### **Adjust Date Ranges:**
Modify date filters in reporting queries:
```m
JQLQuery = "created >= -30d ORDER BY created DESC"  // Last 30 days
JQLQuery = "created >= -7d ORDER BY created DESC"   // Last 7 days
```

## 📊 **Popular Admin Use Cases:**

### **Daily Operations:**
- Use **Issues by Status** to monitor workflow bottlenecks
- Use **Overdue Issues** to identify delayed work
- Use **Recent Issues** to track new work

### **Weekly Reports:**
- Use **Issues by Project** for project health dashboards
- Use **Issues by Assignee** for workload distribution
- Use **Issues by Priority** for priority management

### **Monthly Reviews:**
- Use **All Projects** for project portfolio analysis
- Use **All Workflows** for process optimization
- Use **Custom Fields** for field usage analysis

### **Security Audits:**
- Use **All Users** for user access reviews
- Use **Groups** for permission group analysis
- Use **Permission Schemes** for security configuration

## 🔄 **Data Refresh:**

All queries support automatic refresh:
- **Right-click** on data → **Refresh**
- **Data tab** → **Refresh All**
- **Set up scheduled refresh** for automated reporting

## ⚠️ **Important Notes:**

1. **API Token Required**: All queries require a valid Jira API token
2. **Permissions**: Some queries require admin permissions
3. **Rate Limits**: Be mindful of Jira API rate limits
4. **Data Volume**: Large datasets may take time to load
5. **Customization**: Modify queries to match your Jira configuration

## 🆘 **Troubleshooting:**

### **Authentication Errors:**
- Verify your API token is correct
- Check username/email format
- Ensure token has necessary permissions

### **Permission Errors:**
- Some queries require admin permissions
- Check your Jira user role and permissions
- Contact Jira administrator if needed

### **Data Loading Issues:**
- Check network connectivity
- Verify Jira instance URL
- Reduce data volume with filters if needed

## 📈 **Advanced Tips:**

1. **Combine Queries**: Use Power Query to merge data from multiple sources
2. **Create Dashboards**: Build Excel dashboards using multiple queries
3. **Automate Reports**: Set up scheduled refresh for automated reporting
4. **Data Transformation**: Use Power Query transformations for data cleaning
5. **Export Options**: Export to various formats (CSV, PDF, etc.)

---

**Need Help?** Check the Jira REST API documentation: https://developer.atlassian.com/cloud/jira/platform/rest/v3/
