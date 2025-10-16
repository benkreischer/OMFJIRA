# 🚀 PowerBI Simple OAuth Setup

## **EASIEST METHOD: Use PowerBI's Built-in Jira Connector**

### **STEP 1: Open PowerBI Desktop**
1. Open PowerBI Desktop
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

### **STEP 5: Create Your Dashboard**
1. **Card Visual**: Total Issues count
2. **Bar Chart**: Issues by Status
3. **Table**: Recent Issues with Key, Summary, Status, Assignee

## **That's It!**

No API tokens, no complex setup - just your OMF login credentials!

## **Benefits of This Approach:**
- ✅ **No API tokens needed** - just your OMF login
- ✅ **Automatic refresh** - PowerBI handles authentication
- ✅ **Secure** - OAuth2 is industry standard
- ✅ **User-friendly** - familiar login process
- ✅ **Team-ready** - everyone uses their own credentials

## **Alternative: Custom Query (If Built-in Connector Doesn't Work)**

If the built-in Jira connector doesn't work, use this simple approach:

### **STEP 1: Get Data → Web**
1. Click **"Get Data"** → **"Web"**
2. **URL**: `https://onemain.atlassian.net/rest/api/3/search?jql=ORDER BY updated DESC&maxResults=1000`

### **STEP 2: Authentication**
1. Select **"Basic"**
2. **Username**: Your OMF email
3. **Password**: Your OMF password (not API token)

### **STEP 3: Transform Data**
1. Click **"Transform Data"**
2. Expand the **"issues"** column
3. Expand the **"fields"** column
4. Select the fields you want

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
