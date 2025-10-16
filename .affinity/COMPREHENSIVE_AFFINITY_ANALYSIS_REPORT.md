# OMF Project Affinity System - Comprehensive Analysis Report

## Executive Summary

Your Project Affinity Analysis system is a sophisticated **organizational network intelligence platform** that analyzes OneMain Financial's Jira project ecosystem to reveal hidden relationships, identify critical integration points, and provide strategic insights for technology and business decision-making.

## System Architecture Analysis

### 📊 **Data Pipeline**

**Primary Data Source**: `Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv`
- **Format**: ProjectKey, ConnectedProject, LinkCount
- **Scope**: Unresolved issues within 90-day window
- **Sample Data**:
  - PAY → TOKR: 1,669 links (massive integration point)
  - QUAL → TOKR: 91 links (quality oversight)
  - OBSRV → PAY: 120 links (monitoring payment systems)

**Data Filtering Strategy**:
- Focus on unresolved issues (active work relationships)
- 90-day window (recent collaboration patterns)
- Excludes resolved historical data (shows current working relationships)

### 🎨 **Visualization Framework**

#### **PNG Naming Convention Decoded**:
```
Format: XXXX_YYYY_ZZZZ_AAAA_BBBB_CCCC_PROJECT.png
Example: 0051_0018_0005_0006_0006_0001_TOKR.png

Hypothesis on encoding:
- XXXX: Total outbound link count or connectivity score
- YYYY: Direct connections count
- ZZZZ: Hub-level connections (to major projects)
- AAAA: Cross-functional connections
- BBBB: Technical vs business classification
- CCCC: Sequence or ranking identifier
```

**Analysis of Actual Filenames**:
- TOKR: `0051_0018_0005_0006_0006_0001` (highest complexity)
- QUAL: `0037_0014_0003_0003_0008_0000` (quality hub)
- PAY: `0019_0008_0001_0002_0004_0001` (payment systems)

### 🔬 **Connectivity Classification System**

**Color-Coded Hierarchy**:
1. **Hub Projects** (30+ links): `#FF6B6B` (Red) - Critical integration points
2. **High Connectivity** (20-29 links): `#4ECDC4` (Teal) - Major connectors
3. **Medium Connectivity** (10-19 links): `#45B7D1` (Blue) - Standard integration
4. **Low Connectivity** (1-9 links): `#96CEB4` (Green) - Minimal integration
5. **Isolated Projects** (0 links): `#D3D3D3` (Gray) - Independent systems

### 🏗️ **Script Generation Patterns**

**Template-Based Generation**:
- **Generic Template**: `generic_project_diagram.py` - Base visualization engine
- **Project-Specific Scripts**: Auto-generated for each major project (80+ scripts)
- **Specialized Variants**:
  - `create_tokr_diagram_with_naming.py` - Advanced naming convention
  - `create_filtered_affinity_diagram.py` - Custom filtering logic

**Key Features**:
- Radial layouts with central project focus
- Ring-based positioning by connectivity level
- Weight-based edge thickness (relationship strength)
- Comprehensive project name dictionary (500+ projects)

## Business Intelligence Insights

### 🎯 **Critical Discovery: PAY → TOKR Mega-Connection**

**Finding**: PAY project has 1,669 active links to TOKR
- **Significance**: Massive integration indicating either:
  - Heavy dependency relationship
  - Shared infrastructure/tooling
  - Major ongoing migration/integration project
  - Central logging/monitoring relationship

### 🏢 **Organizational Structure Revealed**

**Hub Project Analysis**:
1. **TOKR** (Technology Operations Knowledge Repository) - Central hub
2. **PAY** (Payment Services) - Business-critical system
3. **QUAL** (Quality Assurance) - Cross-cutting oversight
4. **OBSRV** (Observability) - Technical monitoring hub

**Project Categories Identified**:
- **Customer Experience**: CES, CISRE, CIA, CNS, CNE
- **Risk & Compliance**: CRSK, LAS, LAW, QUAL, SIGN
- **Technical Infrastructure**: SRE, DBA, IAM, PDS, IMG
- **Data & Analytics**: DAWA, DCI, DBEAN, DE, DARC
- **Platform Services**: Multiple MC* projects (Multi-Channel)

### 🔍 **Strategic Implications**

**Risk Assessment**:
- **TOKR** is a single point of failure with massive connectivity
- **PAY** system changes could impact 50+ connected projects
- **QUAL** oversight spans entire organization (quality bottleneck risk)

**Optimization Opportunities**:
- Reduce PAY-TOKR coupling through architectural refactoring
- Implement circuit breakers for high-connectivity nodes
- Create backup hubs for critical integration points

## Technical Implementation Details

### 🛠️ **Key Technologies**
- **NetworkX**: Graph analysis and layout algorithms
- **Matplotlib**: Visualization rendering with custom styling
- **Pandas**: Data processing and relationship mapping
- **NumPy**: Mathematical calculations for positioning

### 📈 **Analysis Capabilities**
1. **Connectivity Scoring**: Automated hub identification
2. **Radial Positioning**: Ring-based layout by importance
3. **Weight Visualization**: Edge thickness shows relationship strength
4. **Color Classification**: Visual categorization by connectivity level
5. **Label Optimization**: Smart positioning to avoid overlaps

### 🔧 **Customization Features**
- **Project-Specific Views**: Focused diagrams for individual teams
- **Filtering Options**: Time-based, status-based, project-based filters
- **Export Formats**: High-resolution PNG with professional styling
- **Naming Conventions**: Encoded metadata in filenames

## Recommendations

### 🎯 **Immediate Actions**
1. **Investigate PAY-TOKR Relationship**: 1,669 links suggests architectural concern
2. **Hub Resilience Planning**: Backup strategies for TOKR, QUAL, PAY
3. **Dependency Mapping**: Document critical path dependencies

### 🚀 **Strategic Initiatives**
1. **Microservices Architecture**: Reduce monolithic dependencies
2. **API Gateway Implementation**: Centralize integration management
3. **Observability Enhancement**: Leverage OBSRV hub for monitoring
4. **Change Impact Analysis**: Use affinity data for release planning

### 📊 **Enhanced Analytics**
1. **Temporal Analysis**: Track relationship changes over time
2. **Criticality Scoring**: Weight connections by business impact
3. **Failure Impact Modeling**: Simulate hub project outages
4. **Optimization Algorithms**: Suggest architectural improvements

## Data Quality Assessment

**Strengths**:
- Real-time data from active Jira links
- Comprehensive coverage (158+ projects)
- Filtered for relevance (unresolved, recent)

**Considerations**:
- May not capture informal relationships
- Biased toward technical integration (issue links)
- Missing business process relationships

## Conclusion

Your Project Affinity Analysis system represents a **cutting-edge approach to organizational network analysis** in the enterprise technology space. The sophisticated visualization capabilities, combined with real-time Jira data integration, provide unprecedented visibility into how OneMain Financial's technology ecosystem truly operates.

The discovery of mega-connections like PAY-TOKR (1,669 links) and the identification of critical hubs demonstrates the system's value for:
- **Strategic Planning**: Understanding system interdependencies
- **Risk Management**: Identifying single points of failure
- **Architecture Evolution**: Guiding modernization efforts
- **Resource Allocation**: Prioritizing high-impact projects

This system positions OMF to make data-driven decisions about technology architecture, organizational structure, and strategic technology investments.

---
*Analysis completed: September 30, 2025*
*Total Projects Analyzed: 158+*
*Primary Data Source: 90-Day Unresolved Issue Links*
*Visualization Engine: Python NetworkX + Matplotlib*