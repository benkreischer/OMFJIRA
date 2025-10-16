# =============================================================================
# ENDPOINT: Issue Links - GET Project to Project Links (Hybrid)
# =============================================================================
#
# DESCRIPTION: Returns a summary showing each project key and all the project
# keys it's linked to through issue links. Shows one row per project with
# all their linked project keys.
#
# OUTPUT COLUMNS:
# - ProjectKey: The main project key
# - LinkedProjectKeys: Semicolon-separated list of project keys linked to this project
# - LinkCount: Number of unique projects this project is linked to
# - GeneratedAt: Timestamp when data was generated
#
# SETUP:
# 1. Run this script in PowerShell
# 2. Ensure you have internet connectivity to reach Jira
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

# Load required assemblies
Add-Type -AssemblyName System.Web

# Authentication - UPDATE THESE VALUES WITH YOUR CREDENTIALS
$BaseUrl = $Params.BaseUrl
$Username = $Params.Username
$ApiToken = $Params.ApiToken

# Create auth header
$authString = "$username`:$apiToken"
$authBytes = [System.Text.Encoding]::ASCII.GetBytes($authString)
$authHeader = [System.Convert]::ToBase64String($authBytes)

Write-Host "Fetching ALL issues with links using pagination..." -ForegroundColor Green

# Search parameters
$searchEndpoint = "/rest/api/3/search"
$searchUrl = "$baseUrl$searchEndpoint"
$MaxResults = $Params.ApiSettings.MaxResults  # Use smaller batches for better performance
$startAt = 0
$allIssues = @()

# JQL to find all issues with links
$jqlQuery = "issuelinks is not EMPTY ORDER BY project ASC, created DESC"

try {
    # Paginate through all results
    do {
        Write-Host "Fetching batch starting at $startAt..." -ForegroundColor Yellow

        $searchBody = @{
            jql = $jqlQuery
            maxResults = $maxResults
            startAt = $startAt
            fields = @("key", "project", "issuelinks")
        } | ConvertTo-Json -Depth 3

        # Use GET method with URL parameters instead of POST
        $encodedJql = [System.Web.HttpUtility]::UrlEncode($jqlQuery)
        $fieldsParam = "key,project,issuelinks"
        $getUrl = "$searchUrl" + "?jql=$encodedJql&maxResults=$maxResults&startAt=$startAt&fields=$fieldsParam"

        $response = Invoke-RestMethod -Uri $getUrl -Method Get -Headers @{
            "Authorization" = "Basic $authHeader"
            "Accept" = "application/json"
        }

        # Add issues to our collection
        $allIssues += $response.issues

        Write-Host "Retrieved $($response.issues.Count) issues in this batch. Total so far: $($allIssues.Count)" -ForegroundColor Cyan

        # Update startAt for next batch
        $startAt += $maxResults

        # Continue if there are more results
    } while ($response.issues.Count -eq $maxResults -and $startAt -lt $response.total)

    Write-Host "`nTotal issues with links found: $($allIssues.Count)" -ForegroundColor Green

    # Get all projects with status information
    Write-Host "Getting project status information..." -ForegroundColor Yellow
    $ProjectsUrl = "$BaseUrl/rest/api/3/project"
    $AllProjects = @()
    $ProjectStartAt = 0
    $ProjectMaxResults = 100

    do {
        $ProjectUrlWithParams = "$ProjectsUrl" + "?maxResults=$ProjectMaxResults&startAt=$ProjectStartAt"
        try {
            $ProjectResponse = Invoke-RestMethod -Uri $ProjectUrlWithParams -Method Get -Headers @{
                "Authorization" = "Basic $authHeader"
                "Accept" = "application/json"
            }

            if ($ProjectResponse -is [array]) {
                $AllProjects += $ProjectResponse
                $HasMoreProjects = $ProjectResponse.Count -eq $ProjectMaxResults
            } else {
                $HasMoreProjects = $false
            }
            $ProjectStartAt += $ProjectMaxResults
        } catch {
            Write-Host "Failed to fetch projects: $($_.Exception.Message)" -ForegroundColor Red
            break
        }
    } while ($HasMoreProjects)

    Write-Host "Found $($AllProjects.Count) total projects" -ForegroundColor Green

    # Create a hashtable to store project relationships
    $projectLinks = @{}

    # Initialize ALL projects with empty arrays
    foreach ($project in $AllProjects) {
        $projectLinks[$project.key] = @()
    }

    # Process each issue from all batches
    foreach ($issue in $allIssues) {
        $projectKey = $issue.fields.project.key

        if (-not $projectLinks.ContainsKey($projectKey)) {
            $projectLinks[$projectKey] = @()
        }

        # Process issue links
        foreach ($link in $issue.fields.issuelinks) {
            $linkedProjectKey = $null

            if ($link.inwardIssue) {
                $linkedProjectKey = ($link.inwardIssue.key -split '-')[0]
            } elseif ($link.outwardIssue) {
                $linkedProjectKey = ($link.outwardIssue.key -split '-')[0]
            }

            # Add linked project if it's different from current project
            if ($linkedProjectKey -and $linkedProjectKey -ne $projectKey) {
                if ($projectLinks[$projectKey] -notcontains $linkedProjectKey) {
                    $projectLinks[$projectKey] += $linkedProjectKey
                }
            }
        }
    }

    # Create output array
    $results = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    foreach ($project in $projectLinks.Keys | Sort-Object) {
        $linkedProjects = $projectLinks[$project] | Sort-Object

        # Find the project details to get status
        $projectDetails = $AllProjects | Where-Object { $_.key -eq $project } | Select-Object -First 1
        $projectStatus = if ($projectDetails -and $projectDetails.archived) { "Archived" } else { "Active" }

        $results += [PSCustomObject]@{
            ProjectKey = $project
            ProjectStatus = $projectStatus
            LinkedProjectKeys = if ($linkedProjects) { $linkedProjects -join "; " } else { "" }
            LinkCount = $linkedProjects.Count
            GeneratedAt = $timestamp
        }
    }

    Write-Host "`nProject to Project Links Summary:" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan

    $results | Format-Table -AutoSize

    # Export to CSV
    $csvPath = "Issue Links - GET Project to Project Links - Anon - Hybrid.csv"
    $results | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "`nData exported to: $csvPath" -ForegroundColor Green

    return $results

} catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
    Write-Error "Response: $($_.Exception.Response)"
}
