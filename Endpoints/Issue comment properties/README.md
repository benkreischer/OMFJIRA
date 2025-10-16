# Issue Comment Properties API Endpoints

## Important Note

These endpoints require **valid comment IDs** to function properly. The scripts are currently configured with placeholder comment ID `326710` which may not exist in your Jira instance.

## How to Use These Scripts

### 1. Find a Valid Comment ID

Before running these scripts, you need to find a valid comment ID from your Jira instance:

1. Go to any Jira issue that has comments
2. Open the issue in your browser
3. Right-click on a comment and inspect the HTML to find the comment ID
4. Or use the Jira REST API to search for issues with comments

### 2. Update the Comment ID

Edit the following files and replace `326710` with a valid comment ID:

- `Issue Comment Properties - GET Comment property keys - Anon - Official.ps1` (line ~29)
- `Issue Comment Properties - GET Comment property - Anon - Official.ps1` (line ~29)
- `Issue Comment Properties - GET Comment property keys - Anon - Official.pq` (line ~27)
- `Issue Comment Properties - GET Comment property - Anon - Official.pq` (line ~27)

### 3. Understanding the Scripts

**GET Comment property keys**: Returns all property keys for a specific comment (most comments have no custom properties, so this often returns empty)

**GET Comment property**: Returns the value of a specific property for a specific comment (requires both comment ID and property key)

## Current Status

✅ **Scripts are functional** - they handle errors gracefully and return "No data returned" when the comment doesn't exist
⚠️ **Need valid comment ID** - replace placeholder `326710` with actual comment ID from your Jira instance
✅ **Error handling** - scripts create error CSV files when API calls fail