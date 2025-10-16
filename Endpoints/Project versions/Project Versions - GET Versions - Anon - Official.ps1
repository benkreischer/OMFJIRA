# =============================================================================
# ENDPOINT: Project Versions - GET Versions
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-project-versions/#api-rest-api-3-project-projectidorkey-versions-get
#
# DESCRIPTION: Returns all versions in a project.
#
# SETUP: 
# 1. Run this script to generate CSV data
# 2. Update the 'ProjectIdOrKey' parameter.
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
# PARAMETERS
# =============================================================================
$ProjectIdOrKey = $Params.CommonParameters.ProjectIdOrKey # <-- IMPORTANT: Replace with the ID or key of the project
$Expand = "operations,issuesstatus" # <-- OPTIONAL: Use expand to include additional information

# =============================================================================

    # =============================================================================
    # PARAMETER - REQUIRED
    # =============================================================================
    $VersionId = "10722" # <-- IMPORTANT: Replace with valid VersionId
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/project/" + $ProjectIdOrKey + "/versions"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Fetching versions for project $ProjectIdOrKey..."
    $QueryString = "expand=" + [System.Uri]::EscapeDataString($Expand)
    $FullUrlWithQuery = $FullUrl + "?" + $QueryString

    $Response = Invoke-RestMethod -Uri $FullUrlWithQuery -Headers $AuthHeader -Method Get

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response -and $Response.Count -gt 0) {
        foreach ($version in $Response) {
            $VersionData = [PSCustomObject]@{
                ID = $version.id
                Name = $version.name
                Description = $version.description
                Archived = if ($version.archived) { $version.archived.ToString().ToLower() } else { "" }
                Released = if ($version.released) { $version.released.ToString().ToLower() } else { "" }
                StartDate = $version.startDate
                ReleaseDate = $version.releaseDate
                UserStartDate = $version.userStartDate
                UserReleaseDate = $version.userReleaseDate
                ProjectId = $version.projectId
                Self = $version.self
                Operations = if ($version.operations) { (($version.operations | ForEach-Object { $_.label } | Sort-Object) -join "; ") } else { "" }
                OperationsCount = if ($version.operations) { $version.operations.Count } else { 0 }
                IssuesStatusCount = if ($version.issuesStatusForFixVersion) { $version.issuesStatusForFixVersion.Count } else { 0 }
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $VersionData
        }
    } else {
        # If no versions, create a single record with empty data
        $VersionData = [PSCustomObject]@{
            ID = ""
            Name = "No versions found"
            Description = ""
            Archived = ""
            Released = ""
            StartDate = ""
            ReleaseDate = ""
            UserStartDate = ""
            UserReleaseDate = ""
            ProjectId = ""
            Self = ""
            Operations = ""
            OperationsCount = 0
            IssuesStatusCount = 0
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $VersionData
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Project Versions - GET Versions - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Wrote $OutputFile with $($Result.Count) rows."

} catch {
    Write-Error "Failed to retrieve project versions data: $($_.Exception.Message)"
    exit 1
}

