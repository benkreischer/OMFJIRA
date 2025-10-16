#!/usr/bin/env python3
"""
Generate ACM-Centered Project Affinity Diagram
Based on the working TOKR template
"""

import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt
import numpy as np
import os
import sys
from pathlib import Path

def load_project_data(csv_file):
    """Load and process project relationship data"""
    print(f"Loading data from {csv_file}...")
    
    # Load the CSV data
    df = pd.read_csv(csv_file)
    
    # Group by ProjectKey and sum LinkCount for total connections
    project_totals = df.groupby('ProjectKey')['LinkCount'].sum().reset_index()
    project_totals.columns = ['ProjectKey', 'TotalLinks']
    
    print(f"Found {len(project_totals)} unique projects")
    print(f"Total relationships: {len(df)}")
    
    return df, project_totals

def create_project_network_graph(df, project_totals):
    """Create network graph from project relationships"""
    G = nx.Graph()
    
    # Get list of valid project keys
    valid_projects = set(project_totals['ProjectKey'].tolist())
    
    # Add all projects as nodes
    for _, row in project_totals.iterrows():
        G.add_node(row['ProjectKey'], link_count=row['TotalLinks'])
    
    # Add edges between connected projects (only if both projects are in our dataset)
    for _, row in df.iterrows():
        if (row['ProjectKey'] != row['ConnectedProject'] and  # Avoid self-loops
            row['ProjectKey'] in valid_projects and 
            row['ConnectedProject'] in valid_projects):
            G.add_edge(row['ProjectKey'], row['ConnectedProject'], weight=row['LinkCount'])
    
    return G

def create_ring_style_diagram(df, project_totals, center_project, output_filename):
    """Create professional ring-style diagram centered on a specific project"""
    
    print(f"\n{'='*60}")
    print(f"Creating {center_project}-Centered Project Affinity Diagram...")
    print(f"{'='*60}")
    
    # Create network graph
    G = create_project_network_graph(df, project_totals)
    
    # Check if center project exists
    if center_project not in G.nodes():
        print(f"ERROR: Project {center_project} not found in dataset")
        return None
    
    # Get direct connections to center project
    center_connections = list(G.neighbors(center_project))
    print(f"{center_project} has {len(center_connections)} direct connections")
    
    if len(center_connections) == 0:
        print(f"WARNING: {center_project} has no connections - creating minimal diagram")
        # Create a simple single-node diagram
        fig, ax = plt.subplots(1, 1, figsize=(12, 10))
        ax.text(0.5, 0.5, f"{center_project}\n(No Connections)", 
                ha='center', va='center', fontsize=16, fontweight='bold')
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.axis('off')
        plt.tight_layout()
        plt.savefig(output_filename, dpi=300, bbox_inches='tight')
        plt.close()
        return True
    
    # Filter to only include connected projects
    center_network_nodes = [center_project] + center_connections
    center_network = G.subgraph(center_network_nodes)
    
    print(f"{center_project} filtered connections: {len(center_connections)}")
    
    # Calculate connection counts for each connected project
    project_network_connections = {}
    for node in center_connections:
        project_network_connections[node] = center_network.degree(node) - 1  # Subtract 1 for connection to center
    
    # Categorize connections based on their total network connectivity
    center_hub_connections = [n for n in center_connections if project_network_connections[n] >= 6]
    center_high_connections = [n for n in center_connections if 4 <= project_network_connections[n] <= 5]
    center_medium_connections = [n for n in center_connections if 2 <= project_network_connections[n] <= 3]
    center_low_connections = [n for n in center_connections if project_network_connections[n] == 1]
    
    print(f"  Hub (6+): {len(center_hub_connections)}, High (4-5): {len(center_high_connections)}, Medium (2-3): {len(center_medium_connections)}, Low (1): {len(center_low_connections)}")
    
    # Create figure
    fig, ax = plt.subplots(1, 1, figsize=(16, 12))
    
    # Define ring radii (tightest configuration)
    center_radius = 0.08
    hub_radius = 0.18
    high_radius = 0.30
    medium_radius = 0.42
    low_radius = 0.54
    
    # Define node sizes
    node_sizes = {}
    for node in center_network_nodes:
        if node == center_project:
            node_sizes[node] = 4000  # Center project size (fixed)
        elif node in center_hub_connections:
            network_connections = project_network_connections[node]
            node_sizes[node] = max(2000, min(3600, network_connections * 200))  # Hub: 2000-3600
        elif node in center_high_connections:
            network_connections = project_network_connections[node]
            node_sizes[node] = max(1200, min(1900, network_connections * 300))  # High: 1200-1900
        elif node in center_medium_connections:
            network_connections = project_network_connections[node]
            node_sizes[node] = max(600, min(1100, network_connections * 250))   # Medium: 600-1100
        elif node in center_low_connections:
            network_connections = project_network_connections[node]
            node_sizes[node] = max(400, min(500, network_connections * 400))    # Low: 400-500
        else:
            node_sizes[node] = 400
    
    # Calculate positions
    pos = {}
    
    # Center project at origin
    pos[center_project] = (0, 0)
    
    # Position connected projects in concentric rings
    angles = {}
    if len(center_hub_connections) > 0:
        angles['hub'] = np.linspace(0, 2*np.pi, len(center_hub_connections), endpoint=False)
    if len(center_high_connections) > 0:
        angles['high'] = np.linspace(0, 2*np.pi, len(center_high_connections), endpoint=False)
    if len(center_medium_connections) > 0:
        angles['medium'] = np.linspace(0, 2*np.pi, len(center_medium_connections), endpoint=False)
    if len(center_low_connections) > 0:
        angles['low'] = np.linspace(0, 2*np.pi, len(center_low_connections), endpoint=False)
    
    # Assign positions
    angle_idx = {'hub': 0, 'high': 0, 'medium': 0, 'low': 0}
    
    for node in center_connections:
        if node in center_hub_connections:
            pos[node] = (hub_radius * np.cos(angles['hub'][angle_idx['hub']]), 
                        hub_radius * np.sin(angles['hub'][angle_idx['hub']]))
            angle_idx['hub'] += 1
        elif node in center_high_connections:
            pos[node] = (high_radius * np.cos(angles['high'][angle_idx['high']]), 
                        high_radius * np.sin(angles['high'][angle_idx['high']]))
            angle_idx['high'] += 1
        elif node in center_medium_connections:
            pos[node] = (medium_radius * np.cos(angles['medium'][angle_idx['medium']]), 
                        medium_radius * np.sin(angles['medium'][angle_idx['medium']]))
            angle_idx['medium'] += 1
        elif node in center_low_connections:
            pos[node] = (low_radius * np.cos(angles['low'][angle_idx['low']]), 
                        low_radius * np.sin(angles['low'][angle_idx['low']]))
            angle_idx['low'] += 1
    
    # Draw edges
    for edge in center_network.edges():
        x1, y1 = pos[edge[0]]
        x2, y2 = pos[edge[1]]
        
        if edge[0] == center_project or edge[1] == center_project:
            # Lines from center to connected projects
            connected_node = edge[1] if edge[0] == center_project else edge[0]
            if connected_node in center_hub_connections:
                ax.plot([x1, x2], [y1, y2], 'orange', linewidth=4, alpha=1.0, zorder=1)
            else:
                ax.plot([x1, x2], [y1, y2], 'lightgray', linewidth=1, alpha=0.25, zorder=1)
        else:
            # Project-to-project connections
            ax.plot([x1, x2], [y1, y2], 'black', linewidth=1, alpha=0.5, linestyle='--', zorder=0)
    
    # Draw nodes by category with different colors and transparency
    node_colors = {}
    for node in center_network_nodes:
        if node == center_project:
            node_colors[node] = '#FF6B6B'  # Center: Red
        elif node in center_hub_connections:
            node_colors[node] = '#FFA500'  # Hub: Orange
        elif node in center_high_connections:
            node_colors[node] = '#4ECDC4'  # High: Blue
        elif node in center_medium_connections:
            node_colors[node] = '#45B7D1'  # Medium: Green
        elif node in center_low_connections:
            node_colors[node] = '#96CEB4'  # Low: Gray
        else:
            node_colors[node] = '#D3D3D3'  # Default: Light Gray
    
    # Draw circles (nodes) with 10% transparency
    for node in center_network_nodes:
        if node in pos:
            circle = plt.Circle(pos[node], node_sizes[node]/200000, 
                              color=node_colors[node], alpha=0.1, zorder=2)
            ax.add_patch(circle)
    
    # Add project labels above circles
    for node in center_network_nodes:
        if node in pos:
            x, y = pos[node]
            if node == center_project:
                # Center project shows connection count
                label_text = f"{len(center_connections)}"
                ax.text(x, y, label_text, ha='center', va='center', 
                       fontsize=12, fontweight='bold', color='black', zorder=4)
                # Project name above circle
                ax.text(x, y + 0.03, center_project, ha='center', va='bottom', 
                       fontsize=14, fontweight='bold', color='black', zorder=4)
            else:
                # Connected projects show their connection count
                connection_count = project_network_connections[node]
                ax.text(x, y, str(connection_count), ha='center', va='center', 
                       fontsize=10, fontweight='bold', color='black', zorder=4)
                # Project key above circle
                ax.text(x, y + 0.03, node, ha='center', va='bottom', 
                       fontsize=10, fontweight='bold', color='black', zorder=4)
    
    # Create legend
    legend_text = f"Ring Categories:\n• Hub (6+ connections): Orange\n• High (4-5 connections): Blue\n• Medium (2-3 connections): Green\n• Low (1 connection): Gray"
    ax.text(0.02, 0.98, legend_text, transform=ax.transAxes, fontsize=10, 
           verticalalignment='top', bbox=dict(boxstyle='round', facecolor='white', alpha=0.8))
    
    # Create data table
    table_data = []
    for node in sorted(center_connections, key=lambda x: project_network_connections[x], reverse=True):
        if node in center_hub_connections:
            category = "Hub (6+)"
            color = '#FFA500'
        elif node in center_high_connections:
            category = "High (4-5)"
            color = '#4ECDC4'
        elif node in center_medium_connections:
            category = "Medium (2-3)"
            color = '#45B7D1'
        elif node in center_low_connections:
            category = "Low (1)"
            color = '#96CEB4'
        else:
            category = "Unknown"
            color = '#D3D3D3'
        
        # Get link count to center project
        center_link_count = df[(df['ProjectKey'] == center_project) & (df['ConnectedProject'] == node)]['LinkCount'].sum()
        if center_link_count == 0:
            center_link_count = df[(df['ProjectKey'] == node) & (df['ConnectedProject'] == center_project)]['LinkCount'].sum()
        
        # Get total links for the connected project
        total_links = 0
        if len(project_totals[project_totals['ProjectKey'] == node]) > 0:
            total_links = project_totals[project_totals['ProjectKey'] == node]['TotalLinks'].iloc[0]
        
        table_data.append([
            node,
            project_network_connections[node],
            center_link_count,
            total_links
        ])
    
    # Sort by connection count (descending), then by TOKR links (descending)
    table_data.sort(key=lambda x: (x[1], x[2]), reverse=True)
    
    # Calculate totals
    hub_count = len(center_hub_connections)
    high_count = len(center_high_connections)
    medium_count = len(center_medium_connections)
    low_count = len(center_low_connections)
    total_projects = len(center_connections)
    weighted_sum = (hub_count * 4) + (high_count * 3) + (medium_count * 2) + (low_count * 1)
    total_tokr_links = sum(row[2] for row in table_data)
    total_project_links = sum(row[3] for row in table_data)
    
    # Add totals row at the top
    table_data.insert(0, [total_projects, weighted_sum, total_tokr_links, total_project_links])
    
    # Create table
    table_text = "Project Analysis Table:\n"
    table_text += f"{'Project':<8} {'Conn':<4} {'Links':<5} {'Total':<5}\n"
    table_text += "-" * 25 + "\n"
    
    for i, row in enumerate(table_data):
        if i == 0:  # Totals row
            table_text += f"{row[0]:<8} {row[1]:<4} {row[2]:<5} {row[3]:<5}\n"
        else:
            table_text += f"{row[0]:<8} {row[1]:<4} {row[2]:<5} {row[3]:<5}\n"
    
    ax.text(0.02, 0.45, table_text, transform=ax.transAxes, fontsize=8, 
           verticalalignment='top', fontfamily='monospace',
           bbox=dict(boxstyle='round', facecolor='white', alpha=0.9))
    
    # Set plot properties
    ax.set_xlim(-0.7, 0.7)
    ax.set_ylim(-0.7, 0.7)
    ax.set_aspect('equal')
    ax.axis('off')
    
    # Add title
    plt.suptitle(f'{center_project}-Centered Project Affinity Analysis', 
                fontsize=16, fontweight='bold', y=0.95)
    
    # Save with proper filename format
    plt.tight_layout()
    plt.savefig(output_filename, dpi=300, bbox_inches='tight')
    plt.close()
    
    # Create proper filename with weighted sum
    total_projects = len(center_connections)
    weighted_sum = (hub_count * 4) + (high_count * 3) + (medium_count * 2) + (low_count * 1)
    proper_filename = f"{weighted_sum:04d}_{total_projects:04d}_{hub_count:04d}_{high_count:04d}_{medium_count:04d}_{low_count:04d}_{center_project}.png"
    
    # Rename the file
    if os.path.exists(output_filename):
        os.rename(output_filename, proper_filename)
        print(f"Diagram saved as: {proper_filename}")
    else:
        print(f"Diagram saved as: {output_filename}")
    
    return True

def main():
    """Main function to generate diagram for ACM"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df, project_totals = load_project_data(csv_file)
    
    # Generate diagram for ACM
    center_project = "ACM"
    output_filename = f"temp_{center_project}.png"
    
    print(f"\n{'='*60}")
    print(f"Creating {center_project}-Centered Project Affinity Diagram...")
    print(f"{'='*60}")
    
    try:
        success = create_ring_style_diagram(df, project_totals, center_project, output_filename)
        if success:
            print(f"[SUCCESS] Created diagram for {center_project}")
        else:
            print(f"[FAILED] Failed to create diagram for {center_project}")
    except Exception as e:
        print(f"[ERROR] Error creating diagram for {center_project}: {str(e)}")

if __name__ == "__main__":
    main()
