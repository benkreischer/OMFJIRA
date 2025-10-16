# =============================================================================
# HELPER FUNCTION: Get-EndpointParameters
# =============================================================================
#
# DESCRIPTION: Loads and returns endpoint configuration parameters from 
#              endpoints-parameters.json file
#
# USAGE: 
#   $Params = Get-EndpointParameters
#   $Params = Get-EndpointParameters -Environment "SourceEnvironment"
#   $Params = Get-EndpointParameters -ParametersPath "custom-path.json"
#
# =============================================================================

function Get-EndpointParameters {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Environment = "Production",
        
        [Parameter(Mandatory = $false)]
        [string]$ParametersPath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeCredentials = $true
    )
    
    try {
        # Determine the path to the parameters file
        if ([string]::IsNullOrEmpty($ParametersPath)) {
            # Start from current location and search up for the parameters file
            $CurrentDir = Get-Location
            $ParametersPath = ""
            
            # Search up the directory tree for endpoints-parameters.json
            $SearchDir = $CurrentDir
            do {
                $TestPath = Join-Path $SearchDir "endpoints-parameters.json"
                if (Test-Path $TestPath) {
                    $ParametersPath = $TestPath
                    break
                }
                $ParentDir = Split-Path -Parent $SearchDir
                if ($ParentDir -eq $SearchDir) { break }  # Reached root
                $SearchDir = $ParentDir
            } while ($true)
            
            # If not found, try relative to the helper script location
            if ([string]::IsNullOrEmpty($ParametersPath)) {
                $ScriptDir = if ($MyInvocation.ScriptName) { 
                    Split-Path -Parent $MyInvocation.ScriptName 
                } else { 
                    Get-Location 
                }
                $ParametersPath = Join-Path $ScriptDir "endpoints-parameters.json"
            }
        }
        
        # Check if parameters file exists
        if (-not (Test-Path $ParametersPath)) {
            throw "Parameters file not found: $ParametersPath"
        }
        
        # Load and parse the JSON file
        $JsonContent = Get-Content -Path $ParametersPath -Raw -Encoding UTF8
        $AllParameters = $JsonContent | ConvertFrom-Json
        
        # Get the specified environment configuration
        if (-not $AllParameters.Environments.$Environment) {
            $AvailableEnvs = $AllParameters.Environments.PSObject.Properties.Name -join ", "
            throw "Environment '$Environment' not found. Available environments: $AvailableEnvs"
        }
        
        $EnvConfig = $AllParameters.Environments.$Environment
        
        # Create the result object with environment-specific settings
        $Result = [PSCustomObject]@{
            # Environment Configuration
            Environment = $Environment
            BaseUrl = $EnvConfig.BaseUrl
            Username = if ($IncludeCredentials) { $EnvConfig.Username } else { "" }
            ApiToken = if ($IncludeCredentials) { $EnvConfig.ApiToken } else { "" }
            ProjectKey = $EnvConfig.ProjectKey
            ProjectName = $EnvConfig.ProjectName
            
            # API Settings
            Timeout = $AllParameters.ApiSettings.Timeout
            RetryAttempts = $AllParameters.ApiSettings.RetryAttempts
            RetryDelaySeconds = $AllParameters.ApiSettings.RetryDelaySeconds
            BatchSize = $AllParameters.ApiSettings.BatchSize
            MaxResults = $AllParameters.ApiSettings.MaxResults
            
            # Output Settings
            LogLevel = $AllParameters.OutputSettings.LogLevel
            GenerateHtmlReport = $AllParameters.OutputSettings.GenerateHtmlReport
            GenerateCsvReport = $AllParameters.OutputSettings.GenerateCsvReport
            OpenReportInBrowser = $AllParameters.OutputSettings.OpenReportInBrowser
            OutputDirectory = $AllParameters.OutputSettings.OutputDirectory
            LogDirectory = $AllParameters.OutputSettings.LogDirectory
            IncludeTimestamp = $AllParameters.OutputSettings.IncludeTimestamp
            IncludeMetadata = $AllParameters.OutputSettings.IncludeMetadata
            
            # Authentication
            AuthMethod = $AllParameters.Authentication.AuthMethod
            IncludeCredentials = $AllParameters.Authentication.IncludeCredentials
            Headers = $AllParameters.Authentication.Headers
            
            # Common Parameters
            CommonParameters = $AllParameters.CommonParameters
            
            # Query Parameters
            DefaultExpand = $AllParameters.QueryParameters.DefaultExpand
            DefaultFields = $AllParameters.QueryParameters.DefaultFields
            DefaultMaxResults = $AllParameters.QueryParameters.DefaultMaxResults
            DefaultStartAt = $AllParameters.QueryParameters.DefaultStartAt
            
            # Mappings
            StatusMapping = $AllParameters.StatusMapping
            IssueTypeMapping = $AllParameters.IssueTypeMapping
            CustomFields = $AllParameters.CustomFields
            UserMapping = $AllParameters.UserMapping
            
            # Test Issues
            TestIssues = $AllParameters.TestIssues
            
            # Raw Parameters (for advanced usage)
            RawParameters = $AllParameters
        }
        
        return $Result
        
    } catch {
        Write-Error "Failed to load endpoint parameters: $($_.Exception.Message)"
        throw
    }
}

# =============================================================================
# HELPER FUNCTION: Get-AuthHeader
# =============================================================================
#
# DESCRIPTION: Creates a Basic Authentication header from parameters
#
# USAGE:
#   $Params = Get-EndpointParameters
#   $AuthHeader = Get-AuthHeader -Parameters $Params
#
# =============================================================================

function Get-AuthHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Parameters
    )
    
    try {
        if ($Parameters.AuthMethod -eq "Basic" -and $Parameters.IncludeCredentials) {
            $AuthString = $Parameters.Username + ":" + $Parameters.ApiToken
            $AuthBytes = [System.Text.Encoding]::ASCII.GetBytes($AuthString)
            $AuthHeader = "Basic " + [System.Convert]::ToBase64String($AuthBytes)
            return $AuthHeader
        } else {
            throw "Authentication method not supported or credentials not available"
        }
    } catch {
        Write-Error "Failed to create authentication header: $($_.Exception.Message)"
        throw
    }
}

# =============================================================================
# HELPER FUNCTION: Get-RequestHeaders
# =============================================================================
#
# DESCRIPTION: Creates request headers including authentication
#
# USAGE:
#   $Params = Get-EndpointParameters
#   $Headers = Get-RequestHeaders -Parameters $Params
#
# =============================================================================

function Get-RequestHeaders {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Parameters,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$AdditionalHeaders = @{}
    )
    
    try {
        $Headers = @{}
        
        # Add authentication header
        if ($Parameters.IncludeCredentials) {
            $Headers["Authorization"] = Get-AuthHeader -Parameters $Parameters
        }
        
        # Add default headers from parameters
        if ($Parameters.Headers) {
            foreach ($HeaderName in $Parameters.Headers.PSObject.Properties.Name) {
                $Headers[$HeaderName] = $Parameters.Headers.$HeaderName
            }
        }
        
        # Add any additional headers
        foreach ($HeaderName in $AdditionalHeaders.Keys) {
            $Headers[$HeaderName] = $AdditionalHeaders[$HeaderName]
        }
        
        return $Headers
        
    } catch {
        Write-Error "Failed to create request headers: $($_.Exception.Message)"
        throw
    }
}

# =============================================================================
# HELPER FUNCTION: Get-CsvPath
# =============================================================================
#
# DESCRIPTION: Generates a CSV output path with timestamp if enabled
#
# USAGE:
#   $Params = Get-EndpointParameters
#   $CsvPath = Get-CsvPath -Parameters $Params -FileName "MyData.csv"
#
# =============================================================================

function Get-CsvPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Parameters,
        
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputDirectory = ""
    )
    
    try {
        # Use provided directory or default from parameters
        if ([string]::IsNullOrEmpty($OutputDirectory)) {
            $OutputDirectory = if ($Parameters.OutputDirectory) { $Parameters.OutputDirectory } else { $PSScriptRoot }
        }
        
        # Ensure output directory exists
        if (-not (Test-Path $OutputDirectory)) {
            New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        }
        
        # Add timestamp if enabled
        if ($Parameters.IncludeTimestamp) {
            $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
            $Extension = [System.IO.Path]::GetExtension($FileName)
            $FileName = "$BaseName-$Timestamp$Extension"
        }
        
        return Join-Path $OutputDirectory $FileName
        
    } catch {
        Write-Error "Failed to generate CSV path: $($_.Exception.Message)"
        throw
    }
}

# Functions are now available for use in other scripts
