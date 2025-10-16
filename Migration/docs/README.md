# Migration Toolkit Documentation

**Complete guides for enterprise-grade Jira project migration**

> 🎯 **New to this toolkit?** Start with [Workflow.md](Workflow.md) for the complete migration guide.  
> 📊 **Want an overview?** Read [TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md) for features and capabilities.

---

## 📚 Documentation Index

### 🎯 Core Guides (Start Here)

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[Workflow.md](Workflow.md)** | Complete migration workflow | **START HERE** - Main guide |
| **[TOOLKIT_SUMMARY.md](TOOLKIT_SUMMARY.md)** | Toolkit overview & capabilities | For quick overview |
| **[MULTI_PROJECT_GUIDE.md](MULTI_PROJECT_GUIDE.md)** | Multi-project structure & launcher | **Essential** - New structure |
| [Parameters.md](Parameters.md) | Configuration parameters reference | Before setup |
| [QESB1_Configuration_Guide.md](QESB1_Configuration_Guide.md) | Project-specific configuration | During setup |

---

### 🛠️ Feature Guides

| Document | Purpose | When to Read |
|----------|---------|--------------|
| **[IDEMPOTENCY_COMPLETE.md](IDEMPOTENCY_COMPLETE.md)** | Idempotent scripts guide | Essential - explains safe re-runs |
| [LEGACY_KEY_PRESERVATION.md](LEGACY_KEY_PRESERVATION.md) | Legacy key tracking | Before Step 08 |
| [HANDLING_LINKS_GUIDE.md](HANDLING_LINKS_GUIDE.md) | Issue & remote link handling | Before Step 11 |
| [QA_VALIDATION_SYSTEM_GUIDE.md](QA_VALIDATION_SYSTEM_GUIDE.md) | Comprehensive QA system | Before Step 16 |

---

### 🔍 Status & Troubleshooting

| Document | Purpose | When to Read |
|----------|---------|--------------|
| [VALIDATION_REPORT.md](VALIDATION_REPORT.md) | Script validation status | Reference - current toolkit status |
| [DUPLICATE_ISSUES_ANALYSIS.md](DUPLICATE_ISSUES_ANALYSIS.md) | Duplicate issues troubleshooting | If duplicates detected |

---

## 🚀 Quick Start

### 1. **Read the Main Workflow**
Start with [Workflow.md](Workflow.md) - it covers everything from setup to completion.

### 2. **Understand the Structure**
Read [MULTI_PROJECT_GUIDE.md](MULTI_PROJECT_GUIDE.md) - learn about the project-based organization.

### 3. **Understand Key Features**
Read these before running migrations:
- **Multi-Project Support** - Run multiple migrations side-by-side
- **Idempotency** - All scripts are safe to re-run
- **Legacy Keys** - Source keys preserved in custom fields
- **QA Validation** - Comprehensive quality checks

### 4. **Run Migration**
```powershell
# Validate first
.\RunMigration.ps1 -Project LAS -DryRun

# Start migration
.\RunMigration.ps1 -Project LAS
```

Follow the workflow, using feature guides as needed for specific steps.

---

## 📖 Reading Order

### For First-Time Users:
1. [Workflow.md](Workflow.md) - Main guide
2. [Parameters.md](Parameters.md) - Configuration
3. [IDEMPOTENCY_COMPLETE.md](IDEMPOTENCY_COMPLETE.md) - Understand safe re-runs
4. [QA_VALIDATION_SYSTEM_GUIDE.md](QA_VALIDATION_SYSTEM_GUIDE.md) - QA system

### For Experienced Users:
- Use as reference documentation
- Jump directly to relevant feature guides
- Consult troubleshooting docs as needed

---

## 🎯 Document Purposes

### Workflow.md (PRIMARY GUIDE)
**Complete end-to-end migration process**
- Setup instructions
- Step-by-step workflow
- Configuration details
- Best practices
- Troubleshooting

### IDEMPOTENCY_COMPLETE.md (ESSENTIAL)
**Understanding idempotent scripts**
- What is idempotency
- How each script prevents duplicates
- Safe re-run capabilities
- Matching strategies
- Benefits and usage

### LEGACY_KEY_PRESERVATION.md
**Source key tracking in target**
- Custom field configuration
- Search by legacy key (JQL)
- Traceability features
- Use cases and examples

### HANDLING_LINKS_GUIDE.md
**Issue and remote link migration**
- Issue link types
- Remote links (Confluence, GitHub, etc.)
- Skipped links handling
- Cross-project strategies

### QA_VALIDATION_SYSTEM_GUIDE.md
**Comprehensive all-in-one QA system**
- Single consolidated script
- Multi-part validation (issues, related items, consistency)
- Interactive HTML dashboard
- Deep validation checks
- How to interpret results

### VALIDATION_REPORT.md
**Current toolkit status**
- Scripts validated
- Syntax checks passed
- Features confirmed
- Production readiness

### DUPLICATE_ISSUES_ANALYSIS.md
**Troubleshooting duplicates**
- Root cause analysis
- Cleanup procedure
- Prevention strategies
- Utility script usage

---

## 🛠️ Documentation Maintenance

### This folder contains:
- **11 essential documents** (streamlined from 16)
- **No redundant content** (merged/removed overlapping docs)
- **Up-to-date information** (reflects current toolkit with multi-project support)
- **Production-ready** (validated and accurate)

### Cleaned up (7 files removed):
- Planning documents (superseded by implementation guides)
- Implementation summaries (merged into feature guides)
- Session notes (historical, no longer needed)
- Backup files (no longer needed)
- Duplicate content (consolidated)

---

## 📞 Support

### If you need help:
1. Check [Workflow.md](Workflow.md) first
2. Consult relevant feature guide
3. Review troubleshooting sections
4. Check validation reports

### Common Questions:
- **"Can I re-run a script?"** → See [IDEMPOTENCY_COMPLETE.md](IDEMPOTENCY_COMPLETE.md)
- **"How do I find source issues?"** → See [LEGACY_KEY_PRESERVATION.md](LEGACY_KEY_PRESERVATION.md)
- **"What about cross-project links?"** → See [HANDLING_LINKS_GUIDE.md](HANDLING_LINKS_GUIDE.md)
- **"How do I validate migration?"** → See [QA_VALIDATION_SYSTEM_GUIDE.md](QA_VALIDATION_SYSTEM_GUIDE.md)
- **"I have duplicates!"** → See [DUPLICATE_ISSUES_ANALYSIS.md](DUPLICATE_ISSUES_ANALYSIS.md)

---

## ✅ Documentation Complete

**Your migration toolkit documentation is now:**
- ✅ Streamlined (9 essential docs)
- ✅ Organized (clear categories)
- ✅ Comprehensive (covers all features)
- ✅ Production-ready (validated content)

**Everything you need, nothing you don't!** 🎯

