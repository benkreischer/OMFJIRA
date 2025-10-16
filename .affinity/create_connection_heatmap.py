#!/usr/bin/env python3
"""
Create Project Connection Heatmap
Generates interactive and static heatmap visualizations of project relationships
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from collections import defaultdict
import warnings
warnings.filterwarnings('ignore')

def load_and_process_data():
    """Load and process the connection data for heatmap creation"""
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = pd.read_csv(csv_file)

    print(f"Processing {len(df)} relationship records...")

    # Get all unique projects
    all_projects = set()
    for _, row in df.iterrows():
        all_projects.add(row['ProjectKey'])
        all_projects.add(row['ConnectedProject'])

    all_projects = sorted(list(all_projects))
    print(f"Found {len(all_projects)} unique projects")

    # Create connection matrix
    connection_matrix = pd.DataFrame(0, index=all_projects, columns=all_projects)

    for _, row in df.iterrows():
        source = row['ProjectKey']
        target = row['ConnectedProject']
        links = row['LinkCount']

        # Fill both directions for symmetric matrix
        connection_matrix.loc[source, target] = links
        connection_matrix.loc[target, source] = links

    # Calculate project totals for sorting
    project_totals = {}
    for project in all_projects:
        project_totals[project] = connection_matrix.loc[project].sum()

    # Sort projects by total connections (descending)
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    sorted_project_names = [p[0] for p in sorted_projects]

    # Reorder matrix by connectivity
    sorted_matrix = connection_matrix.reindex(index=sorted_project_names, columns=sorted_project_names)

    return sorted_matrix, project_totals, sorted_projects

def create_full_heatmap(matrix, project_totals, output_file='project_connection_heatmap_full.png'):
    """Create full heatmap with all projects"""

    # Set up the plot
    plt.figure(figsize=(24, 20))

    # Create custom colormap - log scale for better visibility
    # Use log transform to handle wide range of values
    log_matrix = np.log1p(matrix)  # log1p handles zeros

    # Create heatmap
    ax = sns.heatmap(log_matrix,
                     cmap='YlOrRd',
                     cbar_kws={'label': 'Log(Links + 1)'},
                     square=True,
                     linewidths=0.1,
                     linecolor='white')

    # Customize appearance
    plt.title('OMF Project Connection Heatmap (All 98 Projects)\nLog Scale - Unresolved Issues (90-Day Activity)',
              fontsize=16, fontweight='bold', pad=20)

    # Rotate labels for better readability
    plt.xticks(rotation=45, ha='right', fontsize=8)
    plt.yticks(rotation=0, fontsize=8)

    # Add grid
    ax.set_xlabel('Target Projects', fontsize=12, fontweight='bold')
    ax.set_ylabel('Source Projects', fontsize=12, fontweight='bold')

    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"Full heatmap saved: {output_file}")
    plt.close()

def create_top_projects_heatmap(matrix, project_totals, top_n=30, output_file='project_connection_heatmap_top30.png'):
    """Create focused heatmap with top N connected projects"""

    # Get top N projects
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    top_projects = [p[0] for p in sorted_projects[:top_n]]

    # Create subset matrix
    subset_matrix = matrix.loc[top_projects, top_projects]

    # Set up the plot
    plt.figure(figsize=(16, 14))

    # Create custom annotation - show actual values for subset
    # Use log transform but show original values in annotations
    log_matrix = np.log1p(subset_matrix)

    # Create annotations for non-zero values
    annot_matrix = subset_matrix.copy()
    annot_matrix = annot_matrix.astype(str)
    annot_matrix[subset_matrix == 0] = ''

    # For very large numbers, use abbreviated format
    for i in range(len(subset_matrix)):
        for j in range(len(subset_matrix.columns)):
            val = subset_matrix.iloc[i, j]
            if val >= 1000:
                annot_matrix.iloc[i, j] = f'{val/1000:.1f}k'
            elif val > 0:
                annot_matrix.iloc[i, j] = str(int(val))

    # Create heatmap with annotations
    ax = sns.heatmap(log_matrix,
                     annot=annot_matrix,
                     fmt='',
                     cmap='YlOrRd',
                     cbar_kws={'label': 'Log(Links + 1)'},
                     square=True,
                     linewidths=0.5,
                     linecolor='white',
                     annot_kws={'size': 8})

    # Customize appearance
    plt.title(f'OMF Project Connection Heatmap (Top {top_n} Projects)\nActual Values Shown - Log Color Scale',
              fontsize=14, fontweight='bold', pad=20)

    # Rotate labels for better readability
    plt.xticks(rotation=45, ha='right', fontsize=10)
    plt.yticks(rotation=0, fontsize=10)

    ax.set_xlabel('Target Projects', fontsize=12, fontweight='bold')
    ax.set_ylabel('Source Projects', fontsize=12, fontweight='bold')

    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"Top {top_n} heatmap saved: {output_file}")
    plt.close()

def create_mega_connections_heatmap(matrix, project_totals, output_file='project_connection_heatmap_mega.png'):
    """Create heatmap focusing on mega-connections (100+ links)"""

    # Find projects with connections >= 100
    mega_projects = set()
    for i in range(len(matrix)):
        for j in range(len(matrix.columns)):
            if matrix.iloc[i, j] >= 100:
                mega_projects.add(matrix.index[i])
                mega_projects.add(matrix.columns[j])

    mega_projects = sorted(list(mega_projects))
    print(f"Found {len(mega_projects)} projects with mega-connections (100+ links)")

    if len(mega_projects) > 0:
        # Create subset matrix
        mega_matrix = matrix.loc[mega_projects, mega_projects]

        # Set up the plot
        plt.figure(figsize=(12, 10))

        # Use original values for mega connections
        # Create annotations
        annot_matrix = mega_matrix.copy()
        annot_matrix = annot_matrix.astype(str)
        annot_matrix[mega_matrix == 0] = ''

        # Format large numbers
        for i in range(len(mega_matrix)):
            for j in range(len(mega_matrix.columns)):
                val = mega_matrix.iloc[i, j]
                if val >= 1000:
                    annot_matrix.iloc[i, j] = f'{val/1000:.1f}k'
                elif val >= 100:
                    annot_matrix.iloc[i, j] = str(int(val))
                elif val > 0:
                    annot_matrix.iloc[i, j] = str(int(val))

        # Create heatmap
        ax = sns.heatmap(mega_matrix,
                         annot=annot_matrix,
                         fmt='',
                         cmap='Reds',
                         cbar_kws={'label': 'Connection Count'},
                         square=True,
                         linewidths=1,
                         linecolor='white',
                         annot_kws={'size': 10, 'weight': 'bold'})

        plt.title('OMF Mega-Connections Heatmap (100+ Links)\nActual Values - Linear Scale',
                  fontsize=14, fontweight='bold', pad=20)

        plt.xticks(rotation=45, ha='right', fontsize=12)
        plt.yticks(rotation=0, fontsize=12)

        ax.set_xlabel('Target Projects', fontsize=12, fontweight='bold')
        ax.set_ylabel('Source Projects', fontsize=12, fontweight='bold')

        plt.tight_layout()
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
        print(f"Mega-connections heatmap saved: {output_file}")
        plt.close()

def create_summary_stats(matrix, project_totals):
    """Create summary statistics visualization"""

    plt.figure(figsize=(16, 12))

    # Create 2x2 subplot layout
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))

    # 1. Top 20 projects by total connections
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    top_20 = sorted_projects[:20]

    projects, totals = zip(*top_20)
    ax1.barh(range(len(projects)), totals, color='skyblue')
    ax1.set_yticks(range(len(projects)))
    ax1.set_yticklabels(projects)
    ax1.set_xlabel('Total Links')
    ax1.set_title('Top 20 Projects by Total Links')
    ax1.invert_yaxis()

    # 2. Distribution of connection counts
    all_values = matrix.values.flatten()
    non_zero_values = all_values[all_values > 0]

    ax2.hist(non_zero_values, bins=50, alpha=0.7, color='lightcoral', edgecolor='black')
    ax2.set_xlabel('Connection Count')
    ax2.set_ylabel('Frequency')
    ax2.set_title('Distribution of Non-Zero Connections')
    ax2.set_yscale('log')

    # 3. Mega connections breakdown
    mega_counts = []
    mega_labels = []

    for threshold in [1000, 500, 250, 100, 50]:
        count = np.sum(all_values >= threshold)
        mega_counts.append(count)
        mega_labels.append(f'{threshold}+')

    ax3.bar(mega_labels, mega_counts, color='orange', alpha=0.7)
    ax3.set_xlabel('Connection Threshold')
    ax3.set_ylabel('Number of Connections')
    ax3.set_title('High-Volume Connections by Threshold')

    # 4. Connection density by project
    connection_counts = [np.sum(matrix.loc[proj] > 0) for proj in projects[:20]]

    ax4.barh(range(len(projects[:20])), connection_counts, color='lightgreen')
    ax4.set_yticks(range(len(projects[:20])))
    ax4.set_yticklabels(projects[:20])
    ax4.set_xlabel('Number of Direct Connections')
    ax4.set_title('Connection Density (Top 20 Projects)')
    ax4.invert_yaxis()

    plt.suptitle('OMF Project Network Analysis - Summary Statistics', fontsize=16, fontweight='bold')
    plt.tight_layout()
    plt.savefig('project_network_summary_stats.png', dpi=300, bbox_inches='tight', facecolor='white')
    print("Summary statistics saved: project_network_summary_stats.png")
    plt.close()

def main():
    """Generate all heatmap visualizations"""
    print("Creating project connection heatmaps...")

    # Load and process data
    matrix, project_totals, sorted_projects = load_and_process_data()

    print(f"Matrix shape: {matrix.shape}")
    print(f"Non-zero connections: {np.sum(matrix.values > 0):,}")
    print(f"Max connection: {matrix.values.max():,}")

    # Create different heatmap views
    create_full_heatmap(matrix, project_totals)
    create_top_projects_heatmap(matrix, project_totals, top_n=30)
    create_mega_connections_heatmap(matrix, project_totals)
    create_summary_stats(matrix, project_totals)

    # Print key insights
    print("\n" + "="*60)
    print("HEATMAP GENERATION COMPLETE")
    print("="*60)

    print(f"Generated 4 visualization files:")
    print("1. project_connection_heatmap_full.png - All 98 projects")
    print("2. project_connection_heatmap_top30.png - Top 30 projects with values")
    print("3. project_connection_heatmap_mega.png - Mega-connections (100+ links)")
    print("4. project_network_summary_stats.png - Statistical analysis")

    # Show top connections
    print(f"\nTop 10 Individual Connections:")
    all_connections = []
    for i in range(len(matrix)):
        for j in range(i+1, len(matrix.columns)):  # Avoid duplicates
            val = matrix.iloc[i, j]
            if val > 0:
                all_connections.append((matrix.index[i], matrix.columns[j], val))

    all_connections.sort(key=lambda x: x[2], reverse=True)

    for i, (proj1, proj2, links) in enumerate(all_connections[:10], 1):
        print(f"{i:2d}. {proj1} ↔ {proj2}: {links:,} links")

if __name__ == "__main__":
    main()