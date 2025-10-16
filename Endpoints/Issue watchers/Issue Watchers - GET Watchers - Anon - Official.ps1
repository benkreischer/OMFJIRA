# =============================================================================
# ENDPOINT: Issue Watchers - GET Watchers
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-watchers/#api-rest-api-3-issue-issueidorkey-watchers-get
#
# DESCRIPTION: Returns the watchers for an issue.
#
# =============================================================================


# =============================================================================
# AUTHENTICATION (from parameters)
# =============================================================================
$AuthHeader = Get-AuthHeader -Parameters $Params
$Headers = Get-RequestHeaders -Parameters $Params


# =============================================================================
# PARAMETERS
# =============================================================================
$IssueIdOrKey = $Params.CommonParameters.IssueIdOrKey  # <-- IMPORTANT: Replace with the ID or key of the issue

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/issue/$IssueIdOrKey/watchers"
$FullUrl = $BaseUrl + $Endpoint

try {
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get
    
    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()
    
    # Process watchers
    if ($Response.watchers -and $Response.watchers.Count -gt 0) {
        foreach ($watcher in $Response.watchers) {
            $WatcherData = [PSCustomObject]@{
                Self = $watcher.self
                Name = $watcher.name
                Key = $watcher.key
                EmailAddress = $watcher.emailAddress
                AvatarUrls = if ($watcher.avatarUrls) { ($watcher.avatarUrls | ConvertTo-Json -Compress) } else { "" }
                DisplayName = $watcher.displayName
                Active = if ($watcher.active) { $watcher.active.ToString().ToLower() } else { "" }
                TimeZone = $watcher.timeZone
                Locale = $watcher.locale
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $Result += $WatcherData
        }
    } else {
        # If no watchers, create a single record with empty data
        $WatcherData = [PSCustomObject]@{
            Self = ""
            Name = ""
            Key = ""
            EmailAddress = ""
            AvatarUrls = ""
            DisplayName = ""
            Active = ""
            TimeZone = ""
            Locale = ""
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $Result += $WatcherData
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "Issue Watchers - GET Watchers - Anon - Official.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Output "Wrote $OutputFile with $($Result.Count) rows."
    
} catch {
    Write-Error "Failed to retrieve watchers data: $($_.Exception.Message)"
    exit 1
}

