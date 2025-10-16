#!/usr/bin/env python3
"""
Create PAY-Centered Diagram with Proper Naming Convention
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

def create_pay_centered_diagram(project_summary, relationships_df, output_file):
    """Create PAY-centered diagram with proper ring layout and naming"""
    
    # Create network graph
    G = nx.Graph()
    
    # Add all projects as nodes
    for _, row in project_summary.iterrows():
        project = row['ProjectKey']
        link_count = row['LinkCount']
        
        # Determine connectivity category
        if link_count >= 15:
            size_category = 'Hub'
            color = '#ff8c00'  # Orange
        elif link_count >= 11:
            size_category = 'High'
            color = '#4682b4'  # Blue
        elif link_count >= 6:
            size_category = 'Medium'
            color = '#90ee90'  # Green
        elif link_count >= 1:
            size_category = 'Low'
            color = '#d3d3d3'  # Grey
        else:
            size_category = 'Isolated'
            color = '#d3d3d3'  # Grey
            
        G.add_node(project, 
                  link_count=link_count,
                  size_category=size_category,
                  color=color)
    
    # Add edges from relationships data
    for _, row in relationships_df.iterrows():
        source = row['ProjectKey']
        target = row['ConnectedProject']
        weight = row['LinkCount']
        
        if source in G.nodes() and target in G.nodes():
            G.add_edge(source, target, weight=weight)
    
    # Set up the plot
    plt.figure(figsize=(20, 16))
    
    # Check if PAY exists
    if 'PAY' not in G.nodes():
        print("Warning: PAY project not found in data.")
        return G, 0, 0, 0, 0, {}
    
    # Get PAY's direct connections
    pay_connections = list(G.neighbors('PAY'))
    print(f"PAY has {len(pay_connections)} direct connections")
    
    # Categorize connections by their actual link count TO PAY (not their total connectivity)
    center_hub_connections = []
    center_high_connections = []
    center_medium_connections = []
    center_low_connections = []
    
    for conn in pay_connections:
        # Get the actual link count between PAY and this project
        link_count_to_pay = G.edges[('PAY', conn)]['weight']
        
        if link_count_to_pay >= 15:
            center_hub_connections.append(conn)
        elif link_count_to_pay >= 11:
            center_high_connections.append(conn)
        elif link_count_to_pay >= 6:
            center_medium_connections.append(conn)
        elif link_count_to_pay >= 1:
            center_low_connections.append(conn)
    
    print(f"PAY filtered connections: {len(center_hub_connections + center_high_connections + center_medium_connections + center_low_connections)}")
    print(f"  Hub (15+): {len(center_hub_connections)}, High (11-14): {len(center_high_connections)}, Medium (6-10): {len(center_medium_connections)}, Low (1-5): {len(center_low_connections)}")
    
    # Create positioning
    pos = {}
    
    # PAY at center
    pos['PAY'] = (0, 0)
    
    # Position PAY's connections in proper concentric circles
    # Arrange all connected projects in a single concentric circle around PAY
    all_connected = center_hub_connections + center_high_connections + center_medium_connections + center_low_connections
    
    if all_connected:
        # Create a single concentric circle with all 8 projects
        angles = np.linspace(0, 2*np.pi, len(all_connected), endpoint=False)
        radius = 1.0  # Single radius for all projects
        
        for i, project in enumerate(all_connected):
            angle = angles[i]
            pos[project] = (radius * np.cos(angle), radius * np.sin(angle))
    
    # Draw edges first (only for nodes that have positions)
    edges_to_draw = [(u, v) for u, v in G.edges() if u in pos and v in pos]
    if edges_to_draw:
        nx.draw_networkx_edges(G, pos, edgelist=edges_to_draw, alpha=0.3, edge_color='lightgray', width=0.5)
    
    # Draw nodes by category
    # Center (PAY)
    if 'PAY' in pos:
        nx.draw_networkx_nodes(G, pos, nodelist=['PAY'], 
                              node_color='#1f4e79', node_size=2000, alpha=0.9)
    
    # Hub Ring (Orange)
    if center_hub_connections:
        nx.draw_networkx_nodes(G, pos, nodelist=center_hub_connections, 
                              node_color='#ff8c00', node_size=800, alpha=0.9)
    
    # High Ring (Blue)
    if center_high_connections:
        nx.draw_networkx_nodes(G, pos, nodelist=center_high_connections, 
                              node_color='#4682b4', node_size=600, alpha=0.9)
    
    # Medium Ring (Green)
    if center_medium_connections:
        nx.draw_networkx_nodes(G, pos, nodelist=center_medium_connections, 
                              node_color='#90ee90', node_size=400, alpha=0.9)
    
    # Low Ring (Grey)
    if center_low_connections:
        nx.draw_networkx_nodes(G, pos, nodelist=center_low_connections, 
                              node_color='#d3d3d3', node_size=300, alpha=0.9)
    
    # Draw node labels (project keys ABOVE circles)
    node_labels = {}
    for node in G.nodes():
        if node in pos:
            node_labels[node] = node  # Just the project key above the circle
    
    nx.draw_networkx_labels(G, pos, node_labels, font_size=8, font_weight='bold', font_color='black')
    
    # Draw count labels INSIDE circles
    count_labels = {}
    for node in G.nodes():
        if node in pos:
            if node == 'PAY':
                # PAY shows the count of projects it's connected to on the chart
                count_labels[node] = str(len(pay_connections))
            else:
                # Connected projects show count of their connections that are also on the chart
                node_neighbors = list(G.neighbors(node))
                # Count how many of this node's neighbors are also shown on the chart
                neighbors_on_chart = [n for n in node_neighbors if n in pos]
                count_labels[node] = str(len(neighbors_on_chart))
    
    # Draw count labels INSIDE the circles (offset slightly down from center)
    for node, count in count_labels.items():
        if node in pos:
            x, y = pos[node]
            plt.text(x, y-0.05, count, ha='center', va='center', fontsize=10, weight='bold', color='white')
    
    # Add title
    plt.title(f'Payment Services (PAY) - {len(pay_connections)} Links\n(Filtered: Unresolved Issues, 90-Day Activity)', 
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
    
    plt.axis('off')
    plt.tight_layout()
    
    # Save with high quality
    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except:
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
    
    # Calculate metrics for naming
    project_network_connections = {}
    for node in G.nodes():
        project_network_connections[node] = G.nodes[node]['link_count']
    
    return G, len(center_hub_connections), len(center_high_connections), len(center_medium_connections), len(center_low_connections), project_network_connections, pay_connections

def main():
    """Main function to generate the PAY diagram with proper naming"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    project_summary, relationships_df = load_project_data(csv_file)
    
    center_project = 'PAY'
    
    print(f"\n{'='*60}")
    print(f"Creating {center_project}-Centered Project Affinity Diagram...")
    print(f"{'='*60}")
    
    # Create diagram
    temp_filename = f'{center_project}_temp.png'
    G, hub_count, high_count, medium_count, low_count, project_network_connections, pay_connections = create_pay_centered_diagram(
        project_summary, relationships_df, temp_filename)
    
    # Calculate metrics for naming convention
    center_count = hub_count + high_count + medium_count + low_count
    
    # Calculate total sum and weighted sum using actual link counts TO PAY
    total_sum = 0
    weighted_sum = 0
    if G is not None:
        for project in pay_connections:
            if G.has_edge('PAY', project):
                connections_to_pay = G.edges[('PAY', project)]['weight']
                total_sum += connections_to_pay
                
                # Calculate weighted sum based on ring (using actual link counts to PAY)
                if connections_to_pay >= 15:  # Hub
                    weighted_sum += connections_to_pay * 4
                elif connections_to_pay >= 11:  # High
                    weighted_sum += connections_to_pay * 3
                elif connections_to_pay >= 6:  # Medium
                    weighted_sum += connections_to_pay * 2
                else:  # Low
                    weighted_sum += connections_to_pay * 1
    
    # Create the enhanced filename with all segments padded to 4 digits
    proper_filename = f'{weighted_sum:04d}_{total_sum:04d}_{center_count:04d}_{hub_count:04d}_{high_count:04d}_{medium_count:04d}_{low_count:04d}_{center_project}.png'
    
    # Rename the file
    import os
    if os.path.exists(temp_filename):
        if os.path.exists(proper_filename):
            os.remove(proper_filename)
        os.rename(temp_filename, proper_filename)
        print(f"Diagram saved as: {proper_filename}")
    
    # Print summary
    if G is not None:
        center_connections = list(G.neighbors(center_project))
        print(f"\n{center_project}-CENTERED PROJECT AFFINITY ANALYSIS SUMMARY")
        print(f"Total Projects in Dataset: {len(project_summary)}")
        print(f"{center_project} Total Direct Connections: {len(center_connections)}")
        print(f"{center_project} Hub Connections: {hub_count}")
        print(f"{center_project} High Connections: {high_count}")
        print(f"{center_project} Medium Connections: {medium_count}")
        print(f"{center_project} Low Connections: {low_count}")
        
        print(f"\n{center_project}'s Top Connected Projects:")
        center_neighbors = []
        for n in center_connections:
            if G.has_edge(center_project, n):
                link_count_to_pay = G.edges[(center_project, n)]['weight']
                center_neighbors.append((n, link_count_to_pay))
            else:
                center_neighbors.append((n, 0))
        center_neighbors.sort(key=lambda x: x[1], reverse=True)
        for j, (project, count) in enumerate(center_neighbors[:15], 1):
            print(f"{j:2d}. {project:8s} - {count:2d} links to PAY")

if __name__ == "__main__":
    main()
