# Identify 400 Bad Request Endpoints
$endpointsDir = ".endpoints"
$badRequestEndpoints = @()

Write-Host "Identifying 400 Bad Request endpoints..." -ForegroundColor Green

# Get all PowerShell files that are GET operations
$getScripts = Get-ChildItem -Path $endpointsDir -Recurse -Filter "*.ps1" | Where-Object { 
    $_.Name -match "GET.*\.ps1$" -and $_.Name -notmatch "OAuth2" 
}

foreach ($script in $getScripts) {
    try {
        $scriptContent = Get-Content -Path $script.FullName -Raw
        
        # Extract the API endpoint from the script
        if ($scriptContent -match 'Uri.*\$BaseUrl/rest/api/3/([^"?]+)') {
            $apiPath = $matches[1]
            $fullEndpoint = "/rest/api/3/$apiPath"
            
            # Test the endpoint with a simple call
            $testUrl = "https://onemain.atlassian.net$fullEndpoint?maxResults=1"
            
            try {
                $response = Invoke-RestMethod -Uri $testUrl -Method GET -Headers @{
                    "Authorization" = "Basic YmVuLmtyZWlzY2hlci5jZUBvbWYuY29tOkFUQVRUM3hGZkdGMEFHdjZYQjc1bVJha1dBaldzbmowTi1PMEVnZUtISzJBNjNHUG8zWkZuSFdRYTZ3Y1loTjZHTWhQdmN0djI3SjlJdmhqMGQzcjVJQ1B1MHB6OUtRZlJIakkxOUFXWTFNS3ZUcnl2eklZY1lnalVIZ2stZ3F0RlhtRTljbFdGenJNeXhDLVhPM0lDb1NzU2o1TVE5T0pmQzFsYXJQa0JROTFpSFdrZ0U1VWJIaz02NDFCOTU3MA=="
                    "Accept" = "application/json"
                } -ErrorAction Stop
                
                Write-Host "✅ $($script.Name) - $fullEndpoint" -ForegroundColor Green
                
            } catch {
                if ($_.Exception.Response.StatusCode -eq 400) {
                    Write-Host "❌ $($script.Name) - $fullEndpoint (400 Bad Request)" -ForegroundColor Red
                    $badRequestEndpoints += @{
                        "Script" = $script.Name
                        "Endpoint" = $fullEndpoint
                        "API_Path" = $apiPath
                    }
                } elseif ($_.Exception.Response.StatusCode -eq 404) {
                    Write-Host "⚠️  $($script.Name) - $fullEndpoint (404 Not Found)" -ForegroundColor Yellow
                } elseif ($_.Exception.Response.StatusCode -eq 405) {
                    Write-Host "⚠️  $($script.Name) - $fullEndpoint (405 Method Not Allowed)" -ForegroundColor Yellow
                } elseif ($_.Exception.Response.StatusCode -eq 403) {
                    Write-Host "⚠️  $($script.Name) - $fullEndpoint (403 Forbidden)" -ForegroundColor Yellow
                } else {
                    Write-Host "❓ $($script.Name) - $fullEndpoint ($($_.Exception.Response.StatusCode))" -ForegroundColor Gray
                }
            }
        }
    } catch {
        Write-Host "Error processing $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}
        }
    } catch {
        Write-Host "Error processing $($script.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== 400 BAD REQUEST ENDPOINTS ===" -ForegroundColor Red
Write-Host "These endpoints need specific parameters:" -ForegroundColor Yellow

foreach ($endpoint in $badRequestEndpoints) {
    Write-Host "`n📋 $($endpoint.Script)" -ForegroundColor Cyan
    Write-Host "   Endpoint: $($endpoint.Endpoint)" -ForegroundColor White
    Write-Host "   API Path: $($endpoint.API_Path)" -ForegroundColor Gray
}

Write-Host "`nTotal 400 Bad Request endpoints: $($badRequestEndpoints.Count)" -ForegroundColor Red
