#!/usr/bin/env python3
"""
Create Cross-Project Connection Heatmap
Excludes ORL, TOKR, RC, EOKR, OBSRV, EPMC, and EDME projects
ONLY shows cross-project links (no self-links)
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import warnings
warnings.filterwarnings('ignore')

def load_and_process_data(csv_file):
    """Load and process the project-to-project connections data"""
    df = pd.read_csv(csv_file)
    
    # Filter out self-links
    df_cross = df[df['SourceProject'] != df['TargetProject']].copy()
    
    print(f"Loaded {len(df)} total project-to-project connections")
    print(f"Cross-project connections: {len(df_cross)}")
    print(f"Self-links filtered out: {len(df) - len(df_cross)}")
    print(f"Total cross-project links: {df_cross['TotalLinks'].sum()}")
    
    return df_cross

def create_project_connection_matrix(df, top_n=30):
    """Create a matrix of ONLY cross-project connections"""
    
    # Calculate total CROSS-PROJECT connections for each project
    project_totals = {}
    for _, row in df.iterrows():
        proj1 = row['SourceProject']
        proj2 = row['TargetProject']
        total_links = row['TotalLinks']
        
        if proj1 not in project_totals:
            project_totals[proj1] = 0
        if proj2 not in project_totals:
            project_totals[proj2] = 0
        
        # Count links for both source and target
        project_totals[proj1] += total_links
        project_totals[proj2] += total_links
    
    # Get top N projects by total cross-project connections
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    top_projects = [proj for proj, _ in sorted_projects[:top_n]]
    
    print(f"\nTop {top_n} projects by cross-project connections:")
    for i, (project, total_links) in enumerate(sorted_projects[:top_n], 1):
        print(f"{i:2d}. {project:8s}: {total_links:6d} cross-project links")
    
    # Create matrix
    matrix_size = len(top_projects)
    connection_matrix = np.zeros((matrix_size, matrix_size))
    
    # Fill the matrix with ONLY cross-project connection data
    for i, proj1 in enumerate(top_projects):
        for j, proj2 in enumerate(top_projects):
            if i != j:  # Explicitly exclude diagonal (self-links)
                # Look for connections between proj1 and proj2
                connections = df[(df['SourceProject'] == proj1) & (df['TargetProject'] == proj2)]
                
                if not connections.empty:
                    connection_matrix[i][j] = connections['TotalLinks'].values[0]
    
    return connection_matrix, top_projects

def create_heatmap(connection_matrix, top_projects, output_file):
    """Create and save the heatmap"""
    
    # Set up the plot
    plt.figure(figsize=(12, 10))
    
    # Create the heatmap
    # Use log scale for better visualization of wide range of values
    log_matrix = np.log1p(connection_matrix)  # log(1 + x) to handle zeros
    
    # Create mask for diagonal to make it visually distinct
    mask = np.zeros_like(connection_matrix, dtype=bool)
    np.fill_diagonal(mask, True)
    
    sns.heatmap(log_matrix, 
                xticklabels=top_projects,
                yticklabels=top_projects,
                annot=connection_matrix.astype(int),  # Show raw values as annotations
                fmt='d',
                cmap='YlOrRd',  # Yellow to Red colormap
                cbar_kws={'label': 'Log(Links + 1)'},
                square=True,
                linewidths=0.5,
                annot_kws={'fontsize': 9},
                mask=mask)  # Mask the diagonal
    
    # Customize the plot
    plt.title('OMF Top 10 Projects - Cross-Project Connections Only\n(Filtered: Excluding ORL, TOKR, RC, EOKR, OBSRV, EPMC, EDME, BOKR | No Self-Links)', 
              fontsize=16, fontweight='bold', pad=20)
    plt.xlabel('Target Project', fontsize=12, fontweight='bold')
    plt.ylabel('Source Project', fontsize=12, fontweight='bold')
    
    # Rotate x-axis labels for better readability
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    
    # Adjust layout to prevent label cutoff
    plt.tight_layout()
    
    # Save the plot
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"\nHeatmap saved as: {output_file}")

def analyze_connections(connection_matrix, top_projects):
    """Analyze and print connection statistics"""
    
    print(f"\n{'='*60}")
    print("CROSS-PROJECT CONNECTION ANALYSIS")
    print(f"{'='*60}")
    
    # Find strongest cross-project connections
    connections_list = []
    for i in range(len(top_projects)):
        for j in range(len(top_projects)):
            if i != j and connection_matrix[i][j] > 0:
                connections_list.append((top_projects[i], top_projects[j], connection_matrix[i][j]))
    
    # Sort by connection strength
    connections_list.sort(key=lambda x: x[2], reverse=True)
    
    print(f"\nTop 20 strongest cross-project connections:")
    for idx, (proj1, proj2, connections) in enumerate(connections_list[:20], 1):
        print(f"{idx:2d}. {proj1:8s} -> {proj2:8s}: {int(connections):5d} links")
    
    # Calculate total cross-project connections for each project
    project_connection_totals = {}
    for i, project in enumerate(top_projects):
        total_out = np.sum(connection_matrix[i])  # Outbound to other projects
        total_in = np.sum(connection_matrix[:, i])  # Inbound from other projects
        project_connection_totals[project] = total_out + total_in
    
    print(f"\nTop 20 most connected projects (cross-project only):")
    sorted_by_connections = sorted(project_connection_totals.items(), key=lambda x: x[1], reverse=True)
    for i, (project, total_connections) in enumerate(sorted_by_connections[:20], 1):
        print(f"{i:2d}. {project:8s}: {int(total_connections):6d} total cross-project links")
    
    # Find bidirectional connections
    bidirectional = []
    for i in range(len(top_projects)):
        for j in range(i+1, len(top_projects)):
            if connection_matrix[i][j] > 0 and connection_matrix[j][i] > 0:
                total = connection_matrix[i][j] + connection_matrix[j][i]
                bidirectional.append((top_projects[i], top_projects[j], 
                                    connection_matrix[i][j], connection_matrix[j][i], total))
    
    bidirectional.sort(key=lambda x: x[4], reverse=True)
    
    print(f"\nTop 10 strongest bidirectional relationships:")
    for idx, (proj1, proj2, links1to2, links2to1, total) in enumerate(bidirectional[:10], 1):
        print(f"{idx:2d}. {proj1:8s} <-> {proj2:8s}: {int(total):5d} total ({int(links1to2)} / {int(links2to1)})")

def main():
    """Main function to create the cross-project heatmap"""
    
    print("Creating CROSS-PROJECT connection heatmap...")
    print("Excluded projects: ORL, TOKR, RC, EOKR, OBSRV, EPMC, EDME, BOKR")
    print("Self-links: EXCLUDED\n")
    
    # Load data from PowerShell script output
    csv_file = './Project_to_Project_Detailed_Connections.csv'
    df_cross = load_and_process_data(csv_file)
    
    print(f"\n{'='*60}")
    print("CREATING CROSS-PROJECT CONNECTION HEATMAP")
    print(f"{'='*60}")
    
    # Create connection matrix for top 10 projects (based on cross-project links only)
    connection_matrix, top_projects = create_project_connection_matrix(df_cross, top_n=10)
    
    # Create and save heatmap
    output_file = 'project_connection_heatmap_cross_project_only.png'
    create_heatmap(connection_matrix, top_projects, output_file)
    
    # Analyze connections
    analyze_connections(connection_matrix, top_projects)
    
    print(f"\n{'='*60}")
    print("HEATMAP CREATION COMPLETE")
    print(f"{'='*60}")
    print(f"Output file: {output_file}")
    print(f"Projects analyzed: {len(top_projects)}")
    print(f"Matrix size: {connection_matrix.shape}")
    print(f"Total cross-project connections in heatmap: {int(np.sum(connection_matrix))}")

if __name__ == "__main__":
    main()

