#!/usr/bin/env python3
"""
Create Filtered Project Connection Heatmap
Excludes ORL, TOKR, and RC projects
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import warnings
warnings.filterwarnings('ignore')

def load_and_process_data(csv_file):
    """Load and process the filtered project relationship data"""
    df = pd.read_csv(csv_file)
    
    # Clean up the data
    df['LinkCount'] = pd.to_numeric(df['LinkCount'], errors='coerce').fillna(0)
    
    print(f"Loaded {len(df)} project relationships")
    print(f"Total links: {df['LinkCount'].sum()}")
    
    return df

def create_project_connection_matrix(df, top_n=20):
    """Create a symmetric matrix of project connections"""
    
    # Get all unique projects
    all_projects = sorted(set(df['ProjectKey'].unique()) | set(df['ConnectedProject'].unique()))
    print(f"Total unique projects: {len(all_projects)}")
    
    # Calculate total connections for each project
    project_totals = {}
    for _, row in df.iterrows():
        proj1 = row['ProjectKey']
        proj2 = row['ConnectedProject']
        link_count = row['LinkCount']
        
        if proj1 not in project_totals:
            project_totals[proj1] = 0
        if proj2 not in project_totals:
            project_totals[proj2] = 0
        
        project_totals[proj1] += link_count
        project_totals[proj2] += link_count
    
    # Get top N projects by total connections
    sorted_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)
    top_projects = [proj for proj, _ in sorted_projects[:top_n]]
    
    print(f"\nTop {top_n} projects by total connections:")
    for i, (project, total_links) in enumerate(sorted_projects[:top_n], 1):
        print(f"{i:2d}. {project:8s}: {total_links:4d} total links")
    
    # Create symmetric matrix
    matrix_size = len(top_projects)
    connection_matrix = np.zeros((matrix_size, matrix_size))
    
    # Fill the matrix with connection data
    for i, proj1 in enumerate(top_projects):
        for j, proj2 in enumerate(top_projects):
            if i != j:  # Don't include self-connections
                # Look for connections between proj1 and proj2
                connections = 0
                for _, row in df.iterrows():
                    if ((row['ProjectKey'] == proj1 and row['ConnectedProject'] == proj2) or
                        (row['ProjectKey'] == proj2 and row['ConnectedProject'] == proj1)):
                        connections += row['LinkCount']
                
                connection_matrix[i][j] = connections
    
    return connection_matrix, top_projects

def create_heatmap(connection_matrix, top_projects, output_file):
    """Create and save the heatmap"""
    
    # Set up the plot
    plt.figure(figsize=(16, 12))
    
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
                annot_kws={'fontsize': 8})
    
    # Customize the plot
    plt.title('OMF Top 20 Projects Connection Heatmap\n(Filtered Dataset - Excluding ORL, TOKR, RC, EOKR, OBSRV)', 
              fontsize=16, fontweight='bold', pad=20)
    plt.xlabel('Connected Project', fontsize=12, fontweight='bold')
    plt.ylabel('Source Project', fontsize=12, fontweight='bold')
    
    # Rotate x-axis labels for better readability
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)
    
    # Adjust layout to prevent label cutoff
    plt.tight_layout()
    
    # Save the plot
    plt.savefig(output_file, dpi=300, bbox_inches='tight')
    plt.close()
    
    print(f"Heatmap saved as: {output_file}")

def analyze_connections(connection_matrix, top_projects):
    """Analyze and print connection statistics"""
    
    print(f"\n{'='*60}")
    print("CONNECTION ANALYSIS")
    print(f"{'='*60}")
    
    # Find strongest connections
    max_connections = 0
    strongest_pairs = []
    
    for i in range(len(top_projects)):
        for j in range(i+1, len(top_projects)):
            connections = connection_matrix[i][j]
            if connections > max_connections:
                max_connections = connections
                strongest_pairs = [(top_projects[i], top_projects[j], connections)]
            elif connections == max_connections:
                strongest_pairs.append((top_projects[i], top_projects[j], connections))
    
    print(f"Strongest project connections:")
    for proj1, proj2, connections in strongest_pairs:
        print(f"  {proj1} ↔ {proj2}: {connections} links")
    
    # Calculate total connections for each project
    project_connection_totals = {}
    for i, project in enumerate(top_projects):
        total_connections = np.sum(connection_matrix[i]) + np.sum(connection_matrix[:, i])
        project_connection_totals[project] = total_connections
    
    print(f"\nTop 10 most connected projects in heatmap:")
    sorted_by_connections = sorted(project_connection_totals.items(), key=lambda x: x[1], reverse=True)
    for i, (project, total_connections) in enumerate(sorted_by_connections[:10], 1):
        print(f"{i:2d}. {project:8s}: {int(total_connections):4d} total connections")
    
    # Count projects with no connections
    isolated_projects = []
    for i, project in enumerate(top_projects):
        total_connections = np.sum(connection_matrix[i]) + np.sum(connection_matrix[:, i])
        if total_connections == 0:
            isolated_projects.append(project)
    
    if isolated_projects:
        print(f"\nIsolated projects (no connections to other top 20): {', '.join(isolated_projects)}")
    else:
        print(f"\nAll top 20 projects have connections to other projects in the set")

def main():
    """Main function to create the filtered heatmap"""
    
    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Final Filtered - Exclude ORL TOKR RC EOKR OBSRV - Anon - Official.csv'
    df = load_and_process_data(csv_file)
    
    print(f"\n{'='*60}")
    print("CREATING FILTERED PROJECT CONNECTION HEATMAP")
    print(f"{'='*60}")
    
    # Create connection matrix
    connection_matrix, top_projects = create_project_connection_matrix(df, top_n=20)
    
    # Create and save heatmap
    output_file = 'project_connection_heatmap_filtered_no_orl_tokr_rc_eokr_obsrv.png'
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
