# 16_PushToConfluence.ps1 - Push Migration Documentation to Confluence
# 
# PURPOSE: Pushes the migration documentation, receipts, and reports to Confluence
# in the JIRA space under a Sandbox > ProjectKey folder structure.
#
# WHAT IT DOES:
# - Creates organized Confluence pages with migration documentation
# - Uploads migration receipts and reports as attachments
# - Organizes content in a hierarchical structure (Sandbox > ProjectKey)
# - Provides easy access to all migration artifacts
# - Creates summary pages with links to detailed reports
#
# WHAT IT DOES NOT DO:
# - Does not perform any data migration
# - Does not modify existing Confluence content
# - Does not create new Jira projects or issues
#
# NEXT STEP: Migration documentation is now available in Confluence!
#
#Requires -Version 7.0

param(
    [Parameter(Mandatory = $false)]
    [string]$ParametersPath,
    
    [Parameter(Mandatory = $false)]
    [string]$ProjectKey,
    
    [Parameter(Mandatory = $false)]
    [string]$OutDir,
    [switch]$DryRun
)

# Set default parameters (same pattern as other migration scripts)
if (-not $ParametersPath) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ParametersPath = Join-Path (Split-Path -Parent (Split-Path -Parent $here)) "config\migration-parameters.json"
}

# Load parameters to get project info
try {
    . "$PSScriptRoot\..\_common.ps1"
    $tempParams = Read-JsonFile -Path $ParametersPath
    if (-not $ProjectKey) {
        $ProjectKey = $tempParams.ProjectKey
    }
    if (-not $OutDir) {
        $OutDir = $tempParams.OutputSettings.OutputDirectory
    }
} catch {
    Write-Host "❌ Failed to load parameters for defaults: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Honor DryRun globally
$script:DryRun = $DryRun

# Set up logging
$logFile = Join-Path $OutDir "logs\16_PushToConfluence.log"
$logDir = Split-Path $logFile -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
}

function Test-ConfluenceConnection {
    param([string]$BaseUrl, [string]$Email, [string]$ApiToken)
    
    try {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Email`:$ApiToken"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        if ($script:DryRun) { Write-Log "[DRYRUN] GET $BaseUrl/rest/api/space"; return $true }
        # Test connection by getting space info (Confluence API)
        $response = Invoke-RestMethod -Uri "$BaseUrl/rest/api/space" -Headers $headers -Method Get
        Write-Log "✅ Connected to Confluence at: $BaseUrl" -Level "INFO"
        return $true
    }
    catch {
        Write-Log "❌ Failed to connect to Confluence: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-ConfluenceSpace {
    param([string]$BaseUrl, [string]$Email, [string]$ApiToken, [string]$SpaceKey)
    
    try {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Email`:$ApiToken"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        if ($script:DryRun) { Write-Log "[DRYRUN] GET $BaseUrl/rest/api/space/$SpaceKey"; return @{ name = "[DRYRUN] Space"; key = $SpaceKey } }
        $response = Invoke-RestMethod -Uri "$BaseUrl/rest/api/space/$SpaceKey" -Headers $headers -Method Get
        Write-Log "✅ Found Confluence space: $($response.name) (Key: $($response.key))" -Level "INFO"
        return $response
    }
    catch {
        Write-Log "❌ Failed to get Confluence space '$SpaceKey': $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Create-ConfluencePage {
    param(
        [string]$BaseUrl,
        [string]$Email,
        [string]$ApiToken,
        [string]$SpaceKey,
        [string]$Title,
        [string]$Content,
        [string]$ParentId = $null
    )
    
    try {
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Email`:$ApiToken"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        # Check if page already exists
        $existingPage = $null
        try {
            $searchUrl = "$BaseUrl/rest/api/content?spaceKey=$SpaceKey&title=$([System.Web.HttpUtility]::UrlEncode($Title))"
        if ($script:DryRun) { Write-Log "[DRYRUN] GET $searchUrl"; $existingPages = @{ results = @() } } else { $existingPages = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get }
            if ($existingPages.results.Count -gt 0) {
                $existingPage = $existingPages.results[0]
                Write-Log "⚠️ Page '$Title' already exists (ID: $($existingPage.id))" -Level "WARNING"
                return $existingPage
            }
        } catch {
            # Ignore search errors, proceed with creation
        }
        
    $body = @{
        "type" = "page"
        "title" = $Title
        "space" = @{ "key" = $SpaceKey }
        "body" = @{
            "wiki" = @{
                "value" = $Content
                "representation" = "wiki"
            }
        }
    }
        
        if ($ParentId) {
            $body["ancestors"] = @(@{ "id" = $ParentId })
        }
        
        $jsonBody = $body | ConvertTo-Json -Depth 10
        if ($script:DryRun) { Write-Log "[DRYRUN] POST $BaseUrl/rest/api/content (create page '$Title')"; return @{ id = 0; title = $Title } }
        $response = Invoke-RestMethod -Uri "$BaseUrl/rest/api/content" -Headers $headers -Method Post -Body $jsonBody
        Write-Log "✅ Created Confluence page: '$Title' (ID: $($response.id))" -Level "INFO"
        return $response
    }
    catch {
        Write-Log "❌ Failed to create Confluence page '$Title': $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Response: $($_.Exception.Response)" -Level "ERROR"
        return $null
    }
}

function Upload-ConfluenceAttachment {
    param(
        [string]$BaseUrl,
        [string]$Email,
        [string]$ApiToken,
        [string]$PageId,
        [string]$FilePath,
        [string]$Comment = "Uploaded via Jira Migration Toolkit"
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            Write-Log "⚠️ File not found: $FilePath" -Level "WARNING"
            return $null
        }
        
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Email`:$ApiToken"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "X-Atlassian-Token" = "nocheck"
        }
        
        $fileName = Split-Path $FilePath -Leaf
        
        # Check if attachment already exists
        try {
            $existingAttachmentsUrl = "$BaseUrl/rest/api/content/$PageId/child/attachment?filename=$([System.Web.HttpUtility]::UrlEncode($fileName))"
            if ($script:DryRun) { Write-Log "[DRYRUN] GET $existingAttachmentsUrl"; $existingAttachments = @{ results = @() } } else { $existingAttachments = Invoke-RestMethod -Uri $existingAttachmentsUrl -Headers $headers -Method Get }
            
            if ($existingAttachments.results -and $existingAttachments.results.Count -gt 0) {
                $attachmentId = $existingAttachments.results[0].id
                Write-Log "⚠️ Attachment '$fileName' already exists (ID: $attachmentId), updating..." -Level "WARNING"
                
                # Update existing attachment (post to page's attachment endpoint with attachment ID)
                $form = @{
                    file = Get-Item -Path $FilePath
                    comment = $Comment
                }
                
                $updateUrl = "$BaseUrl/rest/api/content/$PageId/child/attachment/$attachmentId/data"
                if ($script:DryRun) { Write-Log "[DRYRUN] POST $updateUrl (update attachment '$fileName')"; return @{ id = $attachmentId } }
                $response = Invoke-RestMethod -Uri $updateUrl `
                    -Headers $headers `
                    -Method Post `
                    -Form $form
                
                Write-Log "✅ Updated attachment: '$fileName' (ID: $attachmentId)" -Level "INFO"
                return $response
            }
        } catch {
            # If check fails, proceed with normal upload
            Write-Log "Debug: Could not check for existing attachment, proceeding with upload" -Level "INFO"
        }
        
        # Upload new attachment
        $form = @{
            file = Get-Item -Path $FilePath
            comment = $Comment
        }
        
        Write-Log "Debug: Uploading '$fileName' to page ID: $PageId" -Level "INFO"
        Write-Log "Debug: File size: $((Get-Item $FilePath).Length) bytes" -Level "INFO"
        
        if ($script:DryRun) { Write-Log "[DRYRUN] POST $BaseUrl/rest/api/content/$PageId/child/attachment (upload '$fileName')"; return @{ id = 0 } }
        $response = Invoke-RestMethod -Uri "$BaseUrl/rest/api/content/$PageId/child/attachment" `
            -Headers $headers `
            -Method Post `
            -Form $form
        
        Write-Log "✅ Uploaded attachment: '$fileName' to page ID: $PageId" -Level "INFO"
        return $response
    }
    catch {
        Write-Log "❌ Failed to upload attachment '$FilePath': $($_.Exception.Message)" -Level "ERROR"
        if ($_.ErrorDetails.Message) {
            Write-Log "Error Details: $($_.ErrorDetails.Message)" -Level "ERROR"
        }
        return $null
    }
}

function Reorder-ConfluencePages {
    param(
        [string]$BaseUrl,
        [string]$Email,
        [string]$ApiToken,
        [string]$SpaceKey,
        [string]$ParentPageId
    )
    
    try {
        Write-Log "🔄 Reordering all pages under parent page ID: $ParentPageId" -Level "INFO"
        
        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Email`:$ApiToken"))
        $headers = @{
            "Authorization" = "Basic $auth"
            "Content-Type" = "application/json"
            "Accept" = "application/json"
        }
        
        # Get all child pages under the parent
        $childrenUrl = "$BaseUrl/rest/api/content/$ParentPageId/child/page?expand=version,title&limit=100"
        $childrenResponse = Invoke-RestMethod -Uri $childrenUrl -Headers $headers -Method Get
        
        if (-not $childrenResponse.results -or $childrenResponse.results.Count -le 1) {
            Write-Log "ℹ️ No pages to reorder (found $($childrenResponse.results.Count) pages)" -Level "INFO"
            return $true
        }
        
        # Sort pages alphabetically by title
        $sortedPages = $childrenResponse.results | Sort-Object { $_.title }
        
        Write-Log "📋 Reordering $($sortedPages.Count) pages alphabetically: $($sortedPages | ForEach-Object { $_.title } | Join-String -Separator ', ')" -Level "INFO"
        
        # Update each page with its new position
        for ($i = 0; $i -lt $sortedPages.Count; $i++) {
            $page = $sortedPages[$i]
            $newPosition = $i
            
            try {
                # Get current page version
                $getPageUrl = "$BaseUrl/rest/api/content/$($page.id)?expand=version"
                $currentPage = Invoke-RestMethod -Uri $getPageUrl -Headers $headers -Method Get
                
                # Update page with new position
                $updateBody = @{
                    "id" = $page.id
                    "type" = "page"
                    "title" = $page.title
                    "version" = @{ "number" = ($currentPage.version.number + 1) }
                    "space" = @{ "key" = $SpaceKey }
                    "ancestors" = @(@{ "id" = $ParentPageId })
                    "extensions" = @{
                        "position" = $newPosition
                    }
                } | ConvertTo-Json -Depth 10
                
                $updateUrl = "$BaseUrl/rest/api/content/$($page.id)"
                Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Put -Body $updateBody
                
                Write-Log "✅ Positioned '$($page.title)' at position $newPosition" -Level "INFO"
                
                # Small delay to avoid rate limiting
                Start-Sleep -Milliseconds 100
                
            } catch {
                Write-Log "⚠️ Failed to reorder page '$($page.title)': $($_.Exception.Message)" -Level "WARNING"
            }
        }
        
        Write-Log "✅ Completed reordering all pages under parent" -Level "INFO"
        return $true
        
    } catch {
        Write-Log "❌ Failed to reorder pages: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Convert-MarkdownToConfluenceWiki {
    param([string]$MarkdownContent)
    
    # Convert markdown to Confluence Wiki Markup (much simpler!)
    $wikiContent = $MarkdownContent
    
    # Convert headers
    $wikiContent = $wikiContent -replace '^# (.+)$', 'h1. $1'
    $wikiContent = $wikiContent -replace '^## (.+)$', 'h2. $1'
    $wikiContent = $wikiContent -replace '^### (.+)$', 'h3. $1'
    $wikiContent = $wikiContent -replace '^#### (.+)$', 'h4. $1'
    
    # Convert bold text
    $wikiContent = $wikiContent -replace '\*\*(.+?)\*\*', '*$1*'
    
    # Convert italic text
    $wikiContent = $wikiContent -replace '\*(.+?)\*', '_$1_'
    
    # Convert horizontal rules
    $wikiContent = $wikiContent -replace '^---$', '----'
    
    # Convert bullet points
    $wikiContent = $wikiContent -replace '^- (.+)$', '* $1'
    
    # Remove the redundant "Issues" table (duplicate of bulleted summary)
    $wikiContent = $wikiContent -replace '(?s)### Issues.*?(?=\n###|\n##|$)', ''  # Remove the entire Issues table section
    
    # Remove all the garbage sections the user doesn't want
    $wikiContent = $wikiContent -replace '(?s)🎯 Migration Phases Completed.*?(?=\n📞|\nReport|\n<h2>|$)', ''  # Remove migration phases section
    $wikiContent = $wikiContent -replace '(?s)✅ Validation Checklist.*?(?=\n📞|\nReport|\n<h2>|$)', ''  # Remove validation checklist section
    $wikiContent = $wikiContent -replace '(?s)📞 Support.*?(?=\nReport|\n<h2>|$)', ''  # Remove support section
    $wikiContent = $wikiContent -replace '(?s)Report Generated:.*?Generated By:.*?(?=\n<h2>|$)', ''  # Remove report footer
    $wikiContent = $wikiContent -replace '^—\s*$', ''  # Remove standalone horizontal rules
    $wikiContent = $wikiContent -replace '\n\n\n+', "`n`n"  # Clean up multiple newlines
    
    # Convert all remaining tables to friendly bulleted format
    $lines = $wikiContent -split "`n"
    $result = @()
    $inTable = $false
    $tableRows = @()
    $tableTitle = ""
    
    foreach ($line in $lines) {
        if ($line -match '^\|(.+)\|$') {
            # Table row detected (single pipes, not double)
            if (-not $inTable) {
                $inTable = $true
                $tableRows = @()
                # Get the previous line as table title if it's a header
                if ($result.Count -gt 0 -and $result[-1] -match '^#{1,4}\s+(.+)$') {
                    $tableTitle = $matches[1]
                }
            }
            $cells = $line -split '\|' | Where-Object { $_.Trim() -ne '' }
            $tableRows += $cells
        } else {
            if ($inTable) {
                # Convert table to bulleted format
                if ($tableRows.Count -gt 1) {
                    $result += ""
                    if ($tableTitle) {
                        $result += "### $tableTitle"
                        $result += ""
                    }
                    
                    # Skip header row, process data rows
                    for ($i = 1; $i -lt $tableRows.Count; $i++) {
                        $row = $tableRows[$i]
                        if ($row.Count -ge 2) {
                            $metric = $row[0].Trim()
                            $value = $row[1].Trim()
                            
                            # Choose appropriate icon based on metric type
                            $icon = "•"
                            if ($metric -match "Added|Created|Success|Verified") { $icon = "✅" }
                            elseif ($metric -match "Failed|Error") { $icon = "❌" }
                            elseif ($metric -match "Skipped|Existing") { $icon = "⏭️" }
                            elseif ($metric -match "Warning|Orphaned") { $icon = "⚠️" }
                            elseif ($metric -match "Total|Net") { $icon = "📊" }
                            elseif ($metric -match "Fields|Components|Versions") { $icon = "🔧" }
                            elseif ($metric -match "Users") { $icon = "👥" }
                            elseif ($metric -match "Converted|Mapped") { $icon = "🔄" }
                            elseif ($metric -match "Removed") { $icon = "🗑️" }
                            
                            $result += "- $icon **$metric**: $value"
                        }
                    }
                    $result += ""
                }
                $inTable = $false
                $tableRows = @()
                $tableTitle = ""
            }
            $result += $line
        }
    }
    
    # Handle table at end of content
    if ($inTable -and $tableRows.Count -gt 1) {
        if ($tableTitle) {
            $result += ""
            $result += "### $tableTitle"
            $result += ""
        }
        
        for ($i = 1; $i -lt $tableRows.Count; $i++) {
            $row = $tableRows[$i]
            if ($row.Count -ge 2) {
                $metric = $row[0].Trim()
                $value = $row[1].Trim()
                
                $icon = "•"
                if ($metric -match "Added|Created|Success|Verified") { $icon = "✅" }
                elseif ($metric -match "Failed|Error") { $icon = "❌" }
                elseif ($metric -match "Skipped|Existing") { $icon = "⏭️" }
                elseif ($metric -match "Warning|Orphaned") { $icon = "⚠️" }
                elseif ($metric -match "Total|Net") { $icon = "📊" }
                elseif ($metric -match "Fields|Components|Versions") { $icon = "🔧" }
                elseif ($metric -match "Users") { $icon = "👥" }
                elseif ($metric -match "Converted|Mapped") { $icon = "🔄" }
                elseif ($metric -match "Removed") { $icon = "🗑️" }
                
                $result += "- $icon **$metric**: $value"
            }
        }
    }
    
    $wikiContent = $result -join "`n"
    
    # Remove excessive whitespace - much more aggressive
    $wikiContent = $wikiContent -replace '\n\n+', "`n"  # Max 1 newline between any content
    $wikiContent = $wikiContent -replace '^\s*\n', ''        # Remove blank lines at start
    $wikiContent = $wikiContent -replace '\n\s*$', ''        # Remove blank lines at end
    $wikiContent = $wikiContent.Trim()                       # Remove leading/trailing whitespace
    
    return $wikiContent
}

# Main execution
Write-Log "🚀 Starting Step 16: Push to Confluence" -Level "INFO"
Write-Log "Project: $ProjectKey" -Level "INFO"
Write-Log "Parameters: $ParametersPath" -Level "INFO"
Write-Log "Output Directory: $OutDir" -Level "INFO"

# Load parameters and credentials (same pattern as other migration scripts)
try {
    $params = Read-JsonFile -Path $ParametersPath
    
    # Use SOURCE project key for the Confluence folder name (not target)
    $sourceProjectKey = $params.ProjectKey
    $sourceProjectName = if ($params.ProjectName) { $params.ProjectName } else { $sourceProjectKey }
    
    $targetEnv = $params.TargetEnvironment
    $targetProjectKey = $targetEnv.ProjectKey
    $targetProjectName = $targetEnv.ProjectName
    
    # Get Confluence settings from ConfluenceEnvironment (loaded from .env)
    $confluenceEnv = $params.ConfluenceEnvironment
    $baseUrl = $confluenceEnv.BaseUrl.TrimEnd('/')
    $spaceKey = $confluenceEnv.SpaceKey
    $email = $confluenceEnv.Username
    $apiToken = $confluenceEnv.ApiToken
    
    Write-Log "Confluence URL: $baseUrl" -Level "INFO"
    Write-Log "Confluence Space: $spaceKey" -Level "INFO"
    Write-Log "Confluence User: $email" -Level "INFO"
    Write-Log "Source Project: $sourceProjectKey ($sourceProjectName)" -Level "INFO"
    Write-Log "Target Project: $targetProjectKey ($targetProjectName)" -Level "INFO"
    
} catch {
    Write-Log "❌ Failed to load parameters: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Validate Confluence credentials
if (-not $email -or -not $apiToken -or -not $baseUrl -or -not $spaceKey) {
    Write-Log "❌ Confluence credentials not found in .env file" -Level "ERROR"
    Write-Log "Please ensure these are set in .env:" -Level "ERROR"
    Write-Log "- CONFLUENCE_BASE_URL" -Level "ERROR"
    Write-Log "- CONFLUENCE_SPACE_KEY" -Level "ERROR"
    Write-Log "- CONFLUENCE_USERNAME" -Level "ERROR"
    Write-Log "- CONFLUENCE_API_TOKEN" -Level "ERROR"
    exit 1
}

# Test connection
if (-not (Test-ConfluenceConnection -BaseUrl $baseUrl -Email $email -ApiToken $apiToken)) {
    exit 1
}

# Get Confluence space
$space = Get-ConfluenceSpace -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey
if (-not $space) {
    exit 1
}

Write-Log "📁 Creating $sourceProjectKey folder structure in Confluence space: $($space.name)" -Level "INFO"

# Initialize page variables
$receiptsPage = $null
$dashboardPage = $null

# Find the "Sandbox" parent folder
Write-Log "🔍 Looking for 'Sandbox' folder..." -Level "INFO"
$sandboxFolder = $null
try {
    # Search for pages with "Sandbox" in the title using CQL
    $cql = [System.Web.HttpUtility]::UrlEncode("space = $spaceKey AND title = 'Sandbox'")
    $searchUrl = "$baseUrl/rest/api/content/search?cql=$cql&expand=version,ancestors"
    
    Write-Log "Debug: Searching for Sandbox with URL: $searchUrl" -Level "INFO"
    
    if ($script:DryRun) { Write-Log "[DRYRUN] GET $searchUrl"; $searchResponse = @{ results = @() } } else { $searchResponse = Invoke-RestMethod -Uri $searchUrl -Headers @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
        "Accept" = "application/json"
    } -Method Get }
    
    Write-Log "Debug: Search response size: $($searchResponse.size)" -Level "INFO"
    
    if ($searchResponse.results -and $searchResponse.results.Count -gt 0) {
        $sandboxFolder = $searchResponse.results[0]
        Write-Log "✅ Found 'Sandbox' folder (ID: $($sandboxFolder.id))" -Level "INFO"
    } else {
        Write-Log "⚠️ 'Sandbox' folder not found, creating it..." -Level "WARNING"
        
        # Create the Sandbox folder as a page
        $sandboxContent = @"
<h1>Sandbox</h1>

<p>This folder contains documentation for sandbox migration projects.</p>

<h2>📁 Migration Projects</h2>
<ul>
<li>Migration projects (dynamically populated)</li>
</ul>

<h2>📋 Project Documentation</h2>
<p>Each migration project includes:</p>
<ul>
<li>Migration receipts and summary</li>
<li>Quick start guide</li>
<li>QA checklist</li>
<li>Interactive dashboard</li>
</ul>
"@
        
        $sandboxFolder = Create-ConfluencePage -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -Title "Sandbox" -Content $sandboxContent
        if ($sandboxFolder) {
            Write-Log "✅ Created 'Sandbox' folder (ID: $($sandboxFolder.id))" -Level "INFO"
        } else {
            Write-Log "❌ Failed to create 'Sandbox' folder" -Level "ERROR"
            exit 1
        }
    }
} catch {
    Write-Log "❌ Failed to search for 'Sandbox' folder: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# We'll create the project folder content after we create all the pages
# so we can include real links to the actual pages

# Check if project folder exists and is under Sandbox
Write-Log "🔍 Looking for existing $sourceProjectKey folder..." -Level "INFO"
$existingProjectFolder = $null
try {
    # Search for project page using CQL
    $projectCql = [System.Web.HttpUtility]::UrlEncode("space = $spaceKey AND title = '$sourceProjectKey'")
    $projectSearchUrl = "$baseUrl/rest/api/content/search?cql=$projectCql&expand=version,ancestors"
    
    Write-Log "Debug: Searching for $sourceProjectKey with URL: $projectSearchUrl" -Level "INFO"
    
    $projectSearchResponse = Invoke-RestMethod -Uri $projectSearchUrl -Headers @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
        "Accept" = "application/json"
    } -Method Get
    
    Write-Log "Debug: $sourceProjectKey search response size: $($projectSearchResponse.size)" -Level "INFO"
    
    if ($projectSearchResponse.results -and $projectSearchResponse.results.Count -gt 0) {
        $existingProjectFolder = $projectSearchResponse.results[0]
        Write-Log "Debug: Found $sourceProjectKey page (ID: $($existingProjectFolder.id))" -Level "INFO"
        
        # Check if it's under Sandbox
        $isUnderSandbox = $false
        if ($existingProjectFolder.ancestors) {
            Write-Log "Debug: $sourceProjectKey has $($existingProjectFolder.ancestors.Count) ancestors" -Level "INFO"
            foreach ($ancestor in $existingProjectFolder.ancestors) {
                Write-Log "Debug: Ancestor: $($ancestor.title) (ID: $($ancestor.id))" -Level "INFO"
                if ($ancestor.id -eq $sandboxFolder.id) {
                    $isUnderSandbox = $true
                    break
                }
            }
        }
        
        if ($isUnderSandbox) {
            Write-Log "✅ Found $sourceProjectKey folder already under Sandbox (ID: $($existingProjectFolder.id))" -Level "INFO"
            $projectFolder = $existingProjectFolder
        } else {
            Write-Log "⚠️ $sourceProjectKey folder exists but not under Sandbox (deleting old one and creating new)..." -Level "WARNING"
            
            # Delete the old project page
            try {
                $deleteUrl = "$baseUrl/rest/api/content/$($existingProjectFolder.id)"
                $deleteHeaders = @{
                    "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
                }
                if ($script:DryRun) { Write-Log "[DRYRUN] DELETE $deleteUrl" } else { Invoke-JiraWithRetry -Uri $deleteUrl -Headers $deleteHeaders -Method Delete -MaxRetries 3 -TimeoutSec 30 }
                Write-Log "✅ Deleted old $sourceProjectKey page" -Level "INFO"
            } catch {
                Write-Log "⚠️ Failed to delete old $sourceProjectKey page: $($_.Exception.Message)" -Level "WARNING"
            }
            
            # Create project as a proper folder page
            $projectFolderContent = @"
<h1>$sourceProjectKey Migration Documentation</h1>

<p><strong>Source Project:</strong> $sourceProjectName ($sourceProjectKey)</p>
<p><strong>Target Project:</strong> $targetProjectName ($targetProjectKey)</p>
<p><strong>Migration Date:</strong> $(Get-Date -Format "MMMM d, yyyy")</p>
<p><strong>Status:</strong> <span style="color: green;">✅ Completed</span></p>

<h2>📋 Overview</h2>
<p>This folder contains all documentation, reports, and analysis for the $sourceProjectKey migration.</p>

<h2>📄 Documentation Pages</h2>
<p><em>Documentation pages are being created...</em></p>

<h2>📁 Attachments</h2>
<p>CSV reports and data files will be attached to the respective pages.</p>
"@
            $projectFolder = Create-ConfluencePage -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -Title $sourceProjectKey -Content $projectFolderContent -ParentId $sandboxFolder.id
            
            # Reorder pages after creating new project folder
            if ($projectFolder) {
                Write-Log "🔄 Reordering pages after creating new $sourceProjectKey folder..." -Level "INFO"
                Reorder-ConfluencePages -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -ParentPageId $sandboxFolder.id | Out-Null
            }
        }
    } else {
        Write-Log "📄 Creating new $sourceProjectKey folder under Sandbox..." -Level "INFO"
        # Create project as a proper folder page
        $projectFolderContent = @"
<h1>$sourceProjectKey Migration Documentation</h1>

<p><strong>Source Project:</strong> $sourceProjectName ($sourceProjectKey)</p>
<p><strong>Target Project:</strong> $targetProjectName ($targetProjectKey)</p>
<p><strong>Migration Date:</strong> $(Get-Date -Format "MMMM d, yyyy")</p>
<p><strong>Status:</strong> <span style="color: green;">✅ Completed</span></p>

<h2>📋 Overview</h2>
<p>This folder contains all documentation, reports, and analysis for the $sourceProjectKey to $targetProjectKey migration.</p>

<h2>📄 Documentation Pages</h2>
<p><em>Documentation pages are being created...</em></p>

<h2>📁 Attachments</h2>
<p>CSV reports and data files will be attached to the respective pages.</p>
"@
        $projectFolder = Create-ConfluencePage -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -Title $sourceProjectKey -Content $projectFolderContent -ParentId $sandboxFolder.id
        
        # Reorder pages after creating new project folder
        if ($projectFolder) {
            Write-Log "🔄 Reordering pages after creating new $sourceProjectKey folder..." -Level "INFO"
            Reorder-ConfluencePages -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -ParentPageId $sandboxFolder.id | Out-Null
        }
    }
} catch {
    Write-Log "⚠️ Error searching for ${sourceProjectKey}: $($_.Exception.Message)" -Level "WARNING"
    Write-Log "📄 Creating new $sourceProjectKey folder under Sandbox..." -Level "INFO"
    # Create project as a proper folder page
    $projectFolderContent = @"
<h1>$sourceProjectKey Migration Documentation</h1>

<p><strong>Source Project:</strong> $sourceProjectName ($sourceProjectKey)</p>
<p><strong>Target Project:</strong> $targetProjectName ($targetProjectKey)</p>
<p><strong>Migration Date:</strong> $(Get-Date -Format "MMMM d, yyyy")</p>
<p><strong>Status:</strong> <span style="color: green;">✅ Completed</span></p>

<h2>📋 Overview</h2>
<p>This folder contains all documentation, reports, and analysis for the $sourceProjectKey to $targetProjectKey migration.</p>

<h2>📄 Documentation Pages</h2>
<p><em>Documentation pages are being created...</em></p>

<h2>📁 Attachments</h2>
<p>CSV reports and data files will be attached to the respective pages.</p>
"@
    $projectFolder = Create-ConfluencePage -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -Title $sourceProjectKey -Content $projectFolderContent -ParentId $sandboxFolder.id
    
    # Reorder pages after creating new project folder
    if ($projectFolder) {
        Write-Log "🔄 Reordering pages after creating new $sourceProjectKey folder..." -Level "INFO"
        Reorder-ConfluencePages -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -ParentPageId $sandboxFolder.id | Out-Null
    }
}

if (-not $projectFolder) {
    Write-Log "❌ Failed to create $sourceProjectKey folder under Sandbox" -Level "ERROR"
    exit 1
}

# Check if there are existing pages that need to be moved under project folder
Write-Log "🔍 Checking for existing pages to move under $sourceProjectKey folder..." -Level "INFO"
$pagesToMove = @("Migration Receipts & Summary")

foreach ($pageTitle in $pagesToMove) {
    try {
        $pageCql = [System.Web.HttpUtility]::UrlEncode("space = $spaceKey AND title = '$pageTitle'")
        $pageSearchUrl = "$baseUrl/rest/api/content/search?cql=$pageCql&expand=version,ancestors"
        
        if ($script:DryRun) { Write-Log "[DRYRUN] GET $pageSearchUrl"; $pageSearchResponse = @{ results = @() } } else { $pageSearchResponse = Invoke-RestMethod -Uri $pageSearchUrl -Headers @{
            "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
            "Accept" = "application/json"
        } -Method Get }
        
        if ($pageSearchResponse.results -and $pageSearchResponse.results.Count -gt 0) {
            $existingPage = $pageSearchResponse.results[0]
            
            # Check if it's already under project folder or Sandbox directly
            $isUnderProject = $false
            $isUnderSandbox = $false
            
            if ($existingPage.ancestors) {
                foreach ($ancestor in $existingPage.ancestors) {
                    if ($ancestor.id -eq $projectFolder.id) {
                        $isUnderProject = $true
                        break
                    }
                    if ($ancestor.id -eq $sandboxFolder.id) {
                        $isUnderSandbox = $true
                    }
                }
            }
            
            if (-not $isUnderProject -and $isUnderSandbox) {
                Write-Log "📦 Moving '$pageTitle' under $sourceProjectKey folder..." -Level "INFO"
                
                # Get current page details
                $getPageUrl = "$baseUrl/rest/api/content/$($existingPage.id)?expand=version,body.storage"
                if ($script:DryRun) { Write-Log "[DRYRUN] GET $getPageUrl"; $currentPageDetails = @{ version = @{ number = 1 }; body = @{ storage = @{ value = '' } } } } else { $currentPageDetails = Invoke-RestMethod -Uri $getPageUrl -Headers @{
                    "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
                    "Accept" = "application/json"
                } -Method Get }
                
                # Safely get existing page content
                $existingContent = ""
                if ($currentPageDetails.body -and $currentPageDetails.body.storage -and $currentPageDetails.body.storage.value) {
                    $existingContent = $currentPageDetails.body.storage.value
                } elseif ($currentPageDetails.body -and $currentPageDetails.body.atlas_doc_format -and $currentPageDetails.body.atlas_doc_format.value) {
                    $existingContent = $currentPageDetails.body.atlas_doc_format.value
                }
                
                # Update page to move it under project folder
                $updatePageUrl = "$baseUrl/rest/api/content/$($existingPage.id)"
                $updatePageBody = @{
                    version = @{ number = $currentPageDetails.version.number + 1 }
                    title = $pageTitle
                    type = "page"
                    space = @{ key = $spaceKey }
                    ancestors = @(@{ id = $projectFolder.id })
                    body = @{
                        storage = @{
                            value = $existingContent
                            representation = "storage"
                        }
                    }
                } | ConvertTo-Json -Depth 10
                
                if ($script:DryRun) { Write-Log "[DRYRUN] PUT $updatePageUrl (move page under project folder)" } else { $updateResponse = Invoke-RestMethod -Uri $updatePageUrl -Headers @{
                    "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
                    "Accept" = "application/json"
                    "Content-Type" = "application/json"
                } -Method Put -Body $updatePageBody }
                
                Write-Log "✅ Moved '$pageTitle' under $sourceProjectKey folder" -Level "INFO"
            } elseif ($isUnderProject) {
                Write-Log "✅ '$pageTitle' is already under $sourceProjectKey folder" -Level "INFO"
            } else {
                Write-Log "ℹ️ '$pageTitle' is not under Sandbox, skipping move" -Level "INFO"
            }
        }
    } catch {
        Write-Log "⚠️ Failed to check/move '$pageTitle': $($_.Exception.Message)" -Level "WARNING"
    }
}

# Read the migration summary markdown file
$receiptsMarkdownPath = Join-Path $OutDir "MIGRATION_SUMMARY.md"
if (Test-Path $receiptsMarkdownPath) {
    $receiptsContent = Get-Content $receiptsMarkdownPath -Raw
    $confluenceReceiptsContent = Convert-MarkdownToConfluenceWiki -MarkdownContent $receiptsContent
    
    # Put everything on the main DEP page - no subpages
    Write-Log "📄 Adding migration content directly to DEP page..." -Level "INFO"
    
    # Upload CSV attachments to the main DEP page
    $csvFiles = @(
        "03_UsersAndRoles_Report.csv",
        "15_IssueKeyMapping.csv", 
        "08_OrphanedIssues.csv",
        "11_SkippedLinks_NeedManualCreation.csv",
        "Issues_Updated_More_Than_12_Months_Ago.csv"
    )
    
    $uploadedFiles = @()
    foreach ($csvFile in $csvFiles) {
        $csvPath = Join-Path $OutDir $csvFile
        if (Test-Path $csvPath) {
            $absolutePath = (Resolve-Path $csvPath).Path
            $uploadResult = Upload-ConfluenceAttachment -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -PageId $projectFolder.id -FilePath $absolutePath -Comment "Migration data export"
            if ($uploadResult) {
                $uploadedFiles += $csvFile
            }
        } else {
            Write-Log "⚠️ CSV file not found, skipping: $csvPath" -Level "WARNING"
        }
    }
    
    # Update the main DEP page with migration content and attachments
    if ($uploadedFiles.Count -gt 0) {
        # Create ONE attachments macro for all files
        $attachmentsMacro = "<h2>📎 Migration Reports</h2>`n<ac:structured-macro ac:name=`"attachments`" ac:schema-version=`"1`" ac:macro-id=`"$(New-Guid)`">`n"
        $attachmentsMacro += "<ac:parameter ac:name=`"patterns`">*.csv</ac:parameter>`n"
        $attachmentsMacro += "<ac:parameter ac:name=`"sortBy`">name</ac:parameter>`n"
        $attachmentsMacro += "<ac:parameter ac:name=`"sortOrder`">desc</ac:parameter>`n"
        $attachmentsMacro += "<ac:parameter ac:name=`"showIcons`">true</ac:parameter>`n"
        $attachmentsMacro += "</ac:structured-macro>`n"
        
        $updatedContent = $confluenceReceiptsContent + $attachmentsMacro
        
        # Update the main DEP page with migration content and attachments
        try {
            $headers = @{
                "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
                "Content-Type" = "application/json"
            }
            
            # Get current page version
            $getUrl = "$baseUrl/rest/api/content/$($projectFolder.id)?expand=version"
            if ($script:DryRun) { Write-Log "[DRYRUN] GET $getUrl"; $currentPage = @{ version = @{ number = 1 } } } else { $currentPage = Invoke-RestMethod -Uri $getUrl -Headers $headers -Method Get }
            
            # Update page content using Wiki Markup (without position - will be set by reordering)
            $updateBody = @{
                "id" = $projectFolder.id
                "type" = "page"
                "title" = $sourceProjectKey
                "version" = @{ "number" = ($currentPage.version.number + 1) }
                "body" = @{
                    "wiki" = @{
                        "value" = $updatedContent
                        "representation" = "wiki"
                    }
                }
            } | ConvertTo-Json -Depth 10
            
            $updateUrl = "$baseUrl/rest/api/content/$($projectFolder.id)"
            if ($script:DryRun) { Write-Log "[DRYRUN] PUT $updateUrl (update DEP page content)" } else { Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Put -Body $updateBody }
            Write-Log "✅ Updated $sourceProjectKey page with migration content and single attachments macro" -Level "INFO"
            
            # Reorder all pages under Sandbox alphabetically
            Write-Log "🔄 Reordering all project pages under Sandbox alphabetically..." -Level "INFO"
            $reorderSuccess = Reorder-ConfluencePages -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -ParentPageId $sandboxFolder.id
            if ($reorderSuccess) {
                Write-Log "✅ Successfully reordered all pages under Sandbox" -Level "INFO"
            } else {
                Write-Log "⚠️ Failed to reorder pages under Sandbox" -Level "WARNING"
            }
        } catch {
            Write-Log "⚠️ Failed to update DEP page: $($_.Exception.Message)" -Level "WARNING"
        }
    }
} else {
    Write-Log "⚠️ Migration summary file not found: $receiptsMarkdownPath" -Level "WARNING"
    
    # Create a basic receipts page with available data
    $basicReceiptsContent = @"
<h1>Migration Receipts & Summary</h1>

<p><strong>Source Project:</strong> $sourceProjectName ($sourceProjectKey)</p>
<p><strong>Target Project:</strong> $targetProjectName ($targetProjectKey)</p>
<p><strong>Migration Date:</strong> $(Get-Date -Format "MMMM d, yyyy")</p>

<h2>📊 Available Reports</h2>
<p>The following CSV reports are available as attachments:</p>
<ul>
<li>User and Roles Report</li>
<li>Issue Key Mapping</li>
<li>Orphaned Issues</li>
<li>Skipped Links</li>
<li>Issues Updated More Than 12 Months Ago</li>
</ul>

<h2>⚠️ Issues Updated More Than a Year Ago</h2>

<h2>📁 Individual Step Receipts</h2>
<p>Check the project output directory for individual step receipts in JSON format.</p>

<p><em>Note: Full consolidated receipts will be available after running step 15 successfully.</em></p>
"@
    
    # Load stale issues data from sprints receipt
    $staleIssuesData = $null
    $staleIssuesCount = 0
    $staleIssuesFileName = "Issues_Updated_More_Than_12_Months_Ago.csv"
    $staleIssuesFilePath = Join-Path $OutDir $staleIssuesFileName
    
    try {
        $sprintsReceiptPath = Join-Path $OutDir "13_Sprints_receipt.json"
        if (Test-Path $sprintsReceiptPath) {
            $sprintsReceipt = Get-Content $sprintsReceiptPath -Raw | ConvertFrom-Json
            if ($sprintsReceipt.StaleIssuesReport) {
                $staleIssuesData = $sprintsReceipt.StaleIssuesReport
                $staleIssuesCount = $staleIssuesData.Count
                Write-Log "📊 Loaded stale issues data: $staleIssuesCount issues found" -Level "INFO"
            }
        }
    } catch {
        Write-Log "⚠️ Could not load stale issues data: $($_.Exception.Message)" -Level "WARNING"
    }
    
    # Update the receipts content with stale issues data
    if ($staleIssuesCount -gt 0) {
        $staleIssuesSection = @"

<p><strong>Found $staleIssuesCount issues that haven't been updated in over 12 months.</strong> These issues may need attention for maintenance, archival, or closure decisions.</p>

<p><em>The detailed CSV report is available as an attachment below with the following information:</em></p>
<ul>
<li>Source and Target Issue IDs (with hyperlinks)</li>
<li>Issue Summary</li>
<li>Original Updated Date</li>
<li>Original Created Date</li>
<li>Days Since Updated</li>
<li>Days Since Created</li>
</ul>

<p><strong>⚠️ Recommendation:</strong> Review these issues to determine if they should be updated, closed, or archived.</p>
"@
        $basicReceiptsContent = $basicReceiptsContent -replace "<h2>⚠️ Issues Updated More Than a Year Ago</h2>", "<h2>⚠️ Issues Updated More Than a Year Ago ($staleIssuesCount)</h2>$staleIssuesSection"
    } else {
        $noStaleIssuesSection = @"

<p><strong>✅ No stale issues found!</strong> All issues have been updated within the last 12 months.</p>
"@
        $basicReceiptsContent = $basicReceiptsContent -replace "<h2>⚠️ Issues Updated More Than a Year Ago</h2>", "<h2>⚠️ Issues Updated More Than a Year Ago (0)</h2>$noStaleIssuesSection"
    }
    
    $receiptsPage = Create-ConfluencePage -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -Title "Migration Receipts & Summary" -Content $basicReceiptsContent -ParentId $projectFolder.id
    if ($receiptsPage) {
        Write-Log "✅ Created basic Migration Receipts page" -Level "INFO"
        
        # Upload CSV attachments to receipts page
        $csvFiles = @(
            "03_UsersAndRoles_Report.csv",
            "15_IssueKeyMapping.csv", 
            "08_OrphanedIssues.csv",
            "11_SkippedLinks_NeedManualCreation.csv",
            $staleIssuesFileName
        )
        
        foreach ($csvFile in $csvFiles) {
            $csvPath = Join-Path $OutDir $csvFile
            if (Test-Path $csvPath) {
                $absolutePath = (Resolve-Path $csvPath).Path
                Upload-ConfluenceAttachment -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -PageId $receiptsPage.id -FilePath $absolutePath -Comment "Migration data export"
            } else {
                Write-Log "⚠️ CSV file not found, skipping: $csvPath" -Level "WARNING"
            }
        }
    }
}

# Quick Start Guide page removed - not needed

# QA Checklist page removed - not needed

# Migration Dashboard page removed - not working properly

# Create receipt
$receiptData = @{
    StartTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    EndTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
    ConfluenceSpace = $space.name
    ConfluenceSpaceKey = $space.key
    SandboxFolderCreated = if ($sandboxFolder) { $true } else { $false }
    SandboxFolderId = if ($sandboxFolder) { $sandboxFolder.id } else { $null }
    ProjectFolderCreated = if ($projectFolder) { $true } else { $false }
    ProjectFolderId = if ($projectFolder) { $projectFolder.id } else { $null }
    PagesCreated = @(
        if ($receiptsPage) { "Migration Receipts & Summary" }
    ) | Where-Object { $_ -ne $null }
    AttachmentsUploaded = @(
        if (Test-Path (Join-Path $OutDir "03_UsersAndRoles_Report.csv")) { "03_UsersAndRoles_Report.csv" }
        if (Test-Path (Join-Path $OutDir "15_IssueKeyMapping.csv")) { "15_IssueKeyMapping.csv" }
        if (Test-Path (Join-Path $OutDir "08_OrphanedIssues.csv")) { "08_OrphanedIssues.csv" }
        if (Test-Path (Join-Path $OutDir "11_SkippedLinks_NeedManualCreation.csv")) { "11_SkippedLinks_NeedManualCreation.csv" }
        if (Test-Path (Join-Path $OutDir "migration_review_dashboard.html")) { "migration_review_dashboard.html" }
    )
}

$receiptPath = Join-Path $OutDir "16_PushToConfluence_receipt.json"
try {
    $receiptData | ConvertTo-Json -Depth 3 | Out-File -FilePath $receiptPath -Encoding UTF8
    Write-Log "✅ Receipt written: $receiptPath" -Level "INFO"
} catch {
    Write-Log "⚠️ Failed to write receipt: $($_.Exception.Message)" -Level "WARNING"
}

# Update project folder with real links to all created pages
Write-Log "🔗 Updating $sourceProjectKey folder with links to created pages..." -Level "INFO"

    $projectFolderContent = @"
<h1>$sourceProjectKey Migration Documentation</h1>

<p><strong>Source Project:</strong> $sourceProjectName ($sourceProjectKey)</p>
<p><strong>Target Project:</strong> $targetProjectName ($targetProjectKey)</p>
<p><strong>Migration Date:</strong> $(Get-Date -Format "MMMM d, yyyy")</p>
<p><strong>Status:</strong> <span style="color: green;">✅ Completed</span></p>

<h2>📋 Overview</h2>
<p>This folder contains all documentation, reports, and analysis for the $sourceProjectKey to $targetProjectKey migration.</p>

<h2>📄 Documentation Pages</h2>
<ul>
"@

# Add real links to created pages
if ($receiptsPage -and $receiptsPage.id) {
    $projectFolderContent += "<li><a href=""$($baseUrl)/wiki/spaces/$($space.key)/pages/$($receiptsPage.id)/Migration+Receipts+%26+Summary"">Migration Receipts & Summary</a></li>`n"
}

$projectFolderContent += @"
</ul>

<h2>📊 Key Statistics</h2>
<p><em>See the Migration Receipts page for detailed statistics</em></p>

<h2>📁 Attachments</h2>
<p>CSV reports and data files are attached to the respective pages above.</p>

<h2>🔗 Quick Links</h2>
<p>
"@

# Add quick links only for pages that exist
if ($receiptsPage -and $receiptsPage.id) {
    $projectFolderContent += "<a href=""$($baseUrl)/wiki/spaces/$($space.key)/pages/$($receiptsPage.id)/Migration+Receipts+%26+Summary"" style=""background: #0052CC; color: white; padding: 8px 16px; text-decoration: none; border-radius: 4px; margin-right: 8px;"">📊 View Migration Summary</a>"
}

$projectFolderContent += @"
</p>
"@

# Update the project folder page with the new content
try {
    # First, get the current page details to get the version number
    $getUrl = "$baseUrl/rest/api/content/$($projectFolder.id)?expand=version"
    if ($script:DryRun) { Write-Log "[DRYRUN] GET $getUrl"; $currentPage = @{ version = @{ number = 1 } } } else { $currentPage = Invoke-RestMethod -Uri $getUrl -Headers @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
        "Accept" = "application/json"
    } -Method Get }
    
    $versionNumber = if ($currentPage.version -and $currentPage.version.number) { $currentPage.version.number + 1 } else { 2 }
    
    $updateUrl = "$baseUrl/rest/api/content/$($projectFolder.id)"
    $updateBody = @{
        version = @{ number = $versionNumber }
        title = $sourceProjectKey
        type = "page"
        space = @{ key = $spaceKey }
        body = @{
            storage = @{
                value = $projectFolderContent
                representation = "storage"
            }
        }
    } | ConvertTo-Json -Depth 10

    if ($script:DryRun) { Write-Log "[DRYRUN] PUT $updateUrl (update project folder page)" } else { $updateResponse = Invoke-RestMethod -Uri $updateUrl -Headers @{
        "Authorization" = "Basic $([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$email`:$apiToken")))"
        "Accept" = "application/json"
        "Content-Type" = "application/json"
    } -Method Put -Body $updateBody }

    Write-Log "✅ Updated $sourceProjectKey folder with real links to all pages" -Level "INFO"
    
    # Final reordering to ensure all pages are in alphabetical order
    Write-Log "🔄 Final reordering of all project pages under Sandbox..." -Level "INFO"
    $finalReorderSuccess = Reorder-ConfluencePages -BaseUrl $baseUrl -Email $email -ApiToken $apiToken -SpaceKey $spaceKey -ParentPageId $sandboxFolder.id
    if ($finalReorderSuccess) {
        Write-Log "✅ Final reordering completed successfully" -Level "INFO"
    } else {
        Write-Log "⚠️ Final reordering failed" -Level "WARNING"
    }
    
} catch {
    Write-Log "⚠️ Failed to update $sourceProjectKey folder content: $($_.Exception.Message)" -Level "WARNING"
}

Write-Log "🎉 Step 16 completed successfully!" -Level "INFO"
Write-Log "📄 Confluence documentation created in space: $($space.name)" -Level "INFO"
Write-Log "🔗 $sourceProjectKey folder URL: $baseUrl/wiki/spaces/$($space.key)/pages/$($projectFolder.id)/$sourceProjectKey" -Level "INFO"

exit 0
