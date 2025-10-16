# 🔧 Sample Data Replacement Plan

## ❌ **CRITICAL ISSUE IDENTIFIED**

All **32 new Jira API endpoints** I created are using **hardcoded sample data** instead of making **live API calls** to the OneMain Financial Jira instance.

## 🎯 **What Needs to be Fixed**

### **Current Problem**
All endpoints use `Table.FromRecords()` with hardcoded sample data like:
```powerquery
AppUsageStatisticsData = Table.FromRecords({
    [
        AppName = "DrawIO",
        AppCategory = "Diagramming",
        TotalUsers = 45,
        // ... more hardcoded data
    ]
})
```

### **Required Solution**
Replace with live API calls like:
```powerquery
ProjectsResponse = Json.Document(
    Web.Contents(
        BaseUrl & "/rest/api/3/project",
        [
            Headers = [
                #"Authorization" = AuthHeader,
                #"Accept" = "application/json"
            ]
        ]
    )
)
```

## 📊 **Files That Need Live API Calls**

### **✅ FIXED - Integration ROI (4 files)**
- ✅ `Integration ROI - GET App Usage Statistics Analytics.pq`
- ✅ `Integration ROI - GET Cost per Integration Analytics.pq`
- ✅ `Integration ROI - GET Underutilized Tools Detection Analytics.pq`
- ✅ `Integration ROI - GET Performance Metrics Analytics.pq`

### **❌ NEEDS FIXING - Connected Apps (8 files)**
- ❌ `Connected Apps - GET DrawIO Usage Analytics.pq`
- ❌ `Connected Apps - GET Jenkins Integration Analytics.pq`
- ❌ `Connected Apps - GET Confluence Integration Analytics.pq`
- ❌ `Connected Apps - GET Slack Teams Integration Analytics.pq`
- ❌ `Connected Apps - GET GitHub GitLab Integration Analytics.pq`
- ❌ `Connected Apps - GET Tempo Time Tracking Analytics.pq`
- ❌ `Connected Apps - GET Zephyr Test Management Analytics.pq`
- ❌ `Connected Apps - GET Xray Test Management Analytics.pq`

### **❌ NEEDS FIXING - Admin Organization (6 files)**
- ❌ `Admin Organization - GET User Management Analytics.pq`
- ❌ `Admin Organization - GET Group Management Analytics.pq`
- ❌ `Admin Organization - GET Permission Analysis Analytics.pq`
- ❌ `Admin Organization - GET License Usage Analytics.pq`
- ❌ `Admin Organization - GET Audit Log Analytics.pq`
- ❌ `Admin Organization - GET Security Compliance Analytics.pq`

### **❌ NEEDS FIXING - Service Management (5 files)**
- ❌ `Service Management - GET Customer Portal Analytics.pq`
- ❌ `Service Management - GET SLA Analytics.pq`
- ❌ `Service Management - GET Knowledge Base Analytics.pq`
- ❌ `Service Management - GET Queue Management Analytics.pq`
- ❌ `Service Management - GET Agent Performance Analytics.pq`

### **❌ NEEDS FIXING - Advanced Agile (5 files)**
- ❌ `Advanced Agile - GET Sprint Planning Analytics.pq`
- ❌ `Advanced Agile - GET Velocity Tracking Analytics.pq`
- ❌ `Advanced Agile - GET Burndown Analysis Analytics.pq`
- ❌ `Advanced Agile - GET Retrospective Analytics.pq`
- ❌ `Advanced Agile - GET Cross-team Dependencies Analytics.pq`

## 🔧 **Replacement Strategy**

### **For Each Endpoint:**
1. **Remove** `Table.FromRecords()` with hardcoded data
2. **Add** live API calls using `Web.Contents()` and `Json.Document()`
3. **Use** appropriate Jira REST API endpoints:
   - `/rest/api/3/project` for project data
   - `/rest/api/3/users/search` for user data
   - `/rest/api/3/issue/search` for issue data
   - `/rest/api/3/application-properties` for app data
4. **Transform** live data into the required analytics format
5. **Maintain** all existing data transformations and health scoring

## 🚀 **Next Steps**

1. **Fix Connected Apps endpoints** (8 files)
2. **Fix Admin Organization endpoints** (6 files)
3. **Fix Service Management endpoints** (5 files)
4. **Fix Advanced Agile endpoints** (5 files)
5. **Test all endpoints** with live OneMain Financial data
6. **Verify** all analytics and health scoring work correctly

## ⚠️ **Critical Note**

**ALL endpoints must use live API calls** - no sample data should remain in any of the 32 new endpoints. This is essential for the endpoints to provide real analytics from the OneMain Financial Jira instance.
