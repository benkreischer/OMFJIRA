#!/usr/bin/env python3
"""
Create CARD-Centered Diagram with Proper Naming Convention
Based on the original script that created the numbered filename format
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

def create_card_centered_diagram(relationships_df, output_file='card_centered_diagram.png', weighted_sum=0):
    """Create a CARD-centered radial affinity diagram with ring layout and professional styling."""

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

    # Check if CARD exists in the graph
    if 'CARD' not in G.nodes():
        print("Warning: CARD project not found in data. Cannot create CARD-centered diagram.")
        return None, 0, 0, 0, 0, {}, []

    # Get CARD's direct connections
    card_connections = list(G.neighbors('CARD'))
    print(f"CARD has {len(card_connections)} direct connections")

    # Categorize connected projects by their connectivity to OTHER projects in the CARD list
    center_hub_connections = []
    center_high_connections = []
    center_medium_connections = []
    center_low_connections = []

    # Calculate connections for each project to other projects in the CARD list
    card_connected_projects = list(card_connections)
    project_connection_counts = {}
    
    for conn in card_connections:
        connections = 0
        # Count connections to other projects in the CARD list (including CARD)
        project_rels = relationships_df[(relationships_df['ProjectKey'] == conn) | (relationships_df['ConnectedProject'] == conn)]
        
        for _, row in project_rels.iterrows():
            if row['ProjectKey'] == conn:
                other_project = row['ConnectedProject']
            else:
                other_project = row['ProjectKey']
            
            # Count connections to other projects in the CARD list (including CARD)
            if other_project in card_connected_projects + ['CARD']:
                connections += 1
        
        project_connection_counts[conn] = connections
        
        # Categorize based on NEW thresholds: Low=1, Medium=2-3, High=4-5, Hub=6+
        if connections >= 6:
            center_hub_connections.append(conn)
        elif connections >= 4:
            center_high_connections.append(conn)
        elif connections >= 2:
            center_medium_connections.append(conn)
        else:  # connections == 1
            center_low_connections.append(conn)

    print(f"CARD filtered connections: {len(center_hub_connections + center_high_connections + center_medium_connections + center_low_connections)}")
    print(f"  Hub (6+): {len(center_hub_connections)}, High (4-5): {len(center_high_connections)}, Medium (2-3): {len(center_medium_connections)}, Low (1): {len(center_low_connections)}")

    # Create positioning with proper concentric rings
    pos = {}

    # CARD at center
    pos['CARD'] = (0, 0)

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
            angle = np.pi/2  # 12 o'clock position
        else:
            angles = np.linspace(0, 2*np.pi, len(center_low_connections), endpoint=False)
            # Offset to start at 12 o'clock for better balance
            angles = angles + np.pi/2
        radius = 0.6  # Low ring radius
        for i, project in enumerate(center_low_connections):
            if len(center_low_connections) == 1:
                angle = np.pi/2  # 12 o'clock position
            else:
                angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    # Draw edges with simplified coloring - only hub edges are orange
    edges_to_draw = [(u, v) for u, v in G.edges() if u in pos and v in pos]
    if edges_to_draw:
        # Separate CARD hub edges from all other edges
        card_hub_edges = []
        other_edges = []
        
        for u, v in edges_to_draw:
            if u == 'CARD' or v == 'CARD':
                # Determine if this is a hub connection
                target_node = v if u == 'CARD' else u
                circle_number = project_connection_counts.get(target_node, 1)
                
                if circle_number >= 6:  # Hub (6+)
                    card_hub_edges.append((u, v))
                else:
                    other_edges.append((u, v))
            else:
                other_edges.append((u, v))
        
        # Draw all non-hub edges first (light gray, thin, 25% transparent)
        if other_edges:
            nx.draw_networkx_edges(G, pos, edgelist=other_edges, alpha=0.25, edge_color='lightgray', width=0.5)
        
        # Draw hub edges on top (orange, thick)
        if card_hub_edges:
            nx.draw_networkx_edges(G, pos, edgelist=card_hub_edges, alpha=1.0, edge_color='#ff8c00', width=1.0)

    # Draw nodes by category with proper sizing (from yesterday's thresholds)
    # Center (CARD) - Fixed size 4000, 10% transparent
    if 'CARD' in pos:
        nx.draw_networkx_nodes(G, pos, nodelist=['CARD'],
                              node_color='#1f4e79', node_size=4000, alpha=0.9)

    # Hub Ring (Orange) - 2000-3600 based on connections (doubled), 50% transparent
    hub_nodes_in_pos = [n for n in center_hub_connections if n in pos]
    if hub_nodes_in_pos:
        hub_sizes = []
        for node in hub_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(2000, min(3600, connections * 60))  # Hub: 2000-3600 (doubled)
            hub_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes_in_pos,
                              node_color='#ff8c00', node_size=hub_sizes, alpha=0.9)

    # High Ring (Blue) - 1200-1900 based on connections (doubled), 10% transparent
    high_nodes_in_pos = [n for n in center_high_connections if n in pos]
    if high_nodes_in_pos:
        high_sizes = []
        for node in high_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(1200, min(1900, connections * 50))   # High: 1200-1900 (doubled)
            high_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes_in_pos,
                              node_color='#4682b4', node_size=high_sizes, alpha=0.9)

    # Medium Ring (Green) - 600-1100 based on connections (doubled), 10% transparent
    medium_nodes_in_pos = [n for n in center_medium_connections if n in pos]
    if medium_nodes_in_pos:
        medium_sizes = []
        for node in medium_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(600, min(1100, connections * 40))  # Medium: 600-1100 (doubled)
            medium_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes_in_pos,
                              node_color='#90ee90', node_size=medium_sizes, alpha=0.9)

    # Low Ring (Grey) - 400-500 based on connections (doubled), 10% transparent
    low_nodes_in_pos = [n for n in center_low_connections if n in pos]
    if low_nodes_in_pos:
        low_sizes = []
        for node in low_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(400, min(500, connections * 30))  # Low: 400-500 (doubled)
            low_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes_in_pos,
                              node_color='#d3d3d3', node_size=low_sizes, alpha=0.9)

    # Draw node labels (project keys ABOVE circles) - positioned immediately above each circle
    for node in G.nodes():
        if node in pos:
            x, y = pos[node]
            # Position label immediately above the circle with uniform offset for all rings
            if node == 'CARD':
                # CARD shows "CARD" instead of the project key
                plt.text(x, y+0.05, "CARD", ha='center', va='center', fontsize=16, weight='bold', color='black')
            else:
                # All other project keys use same offset
                plt.text(x, y+0.03, node, ha='center', va='center', fontsize=14, weight='bold', color='black')

    # Draw count labels INSIDE circles - centered in white
    for node in G.nodes():
        if node in pos:
            x, y = pos[node]
            if node == 'CARD':
                # CARD shows the count of projects it's connected to on the chart
                count = str(len(card_connections))
            else:
                # Connected projects show their connection count to other projects in the CARD list
                if node in project_connection_counts:
                    count = str(project_connection_counts[node])
                else:
                    count = "1"
            
            # Position count centered in the circle
            plt.text(x, y, count, ha='center', va='center', fontsize=10, weight='bold', color='white')

    # Add title
    plt.title(f'CARD - {len(card_connections)} Links\n(Filtered: Unresolved Issues, 90-Day Activity)',
              fontsize=20, fontweight='bold', pad=20)

    # Add legend
    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', label='CARD (Center)',
                   markerfacecolor='#1f4e79', markersize=12),
        plt.Line2D([0], [0], marker='o', color='w', label='Hub Ring (6+ connections)',
                   markerfacecolor='#ff8c00', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='High Ring (4-5 connections)',
                   markerfacecolor='#4682b4', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Medium Ring (2-3 connections)',
                   markerfacecolor='#90ee90', markersize=10),
        plt.Line2D([0], [0], marker='o', color='w', label='Low Ring (1 connection)',
                   markerfacecolor='#d3d3d3', markersize=10)
    ]

    plt.legend(handles=legend_elements, loc='upper left',
              bbox_to_anchor=(0.02, 0.98), fontsize=18, frameon=False)
    
    # Add data table below the legend (styled like legend)
    center_connections = list(G.neighbors('CARD'))
    center_neighbors = [(n, G.nodes[n]['link_count']) for n in center_connections]
    
    # Sort by column 2 (circle number) descending, then by column 3 (CARD links) descending
    def sort_key(item):
        project = item[0]
        # Get the circle number (column 2)
        circle_number = project_connection_counts.get(project, 1)
        
        # Get CARD links (column 3)
        card_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'CARD' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'CARD')):
                card_links = row['LinkCount']
                break
        
        return (circle_number, card_links)  # Positive for ascending order, then reverse
    
    center_neighbors.sort(key=sort_key, reverse=True)  # Reverse for descending order
    
    # Create table text lines
    table_lines = []
    
    for project, connections in center_neighbors:
        # Get the specific link count between CARD and this project
        card_to_project_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'CARD' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'CARD')):
                card_to_project_links = row['LinkCount']
                break
        
        # Get total project connections (sum of all links for this project)
        total_project_connections = 0
        for _, row in relationships_df.iterrows():
            if row['ProjectKey'] == project or row['ConnectedProject'] == project:
                total_project_connections += row['LinkCount']
        
        # Determine ring color based on connections
        if connections >= 15:  # Hub
            color = '#ff8c00'
        elif connections >= 11:  # High
            color = '#4682b4'
        elif connections >= 6:  # Medium
            color = '#90ee90'
        else:  # Low
            color = '#d3d3d3'
        
        # Get the number that appears inside the circle (project_connection_counts)
        circle_number = project_connection_counts.get(project, 1)
        
        line_text = f"{project:<6s}{circle_number:>6d}{card_to_project_links:>6d}{total_project_connections:>6d}"
        table_lines.append(line_text)
    
    # Display each line with color filled background (like legend) instead of table
    y_position = 0.02
    line_height = 0.02  # Back to original spacing
    
    for line in table_lines:
        # Extract project name to determine color
        project = line.split()[0]  # Get first word (project name)
        
        # Determine ring color based on column 2 (circle_number - connections to other projects)
        circle_number = project_connection_counts.get(project, 1)
        if circle_number >= 6:  # Hub (6+)
            bg_color = '#ff8c00'  # Orange, 50% transparent
        elif circle_number >= 4:  # High (4-5)
            bg_color = '#4682b4'  # Blue, 50% transparent
        elif circle_number >= 2:  # Medium (2-3)
            bg_color = '#90ee90'  # Green, 50% transparent
        else:  # Low (1)
            bg_color = '#d3d3d3'  # Gray, 50% transparent
        
        plt.figtext(0.02, y_position, line, fontsize=18, fontfamily='monospace',
                    verticalalignment='bottom', color='black',
                    bbox=dict(boxstyle='round,pad=0.1', facecolor=bg_color, alpha=0.5))
        
        y_position += line_height
    
    # Add totals row at the top
    y_position = 0.02 + (len(table_lines) * line_height)  # Position directly above table with no gap
    total_rows = len(table_lines)
    
    # Calculate totals for columns 3 and 4
    total_card_links = 0
    total_project_connections = 0
    
    for project, connections in center_neighbors:
        # Get the specific link count between CARD and this project
        card_to_project_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'CARD' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'CARD')):
                card_to_project_links = row['LinkCount']
                break
        
        # Get total project connections (sum of all links for this project)
        total_project_connections_for_this = 0
        for _, row in relationships_df.iterrows():
            if row['ProjectKey'] == project or row['ConnectedProject'] == project:
                total_project_connections_for_this += row['LinkCount']
        
        total_card_links += card_to_project_links
        total_project_connections += total_project_connections_for_this
    
    # Create totals line: Count of rows, Weighted sum, Total CARD links, Total project connections
    totals_line = f"{total_rows:<6d}{weighted_sum:>6d}{total_card_links:>6d}{total_project_connections:>6d}"
    
    plt.figtext(0.02, y_position, totals_line, fontsize=18, fontfamily='monospace',
                verticalalignment='bottom', color='black')

    plt.axis('off')
    plt.axis('equal')
    plt.tight_layout()

    # Save with high quality
    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except Exception as e:
        print(f"Error saving diagram: {e}")
        # Fallback save method
        plt.savefig(output_file, dpi=150, bbox_inches='tight')

    print(f"Diagram saved as: {output_file}")

    return G, len(center_hub_connections), len(center_high_connections), len(center_medium_connections), len(center_low_connections), card_connections

def main():
    """Main function to generate the CARD-centered diagram with proper naming"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    relationships_df = pd.read_csv(csv_file)
    
    print("Found", len(relationships_df), "project relationships")
    print("Total links:", relationships_df['LinkCount'].sum())
    
    print("\n" + "="*60)
    print("Creating CARD-Centered Project Affinity Diagram...")
    print("="*60)
    
    # Create the diagram
    temp_filename = 'card_temp.png'
    G, hub_count, high_count, medium_count, low_count, card_connections = create_card_centered_diagram(
        relationships_df, temp_filename)
    
    if G is not None:
        # Calculate the actual direct connections shown in diagram
        center_count = hub_count + high_count + medium_count + low_count
        
        # Calculate total sum of connection counts shown in the diagram
        total_sum = 0
        if G is not None:
            # Get all connected projects and sum their network connection counts (not total link counts)
            connected_projects = [node for node in G.nodes() if node != 'CARD']
            for project in connected_projects:
                if project in G.nodes():
                    connections = G.nodes[project]['link_count']
                    total_sum += connections
        
        # Calculate weighted sum based on ring counts: Hub*4 + High*3 + Medium*2 + Low*1
        weighted_sum = (hub_count * 4) + (high_count * 3) + (medium_count * 2) + (low_count * 1)
        
        # Recreate the diagram with weighted_sum for the totals row
        G, hub_count, high_count, medium_count, low_count, card_connections = create_card_centered_diagram(
            relationships_df, temp_filename, weighted_sum)
        
        # Create the enhanced filename with weighted sum at front, then ring counts
        proper_filename = f'{weighted_sum:04d}_{center_count:04d}_{hub_count:04d}_{high_count:04d}_{medium_count:04d}_{low_count:04d}_CARD.png'
        
        # Rename the file with error handling
        import os
        if os.path.exists(temp_filename):
            if os.path.exists(proper_filename):
                os.remove(proper_filename)  # Remove existing file
            os.rename(temp_filename, proper_filename)
        
        # Print summary statistics
        print(f"\nCARD-CENTERED PROJECT AFFINITY ANALYSIS SUMMARY")
        unique_projects = set()
        for _, row in relationships_df.iterrows():
            unique_projects.add(row['ProjectKey'])
            unique_projects.add(row['ConnectedProject'])
        print(f"Total Projects in Dataset: {len(unique_projects)}")
        center_connections = list(G.neighbors('CARD'))
        print(f"CARD Total Direct Connections: {len(center_connections)}")
        print(f"CARD Hub Connections: {len([n for n in center_connections if G.nodes[n]['link_count'] >= 15])}")
        print(f"CARD High Connections: {len([n for n in center_connections if 11 <= G.nodes[n]['link_count'] < 15])}")
        print(f"CARD Medium Connections: {len([n for n in center_connections if 6 <= G.nodes[n]['link_count'] < 11])}")
        print(f"CARD Low Connections: {len([n for n in center_connections if 1 <= G.nodes[n]['link_count'] < 6])}")
        
        print(f"\nCARD's Top Connected Projects:")
        center_neighbors = [(n, G.nodes[n]['link_count']) for n in center_connections]
        center_neighbors.sort(key=lambda x: x[1], reverse=True)
        for j, (project, count) in enumerate(center_neighbors[:15], 1):
            # Get the specific link count between CARD and this project
            card_to_project_links = 0
            for _, row in relationships_df.iterrows():
                if ((row['ProjectKey'] == 'CARD' and row['ConnectedProject'] == project) or 
                    (row['ProjectKey'] == project and row['ConnectedProject'] == 'CARD')):
                    card_to_project_links = row['LinkCount']
                    break
            
            print(f"{j:2d}. {project:8s} - {count:2d} total connections (CARD↔{project}: {card_to_project_links} links)")
    
    print(f"\n{'='*60}")
    print(f"CARD PROJECT PROCESSING COMPLETED!")
    print(f"Files generated: 1")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
