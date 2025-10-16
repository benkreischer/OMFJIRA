#!/usr/bin/env python3
"""
Generate Complete Project Connection Tables for All Projects
Creates individual perspective tables for every project in the dataset
"""

import pandas as pd
import numpy as np
from collections import defaultdict

def load_and_analyze_connections():
    """Load the main CSV and create comprehensive connection matrix"""
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = pd.read_csv(csv_file)

    print(f"Loaded {len(df)} relationship records")
    print(f"Total link count: {df['LinkCount'].sum():,}")

    # Get unique projects
    all_projects = set()
    for _, row in df.iterrows():
        all_projects.add(row['ProjectKey'])
        all_projects.add(row['ConnectedProject'])

    all_projects = sorted(list(all_projects))
    print(f"Found {len(all_projects)} unique projects")

    # Create project totals
    project_totals = defaultdict(int)
    for _, row in df.iterrows():
        project_totals[row['ProjectKey']] += row['LinkCount']
        project_totals[row['ConnectedProject']] += row['LinkCount']

    # Create direct connection matrix
    connection_matrix = defaultdict(lambda: defaultdict(int))
    for _, row in df.iterrows():
        project1 = row['ProjectKey']
        project2 = row['ConnectedProject']
        links = row['LinkCount']

        connection_matrix[project1][project2] = links
        connection_matrix[project2][project1] = links

    return df, all_projects, project_totals, connection_matrix

def analyze_project_perspective(project, df, all_projects, project_totals, connection_matrix):
    """Analyze connections from a specific project's perspective"""
    if project not in project_totals:
        return None, []

    # Get all projects that connect to this project
    connected_projects = []
    for other_project in all_projects:
        if other_project != project and connection_matrix[project][other_project] > 0:
            connected_projects.append(other_project)

    # Calculate network connections for each connected project
    project_connections = []
    for other_project in connected_projects:
        # Count how many projects in this network the other_project connects to
        network_connections = 0

        # Check connections to other projects in this project's network (including central project)
        for third_project in connected_projects + [project]:
            if third_project != other_project and connection_matrix[other_project][third_project] > 0:
                network_connections += 1

        # Get direct link count and total links
        direct_links = connection_matrix[project][other_project]
        total_links = project_totals[other_project]

        # Classify ring
        if network_connections >= 6:
            ring = "Hub Ring (6+ connections)"
        elif network_connections >= 4:
            ring = "High Ring (4-5 connections)"
        elif network_connections >= 2:
            ring = "Medium Ring (2-3 connections)"
        else:
            ring = "Low Ring (1 connection)"

        project_connections.append({
            'connected_project': other_project,
            'network_connections': network_connections,
            'direct_links': direct_links,
            'total_links': total_links,
            'ring_classification': ring
        })

    # Sort by network connections desc, then direct links desc
    project_connections.sort(key=lambda x: (x['network_connections'], x['direct_links']), reverse=True)

    return project_totals[project], project_connections

def generate_project_name_expansions():
    """Generate expanded names for project codes"""
    expansions = {
        'TOKR': 'Token Services',
        'PAY': 'Payment Services',
        'EOKR': 'Engineering OKR Repository',
        'CIA': 'Customer Information Analytics',
        'OBSRV': 'Observability Platform',
        'CES': 'Customer Experience Systems',
        'EPMC': 'Enterprise Project Management Center',
        'EDME': 'Enterprise Data Management Engine',
        'IMG': 'Image Management',
        'ACQE': 'Acquisition Engineering',
        'UPT': 'User Platform Technology',
        'LAS': 'Loan Application System',
        'ACQ': 'Acquisition Systems',
        'TRIM': 'Technical Risk Management',
        'QUAL': 'Quality Assurance',
        'CARD': 'Card Services',
        'POP': 'Platform Operations',
        'AUT': 'Automation',
        'OAE': 'Operations Analytics Engine',
        'OSO': 'Operations Support Office',
        'MOB': 'Mobile Platform',
        'ENGOPS': 'Engineering Operations',
        'DBEAN': 'Database Engineering Analytics',
        'PDS': 'Platform Data Services',
        'COL': 'Collections',
        'FORMS': 'Forms Management',
        'DAWA': 'Data Warehouse',
        'COR': 'Core Systems',
        'BINT': 'Business Intelligence',
        'DARC': 'Data Architecture',
        'SIGN': 'Digital Signatures',
        'UX': 'User Experience',
        'ONE': 'OneMain Platform',
        'UN': 'Unified Network',
        'IAM': 'Identity Access Management',
        'PSM': 'Platform Service Management',
        'CISRE': 'Customer Information Systems',
        'CAPS': 'Customer Acquisition Platform Services',
        'CARC': 'Customer Acquisition Risk Control',
        'AI': 'Artificial Intelligence',
        'BINT': 'Business Intelligence',
        'CAD': 'Customer Acquisition Data',
        'CAPE': 'Customer Acquisition Platform Engineering',
        'CACS': 'Customer Acquisition Conversion Systems',
        'CFOPS': 'CFO Operations',
        'CCAL': 'Customer Calculation',
        'CCP': 'Customer Communication Platform',
        'CDL': 'Customer Data Layer',
        'CENG': 'Customer Engineering',
        'CNE': 'Customer Notification Engineering',
        'CNSS': 'Customer Notification Systems',
        'CNS': 'Customer Notification Services',
        'COMMS': 'Communications',
        'COMP': 'Compliance',
        'CONT': 'Content Management',
        'CTGR': 'Customer Targeting',
        'DBA': 'Database Administration',
        'DCI': 'Data Center Infrastructure',
        'DCOM': 'Data Communications',
        'DE': 'Data Engineering',
        'DEP': 'Deployment',
        'DPSS': 'Data Platform Security Services',
        'DR': 'Disaster Recovery',
        'DS': 'Data Services',
        'EA': 'Enterprise Architecture',
        'EMC': 'Enterprise Management Console',
        'ERD': 'Enterprise Resource Database',
        'ESDL': 'Enterprise Service Data Layer',
        'ETAC': 'Enterprise Technology Architecture',
        'FLDR': 'Folder Management',
        'GENAI': 'Generative AI',
        'HRES': 'Human Resources',
        'ICS': 'Infrastructure Control System',
        'INI': 'Infrastructure Integration',
        'INSO': 'Infrastructure Operations',
        'INTG': 'Integration Services',
        'LAW': 'Legal Services',
        'MCCE': 'Multi-Channel Customer Experience',
        'MCCP': 'Multi-Channel Customer Platform',
        'MCLD': 'Multi-Channel Loan Data',
        'MCLNE': 'Multi-Channel Loan Network',
        'MCORG': 'Multi-Channel Originations',
        'MES': 'Manufacturing Execution Systems',
        'PLAQ': 'Platform Analytics Quality',
        'PLOS': 'Platform Operations Services',
        'TDC': 'Technology Data Center',
        'TOCA': 'Technology Operations Control'
    }
    return expansions

def generate_all_project_tables():
    """Generate tables for all projects"""
    df, all_projects, project_totals, connection_matrix = load_and_analyze_connections()
    expansions = generate_project_name_expansions()

    # Sort projects by total links (descending)
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)

    md_content = """# Complete Project Connection Tables - All 98 Projects
## Individual Project Perspectives (Unresolved Issues, 90-Day Activity)

Generated from project relationship data showing each project's perspective with connection tables matching the affinity diagram format.

### Summary Statistics
"""

    md_content += f"- **Total Projects Analyzed**: {len(all_projects)}\n"
    md_content += f"- **Total Relationship Records**: {len(df):,}\n"
    md_content += f"- **Total Link Count**: {df['LinkCount'].sum():,}\n"
    md_content += f"- **Average Links per Project**: {df['LinkCount'].sum() / len(all_projects):.1f}\n\n"

    md_content += "### Project Rankings by Total Links\n\n"
    md_content += "| Rank | Project Code | Project Name | Total Links | Direct Connections |\n"
    md_content += "|------|--------------|--------------|-------------|-------------------|\n"

    for rank, (project, total_links) in enumerate(sorted_projects[:20], 1):
        project_name = expansions.get(project, 'Unknown')
        direct_count = len([p for p in all_projects if connection_matrix[project][p] > 0])
        md_content += f"| {rank:2d} | **{project}** | {project_name} | {total_links:,} | {direct_count} |\n"

    md_content += "\n---\n\n"

    # Generate tables for all projects
    for project_code, total_links in sorted_projects:
        if total_links > 0:  # Only include projects with connections
            total_links, connections = analyze_project_perspective(project_code, df, all_projects, project_totals, connection_matrix)

            if connections:
                project_name = expansions.get(project_code, 'Unknown')
                md_content += f"## {project_code} ({project_name}) - {len(connections)} Direct Connections\n\n"

                md_content += f"**Total Links**: {total_links:,}\n\n"

                md_content += "| Source→Target | Network Connections | Direct Links | Total Links | Ring Classification |\n"
                md_content += "|---------------|---------------------|--------------|-------------|--------------------|\n"

                # Generate table rows
                for conn in connections:
                    target_name = expansions.get(conn['connected_project'], conn['connected_project'])
                    md_content += f"| {project_code}→{conn['connected_project']} | {conn['network_connections']} | {conn['direct_links']:,} | {conn['total_links']:,} | {conn['ring_classification']} |\n"

                # Add ring distribution summary
                ring_counts = defaultdict(int)
                for conn in connections:
                    ring_counts[conn['ring_classification']] += 1

                md_content += f"\n**Ring Distribution**: "
                md_content += f"Hub: {ring_counts['Hub Ring (6+ connections)']}, "
                md_content += f"High: {ring_counts['High Ring (4-5 connections)']}, "
                md_content += f"Medium: {ring_counts['Medium Ring (2-3 connections)']}, "
                md_content += f"Low: {ring_counts['Low Ring (1 connection)']}\n\n"

                # Add top connections summary
                if len(connections) > 0:
                    md_content += "**Top Connections**: "
                    top_3 = connections[:3]
                    top_descriptions = []
                    for conn in top_3:
                        if conn['direct_links'] >= 100:
                            top_descriptions.append(f"{conn['connected_project']} ({conn['direct_links']:,} links)")
                        else:
                            top_descriptions.append(f"{conn['connected_project']} ({conn['direct_links']} links)")
                    md_content += ", ".join(top_descriptions) + "\n\n"

                md_content += "---\n\n"

    md_content += f"\n## Analysis Notes\n\n"
    md_content += f"- **Network Connections**: Number of other projects this project connects to within the central project's network\n"
    md_content += f"- **Direct Links**: Actual Jira issue link count between the two projects\n"
    md_content += f"- **Total Links**: Sum of all links for the target project across the entire network\n"
    md_content += f"- **Ring Classification**: Hub (6+), High (4-5), Medium (2-3), Low (1) network connections\n\n"

    md_content += f"**Data Source**: Issue Links - GET Project to Project Links - Filtered Unresolved 90Day\n"
    md_content += f"**Generated**: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n"

    return md_content

def main():
    """Generate comprehensive project tables for all projects"""
    print("Generating tables for all projects...")

    md_content = generate_all_project_tables()

    output_file = 'ALL_PROJECT_CONNECTION_TABLES.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md_content)

    print(f"Complete project tables generated: {output_file}")
    print("Ready for heatmap generation!")

if __name__ == "__main__":
    main()