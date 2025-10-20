# Extract Failed Issues from Step 8 Receipt
# Creates a CSV with all relevant details for failed issue creation attempts

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectCode,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\projects\$ProjectCode\Deliverables"
)

# Ensure output directory exists
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$ReceiptFile = ".\projects\$ProjectCode\out\08_Import_receipt.json"
$OutputFile = "$OutputPath\$ProjectCode - Failed Issues.csv"

Write-Host "Extracting failed issues for project: $ProjectCode" -ForegroundColor Green
Write-Host "Receipt file: $ReceiptFile" -ForegroundColor Yellow
Write-Host "Output file: $OutputFile" -ForegroundColor Yellow

# Check if receipt file exists
if (!(Test-Path $ReceiptFile)) {
    Write-Error "Receipt file not found: $ReceiptFile"
    exit 1
}

try {
    # Read and parse the JSON file
    Write-Host "Reading receipt file..." -ForegroundColor Cyan
    $ReceiptData = Get-Content $ReceiptFile -Raw | ConvertFrom-Json
    
    # Extract failed issue details
    $FailedIssues = @()
    
    if ($ReceiptData.FailedIssueDetails) {
        Write-Host "Found $($ReceiptData.FailedIssueDetails.Count) failed issues" -ForegroundColor Cyan
        
        foreach ($FailedIssue in $ReceiptData.FailedIssueDetails) {
            $IssueDetails = [PSCustomObject]@{
                SourceKey = $FailedIssue.SourceKey
                IssueType = $FailedIssue.IssueType
                Summary = $FailedIssue.Summary
                Error = $FailedIssue.Error
                ErrorDetails = if ($FailedIssue.ErrorDetails) { $FailedIssue.ErrorDetails } else { "" }
                Priority = if ($FailedIssue.Priority) { $FailedIssue.Priority } else { "" }
                Status = if ($FailedIssue.Status) { $FailedIssue.Status } else { "" }
                Assignee = if ($FailedIssue.Assignee) { $FailedIssue.Assignee } else { "" }
                Reporter = if ($FailedIssue.Reporter) { $FailedIssue.Reporter } else { "" }
                Components = if ($FailedIssue.Components) { ($FailedIssue.Components -join "; ") } else { "" }
                Labels = if ($FailedIssue.Labels) { ($FailedIssue.Labels -join "; ") } else { "" }
                Created = if ($FailedIssue.Created) { $FailedIssue.Created } else { "" }
                Updated = if ($FailedIssue.Updated) { $FailedIssue.Updated } else { "" }
                Description = if ($FailedIssue.Description) { $FailedIssue.Description.Substring(0, [Math]::Min(500, $FailedIssue.Description.Length)) } else { "" }
                SourceURL = "https://onemain.atlassian.net/browse/$($FailedIssue.SourceKey)"
            }
            $FailedIssues += $IssueDetails
        }
    } else {
        Write-Host "No failed issue details found in receipt file" -ForegroundColor Yellow
    }
    
    # Export to CSV
    if ($FailedIssues.Count -gt 0) {
        $FailedIssues | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
        Write-Host "✅ Successfully created CSV with $($FailedIssues.Count) failed issues" -ForegroundColor Green
        Write-Host "📁 Output file: $OutputFile" -ForegroundColor Green
        
        # Display summary
        Write-Host "`n📊 Summary:" -ForegroundColor Cyan
        Write-Host "Total Failed Issues: $($FailedIssues.Count)" -ForegroundColor White
        
        # Group by error type
        $ErrorGroups = $FailedIssues | Group-Object Error
        Write-Host "`nError Types:" -ForegroundColor Cyan
        foreach ($Group in $ErrorGroups) {
            Write-Host "  - $($Group.Name): $($Group.Count) issues" -ForegroundColor White
        }
        
        # Group by issue type
        $TypeGroups = $FailedIssues | Group-Object IssueType
        Write-Host "`nIssue Types:" -ForegroundColor Cyan
        foreach ($Group in $TypeGroups) {
            Write-Host "  - $($Group.Name): $($Group.Count) issues" -ForegroundColor White
        }
        
    } else {
        Write-Host "No failed issues to export" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Error processing receipt file: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n✅ Extraction complete!" -ForegroundColor Green
