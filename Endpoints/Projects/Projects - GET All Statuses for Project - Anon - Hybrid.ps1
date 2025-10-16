# =============================================================================
# ENDPOINT: Projects - GET All Statuses for Project (Hybrid)
# =============================================================================
#
# DESCRIPTION: Returns all projects with their key, name, and all the statuses
# used within each project. This combines data from the Projects API and the
# Project Statuses API to provide a comprehensive view of status usage per project.
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Load the data
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path (Split-Path -Parent $PSScriptRoot) "Get-EndpointParameters.ps1"
if (Test-Path $HelperPath) {
    . $HelperPath
} else {
    Write-Error "Helper file not found: $HelperPath"
    exit 1
}

# =============================================================================
# LOAD CONFIGURATION PARAMETERS
# =============================================================================
$Params = Get-EndpointParameters
$BaseUrl = $Params.BaseUrl

# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params

try {
    # =============================================================================
    # GET ALL PROJECTS (WITH PAGINATION)
    # =============================================================================
    Write-Output "Fetching all projects..."
    $AllProjects = @()
    $StartAt = 0
    $MaxResults = $Params.MaxResults

    do {
        $ProjectsEndpoint = "/rest/api/3/project/search?maxResults=$MaxResults&startAt=$StartAt"
        $ProjectsUrl = $BaseUrl + $ProjectsEndpoint

        Write-Output "Fetching projects batch starting at $StartAt..."
        $ProjectsResponse = Invoke-RestMethod -Uri $ProjectsUrl -Headers $Headers -Method Get

        $AllProjects += $ProjectsResponse.values
        $StartAt += $MaxResults

        Write-Output "Retrieved $($ProjectsResponse.values.Count) projects (Total so far: $($AllProjects.Count))"

    } while ($ProjectsResponse.values.Count -eq $MaxResults -and $ProjectsResponse.isLast -ne $true)

    $Projects = $AllProjects
    Write-Output "Found $($Projects.Count) total projects"

    # =============================================================================
    # GET STATUSES FOR EACH PROJECT
    # =============================================================================
    Write-Output "Collecting statuses for each project..."
    $Result = @()
    $ProcessedCount = 0

    foreach ($project in $Projects) {
        $ProcessedCount++
        if ($ProcessedCount % 50 -eq 0) {
            Write-Output "Processed $ProcessedCount/$($Projects.Count) projects..."
        }

        try {
            $ProjectStatusEndpoint = "/rest/api/3/project/$($project.key)/statuses"
            $ProjectStatusUrl = $BaseUrl + $ProjectStatusEndpoint

            $ProjectStatusResponse = Invoke-RestMethod -Uri $ProjectStatusUrl -Headers $Headers -Method Get

            # Extract all status names from all issue types for this project
            $ProjectStatuses = @()
            foreach ($issueType in $ProjectStatusResponse) {
                foreach ($status in $issueType.statuses) {
                    if ($ProjectStatuses -notcontains $status.name) {
                        $ProjectStatuses += $status.name
                    }
                }
            }

            # Sort status names and join with semicolons
            $StatusString = if ($ProjectStatuses.Count -gt 0) {
                ($ProjectStatuses | Sort-Object) -join "; "
            } else {
                "No statuses found"
            }

            $ProjectData = [PSCustomObject]@{
                ProjectKey = $project.key
                ProjectName = $project.name
                ProjectStatuses = $StatusString
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ProjectData

        } catch {
            Write-Output "Warning: Could not fetch statuses for project $($project.key): $($_.Exception.Message)"

            # Add project with error status
            $ProjectData = [PSCustomObject]@{
                ProjectKey = $project.key
                ProjectName = $project.name
                ProjectStatuses = "Error fetching statuses"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $ProjectData
        }
    }

    Write-Output "Completed project processing. Building final dataset..."

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Projects - GET All Statuses for Project - Anon - Hybrid.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "CSV file generated successfully: $(Get-Location)\$OutputFile"
    Write-Output "Records exported: $($Result.Count)"

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Output "
Sample data:"
        $Result | Select-Object -First 5 | Format-Table -AutoSize
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $EmptyData = [PSCustomObject]@{
        Error = $_.Exception.Message
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "Projects - GET All Statuses for Project - Anon - Hybrid.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}
