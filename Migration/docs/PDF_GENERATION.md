# PDF Report Generation

The Migration Toolkit can optionally generate PDF versions of the three main markdown reports at the end of Step 14 (Review Migration).

## Generated PDFs

When enabled, the following PDF files are created in `projects/[PROJECT]/out/`:

1. **MIGRATION_SUMMARY.pdf** - Executive summary with key metrics and action items
2. **QUICK_START_GUIDE.pdf** - Step-by-step guide for the first week post-migration
3. **QA_CHECKLIST.pdf** - Comprehensive validation checklist

## Configuration

### Option 1: Automatic (No Prompt)

Set `GeneratePdfReports` to `true` in your `parameters.json`:

```json
{
  "MigrationSettings": {
    "GeneratePdfReports": true
  }
}
```

### Option 2: Interactive Prompt (Default)

If `GeneratePdfReports` is `false` or not set, Step 14 will prompt you:

```
Generate PDF versions of markdown reports? (Y/N)
```

## Requirements

PDF generation requires one of the following tools to be installed:

### Recommended: Pandoc + LaTeX

**Pandoc** is the recommended tool for high-quality PDF generation with proper formatting, syntax highlighting, and layout control.

#### Installation (Windows with Chocolatey):

```powershell
# Install Pandoc
choco install pandoc -y

# Install MiKTeX (LaTeX distribution for PDF engine)
choco install miktex -y
```

#### Installation (Other Methods):

- **Pandoc:** https://pandoc.org/installing.html
- **MiKTeX:** https://miktex.org/download
- **Alternative LaTeX:** Install TeX Live instead of MiKTeX

### Alternative: wkhtmltopdf

**Note:** wkhtmltopdf requires HTML input, so it's less convenient for markdown files. Pandoc is strongly recommended.

```powershell
choco install wkhtmltopdf -y
```

## How It Works

1. **After all reports are generated** (at the end of Step 14), the script checks for PDF conversion tools
2. **If Pandoc is found:**
   - Converts each markdown file to PDF using the XeLaTeX engine (with fallback to default)
   - Applies formatting: 1-inch margins, 11pt font, syntax highlighting
   - Creates PDFs in the same `out/` folder as the markdown files
3. **If no tools are found:**
   - Displays installation instructions
   - Continues without generating PDFs (markdown files are still available)

## PDF Generation Process

The script attempts the following for each markdown file:

1. **Try with XeLaTeX engine** (best quality, requires full LaTeX installation)
2. **Fallback to default engine** (if XeLaTeX is not available)
3. **Report success or failure** for each file

Example output:

```
📄 PDF Generation (Optional)

Checking for PDF conversion tools...
✅ Found Pandoc - using for PDF generation
   ✅ Generated: MIGRATION_SUMMARY.pdf
   ✅ Generated: QUICK_START_GUIDE.pdf
   ✅ Generated: QA_CHECKLIST.pdf

✅ Generated 3 PDF report(s)
```

## Troubleshooting

### "No PDF converter found"

**Solution:** Install Pandoc and MiKTeX using the commands above.

### "Failed to generate PDF"

**Possible causes:**
- LaTeX engine not installed (install MiKTeX or TeX Live)
- Markdown contains special characters that LaTeX can't process
- Insufficient permissions to write files

**Solution:**
1. Ensure MiKTeX or TeX Live is installed
2. Check the markdown files for special characters
3. Run PowerShell as Administrator if needed

### "wkhtmltopdf requires HTML input"

**Solution:** Install Pandoc instead, which can convert markdown directly to PDF.

## Manual PDF Generation

If automatic generation fails, you can manually convert the markdown files:

### Using Pandoc (Command Line):

```powershell
cd projects/[PROJECT]/out

# Generate MIGRATION_SUMMARY.pdf
pandoc MIGRATION_SUMMARY.md -o MIGRATION_SUMMARY.pdf -V geometry:margin=1in -V fontsize=11pt

# Generate QUICK_START_GUIDE.pdf
pandoc QUICK_START_GUIDE.md -o QUICK_START_GUIDE.pdf -V geometry:margin=1in -V fontsize=11pt

# Generate QA_CHECKLIST.pdf
pandoc QA_CHECKLIST.md -o QA_CHECKLIST.pdf -V geometry:margin=1in -V fontsize=11pt
```

### Using Online Converters:

If you can't install Pandoc, use an online markdown-to-PDF converter:
- https://www.markdowntopdf.com/
- https://cloudconvert.com/md-to-pdf
- https://products.aspose.app/pdf/conversion/md-to-pdf

## Benefits of PDF Reports

- **Professional presentation** for stakeholders and management
- **Easy sharing** via email or document management systems
- **Print-friendly** for physical documentation
- **Portable format** that looks the same on all devices
- **Archival quality** for long-term storage

## Notes

- PDF generation is **optional** and does not affect the migration process
- Markdown files are always generated, regardless of PDF settings
- CSV reports (Users, Orphaned Issues, Skipped Links) are **not** converted to PDF
- PDF generation adds approximately 10-30 seconds to Step 14 execution time
- Generated PDFs are tracked in the Step 14 receipt

## See Also

- [Project Lead Deliverables](PROJECT_LEAD_DELIVERABLES.md) - Overview of all deliverables
- [Migration Guide](MIGRATION_GUIDE.md) - Complete migration process
- Pandoc Documentation: https://pandoc.org/MANUAL.html

