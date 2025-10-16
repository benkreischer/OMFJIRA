param(
    [string]$JiraBase = $env:JIRA_BASE,
    [string]$JiraEmail = $env:JIRA_EMAIL,
    [string]$JiraApiToken = $env:JIRA_API_TOKEN
)

function Prompt-IfMissing {
    param($Name, [string]$Current)
    if (-not $Current) {
        Write-Host "$Name is not set. Please enter it (input hidden for tokens):"
        if ($Name -like "*TOKEN") {
            $Current = Read-Host -AsSecureString "Enter $Name"
            $Current = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Current))
        } else {
            $Current = Read-Host "Enter $Name"
        }
    }
    return $Current
}

$JiraBase = Prompt-IfMissing -Name "JIRA_BASE (like https://yourorg.atlassian.net)" -Current $JiraBase
$JiraEmail = Prompt-IfMissing -Name "JIRA_EMAIL (your Atlassian account email)" -Current $JiraEmail
$JiraApiToken = Prompt-IfMissing -Name "JIRA_API_TOKEN" -Current $JiraApiToken

if ($JiraBase -match "^https?://") {
    # ok
} else {
    $JiraBase = "https://$JiraBase"
}

$Auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$JiraEmail`:$JiraApiToken"))
$Headers = @{ Authorization = "Basic $Auth"; Accept = 'application/json' }

$ProjectsUrl = "$JiraBase/rest/api/3/project/search"
try {
    $resp = Invoke-RestMethod -Method Get -Uri $ProjectsUrl -Headers $Headers -ErrorAction Stop
    if ($resp.values) {
        Write-Host "Found projects:`n"
        foreach ($p in $resp.values) {
            Write-Host "- $($p.key): $($p.name) ($($p.id))"
        }
    } else {
        Write-Host ($resp | ConvertTo-Json -Depth 5)
    }
} catch {
    Write-Error "Request failed: $($_.Exception.Message)"
    if ($_.InvocationInfo) { Write-Error $_.InvocationInfo.Line }
}
