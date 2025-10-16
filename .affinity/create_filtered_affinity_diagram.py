#!/usr/bin/env python3
"""
Filtered Project Affinity Diagram Generator
Creates a visual representation of OMF Jira project relationships with filtering
"""

import pandas as pd
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

def load_project_data(csv_file):
    """Load and process the project relationship data"""
    df = pd.read_csv(csv_file)
    
    # Clean up the data
    df['LinkCount'] = pd.to_numeric(df['LinkCount'], errors='coerce').fillna(0)
    
    # Create project summary (group by ProjectKey and sum LinkCount)
    project_summary = df.groupby('ProjectKey')['LinkCount'].sum().reset_index()
    project_summary = project_summary.sort_values('LinkCount', ascending=False)
    
    print(f"Found {len(project_summary)} unique projects")
    print(f"Total links: {project_summary['LinkCount'].sum()}")
    
    return project_summary, df

def create_network_graph(project_summary, relationships_df):
    """Create a network graph from the project data"""
    G = nx.Graph()
    
    # Add nodes with attributes
    for _, row in project_summary.iterrows():
        project_key = row['ProjectKey']
        link_count = row['LinkCount']
        
        # Categorize projects by connectivity
        if link_count >= 100:
            size_category = 'Hub'
            color = '#FF6347'  # Red for hubs
        elif link_count >= 50:
            size_category = 'High'
            color = '#FF8C00'  # Orange for high connectivity
        elif link_count >= 20:
            size_category = 'Medium'
            color = '#4682B4'  # Blue for medium connectivity
        elif link_count >= 5:
            size_category = 'Low'
            color = '#90EE90'  # Light green for low connectivity
        else:
            size_category = 'Isolated'
            color = '#D3D3D3'  # Light gray for isolated projects
        
        G.add_node(project_key,
                  label=project_key,
                  link_count=link_count,
                  size_category=size_category,
                  color=color)
    
    # Add edges based on relationships
    for _, row in relationships_df.iterrows():
        source = row['ProjectKey']
        target = row['ConnectedProject']
        weight = row['LinkCount']
        
        if source in G.nodes() and target in G.nodes():
            G.add_edge(source, target, weight=weight)
    
    return G

def create_affinity_diagram(project_summary, relationships_df, output_file='project_affinity_diagram.png'):
    """Create the main affinity diagram"""
    
    G = create_network_graph(project_summary, relationships_df)
    
    # Create figure
    plt.figure(figsize=(20, 16))
    
    # Use spring layout for better positioning
    pos = nx.spring_layout(G, k=3, iterations=50, seed=42)
    
    # Draw nodes with different sizes and colors based on connectivity
    node_sizes = [G.nodes[node]['link_count'] * 3 + 100 for node in G.nodes()]
    node_colors = [G.nodes[node]['color'] for node in G.nodes()]
    
    nx.draw_networkx_nodes(G, pos, 
                          node_size=node_sizes,
                          node_color=node_colors,
                          alpha=0.8,
                          edgecolors='black',
                          linewidths=1)
    
    # Draw edges with varying thickness based on link count
    edges = G.edges()
    edge_weights = [G[u][v]['weight'] for u, v in edges]
    edge_widths = [min(w / 10, 5) for w in edge_weights]  # Normalize edge widths
    
    nx.draw_networkx_edges(G, pos,
                          width=edge_widths,
                          alpha=0.6,
                          edge_color='gray')
    
    # Draw labels
    nx.draw_networkx_labels(G, pos,
                           font_size=8,
                           font_weight='bold',
                           font_color='black')
    
    # Add title and legend
    plt.title('Project Affinity Diagram (Filtered Projects - Unresolved Issues, 90-Day Activity)', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', label='Hub (100+ links)',
                   markerfacecolor='#FF6347', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='High (50-99 links)',
                   markerfacecolor='#FF8C00', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Medium (20-49 links)',
                   markerfacecolor='#4682B4', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Low (5-19 links)',
                   markerfacecolor='#90EE90', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Isolated (<5 links)',
                   markerfacecolor='#D3D3D3', markersize=12)
    ]
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1))
    
    plt.axis('off')
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Project affinity diagram saved to {output_file}")
    
    return G

def create_connectivity_heatmap(relationships_df, output_file='connectivity_heatmap.png'):
    """Create a connectivity heatmap"""
    
    # Create a pivot table for the heatmap
    pivot_df = relationships_df.pivot_table(
        values='LinkCount', 
        index='ProjectKey', 
        columns='ConnectedProject', 
        fill_value=0
    )
    
    # Sort by total connectivity
    row_sums = pivot_df.sum(axis=1).sort_values(ascending=False)
    col_sums = pivot_df.sum(axis=0).sort_values(ascending=False)
    
    # Reorder the pivot table
    pivot_df = pivot_df.loc[row_sums.index, col_sums.index]
    
    # Create the heatmap
    plt.figure(figsize=(16, 12))
    sns.heatmap(pivot_df, 
                cmap='YlOrRd', 
                annot=False, 
                fmt='d',
                cbar_kws={'label': 'Number of Links'})
    
    plt.title('Project Connectivity Heatmap (Filtered Projects - Unresolved Issues, 90-Day Activity)', 
              fontsize=14, fontweight='bold')
    plt.xlabel('Connected Projects', fontsize=12)
    plt.ylabel('Source Projects', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Connectivity heatmap saved to {output_file}")

def create_connectivity_bar_chart(project_summary, output_file='connectivity_bar_chart.png'):
    """Create a bar chart of project connectivity"""
    
    # Get top 20 most connected projects
    top_projects = project_summary.head(20)
    
    plt.figure(figsize=(14, 8))
    bars = plt.bar(range(len(top_projects)), top_projects['LinkCount'], 
                   color='steelblue', alpha=0.7)
    
    plt.title('Top 20 Most Connected Projects (Filtered Projects - Unresolved Issues, 90-Day Activity)', 
              fontsize=14, fontweight='bold')
    plt.xlabel('Projects', fontsize=12)
    plt.ylabel('Total Links', fontsize=12)
    plt.xticks(range(len(top_projects)), top_projects['ProjectKey'], rotation=45, ha='right')
    
    # Add value labels on bars
    for i, bar in enumerate(bars):
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                f'{int(height)}', ha='center', va='bottom', fontsize=9)
    
    plt.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Connectivity bar chart saved to {output_file}")

def create_hub_analysis(project_summary, output_file='hub_analysis.png'):
    """Create a hub analysis visualization"""
    
    # Categorize projects
    hub_projects = project_summary[project_summary['LinkCount'] >= 100]
    high_projects = project_summary[(project_summary['LinkCount'] >= 50) & (project_summary['LinkCount'] < 100)]
    medium_projects = project_summary[(project_summary['LinkCount'] >= 20) & (project_summary['LinkCount'] < 50)]
    low_projects = project_summary[(project_summary['LinkCount'] >= 5) & (project_summary['LinkCount'] < 20)]
    isolated_projects = project_summary[project_summary['LinkCount'] < 5]
    
    # Create pie chart
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 8))
    
    # Pie chart of project categories
    categories = ['Hub (100+)', 'High (50-99)', 'Medium (20-49)', 'Low (5-19)', 'Isolated (<5)']
    sizes = [len(hub_projects), len(high_projects), len(medium_projects), len(low_projects), len(isolated_projects)]
    colors = ['#FF6347', '#FF8C00', '#4682B4', '#90EE90', '#D3D3D3']
    
    wedges, texts, autotexts = ax1.pie(sizes, labels=categories, colors=colors, autopct='%1.1f%%', startangle=90)
    ax1.set_title('Project Connectivity Distribution', fontsize=14, fontweight='bold')
    
    # Bar chart of top hubs
    if len(hub_projects) > 0:
        top_hubs = hub_projects.head(10)
        bars = ax2.bar(range(len(top_hubs)), top_hubs['LinkCount'], color='#FF6347', alpha=0.7)
        ax2.set_title('Top Hub Projects (100+ Links)', fontsize=14, fontweight='bold')
        ax2.set_xlabel('Projects', fontsize=12)
        ax2.set_ylabel('Total Links', fontsize=12)
        ax2.set_xticks(range(len(top_hubs)))
        ax2.set_xticklabels(top_hubs['ProjectKey'], rotation=45, ha='right')
        
        # Add value labels
        for i, bar in enumerate(bars):
            height = bar.get_height()
            ax2.text(bar.get_x() + bar.get_width()/2., height + height*0.01,
                    f'{int(height)}', ha='center', va='bottom', fontsize=9)
    else:
        ax2.text(0.5, 0.5, 'No Hub Projects Found\n(100+ links)', 
                ha='center', va='center', transform=ax2.transAxes, fontsize=12)
        ax2.set_title('Top Hub Projects', fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    print(f"Hub analysis saved to {output_file}")

def main():
    """Main function to generate all visualizations"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    project_summary, relationships_df = load_project_data(csv_file)
    
    print("Creating Project Affinity Diagram (Filtered Projects - Unresolved Issues, 90-Day Activity)...")
    G = create_affinity_diagram(project_summary, relationships_df, 'project_affinity_diagram_filtered_unresolved_90day.png')

    print("Creating Connectivity Heatmap...")
    create_connectivity_heatmap(relationships_df, 'connectivity_heatmap_filtered_unresolved_90day.png')

    print("Creating Connectivity Bar Chart...")
    create_connectivity_bar_chart(project_summary, 'connectivity_bar_chart_filtered_unresolved_90day.png')

    print("Creating Hub Analysis...")
    create_hub_analysis(project_summary, 'hub_analysis_filtered_unresolved_90day.png')

    # Print summary statistics
    print("\n" + "="*60)
    print("PROJECT AFFINITY ANALYSIS SUMMARY - FILTERED PROJECTS (UNRESOLVED ISSUES, 90-DAY ACTIVITY)")
    print("="*60)
    print(f"Total Projects: {len(project_summary)}")
    print(f"Total Connections: {project_summary['LinkCount'].sum()}")
    print(f"Average Connections per Project: {project_summary['LinkCount'].mean():.1f}")
    print(f"Most Connected Project: {project_summary.iloc[0]['ProjectKey']} ({project_summary.iloc[0]['LinkCount']} connections)")
    print(f"Projects with 0 connections: {len(project_summary[project_summary['LinkCount'] == 0])}")
    
    print("\nTop 10 Most Connected Projects:")
    for i, row in project_summary.head(10).iterrows():
        print(f"  {row['ProjectKey']}: {row['LinkCount']} total links")

if __name__ == "__main__":
    main()
