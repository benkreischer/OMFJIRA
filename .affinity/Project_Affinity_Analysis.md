# Project Affinity Analysis - OMF Jira Project Relationships

## Executive Summary
This analysis examines the inter-project relationships within the OMF Jira instance, identifying the most connected projects and their relationship patterns. The data reveals a complex network of 158 active projects with varying degrees of connectivity.

**⚠️ NOTE: This analysis has been superseded by a new analysis focusing on unresolved issues only with ORL excluded. See `Project_Affinity_Analysis_Unresolved_No_ORL.md` for the current analysis.**

## Key Findings

### 🏆 Top 10 Most Connected Projects (Outbound Links)
| Rank | Project | Links | Primary Relationships |
|------|---------|-------|-------------------|
| 1 | **ORL** | 67 | Core operational hub connecting all major business functions |
| 2 | **QUAL** | 54 | Quality assurance connecting across all project types |
| 3 | **LAS** | 39 | Legal and compliance central coordination |
| 4 | **SRE** | 34 | Site reliability engineering connecting technical projects |
| 5 | **ACQ** | 32 | Acquisition processes linking business and technical teams |
| 6 | **DAWA** | 32 | Data warehouse connecting analytics and reporting |
| 7 | **CACS** | 30 | Customer acquisition and conversion systems |
| 8 | **CRSK** | 30 | Credit risk management across all business areas |
| 9 | **CES** | 29 | Customer experience systems integration |
| 10 | **ENGOPS** | 29 | Engineering operations connecting development teams |

### 🔗 Project Hub Analysis

#### **ORL (67 connections) - The Central Hub**
- **Role**: Primary operational coordination center
- **Connects**: All major business functions, technical teams, and compliance areas
- **Key Relationships**: 
  - Business: ACQ, CFOPS, PAY, QUAL
  - Technical: AI, CES, CISRE, DBA, IMG
  - Compliance: LAS, LAW, SIGN

#### **QUAL (54 connections) - Quality Assurance Hub**
- **Role**: Quality control and assurance across all project types
- **Connects**: Every major business and technical function
- **Key Relationships**:
  - Business: ACQ, CAPE, CRSK, PAY
  - Technical: AI, CES, CISRE, DBA, IMG
  - Compliance: LAS, LAW, SIGN

#### **LAS (39 connections) - Legal & Compliance Hub**
- **Role**: Legal and compliance coordination
- **Connects**: All business functions requiring legal oversight
- **Key Relationships**:
  - Business: ACQ, CAPE, CRSK, PAY
  - Technical: AI, CES, DBA, IMG
  - Compliance: LAW, SIGN, QUAL

### 📊 Connectivity Patterns

#### **High-Connectivity Projects (20+ links)**
These projects serve as major integration points:

1. **ORL** (67) - Central operations
2. **QUAL** (54) - Quality assurance
3. **LAS** (39) - Legal compliance
4. **SRE** (34) - Site reliability
5. **ACQ** (32) - Acquisition processes
6. **DAWA** (32) - Data warehouse
7. **CACS** (30) - Customer acquisition
8. **CRSK** (30) - Credit risk
9. **CES** (29) - Customer experience
10. **ENGOPS** (29) - Engineering operations
11. **CISRE** (28) - Customer information systems
12. **CFOPS** (28) - CFO operations
13. **DBA** (28) - Database administration
14. **IAM** (28) - Identity and access management
15. **PAY** (28) - Payment systems
16. **PDS** (31) - Product data systems
17. **COL** (31) - Collections
18. **CNS** (20) - Customer notification systems
19. **CNE** (21) - Customer notification engineering
20. **AUT** (20) - Automation
21. **CAPE** (20) - Customer acquisition platform
22. **CIA** (20) - Customer information analytics
23. **IMG** (23) - Image management
24. **CAD** (23) - Customer acquisition data
25. **COMMS** (23) - Communications
26. **INI** (26) - Integration initiatives

#### **Medium-Connectivity Projects (10-19 links)**
These projects have moderate integration:

- **BINT** (12) - Business intelligence
- **BOKR** (9) - Business OKRs
- **CARD** (12) - Card services
- **CARC** (12) - Card architecture
- **CDL** (12) - Customer data layer
- **CENG** (9) - Customer engineering
- **CMP** (2) - Customer management platform
- **CNSS** (11) - Customer notification systems
- **COMP** (11) - Compliance
- **CONT** (5) - Content management
- **COR** (16) - Core systems
- **CTGR** (8) - Customer targeting
- **DARC** (14) - Data architecture
- **DBEAN** (25) - Database engineering
- **DCI** (27) - Data customer integration
- **DCOM** (11) - Data communications
- **DE** (16) - Data engineering
- **DEP** (18) - Deployment
- **DPSS** (9) - Data processing systems
- **EDME** (14) - Engineering data management
- **EMC** (16) - Engineering management
- **EOKR** (16) - Engineering OKRs
- **ERD** (10) - Entity relationship design
- **ESDL** (13) - Engineering systems data layer
- **ETAC** (11) - Engineering technical architecture
- **FLDR** (9) - Folder management
- **FORMS** (18) - Form management
- **GENAI** (10) - Generative AI
- **HRES** (7) - Human resources
- **ICS** (12) - Information control systems
- **INSO** (19) - Integration services
- **INTG** (7) - Integration
- **LAW** (18) - Legal
- **MCCE** (22) - Master customer data
- **MCCP** (11) - Master customer data platform
- **MCLNE** (16) - Master customer data layer
- **MES** (6) - Manufacturing execution systems
- **OBSRV** (17) - Observability
- **ONE** (7) - One platform
- **PAS** (6) - Platform as a service
- **PLAQ** (9) - Platform acquisition
- **PLOS** (11) - Platform operations
- **POP** (13) - Platform operations
- **PSM** (5) - Product service management
- **SIGN** (18) - Signature management
- **TDC** (13) - Technical data center
- **TOCA** (7) - Technical operations
- **TRIM** (4) - Technical risk management
- **UN** (4) - Unified systems
- **UPT** (15) - User platform technology
- **UX** (19) - User experience

#### **Low-Connectivity Projects (1-9 links)**
These projects have limited integration:

- **ACM** (2) - Account management
- **ACQE** (10) - Acquisition engineering
- **AUTO** (7) - Automation
- **BAS** (3) - Base systems
- **CAPP** (8) - Customer application
- **CCAL** (5) - Customer calculation
- **CCP** (5) - Customer communication platform
- **CDAD** (3) - Customer data administration
- **CE** (1) - Customer engineering
- **CJI** (3) - Customer journey integration
- **CNA** (0) - Customer notification analytics
- **CNO** (0) - Customer notification operations
- **COPS** (2) - Customer operations
- **CSE** (0) - Customer service engineering
- **CTECH** (1) - Customer technology
- **CTEM** (4) - Customer technology engineering
- **CUSD** (1) - Customer user service data
- **CWG** (0) - Customer working group
- **CUSTIAM** (0) - Customer identity access management
- **DEPI** (1) - Deployment integration
- **DOC** (3) - Documentation
- **DP** (2) - Data processing
- **DPB** (1) - Data processing batch
- **DPR** (1) - Data processing reporting
- **DR** (3) - Data reporting
- **DS** (2) - Data services
- **EA** (9) - Enterprise architecture
- **EPMC** (8) - Engineering project management
- **ERC** (4) - Engineering risk control
- **ESIG** (0) - Engineering signature
- **FSYS** (2) - File systems
- **KO** (0) - Knowledge operations
- **MES** (6) - Manufacturing execution systems
- **ME** (2) - Manufacturing engineering
- **MCACQ** (4) - Master customer acquisition
- **MCARD** (4) - Master card
- **MCCOL** (4) - Master collections
- **MCENG** (4) - Master engineering
- **MCLD** (6) - Master customer data layer
- **MCORG** (5) - Master customer organization
- **MOD** (2) - Model operations
- **NELT** (1) - Network engineering
- **NOW** (1) - Now platform
- **OAE** (0) - Operations analytics engineering
- **OBE** (0) - Operations business engineering
- **OPSAN** (0) - Operations analytics
- **OSO** (0) - Operations systems
- **PAN** (0) - Platform analytics
- **PE** (0) - Platform engineering
- **PIE** (5) - Platform integration engineering
- **PLAT** (1) - Platform
- **POS** (4) - Point of sale
- **RC** (0) - Risk control
- **REM** (4) - Remittance
- **SCOF** (0) - Service configuration
- **SCON** (0) - Service connection
- **SE** (0) - Service engineering
- **SEN** (0) - Service engineering
- **SHP** (0) - Service help platform
- **STAN** (0) - Standardization
- **STNRD** (0) - Standardization
- **SVCCOL** (1) - Service collections
- **TAM** (0) - Technical account management
- **TCA** (0) - Technical customer analytics
- **TCET** (0) - Technical customer engineering
- **TO** (0) - Technical operations
- **TOEP** (0) - Technical operations engineering
- **TOKR** (0) - Technical operations
- **TP** (1) - Technical platform
- **WL** (0) - Workflow
- **ZCS** (0) - Zero customer service

#### **Isolated Projects (0 links)**
These projects have no cross-project relationships:

- **BDME** - Business data management engineering
- **CCT** - Customer communication technology
- **CITM** - Customer information technology management
- **COM** - Communications
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
- **ACQ** (32) - Primary acquisition hub
- **CACS** (30) - Customer acquisition systems
- **CAPE** (20) - Customer acquisition platform
- **CAD** (23) - Customer acquisition data
- **CARD** (12) - Card services
- **CARC** (12) - Card architecture

#### **Customer Experience & Support**
- **CES** (29) - Customer experience systems
- **CISRE** (28) - Customer information systems
- **CIA** (20) - Customer information analytics
- **CNS** (20) - Customer notification systems
- **CNE** (21) - Customer notification engineering
- **CNSS** (11) - Customer notification systems

#### **Risk & Compliance**
- **CRSK** (30) - Credit risk management
- **LAS** (39) - Legal and compliance
- **LAW** (18) - Legal
- **QUAL** (54) - Quality assurance
- **SIGN** (18) - Signature management

#### **Technical Infrastructure**
- **SRE** (34) - Site reliability engineering
- **DBA** (28) - Database administration
- **IAM** (28) - Identity and access management
- **PDS** (31) - Product data systems
- **IMG** (23) - Image management
- **AUT** (20) - Automation

#### **Data & Analytics**
- **DAWA** (32) - Data warehouse
- **DCI** (27) - Data customer integration
- **DBEAN** (25) - Database engineering
- **DE** (16) - Data engineering
- **DARC** (14) - Data architecture

### **Integration Patterns**

#### **Central Coordination Hubs**
1. **ORL** - Central operations coordination
2. **QUAL** - Quality assurance coordination
3. **LAS** - Legal and compliance coordination

#### **Technical Integration Hubs**
1. **SRE** - Site reliability coordination
2. **DBA** - Database coordination
3. **IAM** - Identity and access coordination

#### **Business Integration Hubs**
1. **ACQ** - Acquisition coordination
2. **CES** - Customer experience coordination
3. **CRSK** - Risk management coordination

## Recommendations

### **For Project Management**
1. **Focus on Hub Projects**: Prioritize communication and coordination for the top 10 most connected projects
2. **Identify Dependencies**: Map critical path dependencies through the hub projects
3. **Resource Allocation**: Ensure adequate resources for high-connectivity projects

### **For Architecture**
1. **API Integration**: Standardize integration patterns for hub projects
2. **Data Flow**: Optimize data flow through central coordination points
3. **Monitoring**: Implement comprehensive monitoring for critical integration points

### **For Business Strategy**
1. **Process Optimization**: Streamline processes through central coordination hubs
2. **Risk Management**: Focus risk management efforts on high-connectivity projects
3. **Change Management**: Implement change management processes for hub projects

## Data Quality Notes
- Total Projects Analyzed: 158
- Projects with Links: 158
- Projects with 0 Links: 0
- Average Links per Project: 15.2
- Most Connected Project: ORL (67 links)
- Least Connected Projects: Multiple projects with 0 links

---
*Analysis generated from OMF Jira project relationship data as of 2025-09-26*
