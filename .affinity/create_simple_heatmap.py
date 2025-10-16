#!/usr/bin/env python3
"""
Create Simple Project Connection Heatmap
Efficient version focusing on key connections
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

def create_focused_heatmap():
    """Create focused heatmap for top projects only"""

    # Load data
    csv_file = '../.endpoints/Issue search/Issue Links - GET Project to Project Links - Filtered Unresolved 90Day - Anon - Official.csv'
    df = pd.read_csv(csv_file)

    print(f"Processing {len(df)} records...")

    # Get project totals
    project_totals = {}
    for _, row in df.iterrows():
        proj1, proj2, links = row['ProjectKey'], row['ConnectedProject'], row['LinkCount']
        project_totals[proj1] = project_totals.get(proj1, 0) + links
        project_totals[proj2] = project_totals.get(proj2, 0) + links

    # Get top 20 projects
    top_projects = sorted(project_totals.items(), key=lambda x: x[1], reverse=True)[:20]
    top_project_names = [p[0] for p in top_projects]

    print(f"Focusing on top 20 projects: {top_project_names}")

    # Create connection matrix for top projects
    matrix = pd.DataFrame(0, index=top_project_names, columns=top_project_names)

    for _, row in df.iterrows():
        proj1, proj2, links = row['ProjectKey'], row['ConnectedProject'], row['LinkCount']
        if proj1 in top_project_names and proj2 in top_project_names:
            matrix.loc[proj1, proj2] = links
            matrix.loc[proj2, proj1] = links

    # Create heatmap
    plt.figure(figsize=(14, 12))

    # Use log scale for better visualization
    log_matrix = np.log1p(matrix)

    # Create annotations for actual values
    annot_matrix = matrix.copy().astype(str)
    for i in range(len(matrix)):
        for j in range(len(matrix.columns)):
            val = matrix.iloc[i, j]
            if val >= 1000:
                annot_matrix.iloc[i, j] = f'{val/1000:.1f}k'
            elif val > 0:
                annot_matrix.iloc[i, j] = str(int(val))
            else:
                annot_matrix.iloc[i, j] = ''

    # Create heatmap
    ax = sns.heatmap(log_matrix,
                     annot=annot_matrix,
                     fmt='',
                     cmap='YlOrRd',
                     square=True,
                     linewidths=0.5,
                     linecolor='white',
                     cbar_kws={'label': 'Log(Links + 1)'},
                     annot_kws={'size': 8})

    plt.title('OMF Top 20 Projects Connection Heatmap\n(Unresolved Issues, 90-Day Activity)',
              fontsize=14, fontweight='bold', pad=20)
    plt.xticks(rotation=45, ha='right')
    plt.yticks(rotation=0)

    plt.tight_layout()
    plt.savefig('OMF_Project_Heatmap_Top20.png', dpi=300, bbox_inches='tight')
    print("Heatmap saved: OMF_Project_Heatmap_Top20.png")
    plt.close()

    # Print key connections
    print("\nTop 10 Connections:")
    connections = []
    for i in range(len(matrix)):
        for j in range(i+1, len(matrix)):
            val = matrix.iloc[i, j]
            if val > 0:
                connections.append((matrix.index[i], matrix.columns[j], val))

    connections.sort(key=lambda x: x[2], reverse=True)
    for i, (p1, p2, links) in enumerate(connections[:10], 1):
        print(f"{i:2d}. {p1} ↔ {p2}: {links:,} links")

if __name__ == "__main__":
    create_focused_heatmap()