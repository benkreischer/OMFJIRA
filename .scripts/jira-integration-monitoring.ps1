# =============================================================================
# JIRA INTEGRATION MONITORING & ROI ANALYSIS
# =============================================================================
# Comprehensive monitoring of all Jira integrations, usage patterns, and ROI analysis

param(
    [string]$BaseUrl = $env:JIRA_BASE_URL,
    [string]$Username = $env:JIRA_USERNAME,
    [string]$ApiToken = $env:JIRA_API_TOKEN,
    [string]$OutputPath = ".\integration-monitoring-report.json"
)

# =============================================================================
# CONFIGURATION
# =============================================================================
$IntegrationInventory = @{
    "DrawIO" = @{ Category = "Diagramming"; MonthlyCost = 50; Users = 25; Priority = "Medium" }
    "Jenkins" = @{ Category = "CI/CD"; MonthlyCost = 100; Users = 15; Priority = "High" }
    "Confluence" = @{ Category = "Documentation"; MonthlyCost = 75; Users = 100; Priority = "High" }
    "Slack" = @{ Category = "Communication"; MonthlyCost = 25; Users = 200; Priority = "High" }
    "GitHub" = @{ Category = "Version Control"; MonthlyCost = 60; Users = 30; Priority = "High" }
    "Tempo" = @{ Category = "Time Tracking"; MonthlyCost = 40; Users = 50; Priority = "Medium" }
    "Zephyr" = @{ Category = "Test Management"; MonthlyCost = 80; Users = 20; Priority = "Medium" }
    "Xray" = @{ Category = "Test Management"; MonthlyCost = 90; Users = 25; Priority = "Medium" }
    "Microsoft Teams" = @{ Category = "Communication"; MonthlyCost = 30; Users = 150; Priority = "High" }
    "Azure DevOps" = @{ Category = "DevOps"; MonthlyCost = 70; Users = 35; Priority = "High" }
}

# =============================================================================
# FUNCTIONS
# =============================================================================
function Get-JiraData {
    param(
        [string]$Endpoint,
        [hashtable]$Headers
    )
    
    try {
        $response = Invoke-RestMethod -Uri "$BaseUrl$Endpoint" -Headers $Headers -Method Get
        return $response
    }
    catch {
        Write-Warning "Failed to get data from $Endpoint : $($_.Exception.Message)"
        return $null
    }
}

function Analyze-IntegrationUsage {
    param(
        [array]$AuditRecords,
        [hashtable]$Inventory
    )
    
    $usageAnalysis = @{}
    
    foreach ($integration in $Inventory.Keys) {
        $usageCount = 0
        $uniqueUsers = @()
        $lastUsed = $null
        
        foreach ($record in $AuditRecords) {
            if ($record.summary -like "*$integration*") {
                $usageCount++
                if ($record.authorKey -and $uniqueUsers -notcontains $record.authorKey) {
                    $uniqueUsers += $record.authorKey
                }
                if ($record.created -and (!$lastUsed -or $record.created -gt $lastUsed)) {
                    $lastUsed = $record.created
                }
            }
        }
        
        $usageAnalysis[$integration] = @{
            UsageCount = $usageCount
            UniqueUsers = $uniqueUsers.Count
            LastUsed = $lastUsed
            CostPerUser = $Inventory[$integration].MonthlyCost / [Math]::Max($uniqueUsers.Count, 1)
            ROI = if ($usageCount -gt 0) { ($usageCount * 10) / $Inventory[$integration].MonthlyCost } else { 0 }
        }
    }
    
    return $usageAnalysis
}

function Generate-Recommendations {
    param(
        [hashtable]$UsageAnalysis,
        [hashtable]$Inventory
    )
    
    $recommendations = @()
    
    foreach ($integration in $UsageAnalysis.Keys) {
        $usage = $UsageAnalysis[$integration]
        $inventory = $Inventory[$integration]
        
        $recommendation = @{
            Integration = $integration
            Category = $inventory.Category
            MonthlyCost = $inventory.MonthlyCost
            UsageCount = $usage.UsageCount
            UniqueUsers = $usage.UniqueUsers
            CostPerUser = [Math]::Round($usage.CostPerUser, 2)
            ROI = [Math]::Round($usage.ROI, 2)
            LastUsed = $usage.LastUsed
        }
        
        # Generate recommendation based on usage patterns
        if ($usage.UsageCount -eq 0) {
            $recommendation.Recommendation = "Remove - No usage detected"
            $recommendation.Priority = "High"
            $recommendation.Savings = $inventory.MonthlyCost * 12
        }
        elseif ($usage.UsageCount -lt 5) {
            $recommendation.Recommendation = "Monitor closely - Low usage"
            $recommendation.Priority = "Medium"
            $recommendation.Savings = $inventory.MonthlyCost * 6
        }
        elseif ($usage.CostPerUser -gt 10) {
            $recommendation.Recommendation = "Review pricing - High cost per user"
            $recommendation.Priority = "Medium"
            $recommendation.Savings = $inventory.MonthlyCost * 3
        }
        elseif ($usage.ROI -gt 5) {
            $recommendation.Recommendation = "High value - Consider expanding"
            $recommendation.Priority = "Low"
            $recommendation.Savings = 0
        }
        else {
            $recommendation.Recommendation = "Continue monitoring"
            $recommendation.Priority = "Low"
            $recommendation.Savings = 0
        }
        
        $recommendations += $recommendation
    }
    
    return $recommendations
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================
Write-Host "🚀 Jira Integration Monitoring & ROI Analysis" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green

# Set up authentication
$headers = @{
    'Authorization' = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken")))"
    'Content-Type' = 'application/json'
}

Write-Host "📊 Collecting integration usage data..." -ForegroundColor Yellow

# Get audit records for usage analysis
$auditRecords = Get-JiraData -Endpoint "/rest/api/3/audit/records?from=2024-01-01&to=2024-12-31&limit=999999" -Headers $headers

if ($auditRecords -and $auditRecords.records) {
    Write-Host "✅ Retrieved $($auditRecords.records.Count) audit records" -ForegroundColor Green
    
    # Analyze integration usage
    $usageAnalysis = Analyze-IntegrationUsage -AuditRecords $auditRecords.records -Inventory $IntegrationInventory
    
    # Generate recommendations
    $recommendations = Generate-Recommendations -UsageAnalysis $usageAnalysis -Inventory $IntegrationInventory
    
    # Calculate totals
    $totalMonthlyCost = ($IntegrationInventory.Values | Measure-Object -Property MonthlyCost -Sum).Sum
    $totalAnnualCost = $totalMonthlyCost * 12
    $totalSavings = ($recommendations | Measure-Object -Property Savings -Sum).Sum
    
    # Create comprehensive report
    $report = @{
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Summary = @{
            TotalIntegrations = $IntegrationInventory.Count
            TotalMonthlyCost = $totalMonthlyCost
            TotalAnnualCost = $totalAnnualCost
            PotentialSavings = $totalSavings
            SavingsPercentage = [Math]::Round(($totalSavings / $totalAnnualCost) * 100, 2)
        }
        Integrations = $recommendations
        Categories = @{
            HighPriority = ($recommendations | Where-Object { $_.Priority -eq "High" }).Count
            MediumPriority = ($recommendations | Where-Object { $_.Priority -eq "Medium" }).Count
            LowPriority = ($recommendations | Where-Object { $_.Priority -eq "Low" }).Count
        }
    }
    
    # Save report
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "📈 INTEGRATION ANALYSIS SUMMARY" -ForegroundColor Cyan
    Write-Host "Total Integrations: $($report.Summary.TotalIntegrations)" -ForegroundColor White
    Write-Host "Total Monthly Cost: $($report.Summary.TotalMonthlyCost)" -ForegroundColor White
    Write-Host "Total Annual Cost: $($report.Summary.TotalAnnualCost)" -ForegroundColor White
    Write-Host "Potential Savings: $($report.Summary.PotentialSavings)" -ForegroundColor Green
    Write-Host "Savings Percentage: $($report.Summary.SavingsPercentage)%" -ForegroundColor Green
    
    Write-Host "`n🎯 TOP RECOMMENDATIONS" -ForegroundColor Cyan
    $topRecommendations = $recommendations | Sort-Object Savings -Descending | Select-Object -First 5
    foreach ($rec in $topRecommendations) {
        Write-Host "• $($rec.Integration): $($rec.Recommendation) (Savings: $($rec.Savings))" -ForegroundColor Yellow
    }
    
    Write-Host "`n📁 Report saved to: $OutputPath" -ForegroundColor Green
}
else {
    Write-Error "❌ Failed to retrieve audit records. Check your credentials and permissions."
}

Write-Host "`n🎉 Integration monitoring complete!" -ForegroundColor Green
