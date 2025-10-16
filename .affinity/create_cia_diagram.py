#!/usr/bin/env python3
"""
Create CIA-Centered Diagram with Proper Naming Convention
Based on the updated TOKR script with new layer definitions
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
    
    return project_summary, df

def create_cia_centered_diagram(relationships_df, output_file='cia_centered_diagram.png', weighted_sum=0):
    """Create a CIA-centered radial affinity diagram with ring layout and professional styling."""

    G = nx.Graph()

    # First, calculate total link counts for each project
    project_totals = {}
    for _, row in relationships_df.iterrows():
        proj1 = row['ProjectKey']
        proj2 = row['ConnectedProject']
        link_count = row['LinkCount']
        
        # Add to totals
        if proj1 not in project_totals:
            project_totals[proj1] = 0
        if proj2 not in project_totals:
            project_totals[proj2] = 0
        
        project_totals[proj1] += link_count
        project_totals[proj2] += link_count

    # Add all projects as nodes with their total link counts
    for project_key, total_link_count in project_totals.items():
        G.add_node(project_key, label=project_key, link_count=total_link_count)

    # Add edges based on relationships_df
    for _, row in relationships_df.iterrows():
        source = row['ProjectKey']
        target = row['ConnectedProject']
        link_count = row['LinkCount']
        if G.has_node(source) and G.has_node(target):
            G.add_edge(source, target, weight=link_count)

    # Set up the plot
    plt.figure(figsize=(24, 20))

    # Check if CIA exists in the graph
    if 'CIA' not in G.nodes():
        print("Warning: CIA project not found in data. Cannot create CIA-centered diagram.")
        return None, 0, 0, 0, 0, {}, []

    # Get CIA's direct connections
    cia_connections = list(G.neighbors('CIA'))
    print(f"CIA has {len(cia_connections)} direct connections")

    # Categorize connected projects by their connectivity to OTHER projects in the CIA list
    center_hub_connections = []
    center_high_connections = []
    center_medium_connections = []
    center_low_connections = []

    # Calculate connections for each project to other projects in the CIA list
    cia_connected_projects = list(cia_connections)
    project_connection_counts = {}
    
    for conn in cia_connections:
        connections = 0
        # Count connections to other projects in the CIA list (including CIA)
        project_rels = relationships_df[(relationships_df['ProjectKey'] == conn) | (relationships_df['ConnectedProject'] == conn)]
        
        for _, row in project_rels.iterrows():
            if row['ProjectKey'] == conn:
                other_project = row['ConnectedProject']
            else:
                other_project = row['ProjectKey']
            
            # Count connections to other projects in the CIA list (including CIA)
            if other_project in cia_connected_projects + ['CIA']:
                connections += 1
        
        project_connection_counts[conn] = connections
        
        # Categorize based on NEW thresholds: Low=1, Medium=2, High=3, Hub=4+
        if connections >= 4:
            center_hub_connections.append(conn)
        elif connections == 3:
            center_high_connections.append(conn)
        elif connections == 2:
            center_medium_connections.append(conn)
        else:  # connections == 1
            center_low_connections.append(conn)

    print(f"CIA filtered connections: {len(center_hub_connections + center_high_connections + center_medium_connections + center_low_connections)}")
    print(f"  Hub (4+): {len(center_hub_connections)}, High (3): {len(center_high_connections)}, Medium (2): {len(center_medium_connections)}, Low (1): {len(center_low_connections)}")

    # Create positioning with proper concentric rings
    pos = {}

    # CIA at center
    pos['CIA'] = (0, 0)

    # Position projects in concentric rings (even spacing)
    # Hub ring (closest, largest) - Orange
    if center_hub_connections:
        angles = np.linspace(0, 2*np.pi, len(center_hub_connections), endpoint=False)
        radius = 0.15  # Hub ring radius
        for i, project in enumerate(center_hub_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    # High ring (blue) - smaller than hub
    if center_high_connections:
        angles = np.linspace(0, 2*np.pi, len(center_high_connections), endpoint=False)
        radius = 0.3  # High ring radius
        for i, project in enumerate(center_high_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    # Medium ring (green) - outside high
    if center_medium_connections:
        angles = np.linspace(0, 2*np.pi, len(center_medium_connections), endpoint=False)
        radius = 0.45  # Medium ring radius
        for i, project in enumerate(center_medium_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    # Low ring (grey) - outermost
    if center_low_connections:
        # For single project, position at 12 o'clock to balance the layout
        if len(center_low_connections) == 1:
            pos[center_low_connections[0]] = (0, 0.6)
        else:
            angles = np.linspace(0, 2*np.pi, len(center_low_connections), endpoint=False)
            radius = 0.6  # Low ring radius
            for i, project in enumerate(center_low_connections):
                angle = angles[i]
                pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    # Draw edges first (behind nodes) - only draw edges between nodes that are in pos
    edges_to_draw = [(u, v) for u, v in G.edges() if u in pos and v in pos]
    
    if edges_to_draw:
        # Separate hub edges from other edges
        tokr_hub_edges = []
        other_edges = []
        
        for u, v in edges_to_draw:
            if u == 'CIA' or v == 'CIA':
                # Determine if this is a hub connection
                target_node = v if u == 'CIA' else u
                circle_number = project_connection_counts.get(target_node, 1)
                
                if circle_number >= 4:  # Hub (4+)
                    tokr_hub_edges.append((u, v))
                else:
                    other_edges.append((u, v))
            else:
                other_edges.append((u, v))
        
        # Draw all non-hub edges first (light gray, thin, 25% transparent)
        if other_edges:
            nx.draw_networkx_edges(G, pos, edgelist=other_edges, 
                                 edge_color='lightgray', width=0.5, alpha=0.25, style='dashed')
        
        # Draw hub edges on top (orange, thick, no transparency)
        if tokr_hub_edges:
            nx.draw_networkx_edges(G, pos, edgelist=tokr_hub_edges, 
                                 edge_color='#ff8c00', width=4)

    # Draw nodes by category with different sizes and colors
    # Hub Ring (Orange) - 2000-3600 based on connections (doubled), 10% transparent
    if center_hub_connections:
        hub_nodes = center_hub_connections
        hub_sizes = []
        for project in hub_nodes:
            connections = project_connection_counts.get(project, 1)
            size = max(2000, min(3600, connections * 60))  # Hub: 2000-3600 (doubled)
            hub_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes, node_size=hub_sizes,
                              node_color='#ff8c00', alpha=0.1)
    
    # High Ring (Blue) - 1200-1900 based on connections (doubled), 10% transparent
    if center_high_connections:
        high_nodes = center_high_connections
        high_sizes = []
        for project in high_nodes:
            connections = project_connection_counts.get(project, 1)
            size = max(1200, min(1900, connections * 50))  # High: 1200-1900 (doubled)
            high_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes, node_size=high_sizes,
                              node_color='#4682b4', alpha=0.1)
    
    # Medium Ring (Green) - 600-1100 based on connections (doubled), 10% transparent
    if center_medium_connections:
        medium_nodes = center_medium_connections
        medium_sizes = []
        for project in medium_nodes:
            connections = project_connection_counts.get(project, 1)
            size = max(600, min(1100, connections * 40))  # Medium: 600-1100 (doubled)
            medium_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes, node_size=medium_sizes,
                              node_color='#90ee90', alpha=0.1)
    
    # Low Ring (Grey) - 400-500 based on connections (doubled), 10% transparent
    if center_low_connections:
        low_nodes = center_low_connections
        low_sizes = []
        for project in low_nodes:
            connections = project_connection_counts.get(project, 1)
            size = max(400, min(500, connections * 30))  # Low: 400-500 (doubled)
            low_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes, node_size=low_sizes,
                              node_color='#d3d3d3', alpha=0.1)

    # Center node (CIA) - largest, dark blue
    nx.draw_networkx_nodes(G, pos, nodelist=['CIA'], node_size=4000,
                          node_color='#1f4e79', alpha=0.9)

    # Add labels above each circle
    for node in G.nodes():
        if node in pos:
            x, y = pos[node]
            if node == 'CIA':
                # Center node gets project name instead of key
                plt.text(x, y+0.03, 'CIA', ha='center', va='bottom', fontsize=16, fontweight='bold', color='black')
            else:
                plt.text(x, y+0.03, node, ha='center', va='bottom', fontsize=12, color='black')

    # Add numbers inside each circle
    for node in G.nodes():
        if node in pos and node != 'CIA':
            x, y = pos[node]
            connections = project_connection_counts.get(node, 1)
            plt.text(x, y, str(connections), ha='center', va='center', 
                    fontsize=10, fontweight='bold', color='black')

    # Add center number
    plt.text(0, 0, str(len(cia_connections)), ha='center', va='center', 
            fontsize=16, fontweight='bold', color='white')

    # Add legend
    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', label='CIA (Center)',
                   markerfacecolor='#1f4e79', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Hub Ring (4+ connections)',
                   markerfacecolor='#ff8c00', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='High Ring (3 connections)',
                   markerfacecolor='#4682b4', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Medium Ring (2 connections)',
                   markerfacecolor='#90ee90', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Low Ring (1 connection)',
                   markerfacecolor='#d3d3d3', markersize=10)
    ]

    plt.legend(handles=legend_elements, loc='upper left',
              bbox_to_anchor=(0.02, 0.98), fontsize=18, frameon=False)

    # Create table below the legend
    table_lines = []
    
    # Add header
    header = f"{'Project':<6s}{'Links':>6s}{'CIA':>6s}{'Total':>6s}"
    table_lines.append(header)
    
    # Sort projects by circle number (descending), then by CIA links (descending)
    sorted_projects = sorted(cia_connections, key=lambda x: (project_connection_counts.get(x, 0), 
                                                           sum(relationships_df[(relationships_df['ProjectKey'] == 'CIA') & 
                                                                               (relationships_df['ConnectedProject'] == x)]['LinkCount'].tolist()) if len(relationships_df[(relationships_df['ProjectKey'] == 'CIA') & (relationships_df['ConnectedProject'] == x)]) > 0 else 
                                                           sum(relationships_df[(relationships_df['ProjectKey'] == x) & 
                                                                               (relationships_df['ConnectedProject'] == 'CIA')]['LinkCount'].tolist()) if len(relationships_df[(relationships_df['ProjectKey'] == x) & (relationships_df['ConnectedProject'] == 'CIA')]) > 0 else 0), reverse=True)
    
    for project in sorted_projects:
        # Get CIA to project links
        cia_to_project_links = 0
        for _, row in relationships_df.iterrows():
            if (row['ProjectKey'] == 'CIA' and row['ConnectedProject'] == project) or \
               (row['ProjectKey'] == project and row['ConnectedProject'] == 'CIA'):
                cia_to_project_links += row['LinkCount']
        
        # Get total project connections
        total_project_connections = 0
        for _, row in relationships_df.iterrows():
            if row['ProjectKey'] == project or row['ConnectedProject'] == project:
                total_project_connections += row['LinkCount']
        
        # Get the number that appears inside the circle (project_connection_counts)
        circle_number = project_connection_counts.get(project, 1)
        
        # Determine ring color based on circle_number (connections to other projects)
        if circle_number >= 4:  # Hub (4+)
            color = '#ff8c00'
        elif circle_number == 3:  # High (3)
            color = '#4682b4'
        elif circle_number == 2:  # Medium (2)
            color = '#90ee90'
        else:  # Low (1)
            color = '#d3d3d3'
        
        line_text = f"{project:<6s}{circle_number:>6d}{cia_to_project_links:>6d}{total_project_connections:>6d}"
        table_lines.append(line_text)
    
    # Display each line with color filled background (like legend) instead of table
    for i, line in enumerate(table_lines):
        y_position = 0.85 - (i * 0.025)  # Start below legend, move down
        
        if i == 0:  # Header
            plt.figtext(0.02, y_position, line, fontsize=18, fontfamily='monospace',
                       verticalalignment='bottom', color='black', fontweight='bold')
        else:
            # Extract project name to determine color
            project = line.split()[0]  # Get first word (project name)
            
            # Determine ring color based on column 2 (circle_number - connections to other projects)
            circle_number = project_connection_counts.get(project, 1)
            if circle_number >= 4:  # Hub (4+)
                bg_color = '#ff8c00'  # Orange, 50% transparent
            elif circle_number == 3:  # High (3)
                bg_color = '#4682b4'  # Blue, 50% transparent
            elif circle_number == 2:  # Medium (2)
                bg_color = '#90ee90'  # Green, 50% transparent
            else:  # Low (1)
                bg_color = '#d3d3d3'  # Gray, 50% transparent
            
            plt.figtext(0.02, y_position, line, fontsize=18, fontfamily='monospace',
                       verticalalignment='bottom', color='black',
                       bbox=dict(boxstyle='round,pad=0.1', facecolor=bg_color, alpha=0.5))

    plt.axis('off')
    plt.tight_layout()
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()

    return G, len(center_hub_connections), len(center_high_connections), len(center_medium_connections), len(center_low_connections), cia_connections

def main():
    """Main function to generate the CIA-centered diagram with proper naming"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Final Filtered - Exclude ORL TOKR RC - Anon - Official.csv'
    relationships_df = pd.read_csv(csv_file)
    
    print("Found", len(relationships_df), "project relationships")
    print("Total links:", relationships_df['LinkCount'].sum())
    
    print("\n" + "="*60)
    print("Creating CIA-Centered Project Affinity Diagram...")
    print("="*60)
    
    try:
        success = create_cia_centered_diagram(relationships_df, 'cia_centered_diagram.png')
        if success[0] is not None:
            print(f"[SUCCESS] Created CIA-centered diagram")
            
            # Print summary statistics
            G, hub_count, high_count, medium_count, low_count, center_connections = success
            
            print(f"\nCIA Summary Statistics:")
            unique_projects = set()
            for _, row in relationships_df.iterrows():
                unique_projects.add(row['ProjectKey'])
                unique_projects.add(row['ConnectedProject'])
            print(f"Total Projects in Dataset: {len(unique_projects)}")
            center_connections = list(G.neighbors('CIA'))
            print(f"CIA Total Direct Connections: {len(center_connections)}")
            
            # Calculate project connection counts for summary
            project_connection_counts = {}
            for conn in center_connections:
                connections = 0
                project_rels = relationships_df[(relationships_df['ProjectKey'] == conn) | (relationships_df['ConnectedProject'] == conn)]
                
                for _, row in project_rels.iterrows():
                    if row['ProjectKey'] == conn:
                        other_project = row['ConnectedProject']
                    else:
                        other_project = row['ProjectKey']
                    
                    if other_project in center_connections + ['CIA']:
                        connections += 1
                
                project_connection_counts[conn] = connections
            
            print(f"CIA Hub Connections: {len([n for n in center_connections if project_connection_counts.get(n, 0) >= 4])}")
            print(f"CIA High Connections: {len([n for n in center_connections if project_connection_counts.get(n, 0) == 3])}")
            print(f"CIA Medium Connections: {len([n for n in center_connections if project_connection_counts.get(n, 0) == 2])}")
            print(f"CIA Low Connections: {len([n for n in center_connections if project_connection_counts.get(n, 0) == 1])}")
            
            print(f"\nCIA's Top Connected Projects:")
            center_neighbors = [(n, G.nodes[n]['link_count']) for n in center_connections]
            center_neighbors.sort(key=lambda x: x[1], reverse=True)
            for j, (project, count) in enumerate(center_neighbors[:15], 1):
                # Get the specific link count between CIA and this project
                cia_to_project_links = 0
                for _, row in relationships_df.iterrows():
                    if (row['ProjectKey'] == 'CIA' and row['ConnectedProject'] == project) or \
                       (row['ProjectKey'] == project and row['ConnectedProject'] == 'CIA'):
                        cia_to_project_links += row['LinkCount']
                
                print(f"{j:2d}. {project:8s} - {cia_to_project_links:3d} links to CIA, {count:4d} total links")
        else:
            print(f"[FAILED] Failed to create CIA-centered diagram")
    except Exception as e:
        print(f"[ERROR] Error creating CIA-centered diagram: {str(e)}")

if __name__ == "__main__":
    main()