# _improved_error_handling.ps1 - Enhanced Error Handling for Migration Scripts
#
# This module provides improved error handling functions for better user experience

function Write-EnhancedError {
    param(
        [string]$StepName,
        [string]$ErrorMessage,
        [string]$Context = "",
        [array]$Solutions = @(),
        [string]$HelpUrl = ""
    )
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  ERROR: $($StepName.PadRight(55)) ║" -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    
    Write-Host "❌ Error Details:" -ForegroundColor Red
    Write-Host "   $ErrorMessage" -ForegroundColor White
    
    if ($Context) {
        Write-Host ""
        Write-Host "🔍 Context:" -ForegroundColor Yellow
        Write-Host "   $Context" -ForegroundColor Gray
    }
    
    if ($Solutions.Count -gt 0) {
        Write-Host ""
        Write-Host "💡 Solutions:" -ForegroundColor Green
        for ($i = 0; $i -lt $Solutions.Count; $i++) {
            Write-Host "   $($i + 1). $($Solutions[$i])" -ForegroundColor White
        }
    }
    
    if ($HelpUrl) {
        Write-Host ""
        Write-Host "📚 More Help:" -ForegroundColor Cyan
        Write-Host "   $HelpUrl" -ForegroundColor Blue
    }
    
    Write-Host ""
}

function Write-APIError {
    param(
        [string]$StepName,
        [string]$ApiEndpoint,
        [int]$StatusCode,
        [string]$ErrorMessage,
        [string]$ResponseBody = ""
    )
    
    $context = "API Call: $ApiEndpoint`nStatus: $StatusCode"
    if ($ResponseBody) {
        $context += "`nResponse: $ResponseBody"
    }
    
    $solutions = @()
    
    switch ($StatusCode) {
        400 { 
            $solutions += "Check request parameters and data format"
            $solutions += "Verify all required fields are provided"
            $solutions += "Check for invalid characters in project key/name"
        }
        401 { 
            $solutions += "Verify API token is valid and not expired"
            $solutions += "Check username/email is correct"
            $solutions += "Ensure user has appropriate permissions"
        }
        403 { 
            $solutions += "Check user permissions for this operation"
            $solutions += "Verify user has project creation rights"
            $solutions += "Contact Jira administrator for access"
        }
        404 { 
            $solutions += "Verify the endpoint URL is correct"
            $solutions += "Check if the resource exists"
            $solutions += "Verify project key is valid"
        }
        409 { 
            $solutions += "Project key may already exist"
            $solutions += "Check Trash/Recycle Bin for deleted projects"
            $solutions += "Use a different project key"
        }
        429 { 
            $solutions += "Rate limit exceeded - wait and retry"
            $solutions += "Reduce concurrent API calls"
            $solutions += "Check Jira instance status"
        }
        500 { 
            $solutions += "Jira server error - try again later"
            $solutions += "Check Jira instance status"
            $solutions += "Contact Jira administrator"
        }
        default {
            $solutions += "Check Jira instance status"
            $solutions += "Verify network connectivity"
            $solutions += "Review error logs for more details"
        }
    }
    
    Write-EnhancedError -StepName $StepName -ErrorMessage $ErrorMessage -Context $context -Solutions $solutions
}

function Write-ValidationError {
    param(
        [string]$StepName,
        [string]$FieldName,
        [string]$CurrentValue,
        [string]$ExpectedFormat,
        [string]$Example = ""
    )
    
    $errorMessage = "Invalid $FieldName value: '$CurrentValue'"
    $context = "Field: $FieldName`nCurrent: '$CurrentValue'`nExpected: $ExpectedFormat"
    
    $solutions = @()
    $solutions += "Check the value format matches requirements"
    $solutions += "Verify no invalid characters are present"
    if ($Example) {
        $solutions += "Example: $Example"
    }
    $solutions += "Review the configuration file"
    
    Write-EnhancedError -StepName $StepName -ErrorMessage $errorMessage -Context $context -Solutions $solutions
}

function Write-NetworkError {
    param(
        [string]$StepName,
        [string]$Url,
        [string]$ErrorMessage
    )
    
    $context = "URL: $Url`nError: $ErrorMessage"
    
    $solutions = @()
    $solutions += "Check network connectivity"
    $solutions += "Verify the URL is accessible"
    $solutions += "Check firewall/proxy settings"
    $solutions += "Try again in a few moments"
    
    Write-EnhancedError -StepName $StepName -ErrorMessage "Network connection failed" -Context $context -Solutions $solutions
}

function Write-PermissionError {
    param(
        [string]$StepName,
        [string]$RequiredPermission,
        [string]$Resource = ""
    )
    
    $errorMessage = "Insufficient permissions for $RequiredPermission"
    $context = "Required: $RequiredPermission"
    if ($Resource) {
        $context += "`nResource: $Resource"
    }
    
    $solutions = @()
    $solutions += "Contact Jira administrator to grant permissions"
    $solutions += "Verify user account has required access"
    $solutions += "Check project permissions and roles"
    $solutions += "Use a different user account with proper permissions"
    
    Write-EnhancedError -StepName $StepName -ErrorMessage $errorMessage -Context $context -Solutions $solutions
}

# Export functions for use in other scripts
Export-ModuleMember -Function Write-EnhancedError, Write-APIError, Write-ValidationError, Write-NetworkError, Write-PermissionError
