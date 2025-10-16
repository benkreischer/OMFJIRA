# 🚀 OneMain Financial - Jira Analytics & Reporting Suite

A comprehensive collection of tools for extracting, analyzing, and reporting on Jira data using PowerShell, Power Query, and PowerBI.

## 📁 **PROJECT ORGANIZATION & STRUCTURE**

### **✅ Root Directory (Clean & Organized)**

```
Z:\Code\OMF\
├── .backups/          # Backup files
├── .claude/           # Claude AI settings
├── .csv/              # CSV data files
├── .database/         # Database files
├── .docs/             # 📚 Documentation files (44 files)
├── .excel/            # 📊 Excel files (1 file)
├── .images/           # 🖼️ Image files (1 file)
├── .json-files/       # 📄 JSON files (1 file)
├── .powerbi/          # 📈 PowerBI files (1 file)
├── .ps1/              # PowerShell scripts
├── .scripts/          # Power Query scripts
├── .trash/            # Trash/deleted files
├── .vba/              # VBA scripts
├── endpoints/         # 🎯 Main endpoint directory (77+ categories)
├── .gitignore         # Git ignore file
├── acli.exe           # CLI executable (kept in root)
├── env.template       # Environment template
├── PHASE4_OAUTH2_PLAN.md  # 🚀 Active project plan (kept in root)
└── README.md          # 📖 Master documentation (this file)
```

### **📊 File Organization Summary**

#### **📚 Documentation (.docs/) - 44 files**

- **Project Documentation**: All setup guides, implementation docs, completion summaries
- **Phase Summaries**: PHASE1, PHASE2, PHASE3, PHASE4A completion summaries
- **Setup Guides**: Excel, PowerBI, GitHub setup documentation
- **Analysis Reports**: Comprehensive endpoint analysis, authentication analysis
- **User Guides**: OMF user guide, implementation guides

#### **📈 PowerBI (.powerbi/) - 1 file**

- `powerbi-jira-dax-measures.pbix` - PowerBI dashboard with DAX measures

#### **📊 Excel (.excel/) - 1 file**

- `excel-master-analytics.xlsx` - Master analytics Excel workbook

#### **🖼️ Images (.images/) - 1 file**

- `onemain-vertical.svg` - OneMain Financial logo

#### **📄 JSON (.json-files/) - 1 file**

- `fields_onemainfinancial.json` - Field configuration data

#### **🎯 Endpoints (endpoints/) - 77+ categories**

- **Main endpoint directory** with all Power Query (.pq) files
- **Organized by category** with proper naming conventions
- **Live API calls** with OneMain Financial authentication
- **OAuth2 Framework** for advanced authentication

## 🚀 **PROJECT STATUS & PHASE COMPLETION**

### **✅ COMPLETED PHASES**

| Phase | Status | Categories | Endpoints | Description |
|-------|--------|------------|-----------|-------------|
| **Phase 1** | ✅ **100% COMPLETE** | 10 | 53 | Critical Anonymous Endpoints |
| **Phase 2** | ✅ **100% COMPLETE** | 7 | 30 | Important Anonymous Endpoints |
| **Phase 3** | ✅ **100% COMPLETE** | 10 | 37 | Additional Anonymous Endpoints |
| **Phase 4A** | ✅ **100% COMPLETE** | 1 | 3 | OAuth2 Framework Setup |
| **Existing** | ✅ **COMPLETE** | 50 | ~220 | Previously created endpoints |

### **🔄 CURRENT PHASE**

| Phase | Status | Categories | Endpoints | Description |
|-------|--------|------------|-----------|-------------|
| **Phase 4B** | 🚀 **IN PROGRESS** | 6-7 | 30-40 | OAuth2 Endpoint Categories |

### **📊 OVERALL PROGRESS**

- **Total Categories**: 78/110+ (71% complete)
- **Total Endpoints**: ~343/400-600 (69%+ complete)
- **Authentication Coverage**:
  - **Basic Authentication**: 93% (can create with basic auth) ✅
  - **OAuth2 Authentication**: 7% (framework complete, ready for expansion) ✅

### **🎯 ROOT DIRECTORY BENEFITS**

#### **✅ Clean & Focused**

- **Only essential files** in root directory
- **Active project files** easily accessible
- **Clear separation** of concerns

#### **✅ Easy Navigation**

- **Logical folder structure** for different file types
- **Quick access** to documentation, scripts, and endpoints
- **Professional organization** for team collaboration

#### **✅ Maintainable**

- **Scalable structure** for future additions
- **Clear file locations** for different purposes
- **Reduced clutter** in main directory

## 🚀 Quick Start

### Prerequisites

- PowerShell 5.1+ or PowerShell Core 6+
- Excel with Power Query (Excel 2016+)
- Jira Cloud account with API access
- (Optional) PowerBI Desktop for advanced analytics

### Setup

1. **Clone this repository**

   ```bash
   git clone https://github.com/your-org/jira-analytics.git
   cd jira-analytics
   ```

2. **Set up your environment variables**

   ```bash
   # Copy the template
   cp env.template .env
   
   # Edit .env with your Jira credentials
   # NEVER commit the .env file!
   ```

3. **Configure PowerShell environment (Windows)**

   ```powershell
   # Run the setup script
   .\scripts\setup-jira-env.ps1
   ```

4. **Test your connection**

   ```powershell
   .\scripts\test-jira-env.ps1
   ```

## 📁 **DETAILED PROJECT STRUCTURE**

### **🎯 Main Endpoint Categories (endpoints/)**

#### **Phase 1: Critical Anonymous Endpoints (10 categories, 53 endpoints)**

- **Issues** (8 endpoints) - Issue management and retrieval
- **Issue Worklogs** (6 endpoints) - Worklog tracking and management
- **Issue Votes** (3 endpoints) - Voting functionality
- **Issue Watchers** (4 endpoints) - Watcher management
- **Users** (6 endpoints) - User information and management
- **Project Versions** (6 endpoints) - Version management
- **Project Components** (6 endpoints) - Component management
- **Workflows** (6 endpoints) - Workflow operations
- **Permission Schemes** (6 endpoints) - Permission management
- **Time Tracking** (4 endpoints) - Time tracking functionality

#### **Phase 2: Important Anonymous Endpoints (7 categories, 30 endpoints)**

- **Application Roles** (6 endpoints) - Application role management
- **Issue Bulk Operations** (5 endpoints) - Bulk issue operations
- **Project Roles** (6 endpoints) - Project role management
- **License Metrics** (4 endpoints) - License usage and metrics
- **Server Info** (2 endpoints) - Server information and health
- **Status** (4 endpoints) - Status management
- **User Search** (3 endpoints) - User search functionality

#### **Phase 3: Additional Anonymous Endpoints (10 categories, 37 endpoints)**

- **Project Permission Schemes** (4 endpoints) - Project permission schemes
- **Issue Custom Field Associations** (4 endpoints) - Custom field associations
- **Issue Custom Field Configuration (Apps)** (5 endpoints) - Custom field configuration
- **Issue Security Level** (3 endpoints) - Security level management
- **Plans** (5 endpoints) - Plan management
- **Issue Custom Field Values (Apps)** (4 endpoints) - Custom field values
- **Issue Redaction** (3 endpoints) - Issue redaction
- **Issue Type Properties** (3 endpoints) - Issue type properties
- **Issue Worklog Properties** (3 endpoints) - Worklog properties
- **JQL Functions (Apps)** (3 endpoints) - JQL function management

#### **Phase 4A: OAuth2 Framework (1 category, 3 endpoints)**

- **OAuth2 Framework** (4 components) - Complete OAuth2 authentication framework
- **Advanced Analytics (OAuth2)** (3 endpoints) - Advanced analytics with OAuth2

#### **Existing Categories (50 categories, ~220 endpoints)**

- **Connected Apps** - Integration analytics
- **Admin Organization** - Administrative functions
- **Service Management** - JSM functionality
- **Advanced Agile** - Agile analytics
- **Integration ROI** - ROI analysis
- **And 45+ additional categories...**

### **📚 Supporting Infrastructure**

```
Z:\Code\OMF\
├── .docs/                   # 📚 All documentation (44 files)
├── .excel/                  # 📊 Excel workbooks and templates
├── .powerbi/                # 📈 PowerBI dashboards and measures
├── .images/                 # 🖼️ Images and logos
├── .json-files/             # 📄 JSON configuration files
├── .csv/                    # 📊 CSV data files
├── .ps1/                    # 🔧 PowerShell scripts
├── .vba/                    # 🔧 VBA code modules
├── .scripts/                # 🔧 Power Query scripts
├── .backups/                # 💾 Backup files
└── .claude/                 # 🤖 Claude AI settings
```

## 🔧 Usage

### PowerShell Scripts

**Basic API call:**

```powershell
.\scripts\jira-api-env.ps1 -Endpoint "workflow" -Method GET
```

**Search issues:**

```powershell
.\scripts\jira-api-env.ps1 -Endpoint "search" -Method GET -Query "project=PROJ AND status=Open"
```

### Power Query

1. Open Excel
2. Go to Data → Get Data → From Other Sources → Blank Query
3. Copy and paste the Power Query code from `powerquery/` files
4. Modify the configuration section with your parameters
5. Load the data

### Dynamic Excel Integration

1. Set up named ranges in Excel:
   - `JiraBaseUrl`
   - `JiraUsername`
   - `JiraApiToken`
   - `JiraProjectKey`
   - `JiraStatus`
   - `JiraJQL`

2. Use the dynamic Power Query from `powerquery/dynamic-jira-queries.pq`

3. Use VBA functions from `excel/vba/` for automation

## 🔐 Security

### Environment Variables

- **Never commit `.env` files** to version control
- Use the provided `env.template` as a starting point
- Rotate API tokens regularly
- Use least-privilege access for API tokens

### API Token Management

- Create API tokens in Jira: Account Settings → Security → API tokens
- Use different tokens for different environments
- Consider using Jira OAuth for better security

### Team Collaboration

- Share the repository, not individual files with embedded credentials
- Each team member sets up their own `.env` file
- Use branch protection rules for main branch
- Require pull request reviews for changes

## 📊 Available Queries

### Basic Information

- Server information
- User information
- Project listings

### Issue Management

- Search issues with JQL
- Issues by status, assignee, priority
- Overdue issues
- Recent issues

### Reporting & Analytics

- Issues by project
- Status summaries
- Assignee reports
- Priority analysis

### Advanced Features

- Dynamic queries with Excel integration
- Date field conversion and calculations
- Time intelligence measures
- Custom JQL support

## 🛠️ Customization

### Adding New Queries

1. Create a new `.pq` file in `powerquery/`
2. Follow the existing pattern for date conversion
3. Document the query purpose and parameters
4. Test with your Jira instance

### Modifying Existing Queries

1. Edit the relevant `.pq` file
2. Update the configuration section
3. Test the changes
4. Update documentation if needed

## 📈 PowerBI Integration

### Using the Appfire Connector

1. Install the Appfire PowerBI connector
2. Use the provided dashboard templates
3. Import the DAX measures
4. Customize for your needs

### Custom Measures

- Time intelligence (MTD, QTD, YTD)
- Resolution time analysis
- Overdue issue tracking
- Team performance metrics

## 🤝 Contributing

### For Team Members

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

### Code Standards

- Follow existing naming conventions
- Add comments for complex logic
- Test all changes before submitting
- Update documentation as needed

## 🐛 Troubleshooting

### Common Issues

**"Client must be authenticated"**

- Check your API token
- Verify username format (email address)
- Ensure token has proper permissions

**"Date fields showing as text"**

- Use the provided date conversion functions
- Check Power Query data types
- Verify DateTime.FromText() is working

**"Power Query refresh errors"**

- Check network connectivity
- Verify API endpoint URLs
- Review error messages in Power Query editor

### Getting Help

1. Check the troubleshooting section in relevant documentation
2. Review error messages carefully
3. Test with simple queries first
4. Ask team members for assistance

## 📝 License

This project is for internal use only. Do not distribute outside your organization.

## 🔄 Updates

### Version History

- v1.0 - Initial release with basic queries
- v1.1 - Added date conversion and time intelligence
- v1.2 - Added PowerBI integration and dynamic queries

### Planned Features

- OAuth authentication support
- Advanced filtering options
- Automated report scheduling
- Team collaboration features

---

**Need help?** Check the documentation in the `docs/` folder or ask your team lead.
