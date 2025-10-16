#!/usr/bin/env python3
"""
INI-Centered Project Affinity Diagram Generator
Creates a visual representation of OMF Jira project relationships centered on INI
(Since ORL is excluded, INI is now the most connected project)
"""

import pandas as pd
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import warnings
warnings.filterwarnings('ignore')

def load_project_data(csv_file):
    """Load and process the project relationship data"""
    df = pd.read_csv(csv_file)
    
    # Clean up the data
    df['LinkedProjectKeys'] = df['LinkedProjectKeys'].fillna('')
    df['LinkCount'] = df['LinkCount'].fillna(0)
    
    return df

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

def create_ini_centered_diagram(df, output_file='project_affinity_diagram.png'):
    """Create an INI-centered affinity diagram showing only high and medium connections"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot
    plt.figure(figsize=(24, 20))
    
    # Check if INI exists in the graph
    if 'INI' not in G.nodes():
        print("Warning: INI project not found in data.")
        return None
    
    # Get INI's direct connections
    ini_connections = list(G.neighbors('INI'))
    print(f"INI has {len(ini_connections)} direct connections")
    
    # Get projects by connectivity level
    hub_projects = [n for n, d in G.nodes(data=True) if d['link_count'] >= 30]
    high_projects = [n for n, d in G.nodes(data=True) if 20 <= d['link_count'] < 30]
    medium_projects = [n for n, d in G.nodes(data=True) if 10 <= d['link_count'] < 20]
    
    # Get INI's connections by layer (only high and medium)
    ini_hub_connections = [conn for conn in ini_connections if conn in hub_projects]
    ini_high_connections = [conn for conn in ini_connections if conn in high_projects]
    ini_medium_connections = [conn for conn in ini_connections if conn in medium_projects]
    
    # Filter to only show hub, high and medium connections
    ini_filtered_connections = ini_hub_connections + ini_high_connections + ini_medium_connections
    print(f"INI filtered connections (hub+high+medium): {len(ini_filtered_connections)}")
    print(f"INI hub connections: {len(ini_hub_connections)}")
    print(f"INI high connections: {len(ini_high_connections)}")
    print(f"INI medium connections: {len(ini_medium_connections)}")
    
    # Create INI-centered radial layout
    pos = {}
    
    # INI at the center
    pos['INI'] = (0, 0)
    
    # Place INI's hub connections in inner ring
    if ini_hub_connections:
        hub_angle_step = 2 * np.pi / len(ini_hub_connections)
        hub_radius = 0.4
        for i, hub in enumerate(ini_hub_connections):
            angle = i * hub_angle_step
            pos[hub] = (hub_radius * np.cos(angle), hub_radius * np.sin(angle))
    
    # Place INI's high connections in second ring
    if ini_high_connections:
        high_angle_step = 2 * np.pi / len(ini_high_connections)
        high_radius = 0.7
        for i, project in enumerate(ini_high_connections):
            angle = i * high_angle_step
            pos[project] = (high_radius * np.cos(angle), high_radius * np.sin(angle))
    
    # Place INI's medium connections in third ring
    if ini_medium_connections:
        medium_angle_step = 2 * np.pi / len(ini_medium_connections)
        medium_radius = 1.0
        for i, project in enumerate(ini_medium_connections):
            angle = i * medium_angle_step
            pos[project] = (medium_radius * np.cos(angle), medium_radius * np.sin(angle))
    
    # Only show projects directly connected to INI - no other projects
    
    # Separate nodes by connectivity level (only show hub, high, and medium)
    hub_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Hub' and n in pos]
    high_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'High' and n in pos]
    medium_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Medium' and n in pos]
    
    # Categorize edges - only show INI connections and connections between INI's direct connections
    ini_edges = []           # All edges connected to INI (thickest, most prominent)
    hub_to_hub = []          # Hub to Hub (2nd thinnest solid gray)
    high_to_high = []        # High to High only (thinnest solid gray)
    high_to_medium = []      # High to Medium (thinnest solid gray)
    medium_to_medium = []    # Medium to Medium only (thinnest dashed gray)
    
    # Only include nodes that are directly connected to INI (plus INI itself)
    ini_network_nodes = set(['INI'] + ini_filtered_connections)
    
    for edge in G.edges():
        source, target = edge
        
        # Only include edges where both nodes are in INI's direct network
        if source not in ini_network_nodes or target not in ini_network_nodes:
            continue
        
        # Skip edges where nodes are not in our position dictionary
        if source not in pos or target not in pos:
            continue
        
        # Check if edge involves INI
        if source == 'INI' or target == 'INI':
            ini_edges.append(edge)
            continue
        
        # Determine layer categories for connections between INI's direct connections
        source_is_hub = source in hub_projects
        source_is_high = source in high_projects
        source_is_medium = source in medium_projects
        
        target_is_hub = target in hub_projects
        target_is_high = target in high_projects
        target_is_medium = target in medium_projects
        
        # Categorize edges between INI's direct connections
        if source_is_hub or target_is_hub:
            if source_is_hub and target_is_hub:
                hub_to_hub.append(edge)
        elif source_is_high or target_is_high:
            if source_is_high and target_is_high:
                high_to_high.append(edge)
            elif source_is_high and target_is_medium:
                high_to_medium.append(edge)
            elif target_is_high and source_is_medium:
                high_to_medium.append(edge)
        elif source_is_medium and target_is_medium:
            medium_to_medium.append(edge)
    
    # Draw edges in order (outer to inner for proper layering)
    
    # Draw medium to medium connections (thinnest dashed gray)
    if medium_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_medium, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to medium connections (thinnest solid gray)
    if high_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_medium, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw high to high connections (thinnest solid gray)
    if high_to_high:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_high, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw hub to hub connections (2nd thinnest solid gray)
    if hub_to_hub:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_hub, alpha=0.7, width=0.8, 
                              edge_color='darkgray', style='solid')
    
    # Draw INI connections last (thickest, most prominent)
    if ini_edges:
        nx.draw_networkx_edges(G, pos, edgelist=ini_edges, alpha=1.0, width=2.0, 
                              edge_color='#FF4444', style='solid')
    
    # Draw nodes by category with different sizes - make hubs much bigger
    node_sizes = {}
    for n, d in G.nodes(data=True):
        if d['size_category'] == 'Hub':
            # Make hub nodes much larger
            node_sizes[n] = max(800, min(2000, d['link_count'] * 25))
        else:
            node_sizes[n] = max(50, min(500, d['link_count'] * 15))
    
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
    
    # Draw labels with different sizes based on layer
    # Hub labels (largest)
    hub_labels = {node: node for node in hub_nodes}
    if hub_labels:
        nx.draw_networkx_labels(G, pos, hub_labels, font_size=10, font_weight='bold', font_color='white')
    
    # High connectivity labels
    high_labels = {node: node for node in high_nodes}
    if high_labels:
        nx.draw_networkx_labels(G, pos, high_labels, font_size=9, font_weight='bold', font_color='white')
    
    # Medium connectivity labels
    medium_labels = {node: node for node in medium_nodes}
    if medium_labels:
        nx.draw_networkx_labels(G, pos, medium_labels, font_size=8, font_weight='normal', font_color='black')
    
    # Add title and legend
    plt.title('OMF Jira Project Affinity Diagram\nINI-Centered Radial Layout - Unresolved Issues Only (No ORL)', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.scatter([], [], c='#FF6B6B', s=200, label='Hub Ring (30+ links)', alpha=1.0),
        plt.scatter([], [], c='#4ECDC4', s=150, label='High Ring (20-29 links)', alpha=0.9),
        plt.scatter([], [], c='#45B7D1', s=100, label='Medium Ring (10-19 links)', alpha=0.8)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), fontsize=10)
    
    # Add statistics text
    stats_text = f"""
    Total Projects Shown: {len(pos)}
    INI Direct Connections: {len(ini_filtered_connections)}
    Hub Projects: {len(hub_nodes)}
    High Projects: {len(high_nodes)}
    Medium Projects: {len(medium_nodes)}
    Total Connections Shown: {len(ini_edges) + len(hub_to_hub) + len(high_to_high) + len(high_to_medium) + len(medium_to_medium)}
    """
    
    plt.figtext(0.02, 0.02, stats_text, fontsize=10, 
                bbox=dict(boxstyle="round,pad=0.3", facecolor="lightgray", alpha=0.8))
    
    plt.axis('off')
    plt.tight_layout()
    
    # Save with different method to avoid the error
    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except:
        # Fallback save method
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
    
    plt.show()
    
    return G

def main():
    """Main function to generate the INI-centered affinity diagram"""
    
    # Load data
    csv_file = '../.endpoints/Issue links/Issue Links - GET Project to Project Links - Filtered - Unresolved Only - No ORL - Anon - Official.csv'
    df = load_project_data(csv_file)

    print("Creating INI-Centered Project Affinity Diagram (Filtered Projects - Unresolved Issues Only, No ORL)...")
    G = create_ini_centered_diagram(df, 'project_affinity_diagram_ini_centered_filtered_unresolved_no_orl.png')
    
    if G is not None:
        # Print summary statistics
        print("\n" + "="*60)
        print("INI-CENTERED PROJECT AFFINITY ANALYSIS SUMMARY - FILTERED PROJECTS (UNRESOLVED ISSUES ONLY, NO ORL)")
        print("="*60)
        print(f"Total Projects in Dataset: {len(df)}")
        print(f"INI Total Connections: {len(list(G.neighbors('INI')))}")
        print(f"INI Hub Connections: {len([n for n in G.neighbors('INI') if G.nodes[n]['link_count'] >= 30])}")
        print(f"INI High Connections: {len([n for n in G.neighbors('INI') if 20 <= G.nodes[n]['link_count'] < 30])}")
        print(f"INI Medium Connections: {len([n for n in G.neighbors('INI') if 10 <= G.nodes[n]['link_count'] < 20])}")
        print(f"INI Low Connections: {len([n for n in G.neighbors('INI') if 0 < G.nodes[n]['link_count'] < 10])}")
        print(f"INI Isolated Connections: {len([n for n in G.neighbors('INI') if G.nodes[n]['link_count'] == 0])}")
        
        print("\nINI's Top Connected Projects (Hub & High):")
        ini_neighbors = [(n, G.nodes[n]['link_count']) for n in G.neighbors('INI')]
        ini_neighbors.sort(key=lambda x: x[1], reverse=True)
        for i, (project, count) in enumerate(ini_neighbors[:15], 1):
            if G.nodes[project]['link_count'] >= 10:  # Only show hub and high connections
                print(f"{i:2d}. {project:8s} - {count:2d} total connections")

if __name__ == "__main__":
    main()
