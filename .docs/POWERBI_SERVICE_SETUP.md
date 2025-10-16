# 🚀 PowerBI Service Setup (Web Version)

## **No Desktop Version Needed!**

Since you can't install PowerBI Desktop due to admin restrictions, we'll use PowerBI Service (the web version) instead.

---

## **STEP 1: Access PowerBI Service**

1. Go to: **https://app.powerbi.com**
2. **Sign in** with your OMF credentials
3. You should see the PowerBI workspace

---

## **STEP 2: Create a New Dataset**

### **Option A: Use PowerBI's Built-in Jira Connector**

1. Click **"Create"** → **"Dataset"**
2. Select **"Jira"** from the list of connectors
3. **Server URL**: `https://onemain.atlassian.net`
4. **Authentication**: Select **"OAuth2"**
5. Click **"Sign in"**
6. **Enter your OMF credentials** when prompted
7. **Complete 2FA** if required
8. Click **"Allow"** to grant access

### **Option B: Use Web Data Source (If Jira Connector Not Available)**

1. Click **"Create"** → **"Dataset"**
2. Select **"Web"** as the data source
3. **URL**: `https://onemain.atlassian.net/rest/api/3/search?jql=ORDER BY updated DESC&maxResults=1000`
4. **Authentication**: Select **"Basic"**
5. **Username**: Your OMF email
6. **Password**: Your OMF password
7. Click **"Connect"**

---

## **STEP 3: Transform Your Data**

1. **Click "Transform Data"** (if using Web source)
2. **Expand the "issues" column**
3. **Expand the "fields" column**
4. **Select the fields you want**:
   - ✅ **key** (Issue Key)
   - ✅ **summary** (Summary)
   - ✅ **status** (Status)
   - ✅ **assignee** (Assignee)
   - ✅ **reporter** (Reporter)
   - ✅ **created** (Created Date)
   - ✅ **updated** (Updated Date)
   - ✅ **priority** (Priority)
   - ✅ **issuetype** (Issue Type)
   - ✅ **project** (Project)

---

## **STEP 4: Create Your First Report**

1. **Click "Create Report"**
2. **Add a Card visual**:
   - Drag **"Count of Key"** to the card
   - This shows total issues
3. **Add a Bar Chart**:
   - **X-axis**: Status
   - **Y-axis**: Count of Key
4. **Add a Table**:
   - **Columns**: Key, Summary, Status, Assignee, Project

---

## **STEP 5: Create Basic Measures**

1. **Click the "..." menu** next to your dataset
2. **Select "Manage"**
3. **Click "New Measure"**
4. **Add these measures**:

```dax
Total Issues = COUNT(Issues[Key])
```

```dax
Open Issues = 
CALCULATE(
    COUNT(Issues[Key]),
    Issues[Status] = "Open"
)
```

```dax
Done Issues = 
CALCULATE(
    COUNT(Issues[Key]),
    Issues[Status] = "Done"
)
```

---

## **STEP 6: Create a Dashboard**

1. **Click "Create"** → **"Dashboard"**
2. **Name it**: "OMF Jira Analytics"
3. **Pin visuals** from your report to the dashboard
4. **Add tiles** for key metrics

---

## **STEP 7: Set Up Automatic Refresh**

1. **Go to your dataset settings**
2. **Click "Scheduled refresh"**
3. **Enable refresh**
4. **Set frequency**: Daily or Weekly
5. **Configure credentials** if needed

---

## **Benefits of PowerBI Service**

- ✅ **No installation required** - works in any browser
- ✅ **Automatic refresh** - data stays up to date
- ✅ **Team sharing** - share dashboards with colleagues
- ✅ **Mobile access** - view on phone/tablet
- ✅ **Enterprise security** - integrated with OMF systems

---

## **Troubleshooting**

**"Authentication Failed"**
- Make sure you're using your OMF email and password
- Check if you need to complete 2FA
- Verify you have access to the Jira instance

**"No Data"**
- Check your Jira URL is correct
- Verify you have permission to access the data
- Try reducing the maxResults parameter

**"Connector Not Available"**
- Use the Web data source method instead
- Contact your IT team to enable additional connectors

**"Refresh Failed"**
- Check your credentials are still valid
- Verify the data source URL is accessible
- Contact your IT team if issues persist

---

## **Next Steps**

1. **Share your dashboard** with team members
2. **Create additional reports** for different views
3. **Set up alerts** for key metrics
4. **Schedule regular refreshes** to keep data current

**You now have Jira analytics in PowerBI Service without needing Desktop!** 🎉
