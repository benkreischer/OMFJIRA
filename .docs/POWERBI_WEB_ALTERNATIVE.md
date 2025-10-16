# 🌐 PowerBI Web Alternative - No Desktop Required

## Why This Works
- Uses your browser (no admin restrictions)
- Same functionality as PowerBI Desktop
- Can import our Power Query files
- Works with your OMF credentials

## Step-by-Step Setup

### Step 1: Access PowerBI Service
1. Go to [app.powerbi.com](https://app.powerbi.com)
2. Sign in with your OMF credentials: `ben.kreischer.ce@omf.com`
3. You should have access since it's web-based

### Step 2: Create New Dataset
1. Click **"Create"** → **"Dataset"**
2. Choose **"Import Excel workbook"** or **"Other data sources"**
3. Select **"Web"** as your data source

### Step 3: Configure Jira Connection
1. **URL**: `https://onemain.atlassian.net/rest/api/3/search?jql=ORDER BY created DESC&maxResults=100`
2. **Authentication**: Basic
3. **Username**: `ben.kreischer.ce@omf.com`
4. **Password**: Your Jira API token (not your OMF password)

### Step 4: Use Our Power Query Code
Copy the M code from `powerbi-desktop-simple.pq` and paste it into the Advanced Editor in PowerBI Service.

## Alternative: Excel with Power Query
If PowerBI Service also has restrictions, use Excel:
1. Open Excel
2. **Data** → **Get Data** → **From Other Sources** → **Blank Query**
3. Paste our Power Query code
4. Build your analytics there

## Test Your Access
Try accessing these URLs with your OMF credentials:
- [PowerBI Service](https://app.powerbi.com) ✅ Should work
- [PowerBI Desktop Download](https://aka.ms/pbidesktop) ❌ Blocked on personal PC

---

**Next Step**: Try accessing PowerBI Service first, then we'll set up your Jira connection there!
