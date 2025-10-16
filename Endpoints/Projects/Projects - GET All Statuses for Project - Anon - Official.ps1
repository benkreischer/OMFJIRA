# =============================================================================
# ENDPOINT: Projects - Get All Statuses for Project
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-statuses-get
#
# DESCRIPTION: Returns the valid statuses for a project. The statuses are grouped by issue type, 
# as each project has a set of valid issue types and each issue type has a set of valid statuses.
#
# SETUP: 
# 1. Run this script in PowerShell
# 2. CSV file will be generated automatically
#
# =============================================================================


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
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETER - REQUIRED
# =============================================================================
$ProjectIdOrKey = $Params.CommonParameters.ProjectIdOrKey  # <-- IMPORTANT: Replace "ORL" with a valid Project ID or Key

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/project/" + $ProjectIdOrKey + "/statuses"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Host "Calling API endpoint: $FullUrl"
    
    $Headers = Get-RequestHeaders -Parameters $Params
    
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers -ErrorAction Stop
    
    Write-Host "API call successful. Processing response..."
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Results = @()
    
    if ($Response -and $Response.Count -gt 0) {
        foreach ($IssueType in $Response) {
            # Extract Issue Type details
            $IssueTypeSelf = if ($IssueType.self) { $IssueType.self } else { "" }
            $IssueTypeId = if ($IssueType.id) { $IssueType.id } else { "" }
            $IssueTypeName = if ($IssueType.name) { $IssueType.name } else { "" }
            $IssueTypeSubtask = if ($IssueType.subtask -ne $null) { $IssueType.subtask.ToString().ToLower() } else { "false" }
            
            # Process statuses for this issue type
            if ($IssueType.statuses -and $IssueType.statuses.Count -gt 0) {
                foreach ($Status in $IssueType.statuses) {
                    # Extract Status details
                    $StatusSelf = if ($Status.self) { $Status.self } else { "" }
                    $StatusDescription = if ($Status.description) { $Status.description } else { "" }
                    $StatusIconUrl = if ($Status.iconUrl) { $Status.iconUrl } else { "" }
                    $StatusName = if ($Status.name) { $Status.name } else { "" }
                    $StatusId = if ($Status.id) { $Status.id } else { "" }
                    
                    # Extract Status Category details
                    $StatusCategorySelf = ""
                    $StatusCategoryId = ""
                    $StatusCategoryKey = ""
                    $StatusCategoryColorName = ""
                    $StatusCategoryName = ""
                    
                    if ($Status.statusCategory) {
                        $StatusCategorySelf = if ($Status.statusCategory.self) { $Status.statusCategory.self } else { "" }
                        $StatusCategoryId = if ($Status.statusCategory.id) { $Status.statusCategory.id } else { "" }
                        $StatusCategoryKey = if ($Status.statusCategory.key) { $Status.statusCategory.key } else { "" }
                        $StatusCategoryColorName = if ($Status.statusCategory.colorName) { $Status.statusCategory.colorName } else { "" }
                        $StatusCategoryName = if ($Status.statusCategory.name) { $Status.statusCategory.name } else { "" }
                    }
                    
                    $Result = [PSCustomObject]@{
                        "IssueType.self" = $IssueTypeSelf
                        "IssueType.id" = $IssueTypeId
                        "IssueType.name" = $IssueTypeName
                        "IssueType.subtask" = $IssueTypeSubtask
                        "Status.self" = $StatusSelf
                        "Status.description" = $StatusDescription
                        "Status.iconUrl" = $StatusIconUrl
                        "Status.name" = $StatusName
                        "Status.id" = $StatusId
                        "StatusCategory.self" = $StatusCategorySelf
                        "StatusCategory.id" = $StatusCategoryId
                        "StatusCategory.key" = $StatusCategoryKey
                        "StatusCategory.colorName" = $StatusCategoryColorName
                        "StatusCategory.name" = $StatusCategoryName
                        GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    }
                    $Results += $Result
                }
            } else {
                # Handle issue type with no statuses
                $Result = [PSCustomObject]@{
                    "IssueType.self" = $IssueTypeSelf
                    "IssueType.id" = $IssueTypeId
                    "IssueType.name" = $IssueTypeName
                    "IssueType.subtask" = $IssueTypeSubtask
                    "Status.self" = ""
                    "Status.description" = ""
                    "Status.iconUrl" = ""
                    "Status.name" = ""
                    "Status.id" = ""
                    "StatusCategory.self" = ""
                    "StatusCategory.id" = ""
                    "StatusCategory.key" = ""
                    "StatusCategory.colorName" = ""
                    "StatusCategory.name" = ""
                    GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                }
                $Results += $Result
            }
        }
    } else {
        # Handle empty response
        $Result = [PSCustomObject]@{
            "IssueType.self" = ""
            "IssueType.id" = ""
            "IssueType.name" = ""
            "IssueType.subtask" = "false"
            "Status.self" = ""
            "Status.description" = ""
            "Status.iconUrl" = ""
            "Status.name" = ""
            "Status.id" = ""
            "StatusCategory.self" = ""
            "StatusCategory.id" = ""
            "StatusCategory.key" = ""
            "StatusCategory.colorName" = ""
            "StatusCategory.name" = ""
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET All Statuses for Project - Anon - Official.csv"
    $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "CSV file generated successfully: $CsvPath"
    Write-Host "Records exported: $($Results.Count)"
    
    # Display sample data
    if ($Results.Count -gt 0) {
        Write-Host "`nSample data:"
        $Results | Select-Object -First 3 | Format-Table -AutoSize
    }
    
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        ErrorDescription = $_.Exception.ToString()
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET All Statuses for Project - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}
