#!/usr/bin/env python3
"""
Extract All Project Connection Data
Creates a comprehensive matrix showing all project-to-project relationships
"""

import pandas as pd
import numpy as np
from collections import defaultdict

def load_and_analyze_connections():
    """Load the main CSV and create comprehensive connection matrix"""

    # Load the main data source
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

    # Create project totals (for each project, sum all its connections)
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

        # Store both directions for easier lookup
        connection_matrix[project1][project2] = links
        connection_matrix[project2][project1] = links

    return df, all_projects, project_totals, connection_matrix

def analyze_project_perspective(project, df, all_projects, project_totals, connection_matrix):
    """Analyze connections from a specific project's perspective"""

    if project not in project_totals:
        return None, []

    # Get direct connections to this project
    direct_connections = []
    for other_project in all_projects:
        if other_project != project and connection_matrix[project][other_project] > 0:
            link_count = connection_matrix[project][other_project]
            total_links = project_totals[other_project]

            # Calculate connections to other projects in this project's network
            # (This mimics the ring classification logic from the diagram scripts)
            network_connections = 0
            for third_project in all_projects:
                if (third_project != other_project and
                    third_project != project and
                    connection_matrix[other_project][third_project] > 0):
                    # Count connections to projects in this network
                    if connection_matrix[project][third_project] > 0:
                        network_connections += 1

            # Add connection to the central project itself
            network_connections += 1

            # Classify ring based on network connections
            if network_connections >= 6:
                ring = "Hub Ring (6+ connections)"
            elif network_connections >= 4:
                ring = "High Ring (4-5 connections)"
            elif network_connections >= 2:
                ring = "Medium Ring (2-3 connections)"
            else:
                ring = "Low Ring (1 connection)"

            direct_connections.append({
                'connected_project': other_project,
                'direct_links': link_count,
                'total_links': total_links,
                'network_connections': network_connections,
                'ring_classification': ring
            })

    # Sort by network connections (descending), then by direct links (descending)
    direct_connections.sort(key=lambda x: (x['network_connections'], x['direct_links']), reverse=True)

    return project_totals[project], direct_connections

def generate_markdown_report():
    """Generate comprehensive markdown report with all project perspectives"""

    df, all_projects, project_totals, connection_matrix = load_and_analyze_connections()

    # Start building the markdown content
    md_content = """# Complete Project Connection Matrix
## All Project Perspectives - Unresolved Issues (90-Day Activity)

This report shows connection data from each project's perspective, similar to the individual affinity diagrams.

### Summary Statistics
"""

    md_content += f"- **Total Projects**: {len(all_projects)}\n"
    md_content += f"- **Total Relationships**: {len(df):,}\n"
    md_content += f"- **Total Link Count**: {df['LinkCount'].sum():,}\n"
    md_content += f"- **Average Links per Project**: {df['LinkCount'].sum() / len(all_projects):.1f}\n\n"

    # Find top connected projects
    top_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)[:20]

    md_content += "### Top 20 Most Connected Projects (Total Links)\n\n"
    md_content += "| Rank | Project | Total Links | Direct Connections |\n"
    md_content += "|------|---------|-------------|-------------------|\n"

    for rank, (project, total_links) in enumerate(top_projects, 1):
        # Count direct connections
        direct_count = len([p for p in all_projects if connection_matrix[project][p] > 0])
        md_content += f"| {rank:2d} | **{project}** | {total_links:,} | {direct_count} |\n"

    md_content += "\n---\n\n"

    # Generate individual project sections for top projects
    md_content += "## Individual Project Perspectives\n\n"

    for project in [p[0] for p in top_projects[:10]]:  # Top 10 projects
        total_links, connections = analyze_project_perspective(project, df, all_projects, project_totals, connection_matrix)

        if connections:
            md_content += f"### {project} - {len(connections)} Direct Connections\n\n"
            md_content += f"**Total Links**: {total_links:,}\n\n"

            md_content += "| Connected Project | Direct Links | Total Links | Network Connections | Ring Classification |\n"
            md_content += "|------------------|--------------|-------------|-------------------|--------------------|\n"

            for conn in connections:
                md_content += f"| **{conn['connected_project']}** | {conn['direct_links']:,} | {conn['total_links']:,} | {conn['network_connections']} | {conn['ring_classification']} |\n"

            # Add ring summary
            ring_counts = defaultdict(int)
            for conn in connections:
                ring_counts[conn['ring_classification']] += 1

            md_content += f"\n**Ring Distribution**: "
            md_content += f"Hub: {ring_counts['Hub Ring (6+ connections)']}, "
            md_content += f"High: {ring_counts['High Ring (4-5 connections)']}, "
            md_content += f"Medium: {ring_counts['Medium Ring (2-3 connections)']}, "
            md_content += f"Low: {ring_counts['Low Ring (1 connection)']}\n\n"

            md_content += "---\n\n"

    # Add all projects summary table
    md_content += "## Complete Project Index\n\n"
    md_content += "| Project | Total Links | Direct Connections | Max Single Connection |\n"
    md_content += "|---------|-------------|-------------------|----------------------|\n"

    for project in sorted(all_projects):
        if project in project_totals:
            total_links = project_totals[project]
            direct_count = len([p for p in all_projects if connection_matrix[project][p] > 0])
            max_connection = max([connection_matrix[project][p] for p in all_projects], default=0)

            md_content += f"| {project} | {total_links:,} | {direct_count} | {max_connection:,} |\n"

    md_content += f"\n---\n*Generated from: 90-day unresolved issue links*\n"
    md_content += f"*Analysis Date: {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M')}*\n"

    return md_content

def main():
    """Generate the complete project connection matrix report"""
    print("Analyzing project connections...")

    md_content = generate_markdown_report()

    # Save the report
    output_file = 'COMPLETE_PROJECT_CONNECTION_MATRIX.md'
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(md_content)

    print(f"Report generated: {output_file}")
    print("Analysis complete!")

if __name__ == "__main__":
    main()