#!/usr/bin/env python3
"""
Project Affinity Diagram Generator
Creates a visual representation of OMF Jira project relationships
"""

import pandas as pd
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
from collections import defaultdict
import seaborn as sns
from matplotlib.patches import Circle
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
    
    return project_summary

def create_network_graph(df):
    """Create a network graph from the project data"""
    G = nx.Graph()
    
    # Add nodes with attributes
    for _, row in df.iterrows():
        project = row['ProjectKey']
        link_count = row['LinkCount']
        
        # Determine node size based on connectivity
        if link_count >= 30:
            size_category = 'Hub'
            color = '#FF6B6B'  # Red for hubs
        elif link_count >= 20:
            size_category = 'High'
            color = '#4ECDC4'  # Teal for high connectivity
        elif link_count >= 10:
            size_category = 'Medium'
            color = '#45B7D1'  # Blue for medium connectivity
        elif link_count > 0:
            size_category = 'Low'
            color = '#96CEB4'  # Green for low connectivity
        else:
            size_category = 'Isolated'
            color = '#D3D3D3'  # Gray for isolated
            
        G.add_node(project, 
                  link_count=link_count,
                  size_category=size_category,
                  color=color)
    
    # Add edges based on relationships
    for _, row in df.iterrows():
        source = row['ProjectKey']
        linked_projects = row['LinkedProjectKeys']
        
        if linked_projects and linked_projects != '':
            linked_list = [p.strip() for p in linked_projects.split(';') if p.strip()]
            for target in linked_list:
                if target in G.nodes():
                    G.add_edge(source, target)
    
    return G

def create_affinity_diagram(df, output_file='project_affinity_diagram.png'):
    """Create the main affinity diagram"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot
    plt.figure(figsize=(20, 16))
    
    # Get hub projects (30+ connections) for special positioning
    hub_projects = [n for n, d in G.nodes(data=True) if d['link_count'] >= 30]
    
    # Use spring layout with hub projects positioned in center
    pos = nx.spring_layout(G, k=3, iterations=100, seed=42)
    
    # Adjust positions to put hubs in center
    if hub_projects:
        # Get center coordinates
        center_x = sum(pos[node][0] for node in pos) / len(pos)
        center_y = sum(pos[node][1] for node in pos) / len(pos)
        
        # Move hub projects closer to center
        for hub in hub_projects:
            pos[hub] = (center_x + (pos[hub][0] - center_x) * 0.3, 
                       center_y + (pos[hub][1] - center_y) * 0.3)
    
    # Separate nodes by connectivity level
    hub_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Hub']
    high_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'High']
    medium_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Medium']
    low_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Low']
    isolated_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Isolated']
    
    # Draw edges with different colors for hub connections vs others
    hub_edges = []
    other_edges = []
    
    for edge in G.edges():
        source, target = edge
        if source in hub_projects or target in hub_projects:
            hub_edges.append(edge)
        else:
            other_edges.append(edge)
    
    # Draw other edges first (very light gray)
    if other_edges:
        nx.draw_networkx_edges(G, pos, edgelist=other_edges, alpha=0.1, width=0.3, edge_color='lightgray')
    
    # Draw hub edges (darker gray)
    if hub_edges:
        nx.draw_networkx_edges(G, pos, edgelist=hub_edges, alpha=0.6, width=1.0, edge_color='gray')
    
    # Draw nodes by category with different sizes - make hubs much bigger
    node_sizes = {}
    for n, d in G.nodes(data=True):
        if d['size_category'] == 'Hub':
            # Make hub nodes much larger
            node_sizes[n] = max(800, min(2000, d['link_count'] * 25))
        else:
            node_sizes[n] = max(50, min(500, d['link_count'] * 15))
    
    # Draw isolated nodes (small, gray)
    if isolated_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=isolated_nodes, 
                              node_color='#D3D3D3', node_size=50, alpha=0.6)
    
    # Draw low connectivity nodes
    if low_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes, 
                              node_color='#96CEB4', node_size=[node_sizes[n] for n in low_nodes], alpha=0.7)
    
    # Draw medium connectivity nodes
    if medium_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes, 
                              node_color='#45B7D1', node_size=[node_sizes[n] for n in medium_nodes], alpha=0.8)
    
    # Draw high connectivity nodes
    if high_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes, 
                              node_color='#4ECDC4', node_size=[node_sizes[n] for n in high_nodes], alpha=0.9)
    
    # Draw hub nodes (largest, most prominent)
    if hub_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes, 
                              node_color='#FF6B6B', node_size=[node_sizes[n] for n in hub_nodes], alpha=1.0)
    
    # Add labels for hub and high connectivity nodes only
    important_nodes = hub_nodes + high_nodes
    labels = {node: node for node in important_nodes}
    nx.draw_networkx_labels(G, pos, labels, font_size=8, font_weight='bold')
    
    # Add title and legend
    plt.title('OMF Jira Project Affinity Diagram\nUnresolved Issues Only (No ORL) - Project Relationships and Connectivity', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.scatter([], [], c='#FF6B6B', s=200, label='Hub Projects (30+ links)', alpha=1.0),
        plt.scatter([], [], c='#4ECDC4', s=150, label='High Connectivity (20-29 links)', alpha=0.9),
        plt.scatter([], [], c='#45B7D1', s=100, label='Medium Connectivity (10-19 links)', alpha=0.8),
        plt.scatter([], [], c='#96CEB4', s=75, label='Low Connectivity (1-9 links)', alpha=0.7),
        plt.scatter([], [], c='#D3D3D3', s=50, label='Isolated Projects (0 links)', alpha=0.6)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), fontsize=10)
    
    # Add statistics text
    stats_text = f"""
    Total Projects: {len(G.nodes())}
    Hub Projects: {len(hub_nodes)}
    High Connectivity: {len(high_nodes)}
    Medium Connectivity: {len(medium_nodes)}
    Low Connectivity: {len(low_nodes)}
    Isolated Projects: {len(isolated_nodes)}
    Total Connections: {len(G.edges())}
    """
    
    plt.figtext(0.02, 0.02, stats_text, fontsize=10, 
                bbox=dict(boxstyle="round,pad=0.3", facecolor="lightgray", alpha=0.8))
    
    plt.axis('off')
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.show()
    
    return G

def create_connectivity_heatmap(df, output_file='connectivity_heatmap.png'):
    """Create a heatmap showing project connectivity patterns"""
    
    # Get top 20 most connected projects
    top_projects = df.nlargest(20, 'LinkCount')
    
    # Create a matrix of relationships
    project_list = top_projects['ProjectKey'].tolist()
    matrix = np.zeros((len(project_list), len(project_list)))
    
    for i, row in top_projects.iterrows():
        source = row['ProjectKey']
        linked_projects = row['LinkedProjectKeys']
        
        if linked_projects and linked_projects != '':
            linked_list = [p.strip() for p in linked_projects.split(';') if p.strip()]
            for target in linked_list:
                if target in project_list:
                    source_idx = project_list.index(source)
                    target_idx = project_list.index(target)
                    matrix[source_idx][target_idx] = 1
    
    # Create heatmap
    plt.figure(figsize=(15, 12))
    sns.heatmap(matrix, 
                xticklabels=project_list, 
                yticklabels=project_list,
                cmap='YlOrRd',
                cbar_kws={'label': 'Connection Strength'},
                square=True)
    
    plt.title('Project Connectivity Heatmap\nTop 20 Most Connected Projects', 
              fontsize=14, fontweight='bold')
    plt.xlabel('Target Projects', fontsize=12)
    plt.ylabel('Source Projects', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.show()

def create_connectivity_bar_chart(df, output_file='connectivity_bar_chart.png'):
    """Create a bar chart showing project connectivity levels"""
    
    # Categorize projects by connectivity
    def categorize_connectivity(link_count):
        if link_count >= 30:
            return 'Hub (30+)'
        elif link_count >= 20:
            return 'High (20-29)'
        elif link_count >= 10:
            return 'Medium (10-19)'
        elif link_count > 0:
            return 'Low (1-9)'
        else:
            return 'Isolated (0)'
    
    df['ConnectivityCategory'] = df['LinkCount'].apply(categorize_connectivity)
    
    # Create bar chart
    plt.figure(figsize=(12, 8))
    category_counts = df['ConnectivityCategory'].value_counts()
    
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#D3D3D3']
    bars = plt.bar(category_counts.index, category_counts.values, color=colors)
    
    # Add value labels on bars
    for bar in bars:
        height = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                f'{int(height)}', ha='center', va='bottom', fontweight='bold')
    
    plt.title('Project Connectivity Distribution', fontsize=16, fontweight='bold')
    plt.xlabel('Connectivity Level', fontsize=12)
    plt.ylabel('Number of Projects', fontsize=12)
    plt.xticks(rotation=45, ha='right')
    plt.grid(axis='y', alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.show()

def create_hub_analysis(df, output_file='hub_analysis.png'):
    """Create a detailed analysis of hub projects"""
    
    # Get top 10 hub projects
    top_hubs = df.nlargest(10, 'LinkCount')
    
    # Create subplot
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(20, 8))
    
    # Bar chart of hub projects
    bars = ax1.barh(top_hubs['ProjectKey'], top_hubs['LinkCount'], 
                    color=['#FF6B6B', '#FF8E8E', '#FFA8A8', '#FFC2C2', '#FFDCDC',
                           '#FFE6E6', '#FFF0F0', '#FFFAFA', '#FFFFFF', '#F0F0F0'])
    
    ax1.set_xlabel('Number of Connections', fontsize=12)
    ax1.set_ylabel('Project Key', fontsize=12)
    ax1.set_title('Top 10 Hub Projects by Connection Count', fontsize=14, fontweight='bold')
    
    # Add value labels
    for i, bar in enumerate(bars):
        width = bar.get_width()
        ax1.text(width + 0.5, bar.get_y() + bar.get_height()/2, 
                f'{int(width)}', ha='left', va='center', fontweight='bold')
    
    # Pie chart of connectivity distribution
    connectivity_counts = df['LinkCount'].apply(lambda x: 
        'Hub (30+)' if x >= 30 else
        'High (20-29)' if x >= 20 else
        'Medium (10-19)' if x >= 10 else
        'Low (1-9)' if x > 0 else 'Isolated (0)'
    ).value_counts()
    
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#D3D3D3']
    wedges, texts, autotexts = ax2.pie(connectivity_counts.values, 
                                      labels=connectivity_counts.index,
                                      colors=colors[:len(connectivity_counts)],
                                      autopct='%1.1f%%',
                                      startangle=90)
    
    ax2.set_title('Project Connectivity Distribution', fontsize=14, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.show()

def main():
    """Main function to generate all visualizations"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = load_project_data(csv_file)
    
    print("Creating Project Affinity Diagram (Filtered Projects - Unresolved Issues, 90-Day Activity)...")
    G = create_affinity_diagram(df, 'project_affinity_diagram_filtered_unresolved_90day.png')

    print("Creating Connectivity Heatmap...")
    create_connectivity_heatmap(df, 'connectivity_heatmap_filtered_unresolved_90day.png')

    print("Creating Connectivity Bar Chart...")
    create_connectivity_bar_chart(df, 'connectivity_bar_chart_filtered_unresolved_90day.png')

    print("Creating Hub Analysis...")
    create_hub_analysis(df, 'hub_analysis_filtered_unresolved_90day.png')

    # Print summary statistics
    print("\n" + "="*60)
    print("PROJECT AFFINITY ANALYSIS SUMMARY - FILTERED PROJECTS (UNRESOLVED ISSUES, 90-DAY ACTIVITY)")
    print("="*60)
    print(f"Total Projects: {len(df)}")
    print(f"Total Connections: {df['LinkCount'].sum()}")
    print(f"Average Connections per Project: {df['LinkCount'].mean():.1f}")
    print(f"Most Connected Project: {df.loc[df['LinkCount'].idxmax(), 'ProjectKey']} ({df['LinkCount'].max()} connections)")
    print(f"Projects with 0 connections: {len(df[df['LinkCount'] == 0])}")
    print(f"Projects with 30+ connections: {len(df[df['LinkCount'] >= 30])}")
    
    print("\nTop 10 Hub Projects:")
    top_10 = df.nlargest(10, 'LinkCount')
    for i, (_, row) in enumerate(top_10.iterrows(), 1):
        print(f"{i:2d}. {row['ProjectKey']:8s} - {row['LinkCount']:2d} connections")

if __name__ == "__main__":
    main()
