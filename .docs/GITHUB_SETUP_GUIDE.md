# GitHub Setup Guide for Jira Analytics Team

## 🚀 **Secure Team Collaboration Setup**

This guide will help you set up a secure GitHub repository for your Jira analytics project that your team can safely collaborate on.

## 📋 **Pre-Setup Checklist**

- [ ] GitHub account (personal or organization)
- [ ] Team members have GitHub accounts
- [ ] Jira API tokens for each team member
- [ ] Basic understanding of Git/GitHub

## 🔧 **Step 1: Create GitHub Repository**

### **Option A: Create New Repository**

1. Go to [GitHub.com](https://github.com)
2. Click "New repository" or "+" → "New repository"
3. Repository name: `jira-analytics` (or your preferred name)
4. Description: "Jira Analytics & Reporting Suite for [Your Team/Company]"
5. **Visibility**: Choose based on your needs:
   - **Private**: Only your team can see (recommended)
   - **Public**: Anyone can see (not recommended for internal tools)
6. **Initialize with README**: ✅ Check this
7. **Add .gitignore**: Choose "PowerShell" or "Custom"
8. **Add license**: Choose appropriate license for your organization
9. Click "Create repository"

### **Option B: Import Existing Project**

1. Click "Import a repository"
2. Enter your local project path
3. Follow the same settings as Option A

## 🔐 **Step 2: Secure Your Repository**

### **2.1 Create .gitignore File**

Create a `.gitignore` file in your repository root:

```text
# Add this to your .gitignore file
# Environment variables
.env
.env.local
.env.production
.env.staging

# API tokens and credentials
*-credentials.json
*-token.json
*-secret.json

# PowerShell scripts with embedded tokens
*-embedded.ps1
*-with-tokens.ps1

# Excel files with embedded data
*-with-data.xlsx
*-temp.xlsx

# Log files
*.log
logs/

# Temporary files
*.tmp
*.temp
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.swp
*.swo

# Node modules (if using any Node.js tools)
node_modules/

# Python cache (if using Python scripts)
__pycache__/
*.pyc
*.pyo

# Backup files
*.bak
*.backup
*~
```

### **2.2 Create Environment Template**

Create an `env.template` file:

```text
# Jira API Configuration Template
# Copy this file to .env and fill in your actual values
# DO NOT commit .env to version control

# Your Jira instance URL
JIRA_BASE_URL=https://yourcompany.atlassian.net

# Your Jira username (email address)
JIRA_USERNAME=your.email@company.com

# Your Jira API token (generate from Atlassian Account Settings)
JIRA_API_TOKEN=your_api_token_here

# Optional: Default project key for queries
DEFAULT_PROJECT_KEY=PROJ

# Optional: Default JQL for searches
DEFAULT_JQL=ORDER BY created DESC
```

### **2.3 Update Power Query Files**

Replace embedded tokens with environment variables:

```m
// OLD (insecure):
BaseUrl = "https://yourcompany.atlassian.net",
Username = "your.email@company.com",
ApiToken = "ATATT3xFfGF0AGv6XB75mRakWAjWsnj0N-O0EgeKHK2A63GPo3ZFnHWQa6wcYhN6GMhPvctv27J9Ivhj0d3r5ICPu0pZ9KQfRHjI19AWY1MKvTryvzIYcYgjUHgk=641B9570",
```

```m
// NEW (secure):
BaseUrl = Excel.CurrentWorkbook(){[Name="JiraBaseUrl"]}[Content]{0}[Column1],
Username = Excel.CurrentWorkbook(){[Name="JiraUsername"]}[Content]{0}[Column1],
ApiToken = Excel.CurrentWorkbook(){[Name="JiraApiToken"]}[Content]{0}[Column1],
```

## 👥 **Step 3: Add Team Members**

### **3.1 Invite Collaborators**

1. Go to your repository on GitHub
2. Click "Settings" → "Manage access"
3. Click "Invite a collaborator"
4. Enter team member's GitHub username or email
5. Choose permission level:
   - **Read**: Can view and clone
   - **Write**: Can push to repository
   - **Admin**: Full access (use sparingly)
6. Click "Add [username] to this repository"

### **3.2 Set Up Branch Protection**

1. Go to Settings → Branches
2. Click "Add rule"
3. **Branch name pattern**: `main` (or `master`)
4. **Protect matching branches**:
   - ✅ Require a pull request before merging
   - ✅ Require approvals (set to 1 or 2)
   - ✅ Dismiss stale PR approvals when new commits are pushed
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
5. Click "Create"

## 📚 **Step 4: Create Documentation**

### **4.1 Create README.md**

Create a comprehensive README.md file:

```markdown
# Jira Analytics Suite

A comprehensive analytics and reporting suite for Jira, built with Power Query and PowerBI.

## 🚀 **Features**

- **20+ Power Query files** covering all Jira endpoints
- **Advanced analytics** including predictive models
- **Integration monitoring** and ROI analysis
- **Team performance** tracking
- **Cost optimization** recommendations

## 📋 **Prerequisites**

- PowerBI Desktop or Excel with Power Query
- Jira API access
- Basic understanding of Power Query M language

## 🔧 **Setup Instructions**

1. Clone this repository
2. Set up your environment variables (see `env.template`)
3. Import Power Query files into PowerBI/Excel
4. Configure authentication
5. Start building your dashboards!

## 📊 **Available Queries**

- `jira-queries-1-basic-info.pq` - Basic Jira information
- `jira-queries-2-project-analytics.pq` - Project analytics
- `jira-queries-3-team-performance.pq` - Team performance metrics
- ... (and 17 more!)

## 🤝 **Contributing**

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 **License**

This project is licensed under the MIT License - see the LICENSE file for details.
```

### **4.2 Create Setup Instructions**

Create detailed setup instructions:

```markdown
# Team Setup Instructions

## 🔧 **Initial Setup**

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/jira-analytics.git
   cd jira-analytics
   ```

2. **Set up environment variables**:

   ```bash
   cp env.template .env
   # Edit .env with your actual values
   ```

3. **Install dependencies** (if any):

   ```bash
   # Add any installation steps here
   ```

## 📊 **PowerBI Setup**

1. Open PowerBI Desktop
2. Import the Power Query files
3. Configure data sources
4. Set up authentication
5. Create your dashboards

## 🔐 **Security Notes**

- Never commit API tokens or credentials
- Use environment variables for sensitive data
- Regularly rotate API tokens
- Review access permissions quarterly

## 🆘 **Troubleshooting**

### Common Issues

1. **Authentication errors**: Check your API token
2. **Data not loading**: Verify Jira permissions
3. **Performance issues**: Reduce data volume in queries

### Getting Help

- Check the documentation
- Search existing issues
- Create a new issue with details
```

## 🚀 **Step 5: Deploy to GitHub**

### **5.1 Initialize Git Repository**

In your project directory, run:

```bash
git init
git add .
git commit -m "Initial commit: Jira Analytics Suite"
```

### **5.2 Connect to GitHub**

Add your GitHub repository as remote:

```bash
git remote add origin https://github.com/yourusername/jira-analytics.git
git branch -M main
git push -u origin main
```

## 🔄 **Step 6: Set Up Continuous Integration**

### **6.1 GitHub Actions (Optional)**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Validate Markdown
      uses: avto-dev/markdown-lint@v1
      with:
        config: '.markdownlint.yml'
        args: '**/*.md'
    
    - name: Check for secrets
      uses: trufflesecurity/trufflehog@main
      with:
        path: ./
        base: main
        head: HEAD
```

### **6.2 Automated Security Scanning**

Set up automated security scanning for:
- Secret detection
- Dependency vulnerabilities
- Code quality checks

## 📋 **Step 7: Team Onboarding**

### **7.1 Create Team Guidelines**

1. **Code Review Process**:
   - All changes require pull requests
   - Minimum 1 approval required
   - Automated checks must pass

2. **Commit Message Standards**:
   - Use conventional commits format
   - Include issue numbers when applicable
   - Be descriptive and clear

3. **Branch Naming**:
   - `feature/description` for new features
   - `bugfix/description` for bug fixes
   - `hotfix/description` for urgent fixes

### **7.2 Training Materials**

Create training materials for:
- Git/GitHub basics
- Power Query fundamentals
- Jira API usage
- Security best practices

## 🔐 **Step 8: Security Best Practices**

### **8.1 Regular Security Tasks**

- **Monthly**: Review team access permissions
- **Quarterly**: Rotate API tokens
- **Annually**: Review and update security policies

### **8.2 Monitoring**

Set up monitoring for:
- Unusual access patterns
- Failed authentication attempts
- Large data exports
- Unauthorized repository access

## 🎯 **Step 9: Go Live Checklist**

- [ ] Repository created and configured
- [ ] Team members added with appropriate permissions
- [ ] Branch protection rules enabled
- [ ] Documentation created and reviewed
- [ ] Security measures implemented
- [ ] Team training completed
- [ ] Monitoring and alerts configured
- [ ] Backup and recovery procedures tested

## 🆘 **Troubleshooting**

### **Common Issues**

1. **Permission Denied**:
   - Check repository permissions
   - Verify team member access
   - Review branch protection rules

2. **Authentication Failures**:
   - Verify API tokens are valid
   - Check environment variables
   - Test API access manually

3. **Data Access Issues**:
   - Verify Jira permissions
   - Check API rate limits
   - Review query complexity

### **Getting Help**

- Check GitHub documentation
- Review team guidelines
- Contact repository administrators
- Create detailed issue reports

---

**🎉 Congratulations! Your secure Jira analytics repository is ready for team collaboration!**
