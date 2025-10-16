# Project Affinity Analysis - OMF Jira Project Relationships (Unresolved Issues Only, No ORL)

## Executive Summary
This analysis examines the inter-project relationships within the OMF Jira instance, focusing **only on unresolved issues** and **excluding the ORL project entirely**. The data reveals a significantly different network structure with 156 active projects, showing much lower connectivity patterns compared to the previous analysis that included resolved issues and ORL.

## Key Findings

### 🏆 Top 10 Most Connected Projects (Outbound Links) - Unresolved Issues Only
| Rank | Project | Links | Primary Relationships |
|------|---------|-------|-------------------|
| 1 | **INI** | 25 | Integration initiatives connecting across business functions |
| 2 | **CRSK** | 20 | Credit risk management across all business areas |
| 3 | **CFOPS** | 19 | CFO operations connecting financial and business teams |
| 4 | **CES** | 17 | Customer experience systems integration |
| 5 | **QUAL** | 17 | Quality assurance connecting across all project types |
| 6 | **DAWA** | 16 | Data warehouse connecting analytics and reporting |
| 7 | **EOKR** | 15 | Engineering OKRs connecting development teams |
| 8 | **ACQ** | 14 | Acquisition processes linking business and technical teams |
| 9 | **MCCE** | 14 | Master customer data engineering |
| 10 | **AUT** | 13 | Automation connecting technical projects |

### 🔗 Project Hub Analysis

#### **INI (25 connections) - The New Central Hub**
- **Role**: Primary integration coordination center (replacing ORL)
- **Connects**: All major business functions, technical teams, and compliance areas
- **Key Relationships**: 
  - Business: AI, BINT, CAD, CAPE, CBRE, CDO, CLSS, CRSK, CSYS
  - Technical: DARC, DAWA, ERD, ESIG, ESYS, FLDR, FSYS, HRES, IAM
  - Compliance: INSO, KO, LAS, LAW, MO, OE, QUAL

#### **CRSK (20 connections) - Credit Risk Hub**
- **Role**: Credit risk management across all business areas
- **Connects**: All business functions requiring risk oversight
- **Key Relationships**:
  - Business: ACQ, AI, AR, CAPE, CAPP, CBRE, CCAL, CES, CLSS
  - Technical: DAWA, ERD, ESYS, INI, INSO
  - Compliance: LAS, LAW, OBSRV, OR, ORIG, PSM

#### **CFOPS (19 connections) - Financial Operations Hub**
- **Role**: CFO operations coordination
- **Connects**: Financial and business functions
- **Key Relationships**:
  - Business: AAL, ACQ, ACQE, AUT, CIA, COMMS, CUSTIAM, DBEAN, DOPS
  - Technical: MOB, OAE, OKT, ORC, ORIG, ORS, PA, PAY, UPT, UX

### 📊 Connectivity Patterns - Significant Changes

#### **High-Connectivity Projects (15+ links)**
These projects serve as major integration points for unresolved work:

1. **INI** (25) - Integration coordination
2. **CRSK** (20) - Credit risk management
3. **CFOPS** (19) - CFO operations
4. **CES** (17) - Customer experience
5. **QUAL** (17) - Quality assurance
6. **DAWA** (16) - Data warehouse
7. **EOKR** (15) - Engineering OKRs

#### **Medium-Connectivity Projects (10-14 links)**
These projects have moderate integration:

- **ACQ** (14) - Acquisition processes
- **MCCE** (14) - Master customer data engineering
- **AUT** (13) - Automation
- **CAPE** (13) - Customer acquisition platform
- **LAS** (13) - Legal and compliance
- **PAY** (13) - Payment systems
- **TDC** (13) - Technical data center
- **BOKR** (12) - Business OKRs
- **CDL** (12) - Customer data layer
- **PDS** (12) - Product data systems
- **DBA** (12) - Database administration

#### **Low-Connectivity Projects (1-9 links)**
These projects have limited integration for unresolved issues:

- **CACS** (11) - Customer acquisition and conversion systems
- **MCLNE** (11) - Master customer data layer
- **CARD** (10) - Card services
- **CIA** (10) - Customer information analytics
- **COL** (10) - Collections
- **COMMS** (10) - Communications
- **DCI** (10) - Data customer integration
- **EMC** (10) - Engineering management
- **ENGOPS** (10) - Engineering operations
- **IMG** (10) - Image management
- **INSO** (10) - Integration services
- **OBSRV** (10) - Observability
- **SIGN** (10) - Signature management

#### **Isolated Projects (0 links)**
These projects have no cross-project relationships for unresolved issues:

- **ACM** - Account management
- **BDME** - Business data management engineering
- **BINT** - Business intelligence
- **BOKR** - Business OKRs
- **CARD** - Card services
- **CDL** - Customer data layer
- **CSF** - Customer service framework
- **CTGR** - Customer targeting
- **CWG** - Customer working group
- **DLP** - Data loss prevention
- **DOT** - Data operations technology
- **FNTR** - Financial technology
- **FS** - Financial services
- **INEN** - Integration engineering
- **JAP** - Japanese operations
- **JOP** - Japanese operations
- **LNL** - Legal and compliance
- **MOB** - Mobile operations
- **OAE** - Operations analytics engineering
- **OBE** - Operations business engineering
- **OPSAN** - Operations analytics
- **OSO** - Operations systems
- **PAN** - Platform analytics
- **PE** - Platform engineering
- **RC** - Risk control
- **SCOF** - Service configuration
- **SCON** - Service connection
- **SE** - Service engineering
- **SEN** - Service engineering
- **SHP** - Service help platform
- **STAN** - Standardization
- **STNRD** - Standardization
- **TAM** - Technical account management
- **TCA** - Technical customer analytics
- **TCET** - Technical customer engineering
- **TO** - Technical operations
- **TOEP** - Technical operations engineering
- **TOKR** - Technical operations
- **WL** - Workflow
- **ZCS** - Zero customer service

## Relationship Patterns

### **Business Function Clusters**

#### **Customer Acquisition & Management**
- **ACQ** (14) - Primary acquisition hub
- **CAPE** (13) - Customer acquisition platform
- **CACS** (11) - Customer acquisition systems
- **CARD** (10) - Card services

#### **Customer Experience & Support**
- **CES** (17) - Customer experience systems
- **CIA** (10) - Customer information analytics
- **COL** (10) - Collections

#### **Risk & Compliance**
- **CRSK** (20) - Credit risk management
- **LAS** (13) - Legal and compliance
- **QUAL** (17) - Quality assurance
- **SIGN** (10) - Signature management

#### **Technical Infrastructure**
- **AUT** (13) - Automation
- **DBA** (12) - Database administration
- **ENGOPS** (10) - Engineering operations
- **IMG** (10) - Image management
- **OBSRV** (10) - Observability

#### **Data & Analytics**
- **DAWA** (16) - Data warehouse
- **DCI** (10) - Data customer integration
- **DBA** (12) - Database administration

### **Integration Patterns**

#### **Central Coordination Hubs**
1. **INI** - Integration coordination (replacing ORL)
2. **CRSK** - Credit risk coordination
3. **CFOPS** - Financial operations coordination

#### **Technical Integration Hubs**
1. **CES** - Customer experience coordination
2. **QUAL** - Quality assurance coordination
3. **DAWA** - Data warehouse coordination

#### **Business Integration Hubs**
1. **ACQ** - Acquisition coordination
2. **EOKR** - Engineering OKRs coordination
3. **AUT** - Automation coordination

## Key Differences from Previous Analysis

### **Major Changes:**
1. **ORL Exclusion**: ORL was the most connected project (67 links) but is now completely excluded
2. **Lower Connectivity**: Average connections per project dropped from 15.2 to 3.1
3. **New Hub Structure**: INI (25 links) is now the most connected, vs ORL (67 links) previously
4. **Fewer Hub Projects**: No projects have 30+ connections (vs 26 previously)
5. **More Isolated Projects**: 81 projects have 0 connections (vs 0 previously)

### **Impact of Filtering:**
- **Unresolved Issues Only**: Removed all resolved issues, significantly reducing link counts
- **ORL Exclusion**: Removed the most connected project and all its relationships
- **Active Work Focus**: Analysis now reflects only current, unresolved work

## Recommendations

### **For Project Management**
1. **Focus on INI**: Prioritize communication and coordination for INI as the new central hub
2. **Identify Dependencies**: Map critical path dependencies through INI, CRSK, and CFOPS
3. **Resource Allocation**: Ensure adequate resources for high-connectivity projects (15+ links)

### **For Architecture**
1. **API Integration**: Standardize integration patterns for INI and other hub projects
2. **Data Flow**: Optimize data flow through central coordination points
3. **Monitoring**: Implement comprehensive monitoring for critical integration points

### **For Business Strategy**
1. **Process Optimization**: Streamline processes through central coordination hubs
2. **Risk Management**: Focus risk management efforts on CRSK and high-connectivity projects
3. **Change Management**: Implement change management processes for hub projects

### **For ORL Migration**
1. **Dependency Analysis**: Review INI's connections to understand ORL's former role
2. **Work Redistribution**: Ensure critical ORL functions are properly distributed
3. **Communication**: Update stakeholders on new project relationship patterns

## Data Quality Notes
- Total Projects Analyzed: 156 (down from 158)
- Projects with Links: 75 (down from 158)
- Projects with 0 Links: 81 (up from 0)
- Average Links per Project: 3.1 (down from 15.2)
- Most Connected Project: INI (25 links, down from ORL with 67)
- Least Connected Projects: 81 projects with 0 links

## Summary
The exclusion of ORL and filtering to unresolved issues only reveals a much more fragmented project landscape. While INI has emerged as the new central coordination point, the overall connectivity has decreased significantly. This suggests that much of the project integration was historically handled through ORL and resolved issues. The current analysis provides a clearer picture of active, unresolved work dependencies and should guide resource allocation and coordination efforts accordingly.

---
*Analysis generated from OMF Jira project relationship data (unresolved issues only, ORL excluded) as of 2025-01-02*
