# Fix Markdown Linting Issues
# This script fixes common Markdown linting errors

$files = @(
    "GITHUB_SETUP_GUIDE.md",
    "POWERBI_DASHBOARD_MOCKUP.md", 
    "POWERBI_BEST_PRACTICES_LAYOUT.md"
)

foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Host "Fixing $file..." -ForegroundColor Yellow
        
        $content = Get-Content $file -Raw
        
        # Fix MD022: Add blank lines around headings
        $content = $content -replace '(\n###[^\n]+\n)([^#\n])', '$1`n$2'
        $content = $content -replace '(\n####[^\n]+\n)([^#\n])', '$1`n$2'
        
        # Fix MD032: Add blank lines around lists
        $content = $content -replace '(\n)([^\n]*\n)(- [^\n]+)', '$1$2`n$3'
        $content = $content -replace '(\n)([^\n]*\n)(\d+\. [^\n]+)', '$1$2`n$3'
        
        # Fix MD031: Add blank lines around fenced code blocks
        $content = $content -replace '(\n)([^`\n]*\n)(```)', '$1$2`n$3'
        $content = $content -replace '(```\n)([^`\n]*\n)([^`\n])', '$1$2`n$3'
        
        # Fix MD040: Add language to fenced code blocks
        $content = $content -replace '(\n```)(\n[^`]+)', '$1text$2'
        
        # Fix MD029: Fix ordered list numbering
        $content = $content -replace '(\n)(\d+\. [^\n]+\n)(\d+\. [^\n]+)', '$1$2$3'
        
        # Fix MD024: Fix duplicate headings by adding unique identifiers
        $content = $content -replace '(\n### \*\*Layout Specifications:\*\*)', '$1 (Page 1)'
        $content = $content -replace '(\n### \*\*Layout Specifications:\*\*)', '$1 (Page 2)'
        $content = $content -replace '(\n### \*\*Layout Specifications:\*\*)', '$1 (Page 3)'
        
        Set-Content $file -Value $content -NoNewline
        Write-Host "Fixed $file" -ForegroundColor Green
    }
}

Write-Host "All Markdown files have been fixed!" -ForegroundColor Green
