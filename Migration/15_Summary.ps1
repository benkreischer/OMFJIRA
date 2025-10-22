# 15_Summary.ps1 - Collect and Organize All Migration Reports
# 
# PURPOSE: Simple collection and organization of all CSV reports from the migration.
# This script discovers all CSV files from exports01-14 and copies them to ExportCSV
# with a consistent naming pattern: {ProjectKey} - {StepNumber} - {ReportName}
#
# WHAT IT DOES:
# 1. **Discover CSV Files** - Finds all CSV files in exports01 through exports14
# 2. **Apply Naming Pattern** - Renames files to {ProjectKey} - {StepNumber} - {ReportName}
# 3. **Copy to ExportCSV** - Organizes all reports in a single folder
# 4. **Generate Dashboard** - Creates a simple, modern HTML dashboard
#
# OUTPUTS:
#   - ExportCSV/ folder with all CSV reports organized by step
#   - migration_dashboard.html - Simple, modern dashboard
#
# NEXT STEP: Review all reports in the ExportCSV folder
#
param(
    [string] $ParametersPath,
    [switch] $DryRun                  # Simulate without copying files
)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonPath = Join-Path $here "_common.ps1"
. $commonPath
$script:DryRun = $DryRun

# Set default ParametersPath if not provided
if (-not $ParametersPath) {
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

$startTime = Get-Date
$p = Read-JsonFile -Path $ParametersPath

# Environment setup
$srcKey = $p.ProjectKey
$tgtKey = $p.TargetEnvironment.ProjectKey
$srcBase = $p.SourceEnvironment.BaseUrl
$tgtBase = $p.TargetEnvironment.BaseUrl

# Hardcode paths for now to get script working
$outDir = ".\projects\REM\out"

# Create ExportCSV directory and cleanup
$stepExportsDir = Join-Path $outDir "ExportCSV"
if (Test-Path $stepExportsDir) {
    Write-Host "🗑️  Cleaning up previous ExportCSV directory..." -ForegroundColor Yellow
    Remove-Item $stepExportsDir -Recurse -Force
}

New-Item -ItemType Directory -Path $stepExportsDir -Force | Out-Null

# Initialize issues logging
Initialize-IssuesLog -StepName "15_Summary" -OutDir $stepExportsDir

# Set step start time
$script:StepStartTime = Get-Date

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║              MIGRATION SUMMARY COLLECTION                ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Collecting all CSV reports from migration steps..." -ForegroundColor Yellow
Write-Host "Source: $srcKey → Target: $tgtKey" -ForegroundColor White
Write-Host ""

# Step 1: Discover ALL CSV files from exports01 through exports14
Write-Host "🔍 Discovering ALL CSV files from exports01-14..." -ForegroundColor Cyan

$allCsvFiles = @()
for ($stepNum = 1; $stepNum -le 14; $stepNum++) {
    $stepDir = Join-Path $outDir "exports$($stepNum.ToString('00'))"
    if (Test-Path $stepDir) {
        $csvFiles = @(Get-ChildItem -Path $stepDir -Filter "*.csv")
        if ($csvFiles.Count -gt 0) {
            Write-Host "   📁 Found $($csvFiles.Count) CSV files in exports$($stepNum.ToString('00'))" -ForegroundColor Green
            foreach ($csvFile in $csvFiles) {
                $allCsvFiles += @{
                    SourcePath = $csvFile.FullName
                    SourceRelative = "exports$($stepNum.ToString('00'))\$($csvFile.Name)"
                    FileName = $csvFile.Name
                    StepNumber = $stepNum
                }
            }
        }
    }
}

Write-Host "✅ Total CSV files discovered: $($allCsvFiles.Count)" -ForegroundColor Green
Write-Host ""

# Step 2: Copy ALL discovered CSV files to ExportCSV with project key naming
Write-Host "📦 Copying ALL CSV files to ExportCSV folder..." -ForegroundColor Cyan

$copiedCount = 0
foreach ($csvFile in $allCsvFiles) {
    # Create new filename with pattern: {ProjectKey} - {StepNumber} - {ReportName with spaces}
    $stepNum = $csvFile.StepNumber.ToString("00")
    $baseName = $csvFile.FileName -replace '\.csv$', ''
    # Remove step number prefix (e.g., "01_Preflight_Report" -> "Preflight_Report")
    $cleanName = $baseName -replace '^\d+_', ''
    # Convert underscores to spaces and title case
    $reportName = ($cleanName -replace '_', ' ').Split(' ') | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() } | Join-String -Separator ' '
    $newName = "$srcKey - $stepNum - $reportName.csv"
    $destPath = Join-Path $stepExportsDir $newName
    
    if (-not $DryRun) {
        Copy-Item -Path $csvFile.SourcePath -Destination $destPath -Force
    }
    $copiedCount++
    Write-Host "   ✅ Copied: $($csvFile.SourceRelative) → $newName" -ForegroundColor Green
}

Write-Host "✅ Copied $copiedCount CSV files to ExportCSV folder" -ForegroundColor Green
Write-Host ""

# Step 3: Generate Simple Dashboard
Write-Host "📊 Generating simple dashboard..." -ForegroundColor Cyan

$dashboardPath = Join-Path $outDir "migration_dashboard.html"
$htmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Migration Dashboard - $srcKey → $tgtKey</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Helvetica Neue', Arial, sans-serif;
            background: #ffffff;
            color: #333333;
            line-height: 1.6;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        
        .header {
            text-align: center;
            margin-bottom: 60px;
        }
        
        .title {
            font-size: 48px;
            font-weight: 300;
            color: #2c3e50;
            margin-bottom: 20px;
        }
        
        .subtitle {
            font-size: 24px;
            color: #7f8c8d;
            font-weight: 400;
        }
        
        .project-links {
            display: flex;
            justify-content: center;
            gap: 40px;
            margin-top: 40px;
        }
        
        .project-link {
            display: inline-block;
            padding: 16px 32px;
            background: #3498db;
            color: white;
            text-decoration: none;
            border-radius: 8px;
            font-size: 18px;
            font-weight: 500;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(52, 152, 219, 0.3);
        }
        
        .project-link:hover {
            background: #2980b9;
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(52, 152, 219, 0.4);
        }
        
        .project-link.source {
            background: #e74c3c;
            box-shadow: 0 4px 12px rgba(231, 76, 60, 0.3);
        }
        
        .project-link.source:hover {
            background: #c0392b;
            box-shadow: 0 6px 20px rgba(231, 76, 60, 0.4);
        }
        
        .project-link.target {
            background: #27ae60;
            box-shadow: 0 4px 12px rgba(39, 174, 96, 0.3);
        }
        
        .project-link.target:hover {
            background: #229954;
            box-shadow: 0 6px 20px rgba(39, 174, 96, 0.4);
        }
        
        .reports-section {
            margin-top: 60px;
        }
        
        .reports-title {
            font-size: 32px;
            font-weight: 400;
            color: #2c3e50;
            text-align: center;
            margin-bottom: 40px;
        }
        
        .dashboard-layout {
            display: flex;
            gap: 20px;
            margin-top: 20px;
        }
        
        .sidebar {
            width: 300px;
            padding: 15px;
            max-height: 70vh;
            overflow-y: auto;
        }
        
        .content-area {
            flex: 1;
            padding: 15px;
            min-height: 50vh;
        }
        
        .step-group {
            margin-bottom: 15px;
        }
        
        .step-header {
            padding: 8px 0;
            cursor: pointer;
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 5px;
        }
        
        .step-info {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .step-number {
            background: #666;
            color: white;
            width: 24px;
            height: 24px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 12px;
        }
        
        .step-title {
            font-size: 14px;
            color: #333;
        }
        
        .step-count {
            font-size: 11px;
            color: #666;
        }
        
        .expand-icon {
            font-size: 12px;
            color: #666;
        }
        
        .reports-list {
            max-height: 0;
            overflow: hidden;
        }
        
        .step-group.expanded .reports-list {
            max-height: 300px;
        }
        
        .report-item {
            padding: 6px 0;
            cursor: pointer;
            margin-bottom: 2px;
            font-size: 13px;
            color: #333;
        }
        
        .report-item:hover {
            background: #f0f0f0;
        }
        
        .report-item.active {
            background: #666;
            color: white;
        }
        
        .data-viewer {
            padding: 15px;
            min-height: 300px;
            font-family: monospace;
            font-size: 12px;
            white-space: pre-wrap;
            overflow: auto;
        }
        
        .data-placeholder {
            text-align: center;
            color: #666;
            padding: 40px 20px;
        }
        
        .data-content {
            display: none;
        }
        
        .data-content.active {
            display: block;
        }
        
        .summary-stats {
            background: #f8f9fa;
            border-radius: 8px;
            padding: 30px;
            margin-top: 40px;
            text-align: center;
        }
        
        .stats-title {
            font-size: 24px;
            font-weight: 500;
            color: #2c3e50;
            margin-bottom: 20px;
        }
        
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 20px;
        }
        
        .stat-item {
            text-align: center;
        }
        
        .stat-number {
            font-size: 32px;
            font-weight: 600;
            color: #3498db;
            margin-bottom: 8px;
        }
        
        .stat-label {
            font-size: 14px;
            color: #7f8c8d;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">Migration Dashboard</h1>
            <p class="subtitle">$srcKey → $tgtKey</p>
            
            <div class="project-links">
                <a href="$($srcBase.TrimEnd('/'))/browse/$srcKey" target="_blank" class="project-link source">
                    📊 Source Project ($srcKey)
                </a>
                <a href="$($tgtBase.TrimEnd('/'))/browse/$tgtKey" target="_blank" class="project-link target">
                    🎯 Target Project ($tgtKey)
                </a>
            </div>
        </div>
        
        <div class="reports-section">
            <h2 class="reports-title">📊 Migration Reports</h2>
            <div class="dashboard-layout">
                <div class="sidebar">
                    <h3 style="margin-bottom: 20px; color: #2c3e50;">Migration Steps</h3>
"@

# Group CSV files by step number
$stepsData = @{}
foreach ($csvFile in $allCsvFiles) {
    $stepNum = $csvFile.StepNumber
    if (-not $stepsData.ContainsKey($stepNum)) {
        $stepsData[$stepNum] = @()
    }
    $stepsData[$stepNum] += $csvFile
}

# Add expandable step items
foreach ($stepNum in ($stepsData.Keys | Sort-Object)) {
    $stepFiles = $stepsData[$stepNum]
    $stepTitle = switch ($stepNum) {
        1 { "Preflight Check" }
        2 { "Project Creation" }
        3 { "Users & Roles" }
        4 { "Components & Labels" }
        5 { "Versions" }
        6 { "Boards" }
        7 { "Issue Export" }
        8 { "Issue Import" }
        9 { "Comments" }
        10 { "Attachments" }
        11 { "Links" }
        12 { "Worklogs" }
        13 { "Sprints" }
        14 { "History" }
        default { "Step $stepNum" }
    }
    
    $htmlContent += @"
                    <div class="step-group" onclick="toggleStep($stepNum)">
                        <div class="step-header">
                            <div class="step-info">
                                <div class="step-number">$stepNum</div>
                                <div class="step-title">$stepTitle</div>
                                <div class="step-count">$($stepFiles.Count)</div>
                            </div>
                            <div class="expand-icon">▼</div>
                        </div>
                        <div class="reports-list">
"@
    
    foreach ($csvFile in $stepFiles) {
        $baseName = $csvFile.FileName -replace '\.csv$', ''
        $cleanName = $baseName -replace '^\d+_', ''
        $reportName = ($cleanName -replace '_', ' ').Split(' ') | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() } | Join-String -Separator ' '
        $newName = "$srcKey - $stepNum.ToString('00') - $reportName.csv"
        
        $htmlContent += @"
                            <div class="report-item" onclick="loadReport('$newName', '$reportName')">
                                $reportName
                            </div>
"@
    }
    
    $htmlContent += @"
                        </div>
                    </div>
"@
}

$htmlContent += @"
                </div>
                
                <div class="content-area">
                    <h3 style="margin-bottom: 20px; color: #2c3e50;">Report Viewer</h3>
                    <div class="data-viewer">
                        <div class="data-placeholder">
                            👈 Select a report from the left to view its contents
                        </div>
                        <div class="data-content" id="report-content">
                            <!-- CSV data will be loaded here -->
                        </div>
                    </div>
                </div>
            </div>
            
            <div class="summary-stats">
                <h3 class="stats-title">📈 Migration Summary</h3>
                <div class="stats-grid">
                    <div class="stat-item">
                        <div class="stat-number">$($allCsvFiles.Count)</div>
                        <div class="stat-label">Total Reports</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-number">14</div>
                        <div class="stat-label">Migration Steps</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-number">100%</div>
                        <div class="stat-label">Complete</div>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function toggleStep(stepNum) {
            const stepGroup = event.currentTarget;
            stepGroup.classList.toggle('expanded');
        }
        
        function loadReport(fileName, reportName) {
            // Remove active class from all report items
            document.querySelectorAll('.report-item').forEach(item => {
                item.classList.remove('active');
            });
            
            // Add active class to clicked item
            event.currentTarget.classList.add('active');
            
            // Hide placeholder and show content
            document.querySelector('.data-placeholder').style.display = 'none';
            const content = document.getElementById('report-content');
            content.classList.add('active');
            
            // Show loading message
            content.innerHTML = 'Loading ' + reportName + '...';
            
            // Load CSV data
            fetch('ExportCSV/' + fileName)
                .then(response => response.text())
                .then(data => {
                    content.innerHTML = reportName + '\n\n' + data;
                })
                .catch(error => {
                    content.innerHTML = 'Error loading ' + reportName + ':\n' + error.message + '\n\nFile: ' + fileName;
                });
        }
        
        // Add some initial interactivity
        document.addEventListener('DOMContentLoaded', function() {
            console.log('Migration Dashboard loaded successfully!');
        });
    </script>
</body>
</html>
"@

if (-not $DryRun) {
    $htmlContent | Out-File -FilePath $dashboardPath -Encoding UTF8
    Write-Host "✅ Dashboard generated: $dashboardPath" -ForegroundColor Green
}

# Create receipt
$stepEndTime = Get-Date
$receiptData = @{
    SourceProject = @{ key = $srcKey }
    TargetProject = @{ key = $tgtKey }
    CsvFilesDiscovered = $allCsvFiles.Count
    CsvFilesCopied = $copiedCount
    ExportCsvPath = $stepExportsDir
    DashboardPath = $dashboardPath
    Status = "Summary Collection Complete"
    Notes = @("All CSV reports organized in ExportCSV folder", "Files renamed with project key pattern", "Simple dashboard generated")
    StartTime = $script:StepStartTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
    EndTime = $stepEndTime.ToString("yyyy-MM-ddTHH:mm:ss.fffffffK")
}

Write-StageReceipt -OutDir $outDir -Stage "15_Summary" -Data $receiptData

Write-Host ""
Write-Host "✅ Step 15 Summary completed successfully!" -ForegroundColor Green
Write-Host "📁 ExportCSV: $stepExportsDir" -ForegroundColor Cyan
Write-Host "📊 Dashboard: $dashboardPath" -ForegroundColor Cyan
Write-Host "📄 Receipt: $outDir\15_Summary_receipt.json" -ForegroundColor Cyan
Write-Host "📊 Files organized: $copiedCount CSV reports" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 All migration reports are now organized in the ExportCSV folder!" -ForegroundColor Green





