# =============================================================================
# ENDPOINT: Status - GET Statuses by Project (Hybrid)
# =============================================================================
#
# DESCRIPTION: Returns all statuses with their ID, Name, Description and the
# project keys that use each status. This combines data from the Statuses API
# and Projects API to provide a comprehensive view of status usage.
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Load the data
#
# =============================================================================
# LOAD HELPER FUNCTIONS
# =============================================================================
$HelperPath = Join-Path $PSScriptRoot "Get-EndpointParameters.ps1"
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

# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


    # =============================================================================
    # GET ALL STATUSES
    # =============================================================================
    $StatusesEndpoint = "/rest/api/3/status"
    $StatusesUrl = $BaseUrl + $StatusesEndpoint

    Write-Output "Fetching all statuses..."
    $StatusesResponse = Invoke-RestMethod -Uri $StatusesUrl -Headers $AuthHeader -Method Get

    # Create hashtable for quick status lookup
    $StatusLookup = @{}
    foreach ($status in $StatusesResponse) {
        $StatusLookup[$status.id] = @{
            Name = $status.name
            Description = if ($status.description) { $status.description } else { "" }
        }
    }

    Write-Output "Found $($StatusesResponse.Count) statuses"

    # =============================================================================
    # GET ALL PROJECTS (WITH PAGINATION)
    # =============================================================================
    Write-Output "Fetching all projects..."
    $AllProjects = @()
    $StartAt = 0
    $MaxResults = $Params.ApiSettings.MaxResults

    do {
        $ProjectsEndpoint = "/rest/api/3/project/search?maxResults=$MaxResults&startAt=$StartAt"
        $ProjectsUrl = $BaseUrl + $ProjectsEndpoint

        Write-Output "Fetching projects batch starting at $StartAt..."
        $ProjectsResponse = Invoke-RestMethod -Uri $ProjectsUrl -Headers $AuthHeader -Method Get

        $AllProjects += $ProjectsResponse.values
        $StartAt += $MaxResults

        Write-Output "Retrieved $($ProjectsResponse.values.Count) projects (Total so far: $($AllProjects.Count))"

    } while ($ProjectsResponse.values.Count -eq $MaxResults)

    $Projects = $AllProjects
    Write-Output "Found $($Projects.Count) total projects"

    # =============================================================================
    # COLLECT STATUS-PROJECT MAPPINGS
    # =============================================================================
    $StatusProjectMap = @{}

    Write-Output "Collecting status usage by project..."
    $ProcessedCount = 0

    foreach ($project in $Projects) {
        $ProcessedCount++
        if ($ProcessedCount % 50 -eq 0) {
            Write-Output "Processed $ProcessedCount/$($Projects.Count) projects..."
        }

        try {
            $ProjectStatusEndpoint = "/rest/api/3/project/$($project.key)/statuses"
            $ProjectStatusUrl = $BaseUrl + $ProjectStatusEndpoint

            $ProjectStatusResponse = Invoke-RestMethod -Uri $ProjectStatusUrl -Headers $AuthHeader -Method Get

            # Extract all status IDs used in this project
            $ProjectStatuses = @()
            foreach ($issueType in $ProjectStatusResponse) {
                foreach ($status in $issueType.statuses) {
                    if ($ProjectStatuses -notcontains $status.id) {
                        $ProjectStatuses += $status.id
                    }
                }
            }

            # Add project key to each status
            foreach ($statusId in $ProjectStatuses) {
                if (-not $StatusProjectMap.ContainsKey($statusId)) {
                    $StatusProjectMap[$statusId] = @()
                }
                $StatusProjectMap[$statusId] += $project.key
            }

        } catch {
            Write-Output "Warning: Could not fetch statuses for project $($project.key): $($_.Exception.Message)"
        }
    }

    Write-Output "Completed project processing. Building final dataset..."

    # =============================================================================
    # BUILD FINAL DATASET
    # =============================================================================
    $Result = @()

    foreach ($status in $StatusesResponse) {
        $ProjectKeys = if ($StatusProjectMap.ContainsKey($status.id)) {
            ($StatusProjectMap[$status.id] | Sort-Object -Unique) -join "; "
        } else {
            "No projects found"
        }

        $StatusData = [PSCustomObject]@{
            ID = $status.id
            Name = $status.name
            ProjectKeys = $ProjectKeys
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $StatusData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Status - GET Statuses by Project - Anon - Hybrid.csv"
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
    $OutputFile = "Status - GET Statuses by Project - Anon - Hybrid.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}
