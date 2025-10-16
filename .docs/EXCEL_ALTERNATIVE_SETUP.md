# 📊 Excel Alternative Setup

## **If PowerBI Service Also Has Restrictions**

If PowerBI Service also has restrictions, we can use Excel with Power Query instead!

---

## **STEP 1: Open Excel**

1. **Open Excel** (should be available on your work PC)
2. **Go to Data tab**
3. **Click "Get Data"** → **"From Web"**

---

## **STEP 2: Connect to Jira**

1. **URL**: `https://onemain.atlassian.net/rest/api/3/search?jql=ORDER BY updated DESC&maxResults=1000`
2. **Click "OK"**
3. **When prompted for authentication**:
   - Select **"Basic"**
   - **Username**: Your OMF email
   - **Password**: Your OMF password
4. **Click "Connect"**

---

## **STEP 3: Transform Data**

1. **Click "Transform Data"**
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

## **STEP 4: Load Data**

1. **Click "Close & Load"**
2. **Wait for data to load**
3. **You'll see your Jira data in Excel!**

---

## **STEP 5: Create Basic Analytics**

### **Create a Summary Table**
1. **Insert a new sheet**
2. **Create a pivot table** from your Jira data
3. **Add fields**:
   - **Rows**: Status
   - **Values**: Count of Key

### **Create Charts**
1. **Select your pivot table**
2. **Insert** → **Charts**
3. **Choose a chart type** (Bar, Pie, etc.)

### **Add Filters**
1. **Insert** → **Slicers**
2. **Select fields** like Status, Project, Assignee
3. **Use slicers to filter data**

---

## **STEP 6: Set Up Refresh**

1. **Go to Data tab**
2. **Click "Refresh All"** to update data
3. **Or right-click on the table** → **"Refresh"**

---

## **Benefits of Excel Approach**

- ✅ **No additional software** - uses existing Excel
- ✅ **Familiar interface** - most people know Excel
- ✅ **Easy sharing** - send Excel files to colleagues
- ✅ **Flexible analysis** - pivot tables and charts
- ✅ **No admin restrictions** - Excel is usually available

---

## **Advanced Excel Features**

### **Power Query Editor**
1. **Right-click on your table** → **"Edit Query"**
2. **Add calculated columns**:
   - Days since created
   - Resolution time
   - Status categories

### **Conditional Formatting**
1. **Select your data**
2. **Home** → **Conditional Formatting**
3. **Highlight cells** based on status, priority, etc.

### **Data Validation**
1. **Create dropdown lists** for filtering
2. **Use data validation** for consistent data entry

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

**"Power Query Not Available"**
- Check if Power Query is enabled in Excel
- Contact your IT team to enable Power Query
- Use the basic Excel import method instead

---

## **Next Steps**

1. **Create multiple sheets** for different views
2. **Add charts and pivot tables**
3. **Set up automatic refresh**
4. **Share with team members**

**You now have Jira analytics in Excel!** 📊
