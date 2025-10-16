# QA Validation Checklist

**Project:** EO - Quality Assurance Sandbox  
**Target Project:** QUAL1  
**Migration Date:** 2025-10-13 18:33  
**QA Reviewer:** ___________________  
**QA Date:** ___________________

---

## 📋 Purpose

This checklist ensures all critical aspects of the migration have been validated and are functioning correctly in the target environment.

---

## ✅ 1. User Access & Permissions

### User Synchronization
- [ ] All expected users appear in target project
- [ ] User roles correctly assigned
- [ ] Failed user additions documented and resolved
- [ ] External/guest users handled appropriately

**Validation Method:**
- Open: https://onemainfinancial-migrationsandbox.atlassian.net/plugins/servlet/project-config/QUAL1/summary
- Compare with `03_UsersAndRoles_Report.csv`

**Issues Found:**
```
(Document any issues here)
```

---

### Permission Verification
- [ ] "Assignable User" permission granted to appropriate roles
- [ ] Users can create issues
- [ ] Users can edit issues they're assigned to
- [ ] Users can comment on issues
- [ ] Users can transition issues through workflow
- [ ] Admin users have project admin permissions

**Test Method:**
1. Have 3-5 team members each:
   - Create a test issue
   - Assign it to themselves
   - Add a comment
   - Move through 2-3 workflow states
   - Delete test issue

**Permission Issues:**
```
(Document any permission problems)
```

---

## ✅ 2. Issue Data Integrity

### Issue Counts
- [ ] Total issues match expectation: Expected 829, Got 637
- [ ] All critical issues migrated
- [ ] Failed issues reviewed and documented

**Actual Counts:**
- Created: 637
- Skipped (existing): 15
- Failed: 37
- **Total:** 689

**Variance Acceptable:** Yes ☐ No ☐  
**If No, explain:**
```

```

---

### Issue Fields
Random sample check (test 10-15 issues):

- [ ] Summary field correct
- [ ] Description preserved (including formatting)
- [ ] Issue type correct
- [ ] Priority preserved
- [ ] Status mapped correctly
- [ ] Reporter correct (or marked as API user)
- [ ] Assignee correct (or unassigned with note)
- [ ] Components correct
- [ ] Fix Version/Release correct
- [ ] Labels preserved
- [ ] Custom fields preserved or noted in description

**Sample Issues Tested:**
```
Issue Key | Summary Check | Fields Check | Links Check | Overall
----------|---------------|--------------|-------------|--------
          | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ PASS ☐ FAIL
          | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ PASS ☐ FAIL
          | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ PASS ☐ FAIL
          | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ PASS ☐ FAIL
          | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ OK ☐ Issues | ☐ PASS ☐ FAIL
```

**Field Issues Found:**
```

```

---

### Historical Data Preservation
- [ ] Original created dates preserved in custom field
- [ ] Original updated dates preserved in custom field
- [ ] Original creator noted in description
- [ ] Legacy key stored in custom field
- [ ] Legacy key URL stored in custom field

**Test Method:**
- Open 3-5 random issues
- Check "Original Created Date" field
- Check "Original Updated Date" field
- Check "Legacy Key" field
- Verify description includes "Original Creator"

**Historical Data Issues:**
```

```

---

## ✅ 3. Relationships & Links

### Parent-Child Relationships
- [ ] Parent-child links preserved for migrated parents
- [ ] Orphaned issues identified: 1 issues
- [ ] Orphaned issues action plan documented
- [ ] Sub-tasks properly linked
- [ ] Epic relationships preserved

**Test Method:**
- Open a few Epics → verify Stories linked
- Open a few Stories → verify Sub-tasks linked
- Check `08_OrphanedIssues.csv` for missing parents

**Relationship Issues:**
```

```

---

### Cross-Project Links
- [ ] Cross-project parent links identified: 117
- [ ] Remote links created (if applicable)
- [ ] External links documented

**Cross-Project Links:**
```
(List any that need manual attention)
```

---

### Issue Links
- [ ] "Relates to" links preserved
- [ ] "Blocks/Blocked by" links preserved
- [ ] "Duplicates" links preserved
- [ ] "Clones" links preserved

**Test Method:**
- Find issues with links in source
- Verify same links exist in target
- Test 5-10 linked issues

**Link Issues:**
```

```

---

## ✅ 4. Workflows & Status

### Status Mapping
- [ ] All source statuses mapped to target statuses
- [ ] Status transitions work correctly
- [ ] No issues stuck in incorrect status
- [ ] Multi-hop transitions successful

**Status Mapping Verification:**
```
Source Status → Target Status | Verified | Issues
--------------|----------|-------
              | ☐        |
              | ☐        |
              | ☐        |
```

**Test Method:**
1. Create test issue
2. Try to move through all workflow states
3. Verify all expected transitions available
4. Check that guards/validators work

**Workflow Issues:**
```

```

---

### Workflow Functionality
- [ ] Can create issues in all issue types
- [ ] Can transition issues through full lifecycle
- [ ] Workflow validators function
- [ ] Workflow post-functions execute
- [ ] Required fields enforced
- [ ] Resolution field behavior correct

**Tested Issue Types:**
```
Issue Type | Create | Transition | Resolution | Overall
-----------|--------|------------|------------|--------
Story      | ☐      | ☐          | ☐          | ☐ PASS ☐ FAIL
Task       | ☐      | ☐          | ☐          | ☐ PASS ☐ FAIL
Bug        | ☐      | ☐          | ☐          | ☐ PASS ☐ FAIL
Epic       | ☐      | ☐          | ☐          | ☐ PASS ☐ FAIL
Sub-task   | ☐      | ☐          | ☐          | ☐ PASS ☐ FAIL
```

---

## ✅ 5. Boards & Filters

### Board Configuration
- [ ] All boards migrated/configured
- [ ] Board columns match workflow
- [ ] Board filters include migrated issues
- [ ] Swimlanes configured (if used)
- [ ] Quick filters work
- [ ] Card layout shows correct fields

**Boards to Verify:**
```
Board Name | Columns OK | Filter OK | Issues Display | Overall
-----------|------------|-----------|----------------|--------
           | ☐          | ☐         | ☐              | ☐ PASS ☐ FAIL
           | ☐          | ☐         | ☐              | ☐ PASS ☐ FAIL
```

**Test Method:**
- Open each board
- Verify issues appear
- Try filtering/searching
- Drag issue to different column

**Board Issues:**
```

```

---

### Filters & JQL
- [ ] Saved filters work
- [ ] JQL searches return expected results
- [ ] Issue navigator displays correctly
- [ ] Export functions work

**Critical Filters to Test:**
```
Filter Name | Works | Returns Expected | Overall
------------|-------|------------------|--------
            | ☐     | ☐                | ☐ PASS ☐ FAIL
            | ☐     | ☐                | ☐ PASS ☐ FAIL
```

---

## ✅ 6. Components & Versions

### Components
- [ ] All components migrated: 176
- [ ] Component leads assigned
- [ ] Component descriptions preserved
- [ ] Issues correctly tagged with components

**Test Method:**
- Project Settings → Components
- Verify list matches source
- Check a few issues have correct components

**Component Issues:**
```

```

---

### Versions/Releases
- [ ] All versions migrated: 15
- [ ] Version dates preserved
- [ ] Released/archived status correct
- [ ] Issues correctly tagged with fix versions

**Test Method:**
- Project Settings → Releases
- Compare with source project
- Verify dates and statuses

**Version Issues:**
```

```

---

## ✅ 7. Custom Fields

### Custom Field Mapping
- [ ] Critical custom fields mapped: 53
- [ ] Custom field values preserved
- [ ] Field conversions documented: 0
- [ ] Unmapped fields noted in descriptions

**Critical Custom Fields:**
```
Field Name | Migrated | Values Correct | Issues
-----------|----------|----------------|-------
           | ☐        | ☐              |
           | ☐        | ☐              |
           | ☐        | ☐              |
```

**Test Method:**
- Review `08_CustomFieldConversions_Report.json`
- Check 10-15 issues with custom field data
- Verify values or check descriptions

**Custom Field Issues:**
```

```

---

## ✅ 8. Sprints & Agile Features (if applicable)

### Sprint Data
- [ ] Active sprints migrated
- [ ] Sprint dates preserved
- [ ] Issues correctly assigned to sprints
- [ ] Sprint reports accessible
- [ ] Backlog organized correctly

**Active Sprints:**
```
Sprint Name | Issues Count | Dates OK | Overall
------------|--------------|----------|--------
            | ☐            | ☐        | ☐ PASS ☐ FAIL
            | ☐            | ☐        | ☐ PASS ☐ FAIL
```

**Sprint Issues:**
```

```

---

## ✅ 9. Search & Performance

### Search Functionality
- [ ] Text search works
- [ ] Quick search finds issues
- [ ] Advanced search (JQL) works
- [ ] Search results accurate
- [ ] Search performance acceptable

**Test Searches:**
```
Search Term | Results Found | Speed | Overall
------------|---------------|-------|--------
            | ☐ Correct     | ☐ Fast | ☐ PASS ☐ FAIL
            | ☐ Correct     | ☐ Fast | ☐ PASS ☐ FAIL
```

---

### System Performance
- [ ] Issue loading speed acceptable
- [ ] Board loading speed acceptable
- [ ] Search response time acceptable
- [ ] No timeout errors
- [ ] Bulk operations work

**Performance Notes:**
```

```

---

## ✅ 10. Notifications & Integrations

### Notifications
- [ ] Notification schemes applied
- [ ] Users receive expected notifications
- [ ] Email notifications working
- [ ] @mentions work
- [ ] Watchers preserved (if applicable)

**Test Method:**
- Create issue and assign to someone
- Add comment with @mention
- Verify notifications sent

**Notification Issues:**
```

```

---

### Integrations
- [ ] Confluence links work (if applicable)
- [ ] External integrations documented
- [ ] Webhooks configured (if needed)
- [ ] API access working

**Integrations to Verify:**
```
Integration | Status | Issues
------------|--------|-------
            | ☐ OK   |
            | ☐ OK   |
```

---

## 📊 Overall Assessment

### Summary Statistics
- **Total Checks:** _____ / _____
- **Passed:** _____
- **Failed:** _____
- **Not Applicable:** _____

### Critical Issues Found
```
Priority | Issue Description | Impact | Action Required | Owner
---------|-------------------|--------|-----------------|------
🔴 HIGH  |                   |        |                 |
🟡 MED   |                   |        |                 |
🟢 LOW   |                   |        |                 |
```

---

## ✅ Sign-Off

### QA Approval
- [ ] All critical issues resolved
- [ ] All medium issues documented with action plan
- [ ] Migration meets acceptance criteria
- [ ] Project ready for team use

**QA Reviewer:** ___________________  
**Date:** ___________________  
**Signature:** ___________________

### Project Lead Approval
- [ ] QA results reviewed
- [ ] Outstanding issues acceptable
- [ ] Team ready to use target project
- [ ] Migration approved

**Project Lead:** ___________________  
**Date:** ___________________  
**Signature:** ___________________

---

## 📞 Support & Follow-Up

**Outstanding Issues:** _____  
**Follow-up Meeting Scheduled:** ___________________  
**Next Review Date:** ___________________

**Additional Notes:**
```




```

---

**Generated:** 2025-10-13 18:33  
**Migration Toolkit Version:** 2.0


