# =============================================================================
# ENDPOINT: Projects - Get Project
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-get
#
# DESCRIPTION: Returns the details for a project.
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
$Endpoint = "/rest/api/3/project/" + $ProjectIdOrKey
$FullUrl = $BaseUrl + $Endpoint + "?expand=" + $Params.QueryParameters.DefaultExpand

try {
    Write-Host "Calling API endpoint: $FullUrl"
    
    $Headers = Get-RequestHeaders -Parameters $Params
    
    $Response = Invoke-RestMethod -Uri $FullUrl -Method GET -Headers $Headers -ErrorAction Stop
    
    Write-Host "API call successful. Processing response..."
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Results = @()
    
    if ($Response) {
        # Handle lead object
        $LeadAccountId = if ($Response.lead -and $Response.lead.accountId) { $Response.lead.accountId } else { "" }
        $LeadDisplayName = if ($Response.lead -and $Response.lead.displayName) { $Response.lead.displayName } else { "" }
        $LeadActive = if ($Response.lead -and $Response.lead.active -ne $null) { $Response.lead.active.ToString().ToLower() } else { "false" }
        
        # Handle description object (Atlassian Document Format)
        $DescriptionContent = if ($Response.description -and $Response.description.content) { 
            # Convert Atlassian Document Format to plain text
            $DescriptionText = ""
            foreach ($content in $Response.description.content) {
                if ($content.content -and $content.content.Count -gt 0) {
                    foreach ($textContent in $content.content) {
                        if ($textContent.text) {
                            $DescriptionText += $textContent.text + " "
                        }
                    }
                }
            }
            $DescriptionText.Trim()
        } else { "" }
        
        # Handle issueTypes array
        $IssueTypes = if ($Response.issueTypes -and $Response.issueTypes.Count -gt 0) {
            $types = @()
            foreach ($type in $Response.issueTypes) {
                $types += "$($type.name) ($($type.id))"
            }
            $types -join "; "
        } else { "" }
        
        # Handle url object
        $UrlValue = if ($Response.url) { $Response.url } else { "" }
        
        # Handle projectKeys array
        $ProjectKeys = if ($Response.projectKeys -and $Response.projectKeys.Count -gt 0) {
            $Response.projectKeys -join "; "
        } else { "" }
        
        # Handle insight object
        $InsightTotalIssueCount = if ($Response.insight -and $Response.insight.totalIssueCount) { $Response.insight.totalIssueCount } else { "" }
        $InsightLastIssueUpdateTime = if ($Response.insight -and $Response.insight.lastIssueUpdateTime) { $Response.insight.lastIssueUpdateTime } else { "" }
        
        $Result = [PSCustomObject]@{
            self = if ($Response.self) { $Response.self } else { "" }
            id = if ($Response.id) { $Response.id } else { "" }
            key = if ($Response.key) { $Response.key } else { "" }
            name = if ($Response.name) { $Response.name } else { "" }
            projectTypeKey = if ($Response.projectTypeKey) { $Response.projectTypeKey } else { "" }
            simplified = if ($Response.simplified -ne $null) { $Response.simplified.ToString().ToLower() } else { "false" }
            style = if ($Response.style) { $Response.style } else { "" }
            isPrivate = if ($Response.isPrivate -ne $null) { $Response.isPrivate.ToString().ToLower() } else { "false" }
            LeadAccountId = $LeadAccountId
            LeadDisplayName = $LeadDisplayName
            LeadActive = $LeadActive
            description = $DescriptionContent
            issueTypes = $IssueTypes
            url = $UrlValue
            projectKeys = $ProjectKeys
            InsightTotalIssueCount = $InsightTotalIssueCount
            InsightLastIssueUpdateTime = $InsightLastIssueUpdateTime
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    } else {
        # Handle empty response
        $Result = [PSCustomObject]@{
            self = ""
            id = ""
            key = ""
            name = ""
            projectTypeKey = ""
            simplified = "false"
            style = ""
            isPrivate = "false"
            LeadAccountId = ""
            LeadDisplayName = ""
            LeadActive = "false"
            description = ""
            issueTypes = ""
            url = ""
            projectKeys = ""
            InsightTotalIssueCount = ""
            InsightLastIssueUpdateTime = ""
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET Project - Anon - Official.csv"
    $Results | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "CSV file generated successfully: $CsvPath"
    Write-Host "Records exported: $($Results.Count)"
    
    # Display sample data
    if ($Results.Count -gt 0) {
        Write-Host "`nSample data:"
        $Results | Select-Object -First 1 | Format-Table -AutoSize
    }
    
} catch {
    Write-Error "API call failed: $($_.Exception.Message)"
    
    # Create error CSV
    $ErrorResult = [PSCustomObject]@{
        Error = $_.Exception.Message
        ErrorDescription = $_.Exception.ToString()
        Timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET Project - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}
