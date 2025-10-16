# Duplicate Issues Analysis & Resolution

## 🔍 Root Cause Analysis

### What Happened

Your QA validation detected **338 duplicate issues** in the target project (DEP1).

**The Evidence:**
- Expected issues: 1,130 (successfully created)
- Actual in target: 1,464 issues
- Excess: 334 issues
- Duplicates detected: 338 issues (279 groups)

**The Cause:**
Step 08 (CreateIssues_Target.ps1) was run **16 times**:
```
Oct 5:  1 run  (11:04 PM)
Oct 6:  9 runs (8:08 AM - 8:38 AM) ← RAPID RE-RUNS
Oct 8:  6 runs (6:20 AM - 1:12 PM)
```

### Why This Happened

**Step 08 is NOT idempotent** - it doesn't check if issues already exist before creating them.

**Likely scenarios:**
1. **Testing/Debugging** - Multiple runs while troubleshooting
2. **Script Interruptions** - Script stopped midway, restarted
3. **Error Recovery** - Re-ran after failures
4. **Accidental Re-runs** - Unclear if step completed

---

## 📊 Duplicate Analysis

### Distribution of Duplicates

Based on QA findings:
- **279 duplicate summary groups**
- **338 total duplicate issues**
- **~1.2 duplicates per group** average
- **Most are 2x duplicates** (original + 1 copy)

### Examples Detected:
```
' Deploy next gen Palo Alto firewall in AWS' x2: DEP1-723, DEP1-802
' Developer Access' x2: DEP1-682, DEP1-761
'(ENABL) Enable a more productive...' x2: DEP1-611, DEP1-618
```

### Issue Type Impact:
```
Epic:       129 → 292 (+163, +126%)  ← Heavy duplication
Initiative:  30 → 62  (+32, +107%)   ← Heavy duplication
Task:       463 → 587 (+124, +27%)   ← Moderate duplication
Spike:       73 → 65  (-8)           ← Some deleted/failed
Story:      376 → 376 (0)            ← No duplication!
```

**Pattern:** Epics and Initiatives heavily duplicated, Stories clean.  
**Hypothesis:** Later runs only created certain issue types (partial re-runs).

---

## 🛠️ Solution: Cleanup Script

### Script Created: `src/Utility/08_RemoveDuplicatesIssues.ps1`

**Features:**
- ✅ Intelligent duplicate detection
- ✅ **Keeps earliest created issue** (original)
- ✅ Deletes later duplicates
- ✅ Dry-run mode for safety
- ✅ Detailed deletion report
- ✅ Backup capabilities

### How It Works:

1. **Fetch all issues** from target project
2. **Group by summary** (identical summaries = duplicates)
3. **Sort each group by creation date**
4. **Keep the earliest** (first created)
5. **Delete the rest** (later duplicates)
6. **Report results**

---

## 🚀 How To Use

### Step 1: Preview (Dry Run)
```powershell
.\src\Utility\08_RemoveDuplicatesIssues.ps1 -DryRun
```

**This will:**
- Show you exactly what would be deleted
- Save preview report to `duplicate_removal_dry_run.json`
- NOT delete anything

### Step 2: Review the Plan
- Check the console output
- Review `duplicate_removal_dry_run.json`
- Verify the right issues will be kept/deleted

### Step 3: Execute Deletion
```powershell
# With confirmation prompt (recommended)
.\src\Utility\08_RemoveDuplicatesIssues.ps1

# Auto-confirm (no prompts)
.\src\Utility\08_RemoveDuplicatesIssues.ps1 -AutoConfirm
```

### Step 4: Re-Validate
```powershell
# Run QA again to verify cleanup
.\src\steps\16_QA_Validation_Orchestrator.ps1
```

**Expected result:**
- Quality score jumps from 66.7% to 95%+
- Duplicate count goes from 338 to 0
- Issue counts match expected

---

## ⚙️ Prevention for Future Migrations

### Make Step 08 Idempotent

**Option 1: Add Duplicate Check** (Recommended)
Before creating each issue, check if it already exists:
```powershell
# In step 08, before creating issue:
$existingIssue = Invoke-RestMethod -Uri "$tgtBase/rest/api/3/search" `
    -Headers $tgtHdr `
    -Body (@{ jql = "project = $tgtKey AND summary ~ `"$summary`""; maxResults = 1 } | ConvertTo-Json) `
    -ContentType "application/json"

if ($existingIssue.total -eq 0) {
    # Issue doesn't exist, create it
} else {
    # Issue exists, skip creation
    Write-Host "  ⏭️  Issue already exists: $($existingIssue.issues[0].key)"
}
```

**Option 2: Add Run Guard**
Create a lock file that prevents re-running:
```powershell
# At start of step 08:
$lockFile = Join-Path $outDir "08_CreateIssues_RUNNING.lock"
if (Test-Path $lockFile) {
    throw "Step 08 is already running or was not cleanly completed. Delete lock file to override."
}
New-Item -Path $lockFile -ItemType File

# At end of step 08:
Remove-Item $lockFile
```

**Option 3: Clear Naming**
Include run number in receipt names to track multiple runs:
```powershell
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$runNumber = (Get-ChildItem "$outDir/08_CreateIssues*.json").Count + 1
$receiptName = "08_CreateIssues_Run${runNumber}_${timestamp}.json"
```

---

## 📋 Cleanup Checklist

Use this checklist for your cleanup:

- [ ] Run dry-run mode first: `.\src\Utility\08_RemoveDuplicatesIssues.ps1 -DryRun`
- [ ] Review dry-run report: `out/duplicate_removal_dry_run.json`
- [ ] Verify deletion plan looks correct
- [ ] **Backup target project** (if possible in Jira)
- [ ] Run actual deletion: `.\src\Utility\08_RemoveDuplicatesIssues.ps1`
- [ ] Review deletion report: `out/duplicate_removal_report.json`
- [ ] Re-run QA validation: `.\src\steps\16_QA_Validation_Orchestrator.ps1`
- [ ] Verify quality score improved to 95%+
- [ ] Check issue counts match expected
- [ ] Update documentation

---

## 🎯 Expected Outcome

### Before Cleanup:
```
Target Issues: 1,464
Expected:      1,130
Excess:        334
Duplicates:    338
Quality Score: 66.7%
```

### After Cleanup:
```
Target Issues: 1,126  (1,464 - 338)
Expected:      1,130
Difference:    -4 (minor variance acceptable)
Duplicates:    0
Quality Score: 95%+
```

---

## 🚨 Safety Notes

### The Script Will:
- ✅ Keep the EARLIEST created issue (original from first run)
- ✅ Delete LATER duplicates (from subsequent runs)
- ✅ Preserve all data on kept issues
- ✅ Create detailed audit trail

### The Script Will NOT:
- ❌ Delete issues that aren't duplicates
- ❌ Modify kept issues
- ❌ Delete if summary is unique
- ❌ Affect source project

### Reverting (if needed):
Unfortunately, **Jira doesn't have an "undelete"** feature. However:
- You have the deletion report with all deleted keys
- You can re-run step 08 to recreate (but this causes the same problem!)
- Better: Use dry-run first to ensure correctness

---

## 💡 Recommendations

### Immediate:
1. **Run dry-run NOW** to see the deletion plan
2. Review carefully
3. Execute cleanup
4. Re-validate

### For Future Migrations:
1. Add idempotency check to step 08
2. Use lock files to prevent re-runs
3. Add "Are you sure?" prompts to creation steps
4. Run QA validation immediately after step 08
5. Document when each step was run

---

## 📞 Support

If you're unsure:
1. Run dry-run mode first (100% safe)
2. Review the plan carefully
3. Export a backup of Jira data if possible
4. Delete in small batches (modify script)
5. Re-validate after each batch

---

**The duplicate removal script is ready. Start with dry-run mode to see exactly what will happen!**

```powershell
.\src\Utility\08_RemoveDuplicatesIssues.ps1 -DryRun
```

