# =============================================================================
# JIRA ENTERPRISE SECURITY SYSTEM
# =============================================================================

# Enterprise-grade security system for Jira analytics
# This system provides comprehensive security, compliance, and governance

param(
    [string]$SecurityType = "all",
    [switch]$EnableAuditLogging = $false,
    [switch]$EnableDataEncryption = $false,
    [switch]$EnableAccessControl = $false,
    [switch]$EnableCompliance = $false,
    [string]$ComplianceStandard = "SOC2",
    [switch]$EnableBackup = $false,
    [string]$BackupLocation = "",
    [switch]$EnableRecovery = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Security configuration
$SecurityConfig = @{
    "audit_logging" = $EnableAuditLogging
    "data_encryption" = $EnableDataEncryption
    "access_control" = $EnableAccessControl
    "compliance" = $EnableCompliance
    "compliance_standard" = $ComplianceStandard
    "backup" = $EnableBackup
    "backup_location" = $BackupLocation
    "recovery" = $EnableRecovery
    "encryption_key" = $env:ENCRYPTION_KEY
    "audit_retention_days" = 90
    "backup_retention_days" = 30
    "access_control_rules" = @{
        "admin_users" = @($env:ADMIN_USERS -split ",")
        "read_only_users" = @($env:READ_ONLY_USERS -split ",")
        "restricted_projects" = @($env:RESTRICTED_PROJECTS -split ",")
        "sensitive_fields" = @("description", "comments", "attachments")
    }
    "compliance_requirements" = @{
        "SOC2" = @{
            "data_retention" = 7
            "audit_trail" = $true
            "access_logging" = $true
            "encryption_required" = $true
        }
        "GDPR" = @{
            "data_retention" = 30
            "audit_trail" = $true
            "access_logging" = $true
            "encryption_required" = $true
            "data_anonymization" = $true
        }
        "HIPAA" = @{
            "data_retention" = 6
            "audit_trail" = $true
            "access_logging" = $true
            "encryption_required" = $true
            "access_control" = $true
        }
    }
}

# Security state
$SecurityState = @{
    "audit_log" = @()
    "access_log" = @()
    "encryption_keys" = @{}
    "backup_history" = @()
    "compliance_status" = @{}
    "security_incidents" = @()
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

function Get-JiraData {
    param(
        [string]$Endpoint,
        [string]$JQL = "",
        [string]$User = "",
        [string]$Action = "READ"
    )
    
    # Log access
    if ($SecurityConfig.audit_logging) {
        Log-AuditEvent -User $User -Action $Action -Resource $Endpoint -Details $JQL
    }
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
        "Content-Type" = "application/json"
    }
    
    $url = if ($JQL) {
        "$JiraBaseUrl/search?jql=$([Uri]::EscapeDataString($JQL))&maxResults=999999"
    } else {
        "$JiraBaseUrl/$Endpoint"
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        
        # Encrypt sensitive data if required
        if ($SecurityConfig.data_encryption) {
            $response = Encrypt-SensitiveData -Data $response -User $User
        }
        
        return $response
    }
    catch {
        Log-SecurityIncident -Type "API_ACCESS_FAILED" -User $User -Details $_.Exception.Message
        Write-Error "Failed to get Jira data: $($_.Exception.Message)"
        return $null
    }
}

function Log-AuditEvent {
    param(
        [string]$User,
        [string]$Action,
        [string]$Resource,
        [string]$Details = "",
        [string]$Result = "SUCCESS"
    )
    
    $auditEvent = @{
        "timestamp" = Get-Date
        "user" = $User
        "action" = $Action
        "resource" = $Resource
        "details" = $Details
        "result" = $Result
        "ip_address" = $env:COMPUTERNAME
        "session_id" = [System.Guid]::NewGuid().ToString()
    }
    
    $SecurityState.audit_log += $auditEvent
    
    # Keep only last N days of audit logs
    $cutoffDate = (Get-Date).AddDays(-$SecurityConfig.audit_retention_days)
    $SecurityState.audit_log = $SecurityState.audit_log | Where-Object { $_.timestamp -gt $cutoffDate }
    
    # Write to audit log file
    $auditLogPath = ".\audit-log.json"
    $SecurityState.audit_log | ConvertTo-Json -Depth 10 | Out-File -FilePath $auditLogPath -Encoding UTF8
    
    Write-Host "Audit event logged: $Action by $User on $Resource" -ForegroundColor Green
}

function Log-SecurityIncident {
    param(
        [string]$Type,
        [string]$User,
        [string]$Details,
        [string]$Severity = "Medium"
    )
    
    $incident = @{
        "timestamp" = Get-Date
        "type" = $Type
        "user" = $User
        "details" = $Details
        "severity" = $Severity
        "status" = "Open"
        "incident_id" = [System.Guid]::NewGuid().ToString()
    }
    
    $SecurityState.security_incidents += $incident
    
    # Write to security incidents file
    $incidentsPath = ".\security-incidents.json"
    $SecurityState.security_incidents | ConvertTo-Json -Depth 10 | Out-File -FilePath $incidentsPath -Encoding UTF8
    
    Write-Host "🚨 SECURITY INCIDENT: $Type - $Details" -ForegroundColor Red
}

function Encrypt-SensitiveData {
    param(
        [object]$Data,
        [string]$User
    )
    
    if (-not $SecurityConfig.data_encryption -or -not $SecurityConfig.encryption_key) {
        return $Data
    }
    
    try {
        # Simple encryption using AES (in production, use proper key management)
        $key = [System.Text.Encoding]::UTF8.GetBytes($SecurityConfig.encryption_key.PadRight(32, "0"))
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        $aes.GenerateIV()
        
        # Encrypt sensitive fields
        if ($Data -is [array]) {
            foreach ($item in $Data) {
                if ($item.fields) {
                    foreach ($field in $SecurityConfig.access_control_rules.sensitive_fields) {
                        if ($item.fields.$field) {
                            $plaintext = [System.Text.Encoding]::UTF8.GetBytes($item.fields.$field)
                            $encryptor = $aes.CreateEncryptor()
                            $encrypted = $encryptor.TransformFinalBlock($plaintext, 0, $plaintext.Length)
                            $item.fields.$field = [Convert]::ToBase64String($encrypted)
                        }
                    }
                }
            }
        }
        
        return $Data
    }
    catch {
        Log-SecurityIncident -Type "ENCRYPTION_FAILED" -User $User -Details $_.Exception.Message
        return $Data
    }
}

function Decrypt-SensitiveData {
    param(
        [object]$Data,
        [string]$User
    )
    
    if (-not $SecurityConfig.data_encryption -or -not $SecurityConfig.encryption_key) {
        return $Data
    }
    
    try {
        $key = [System.Text.Encoding]::UTF8.GetBytes($SecurityConfig.encryption_key.PadRight(32, "0"))
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.Key = $key
        
        # Decrypt sensitive fields
        if ($Data -is [array]) {
            foreach ($item in $Data) {
                if ($item.fields) {
                    foreach ($field in $SecurityConfig.access_control_rules.sensitive_fields) {
                        if ($item.fields.$field) {
                            $encrypted = [Convert]::FromBase64String($item.fields.$field)
                            $decryptor = $aes.CreateDecryptor()
                            $decrypted = $decryptor.TransformFinalBlock($encrypted, 0, $encrypted.Length)
                            $item.fields.$field = [System.Text.Encoding]::UTF8.GetString($decrypted)
                        }
                    }
                }
            }
        }
        
        return $Data
    }
    catch {
        Log-SecurityIncident -Type "DECRYPTION_FAILED" -User $User -Details $_.Exception.Message
        return $Data
    }
}

function Check-AccessControl {
    param(
        [string]$User,
        [string]$Resource,
        [string]$Action
    )
    
    if (-not $SecurityConfig.access_control) {
        return $true
    }
    
    $rules = $SecurityConfig.access_control_rules
    
    # Check if user is admin
    if ($rules.admin_users -contains $User) {
        return $true
    }
    
    # Check if user is read-only
    if ($rules.read_only_users -contains $User -and $Action -ne "READ") {
        Log-SecurityIncident -Type "UNAUTHORIZED_ACCESS" -User $User -Details "Read-only user attempted $Action on $Resource" -Severity "High"
        return $false
    }
    
    # Check restricted projects
    if ($rules.restricted_projects -contains $Resource) {
        Log-SecurityIncident -Type "RESTRICTED_ACCESS" -User $User -Details "User attempted to access restricted project $Resource" -Severity "Medium"
        return $false
    }
    
    return $true
}

function Create-Backup {
    param(
        [string]$BackupType = "Full"
    )
    
    if (-not $SecurityConfig.backup) {
        Write-Warning "Backup not enabled"
        return
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupPath = if ($SecurityConfig.backup_location) {
        "$($SecurityConfig.backup_location)\jira-backup-$timestamp"
    } else {
        ".\backups\jira-backup-$timestamp"
    }
    
    try {
        # Create backup directory
        if (-not (Test-Path $backupPath)) {
            New-Item -ItemType Directory -Path $backupPath -Force
        }
        
        # Backup configuration
        $configBackup = @{
            "timestamp" = Get-Date
            "type" = $BackupType
            "security_config" = $SecurityConfig
            "backup_path" = $backupPath
        }
        $configBackup | ConvertTo-Json -Depth 10 | Out-File -FilePath "$backupPath\config.json" -Encoding UTF8
        
        # Backup audit logs
        if ($SecurityState.audit_log.Count -gt 0) {
            $SecurityState.audit_log | ConvertTo-Json -Depth 10 | Out-File -FilePath "$backupPath\audit-log.json" -Encoding UTF8
        }
        
        # Backup security incidents
        if ($SecurityState.security_incidents.Count -gt 0) {
            $SecurityState.security_incidents | ConvertTo-Json -Depth 10 | Out-File -FilePath "$backupPath\security-incidents.json" -Encoding UTF8
        }
        
        # Backup compliance status
        if ($SecurityState.compliance_status.Count -gt 0) {
            $SecurityState.compliance_status | ConvertTo-Json -Depth 10 | Out-File -FilePath "$backupPath\compliance-status.json" -Encoding UTF8
        }
        
        $backupRecord = @{
            "timestamp" = Get-Date
            "type" = $BackupType
            "path" = $backupPath
            "size" = (Get-ChildItem $backupPath -Recurse | Measure-Object -Property Length -Sum).Sum
            "status" = "Success"
        }
        
        $SecurityState.backup_history += $backupRecord
        
        # Cleanup old backups
        $cutoffDate = (Get-Date).AddDays(-$SecurityConfig.backup_retention_days)
        $SecurityState.backup_history = $SecurityState.backup_history | Where-Object { $_.timestamp -gt $cutoffDate }
        
        Write-Host "Backup created successfully: $backupPath" -ForegroundColor Green
        Log-AuditEvent -User "SYSTEM" -Action "BACKUP_CREATED" -Resource $backupPath -Details "Backup type: $BackupType"
    }
    catch {
        Write-Error "Failed to create backup: $($_.Exception.Message)"
        Log-SecurityIncident -Type "BACKUP_FAILED" -User "SYSTEM" -Details $_.Exception.Message
    }
}

function Restore-Backup {
    param(
        [string]$BackupPath
    )
    
    if (-not $SecurityConfig.recovery) {
        Write-Warning "Recovery not enabled"
        return
    }
    
    if (-not (Test-Path $BackupPath)) {
        Write-Error "Backup path does not exist: $BackupPath"
        return
    }
    
    try {
        # Restore configuration
        if (Test-Path "$BackupPath\config.json") {
            $config = Get-Content "$BackupPath\config.json" | ConvertFrom-Json
            Write-Host "Restoring configuration from backup" -ForegroundColor Green
        }
        
        # Restore audit logs
        if (Test-Path "$BackupPath\audit-log.json") {
            $SecurityState.audit_log = Get-Content "$BackupPath\audit-log.json" | ConvertFrom-Json
            Write-Host "Restored $($SecurityState.audit_log.Count) audit log entries" -ForegroundColor Green
        }
        
        # Restore security incidents
        if (Test-Path "$BackupPath\security-incidents.json") {
            $SecurityState.security_incidents = Get-Content "$BackupPath\security-incidents.json" | ConvertFrom-Json
            Write-Host "Restored $($SecurityState.security_incidents.Count) security incidents" -ForegroundColor Green
        }
        
        # Restore compliance status
        if (Test-Path "$BackupPath\compliance-status.json") {
            $SecurityState.compliance_status = Get-Content "$BackupPath\compliance-status.json" | ConvertFrom-Json
            Write-Host "Restored compliance status" -ForegroundColor Green
        }
        
        Write-Host "Backup restored successfully from: $BackupPath" -ForegroundColor Green
        Log-AuditEvent -User "SYSTEM" -Action "BACKUP_RESTORED" -Resource $BackupPath -Details "Recovery operation completed"
    }
    catch {
        Write-Error "Failed to restore backup: $($_.Exception.Message)"
        Log-SecurityIncident -Type "RESTORE_FAILED" -User "SYSTEM" -Details $_.Exception.Message
    }
}

# =============================================================================
# COMPLIANCE FUNCTIONS
# =============================================================================

function Check-Compliance {
    param(
        [string]$Standard = ""
    )
    
    $standard = if ($Standard) { $Standard } else { $SecurityConfig.compliance_standard }
    $requirements = $SecurityConfig.compliance_requirements[$standard]
    
    if (-not $requirements) {
        Write-Warning "Unknown compliance standard: $standard"
        return
    }
    
    Write-Host "Checking compliance for $standard..." -ForegroundColor Cyan
    
    $complianceStatus = @{
        "standard" = $standard
        "timestamp" = Get-Date
        "requirements" = @{}
        "overall_status" = "Compliant"
    }
    
    # Check data retention
    if ($requirements.data_retention) {
        $retentionDays = $requirements.data_retention
        $cutoffDate = (Get-Date).AddDays(-$retentionDays)
        $oldAuditLogs = $SecurityState.audit_log | Where-Object { $_.timestamp -lt $cutoffDate }
        
        $complianceStatus.requirements["data_retention"] = @{
            "status" = if ($oldAuditLogs.Count -eq 0) { "Compliant" } else { "Non-Compliant" }
            "details" = "Found $($oldAuditLogs.Count) audit logs older than $retentionDays days"
        }
        
        if ($oldAuditLogs.Count -gt 0) {
            $complianceStatus.overall_status = "Non-Compliant"
        }
    }
    
    # Check audit trail
    if ($requirements.audit_trail) {
        $auditLogCount = $SecurityState.audit_log.Count
        $complianceStatus.requirements["audit_trail"] = @{
            "status" = if ($auditLogCount -gt 0) { "Compliant" } else { "Non-Compliant" }
            "details" = "Audit log contains $auditLogCount entries"
        }
        
        if ($auditLogCount -eq 0) {
            $complianceStatus.overall_status = "Non-Compliant"
        }
    }
    
    # Check access logging
    if ($requirements.access_logging) {
        $accessLogCount = $SecurityState.access_log.Count
        $complianceStatus.requirements["access_logging"] = @{
            "status" = if ($accessLogCount -gt 0) { "Compliant" } else { "Non-Compliant" }
            "details" = "Access log contains $accessLogCount entries"
        }
        
        if ($accessLogCount -eq 0) {
            $complianceStatus.overall_status = "Non-Compliant"
        }
    }
    
    # Check encryption
    if ($requirements.encryption_required) {
        $encryptionEnabled = $SecurityConfig.data_encryption
        $complianceStatus.requirements["encryption"] = @{
            "status" = if ($encryptionEnabled) { "Compliant" } else { "Non-Compliant" }
            "details" = "Data encryption is $($encryptionEnabled ? 'enabled' : 'disabled')"
        }
        
        if (-not $encryptionEnabled) {
            $complianceStatus.overall_status = "Non-Compliant"
        }
    }
    
    # Check access control
    if ($requirements.access_control) {
        $accessControlEnabled = $SecurityConfig.access_control
        $complianceStatus.requirements["access_control"] = @{
            "status" = if ($accessControlEnabled) { "Compliant" } else { "Non-Compliant" }
            "details" = "Access control is $($accessControlEnabled ? 'enabled' : 'disabled')"
        }
        
        if (-not $accessControlEnabled) {
            $complianceStatus.overall_status = "Non-Compliant"
        }
    }
    
    $SecurityState.compliance_status[$standard] = $complianceStatus
    
    # Write compliance report
    $compliancePath = ".\compliance-report-$standard.json"
    $complianceStatus | ConvertTo-Json -Depth 10 | Out-File -FilePath $compliancePath -Encoding UTF8
    
    Write-Host "Compliance check completed for $standard: $($complianceStatus.overall_status)" -ForegroundColor Green
    return $complianceStatus
}

function Generate-ComplianceReport {
    param(
        [string]$Standard = "",
        [string]$OutputPath = ""
    )
    
    $standard = if ($Standard) { $Standard } else { $SecurityConfig.compliance_standard }
    $complianceStatus = Check-Compliance -Standard $standard
    
    $reportPath = if ($OutputPath) { $OutputPath } else { ".\compliance-report-$standard-$(Get-Date -Format 'yyyyMMdd').html" }
    
    $htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Compliance Report - $standard</title>
    <meta charset="utf-8">
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #0052cc; color: white; padding: 20px; border-radius: 5px; }
        .status-compliant { color: green; font-weight: bold; }
        .status-non-compliant { color: red; font-weight: bold; }
        .requirement { margin: 10px 0; padding: 10px; border-left: 4px solid #0052cc; background: #f5f5f5; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Compliance Report - $standard</h1>
        <p>Generated: $($complianceStatus.timestamp.ToString("yyyy-MM-dd HH:mm:ss"))</p>
        <p>Overall Status: <span class="status-$($complianceStatus.overall_status.ToLower().Replace('-', '-'))">$($complianceStatus.overall_status)</span></p>
    </div>
    
    <h2>Requirements</h2>
"@
    
    foreach ($requirement in $complianceStatus.requirements.Keys) {
        $req = $complianceStatus.requirements[$requirement]
        $statusClass = $req.status.ToLower().Replace("-", "-")
        $htmlReport += @"
    <div class="requirement">
        <h3>$requirement</h3>
        <p>Status: <span class="status-$statusClass">$($req.status)</span></p>
        <p>Details: $($req.details)</p>
    </div>
"@
    }
    
    $htmlReport += @"
</body>
</html>
"@
    
    $htmlReport | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Compliance report generated: $reportPath" -ForegroundColor Green
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Enterprise Security System" -ForegroundColor Green
Write-Host "===============================" -ForegroundColor Green
Write-Host "Security Type: $SecurityType" -ForegroundColor Yellow
Write-Host "Audit Logging: $EnableAuditLogging" -ForegroundColor Yellow
Write-Host "Data Encryption: $EnableDataEncryption" -ForegroundColor Yellow
Write-Host "Access Control: $EnableAccessControl" -ForegroundColor Yellow
Write-Host "Compliance: $EnableCompliance ($ComplianceStandard)" -ForegroundColor Yellow
Write-Host "Backup: $EnableBackup" -ForegroundColor Yellow
Write-Host "Recovery: $EnableRecovery" -ForegroundColor Yellow

try {
    switch ($SecurityType.ToLower()) {
        "audit" {
            Write-Host "Audit logging system initialized" -ForegroundColor Green
            Log-AuditEvent -User "SYSTEM" -Action "SECURITY_SYSTEM_STARTED" -Resource "Security System" -Details "Audit logging enabled"
        }
        "encryption" {
            Write-Host "Data encryption system initialized" -ForegroundColor Green
            if (-not $SecurityConfig.encryption_key) {
                Write-Warning "Encryption key not configured. Set ENCRYPTION_KEY environment variable."
            }
        }
        "access" {
            Write-Host "Access control system initialized" -ForegroundColor Green
            Write-Host "Admin users: $($SecurityConfig.access_control_rules.admin_users -join ', ')" -ForegroundColor Yellow
            Write-Host "Read-only users: $($SecurityConfig.access_control_rules.read_only_users -join ', ')" -ForegroundColor Yellow
        }
        "compliance" {
            Write-Host "Compliance system initialized" -ForegroundColor Green
            $complianceStatus = Check-Compliance -Standard $ComplianceStandard
            Generate-ComplianceReport -Standard $ComplianceStandard
        }
        "backup" {
            Write-Host "Backup system initialized" -ForegroundColor Green
            Create-Backup -BackupType "Full"
        }
        "all" {
            Write-Host "All security systems initialized" -ForegroundColor Green
            
            if ($EnableAuditLogging) {
                Log-AuditEvent -User "SYSTEM" -Action "SECURITY_SYSTEM_STARTED" -Resource "Security System" -Details "All security systems enabled"
            }
            
            if ($EnableCompliance) {
                $complianceStatus = Check-Compliance -Standard $ComplianceStandard
                Generate-ComplianceReport -Standard $ComplianceStandard
            }
            
            if ($EnableBackup) {
                Create-Backup -BackupType "Full"
            }
        }
        default {
            Write-Warning "Unknown security type: $SecurityType. Use 'all', 'audit', 'encryption', 'access', 'compliance', or 'backup'"
        }
    }
}
catch {
    Write-Error "Error during security system initialization: $($_.Exception.Message)"
    Log-SecurityIncident -Type "SYSTEM_ERROR" -User "SYSTEM" -Details $_.Exception.Message -Severity "High"
}

Write-Host "Enterprise security system finished." -ForegroundColor Green
