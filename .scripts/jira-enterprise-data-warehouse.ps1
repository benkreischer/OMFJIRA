# =============================================================================
# JIRA ENTERPRISE DATA WAREHOUSE SYSTEM
# =============================================================================

# Enterprise-grade data warehouse system for Jira analytics
# This system provides historical data storage, ETL pipelines, and data quality monitoring

param(
    [string]$OperationType = "all",
    [switch]$EnableDataWarehouse = $false,
    [switch]$EnableETLPipeline = $false,
    [switch]$EnableDataQuality = $false,
    [switch]$EnableHistoricalStorage = $false,
    [switch]$EnableDataLake = $false,
    [string]$DataWarehousePath = ".\data-warehouse",
    [string]$DataLakePath = ".\data-lake",
    [int]$RetentionDays = 365,
    [switch]$EnableIncrementalLoad = $false,
    [switch]$EnableDataValidation = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Data warehouse configuration
$DataWarehouseConfig = @{
    "enabled" = $EnableDataWarehouse
    "etl_pipeline" = $EnableETLPipeline
    "data_quality" = $EnableDataQuality
    "historical_storage" = $EnableHistoricalStorage
    "data_lake" = $EnableDataLake
    "warehouse_path" = $DataWarehousePath
    "lake_path" = $DataLakePath
    "retention_days" = $RetentionDays
    "incremental_load" = $EnableIncrementalLoad
    "data_validation" = $EnableDataValidation
    "etl_schedule" = "daily"
    "data_quality_thresholds" = @{
        "completeness" = 95
        "accuracy" = 98
        "consistency" = 99
        "timeliness" = 24
    }
    "data_schemas" = @{
        "issues" = @("key", "summary", "status", "assignee", "reporter", "created", "updated", "priority", "issuetype", "project", "duedate", "resolutiondate")
        "projects" = @("key", "name", "description", "lead", "created", "updated", "projectType")
        "users" = @("key", "displayName", "emailAddress", "active", "created", "updated")
        "workflows" = @("id", "name", "description", "statuses", "transitions")
    }
}

# Data warehouse state
$DataWarehouseState = @{
    "last_etl_run" = $null
    "etl_history" = @()
    "data_quality_metrics" = @{}
    "storage_metrics" = @{}
    "validation_results" = @{}
    "incremental_timestamps" = @{}
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

function Get-JiraData {
    param(
        [string]$Endpoint,
        [string]$JQL = "",
        [hashtable]$Parameters = @{}
    )
    
    $headers = @{
        "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
        "Content-Type" = "application/json"
    }
    
    $url = if ($JQL) {
        "$JiraBaseUrl/search?jql=$([Uri]::EscapeDataString($JQL))&maxResults=999999"
    } else {
        "$JiraBaseUrl/$Endpoint"
    }
    
    # Add parameters
    if ($Parameters.Count -gt 0) {
        $queryParams = @()
        foreach ($key in $Parameters.Keys) {
            $queryParams += "$key=$($Parameters[$key])"
        }
        $url += "&" + ($queryParams -join "&")
    }
    
    try {
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        return $response
    }
    catch {
        Write-Error "Failed to get Jira data: $($_.Exception.Message)"
        return $null
    }
}

function Initialize-DataWarehouse {
    Write-Host "Initializing data warehouse..." -ForegroundColor Cyan
    
    # Create directory structure
    $directories = @(
        "$DataWarehouseConfig.warehouse_path",
        "$DataWarehouseConfig.warehouse_path\raw",
        "$DataWarehouseConfig.warehouse_path\processed",
        "$DataWarehouseConfig.warehouse_path\aggregated",
        "$DataWarehouseConfig.warehouse_path\metadata",
        "$DataWarehouseConfig.warehouse_path\logs"
    )
    
    if ($DataWarehouseConfig.data_lake) {
        $directories += @(
            "$DataWarehouseConfig.lake_path",
            "$DataWarehouseConfig.lake_path\bronze",
            "$DataWarehouseConfig.lake_path\silver",
            "$DataWarehouseConfig.lake_path\gold"
        )
    }
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force
            Write-Host "Created directory: $dir" -ForegroundColor Green
        }
    }
    
    # Initialize metadata
    $metadata = @{
        "created" = Get-Date
        "version" = "1.0"
        "schemas" = $DataWarehouseConfig.data_schemas
        "config" = $DataWarehouseConfig
    }
    
    $metadataPath = "$DataWarehouseConfig.warehouse_path\metadata\warehouse-metadata.json"
    $metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataPath -Encoding UTF8
    
    Write-Host "Data warehouse initialized successfully" -ForegroundColor Green
}

function Start-ETLPipeline {
    Write-Host "Starting ETL pipeline..." -ForegroundColor Cyan
    
    $etlStartTime = Get-Date
    $etlRun = @{
        "start_time" = $etlStartTime
        "status" = "Running"
        "steps" = @()
        "records_processed" = 0
        "errors" = @()
    }
    
    try {
        # Extract data
        $extractResult = Invoke-ExtractData -ETLRun $etlRun
        $etlRun.steps += $extractResult
        
        # Transform data
        $transformResult = Invoke-TransformData -ETLRun $etlRun
        $etlRun.steps += $transformResult
        
        # Load data
        $loadResult = Invoke-LoadData -ETLRun $etlRun
        $etlRun.steps += $loadResult
        
        # Validate data
        if ($DataWarehouseConfig.data_validation) {
            $validationResult = Invoke-DataValidation -ETLRun $etlRun
            $etlRun.steps += $validationResult
        }
        
        $etlRun.status = "Completed"
        $etlRun.end_time = Get-Date
        $etlRun.duration = ($etlRun.end_time - $etlRun.start_time).TotalMinutes
        
        Write-Host "ETL pipeline completed successfully in $([math]::Round($etlRun.duration, 2)) minutes" -ForegroundColor Green
    }
    catch {
        $etlRun.status = "Failed"
        $etlRun.end_time = Get-Date
        $etlRun.errors += $_.Exception.Message
        Write-Error "ETL pipeline failed: $($_.Exception.Message)"
    }
    finally {
        $DataWarehouseState.last_etl_run = $etlRun
        $DataWarehouseState.etl_history += $etlRun
        
        # Keep only last 30 ETL runs
        if ($DataWarehouseState.etl_history.Count -gt 30) {
            $DataWarehouseState.etl_history = $DataWarehouseState.etl_history[-30..-1]
        }
        
        # Save ETL history
        $etlHistoryPath = "$DataWarehouseConfig.warehouse_path\logs\etl-history.json"
        $DataWarehouseState.etl_history | ConvertTo-Json -Depth 10 | Out-File -FilePath $etlHistoryPath -Encoding UTF8
    }
}

function Invoke-ExtractData {
    param([hashtable]$ETLRun)
    
    Write-Host "Extracting data from Jira..." -ForegroundColor Yellow
    
    $extractStep = @{
        "step" = "Extract"
        "start_time" = Get-Date
        "records_extracted" = 0
        "tables" = @()
    }
    
    try {
        # Extract issues
        $issuesData = Get-JiraData -JQL "ORDER BY updated DESC"
        if ($issuesData) {
            $issuesPath = "$DataWarehouseConfig.warehouse_path\raw\issues-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $issuesData | ConvertTo-Json -Depth 10 | Out-File -FilePath $issuesPath -Encoding UTF8
            $extractStep.records_extracted += $issuesData.issues.Count
            $extractStep.tables += "issues"
        }
        
        # Extract projects
        $projectsData = Get-JiraData -Endpoint "project"
        if ($projectsData) {
            $projectsPath = "$DataWarehouseConfig.warehouse_path\raw\projects-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $projectsData | ConvertTo-Json -Depth 10 | Out-File -FilePath $projectsPath -Encoding UTF8
            $extractStep.records_extracted += $projectsData.Count
            $extractStep.tables += "projects"
        }
        
        # Extract users
        $usersData = Get-JiraData -Endpoint "user/search" -Parameters @{ "maxResults" = 1000 }
        if ($usersData) {
            $usersPath = "$DataWarehouseConfig.warehouse_path\raw\users-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $usersData | ConvertTo-Json -Depth 10 | Out-File -FilePath $usersPath -Encoding UTF8
            $extractStep.records_extracted += $usersData.Count
            $extractStep.tables += "users"
        }
        
        # Extract workflows
        $workflowsData = Get-JiraData -Endpoint "workflow"
        if ($workflowsData) {
            $workflowsPath = "$DataWarehouseConfig.warehouse_path\raw\workflows-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $workflowsData | ConvertTo-Json -Depth 10 | Out-File -FilePath $workflowsPath -Encoding UTF8
            $extractStep.records_extracted += $workflowsData.Count
            $extractStep.tables += "workflows"
        }
        
        $extractStep.end_time = Get-Date
        $extractStep.duration = ($extractStep.end_time - $extractStep.start_time).TotalMinutes
        
        Write-Host "Extracted $($extractStep.records_extracted) records from $($extractStep.tables.Count) tables" -ForegroundColor Green
        
        return $extractStep
    }
    catch {
        $extractStep.status = "Failed"
        $extractStep.error = $_.Exception.Message
        Write-Error "Data extraction failed: $($_.Exception.Message)"
        return $extractStep
    }
}

function Invoke-TransformData {
    param([hashtable]$ETLRun)
    
    Write-Host "Transforming data..." -ForegroundColor Yellow
    
    $transformStep = @{
        "step" = "Transform"
        "start_time" = Get-Date
        "records_transformed" = 0
        "transformations" = @()
    }
    
    try {
        # Get latest raw data files
        $rawPath = "$DataWarehouseConfig.warehouse_path\raw"
        $latestFiles = Get-ChildItem $rawPath -Filter "*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 4
        
        foreach ($file in $latestFiles) {
            $data = Get-Content $file.FullName | ConvertFrom-Json
            $transformedData = $null
            
            switch ($file.BaseName) {
                { $_ -match "issues" } {
                    $transformedData = Transform-IssuesData -Data $data
                    $transformStep.transformations += "issues_normalization"
                }
                { $_ -match "projects" } {
                    $transformedData = Transform-ProjectsData -Data $data
                    $transformStep.transformations += "projects_normalization"
                }
                { $_ -match "users" } {
                    $transformedData = Transform-UsersData -Data $data
                    $transformStep.transformations += "users_normalization"
                }
                { $_ -match "workflows" } {
                    $transformedData = Transform-WorkflowsData -Data $data
                    $transformStep.transformations += "workflows_normalization"
                }
            }
            
            if ($transformedData) {
                $processedPath = "$DataWarehouseConfig.warehouse_path\processed\$($file.BaseName)-processed.json"
                $transformedData | ConvertTo-Json -Depth 10 | Out-File -FilePath $processedPath -Encoding UTF8
                $transformStep.records_transformed += $transformedData.Count
            }
        }
        
        $transformStep.end_time = Get-Date
        $transformStep.duration = ($transformStep.end_time - $transformStep.start_time).TotalMinutes
        
        Write-Host "Transformed $($transformStep.records_transformed) records with $($transformStep.transformations.Count) transformations" -ForegroundColor Green
        
        return $transformStep
    }
    catch {
        $transformStep.status = "Failed"
        $transformStep.error = $_.Exception.Message
        Write-Error "Data transformation failed: $($_.Exception.Message)"
        return $transformStep
    }
}

function Transform-IssuesData {
    param([object]$Data)
    
    $transformedIssues = @()
    
    foreach ($issue in $Data.issues) {
        $transformedIssue = @{
            "key" = $issue.key
            "id" = $issue.id
            "summary" = $issue.fields.summary
            "status" = $issue.fields.status.name
            "assignee" = if ($issue.fields.assignee) { $issue.fields.assignee.displayName } else { $null }
            "reporter" = if ($issue.fields.reporter) { $issue.fields.reporter.displayName } else { $null }
            "created" = [DateTime]::Parse($issue.fields.created)
            "updated" = [DateTime]::Parse($issue.fields.updated)
            "priority" = $issue.fields.priority.name
            "issuetype" = $issue.fields.issuetype.name
            "project" = $issue.fields.project.key
            "duedate" = if ($issue.fields.duedate) { [DateTime]::Parse($issue.fields.duedate) } else { $null }
            "resolutiondate" = if ($issue.fields.resolutiondate) { [DateTime]::Parse($issue.fields.resolutiondate) } else { $null }
            "resolution_time_days" = if ($issue.fields.resolutiondate) { 
                ([DateTime]::Parse($issue.fields.resolutiondate) - [DateTime]::Parse($issue.fields.created)).TotalDays 
            } else { $null }
            "etl_timestamp" = Get-Date
        }
        
        $transformedIssues += $transformedIssue
    }
    
    return $transformedIssues
}

function Transform-ProjectsData {
    param([object]$Data)
    
    $transformedProjects = @()
    
    foreach ($project in $Data) {
        $transformedProject = @{
            "key" = $project.key
            "name" = $project.name
            "description" = $project.description
            "lead" = if ($project.lead) { $project.lead.displayName } else { $null }
            "created" = if ($project.created) { [DateTime]::Parse($project.created) } else { $null }
            "updated" = if ($project.updated) { [DateTime]::Parse($project.updated) } else { $null }
            "projectType" = $project.projectTypeKey
            "etl_timestamp" = Get-Date
        }
        
        $transformedProjects += $transformedProject
    }
    
    return $transformedProjects
}

function Transform-UsersData {
    param([object]$Data)
    
    $transformedUsers = @()
    
    foreach ($user in $Data) {
        $transformedUser = @{
            "key" = $user.key
            "displayName" = $user.displayName
            "emailAddress" = $user.emailAddress
            "active" = $user.active
            "created" = if ($user.created) { [DateTime]::Parse($user.created) } else { $null }
            "updated" = if ($user.updated) { [DateTime]::Parse($user.updated) } else { $null }
            "etl_timestamp" = Get-Date
        }
        
        $transformedUsers += $transformedUser
    }
    
    return $transformedUsers
}

function Transform-WorkflowsData {
    param([object]$Data)
    
    $transformedWorkflows = @()
    
    foreach ($workflow in $Data) {
        $transformedWorkflow = @{
            "id" = $workflow.id
            "name" = $workflow.name
            "description" = $workflow.description
            "statuses" = $workflow.statuses.Count
            "transitions" = $workflow.transitions.Count
            "etl_timestamp" = Get-Date
        }
        
        $transformedWorkflows += $transformedWorkflow
    }
    
    return $transformedWorkflows
}

function Invoke-LoadData {
    param([hashtable]$ETLRun)
    
    Write-Host "Loading data to warehouse..." -ForegroundColor Yellow
    
    $loadStep = @{
        "step" = "Load"
        "start_time" = Get-Date
        "records_loaded" = 0
        "tables_loaded" = @()
    }
    
    try {
        # Get processed data files
        $processedPath = "$DataWarehouseConfig.warehouse_path\processed"
        $processedFiles = Get-ChildItem $processedPath -Filter "*-processed.json"
        
        foreach ($file in $processedFiles) {
            $data = Get-Content $file.FullName | ConvertFrom-Json
            
            # Load to aggregated tables
            $aggregatedPath = "$DataWarehouseConfig.warehouse_path\aggregated\$($file.BaseName).json"
            $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $aggregatedPath -Encoding UTF8
            
            # Load to data lake if enabled
            if ($DataWarehouseConfig.data_lake) {
                $lakePath = "$DataWarehouseConfig.lake_path\silver\$($file.BaseName).json"
                $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $lakePath -Encoding UTF8
            }
            
            $loadStep.records_loaded += $data.Count
            $loadStep.tables_loaded += $file.BaseName
        }
        
        $loadStep.end_time = Get-Date
        $loadStep.duration = ($loadStep.end_time - $loadStep.start_time).TotalMinutes
        
        Write-Host "Loaded $($loadStep.records_loaded) records to $($loadStep.tables_loaded.Count) tables" -ForegroundColor Green
        
        return $loadStep
    }
    catch {
        $loadStep.status = "Failed"
        $loadStep.error = $_.Exception.Message
        Write-Error "Data loading failed: $($_.Exception.Message)"
        return $loadStep
    }
}

function Invoke-DataValidation {
    param([hashtable]$ETLRun)
    
    Write-Host "Validating data quality..." -ForegroundColor Yellow
    
    $validationStep = @{
        "step" = "Validation"
        "start_time" = Get-Date
        "validation_results" = @{}
        "quality_score" = 0
    }
    
    try {
        $aggregatedPath = "$DataWarehouseConfig.warehouse_path\aggregated"
        $aggregatedFiles = Get-ChildItem $aggregatedPath -Filter "*.json"
        
        foreach ($file in $aggregatedFiles) {
            $data = Get-Content $file.FullName | ConvertFrom-Json
            $validationResult = Test-DataQuality -Data $data -TableName $file.BaseName
            $validationStep.validation_results[$file.BaseName] = $validationResult
        }
        
        # Calculate overall quality score
        $totalScore = 0
        $tableCount = 0
        foreach ($result in $validationStep.validation_results.Values) {
            $totalScore += $result.quality_score
            $tableCount++
        }
        
        $validationStep.quality_score = if ($tableCount -gt 0) { $totalScore / $tableCount } else { 0 }
        
        $validationStep.end_time = Get-Date
        $validationStep.duration = ($validationStep.end_time - $validationStep.start_time).TotalMinutes
        
        Write-Host "Data validation completed. Overall quality score: $([math]::Round($validationStep.quality_score, 2))%" -ForegroundColor Green
        
        return $validationStep
    }
    catch {
        $validationStep.status = "Failed"
        $validationStep.error = $_.Exception.Message
        Write-Error "Data validation failed: $($_.Exception.Message)"
        return $validationStep
    }
}

function Test-DataQuality {
    param(
        [object]$Data,
        [string]$TableName
    )
    
    $qualityResult = @{
        "table" = $TableName
        "total_records" = $Data.Count
        "completeness" = 0
        "accuracy" = 0
        "consistency" = 0
        "timeliness" = 0
        "quality_score" = 0
        "issues" = @()
    }
    
    if ($Data.Count -eq 0) {
        $qualityResult.issues += "No data found"
        return $qualityResult
    }
    
    # Test completeness
    $requiredFields = $DataWarehouseConfig.data_schemas[$TableName.Replace("-processed", "")]
    if ($requiredFields) {
        $completeRecords = 0
        foreach ($record in $Data) {
            $isComplete = $true
            foreach ($field in $requiredFields) {
                if (-not $record.$field -or $record.$field -eq "") {
                    $isComplete = $false
                    break
                }
            }
            if ($isComplete) { $completeRecords++ }
        }
        $qualityResult.completeness = ($completeRecords / $Data.Count) * 100
    }
    
    # Test accuracy (basic checks)
    $accurateRecords = 0
    foreach ($record in $Data) {
        $isAccurate = $true
        
        # Check date formats
        if ($record.created -and $record.created -isnot [DateTime]) {
            $isAccurate = $false
        }
        if ($record.updated -and $record.updated -isnot [DateTime]) {
            $isAccurate = $false
        }
        
        # Check required string fields
        if ($record.key -and $record.key.Length -lt 3) {
            $isAccurate = $false
        }
        
        if ($isAccurate) { $accurateRecords++ }
    }
    $qualityResult.accuracy = ($accurateRecords / $Data.Count) * 100
    
    # Test consistency
    $consistentRecords = 0
    foreach ($record in $Data) {
        $isConsistent = $true
        
        # Check date consistency
        if ($record.created -and $record.updated -and $record.created -gt $record.updated) {
            $isConsistent = $false
        }
        
        if ($isConsistent) { $consistentRecords++ }
    }
    $qualityResult.consistency = ($consistentRecords / $Data.Count) * 100
    
    # Test timeliness
    $timelyRecords = 0
    $cutoffTime = (Get-Date).AddHours(-$DataWarehouseConfig.data_quality_thresholds.timeliness)
    foreach ($record in $Data) {
        if ($record.etl_timestamp -and $record.etl_timestamp -gt $cutoffTime) {
            $timelyRecords++
        }
    }
    $qualityResult.timeliness = ($timelyRecords / $Data.Count) * 100
    
    # Calculate overall quality score
    $qualityResult.quality_score = ($qualityResult.completeness + $qualityResult.accuracy + $qualityResult.consistency + $qualityResult.timeliness) / 4
    
    # Identify issues
    if ($qualityResult.completeness -lt $DataWarehouseConfig.data_quality_thresholds.completeness) {
        $qualityResult.issues += "Low completeness: $([math]::Round($qualityResult.completeness, 2))%"
    }
    if ($qualityResult.accuracy -lt $DataWarehouseConfig.data_quality_thresholds.accuracy) {
        $qualityResult.issues += "Low accuracy: $([math]::Round($qualityResult.accuracy, 2))%"
    }
    if ($qualityResult.consistency -lt $DataWarehouseConfig.data_quality_thresholds.consistency) {
        $qualityResult.issues += "Low consistency: $([math]::Round($qualityResult.consistency, 2))%"
    }
    if ($qualityResult.timeliness -lt $DataWarehouseConfig.data_quality_thresholds.timeliness) {
        $qualityResult.issues += "Low timeliness: $([math]::Round($qualityResult.timeliness, 2))%"
    }
    
    return $qualityResult
}

function Get-DataWarehouseMetrics {
    Write-Host "Generating data warehouse metrics..." -ForegroundColor Cyan
    
    $metrics = @{
        "timestamp" = Get-Date
        "storage_metrics" = @{
            "raw_data_size" = 0
            "processed_data_size" = 0
            "aggregated_data_size" = 0
            "total_size" = 0
        }
        "etl_metrics" = @{
            "last_run" = $DataWarehouseState.last_etl_run
            "total_runs" = $DataWarehouseState.etl_history.Count
            "success_rate" = 0
            "avg_duration" = 0
        }
        "data_quality" = $DataWarehouseState.data_quality_metrics
        "retention_status" = @{}
    }
    
    # Calculate storage metrics
    $warehousePath = $DataWarehouseConfig.warehouse_path
    if (Test-Path $warehousePath) {
        $rawSize = (Get-ChildItem "$warehousePath\raw" -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $processedSize = (Get-ChildItem "$warehousePath\processed" -Recurse -File | Measure-Object -Property Length -Sum).Sum
        $aggregatedSize = (Get-ChildItem "$warehousePath\aggregated" -Recurse -File | Measure-Object -Property Length -Sum).Sum
        
        $metrics.storage_metrics.raw_data_size = $rawSize
        $metrics.storage_metrics.processed_data_size = $processedSize
        $metrics.storage_metrics.aggregated_data_size = $aggregatedSize
        $metrics.storage_metrics.total_size = $rawSize + $processedSize + $aggregatedSize
    }
    
    # Calculate ETL metrics
    if ($DataWarehouseState.etl_history.Count -gt 0) {
        $successfulRuns = ($DataWarehouseState.etl_history | Where-Object { $_.status -eq "Completed" }).Count
        $metrics.etl_metrics.success_rate = ($successfulRuns / $DataWarehouseState.etl_history.Count) * 100
        
        $avgDuration = ($DataWarehouseState.etl_history | Where-Object { $_.duration } | Measure-Object -Property duration -Average).Average
        $metrics.etl_metrics.avg_duration = if ($avgDuration) { $avgDuration } else { 0 }
    }
    
    # Check retention status
    $cutoffDate = (Get-Date).AddDays(-$DataWarehouseConfig.retention_days)
    $oldFiles = Get-ChildItem $warehousePath -Recurse -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    $metrics.retention_status.old_files_count = $oldFiles.Count
    $metrics.retention_status.old_files_size = ($oldFiles | Measure-Object -Property Length -Sum).Sum
    
    return $metrics
}

function Cleanup-OldData {
    Write-Host "Cleaning up old data..." -ForegroundColor Cyan
    
    $cutoffDate = (Get-Date).AddDays(-$DataWarehouseConfig.retention_days)
    $warehousePath = $DataWarehouseConfig.warehouse_path
    
    $oldFiles = Get-ChildItem $warehousePath -Recurse -File | Where-Object { $_.LastWriteTime -lt $cutoffDate }
    
    $cleanedFiles = 0
    $cleanedSize = 0
    
    foreach ($file in $oldFiles) {
        $cleanedSize += $file.Length
        Remove-Item $file.FullName -Force
        $cleanedFiles++
    }
    
    Write-Host "Cleaned up $cleanedFiles files ($([math]::Round($cleanedSize / 1MB, 2)) MB)" -ForegroundColor Green
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Enterprise Data Warehouse System" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Operation Type: $OperationType" -ForegroundColor Yellow
Write-Host "Data Warehouse: $EnableDataWarehouse" -ForegroundColor Yellow
Write-Host "ETL Pipeline: $EnableETLPipeline" -ForegroundColor Yellow
Write-Host "Data Quality: $EnableDataQuality" -ForegroundColor Yellow
Write-Host "Historical Storage: $EnableHistoricalStorage" -ForegroundColor Yellow
Write-Host "Data Lake: $EnableDataLake" -ForegroundColor Yellow
Write-Host "Retention Days: $RetentionDays" -ForegroundColor Yellow

try {
    switch ($OperationType.ToLower()) {
        "init" {
            Initialize-DataWarehouse
        }
        "etl" {
            Start-ETLPipeline
        }
        "validation" {
            $validationResult = Invoke-DataValidation -ETLRun @{}
            Write-Host "Validation completed with quality score: $([math]::Round($validationResult.quality_score, 2))%" -ForegroundColor Green
        }
        "metrics" {
            $metrics = Get-DataWarehouseMetrics
            $metricsPath = ".\data-warehouse-metrics-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsPath -Encoding UTF8
            Write-Host "Data warehouse metrics generated: $metricsPath" -ForegroundColor Green
        }
        "cleanup" {
            Cleanup-OldData
        }
        "all" {
            Write-Host "Initializing complete data warehouse system..." -ForegroundColor Green
            
            if ($EnableDataWarehouse) {
                Initialize-DataWarehouse
            }
            
            if ($EnableETLPipeline) {
                Start-ETLPipeline
            }
            
            if ($EnableDataQuality) {
                $validationResult = Invoke-DataValidation -ETLRun @{}
                Write-Host "Data quality validation completed" -ForegroundColor Green
            }
            
            $metrics = Get-DataWarehouseMetrics
            $metricsPath = ".\data-warehouse-metrics-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $metrics | ConvertTo-Json -Depth 10 | Out-File -FilePath $metricsPath -Encoding UTF8
            
            if ($EnableHistoricalStorage) {
                Cleanup-OldData
            }
        }
        default {
            Write-Warning "Unknown operation type: $OperationType. Use 'all', 'init', 'etl', 'validation', 'metrics', or 'cleanup'"
        }
    }
}
catch {
    Write-Error "Error during data warehouse operation: $($_.Exception.Message)"
}

Write-Host "Enterprise data warehouse system finished." -ForegroundColor Green
