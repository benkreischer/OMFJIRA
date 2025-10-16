# 🚀 PowerBI Desktop - Simple Setup with OMF Login

## Quick Setup (5 minutes)

### Step 1: Get Your Jira API Token
1. Go to [Atlassian Account Settings](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Click **"Create API token"**
3. Name it: `PowerBI Analytics`
4. Copy the token (starts with `ATATT3...`)

### Step 2: Open PowerBI Desktop
1. Launch PowerBI Desktop
2. Click **"Get Data"** → **"More..."**
3. Search for **"Web"** and select it
4. Click **"Connect"**

### Step 3: Configure Jira Connection
1. **URL**: `https://onemain.atlassian.net/rest/api/3/search`
2. **HTTP Headers**:
   - **Name**: `Authorization`
   - **Value**: `Basic [YOUR_BASE64_ENCODED_CREDENTIALS]`

### Step 4: Create Base64 Credentials
Use this PowerShell command (replace with your actual credentials):

```powershell
$username = "your.omf.email@onemain.com"
$apiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk=641B9570"
$credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$username`:$apiToken"))
Write-Host "Use this in PowerBI: Basic $credentials"
```

### Step 5: Test Connection
1. Click **"OK"** in PowerBI
2. You should see JSON data from Jira
3. Click **"Transform Data"**

### Step 6: Load Your First Dataset
1. In Power Query Editor, expand the **"issues"** table
2. Select the columns you want
3. Click **"Close & Apply"**

## 🎯 Ready-to-Use Queries

I'll create a simple Power Query file that you can import directly into PowerBI Desktop:

### Basic Issues Query
```m
let
    // Your Jira connection
    BaseUrl = "https://onemain.atlassian.net",
    Username = "your.omf.email@onemain.com",
    ApiToken = "YOUR_API_TOKEN_HERE",
    
    // Create authentication
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Get issues
    Url = BaseUrl & "/rest/api/3/search?jql=ORDER BY created DESC&maxResults=100",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    
    // Convert to table
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    ExpandedIssues = Table.ExpandRecordColumn(IssuesTable, "Column1", {"id", "key", "summary", "status", "assignee", "created", "updated"}, {"Issue ID", "Key", "Summary", "Status", "Assignee", "Created", "Updated"})
in
    ExpandedIssues
```

## 🔧 Advanced Setup Options

### Option 1: Use Our Pre-built Queries
1. Copy any of the `.pq` files from this repository
2. Replace the credentials in the file
3. Import into PowerBI Desktop

### Option 2: Use PowerBI's Built-in Jira Connector
1. **Get Data** → **Online Services** → **Jira**
2. **Server URL**: `https://onemain.atlassian.net`
3. **Authentication**: Basic
4. **Username**: Your OMF email
5. **Password**: Your API token (not your actual password)

## 📊 Quick Dashboard Creation

### Essential Visualizations:
1. **Issue Status Pie Chart**
2. **Issues Created Over Time (Line Chart)**
3. **Assignee Workload (Bar Chart)**
4. **Project Summary (Table)**

### DAX Measures to Add:
```dax
Total Issues = COUNTROWS(Issues)
Open Issues = CALCULATE(COUNTROWS(Issues), Issues[Status] = "Open")
Closed This Month = CALCULATE(COUNTROWS(Issues), 
    Issues[Status] = "Done", 
    MONTH(Issues[Updated]) = MONTH(TODAY())
)
```

## 🚨 Troubleshooting

### Common Issues:
1. **401 Unauthorized**: Check your API token
2. **403 Forbidden**: Verify you have Jira access
3. **Timeout**: Reduce maxResults in your query
4. **Date Issues**: Use our date conversion formulas

### Test Your Connection:
```powershell
# Test in PowerShell first
$headers = @{
    'Authorization' = "Basic $credentials"
    'Content-Type' = 'application/json'
}
Invoke-RestMethod -Uri "https://onemain.atlassian.net/rest/api/3/myself" -Headers $headers
```

## 🎉 Next Steps

1. **Start Simple**: Get basic issues working first
2. **Add More Data**: Import our advanced query files
3. **Create Dashboards**: Build your first dashboard
4. **Share**: Publish to PowerBI Service for team access

## 📁 Files to Use

- `jira-queries-1-basic-info.pq` - Start here
- `jira-queries-2-project-analytics.pq` - Project insights
- `jira-queries-3-team-performance.pq` - Team metrics
- `powerbi-jira-dax-measures.pbix` - Pre-built measures

---

**Need Help?** All the advanced query files in this repository are ready to use - just update the credentials and import into PowerBI Desktop!
