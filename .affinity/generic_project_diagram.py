#!/usr/bin/env python3
"""
Generic Project Affinity Diagram Generator
Creates a visual representation of any project's relationships with customizable styling
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

def create_generic_project_diagram(df, center_project, output_file='generic_project_diagram.png'):
    """Create a generic project-centered diagram with custom styling"""
    
    # Create network graph
    G = create_network_graph(df)
    
    # Set up the plot (smaller, tighter layout)
    plt.figure(figsize=(16, 12))
    
    # Check if center project exists in the graph
    if center_project not in G.nodes():
        print(f"Warning: {center_project} project not found in data.")
        return None
    
    # Get center project's direct connections
    center_connections = list(G.neighbors(center_project))
    print(f"{center_project} has {len(center_connections)} direct connections")
    
    # Get projects by connectivity level within ORL's network
    # We'll recategorize based on connections within ORL's network, not global connectivity
    hub_projects = []  # Will be determined after calculating network connections
    high_projects = []  # Will be determined after calculating network connections
    medium_projects = []  # Will be determined after calculating network connections
    low_projects = []  # Will be determined after calculating network connections
    
    # Calculate connections within ORL's network for each project
    center_network_nodes = set([center_project] + center_connections)
    project_network_connections = {}
    
    for project in center_connections:
        # Count how many connections this project has to other projects in ORL's network
        connections_to_network = len([neighbor for neighbor in G.neighbors(project) 
                                    if neighbor in center_network_nodes and neighbor != center_project])
        # No need to add 1 since we're now showing the center connection lines
        project_network_connections[project] = connections_to_network
    
    # Categorize projects based on their connections within ORL's network
    center_hub_connections = [p for p in center_connections if project_network_connections[p] >= 15]
    center_high_connections = [p for p in center_connections if 11 <= project_network_connections[p] <= 14]
    center_medium_connections = [p for p in center_connections if 6 <= project_network_connections[p] <= 10]
    center_low_connections = [p for p in center_connections if 1 <= project_network_connections[p] <= 5]
    
    # Filter to only show hub, high, medium, and low connections
    center_filtered_connections = center_hub_connections + center_high_connections + center_medium_connections + center_low_connections
    print(f"{center_project} filtered connections: {len(center_filtered_connections)}")
    print(f"  Hub (15+): {len(center_hub_connections)}, High (11-14): {len(center_high_connections)}, Medium (6-10): {len(center_medium_connections)}, Low (1-5): {len(center_low_connections)}")
    
    # Create center project-centered radial layout
    pos = {}
    
    # Center project at the center
    pos[center_project] = (0, 0)
    
    # Sort connections by network connections (largest first) for each layer
    center_hub_connections_sorted = sorted(center_hub_connections, key=lambda x: project_network_connections[x], reverse=True)
    center_high_connections_sorted = sorted(center_high_connections, key=lambda x: project_network_connections[x], reverse=True)
    center_medium_connections_sorted = sorted(center_medium_connections, key=lambda x: project_network_connections[x], reverse=True)
    center_low_connections_sorted = sorted(center_low_connections, key=lambda x: project_network_connections[x], reverse=True)
    
    # Layer 1: Hub connections (orange) - clock positioning
    if center_hub_connections_sorted:
        hub_radius = 0.3
        for i, hub in enumerate(center_hub_connections_sorted):
            # Clock positioning: largest at 12 o'clock, go clockwise
            angle = np.pi/2 - (i * 2 * np.pi / len(center_hub_connections_sorted))
            pos[hub] = (hub_radius * np.cos(angle), hub_radius * np.sin(angle))
    
    # Layer 2: High connections (blue) - clock positioning
    if center_high_connections_sorted:
        high_radius = 0.5
        for i, project in enumerate(center_high_connections_sorted):
            # Clock positioning: largest at 12 o'clock, go clockwise
            angle = np.pi/2 - (i * 2 * np.pi / len(center_high_connections_sorted))
            pos[project] = (high_radius * np.cos(angle), high_radius * np.sin(angle))
    
    # Layer 3: Medium connections (green) - clock positioning
    if center_medium_connections_sorted:
        medium_radius = 0.7
        for i, project in enumerate(center_medium_connections_sorted):
            # Clock positioning: largest at 12 o'clock, go clockwise
            angle = np.pi/2 - (i * 2 * np.pi / len(center_medium_connections_sorted))
            pos[project] = (medium_radius * np.cos(angle), medium_radius * np.sin(angle))
    
    # Layer 4: Low connections (gray) - clock positioning
    if center_low_connections_sorted:
        low_radius = 0.9
        for i, project in enumerate(center_low_connections_sorted):
            # Clock positioning: largest at 12 o'clock, go clockwise
            angle = np.pi/2 - (i * 2 * np.pi / len(center_low_connections_sorted))
            pos[project] = (low_radius * np.cos(angle), low_radius * np.sin(angle))
    
    # Only show projects directly connected to center project
    center_network_nodes = set([center_project] + center_filtered_connections)
    
    # Separate nodes by layer based on connections within ORL's network
    hub_nodes = [n for n in center_hub_connections if n in pos]
    high_nodes = [n for n in center_high_connections if n in pos]
    medium_nodes = [n for n in center_medium_connections if n in pos]
    low_nodes = [n for n in center_low_connections if n in pos]
    
    # Categorize edges with custom styling (no hub connections shown)
    center_edges = []           # Center to all layers (no lines)
    high_to_high = []          # High to High (blue lines)
    high_to_medium = []        # High to Medium (blue lines)
    high_to_low = []           # High to Low (blue lines)
    medium_to_medium = []      # Medium to Medium (green lines)
    medium_to_low = []         # Medium to Low (green lines)
    low_to_low = []            # Low to Low (gray lines)
    # Add missing edge categories
    hub_to_high = []           # Hub to High (orange lines)
    hub_to_medium = []         # Hub to Medium (orange lines)
    hub_to_low = []            # Hub to Low (orange lines)
    hub_to_hub = []            # Hub to Hub (orange lines)
    
    for edge in G.edges():
        source, target = edge
        
        # Only include edges where both nodes are in center project's direct network
        if source not in center_network_nodes or target not in center_network_nodes:
            continue
        
        # Skip edges where nodes are not in our position dictionary
        if source not in pos or target not in pos:
            continue
        
        # Check if edge involves center project (no lines to center)
        if source == center_project or target == center_project:
            center_edges.append(edge)
            continue
        
        # Determine layer categories for connections between center project's direct connections
        source_is_hub = source in center_hub_connections
        source_is_high = source in center_high_connections
        source_is_medium = source in center_medium_connections
        source_is_low = source in center_low_connections
        
        target_is_hub = target in center_hub_connections
        target_is_high = target in center_high_connections
        target_is_medium = target in center_medium_connections
        target_is_low = target in center_low_connections
        
        # Categorize edges with custom styling (include all connections)
        if source_is_hub or target_is_hub:
            if source_is_hub and target_is_hub:
                hub_to_hub.append(edge)
            elif source_is_hub and target_is_high:
                hub_to_high.append(edge)
            elif source_is_hub and target_is_medium:
                hub_to_medium.append(edge)
            elif source_is_hub and target_is_low:
                hub_to_low.append(edge)
            elif target_is_hub and source_is_high:
                hub_to_high.append(edge)
            elif target_is_hub and source_is_medium:
                hub_to_medium.append(edge)
            elif target_is_hub and source_is_low:
                hub_to_low.append(edge)
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
    
    # Draw edges in order (inner to outer for proper layering - hub over high over medium over low)
    
    # Draw low to low connections (light gray dashed lines) - bottom layer
    if low_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=low_to_low, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to low connections (light gray dashed lines)
    if medium_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_low, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw medium to medium connections (light gray dashed lines)
    if medium_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=medium_to_medium, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to low connections (light gray dashed lines)
    if high_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_low, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to medium connections (light gray dashed lines)
    if high_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_medium, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw high to high connections (light gray dashed lines)
    if high_to_high:
        nx.draw_networkx_edges(G, pos, edgelist=high_to_high, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw hub to low connections (light gray dashed lines)
    if hub_to_low:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_low, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw hub to medium connections (light gray dashed lines)
    if hub_to_medium:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_medium, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw hub to high connections (light gray dashed lines)
    if hub_to_high:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_high, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw hub to hub connections (light gray dashed lines)
    if hub_to_hub:
        nx.draw_networkx_edges(G, pos, edgelist=hub_to_hub, alpha=1.0, width=0.1, 
                              edge_color='lightgray', style='dashed')
    
    # Draw center edges - lines to center project (medium blue, 50% transparent)
    if center_edges:
        nx.draw_networkx_edges(G, pos, edgelist=center_edges, alpha=0.5, width=0.2, 
                              edge_color='mediumblue', style='solid')
    
    # Draw nodes by category with different sizes and colors
    node_sizes = {}
    for node in center_network_nodes:
        if node in pos:
            if node == center_project:
                node_sizes[node] = 2000  # Center project size (fixed)
            elif node in center_hub_connections:
                network_connections = project_network_connections[node]
                node_sizes[node] = max(1000, min(1800, network_connections * 30))  # Hub: 1000-1800
            elif node in center_high_connections:
                network_connections = project_network_connections[node]
                node_sizes[node] = max(600, min(950, network_connections * 25))   # High: 600-950
            elif node in center_medium_connections:
                network_connections = project_network_connections[node]
                node_sizes[node] = max(300, min(550, network_connections * 20))  # Medium: 300-550
            elif node in center_low_connections:
                network_connections = project_network_connections[node]
                node_sizes[node] = max(200, min(250, network_connections * 15))  # Low: 200-250
            else:
                node_sizes[node] = 200
    
    # Draw low connectivity nodes (gray - outer ring, 75% transparency)
    if low_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=low_nodes, 
                              node_color='gray', node_size=[node_sizes[n] for n in low_nodes], alpha=0.25)
    
    # Draw medium connectivity nodes (green - third ring, 60% transparency)
    if medium_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=medium_nodes, 
                              node_color='green', node_size=[node_sizes[n] for n in medium_nodes], alpha=0.4)
    
    # Draw high connectivity nodes (blue - middle ring, 50% transparency)
    if high_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=high_nodes, 
                              node_color='blue', node_size=[node_sizes[n] for n in high_nodes], alpha=0.5)
    
    # Draw hub nodes (orange - inner ring, 25% transparency)
    if hub_nodes:
        nx.draw_networkx_nodes(G, pos, nodelist=hub_nodes, 
                              node_color='orange', node_size=[node_sizes[n] for n in hub_nodes], alpha=0.75)
    
    # Draw center project (navy blue, 0% transparency) - fixed size for all diagrams
    center_size = 2000  # Fixed size for all center circles
    nx.draw_networkx_nodes(G, pos, nodelist=[center_project], 
                          node_color='navy', node_size=center_size, alpha=1.0)
    
    # Draw labels right on top of circles and direct connection counts inside circles
    # Center project - project name above circle, key and count inside circle
    center_count = len(center_filtered_connections)  # Use filtered connections (45)
    
    # Add full project name above center circle
    project_full_names = {
        'ACM': 'Access Control Management',
        'ACQ': 'Acquisitions',
        'ACQE': 'Acquisition Engineering',
        'AI': 'Artificial Intelligence',
        'AUT': 'Automation',
        'BAS': 'Business Analytics System',
        'BDME': 'Business Data Management Engine',
        'BINT': 'Business Intelligence',
        'BOKR': 'Business Operations Knowledge Repository',
        'CACS': 'Customer Account Management System',
        'CAD': 'Computer Aided Design',
        'CAPE': 'Customer Analytics Platform Engine',
        'CAPS': 'Customer Analytics Platform System',
        'CARC': 'Customer Analytics Reporting Center',
        'CARD': 'Card Services',
        'CBRE': 'Customer Business Relationship Engine',
        'CCAL': 'Customer Calendar',
        'CCOL': 'Customer Collections',
        'CCP': 'Customer Communication Platform',
        'CCT': 'Customer Communication Technology',
        'CDAD': 'Customer Data Analytics Dashboard',
        'CDL': 'Customer Data Lake',
        'CE': 'Customer Experience',
        'CENG': 'Customer Engineering',
        'CES': 'Customer Experience System',
        'CFOPS': 'Customer Financial Operations',
        'CIA': 'Customer Intelligence Analytics',
        'CISRE': 'Customer Infrastructure Site Reliability Engineering',
        'CITM': 'Customer IT Management',
        'CJI': 'Customer Journey Intelligence',
        'CMP': 'Customer Management Platform',
        'CNE': 'Customer Network Engineering',
        'CNS': 'Customer Network Services',
        'CNSS': 'Customer Network Security Services',
        'COL': 'Collections',
        'COM': 'Communications',
        'COMMS': 'Communications System',
        'COMP': 'Compliance',
        'CONT': 'Content Management',
        'COPS': 'Customer Operations',
        'COR': 'Customer Operations Reporting',
        'CRSK': 'Customer Risk Management',
        'CSF': 'Customer Service Framework',
        'CTECH': 'Customer Technology',
        'CTEM': 'Customer Technology Engineering Management',
        'CTGR': 'Customer Technology Governance',
        'CUSD': 'Customer User Service Desk',
        'CWG': 'Customer Workflow Gateway',
        'DARC': 'Data Analytics Reporting Center',
        'DAWA': 'Data Warehouse Analytics',
        'DBA': 'Database Administration',
        'DBEAN': 'Database Engineering Analytics Network',
        'DCI': 'Data Center Infrastructure',
        'DCOM': 'Data Communications',
        'DE': 'Data Engineering',
        'DEP': 'Deployment',
        'DEPI': 'Deployment Infrastructure',
        'DLP': 'Data Loss Prevention',
        'DOC': 'Documentation',
        'DOT': 'Data Operations Technology',
        'DP': 'Data Platform',
        'DPB': 'Data Platform Business',
        'DPR': 'Data Platform Reporting',
        'DPSS': 'Data Platform Security Services',
        'DR': 'Disaster Recovery',
        'DS': 'Data Services',
        'EA': 'Enterprise Architecture',
        'EDME': 'Enterprise Data Management Engine',
        'EMC': 'Enterprise Management Console',
        'ENGOPS': 'Engineering Operations',
        'EOKR': 'Engineering Operations Knowledge Repository',
        'EPMC': 'Enterprise Project Management Center',
        'ERC': 'Enterprise Resource Center',
        'ERD': 'Enterprise Resource Database',
        'ESDL': 'Enterprise Service Data Lake',
        'ETAC': 'Enterprise Technology Architecture Center',
        'FLDR': 'Folder Management',
        'FNTR': 'Financial Technology',
        'FORMS': 'Forms Management',
        'FS': 'File System',
        'FSYS': 'File System Services',
        'GENAI': 'Generative AI',
        'HRES': 'Human Resources',
        'IAM': 'Identity and Access Management',
        'ICS': 'Infrastructure Control System',
        'IMG': 'Image Management',
        'INEN': 'Infrastructure Engineering',
        'INI': 'Infrastructure Integration',
        'INSO': 'Infrastructure Operations',
        'INTG': 'Integration Services',
        'JAP': 'Java Application Platform',
        'JOP': 'Java Operations Platform',
        'LAS': 'Loan Application System',
        'LAW': 'Legal and Compliance',
        'LNL': 'Loan Network Layer',
        'MCACQ': 'Multi-Channel Acquisitions',
        'MCARD': 'Multi-Channel Card Services',
        'MCCE': 'Multi-Channel Customer Experience',
        'MCCOL': 'Multi-Channel Collections',
        'MCCP': 'Multi-Channel Customer Platform',
        'MCENG': 'Multi-Channel Engineering',
        'MCLD': 'Multi-Channel Loan Data',
        'MCLNE': 'Multi-Channel Loan Network Engine',
        'MCORG': 'Multi-Channel Originations',
        'ME': 'Management Engine',
        'MES': 'Management Engine Services',
        'MOB': 'Mobile Services',
        'MOD': 'Modular Development',
        'NELT': 'Network Engineering and Load Testing',
        'NOW': 'Network Operations Workflow',
        'OAE': 'Operations Analytics Engine',
        'OBE': 'Operations Business Engine',
        'OBSRV': 'Observability',
        'ONE': 'OneMain Financial',
        'OPSAN': 'Operations Analytics',
        'ORL': 'Originations',
        'OSO': 'Operations Support Office',
        'PAN': 'Platform Analytics Network',
        'PAS': 'Platform Analytics Services',
        'PAY': 'Payment Services',
        'PDS': 'Platform Data Services',
        'PE': 'Platform Engineering',
        'PIE': 'Platform Integration Engine',
        'PLAQ': 'Platform Analytics Quality',
        'PLAT': 'Platform Services',
        'PLOS': 'Platform Operations Services',
        'POP': 'Platform Operations Platform',
        'POS': 'Point of Sale',
        'PSM': 'Platform Service Management',
        'QUAL': 'Quality Assurance',
        'RC': 'Risk Control',
        'REM': 'Remediation',
        'SCOF': 'Security Control Framework',
        'SCON': 'Security Control',
        'SE': 'Security Engineering',
        'SEN': 'Security Engineering Network',
        'SHP': 'Security Health Platform',
        'SIGN': 'Digital Signatures',
        'SRE': 'Site Reliability Engineering',
        'STAN': 'Standards',
        'STNRD': 'Standards and Requirements',
        'SVCCOL': 'Service Collections',
        'TAM': 'Technology Asset Management',
        'TCA': 'Technology Control Architecture',
        'TCET': 'Technology Control Engineering Team',
        'TDC': 'Technology Data Center',
        'TO': 'Technology Operations',
        'TOCA': 'Technology Operations Control Architecture',
        'TOEP': 'Technology Operations Engineering Platform',
        'TOKR': 'Technology Operations Knowledge Repository',
        'TP': 'Technology Platform',
        'TRIM': 'Technology Risk and Information Management',
        'UN': 'User Network',
        'UPT': 'User Platform Technology',
        'UX': 'User Experience',
        'WL': 'Workflow Layer',
        'ZCS': 'Zero Configuration Services'
    }
    full_name = project_full_names.get(center_project, center_project)
    plt.text(pos[center_project][0], pos[center_project][1] + 0.08, full_name, 
             ha='center', va='bottom', fontsize=12, fontweight='bold', color='black')
    
    # Project key and count inside center circle
    plt.text(pos[center_project][0], pos[center_project][1], f"{center_project}\n{center_count}", 
             ha='center', va='center', fontsize=10, fontweight='bold', color='white')
    
    # Hub labels right on top of circles
    for node in hub_nodes:
        x, y = pos[node]
        # Position label right on top of circle with consistent spacing
        plt.text(x, y + 0.08, node, ha='center', va='bottom', fontsize=8, fontweight='bold', color='black')
        # Count connections to other projects that are also directly connected to center
        connections_to_center_network = project_network_connections[node]
        plt.text(x, y, str(connections_to_center_network), ha='center', va='center', fontsize=7, fontweight='bold', color='white')
    
    # High connectivity labels right on top of circles
    for node in high_nodes:
        x, y = pos[node]
        # Position label right on top of circle
        plt.text(x, y + 0.05, node, ha='center', va='bottom', fontsize=8, fontweight='bold', color='black')
        # Count connections to other projects that are also directly connected to center
        connections_to_center_network = project_network_connections[node]
        plt.text(x, y, str(connections_to_center_network), ha='center', va='center', fontsize=7, fontweight='bold', color='white')
    
    # Medium connectivity labels right on top of circles
    for node in medium_nodes:
        x, y = pos[node]
        # Position label right on top of circle
        plt.text(x, y + 0.05, node, ha='center', va='bottom', fontsize=8, fontweight='bold', color='black')
        # Count connections to other projects that are also directly connected to center
        connections_to_center_network = project_network_connections[node]
        plt.text(x, y, str(connections_to_center_network), ha='center', va='center', fontsize=7, fontweight='bold', color='white')
    
    # Low connectivity labels right on top of circles
    for node in low_nodes:
        x, y = pos[node]
        # Position label right on top of circle
        plt.text(x, y + 0.05, node, ha='center', va='bottom', fontsize=8, fontweight='bold', color='black')
        # Count connections to other projects that are also directly connected to center
        connections_to_center_network = project_network_connections[node]
        plt.text(x, y, str(connections_to_center_network), ha='center', va='center', fontsize=7, fontweight='bold', color='white')
    
    # Add title with project name and connection count
    center_count = len(center_filtered_connections)
    plt.title(f'{full_name} ({center_project}) - {center_count} Links', 
              fontsize=16, fontweight='bold', pad=20)
    
    # Create legend
    legend_elements = [
        plt.scatter([], [], c='navy', s=200, label=f'{center_project} (Center)', alpha=1.0),
        plt.scatter([], [], c='orange', s=150, label='Hub Ring (15+ network connections)', alpha=0.75),
        plt.scatter([], [], c='blue', s=100, label='High Ring (11-14 network connections)', alpha=0.5),
        plt.scatter([], [], c='green', s=75, label='Medium Ring (6-10 network connections)', alpha=0.4),
        plt.scatter([], [], c='gray', s=50, label='Low Ring (1-5 network connections)', alpha=0.25)
    ]
    
    plt.legend(handles=legend_elements, loc='upper left', bbox_to_anchor=(0, 1), fontsize=10)
    
    # Statistics text removed as requested
    
    plt.axis('off')
    plt.tight_layout()
    
    # Save with different method to avoid the error
    try:
        plt.savefig(output_file, dpi=300, bbox_inches='tight', facecolor='white')
    except:
        # Fallback save method
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
    
    # plt.show()  # Removed to allow batch processing without pausing
    
    return G, len(center_hub_connections), len(center_high_connections), len(center_medium_connections), len(center_low_connections), project_network_connections

def main():
    """Main function to generate the generic project diagram"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = load_project_data(csv_file)
    
    # Process only PAY project
    center_project = 'PAY'
    
    print(f"Processing {center_project} project with filtered data")
    
    for i, center_project in enumerate([center_project], 1):
        print(f"\n{'='*60}")
        print(f"Creating {center_project}-Centered Project Affinity Diagram ({i}/157)...")
        print(f"{'='*60}")
        
        # Create diagram and get ring counts
        temp_filename = f'{center_project}_temp_{i}.png'
        G, hub_count, high_count, medium_count, low_count, project_network_connections = create_generic_project_diagram(df, center_project, temp_filename)
        
        # Calculate the actual direct connections shown in diagram
        center_count = hub_count + high_count + medium_count + low_count
        
        # Calculate total sum of connection counts shown in the diagram
        total_sum = 0
        weighted_sum = 0
        if G is not None:
            # Get all connected projects and sum their network connection counts (not total link counts)
            connected_projects = [node for node in G.nodes() if node != center_project]
            for project in connected_projects:
                if project in project_network_connections:
                    connections = project_network_connections[project]
                    total_sum += connections
                    
                    # Calculate weighted sum based on ring
                    if connections >= 15:  # Hub
                        weighted_sum += connections * 4
                    elif connections >= 11:  # High
                        weighted_sum += connections * 3
                    elif connections >= 6:  # Medium
                        weighted_sum += connections * 2
                    else:  # Low
                        weighted_sum += connections * 1
        
        # Create the enhanced filename with all segments padded to 4 digits
        proper_filename = f'{weighted_sum:04d}_{total_sum:04d}_{center_count:04d}_{hub_count:04d}_{high_count:04d}_{medium_count:04d}_{low_count:04d}_{center_project}.png'
        
        # Rename the file with error handling
        import os
        if os.path.exists(temp_filename):
            if os.path.exists(proper_filename):
                os.remove(proper_filename)  # Remove existing file
            os.rename(temp_filename, proper_filename)
    
        if G is not None:
            # Print summary statistics
            print(f"\n{center_project.upper()}-CENTERED PROJECT AFFINITY ANALYSIS SUMMARY")
            print(f"Total Projects in Dataset: {len(df)}")
            center_connections = list(G.neighbors(center_project))
            print(f"{center_project} Total Direct Connections: {len(center_connections)}")
            print(f"{center_project} Hub Connections: {len([n for n in center_connections if G.nodes[n]['link_count'] >= 30])}")
            print(f"{center_project} High Connections: {len([n for n in center_connections if 20 <= G.nodes[n]['link_count'] < 30])}")
            print(f"{center_project} Medium Connections: {len([n for n in center_connections if 10 <= G.nodes[n]['link_count'] < 20])}")
            print(f"{center_project} Low Connections: {len([n for n in center_connections if 0 < G.nodes[n]['link_count'] < 10])}")
            print(f"{center_project} Isolated Connections: {len([n for n in center_connections if G.nodes[n]['link_count'] == 0])}")
            print(f"Projects Shown in Diagram: {len(center_connections)} (only direct connections)")
            
            print(f"\n{center_project}'s Top Connected Projects:")
            center_neighbors = [(n, G.nodes[n]['link_count']) for n in center_connections]
            center_neighbors.sort(key=lambda x: x[1], reverse=True)
            for j, (project, count) in enumerate(center_neighbors[:15], 1):
                print(f"{j:2d}. {project:8s} - {count:2d} total connections")
    
    print(f"\n{'='*60}")
    print(f"PAY PROJECT PROCESSING COMPLETED!")
    print(f"Files generated: 1")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
