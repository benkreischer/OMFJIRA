#!/usr/bin/env python3
"""
Create Filtered Project Connection Heatmap
Excludes ORL, TOKR, RC, EOKR, OBSRV, EPMC, and EDME projects
Uses data from analyze_project_links.ps1 output
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
    
    print(f"Loaded {len(df)} project-to-project connections")
    print(f"Total links: {df['TotalLinks'].sum()}")
    
    return df

def create_project_connection_matrix(df, top_n=30):
    """Create a symmetric matrix of project connections"""
    
    # Get all unique projects
    all_projects = sorted(set(df['SourceProject'].unique()) | set(df['TargetProject'].unique()))
    print(f"Total unique projects: {len(all_projects)}")
    
    # Calculate total connections for each project
    project_totals = {}
    for _, row in df.iterrows():
        proj1 = row['SourceProject']
        proj2 = row['TargetProject']
        total_links = row['TotalLinks']
        
        if proj1 not in project_totals:
            project_totals[proj1] = 0
        if proj2 not in project_totals:
            project_totals[proj2] = 0
        
        project_totals[proj1] += total_links
        if proj1 != proj2:  # Don't double count self-links
            project_totals[proj2] += total_links
    
    # Get top N projects by total connections
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    top_projects = [proj for proj, _ in sorted_projects[:top_n]]
    
    print(f"\nTop {top_n} projects by total connections:")
    for i, (project, total_links) in enumerate(sorted_projects[:top_n], 1):
        print(f"{i:2d}. {project:8s}: {total_links:6d} total links")
    
    # Create symmetric matrix
    matrix_size = len(top_projects)
    connection_matrix = np.zeros((matrix_size, matrix_size))
    
    # Fill the matrix with connection data
    for i, proj1 in enumerate(top_projects):
        for j, proj2 in enumerate(top_projects):
            # Look for connections between proj1 and proj2
            connections = df[(df['SourceProject'] == proj1) & (df['TargetProject'] == proj2)]
            
            if not connections.empty:
                connection_matrix[i][j] = connections['TotalLinks'].values[0]
    
    return connection_matrix, top_projects

def create_heatmap(connection_matrix, top_projects, output_file):
    """Create and save the heatmap"""
    
    # Set up the plot
    plt.figure(figsize=(18, 14))
    
    # Create the heatmap
    # Use log scale for better visualization of wide range of values
    log_matrix = np.log1p(connection_matrix)  # log(1 + x) to handle zeros
    
    sns.heatmap(log_matrix, 
                xticklabels=top_projects,
                yticklabels=top_projects,
                annot=connection_matrix.astype(int),  # Show raw values as annotations
                fmt='d',
                cmap='YlOrRd',  # Yellow to Red colormap
                cbar_kws={'label': 'Log(Links + 1)'},
                square=True,
                linewidths=0.5,
                annot_kws={'fontsize': 7})
    
    # Customize the plot
    plt.title('OMF Top 30 Projects Connection Heatmap\n(Filtered Dataset - Excluding ORL, TOKR, RC, EOKR, OBSRV, EPMC, EDME)', 
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
    print("CONNECTION ANALYSIS")
    print(f"{'='*60}")
    
    # Find strongest connections (excluding self-connections)
    connections_list = []
    for i in range(len(top_projects)):
        for j in range(len(top_projects)):
            if i != j and connection_matrix[i][j] > 0:
                connections_list.append((top_projects[i], top_projects[j], connection_matrix[i][j]))
    
    # Sort by connection strength
    connections_list.sort(key=lambda x: x[2], reverse=True)
    
    print(f"\nTop 10 strongest project connections:")
    for idx, (proj1, proj2, connections) in enumerate(connections_list[:10], 1):
        print(f"{idx:2d}. {proj1:8s} -> {proj2:8s}: {int(connections):5d} links")
    
    # Calculate total connections for each project
    project_connection_totals = {}
    for i, project in enumerate(top_projects):
        total_out = np.sum(connection_matrix[i]) - connection_matrix[i][i]  # Exclude self-links
        total_in = np.sum(connection_matrix[:, i]) - connection_matrix[i][i]  # Exclude self-links
        project_connection_totals[project] = total_out + total_in
    
    print(f"\nTop 10 most connected projects in heatmap:")
    sorted_by_connections = sorted(project_connection_totals.items(), key=lambda x: x[1], reverse=True)
    for i, (project, total_connections) in enumerate(sorted_by_connections[:10], 1):
        print(f"{i:2d}. {project:8s}: {int(total_connections):6d} total connections")
    
    # Find self-linking projects
    self_linkers = []
    for i, project in enumerate(top_projects):
        if connection_matrix[i][i] > 0:
            self_linkers.append((project, int(connection_matrix[i][i])))
    
    if self_linkers:
        self_linkers.sort(key=lambda x: x[1], reverse=True)
        print(f"\nTop 10 projects with most self-links:")
        for idx, (project, self_links) in enumerate(self_linkers[:10], 1):
            print(f"{idx:2d}. {project:8s}: {self_links:5d} self-links")

def main():
    """Main function to create the filtered heatmap"""
    
    print("Creating filtered project connection heatmap...")
    print("Excluded projects: ORL, TOKR, RC, EOKR, OBSRV, EPMC, EDME\n")
    
    # Load data from PowerShell script output
    csv_file = './Project_to_Project_Detailed_Connections.csv'
    df = load_and_process_data(csv_file)
    
    print(f"\n{'='*60}")
    print("CREATING FILTERED PROJECT CONNECTION HEATMAP")
    print(f"{'='*60}")
    
    # Create connection matrix for top 30 projects
    connection_matrix, top_projects = create_project_connection_matrix(df, top_n=30)
    
    # Create and save heatmap
    output_file = 'project_connection_heatmap_filtered_no_7projects.png'
    create_heatmap(connection_matrix, top_projects, output_file)
    
    # Analyze connections
    analyze_connections(connection_matrix, top_projects)
    
    print(f"\n{'='*60}")
    print("HEATMAP CREATION COMPLETE")
    print(f"{'='*60}")
    print(f"Output file: {output_file}")
    print(f"Projects analyzed: {len(top_projects)}")
    print(f"Matrix size: {connection_matrix.shape}")
    print(f"Total connections in heatmap: {int(np.sum(connection_matrix))}")

if __name__ == "__main__":
    main()

