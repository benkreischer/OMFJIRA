# Create missing endpoints for empty folders based on Jira REST API v3 documentation
Write-Host "Creating missing endpoints for empty folders..." -ForegroundColor Green

# Define missing endpoints based on Jira REST API v3 documentation
$MissingEndpoints = @{
    "App migration" = @(
        @{
            Name = "App Migration - GET App Properties"
            Endpoint = "/rest/api/3/app/properties"
            Description = "Returns the properties of all apps installed on the instance."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-app-migration/"
        }
    )

    "Issue bulk operations" = @(
        @{
            Name = "Issue Bulk Operations - GET Bulk Issue Operation Status"
            Endpoint = "/rest/api/3/task/{taskId}"
            Description = "Returns the status of a bulk operation task."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-bulk-operations/"
            RequiresParam = $true
            ParamName = "TaskId"
        }
    )

    "Issue custom field contexts" = @(
        @{
            Name = "Issue Custom Field Contexts - GET Contexts for Field"
            Endpoint = "/rest/api/3/field/{fieldId}/context"
            Description = "Returns contexts for a custom field."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-contexts/"
            RequiresParam = $true
            ParamName = "FieldId"
        }
    )

    "Issue custom field options" = @(
        @{
            Name = "Issue Custom Field Options - GET Options for Context"
            Endpoint = "/rest/api/3/field/{fieldId}/context/{contextId}/option"
            Description = "Returns the options for a context."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-custom-field-options/"
            RequiresParam = $true
            ParamName = "FieldId"
        }
    )

    "Jira expressions" = @(
        @{
            Name = "Jira Expressions - GET Expression Analysis"
            Endpoint = "/rest/api/3/expression/analyse"
            Description = "Parses and evaluates Jira expressions."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-jira-expressions/"
        }
    )

    "Workflow status categories" = @(
        @{
            Name = "Workflow Status Categories - GET Status Categories"
            Endpoint = "/rest/api/3/statuscategory"
            Description = "Returns a list of all status categories."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-status-categories/"
        },
        @{
            Name = "Workflow Status Categories - GET Status Category"
            Endpoint = "/rest/api/3/statuscategory/{idOrKey}"
            Description = "Returns a status category."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-status-categories/"
            RequiresParam = $true
            ParamName = "CategoryId"
        }
    )

    "Workflow statuses" = @(
        @{
            Name = "Workflow Statuses - GET Statuses"
            Endpoint = "/rest/api/3/status"
            Description = "Returns a list of the statuses specified by one or more status IDs."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-statuses/"
        },
        @{
            Name = "Workflow Statuses - GET Status"
            Endpoint = "/rest/api/3/status/{idOrName}"
            Description = "Returns a status."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-statuses/"
            RequiresParam = $true
            ParamName = "StatusId"
        }
    )

    "Workflow schemes" = @(
        @{
            Name = "Workflow Schemes - GET Workflow Schemes"
            Endpoint = "/rest/api/3/workflowscheme"
            Description = "Returns a paginated list of workflow schemes."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-schemes/"
        },
        @{
            Name = "Workflow Schemes - GET Workflow Scheme"
            Endpoint = "/rest/api/3/workflowscheme/{id}"
            Description = "Returns a workflow scheme."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-workflow-schemes/"
            RequiresParam = $true
            ParamName = "SchemeId"
        }
    )

    "Webhooks" = @(
        @{
            Name = "Webhooks - GET Webhooks"
            Endpoint = "/rest/api/3/webhook"
            Description = "Returns a paginated list of the webhooks registered by the calling app."
            ApiDoc = "https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-webhooks/"
        }
    )
}

# Base template for PowerShell files
$Ps1Template = @'
# =============================================================================
# ENDPOINT: {0}
# =============================================================================
#
# API DOCUMENTATION: {1}
#
# DESCRIPTION: {2}
#
# SETUP:
# 1. Run this script to generate CSV data
# 2. Load the data
#
# =============================================================================

# =============================================================================
# AUTHENTICATION
# =============================================================================
$BaseUrl = "https://onemain.atlassian.net"
$Username = "ben.kreischer.ce@omf.com"
$ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE"
$AuthHeader = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$ApiToken"))
    "Accept" = "application/json"
}

{3}

# =============================================================================
# API CALL
# =============================================================================
$Endpoint = "{4}"
$FullUrl = $BaseUrl + $Endpoint

try {
    Write-Output "Calling API endpoint: $FullUrl"
    $Response = Invoke-RestMethod -Uri $FullUrl -Headers $AuthHeader -Method Get

    Write-Output "API call successful. Processing response..."

    # =============================================================================
    # DATA TRANSFORMATION
    # =============================================================================
    $Result = @()

    if ($Response) {
        # Handle different response structures
        if ($Response -is [Array]) {
            # Response is already an array
            foreach ($item in $Response) {
                $Result += $item
            }
        } elseif ($Response.values) {
            # Response has paginated structure with 'values' property
            $Result += $Response.values
        } elseif ($Response.PSObject.Properties.Count -gt 0) {
            # Response is a single object
            $Result += $Response
        } else {
            # Empty or unexpected response
            $Result += [PSCustomObject]@{
                Message = "No data returned"
                GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } else {
        # No response data
        $Result += [PSCustomObject]@{
            Message = "No data returned"
            GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
    }

    # =============================================================================
    # EXPORT TO CSV
    # =============================================================================
    $OutputFile = "{5}.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "CSV file generated successfully: $(Get-Location)\$OutputFile"
    Write-Output "Records exported: $($Result.Count)"

    # Show sample data
    if ($Result.Count -gt 0) {
        Write-Output "`nSample data:"
        $Result | Select-Object -First 3 | Format-Table -AutoSize
    }

} catch {
    Write-Output "Failed to retrieve data: $($_.Exception.Message)"
    # Create empty record for failed endpoint
    $EmptyData = [PSCustomObject]@{
        Error = $_.Exception.Message
        GeneratedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    $Result = @($EmptyData)

    # Export error CSV
    $OutputFile = "{5}.csv"
    $Result | Export-Csv -Path $OutputFile -NoTypeInformation -Force

    Write-Output "Created error CSV: $OutputFile"
    exit 1
}
'@

# Base template for PowerQuery files
$PqTemplate = @'
// =============================================================================
// ENDPOINT: {0}
// =============================================================================
//
// API DOCUMENTATION: {1}
//
// DESCRIPTION: {2}
//
// SETUP:
// 1. Copy this code into Excel Power Query (Data > Get Data > From Other Sources > Blank Query)
//
// =============================================================================

let
    // =============================================================================
    // AUTHENTICATION
    // =============================================================================
    BaseUrl = "https://onemain.atlassian.net",
    Username = "ben.kreischer.ce@omf.com",
    ApiToken = "ATATT3xFfGF0CUZOrKauSx0nmoC7tn0ss2elEWUyR0Ubu35YzQSt99NNMI4FoE0wta2sKSsVLRq4Gn1knGCVRL5e8YAeGVBUFCliwyNEmhfUxD6DtLKpLDNrKOdMawuYrJ3bbFkINiorVs9A33AJdlTJS7vf5YN2iV1SgZFxLCd5cwGBYEbWtn8=95F9C3DE",
    AuthHeader = "Basic " & Binary.ToText(Text.ToBinary(Username & ":" & ApiToken), BinaryEncoding.Base64),

    {3}

    // =============================================================================
    // API CALL
    // =============================================================================
    Endpoint = "{4}",
    FullUrl = BaseUrl & Endpoint,

    Response = Json.Document(Web.Contents(FullUrl, [Headers=[#"Authorization"=AuthHeader, #"Content-Type"="application/json"]])),

    // =============================================================================
    // DATA TRANSFORMATION
    // =============================================================================
    #"Converted to Table" = if Response is list then
        Table.FromList(Response, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    else if Record.HasFields(Response, "values") then
        Table.FromList(Response[values], Splitter.SplitByNothing(), null, null, ExtraValues.Error)
    else
        Table.FromRecords({{Response}})

in
    #"Converted to Table"
'@

$createdEndpoints = 0
$totalEndpoints = 0

# Create endpoints for each folder
foreach ($folderName in $MissingEndpoints.Keys) {
    $endpoints = $MissingEndpoints[$folderName]

    Write-Host "Creating endpoints for folder: $folderName" -ForegroundColor Yellow

    foreach ($endpoint in $endpoints) {
        $totalEndpoints++

        # Prepare parameter section if needed
        $parameterSection = ""
        $pqParameterSection = ""
        $endpointPath = $endpoint.Endpoint

        if ($endpoint.RequiresParam) {
            # Use existing parameters from tracking document
            switch ($endpoint.ParamName) {
                "FieldId" {
                    $paramValue = "statusCategory"
                    $endpointPath = $endpoint.Endpoint -replace '\{fieldId\}', $paramValue
                }
                "TaskId" {
                    $paramValue = "12345"
                    $endpointPath = $endpoint.Endpoint -replace '\{taskId\}', $paramValue
                }
                "CategoryId" {
                    $paramValue = "1"
                    $endpointPath = $endpoint.Endpoint -replace '\{idOrKey\}', $paramValue
                }
                "StatusId" {
                    $paramValue = "1"
                    $endpointPath = $endpoint.Endpoint -replace '\{idOrName\}', $paramValue
                }
                "SchemeId" {
                    $paramValue = "1"
                    $endpointPath = $endpoint.Endpoint -replace '\{id\}', $paramValue
                }
                default {
                    $paramValue = "1"
                    $endpointPath = $endpoint.Endpoint -replace '\{[^}]+\}', $paramValue
                }
            }

            $parameterSection = @"

# =============================================================================
# PARAMETER - REQUIRED
# =============================================================================
`$$($endpoint.ParamName) = "$paramValue" # <-- IMPORTANT: Replace with valid $($endpoint.ParamName)

"@

            $pqParameterSection = @"

    // =============================================================================
    // PARAMETER - REQUIRED
    // =============================================================================
    $($endpoint.ParamName) = "$paramValue", // <-- IMPORTANT: Replace with valid $($endpoint.ParamName)
"@
        }

        # Generate file names
        $fileName = $endpoint.Name -replace ' - GET ', ' - GET ' -replace ' - ', ' - '
        $safeFileName = $fileName + " - Anon - Official"

        try {
            # Create PowerShell file
            $ps1Content = $Ps1Template -f $endpoint.Name, $endpoint.ApiDoc, $endpoint.Description, $parameterSection, $endpointPath, $safeFileName
            $ps1Path = Join-Path ".endpoints" $folderName ($safeFileName + ".ps1")
            Set-Content -Path $ps1Path -Value $ps1Content -Encoding UTF8

            # Create PowerQuery file
            $pqContent = $PqTemplate -f $endpoint.Name, $endpoint.ApiDoc, $endpoint.Description, $pqParameterSection, $endpointPath
            $pqPath = Join-Path ".endpoints" $folderName ($safeFileName + ".pq")
            Set-Content -Path $pqPath -Value $pqContent -Encoding UTF8

            Write-Host "  ✅ Created: $safeFileName" -ForegroundColor Green
            $createdEndpoints++

        } catch {
            Write-Warning "  ❌ Failed to create $($endpoint.Name): $($_.Exception.Message)"
        }
    }
}

Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Total endpoints processed: $totalEndpoints"
Write-Host "Successfully created: $createdEndpoints" -ForegroundColor Green
Write-Host "Ready to test new endpoints!" -ForegroundColor Yellow