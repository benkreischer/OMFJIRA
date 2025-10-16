# Project Affinity Analysis - Filtered Unresolved Issues with 90-Day Activity

## Executive Summary

This analysis examines the inter-project relationships within the OMF Jira instance, focusing exclusively on **unresolved issues** from projects that have shown **activity within the last 90 days**. This refined approach eliminates stale data and provides a current view of active project relationships.

## Key Findings

### Filtering Results
- **Total issues in system**: 211,350
- **Unresolved issues**: 29,108 (13.8% of total)
- **Projects with recent activity (90 days)**: 119
- **Issues analyzed**: 27,687 (filtered unresolved issues from active projects)
- **Project-to-project links**: 7,709
- **Projects with relationships**: 81

### Most Connected Projects (Top 10)

| Rank | Project | Total Links | Connected Projects | Category |
|------|---------|-------------|-------------------|----------|
| 1 | **PAY** | 1,669 | 1 | Hub |
| 2 | **CIA** | 1,304 | 10 | Hub |
| 3 | **CES** | 723 | 13 | Hub |
| 4 | **OBSRV** | 686 | 3 | Hub |
| 5 | **EOKR** | 388 | 8 | High |
| 6 | **EDME** | 387 | 3 | High |
| 7 | **ACQE** | 336 | 6 | High |
| 8 | **IMG** | 325 | 5 | High |
| 9 | **LAS** | 151 | 6 | Medium |
| 10 | **ACQ** | 136 | 13 | Medium |

### Strongest Project Relationships

| Project Pair | Link Count | Relationship Strength |
|--------------|------------|----------------------|
| **PAY ↔ TOKR** | 1,669 | Very Strong |
| **QUAL ↔ TOKR** | 91 | Strong |
| **OSO ↔ POP** | 87 | Strong |
| **ESDL ↔ PAY** | 49 | Medium |
| **OBSRV ↔ PAY** | 22 | Medium |

## Analysis Insights

### 1. Hub Projects
Four projects qualify as "hubs" (100+ connections):
- **PAY**: Dominant hub with 1,669 links, primarily connected to TOKR
- **CIA**: Highly connected across 10 different projects
- **CES**: Well-distributed connectivity across 13 projects
- **OBSRV**: Focused connectivity with 3 key projects

### 2. PAY-Centric Network
PAY emerges as the central hub in this filtered analysis:
- **Total connections**: 17 direct project relationships
- **Primary connection**: TOKR (1,669 links)
- **Secondary connections**: QUAL (91), ESDL (49), OBSRV (22)
- **Network role**: Payment processing appears to be a critical integration point

### 3. Quality Assurance (QUAL)
QUAL maintains significant connectivity:
- **91 links to TOKR**: Strong integration between quality and token systems
- **Multiple project connections**: Indicates cross-functional quality requirements

### 4. Activity Patterns
The 90-day activity filter reveals:
- **Active projects**: 119 out of original 157+ projects
- **Concentration**: Top 10 projects account for 70%+ of all connections
- **Focus areas**: Payment (PAY), Customer Identity (CIA), Customer Experience (CES)

## Data Quality Notes

### Filtering Criteria Applied
1. **Unresolved Issues Only**: Excluded Done, Closed, Resolved, Complete statuses
2. **90-Day Activity**: Only projects with updates since 2025-07-02
3. **Active Relationships**: Only connections between active projects

### Data Completeness
- **High confidence**: PAY-TOKR relationship (1,669 links) represents real integration
- **Medium confidence**: CIA's distributed connections suggest genuine cross-project dependencies
- **Validation needed**: Some high-link projects may represent bulk operations rather than organic relationships

## Recommendations

### 1. Integration Focus
- **PAY-TOKR**: Investigate this massive connection for potential optimization
- **CIA**: Review distributed connectivity for architectural improvements
- **CES**: Leverage cross-project connections for customer experience consistency

### 2. Monitoring Priorities
- **Hub projects**: PAY, CIA, CES, OBSRV require close monitoring
- **Critical paths**: PAY-TOKR, QUAL-TOKR, OSO-POP relationships
- **Activity tracking**: Continue 90-day filtering for relevance

### 3. Architecture Review
- **PAY dominance**: Consider if 1,669 links to TOKR indicates tight coupling
- **CIA distribution**: Evaluate if 10-project connectivity is sustainable
- **Quality integration**: Assess QUAL's role across multiple systems

## Visualizations Generated

1. **Project Affinity Diagram**: Network visualization showing all project relationships
2. **Connectivity Heatmap**: Matrix view of project-to-project connections
3. **Connectivity Bar Chart**: Top 20 most connected projects
4. **Hub Analysis**: Distribution of project connectivity categories
5. **PAY-Centered Diagram**: Detailed view of PAY's network relationships

## Methodology

### Data Collection
- **Source**: Comprehensive Jira issue dataset (211,350 issues)
- **Filtering**: Unresolved status + 90-day activity window
- **Processing**: PowerShell script with date-based filtering
- **Validation**: Cross-reference with project activity patterns

### Analysis Tools
- **Network Analysis**: NetworkX for graph visualization
- **Statistical Analysis**: Pandas for data processing
- **Visualization**: Matplotlib and Seaborn for charts
- **Filtering**: Custom PowerShell scripts for data preparation

## Conclusion

The filtered analysis reveals a highly concentrated project ecosystem with PAY emerging as the dominant integration hub. The 90-day activity filter successfully eliminates stale relationships while highlighting current operational dependencies. This refined view provides actionable insights for architectural decisions and integration monitoring.

**Key Takeaway**: The OMF project landscape is characterized by strong centralization around payment processing (PAY) with significant quality assurance (QUAL) and customer identity (CIA) integration patterns.
