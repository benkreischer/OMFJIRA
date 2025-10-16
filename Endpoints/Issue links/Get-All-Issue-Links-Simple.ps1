# =============================================================================
# GET ALL ISSUE LINKS - SIMPLE VERSION
# =============================================================================
#
# PURPOSE: Get ALL issues and their links without bulk fetch complexity
# OUTPUT: IssueKey, FirstLinkedIssue, SourceProject, LinkedProject
#
# =============================================================================

# Load helper functions
$HelperPath = Join-Path $PSScriptRoot "..\Get-EndpointParameters.ps1"
. $HelperPath

# Get parameters
$Params = Get-EndpointParameters -ParametersPath (Join-Path $PSScriptRoot "..\endpoints-parameters.json")
$BaseUrl = $Params.BaseUrl
$Headers = Get-RequestHeaders -Parameters $Params
$Headers["Accept"] = "application/json"

Write-Host "=== GETTING ALL ISSUES WITH LINKS ===" -ForegroundColor Green
Write-Host ""

try {
    # Use the regular search API which returns fields directly
    $SearchUrl = "$BaseUrl/rest/api/3/search"
    $AllIssues = @()
    $StartAt = 0
    $MaxResults = 100
    $TotalFetched = 0
    
    Write-Host "Fetching issues with links..." -ForegroundColor Cyan
    
    do {
        # Build URL with JQL
        $JqlQuery = [System.Web.HttpUtility]::UrlEncode('issueLink IS NOT EMPTY AND created >= "2020-01-01"')
        $Url = "${SearchUrl}?jql=${JqlQuery}&startAt=${StartAt}&maxResults=${MaxResults}&fields=key,project,issuelinks,status,resolution"
        
        Write-Host "  Fetching from $StartAt..." -ForegroundColor Gray
        
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method GET -Headers $Headers
            
            $TotalFetched += $Response.issues.Count
            Write-Host "    Retrieved $($Response.issues.Count) issues (Total: $TotalFetched of $($Response.total))" -ForegroundColor Gray
            
            # Process issues immediately
            foreach ($issue in $Response.issues) {
                $IssueKey = $issue.key
                $SourceProject = if ($issue.fields.project) { $issue.fields.project.key } else { "" }
                $Status = if ($issue.fields.status) { $issue.fields.status.name } else { "" }
                $Resolution = if ($issue.fields.resolution) { $issue.fields.resolution.name } else { "Unresolved" }
                
                if ($issue.fields.issuelinks -and $issue.fields.issuelinks.Count -gt 0) {
                    foreach ($link in $issue.fields.issuelinks) {
                        $LinkedIssueKey = $null
                        
                        if ($link.inwardIssue -and $link.inwardIssue.key) {
                            $LinkedIssueKey = $link.inwardIssue.key
                        } elseif ($link.outwardIssue -and $link.outwardIssue.key) {
                            $LinkedIssueKey = $link.outwardIssue.key
                        }
                        
                        if ($LinkedIssueKey) {
                            $LinkedProject = ($LinkedIssueKey -split '-')[0]
                            
                            $AllIssues += [PSCustomObject]@{
                                IssueKey = $IssueKey
                                SourceProject = $SourceProject
                                LinkedIssueKey = $LinkedIssueKey
                                LinkedProject = $LinkedProject
                                Status = $Status
                                Resolution = $Resolution
                                IsCrossProject = ($SourceProject -ne $LinkedProject)
                            }
                        }
                    }
                }
            }
            
            $StartAt += $MaxResults
            $HasMore = ($TotalFetched -lt $Response.total)
            
            # Add small delay to avoid rate limiting
            Start-Sleep -Milliseconds 200
            
        } catch {
            if ($_.Exception.Message -like "*410*") {
                Write-Host "    API endpoint deprecated, switching to Enhanced JQL..." -ForegroundColor Yellow
                break
            }
            throw
        }
        
    } while ($HasMore)
    
    Write-Host ""
    Write-Host "Collected $($AllIssues.Count) issue-link relationships" -ForegroundColor Green
    
    # Export results
    $OutputFile = "All-Issue-Links-Complete.csv"
    $AllIssues | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host ""
    Write-Host "=== SUCCESS ===" -ForegroundColor Green
    Write-Host "Results exported to: $((Get-Location).Path)\$OutputFile" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Total issue-link relationships: $($AllIssues.Count)" -ForegroundColor White
    Write-Host "Cross-project links: $(($AllIssues | Where-Object { $_.IsCrossProject }).Count)" -ForegroundColor Yellow
    Write-Host "Same-project links: $(($AllIssues | Where-Object { -not $_.IsCrossProject }).Count)" -ForegroundColor White
    Write-Host "Unresolved: $(($AllIssues | Where-Object { $_.Resolution -eq 'Unresolved' }).Count)" -ForegroundColor Yellow
    Write-Host "Resolved: $(($AllIssues | Where-Object { $_.Resolution -ne 'Unresolved' }).Count)" -ForegroundColor Green
    Write-Host ""
    
    # Show cross-project summary
    Write-Host "=== CROSS-PROJECT LINK COUNTS ===" -ForegroundColor Cyan
    $CrossProjectLinks = $AllIssues | Where-Object { $_.IsCrossProject }
    $Summary = $CrossProjectLinks | 
        Group-Object @{Expression={"{0} -> {1}" -f $_.SourceProject, $_.LinkedProject}} |
        ForEach-Object {
            $parts = $_.Name -split ' -> '
            [PSCustomObject]@{
                SourceProject = $parts[0]
                LinkedProject = $parts[1]
                LinkCount = $_.Count
                UnresolvedCount = ($_.Group | Where-Object { $_.Resolution -eq 'Unresolved' }).Count
            }
        } | Sort-Object LinkCount -Descending
    
    Write-Host ""
    $Summary | Select-Object -First 20 | Format-Table -AutoSize
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

