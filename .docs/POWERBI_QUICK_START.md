# 🚀 PowerBI Quick Start Guide

## **EASIEST METHOD: Use PowerBI's Built-in Jira Connector**

### **STEP 1: Open PowerBI Desktop**
1. Open PowerBI Desktop on your work PC
2. Click **"Get Data"**
3. Search for **"Jira"**
4. Select **"Jira"** from the list

### **STEP 2: Configure Connection**
1. **Server URL**: `https://onemain.atlassian.net`
2. **Authentication**: Select **"OAuth2"**
3. Click **"Sign in"**

### **STEP 3: Login with OMF Credentials**
1. You'll be redirected to OMF's login page
2. **Enter your OMF email and password**
3. **Complete any 2FA if prompted**
4. Click **"Allow"** to grant PowerBI access

### **STEP 4: Select Data**
1. **Expand "Issues"** in the navigator
2. **Check the boxes** for the data you want:
   - ✅ **Issues** (main table)
   - ✅ **Projects** (if you want project info)
   - ✅ **Users** (if you want user info)
3. Click **"Load"**

## **STEP 5: Create Your First Dashboard**

1. **Drag a "Card" visual** to the canvas
2. **Add "Total Issues"** measure (or just count of Key column)
3. **Drag a "Table" visual** to see the actual data
4. **Add columns**: Key, Summary, Status, Assignee, Project

## **STEP 6: Add Basic Measures**

In the **Fields** pane, right-click and **"New Measure"**:

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

## **STEP 7: Create Visualizations**

1. **Card Visual**: Total Issues, Open Issues, Done Issues
2. **Bar Chart**: Issues by Status
3. **Pie Chart**: Issues by Project
4. **Table**: Recent Issues with Key, Summary, Status, Assignee

## **That's It!**

You now have a basic Jira analytics dashboard in PowerBI!

## **Next Steps (Optional)**

- Add more measures from the DAX file
- Create more advanced visualizations
- Set up automatic refresh
- Share with your team

## **ALTERNATIVE METHOD: If Built-in Connector Doesn't Work**

### **Use Basic Authentication**
1. Click **"Get Data"** → **"Web"**
2. **URL**: `https://onemain.atlassian.net/rest/api/3/search?jql=ORDER BY updated DESC&maxResults=1000`
3. **Authentication**: Select **"Basic"**
4. **Username**: Your OMF email
5. **Password**: Your OMF password (not API token)

## **Troubleshooting**

**"Authentication Failed"**
- Make sure you're using your OMF email and password
- Check if you need to complete 2FA
- Verify you have access to the Jira instance

**"No Data"**
- Check your Jira URL is correct
- Verify you have permission to access the data
- Try reducing the maxResults parameter

**"OAuth Not Available"**
- Use the alternative Basic authentication method
- Or contact your IT team to enable OAuth for Jira
