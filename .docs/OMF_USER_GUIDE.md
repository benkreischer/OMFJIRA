# 🚀 OMF JIRA ANALYTICS - USER GUIDE

## Welcome to the OMF Jira Analytics System!

This guide will help you get started with the advanced Jira analytics system that provides insights far beyond what Atlassian Analytics offers.

---

## 🎯 **WHAT YOU GET**

### **Advanced Analytics**
- ✅ **Predictive Analytics** - Forecast project completion, resource needs, and bug rates
- ✅ **Business Intelligence** - Lead time analysis, cycle time optimization, deployment tracking
- ✅ **Custom Metrics** - Team performance scoring, project health indicators
- ✅ **Real-Time Monitoring** - Live dashboards with instant alerts

### **Enterprise Features**
- ✅ **OMF SSO Integration** - Login with your OMF credentials
- ✅ **Role-Based Access** - See only what you're authorized to see
- ✅ **Secure Authentication** - No embedded credentials, encrypted tokens
- ✅ **Audit Logging** - Complete tracking of all access

---

## 🚀 **QUICK START GUIDE**

### **Step 1: Login with OMF Credentials**
```powershell
# Open PowerShell and run:
.\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO
```

### **Step 2: Set Up Excel (One-Time Setup)**
1. Open Excel
2. Go to **Formulas** > **Name Manager**
3. Create these named ranges:

| Named Range | Value | Description |
|-------------|-------|-------------|
| `JiraBaseUrl` | `https://onemain.atlassian.net/rest/api/3` | Jira API base URL |
| `JiraUsername` | `your.email@omf.com` | Your OMF email |
| `JiraApiToken` | `[Auto-generated]` | Your API token (auto-populated) |

### **Step 3: Load Analytics**
1. Copy any query from the `.pq` files
2. Paste into Power Query Editor
3. Refresh to load your data
4. Enjoy advanced analytics!

---

## 📊 **AVAILABLE ANALYTICS**

### **Basic Information (jira-queries-1-basic-info.pq)**
- Server information
- Current user details
- All users (admin access)

### **Project Analytics (jira-queries-2-projects.pq)**
- Project overview
- Project health metrics
- Project performance analysis

### **Issue Tracking (jira-queries-4-issues.pq)**
- Issue status tracking
- Resolution time analysis
- Priority distribution
- **Date/Time conversions included**

### **Advanced Analytics (jira-queries-8-advanced.pq)**
- Velocity tracking
- Burndown analysis
- Team performance metrics

### **Predictive Analytics (jira-queries-9-predictive-analytics.pq)**
- Project completion forecasting
- Resource utilization prediction
- Bug rate prediction
- Sprint velocity forecasting
- Risk assessment models

### **Business Intelligence (jira-queries-10-business-intelligence.pq)**
- Lead time analysis
- Cycle time optimization
- Deployment frequency tracking
- Mean Time to Recovery (MTTR)
- Change failure rate analysis

### **Custom Metrics (jira-queries-11-custom-metrics.pq)**
- Team performance scoring
- Project health indicators
- Quality gates analysis
- Technical debt tracking
- Innovation metrics

### **Real-Time Monitoring (jira-queries-12-real-time-monitoring.pq)**
- Live dashboards
- Alert systems
- Performance monitoring
- Resource utilization tracking

---

## 🔐 **SECURITY & PERMISSIONS**

### **Your Access Level**
- **All OMF Employees**: Basic issue access, dashboard viewing
- **Project Managers**: Project-level analytics, team metrics
- **Team Leads**: Advanced analytics, team performance data
- **Admins**: Full access to all analytics and user management

### **Data Security**
- ✅ **Encrypted Storage** - All credentials are encrypted
- ✅ **Session Management** - Automatic timeout and refresh
- ✅ **Audit Logging** - All access is tracked
- ✅ **Role-Based Access** - See only authorized data

---

## 📈 **EXCEL INTEGRATION**

### **Power Query Features**
- **Dynamic Data** - Refresh with latest information
- **Date/Time Conversion** - Proper date handling
- **Calculated Columns** - Days since created, resolution time, etc.
- **Filtering** - Filter by project, status, assignee, etc.

### **VBA Automation**
- **Auto-Refresh** - Set up automatic data refresh
- **Dynamic Filtering** - Change filters via Excel cells
- **Custom Dashboards** - Build your own analytics views

---

## 🚨 **ALERTS & NOTIFICATIONS**

### **Available Alerts**
- **Sprint at Risk** - When sprint completion is below threshold
- **Resource Overload** - When team members are overloaded
- **Quality Breach** - When bug rates exceed limits
- **Deadline Risk** - When deadlines are at risk
- **Performance Issues** - When response times are slow

### **Alert Channels**
- **Slack** - Real-time notifications
- **Teams** - Microsoft Teams integration
- **Email** - Detailed reports
- **SMS** - Critical alerts only

---

## 🛠️ **TROUBLESHOOTING**

### **Common Issues**

#### **"Authentication Failed"**
```powershell
# Re-login with your OMF credentials:
.\jira-authentication-manager.ps1 -Action login -Username "your.email@omf.com" -UseSSO
```

#### **"Named Range Not Found"**
1. Check that you created the named ranges in Excel
2. Verify the names match exactly: `JiraBaseUrl`, `JiraUsername`, `JiraApiToken`

#### **"No Data Returned"**
1. Check your permissions - you may not have access to certain projects
2. Verify your API token is valid
3. Contact your admin if issues persist

#### **"Power Query Error"**
1. Ensure you're using the updated `.pq` files
2. Check that all named ranges are properly set
3. Try refreshing the query

### **Getting Help**
- **OMF Analytics Team**: Contact for technical support
- **Documentation**: Check the setup guides in the project
- **Logs**: Check the authentication logs for detailed error information

---

## 📚 **ADVANCED FEATURES**

### **Custom Dashboards**
- Build your own analytics views
- Combine multiple data sources
- Create executive summaries
- Set up automated reports

### **Data Export**
- Export to Excel, CSV, or other formats
- Schedule regular exports
- Share data with stakeholders
- Create presentations

### **Integration Options**
- **Slack/Teams** - Real-time notifications
- **CI/CD Pipelines** - Automated reporting
- **External Tools** - Connect with other systems

---

## 🎯 **BEST PRACTICES**

### **Daily Usage**
1. **Check Alerts** - Review any notifications
2. **Monitor Dashboards** - Keep track of key metrics
3. **Update Filters** - Adjust views as needed
4. **Share Insights** - Communicate findings with team

### **Weekly Reviews**
1. **Sprint Progress** - Review sprint health
2. **Team Performance** - Check team metrics
3. **Project Status** - Review project health
4. **Quality Metrics** - Monitor quality trends

### **Monthly Analysis**
1. **Trend Analysis** - Look for patterns over time
2. **Resource Planning** - Plan for upcoming needs
3. **Process Improvement** - Identify optimization opportunities
4. **Reporting** - Create executive summaries

---

## 🏆 **SUCCESS METRICS**

### **What You'll Achieve**
- **Better Visibility** - See project health in real-time
- **Faster Decisions** - Make data-driven decisions quickly
- **Improved Planning** - Forecast and plan more accurately
- **Enhanced Quality** - Monitor and improve quality metrics
- **Team Performance** - Track and improve team efficiency

### **ROI Benefits**
- **Time Savings** - Automated reporting and monitoring
- **Better Planning** - Predictive analytics for resource planning
- **Quality Improvement** - Early detection of quality issues
- **Risk Reduction** - Proactive identification of project risks
- **Team Efficiency** - Data-driven team performance optimization

---

## 🎉 **GETTING STARTED**

### **Ready to Begin?**
1. **Run the login command** above
2. **Set up Excel named ranges** as shown
3. **Try a basic query** from `jira-queries-1-basic-info.pq`
4. **Explore the analytics** that interest you most
5. **Set up alerts** for your key metrics

### **Need Help?**
- **Technical Support**: Contact OMF Analytics Team
- **Training**: Request training sessions for your team
- **Customization**: Ask about custom analytics for your needs

---

## 📞 **SUPPORT & CONTACT**

- **OMF Analytics Team**: [Contact Information]
- **Documentation**: Check project files for detailed guides
- **Updates**: System updates are automatically applied
- **Feedback**: Share your feedback to improve the system

---

**Welcome to the future of Jira analytics at OMF!** 🚀

*This system provides enterprise-grade analytics that surpasses Atlassian Analytics in every way. Enjoy the insights and make data-driven decisions with confidence.*
