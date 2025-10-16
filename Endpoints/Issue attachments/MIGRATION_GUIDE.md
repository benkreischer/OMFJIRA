# Project Attachment Migration Guide

## Overview
This guide provides step-by-step instructions for extracting and downloading all attachments from Jira projects for migration purposes.

---

## Prerequisites
- PowerShell access
- Jira API credentials configured in scripts
- Access to: `Z:\Code\OMF\`

---

## Step 0: Generate Gold Copy Data (One-Time Setup)

**Purpose:** Create a master reference file of all cross-project links and issue data.

**Location:** `Z:\Code\OMF\Affinity`

**Command:**
```
cd "Z:\Code\OMF\Affinity"
.\export_all_cross_project_links_complete.ps1
```

**What this does:**
- Reads all issues with links from the endpoint data file
- Extracts ALL cross-project links (no filters applied)
- Processes approximately 33,897 issues
- Creates: `Complete_Cross_Project_Links_Gold_Copy.csv` (24,717 cross-project links)

**Time estimate:** 10-15 minutes

**Output file contains:**
- Source and target project keys
- Source and target issue keys  
- Full issue details for both sides (summary, status, assignee, reporter, dates, etc.)
- Link direction (Inbound/Outbound)

**Important:** You only need to run this once - it becomes your master reference file for all projects.

---

## Step 1: Get Attachment List for a Project

**Purpose:** Extract attachment metadata for a specific project.

**Location:** `Z:\Code\OMF\.endpoints\Issue attachments`

**Command:**
```
cd "Z:\Code\OMF\.endpoints\Issue attachments"
.\Get-Project-Attachments-From-Data.ps1 -ProjectKey "PROJECTKEY"
```

Replace `PROJECTKEY` with your target project (e.g., "ENGOPS", "CIA", "PAY")

**What this does:**
- Reads the gold copy CSV to find all unique issue keys for the project
- Calls Jira REST API `/rest/api/3/issue/{issueIdOrKey}` for each issue
- Extracts attachment metadata from each issue
- Creates: `Project_PROJECTKEY_Attachments.csv`

**Time estimate:** 1-2 minutes per 100 issues

**Output CSV contains:**
- ProjectKey, IssueKey, IssueSummary, IssueStatus, IssueType, IssuePriority
- IssueAssignee, IssueReporter, IssueCreated, IssueUpdated
- AttachmentId, AttachmentFilename, AttachmentSize, AttachmentMimeType
- AttachmentCreated, AttachmentAuthor, AttachmentContentUrl, AttachmentThumbnailUrl

---

## Step 2: Download All Attachments

**Purpose:** Download all attachment files from Jira to local storage.

**Location:** Same as Step 1

**Command:**
```
.\Download-Project-Attachments.ps1 -ProjectKey "PROJECTKEY"
```

Replace `PROJECTKEY` with the same project key from Step 1

**What this does:**
- Reads the CSV from Step 1
- Downloads each attachment using the ContentUrl from Jira API
- Organizes files by issue key in subfolders
- Skips files that already exist (safe to re-run)
- Shows progress for each download with file size

**Time estimate:** 
- Small projects (100 MB): 2-5 minutes
- Medium projects (500 MB): 5-15 minutes
- Large projects (1 GB+): 15-30 minutes

**Output structure:**
```
Attachments_PROJECTKEY/
├── ISSUEKEY-001/
│   ├── attachment1.png
│   └── attachment2.xlsx
├── ISSUEKEY-002/
│   └── document.pdf
└── ...
```

---

## Complete Example: ENGOPS Project Migration

### Step-by-step execution:

**Step 0: Generate gold copy (if not already done)**
```
cd "Z:\Code\OMF\Affinity"
.\export_all_cross_project_links_complete.ps1
```
- Output: `Complete_Cross_Project_Links_Gold_Copy.csv` (24,717 links)
- Time: ~10-15 minutes

**Step 1: Get ENGOPS attachment list**
```
cd "Z:\Code\OMF\.endpoints\Issue attachments"
.\Get-Project-Attachments-From-Data.ps1 -ProjectKey "ENGOPS"
```
- Output: `Project_ENGOPS_Attachments.csv` (267 attachments from 431 issues)
- Time: ~4-5 minutes

**Step 2: Download all ENGOPS attachments**
```
.\Download-Project-Attachments.ps1 -ProjectKey "ENGOPS"
```
- Output: `Attachments_ENGOPS/` folder (694 MB in 127 issue folders)
- Time: ~8-10 minutes

### ENGOPS Results:
- **431 issues** checked
- **127 issues** with attachments (29%)
- **267 total attachments** downloaded
- **694.29 MB** total size

**File Type Breakdown:**
- PNG images: 175 files (66%)
- Excel spreadsheets: 76 files (28%)
- Word documents: 7 files
- SVG images: 4 files
- ZIP archives: 3 files
- MP4 video: 1 file
- Excel macro-enabled: 1 file

---

## Multiple Project Migration

For migrating multiple projects, repeat Steps 1-2 for each project after completing Step 0 once:

```
# One-time setup (if not already done)
cd "Z:\Code\OMF\Affinity"
.\export_all_cross_project_links_complete.ps1

# Then for each project:
cd "Z:\Code\OMF\.endpoints\Issue attachments"

# Project 1: CIA
.\Get-Project-Attachments-From-Data.ps1 -ProjectKey "CIA"
.\Download-Project-Attachments.ps1 -ProjectKey "CIA"

# Project 2: PAY
.\Get-Project-Attachments-From-Data.ps1 -ProjectKey "PAY"
.\Download-Project-Attachments.ps1 -ProjectKey "PAY"

# Project 3: COR
.\Get-Project-Attachments-From-Data.ps1 -ProjectKey "COR"
.\Download-Project-Attachments.ps1 -ProjectKey "COR"
```

---

## Final Directory Structure

After completing all steps, your directory structure will look like:

```
Z:\Code\OMF\
│
├── Affinity\
│   └── Complete_Cross_Project_Links_Gold_Copy.csv    # Master reference file
│
└── .endpoints\Issue attachments\
    ├── Get-Project-Attachments-From-Data.ps1         # Step 1 script
    ├── Download-Project-Attachments.ps1              # Step 2 script
    │
    ├── Project_ENGOPS_Attachments.csv                # Metadata inventories
    ├── Project_CIA_Attachments.csv
    ├── Project_PAY_Attachments.csv
    │
    ├── Attachments_ENGOPS\                           # Downloaded files by project
    │   ├── ENGOPS-4718\
    │   │   └── image-20250923-174606.png
    │   ├── ENGOPS-4609\
    │   │   └── Screenshot.png
    │   └── ... (127 issue folders)
    │
    ├── Attachments_CIA\
    └── Attachments_PAY\
```

---

## Time Estimates by Project Size

| Step | Small Project (50 issues) | Medium (200 issues) | Large (500+ issues) |
|------|---------------------------|---------------------|---------------------|
| Step 0 (one-time) | Runs for all projects - approximately 15 minutes | Same | Same |
| Step 1 (Get list) | ~30 seconds | ~2 minutes | ~5 minutes |
| Step 2 (Download) | ~2-5 minutes | ~10-15 minutes | ~30+ minutes |
| **Total per project** | **~5 minutes** | **~15 minutes** | **~40 minutes** |

Note: Step 0 only needs to be run once regardless of how many projects you migrate.

---

## Migration Checklist

### Pre-Migration
- [ ] Run Step 0: Gold copy generator (one time only)
- [ ] Verify `Complete_Cross_Project_Links_Gold_Copy.csv` exists and contains data

### Per-Project Migration
- [ ] Run Step 1: Get attachment inventory CSV
- [ ] Verify CSV row count matches expected attachments
- [ ] Check console output for any API errors
- [ ] Run Step 2: Download all attachments
- [ ] Verify "Successfully Downloaded" count matches CSV row count
- [ ] Check total size matches summary output
- [ ] Verify folder structure created correctly

### Post-Migration Validation
- [ ] Compare CSV row count to number of downloaded files
- [ ] Verify no "Failed" downloads in summary output
- [ ] Check total file size matches between summary and actual files
- [ ] Spot-check random files to ensure they're not corrupted
- [ ] Test opening various file types (images, documents, spreadsheets)

---

## Troubleshooting

### Step 0 Issues

**Problem:** Script fails to find source data file

**Solution:** 
- Verify you're in the correct directory: `Z:\Code\OMF\Affinity`
- Check that `..\.endpoints\Issue links\Issue Links - GET All Issues with Links - Anon - Hybrid.csv` exists

---

### Step 1 Issues

**Problem:** "410 Gone" or other API errors

**Solution:**
- Check API credentials are valid in the script
- Verify gold copy CSV exists at: `Z:\Code\OMF\Affinity\Complete_Cross_Project_Links_Gold_Copy.csv`
- Test with a smaller project first
- Check network connection to Jira

**Problem:** "Project not found" or "No issues found"

**Solution:**
- Verify project key spelling (case-sensitive)
- Check that project exists in the gold copy CSV
- Confirm project has issues with links

---

### Step 2 Issues

**Problem:** Download failures or timeouts

**Solution:**
- Re-run the script (it will automatically skip already downloaded files)
- Check available disk space
- Verify network connection stability
- Check Jira API rate limits

**Problem:** "File already exists" warnings

**Solution:**
- This is normal behavior - the script skips files that already exist
- If you want to re-download, delete the specific file or folder first

---

## Important Notes

1. **Resume Capability:** Step 2 (Download) can be safely re-run. It will skip files that already exist with the correct size.

2. **API Rate Limiting:** If processing large projects (500+ issues), you may encounter rate limits. The scripts include small delays to mitigate this.

3. **Network Requirements:** Downloading large attachments requires stable network connection. If interrupted, simply re-run Step 2.

4. **Storage Requirements:** Ensure adequate disk space. Check the CSV file size totals before downloading.

5. **File Naming:** Original filenames are preserved. Files are organized by issue key for easy reference.

6. **Authentication:** API credentials are embedded in the scripts. Ensure scripts are kept secure.

---

## Support & Questions

For issues or questions about this migration process, please contact the migration team or refer to Jira API documentation:
- Jira REST API v3: https://developer.atlassian.com/cloud/jira/platform/rest/v3/
- Issue Attachments: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-attachments/

---

**Last Updated:** October 2025
**Version:** 1.0

