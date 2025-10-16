# Quick Start Guide for Project Lead

**Project:** EO - Quality Assurance Sandbox  
**Target Project Key:** QUAL1  
**Migration Completed:** 2025-10-13 18:33

---

## 🎯 Welcome to Your Migrated Project!

Your Jira project has been successfully migrated. This guide will help you get started and complete the essential post-migration tasks.

---

## ✅ Week 1 Checklist - Critical Actions

### Day 1: User Access (30 minutes)

**📄 Open:** `03_UsersAndRoles_Report.csv`

1. **Review Successfully Added Users**
   - ✅ 14 users were added to the project
   - Verify your team members are included
   - Check that roles are correct

2. **Grant Assignable User Permission** ⭐ **IMPORTANT**
   - Go to: https://onemainfinancial-migrationsandbox.atlassian.net/plugins/servlet/project-config/QUAL1/permissions
   - Click "Assignable User"
   - Add roles that need to assign issues
   - **Why:** Users without this permission will fail when assigned to issues

3. **Resolve Failed Users** (if any)
   - 0 users failed to sync
   - Review the "Reason" column in the CSV
   - Contact Jira admin to resolve

**Estimated Time:** 30 minutes  
**Priority:** 🔴 **CRITICAL** - Do this first!

---

### Days 1-3: Fix Orphaned Issues (1-2 hours)

**📄 Open:** `08_OrphanedIssues.csv` in Excel

**What are orphaned issues?**
These are issues whose parent tasks were already resolved/completed and weren't migrated, leaving the child issues without parents.

**How to fix them:**

1. **Sort by Issue Type** (to batch similar items)

2. **For each issue:**
   ```
   Step 1: Click "Source URL" → See original parent relationship
   Step 2: Click "Target URL" → Opens issue in target Jira
   Step 3: Choose one:
      • Link to appropriate parent in target project
      • Leave as standalone (remove parent requirement)
      • Mark as "Won't Do" if no longer relevant
   ```

3. **Quick Action:**
   - In Target Jira, edit the issue
   - Under "Parent" field, search for appropriate parent
   - Or clear the field entirely if standalone

**Issues to Fix:** 1  
**Estimated Time:** 5-10 minutes per issue  
**Priority:** 🟡 **HIGH** - Complete within first week

---

### Days 2-5: Verify Failed Issues (if applicable)

**📄 Open:** `08_FailedIssues.csv`

**What happened?**
37 issues could not be created due to validation errors or field incompatibilities.

**How to fix:**
1. Open the CSV to see which issues failed
2. Review the "Error" column for each issue
3. Options:
   - Work with migration team to resolve technical issues
   - Manually create critical issues
   - Document as known limitation if non-critical

**Estimated Time:** 30-60 minutes  
**Priority:** 🟡 **HIGH**

---

## 🔍 Week 1-2: Validation & Testing

### Verify Core Functionality

**1. Browse Issues** ✅
- Go to: https://onemainfinancial-migrationsandbox.atlassian.net/browse/QUAL1
- Verify issues appear correctly
- Check that filters work
- Spot-check a few issues for completeness

**2. Test Workflows** ✅
- Create a test issue
- Move through your workflow states
- Verify transitions work as expected
- Delete test issue when done

**3. Check Boards** ✅
- Open your team's board
- Verify columns match your workflow
- Check that sprint data appears (if applicable)
- Configure swimlanes if needed

**4. Review Components & Versions** ✅
- Project Settings → Components
- Verify components migrated
- Check fix versions/releases

**5. Test Permissions** ✅
- Have team members try to:
  - Create issues
  - Assign issues
  - Comment on issues
  - Move issues through workflow

---

## 📊 Understanding Your Migration

### What Was Migrated?

✅ **Issues:** 637 created, 15 already existed  
✅ **Users:** 14 synced to project  
✅ **Components:** 176  
✅ **Versions:** 15  
✅ **Custom Fields:** 53 mapped  
✅ **Historical Data:** Original created/updated dates preserved  

### What Changed?

**Status Mappings:**
- Old statuses mapped to new workflow
- Some multi-hop transitions applied
- Check `MIGRATION_SUMMARY.md` for details

**Custom Fields:**
- 0 fields converted to plain text (from rich text)
- Check descriptions for fields that couldn't be mapped

**Parent Links:**
- 1 issues missing parents (see CSV)
- 117 cross-project parent links

---

## 🚨 Common Issues & Solutions

### Issue: "I can't assign issues to team members"
**Solution:** Grant "Assignable User" permission  
**Link:** https://onemainfinancial-migrationsandbox.atlassian.net/plugins/servlet/project-config/QUAL1/permissions

### Issue: "Some issues are in wrong status"
**Solution:** Multi-hop transitions may have stopped early  
**Action:** Manually move issues to correct status

### Issue: "Custom field data missing"
**Solution:** Check issue description - data may be appended  
**Reference:** `08_CustomFieldConversions_Report.json`

### Issue: "User not in target project"
**Solution:** Check `03_UsersAndRoles_Report.csv` for sync status  
**Action:** Contact admin to add user manually

### Issue: "Board doesn't show all issues"
**Solution:** Board filter may need adjustment  
**Action:** Edit board → Configure → Filter

---

## 📞 Need Help?

### For Technical Issues
1. Check `MIGRATION_DETAILED_REPORT.md` for technical details
2. Review `migration_progress.html` for step-by-step results
3. Contact migration team with specific questions

### For Data Issues
1. Document the issue (issue key, expected vs actual)
2. Create a ticket tagged with `migration-issue`
3. Include screenshots if helpful

### For Training
1. Share `QUICK_START_GUIDE.md` with team
2. Walk through workflow changes in team meeting
3. Update team documentation

---

## 📋 Quick Reference Links

| Resource | Link |
|----------|------|
| **Target Project** | https://onemainfinancial-migrationsandbox.atlassian.net/browse/QUAL1 |
| **Source Project** (reference) | https://onemain-migrationsandbox.atlassian.net/browse/QUAL |
| **Project Settings** | https://onemainfinancial-migrationsandbox.atlassian.net/plugins/servlet/project-config/QUAL1/summary |
| **User Permissions** | https://onemainfinancial-migrationsandbox.atlassian.net/plugins/servlet/project-config/QUAL1/permissions |
| **Project Boards** | https://onemainfinancial-migrationsandbox.atlassian.net/jira/software/projects/QUAL1/boards |

---

## ✅ Success Criteria

Your migration is complete when:

- [ ] All team members have appropriate access
- [ ] "Assignable User" permissions granted
- [ ] Orphaned issues are linked or marked standalone
- [ ] Failed issues resolved (if any)
- [ ] Core workflows tested and functioning
- [ ] Team is trained and comfortable with target project
- [ ] No critical data gaps identified

---

## 📅 Timeline Summary

| Phase | Duration | Priority |
|-------|----------|----------|
| **User Access Setup** | Day 1 (30 min) | 🔴 Critical |
| **Fix Orphaned Issues** | Days 1-3 (1-2 hrs) | 🟡 High |
| **Core Validation** | Days 2-5 (2-3 hrs) | 🟡 High |
| **Team Testing** | Week 2 | 🟢 Medium |
| **Full Production Use** | Week 3+ | 🟢 Ongoing |

---

**Questions?** Contact the migration team  
**Documentation:** See companion files in migration output folder

---

**Generated:** 2025-10-13 18:33  
**Migration Toolkit Version:** 2.0


