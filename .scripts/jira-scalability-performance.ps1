# =============================================================================
# JIRA SCALABILITY & PERFORMANCE SYSTEM
# =============================================================================

# Enterprise-grade scalability and performance optimization system
# This system provides horizontal scaling, caching, and performance monitoring

param(
    [string]$OperationType = "all",
    [switch]$EnableCaching = $false,
    [switch]$EnableLoadBalancing = $false,
    [switch]$EnablePerformanceMonitoring = $false,
    [switch]$EnableAutoScaling = $false,
    [int]$CacheSize = 1000,
    [int]$MaxConcurrentRequests = 100,
    [string]$CacheStrategy = "LRU",
    [switch]$EnableDataPartitioning = $false,
    [switch]$EnableQueryOptimization = $false
)

# Configuration
$JiraBaseUrl = $env:JIRA_BASE_URL
$JiraUsername = $env:JIRA_USERNAME
$JiraApiToken = $env:JIRA_API_TOKEN

# Performance configuration
$PerformanceConfig = @{
    "caching" = $EnableCaching
    "load_balancing" = $EnableLoadBalancing
    "performance_monitoring" = $EnablePerformanceMonitoring
    "auto_scaling" = $EnableAutoScaling
    "cache_size" = $CacheSize
    "max_concurrent_requests" = $MaxConcurrentRequests
    "cache_strategy" = $CacheStrategy
    "data_partitioning" = $EnableDataPartitioning
    "query_optimization" = $EnableQueryOptimization
    "cache_ttl" = 300  # 5 minutes
    "performance_thresholds" = @{
        "response_time_ms" = 2000
        "throughput_rps" = 100
        "error_rate_percent" = 5
        "cpu_usage_percent" = 80
        "memory_usage_percent" = 85
    }
    "scaling_rules" = @{
        "scale_up_cpu" = 80
        "scale_up_memory" = 85
        "scale_up_response_time" = 3000
        "scale_down_cpu" = 30
        "scale_down_memory" = 40
        "scale_down_response_time" = 1000
    }
}

# Performance state
$PerformanceState = @{
    "cache" = @{}
    "performance_metrics" = @{}
    "request_queue" = @()
    "active_requests" = 0
    "scaling_history" = @()
    "optimization_suggestions" = @()
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

function Get-JiraData {
    param(
        [string]$Endpoint,
        [string]$JQL = "",
        [switch]$UseCache = $true
    )
    
    $startTime = Get-Date
    
    # Check cache first
    if ($PerformanceConfig.caching -and $UseCache) {
        $cacheKey = "$Endpoint-$JQL"
        $cachedData = Get-CachedData -Key $cacheKey
        if ($cachedData) {
            $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
            Log-PerformanceMetric -Operation "CACHE_HIT" -ResponseTime $responseTime -Details $cacheKey
            return $cachedData
        }
    }
    
    # Rate limiting
    if ($PerformanceState.active_requests -ge $PerformanceConfig.max_concurrent_requests) {
        Write-Warning "Rate limit reached. Queuing request..."
        $PerformanceState.request_queue += @{
            "endpoint" = $Endpoint
            "jql" = $JQL
            "timestamp" = Get-Date
        }
        return $null
    }
    
    $PerformanceState.active_requests++
    
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraUsername`:$JiraApiToken"))
            "Content-Type" = "application/json"
        }
        
        $url = if ($JQL) {
            "$JiraBaseUrl/search?jql=$([Uri]::EscapeDataString($JQL))&maxResults=999999"
        } else {
            "$JiraBaseUrl/$Endpoint"
        }
        
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method GET
        
        $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
        
        # Cache the response
        if ($PerformanceConfig.caching -and $UseCache) {
            Set-CachedData -Key $cacheKey -Data $response
        }
        
        # Log performance metrics
        Log-PerformanceMetric -Operation "API_CALL" -ResponseTime $responseTime -Details $url
        
        return $response
    }
    catch {
        $responseTime = ((Get-Date) - $startTime).TotalMilliseconds
        Log-PerformanceMetric -Operation "API_ERROR" -ResponseTime $responseTime -Details $_.Exception.Message
        Write-Error "Failed to get Jira data: $($_.Exception.Message)"
        return $null
    }
    finally {
        $PerformanceState.active_requests--
    }
}

function Get-CachedData {
    param([string]$Key)
    
    if (-not $PerformanceState.cache.ContainsKey($Key)) {
        return $null
    }
    
    $cachedItem = $PerformanceState.cache[$Key]
    $now = Get-Date
    
    # Check TTL
    if (($now - $cachedItem.timestamp).TotalSeconds -gt $PerformanceConfig.cache_ttl) {
        $PerformanceState.cache.Remove($Key)
        return $null
    }
    
    return $cachedItem.data
}

function Set-CachedData {
    param(
        [string]$Key,
        [object]$Data
    )
    
    # Implement cache eviction if needed
    if ($PerformanceState.cache.Count -ge $PerformanceConfig.cache_size) {
        switch ($PerformanceConfig.cache_strategy.ToUpper()) {
            "LRU" {
                # Remove least recently used item
                $oldestKey = $PerformanceState.cache.Keys | ForEach-Object {
                    [PSCustomObject]@{
                        Key = $_
                        Timestamp = $PerformanceState.cache[$_].timestamp
                    }
                } | Sort-Object Timestamp | Select-Object -First 1
                
                if ($oldestKey) {
                    $PerformanceState.cache.Remove($oldestKey.Key)
                }
            }
            "FIFO" {
                # Remove first in, first out
                $firstKey = $PerformanceState.cache.Keys | Select-Object -First 1
                if ($firstKey) {
                    $PerformanceState.cache.Remove($firstKey)
                }
            }
        }
    }
    
    $PerformanceState.cache[$Key] = @{
        "data" = $Data
        "timestamp" = Get-Date
        "access_count" = 0
    }
}

function Log-PerformanceMetric {
    param(
        [string]$Operation,
        [double]$ResponseTime,
        [string]$Details = "",
        [hashtable]$AdditionalMetrics = @{}
    )
    
    $metric = @{
        "timestamp" = Get-Date
        "operation" = $Operation
        "response_time_ms" = $ResponseTime
        "details" = $Details
        "active_requests" = $PerformanceState.active_requests
        "cache_size" = $PerformanceState.cache.Count
        "queue_size" = $PerformanceState.request_queue.Count
    }
    
    # Add additional metrics
    foreach ($key in $AdditionalMetrics.Keys) {
        $metric[$key] = $AdditionalMetrics[$key]
    }
    
    $PerformanceState.performance_metrics[([System.Guid]::NewGuid().ToString())] = $metric
    
    # Keep only last 1000 metrics
    if ($PerformanceState.performance_metrics.Count -gt 1000) {
        $oldestKeys = $PerformanceState.performance_metrics.Keys | Select-Object -First 100
        foreach ($key in $oldestKeys) {
            $PerformanceState.performance_metrics.Remove($key)
        }
    }
    
    # Check performance thresholds
    Check-PerformanceThresholds -Metric $metric
}

function Check-PerformanceThresholds {
    param([hashtable]$Metric)
    
    $thresholds = $PerformanceConfig.performance_thresholds
    
    # Check response time
    if ($Metric.response_time_ms -gt $thresholds.response_time_ms) {
        Write-Warning "Performance threshold exceeded: Response time $($Metric.response_time_ms)ms > $($thresholds.response_time_ms)ms"
        Add-OptimizationSuggestion -Type "ResponseTime" -Message "Response time exceeded threshold. Consider caching or query optimization."
    }
    
    # Check error rate
    if ($Metric.operation -eq "API_ERROR") {
        $errorRate = ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "API_ERROR" }).Count / $PerformanceState.performance_metrics.Count * 100
        if ($errorRate -gt $thresholds.error_rate_percent) {
            Write-Warning "Error rate threshold exceeded: $([math]::Round($errorRate, 2))% > $($thresholds.error_rate_percent)%"
            Add-OptimizationSuggestion -Type "ErrorRate" -Message "High error rate detected. Check API connectivity and rate limits."
        }
    }
}

function Add-OptimizationSuggestion {
    param(
        [string]$Type,
        [string]$Message,
        [string]$Priority = "Medium"
    )
    
    $suggestion = @{
        "timestamp" = Get-Date
        "type" = $Type
        "message" = $Message
        "priority" = $Priority
        "status" = "Open"
    }
    
    $PerformanceState.optimization_suggestions += $suggestion
    
    Write-Host "💡 Optimization suggestion: $Message" -ForegroundColor Yellow
}

# =============================================================================
# CACHING FUNCTIONS
# =============================================================================

function Initialize-Cache {
    Write-Host "Initializing cache system..." -ForegroundColor Cyan
    
    $PerformanceState.cache = @{}
    
    # Pre-populate cache with common queries
    $commonQueries = @(
        "ORDER BY updated DESC",
        "status = Done ORDER BY resolutiondate DESC",
        "assignee is not EMPTY ORDER BY updated DESC",
        "duedate is not EMPTY ORDER BY duedate ASC"
    )
    
    foreach ($query in $commonQueries) {
        Write-Host "Pre-populating cache with: $query" -ForegroundColor Yellow
        $data = Get-JiraData -JQL $query -UseCache $false
        if ($data) {
            Set-CachedData -Key "common-$query" -Data $data
        }
    }
    
    Write-Host "Cache system initialized with $($PerformanceState.cache.Count) entries" -ForegroundColor Green
}

function Optimize-Cache {
    Write-Host "Optimizing cache..." -ForegroundColor Cyan
    
    # Analyze cache usage
    $cacheStats = @{
        "total_entries" = $PerformanceState.cache.Count
        "hit_rate" = 0
        "miss_rate" = 0
        "avg_access_count" = 0
    }
    
    if ($PerformanceState.cache.Count -gt 0) {
        $totalAccessCount = ($PerformanceState.cache.Values | Measure-Object -Property access_count -Sum).Sum
        $cacheStats.avg_access_count = $totalAccessCount / $PerformanceState.cache.Count
        
        # Calculate hit/miss rates from performance metrics
        $cacheHits = ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "CACHE_HIT" }).Count
        $cacheMisses = ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "API_CALL" }).Count
        $totalCacheOperations = $cacheHits + $cacheMisses
        
        if ($totalCacheOperations -gt 0) {
            $cacheStats.hit_rate = ($cacheHits / $totalCacheOperations) * 100
            $cacheStats.miss_rate = ($cacheMisses / $totalCacheOperations) * 100
        }
    }
    
    Write-Host "Cache Statistics:" -ForegroundColor Green
    Write-Host "  Total entries: $($cacheStats.total_entries)" -ForegroundColor White
    Write-Host "  Hit rate: $([math]::Round($cacheStats.hit_rate, 2))%" -ForegroundColor White
    Write-Host "  Miss rate: $([math]::Round($cacheStats.miss_rate, 2))%" -ForegroundColor White
    Write-Host "  Avg access count: $([math]::Round($cacheStats.avg_access_count, 2))" -ForegroundColor White
    
    # Optimize cache strategy
    if ($cacheStats.hit_rate -lt 50) {
        Add-OptimizationSuggestion -Type "CacheHitRate" -Message "Low cache hit rate ($([math]::Round($cacheStats.hit_rate, 2))%). Consider increasing cache size or TTL." -Priority "High"
    }
    
    if ($cacheStats.avg_access_count -lt 2) {
        Add-OptimizationSuggestion -Type "CacheUsage" -Message "Low cache usage. Consider removing unused cache entries." -Priority "Medium"
    }
}

# =============================================================================
# LOAD BALANCING FUNCTIONS
# =============================================================================

function Initialize-LoadBalancer {
    Write-Host "Initializing load balancer..." -ForegroundColor Cyan
    
    # Simulate multiple Jira instances
    $jiraInstances = @(
        @{ "url" = $JiraBaseUrl; "weight" = 1; "status" = "Active" },
        @{ "url" = $JiraBaseUrl.Replace("onemain", "onemain-backup"); "weight" = 1; "status" = "Standby" },
        @{ "url" = $JiraBaseUrl.Replace("onemain", "onemain-mirror"); "weight" = 1; "status" = "Standby" }
    )
    
    $PerformanceState.jira_instances = $jiraInstances
    
    Write-Host "Load balancer initialized with $($jiraInstances.Count) instances" -ForegroundColor Green
}

function Get-BestInstance {
    $instances = $PerformanceState.jira_instances | Where-Object { $_.status -eq "Active" }
    
    if ($instances.Count -eq 0) {
        Write-Warning "No active Jira instances available"
        return $null
    }
    
    # Simple round-robin selection
    $totalWeight = ($instances | Measure-Object -Property weight -Sum).Sum
    $random = Get-Random -Minimum 1 -Maximum ($totalWeight + 1)
    
    $currentWeight = 0
    foreach ($instance in $instances) {
        $currentWeight += $instance.weight
        if ($random -le $currentWeight) {
            return $instance
        }
    }
    
    return $instances[0]
}

# =============================================================================
# AUTO-SCALING FUNCTIONS
# =============================================================================

function Check-AutoScaling {
    if (-not $PerformanceConfig.auto_scaling) {
        return
    }
    
    Write-Host "Checking auto-scaling conditions..." -ForegroundColor Cyan
    
    # Get current performance metrics
    $recentMetrics = $PerformanceState.performance_metrics.Values | Where-Object { 
        (Get-Date) - $_.timestamp -lt [TimeSpan]::FromMinutes(5) 
    }
    
    if ($recentMetrics.Count -eq 0) {
        return
    }
    
    $avgResponseTime = ($recentMetrics | Measure-Object -Property response_time_ms -Average).Average
    $maxActiveRequests = ($recentMetrics | Measure-Object -Property active_requests -Maximum).Maximum
    $errorCount = ($recentMetrics | Where-Object { $_.operation -eq "API_ERROR" }).Count
    $errorRate = ($errorCount / $recentMetrics.Count) * 100
    
    $scalingRules = $PerformanceConfig.scaling_rules
    
    # Check scale-up conditions
    if ($avgResponseTime -gt $scalingRules.scale_up_response_time -or 
        $maxActiveRequests -gt $PerformanceConfig.max_concurrent_requests * 0.8 -or
        $errorRate -gt 10) {
        
        Scale-Up
    }
    
    # Check scale-down conditions
    if ($avgResponseTime -lt $scalingRules.scale_down_response_time -and 
        $maxActiveRequests -lt $PerformanceConfig.max_concurrent_requests * 0.3 -and
        $errorRate -lt 2) {
        
        Scale-Down
    }
}

function Scale-Up {
    Write-Host "Scaling up resources..." -ForegroundColor Yellow
    
    # Increase max concurrent requests
    $PerformanceConfig.max_concurrent_requests = [math]::Min($PerformanceConfig.max_concurrent_requests * 1.5, 500)
    
    # Increase cache size
    $PerformanceConfig.cache_size = [math]::Min($PerformanceConfig.cache_size * 1.2, 5000)
    
    # Activate standby instances
    $standbyInstances = $PerformanceState.jira_instances | Where-Object { $_.status -eq "Standby" }
    if ($standbyInstances.Count -gt 0) {
        $standbyInstances[0].status = "Active"
        Write-Host "Activated standby instance: $($standbyInstances[0].url)" -ForegroundColor Green
    }
    
    $scalingRecord = @{
        "timestamp" = Get-Date
        "action" = "ScaleUp"
        "max_concurrent_requests" = $PerformanceConfig.max_concurrent_requests
        "cache_size" = $PerformanceConfig.cache_size
        "active_instances" = ($PerformanceState.jira_instances | Where-Object { $_.status -eq "Active" }).Count
    }
    
    $PerformanceState.scaling_history += $scalingRecord
    
    Write-Host "Scaled up: Max requests = $($PerformanceConfig.max_concurrent_requests), Cache size = $($PerformanceConfig.cache_size)" -ForegroundColor Green
}

function Scale-Down {
    Write-Host "Scaling down resources..." -ForegroundColor Yellow
    
    # Decrease max concurrent requests
    $PerformanceConfig.max_concurrent_requests = [math]::Max($PerformanceConfig.max_concurrent_requests * 0.8, 10)
    
    # Decrease cache size
    $PerformanceConfig.cache_size = [math]::Max($PerformanceConfig.cache_size * 0.8, 100)
    
    # Deactivate excess instances
    $activeInstances = $PerformanceState.jira_instances | Where-Object { $_.status -eq "Active" }
    if ($activeInstances.Count -gt 1) {
        $activeInstances[-1].status = "Standby"
        Write-Host "Deactivated instance: $($activeInstances[-1].url)" -ForegroundColor Green
    }
    
    $scalingRecord = @{
        "timestamp" = Get-Date
        "action" = "ScaleDown"
        "max_concurrent_requests" = $PerformanceConfig.max_concurrent_requests
        "cache_size" = $PerformanceConfig.cache_size
        "active_instances" = ($PerformanceState.jira_instances | Where-Object { $_.status -eq "Active" }).Count
    }
    
    $PerformanceState.scaling_history += $scalingRecord
    
    Write-Host "Scaled down: Max requests = $($PerformanceConfig.max_concurrent_requests), Cache size = $($PerformanceConfig.cache_size)" -ForegroundColor Green
}

# =============================================================================
# QUERY OPTIMIZATION FUNCTIONS
# =============================================================================

function Optimize-Queries {
    Write-Host "Optimizing queries..." -ForegroundColor Cyan
    
    $optimizationSuggestions = @()
    
    # Analyze query patterns
    $queryPatterns = @{}
    foreach ($metric in $PerformanceState.performance_metrics.Values) {
        if ($metric.details -match "jql=") {
            $jql = [Uri]::UnescapeDataString($metric.details -replace ".*jql=", "")
            if (-not $queryPatterns.ContainsKey($jql)) {
                $queryPatterns[$jql] = @{
                    "count" = 0
                    "avg_response_time" = 0
                    "total_response_time" = 0
                }
            }
            $queryPatterns[$jql].count++
            $queryPatterns[$jql].total_response_time += $metric.response_time_ms
            $queryPatterns[$jql].avg_response_time = $queryPatterns[$jql].total_response_time / $queryPatterns[$jql].count
        }
    }
    
    # Find slow queries
    foreach ($query in $queryPatterns.Keys) {
        $pattern = $queryPatterns[$query]
        if ($pattern.avg_response_time -gt 1000 -and $pattern.count -gt 5) {
            $optimizationSuggestions += "Slow query detected: $query (avg: $([math]::Round($pattern.avg_response_time, 2))ms, count: $($pattern.count))"
        }
    }
    
    # Suggest optimizations
    foreach ($suggestion in $optimizationSuggestions) {
        Add-OptimizationSuggestion -Type "QueryOptimization" -Message $suggestion -Priority "High"
    }
    
    Write-Host "Query optimization analysis completed. Found $($optimizationSuggestions.Count) optimization opportunities." -ForegroundColor Green
}

# =============================================================================
# PERFORMANCE MONITORING FUNCTIONS
# =============================================================================

function Generate-PerformanceReport {
    Write-Host "Generating performance report..." -ForegroundColor Cyan
    
    $report = @{
        "timestamp" = Get-Date
        "cache_stats" = @{
            "size" = $PerformanceState.cache.Count
            "max_size" = $PerformanceConfig.cache_size
            "utilization" = ($PerformanceState.cache.Count / $PerformanceConfig.cache_size) * 100
        }
        "request_stats" = @{
            "max_concurrent" = $PerformanceConfig.max_concurrent_requests
            "current_active" = $PerformanceState.active_requests
            "queue_size" = $PerformanceState.request_queue.Count
        }
        "performance_metrics" = @{
            "total_requests" = $PerformanceState.performance_metrics.Count
            "avg_response_time" = 0
            "error_rate" = 0
            "cache_hit_rate" = 0
        }
        "scaling_history" = $PerformanceState.scaling_history
        "optimization_suggestions" = $PerformanceState.optimization_suggestions
    }
    
    # Calculate performance metrics
    if ($PerformanceState.performance_metrics.Count -gt 0) {
        $report.performance_metrics.avg_response_time = ($PerformanceState.performance_metrics.Values | Measure-Object -Property response_time_ms -Average).Average
        $errorCount = ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "API_ERROR" }).Count
        $report.performance_metrics.error_rate = ($errorCount / $PerformanceState.performance_metrics.Count) * 100
        
        $cacheHits = ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "CACHE_HIT" }).Count
        $totalCacheOperations = $cacheHits + ($PerformanceState.performance_metrics.Values | Where-Object { $_.operation -eq "API_CALL" }).Count
        if ($totalCacheOperations -gt 0) {
            $report.performance_metrics.cache_hit_rate = ($cacheHits / $totalCacheOperations) * 100
        }
    }
    
    # Write report to file
    $reportPath = ".\performance-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
    
    Write-Host "Performance report generated: $reportPath" -ForegroundColor Green
    return $report
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "Jira Scalability & Performance System" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host "Operation Type: $OperationType" -ForegroundColor Yellow
Write-Host "Caching: $EnableCaching" -ForegroundColor Yellow
Write-Host "Load Balancing: $EnableLoadBalancing" -ForegroundColor Yellow
Write-Host "Performance Monitoring: $EnablePerformanceMonitoring" -ForegroundColor Yellow
Write-Host "Auto Scaling: $EnableAutoScaling" -ForegroundColor Yellow
Write-Host "Cache Size: $CacheSize" -ForegroundColor Yellow
Write-Host "Max Concurrent Requests: $MaxConcurrentRequests" -ForegroundColor Yellow

try {
    switch ($OperationType.ToLower()) {
        "cache" {
            Initialize-Cache
            Optimize-Cache
        }
        "loadbalancer" {
            Initialize-LoadBalancer
        }
        "autoscaling" {
            Check-AutoScaling
        }
        "optimization" {
            Optimize-Queries
        }
        "monitoring" {
            Generate-PerformanceReport
        }
        "all" {
            Write-Host "Initializing all performance systems..." -ForegroundColor Green
            
            if ($EnableCaching) {
                Initialize-Cache
                Optimize-Cache
            }
            
            if ($EnableLoadBalancing) {
                Initialize-LoadBalancer
            }
            
            if ($EnableQueryOptimization) {
                Optimize-Queries
            }
            
            if ($EnablePerformanceMonitoring) {
                Generate-PerformanceReport
            }
            
            if ($EnableAutoScaling) {
                Check-AutoScaling
            }
        }
        default {
            Write-Warning "Unknown operation type: $OperationType. Use 'all', 'cache', 'loadbalancer', 'autoscaling', 'optimization', or 'monitoring'"
        }
    }
}
catch {
    Write-Error "Error during performance system operation: $($_.Exception.Message)"
}

Write-Host "Scalability & performance system finished." -ForegroundColor Green
