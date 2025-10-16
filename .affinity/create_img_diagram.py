#!/usr/bin/env python3
"""
Create IMG-Centered Diagram with Proper Naming Convention
Based on the working TOKR script - EXACT COPY with IMG substituted for TOKR
"""

import pandas as pd
import matplotlib.pyplot as plt
import networkx as nx
import numpy as np
import warnings
warnings.filterwarnings('ignore')

def create_cia_centered_diagram(relationships_df, output_file='cia_centered_diagram.png', weighted_sum=0):
    """Create a IMG-centered radial affinity diagram with ring layout and professional styling."""

    G = nx.Graph()

    # First, calculate total link counts for each project
    project_totals = {}
    for _, row in relationships_df.iterrows():
        proj1 = row['ProjectKey']
        proj2 = row['ConnectedProject']
        link_count = row['LinkCount']
        
        if proj1 not in project_totals:
            project_totals[proj1] = 0
        if proj2 not in project_totals:
            project_totals[proj2] = 0
        
        project_totals[proj1] += link_count
        project_totals[proj2] += link_count

    for project_key, total_link_count in project_totals.items():
        G.add_node(project_key, label=project_key, link_count=total_link_count)

    for _, row in relationships_df.iterrows():
        source = row['ProjectKey']
        target = row['ConnectedProject']
        link_count = row['LinkCount']
        if G.has_node(source) and G.has_node(target):
            G.add_edge(source, target, weight=link_count)

    plt.figure(figsize=(24, 20))

    if 'IMG' not in G.nodes():
        print("Warning: IMG project not found in data. Cannot create IMG-centered diagram.")
        return None, 0, 0, 0, 0, {}, []

    cia_connections = list(G.neighbors('IMG'))
    print(f"IMG has {len(cia_connections)} direct connections")

    center_hub_connections = []
    center_high_connections = []
    center_medium_connections = []
    center_low_connections = []

    cia_connected_projects = list(cia_connections)
    project_connection_counts = {}
    
    for conn in cia_connections:
        connections = 0
        project_rels = relationships_df[(relationships_df['ProjectKey'] == conn) | (relationships_df['ConnectedProject'] == conn)]
        
        for _, row in project_rels.iterrows():
            if row['ProjectKey'] == conn:
                other_project = row['ConnectedProject']
            else:
                other_project = row['ProjectKey']
            
            if other_project in cia_connected_projects + ['IMG']:
                connections += 1
        
        project_connection_counts[conn] = connections
        
        if connections >= 6:
            center_hub_connections.append(conn)
        elif connections >= 4:
            center_high_connections.append(conn)
        elif connections >= 2:
            center_medium_connections.append(conn)
        else:
            center_low_connections.append(conn)

    print(f"IMG filtered connections: {len(center_hub_connections + center_high_connections + center_medium_connections + center_low_connections)}")
    print(f"  Hub (6+): {len(center_hub_connections)}, High (4-5): {len(center_high_connections)}, Medium (2-3): {len(center_medium_connections)}, Low (1): {len(center_low_connections)}")

    pos = {}
    pos['IMG'] = (0, 0)

    if center_hub_connections:
        angles = np.linspace(0, 2*np.pi, len(center_hub_connections), endpoint=False)
        radius = 0.15
        for i, project in enumerate(center_hub_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    if center_high_connections:
        angles = np.linspace(0, 2*np.pi, len(center_high_connections), endpoint=False)
        radius = 0.3
        for i, project in enumerate(center_high_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    if center_medium_connections:
        angles = np.linspace(0, 2*np.pi, len(center_medium_connections), endpoint=False)
        radius = 0.45
        for i, project in enumerate(center_medium_connections):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    if center_low_connections:
        if len(center_low_connections) == 1:
            angle = np.pi/2
        else:
            angles = np.linspace(0, 2*np.pi, len(center_low_connections), endpoint=False)
            angles = angles + np.pi/2
        radius = 0.6
        for i, project in enumerate(center_low_connections):
            if len(center_low_connections) == 1:
                angle = np.pi/2
            else:
                angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))

    edges_to_draw = [(u, v) for u, v in G.edges() if u in pos and v in pos]
    if edges_to_draw:
        cia_hub_edges = []
        other_edges = []
        
        for u, v in edges_to_draw:
            if u == 'IMG' or v == 'IMG':
                target_node = v if u == 'IMG' else u
                circle_number = project_connection_counts.get(target_node, 1)
                
                if circle_number >= 6:
                    cia_hub_edges.append((u, v))
                else:
                    other_edges.append((u, v))
            else:
                other_edges.append((u, v))
        
        if other_edges:
            nx.draw_networkx_edges(G, pos, edgelist=other_edges, alpha=0.25, edge_color='lightgray', width=0.5)
        
        if cia_hub_edges:
            nx.draw_networkx_edges(G, pos, edgelist=cia_hub_edges, alpha=1.0, edge_color='#ff8c00', width=1.0)

    if 'IMG' in pos:
        nx.draw_networkx_nodes(G, pos, nodelist=['IMG'],
                              node_color='#1f4e79', node_size=4000, alpha=0.9)

    hub_nodes_in_pos = [n for n in center_hub_connections if n in pos]
    if hub_nodes_in_pos:
        hub_sizes = []
        for node in hub_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(2000, min(3600, connections * 60))
            hub_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes_in_pos,
                              node_color='#ff8c00', node_size=hub_sizes, alpha=0.9)

    high_nodes_in_pos = [n for n in center_high_connections if n in pos]
    if high_nodes_in_pos:
        high_sizes = []
        for node in high_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(1200, min(1900, connections * 50))
            high_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes_in_pos,
                              node_color='#4682b4', node_size=high_sizes, alpha=0.9)

    medium_nodes_in_pos = [n for n in center_medium_connections if n in pos]
    if medium_nodes_in_pos:
        medium_sizes = []
        for node in medium_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(600, min(1100, connections * 40))
            medium_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes_in_pos,
                              node_color='#90ee90', node_size=medium_sizes, alpha=0.9)

    low_nodes_in_pos = [n for n in center_low_connections if n in pos]
    if low_nodes_in_pos:
        low_sizes = []
        for node in low_nodes_in_pos:
            connections = project_connection_counts[node]
            size = max(400, min(500, connections * 30))
            low_sizes.append(size)
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes_in_pos,
                              node_color='#d3d3d3', node_size=low_sizes, alpha=0.9)

    for node in G.nodes():
        if node in pos:
            x, y = pos[node]
            if node == 'IMG':
                plt.text(x, y+0.05, "Image Management", ha='center', va='center', fontsize=16, weight='bold', color='black')
            else:
                plt.text(x, y+0.03, node, ha='center', va='center', fontsize=14, weight='bold', color='black')

    for node in G.nodes():
        if node in pos:
            x, y = pos[node]
            if node == 'IMG':
                count = str(len(cia_connections))
            else:
                if node in project_connection_counts:
                    count = str(project_connection_counts[node])
                else:
                    count = "1"
            
            plt.text(x, y, count, ha='center', va='center', fontsize=10, weight='bold', color='white')

    plt.title(f'Image Management (IMG) - {len(cia_connections)} Links\n(Filtered: Unresolved Issues, 90-Day Activity)',
              fontsize=20, fontweight='bold', pad=20)

    legend_elements = [
        plt.Line2D([0], [0], marker='o', color='w', label='IMG (Center)',
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
    
    center_connections = list(G.neighbors('IMG'))
    center_neighbors = [(n, G.nodes[n]['link_count']) for n in center_connections]
    
    def sort_key(item):
        project = item[0]
        circle_number = project_connection_counts.get(project, 1)
        
        cia_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'IMG' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'IMG')):
                cia_links = row['LinkCount']
                break
        
        return (circle_number, cia_links)
    
    center_neighbors.sort(key=sort_key, reverse=True)
    
    table_lines = []
    
    for project, connections in center_neighbors:
        cia_to_project_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'IMG' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'IMG')):
                cia_to_project_links = row['LinkCount']
                break
        
        total_project_connections = 0
        for _, row in relationships_df.iterrows():
            if row['ProjectKey'] == project or row['ConnectedProject'] == project:
                total_project_connections += row['LinkCount']
        
        circle_number = project_connection_counts.get(project, 1)
        
        line_text = f"{project:<6s}{circle_number:>6d}{cia_to_project_links:>6d}{total_project_connections:>6d}"
        table_lines.append(line_text)
    
    y_position = 0.02
    line_height = 0.02
    
    for line in table_lines:
        project = line.split()[0]
        
        circle_number = project_connection_counts.get(project, 1)
        if circle_number >= 6:
            bg_color = '#ff8c00'
        elif circle_number >= 4:
            bg_color = '#4682b4'
        elif circle_number >= 2:
            bg_color = '#90ee90'
        else:
            bg_color = '#d3d3d3'
        
        plt.figtext(0.02, y_position, line, fontsize=18, fontfamily='monospace',
                    verticalalignment='bottom', color='black',
                    bbox=dict(boxstyle='round,pad=0.1', facecolor=bg_color, alpha=0.5))
        
        y_position += line_height
    
    y_position = 0.02 + (len(table_lines) * line_height)
    total_rows = len(table_lines)
    
    total_cia_links = 0
    total_project_connections = 0
    
    for project, connections in center_neighbors:
        cia_to_project_links = 0
        for _, row in relationships_df.iterrows():
            if ((row['ProjectKey'] == 'IMG' and row['ConnectedProject'] == project) or 
                (row['ProjectKey'] == project and row['ConnectedProject'] == 'IMG')):
                cia_to_project_links = row['LinkCount']
                break
        
        total_project_connections_for_this = 0
        for _, row in relationships_df.iterrows():
            if row['ProjectKey'] == project or row['ConnectedProject'] == project:
                total_project_connections_for_this += row['LinkCount']
        
        total_cia_links += cia_to_project_links
        total_project_connections += total_project_connections_for_this
    
    totals_line = f"{total_rows:<6d}{weighted_sum:>6d}{total_cia_links:>6d}{total_project_connections:>6d}"
    
    plt.figtext(0.02, y_position, totals_line, fontsize=18, fontfamily='monospace',
                verticalalignment='bottom', color='black')

    plt.axis('off')
    plt.axis('equal')
    plt.tight_layout()

    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except Exception as e:
        print(f"Error saving diagram: {e}")
        plt.savefig(output_file, dpi=150, bbox_inches='tight')

    print(f"Diagram saved as: {output_file}")

    return G, len(center_hub_connections), len(center_high_connections), len(center_medium_connections), len(center_low_connections), cia_connections

def main():
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    relationships_df = pd.read_csv(csv_file)
    
    print("Found", len(relationships_df), "project relationships")
    print("Total links:", relationships_df['LinkCount'].sum())
    
    print("\n" + "="*60)
    print("Creating IMG-Centered Project Affinity Diagram...")
    print("="*60)
    
    temp_filename = 'cia_temp.png'
    G, hub_count, high_count, medium_count, low_count, cia_connections = create_cia_centered_diagram(
        relationships_df, temp_filename)
    
    if G is not None:
        center_count = hub_count + high_count + medium_count + low_count
        weighted_sum = (hub_count * 4) + (high_count * 3) + (medium_count * 2) + (low_count * 1)
        
        G, hub_count, high_count, medium_count, low_count, cia_connections = create_cia_centered_diagram(
            relationships_df, temp_filename, weighted_sum)
        
        proper_filename = f'{weighted_sum:04d}_{center_count:04d}_{hub_count:04d}_{high_count:04d}_{medium_count:04d}_{low_count:04d}_IMG.png'
        
        import os
        if os.path.exists(temp_filename):
            if os.path.exists(proper_filename):
                os.remove(proper_filename)
            os.rename(temp_filename, proper_filename)
        
        print(f"\nIMG-CENTERED PROJECT AFFINITY ANALYSIS SUMMARY")
        center_connections = list(G.neighbors('IMG'))
        print(f"IMG Total Direct Connections: {len(center_connections)}")
    
    print(f"\n{'='*60}")
    print(f"IMG PROJECT PROCESSING COMPLETED!")
    print(f"Files generated: 1")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
