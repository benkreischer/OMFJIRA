# Jira Date Field Conversion Guide
## Converting Text Dates to Proper Date/Time Fields

This guide shows you how to properly convert Jira date fields from text strings to proper date/time data types in both Power Query and PowerBI.

## 🚨 **The Problem**

Jira API returns date fields as text strings in ISO 8601 format:
- **Created**: `"2024-01-15T10:30:00.000+0000"`
- **Updated**: `"2024-01-16T14:45:00.000+0000"`
- **Due Date**: `"2024-01-20T17:00:00.000+0000"`
- **Resolution Date**: `"2024-01-18T16:20:00.000+0000"`

These need to be converted to proper date/time fields for:
- ✅ **Time intelligence** functions (MTD, QTD, YTD)
- ✅ **Date filtering** and comparisons
- ✅ **Calculated measures** and columns
- ✅ **Proper sorting** and grouping
- ✅ **Chart axes** and time series

## 🔧 **Solution Methods**

### **Method 1: Basic Date Conversion (Power Query)**

```m
// Convert date fields from text to proper date/time
ConvertDates = Table.TransformColumns(IssuesExpanded, {
    {"Created", DateTime.FromText},
    {"Updated", DateTime.FromText},
    {"Due Date", DateTime.FromText},
    {"Resolution Date", DateTime.FromText}
})
```

### **Method 2: Advanced Date Conversion with Error Handling**

```m
// Advanced date conversion with error handling
ConvertDatesAdvanced = Table.TransformColumns(IssuesExpanded, {
    {"Created", each try DateTime.FromText(_) otherwise null, type datetime},
    {"Updated", each try DateTime.FromText(_) otherwise null, type datetime},
    {"Due Date", each try DateTime.FromText(_) otherwise null, type datetime},
    {"Resolution Date", each try DateTime.FromText(_) otherwise null, type datetime}
})
```

### **Method 3: Custom Date Conversion Function**

```m
// Custom function to convert Jira date strings
ConvertJiraDate = (dateText as text) as datetime =>
let
    // Handle null or empty values
    CleanDate = if dateText = null or dateText = "" then null else dateText,
    // Convert to datetime
    ConvertedDate = if CleanDate = null then null else DateTime.FromText(CleanDate)
in
    ConvertedDate
```

## 📊 **Complete Implementation Example**

### **Step 1: Update Your Power Query**

Replace your existing Power Query with this enhanced version:

```m
let
    // Configuration
    BaseUrl = "https://onemain.atlassian.net/rest/api/3",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk-gqtFXmE9clWFzrMyxC-XO3ICoSsSj5MQ9OJfC1larPkBQ91iHWgkE5UbHk=641B9570",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),
    
    // Custom date conversion function
    ConvertJiraDate = (dateText as text) as datetime =>
    let
        CleanDate = if dateText = null or dateText = "" then null else dateText,
        ConvertedDate = if CleanDate = null then null else DateTime.FromText(CleanDate)
    in
        ConvertedDate,
    
    // API call
    Url = BaseUrl & "/search?jql=ORDER BY updated DESC&maxResults=1000",
    Headers = [#"Authorization" = AuthHeader, #"Content-Type" = "application/json"],
    Response = Json.Document(Web.Contents(Url, [Headers = Headers])),
    Issues = Response[issues],
    IssuesTable = Table.FromList(Issues, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
    IssuesExpanded = Table.ExpandRecordColumn(Table.ExpandRecordColumn(IssuesTable, "Column1", {"key", "fields", "id"}, {"Key", "Fields", "ID"}), "Fields", {"summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "duedate", "resolutiondate"}, {"Summary", "Status", "Assignee", "Reporter", "Created", "Updated", "Priority", "Issue Type", "Due Date", "Resolution Date"}),
    
    // Convert all date fields
    ConvertDates = Table.TransformColumns(IssuesExpanded, {
        {"Created", ConvertJiraDate, type datetime},
        {"Updated", ConvertJiraDate, type datetime},
        {"Due Date", ConvertJiraDate, type datetime},
        {"Resolution Date", ConvertJiraDate, type datetime}
    }),
    
    // Add calculated date columns
    AddCalculatedColumns = Table.AddColumn(ConvertDates, "Created Date Only", each DateTime.Date([Created]), type date),
    AddCalculatedColumns2 = Table.AddColumn(AddCalculatedColumns, "Updated Date Only", each DateTime.Date([Updated]), type date),
    AddCalculatedColumns3 = Table.AddColumn(AddCalculatedColumns2, "Due Date Only", each DateTime.Date([Due Date]), type date),
    AddCalculatedColumns4 = Table.AddColumn(AddCalculatedColumns3, "Resolution Date Only", each DateTime.Date([Resolution Date]), type date),
    
    // Add time-based calculated columns
    AddTimeColumns = Table.AddColumn(AddCalculatedColumns4, "Days Since Created", each Duration.Days(DateTime.LocalNow() - [Created]), type number),
    AddTimeColumns2 = Table.AddColumn(AddTimeColumns, "Days Since Updated", each Duration.Days(DateTime.LocalNow() - [Updated]), type number),
    AddTimeColumns3 = Table.AddColumn(AddTimeColumns2, "Days Until Due", each if [Due Date] = null then null else Duration.Days([Due Date] - DateTime.LocalNow()), type number),
    AddTimeColumns4 = Table.AddColumn(AddTimeColumns3, "Resolution Time Days", each if [Resolution Date] = null then null else Duration.Days([Resolution Date] - [Created]), type number)
    
in
    AddTimeColumns4
```

### **Step 2: Verify Data Types**

After applying the conversion, verify that your date fields show as:
- **Created**: `DateTime` (not Text)
- **Updated**: `DateTime` (not Text)
- **Due Date**: `DateTime` (not Text)
- **Resolution Date**: `DateTime` (not Text)

## 📈 **Enhanced DAX Measures for Date Fields**

### **Time Intelligence Measures**

```dax
// Issues Created This Month
Issues Created MTD = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    DATESMTD(Issues[Created Date Only])
)

// Issues Created Last Month
Issues Created LMP = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    DATESMTD(DATEADD(Issues[Created Date Only], -1, MONTH))
)

// Issues Created This Quarter
Issues Created QTD = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    DATESQTD(Issues[Created Date Only])
)

// Issues Created This Year
Issues Created YTD = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    DATESYTD(Issues[Created Date Only])
)

// Month-over-Month Growth
MoM Growth = 
DIVIDE(
    [Issues Created MTD] - [Issues Created LMP],
    [Issues Created LMP]
)
```

### **Resolution Time Measures**

```dax
// Average Resolution Time (Days)
Avg Resolution Time = 
AVERAGE(Issues[Resolution Time Days])

// Median Resolution Time (Days)
Median Resolution Time = 
MEDIAN(Issues[Resolution Time Days])

// Issues Resolved This Month
Issues Resolved MTD = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    Issues[Status] = "Done",
    DATESMTD(Issues[Resolution Date Only])
)

// Resolution Rate
Resolution Rate = 
DIVIDE(
    [Issues Resolved MTD],
    [Issues Created MTD]
)
```

### **Overdue and Due Date Measures**

```dax
// Overdue Issues
Overdue Issues = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    Issues[Due Date Only] < TODAY(),
    Issues[Status] <> "Done"
)

// Issues Due Today
Issues Due Today = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    Issues[Due Date Only] = TODAY(),
    Issues[Status] <> "Done"
)

// Issues Due This Week
Issues Due This Week = 
CALCULATE(
    COUNT(Issues[Issue Key]),
    Issues[Due Date Only] >= TODAY(),
    Issues[Due Date Only] <= TODAY() + 7,
    Issues[Status] <> "Done"
)

// Average Days Until Due
Avg Days Until Due = 
AVERAGE(Issues[Days Until Due])
```

## 🎯 **Common Date Field Issues and Solutions**

### **Issue 1: Null Date Values**

**Problem**: Some issues don't have due dates or resolution dates
**Solution**: Use error handling in conversion

```m
{"Due Date", each try DateTime.FromText(_) otherwise null, type datetime}
```

### **Issue 2: Different Date Formats**

**Problem**: Jira might return dates in different formats
**Solution**: Use flexible date parsing

```m
ConvertFlexibleDate = (dateText as text) as datetime =>
let
    CleanDate = if dateText = null or dateText = "" then null else dateText,
    ConvertedDate = if CleanDate = null then null else 
        try DateTime.FromText(CleanDate) otherwise
        try DateTime.FromText(CleanDate, "yyyy-MM-dd") otherwise
        try DateTime.FromText(CleanDate, "MM/dd/yyyy") otherwise null
in
    ConvertedDate
```

### **Issue 3: Time Zone Issues**

**Problem**: Dates might be in different time zones
**Solution**: Convert to local time zone

```m
ConvertToLocalTime = (dateText as text) as datetime =>
let
    CleanDate = if dateText = null or dateText = "" then null else dateText,
    ConvertedDate = if CleanDate = null then null else DateTime.FromText(CleanDate),
    LocalTime = if ConvertedDate = null then null else DateTimeZone.ToLocal(ConvertedDate)
in
    LocalTime
```

## 🔄 **Updating Existing Queries**

### **For Existing Power Query:**

1. **Open** your existing Power Query
2. **Go to** Advanced Editor
3. **Add** the date conversion step after expanding fields
4. **Test** the conversion
5. **Refresh** the data

### **For Existing PowerBI Model:**

1. **Open** PowerBI Desktop
2. **Go to** Data view
3. **Select** date columns
4. **Change** data type to Date/Time
5. **Refresh** the model

## 📊 **Testing Date Conversion**

### **Verification Steps:**

1. **Check Data Types**: Ensure date fields show as DateTime, not Text
2. **Test Time Intelligence**: Verify MTD, QTD, YTD measures work
3. **Test Filtering**: Ensure date filters work properly
4. **Test Sorting**: Verify dates sort chronologically
5. **Test Calculations**: Ensure date arithmetic works

### **Sample Test Measures:**

```dax
// Test measure to verify date conversion
Date Test = 
VAR TestDate = SELECTEDVALUE(Issues[Created Date Only])
VAR TestResult = IF(TestDate = BLANK(), "No Date", "Date Found")
RETURN TestResult

// Test measure for date arithmetic
Date Arithmetic Test = 
VAR CreatedDate = SELECTEDVALUE(Issues[Created Date Only])
VAR DaysDiff = DATEDIFF(CreatedDate, TODAY(), DAY)
RETURN DaysDiff
```

## 🚀 **Best Practices**

### **1. Always Use Error Handling**
```m
{"Date Field", each try DateTime.FromText(_) otherwise null, type datetime}
```

### **2. Add Both Date and DateTime Columns**
- **DateTime**: For precise timestamps
- **Date**: For date-only operations and grouping

### **3. Use Consistent Date Formats**
- **ISO 8601**: Standard format for APIs
- **Local Time**: Convert to user's time zone

### **4. Validate Date Ranges**
```dax
// Validate date ranges
Valid Date Range = 
IF(
    Issues[Created Date Only] >= DATE(2020, 1, 1) && 
    Issues[Created Date Only] <= TODAY(),
    "Valid",
    "Invalid"
)
```

### **5. Handle Null Values Gracefully**
```dax
// Handle null dates in measures
Safe Date Measure = 
IF(
    ISBLANK(Issues[Due Date Only]),
    "No Due Date",
    FORMAT(Issues[Due Date Only], "MM/dd/yyyy")
)
```

## 🆘 **Troubleshooting**

### **Common Errors:**

**"Cannot convert value to DateTime"**
- Check date format in source data
- Add error handling with try/otherwise

**"Date field shows as text"**
- Verify data type conversion in Power Query
- Check for null or empty values

**"Time intelligence not working"**
- Ensure date field is proper DateTime type
- Check for date table relationships

**"Dates not sorting correctly"**
- Verify data type is DateTime, not Text
- Check for mixed date formats

### **Debug Steps:**

1. **Inspect** raw data from API
2. **Check** data types in Power Query
3. **Verify** conversion functions
4. **Test** with sample data
5. **Validate** in PowerBI model

---

**Next Steps**: Apply the date conversion to your existing queries, test the conversion, and then use the enhanced DAX measures for proper time intelligence and date-based analytics.
