#!/usr/bin/env python3
"""
Simple Project Affinity Diagram Generator
Creates a visual representation of OMF Jira project relationships
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
    
    return G

def create_orl_centered_diagram(df, output_file='project_affinity_diagram.png'):
    """Create an ORL-centered affinity diagram showing all its relationships"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot
    plt.figure(figsize=(24, 20))
    
    # Check if ORL exists in the graph
    if 'ORL' not in G.nodes():
        print("Warning: ORL project not found in data. Using general hub layout instead.")
        return create_affinity_diagram(df, output_file)
    
    # Get ORL's direct connections
    orl_connections = list(G.neighbors('ORL'))
    print(f"ORL has {len(orl_connections)} direct connections")
    
    # Get projects by connectivity level
    hub_projects = [n for n, d in G.nodes(data=True) if d['link_count'] >= 30]
    high_projects = [n for n, d in G.nodes(data=True) if 20 <= d['link_count'] < 30]
    medium_projects = [n for n, d in G.nodes(data=True) if 10 <= d['link_count'] < 20]
    low_projects = [n for n, d in G.nodes(data=True) if 0 < d['link_count'] < 10]
    isolated_projects = [n for n, d in G.nodes(data=True) if d['link_count'] == 0]
    
    # Create ORL-centered radial layout
    pos = {}
    
    # ORL at the center
    pos['ORL'] = (0, 0)
    
    # Get ORL's connections by layer for organized placement (only high and medium)
    orl_hub_connections = [conn for conn in orl_connections if conn in hub_projects]
    orl_high_connections = [conn for conn in orl_connections if conn in high_projects]
    orl_medium_connections = [conn for conn in orl_connections if conn in medium_projects]
    
    # Filter to only show high and medium connections (hide low and isolated)
    orl_filtered_connections = orl_hub_connections + orl_high_connections + orl_medium_connections
    print(f"ORL filtered connections (hub+high+medium): {len(orl_filtered_connections)}")
    print(f"ORL hub connections: {len(orl_hub_connections)}")
    print(f"ORL high connections: {len(orl_high_connections)}")
    print(f"ORL medium connections: {len(orl_medium_connections)}")
    
    # Place ORL's hub connections in inner ring
    if orl_hub_connections:
        hub_angle_step = 2 * np.pi / len(orl_hub_connections)
        hub_radius = 0.4
        for i, hub in enumerate(orl_hub_connections):
            angle = i * hub_angle_step
            pos[hub] = (hub_radius * np.cos(angle), hub_radius * np.sin(angle))
    
    # Place ORL's high connections in second ring
    if orl_high_connections:
        high_angle_step = 2 * np.pi / len(orl_high_connections)
        high_radius = 0.7
        for i, project in enumerate(orl_high_connections):
            angle = i * high_angle_step
            pos[project] = (high_radius * np.cos(angle), high_radius * np.sin(angle))
    
    # Place ORL's medium connections in third ring
    if orl_medium_connections:
        medium_angle_step = 2 * np.pi / len(orl_medium_connections)
        medium_radius = 1.0
        for i, project in enumerate(orl_medium_connections):
            angle = i * medium_angle_step
            pos[project] = (medium_radius * np.cos(angle), medium_radius * np.sin(angle))
    
    # Skip low and isolated connections - they are filtered out
    
    # Add other projects not directly connected to ORL in outer areas (only high and medium)
    other_projects = [n for n in G.nodes() if n != 'ORL' and n not in orl_filtered_connections and n in (hub_projects + high_projects + medium_projects)]
    
    # Place other hub projects
    other_hub_projects = [p for p in other_projects if p in hub_projects]
    if other_hub_projects:
        other_hub_angle_step = 2 * np.pi / len(other_hub_projects)
        other_hub_radius = 2.0
        for i, project in enumerate(other_hub_projects):
            angle = i * other_hub_angle_step
            pos[project] = (other_hub_radius * np.cos(angle), other_hub_radius * np.sin(angle))
    
    # Place other high projects
    other_high_projects = [p for p in other_projects if p in high_projects]
    if other_high_projects:
        other_high_angle_step = 2 * np.pi / len(other_high_projects)
        other_high_radius = 2.3
        for i, project in enumerate(other_high_projects):
            angle = i * other_high_angle_step
            pos[project] = (other_high_radius * np.cos(angle), other_high_radius * np.sin(angle))
    
    # Place other medium projects
    other_medium_projects = [p for p in other_projects if p in medium_projects]
    if other_medium_projects:
        other_medium_angle_step = 2 * np.pi / len(other_medium_projects)
        other_medium_radius = 2.6
        for i, project in enumerate(other_medium_projects):
            angle = i * other_medium_angle_step
            pos[project] = (other_medium_radius * np.cos(angle), other_medium_radius * np.sin(angle))
    
    # Skip low and isolated projects - they are filtered out
    
    # Separate nodes by connectivity level (only show hub, high, and medium)
    hub_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Hub' and n in pos]
    high_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'High' and n in pos]
    medium_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Medium' and n in pos]
    # Skip low and isolated nodes - they are filtered out
    
    # Categorize edges with special focus on ORL connections
    orl_edges = []           # All edges connected to ORL (thickest, most prominent)
    hub_to_hub = []          # Hub to Hub (2nd thinnest solid gray)
    hub_to_outer = []        # Hub to any outer layer (2nd thinnest solid gray)
    high_to_high = []        # High to High only (thinnest solid gray)
    high_to_medium = []      # High to Medium (thinnest solid gray)
    high_to_low = []         # High to Low (thinnest solid gray)
    medium_to_medium = []    # Medium to Medium only (thinnest dashed gray)
    medium_to_low = []       # Medium to Low (thinnest dashed gray)
    low_to_low = []          # Low to Low (thinnest dashed gray)
    isolated_edges = []      # Any connections to isolated
    
    for edge in G.edges():
        source, target = edge
        
        # Check if edge involves ORL and the connected project is in our filtered set
        if source == 'ORL' or target == 'ORL':
            # Only include ORL edges if the connected project is in our filtered connections
            connected_project = target if source == 'ORL' else source
            if connected_project in orl_filtered_connections:
                orl_edges.append(edge)
            continue
        
        # Determine layer categories
        source_is_hub = source in hub_projects
        source_is_high = source in high_projects
        source_is_medium = source in medium_projects
        source_is_low = source in low_projects
        source_is_isolated = source in isolated_projects
        
        target_is_hub = target in hub_projects
        target_is_high = target in high_projects
        target_is_medium = target in medium_projects
        target_is_low = target in low_projects
        target_is_isolated = target in isolated_projects
        
        # Categorize edges with priority (inner layers override outer)
        if source_is_hub or target_is_hub:
            if source_is_hub and target_is_hub:
                hub_to_hub.append(edge)
            else:
                hub_to_outer.append(edge)
        elif source_is_high or target_is_high:
            if source_is_high and target_is_high:
                high_to_high.append(edge)
            elif source_is_high and target_is_medium:
                high_to_medium.append(edge)
            elif source_is_high and target_is_low:
                high_to_low.append(edge)
            elif target_is_high and source_is_medium:
                high_to_medium.append(edge)
            elif target_is_high and source_is_low:
                high_to_low.append(edge)
        elif source_is_medium or target_is_medium:
            if source_is_medium and target_is_medium:
                medium_to_medium.append(edge)
            elif source_is_medium and target_is_low:
                medium_to_low.append(edge)
            elif target_is_medium and source_is_low:
                medium_to_low.append(edge)
        elif source_is_low and target_is_low:
            low_to_low.append(edge)
        else:
            isolated_edges.append(edge)
    
    # Draw edges in order (outer to inner for proper layering)
    
    # Draw isolated connections first (thinnest dashed gray)
    if isolated_edges:
        nx.draw_networkx_edges(G, pos, edgelist=isolated_edges, alpha=0.3, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw low to low connections (thinnest dashed gray)
    if low_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=low_to_low, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to low connections (thinnest dashed gray)
    if medium_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_low, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to medium connections (thinnest dashed gray)
    if medium_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_medium, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to low connections (thinnest solid gray)
    if high_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_low, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw high to medium connections (thinnest solid gray)
    if high_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_medium, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw high to high connections (thinnest solid gray)
    if high_to_high:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_high, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw hub to outer connections (2nd thinnest solid gray)
    if hub_to_outer:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_outer, alpha=0.7, width=0.8, 
                              edge_color='darkgray', style='solid')
    
    # Draw hub to hub connections (2nd thinnest solid gray)
    if hub_to_hub:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_hub, alpha=0.7, width=0.8, 
                              edge_color='darkgray', style='solid')
    
    # Draw ORL connections last (thickest, most prominent)
    if orl_edges:
        nx.draw_networkx_edges(G, pos, edgelist=orl_edges, alpha=1.0, width=2.0, 
                              edge_color='#FF4444', style='solid')
    
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
    
    # Add labels for ALL nodes with different font sizes based on layer
    all_labels = {}
    for node in G.nodes():
        all_labels[node] = node
    
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
    
    # Low connectivity labels
    low_labels = {node: node for node in low_nodes}
    if low_labels:
        nx.draw_networkx_labels(G, pos, low_labels, font_size=7, font_weight='normal', font_color='black')
    
    # Isolated labels
    isolated_labels = {node: node for node in isolated_nodes}
    if isolated_labels:
        nx.draw_networkx_labels(G, pos, isolated_labels, font_size=6, font_weight='normal', font_color='black')
    
    # Add title and legend
    plt.title('OMF Jira Project Affinity Diagram\nORL-Centered Radial Layout - All ORL Relationships', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.scatter([], [], c='#FF6B6B', s=200, label='Hub Ring (30+ links) - Center', alpha=1.0),
        plt.scatter([], [], c='#4ECDC4', s=150, label='High Ring (20-29 links)', alpha=0.9),
        plt.scatter([], [], c='#45B7D1', s=100, label='Medium Ring (10-19 links)', alpha=0.8),
        plt.scatter([], [], c='#96CEB4', s=75, label='Low Ring (1-9 links)', alpha=0.7),
        plt.scatter([], [], c='#D3D3D3', s=50, label='Isolated Ring (0 links)', alpha=0.6)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), fontsize=10)
    
    # Add statistics text
    stats_text = f"""
    Total Projects: {len(G.nodes())}
    ORL Direct Connections: {len(orl_connections)}
    Hub Projects: {len(hub_nodes)}
    High Projects: {len(high_nodes)}
    Medium Projects: {len(medium_nodes)}
    Low Projects: {len(low_nodes)}
    Isolated Projects: {len(isolated_nodes)}
    Total Connections: {len(G.edges())}
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

def create_affinity_diagram(df, output_file='project_affinity_diagram.png'):
    """Create the main affinity diagram with circular hub layout (fallback function)"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot
    plt.figure(figsize=(24, 20))
    
    # Get projects by connectivity level
    hub_projects = [n for n, d in G.nodes(data=True) if d['link_count'] >= 30]
    high_projects = [n for n, d in G.nodes(data=True) if 20 <= d['link_count'] < 30]
    medium_projects = [n for n, d in G.nodes(data=True) if 10 <= d['link_count'] < 20]
    low_projects = [n for n, d in G.nodes(data=True) if 0 < d['link_count'] < 10]
    isolated_projects = [n for n, d in G.nodes(data=True) if d['link_count'] == 0]
    
    # Create circular layout
    pos = {}
    
    # Center ring: Hub projects (30+ connections) in a circle
    if hub_projects:
        hub_angle_step = 2 * np.pi / len(hub_projects)
        hub_radius = 0.3
        for i, hub in enumerate(hub_projects):
            angle = i * hub_angle_step
            pos[hub] = (hub_radius * np.cos(angle), hub_radius * np.sin(angle))
    
    # Second ring: High connectivity projects (20-29 connections)
    if high_projects:
        high_angle_step = 2 * np.pi / len(high_projects)
        high_radius = 0.6
        for i, project in enumerate(high_projects):
            angle = i * high_angle_step
            pos[project] = (high_radius * np.cos(angle), high_radius * np.sin(angle))
    
    # Third ring: Medium connectivity projects (10-19 connections)
    if medium_projects:
        medium_angle_step = 2 * np.pi / len(medium_projects)
        medium_radius = 0.9
        for i, project in enumerate(medium_projects):
            angle = i * medium_angle_step
            pos[project] = (medium_radius * np.cos(angle), medium_radius * np.sin(angle))
    
    # Fourth ring: Low connectivity projects (1-9 connections)
    if low_projects:
        low_angle_step = 2 * np.pi / len(low_projects)
        low_radius = 1.2
        for i, project in enumerate(low_projects):
            angle = i * low_angle_step
            pos[project] = (low_radius * np.cos(angle), low_radius * np.sin(angle))
    
    # Outer ring: Isolated projects (0 connections)
    if isolated_projects:
        isolated_angle_step = 2 * np.pi / len(isolated_projects)
        isolated_radius = 1.5
        for i, project in enumerate(isolated_projects):
            angle = i * isolated_angle_step
            pos[project] = (isolated_radius * np.cos(angle), isolated_radius * np.sin(angle))
    
    # Separate nodes by connectivity level
    hub_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Hub']
    high_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'High']
    medium_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Medium']
    low_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Low']
    isolated_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Isolated']
    
    # Categorize edges by layer priority (inner layers override outer layer styling)
    hub_to_hub = []          # Hub to Hub (2nd thinnest solid gray)
    hub_to_outer = []        # Hub to any outer layer (2nd thinnest solid gray)
    high_to_high = []        # High to High only (thinnest solid gray)
    high_to_medium = []      # High to Medium (thinnest solid gray)
    high_to_low = []         # High to Low (thinnest solid gray)
    medium_to_medium = []    # Medium to Medium only (thinnest dashed gray)
    medium_to_low = []       # Medium to Low (thinnest dashed gray)
    low_to_low = []          # Low to Low (thinnest dashed gray)
    isolated_edges = []      # Any connections to isolated
    
    for edge in G.edges():
        source, target = edge
        
        # Determine layer categories
        source_is_hub = source in hub_projects
        source_is_high = source in high_projects
        source_is_medium = source in medium_projects
        source_is_low = source in low_projects
        source_is_isolated = source in isolated_projects
        
        target_is_hub = target in hub_projects
        target_is_high = target in high_projects
        target_is_medium = target in medium_projects
        target_is_low = target in low_projects
        target_is_isolated = target in isolated_projects
        
        # Categorize edges with priority (inner layers override outer)
        if source_is_hub or target_is_hub:
            if source_is_hub and target_is_hub:
                hub_to_hub.append(edge)
            else:
                hub_to_outer.append(edge)
        elif source_is_high or target_is_high:
            if source_is_high and target_is_high:
                high_to_high.append(edge)
            elif source_is_high and target_is_medium:
                high_to_medium.append(edge)
            elif source_is_high and target_is_low:
                high_to_low.append(edge)
            elif target_is_high and source_is_medium:
                high_to_medium.append(edge)
            elif target_is_high and source_is_low:
                high_to_low.append(edge)
        elif source_is_medium or target_is_medium:
            if source_is_medium and target_is_medium:
                medium_to_medium.append(edge)
            elif source_is_medium and target_is_low:
                medium_to_low.append(edge)
            elif target_is_medium and source_is_low:
                medium_to_low.append(edge)
        elif source_is_low and target_is_low:
            low_to_low.append(edge)
        else:
            isolated_edges.append(edge)
    
    # Draw edges in order (outer to inner for proper layering)
    
    # Draw isolated connections first (thinnest dashed gray)
    if isolated_edges:
        nx.draw_networkx_edges(G, pos, edgelist=isolated_edges, alpha=0.3, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw low to low connections (thinnest dashed gray)
    if low_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=low_to_low, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to low connections (thinnest dashed gray)
    if medium_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_low, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to medium connections (thinnest dashed gray)
    if medium_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_medium, alpha=0.4, width=0.5, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to low connections (thinnest solid gray)
    if high_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_low, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw high to medium connections (thinnest solid gray)
    if high_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_medium, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw high to high connections (thinnest solid gray)
    if high_to_high:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_high, alpha=0.5, width=0.3, 
                              edge_color='gray', style='solid')
    
    # Draw hub to outer connections (2nd thinnest solid gray)
    if hub_to_outer:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_outer, alpha=0.7, width=0.8, 
                              edge_color='darkgray', style='solid')
    
    # Draw hub to hub connections (2nd thinnest solid gray)
    if hub_to_hub:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_hub, alpha=0.7, width=0.8, 
                              edge_color='darkgray', style='solid')
    
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
    
    # Add labels for ALL nodes with different font sizes based on layer
    all_labels = {}
    for node in G.nodes():
        all_labels[node] = node
    
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
    
    # Low connectivity labels
    low_labels = {node: node for node in low_nodes}
    if low_labels:
        nx.draw_networkx_labels(G, pos, low_labels, font_size=7, font_weight='normal', font_color='black')
    
    # Isolated labels
    isolated_labels = {node: node for node in isolated_nodes}
    if isolated_labels:
        nx.draw_networkx_labels(G, pos, isolated_labels, font_size=6, font_weight='normal', font_color='black')
    
    # Add title and legend
    plt.title('OMF Jira Project Affinity Diagram\nCircular Ring Layout - Hub Projects in Center', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.scatter([], [], c='#FF6B6B', s=200, label='Hub Ring (30+ links) - Center', alpha=1.0),
        plt.scatter([], [], c='#4ECDC4', s=150, label='High Ring (20-29 links)', alpha=0.9),
        plt.scatter([], [], c='#45B7D1', s=100, label='Medium Ring (10-19 links)', alpha=0.8),
        plt.scatter([], [], c='#96CEB4', s=75, label='Low Ring (1-9 links)', alpha=0.7),
        plt.scatter([], [], c='#D3D3D3', s=50, label='Isolated Ring (0 links)', alpha=0.6)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), fontsize=10)
    
    # Add statistics text
    stats_text = f"""
    Total Projects: {len(G.nodes())}
    Center Ring (Hubs): {len(hub_nodes)}
    Ring 2 (High): {len(high_nodes)}
    Ring 3 (Medium): {len(medium_nodes)}
    Ring 4 (Low): {len(low_nodes)}
    Outer Ring (Isolated): {len(isolated_nodes)}
    Total Connections: {len(G.edges())}
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

def create_pay_centered_diagram(df, output_file='pay_centered_diagram.png'):
    """Create a PAY-centered radial affinity diagram with ring layout"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot
    plt.figure(figsize=(24, 20))
    
    # Check if PAY exists in the graph
    if 'PAY' not in G.nodes():
        print("Warning: PAY project not found in data. Using general hub layout instead.")
        return create_affinity_diagram(df, output_file)
    
    # Get PAY's direct connections
    pay_connections = list(G.neighbors('PAY'))
    print(f"PAY has {len(pay_connections)} direct connections")
    
    # Get projects by connectivity level
    hub_projects = [n for n, d in G.nodes(data=True) if d['link_count'] >= 15]
    high_projects = [n for n, d in G.nodes(data=True) if 11 <= d['link_count'] < 15]
    medium_projects = [n for n, d in G.nodes(data=True) if 6 <= d['link_count'] < 11]
    low_projects = [n for n, d in G.nodes(data=True) if 1 <= d['link_count'] < 6]
    
    # Create PAY-centered radial layout
    pos = {}
    
    # PAY at the center
    pos['PAY'] = (0, 0)
    
    # Get PAY's connections by layer for organized placement
    pay_hub_connections = [conn for conn in pay_connections if conn in hub_projects]
    pay_high_connections = [conn for conn in pay_connections if conn in high_projects]
    pay_medium_connections = [conn for conn in pay_connections if conn in medium_projects]
    pay_low_connections = [conn for conn in pay_connections if conn in low_projects]
    
    # Place PAY's connections in rings
    if pay_hub_connections:
        hub_angle_step = 2 * np.pi / len(pay_hub_connections)
        hub_radius = 0.4
        for i, hub in enumerate(pay_hub_connections):
            angle = i * hub_angle_step
            pos[hub] = (hub_radius * np.cos(angle), hub_radius * np.sin(angle))
    
    if pay_high_connections:
        high_angle_step = 2 * np.pi / len(pay_high_connections)
        high_radius = 0.7
        for i, project in enumerate(pay_high_connections):
            angle = i * high_angle_step
            pos[project] = (high_radius * np.cos(angle), high_radius * np.sin(angle))
    
    if pay_medium_connections:
        medium_angle_step = 2 * np.pi / len(pay_medium_connections)
        medium_radius = 1.0
        for i, project in enumerate(pay_medium_connections):
            angle = i * medium_angle_step
            pos[project] = (medium_radius * np.cos(angle), medium_radius * np.sin(angle))
    
    if pay_low_connections:
        low_angle_step = 2 * np.pi / len(pay_low_connections)
        low_radius = 1.3
        for i, project in enumerate(pay_low_connections):
            angle = i * low_angle_step
            pos[project] = (low_radius * np.cos(angle), low_radius * np.sin(angle))
    
    # Add other projects not directly connected to PAY in outer areas
    other_projects = [n for n in G.nodes() if n != 'PAY' and n not in pay_connections]
    
    # Place other projects in outer rings
    other_hub_projects = [p for p in other_projects if p in hub_projects]
    if other_hub_projects:
        other_hub_angle_step = 2 * np.pi / len(other_hub_projects)
        other_hub_radius = 2.0
        for i, project in enumerate(other_hub_projects):
            angle = i * other_hub_angle_step
            pos[project] = (other_hub_radius * np.cos(angle), other_hub_radius * np.sin(angle))
    
    other_high_projects = [p for p in other_projects if p in high_projects]
    if other_high_projects:
        other_high_angle_step = 2 * np.pi / len(other_high_projects)
        other_high_radius = 2.3
        for i, project in enumerate(other_high_projects):
            angle = i * other_high_angle_step
            pos[project] = (other_high_radius * np.cos(angle), other_high_radius * np.sin(angle))
    
    other_medium_projects = [p for p in other_projects if p in medium_projects]
    if other_medium_projects:
        other_medium_angle_step = 2 * np.pi / len(other_medium_projects)
        other_medium_radius = 2.6
        for i, project in enumerate(other_medium_projects):
            angle = i * other_medium_angle_step
            pos[project] = (other_medium_radius * np.cos(angle), other_medium_radius * np.sin(angle))
    
    other_low_projects = [p for p in other_projects if p in low_projects]
    if other_low_projects:
        other_low_angle_step = 2 * np.pi / len(other_low_projects)
        other_low_radius = 2.9
        for i, project in enumerate(other_low_projects):
            angle = i * other_low_angle_step
            pos[project] = (other_low_radius * np.cos(angle), other_low_radius * np.sin(angle))
    
    # Separate nodes by connectivity level
    hub_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Hub' and n in pos]
    high_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'High' and n in pos]
    medium_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Medium' and n in pos]
    low_nodes = [n for n, d in G.nodes(data=True) if d['size_category'] == 'Low' and n in pos]
    
    # Draw edges first (behind nodes)
    nx.draw_networkx_edges(G, pos, alpha=0.3, edge_color='lightgray', width=0.5)
    
    # Draw nodes by ring with appropriate colors
    # Center (PAY)
    if 'PAY' in pos:
        nx.draw_networkx_nodes(G, pos, nodelist=['PAY'], 
                              node_color='#1f4e79', node_size=2000, alpha=0.9)
    
    # Hub Ring (Orange)
    if hub_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes, 
                              node_color='#ff8c00', node_size=800, alpha=0.9)
    
    # High Ring (Blue)
    if high_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes, 
                              node_color='#4682b4', node_size=600, alpha=0.9)
    
    # Medium Ring (Green)
    if medium_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes, 
                              node_color='#90ee90', node_size=400, alpha=0.9)
    
    # Low Ring (Grey)
    if low_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes, 
                              node_color='#d3d3d3', node_size=300, alpha=0.9)
    
    # Draw labels with connection counts
    labels = {}
    for node in G.nodes():
        if node in pos:
            link_count = G.nodes[node]['link_count']
            if node == 'PAY':
                labels[node] = f"{node}\n{link_count}"
            else:
                labels[node] = f"{node}\n{link_count}"
    
    nx.draw_networkx_labels(G, pos, labels, font_size=8, font_weight='bold', font_color='white')
    
    # Add title
    plt.title('Payment Services (PAY) - Network Connections\n(Filtered: Unresolved Issues, 90-Day Activity)', 
              fontsize=20, fontweight='bold', pad=20)
    
    # Add legend
    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', label='PAY (Center)',
                   markerfacecolor='#1f4e79', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Hub Ring (15+ connections)',
                   markerfacecolor='#ff8c00', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='High Ring (11-14 connections)',
                   markerfacecolor='#4682b4', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Medium Ring (6-10 connections)',
                   markerfacecolor='#90ee90', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Low Ring (1-5 connections)',
                   markerfacecolor='#d3d3d3', markersize=10)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0.02, 0.98), fontsize=12)
    
    # Add statistics text
    stats_text = f"""
    Total Projects: {len(G.nodes())}
    Center (PAY): 1
    Hub Ring (15+): {len(hub_nodes)}
    High Ring (11-14): {len(high_nodes)}
    Medium Ring (6-10): {len(medium_nodes)}
    Low Ring (1-5): {len(low_nodes)}
    Total Connections: {len(G.edges())}
    """
    
    plt.figtext(0.02, 0.02, stats_text, fontsize=10, 
                bbox=dict(boxstyle="round,pad=0.3", facecolor="lightgray", alpha=0.8))
    
    plt.axis('off')
    plt.tight_layout()
    
    # Save with high quality
    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except:
        # Fallback save method
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
    
    plt.show()
    
    return G

def main():
    """Main function to generate the affinity diagram"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = load_project_data(csv_file)
    
    print("Creating PAY-Centered Project Affinity Diagram...")
    G = create_pay_centered_diagram(df, 'project_affinity_diagram_pay_filtered.png')
    
    # Print summary statistics
    print("\n" + "="*50)
    print("PROJECT AFFINITY ANALYSIS SUMMARY")
    print("="*50)
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
