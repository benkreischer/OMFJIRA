# =============================================================================
# ENDPOINT: Projects - Get Project Notification Scheme
# =============================================================================
#
# API DOCUMENTATION: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-projects/#api-rest-api-3-project-projectidorkey-notificationscheme-get
#
# DESCRIPTION: Gets the notification scheme associated with a project.
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
$ProjectIdOrKey = if ($Params.CommonParameters.ProjectIdOrKey) { $Params.CommonParameters.ProjectIdOrKey } else { "DEVEX" }  # Default to DEVEX if not specified

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "/rest/api/3/project/" + $ProjectIdOrKey + "/notificationscheme"
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
    
    # Extract scheme info (matching .pq file logic)
    $SchemeName = if ($Response.name) { $Response.name } else { "" }
    $SchemeId = if ($Response.id) { $Response.id } else { "" }
    
    # Extract notification events
    $NotificationEvents = if ($Response.notificationScheme -and $Response.notificationScheme.notificationSchemeEvents) { 
        $Response.notificationScheme.notificationSchemeEvents 
    } else { @() }
    
    if ($NotificationEvents -and $NotificationEvents.Count -gt 0) {
        foreach ($Event in $NotificationEvents) {
            # Extract event details
            $EventId = if ($Event.event -and $Event.event.id) { $Event.event.id } else { "" }
            $EventName = if ($Event.event -and $Event.event.name) { $Event.event.name } else { "" }
            
            # Process notifications for this event
            if ($Event.notifications -and $Event.notifications.Count -gt 0) {
                foreach ($Notification in $Event.notifications) {
                    $NotificationId = if ($Notification.id) { $Notification.id } else { "" }
                    $NotificationType = if ($Notification.notificationType) { $Notification.notificationType } else { "" }
                    $NotificationParameter = if ($Notification.parameter) { $Notification.parameter } else { "" }
                    $NotificationUser = if ($Notification.user) { $Notification.user } else { "" }
                    
                    $Result = [PSCustomObject]@{
                        "Event.id" = $EventId
                        "Event.name" = $EventName
                        "Notification.id" = $NotificationId
                        "Notification.type" = $NotificationType
                        "Notification.parameter" = $NotificationParameter
                        "Notification.user" = $NotificationUser
                        "Scheme Name" = $SchemeName
                        "Scheme ID" = $SchemeId
                        GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    }
                    $Results += $Result
                }
            } else {
                # Handle event with no notifications
                $Result = [PSCustomObject]@{
                    "Event.id" = $EventId
                    "Event.name" = $EventName
                    "Notification.id" = ""
                    "Notification.type" = ""
                    "Notification.parameter" = ""
                    "Notification.user" = ""
                    "Scheme Name" = $SchemeName
                    "Scheme ID" = $SchemeId
                    GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                }
                $Results += $Result
            }
        }
    } else {
        # Handle empty response
        $Result = [PSCustomObject]@{
            "Event.id" = ""
            "Event.name" = ""
            "Notification.id" = ""
            "Notification.type" = ""
            "Notification.parameter" = ""
            "Notification.user" = ""
            "Scheme Name" = $SchemeName
            "Scheme ID" = $SchemeId
            GeneratedAt = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        $Results += $Result
    }
    
    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET Project Notification Scheme - Anon - Official.csv"
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
    
    $CsvPath = Get-CsvPath -Parameters $Params -FileName "Projects - GET Project Notification Scheme - Anon - Official.csv"
    $ErrorResult | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Error details exported to: $CsvPath"
}
