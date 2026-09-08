#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$InspectionPath = '',
    [Parameter()][string]$OutputPath = '',
    [Parameter()][string]$FixturePath = '',
    [Parameter()][ValidateRange(1, 20)][int]$MaxUrls = 5,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRootPath = [IO.Path]::GetFullPath($ProjectRoot)
$inspectionFilePath = if ([string]::IsNullOrWhiteSpace($InspectionPath)) {
    $candidates = @(Get-ChildItem -LiteralPath (Join-Path $projectRootPath 'logs/jobagent') -Filter 'JA-027-fetch-error-inspection-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1)
    if ($candidates.Count -eq 0) {
        throw 'Kein Fetch-Error-Inspection-Log gefunden. Fuehre zuerst tools/Inspect-JobAgentFetchErrors.ps1 aus oder uebergib -InspectionPath.'
    }
    $candidates[0].FullName
}
elseif ([IO.Path]::IsPathRooted($InspectionPath)) {
    [IO.Path]::GetFullPath($InspectionPath)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRootPath $InspectionPath))
}

$outputFilePath = if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $stamp = [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
    Join-Path $projectRootPath ("logs/jobagent/JA-027-fetch-environment-$stamp.json")
}
elseif ([IO.Path]::IsPathRooted($OutputPath)) {
    [IO.Path]::GetFullPath($OutputPath)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRootPath $OutputPath))
}

function Read-ToolJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
}

function Get-ToolInspectionSampleUrls {
    param(
        [Parameter(Mandatory)][object]$Inspection,
        [Parameter(Mandatory)][int]$Limit
    )

    $urls = New-Object System.Collections.Generic.List[string]
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($class in @('TLS_CREDENTIAL_UNAVAILABLE', 'TLS_HANDSHAKE_FAILED')) {
        foreach ($entry in @($Inspection.by_error_class | Where-Object { [string]$_.error_class -eq $class })) {
            foreach ($url in @($entry.sample_urls)) {
                $value = ([string]$url).Trim()
                if ([string]::IsNullOrWhiteSpace($value) -or -not [Uri]::IsWellFormedUriString($value, [UriKind]::Absolute)) {
                    continue
                }
                if ($seen.Add($value)) {
                    $urls.Add($value)
                    if ($urls.Count -ge $Limit) {
                        return $urls.ToArray()
                    }
                }
            }
        }
    }
    return $urls.ToArray()
}

function Get-ToolExceptionMessages {
    param([Parameter(Mandatory)][Exception]$Exception)

    $messages = New-Object System.Collections.Generic.List[string]
    $types = New-Object System.Collections.Generic.List[string]
    $current = $Exception
    while ($null -ne $current) {
        $types.Add($current.GetType().FullName)
        if (-not [string]::IsNullOrWhiteSpace($current.Message)) {
            $messages.Add($current.Message)
        }
        $current = $current.InnerException
    }
    [pscustomobject]@{
        message = $Exception.Message
        detail = ($messages.ToArray() -join ' | ')
        exception_types = @($types.ToArray())
    }
}

function Invoke-ToolDotNetProbe {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][int]$Timeout
    )

    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -Method Head -TimeoutSec $Timeout -MaximumRedirection 0 -SkipHttpErrorCheck -ErrorAction Stop
        return [pscustomobject]@{
            client = 'dotnet-invoke-webrequest'
            ok = $true
            status_code = [int]$response.StatusCode
            error = $null
            error_detail = $null
            exception_types = @()
        }
    }
    catch {
        $diagnostic = Get-ToolExceptionMessages -Exception $_.Exception
        return [pscustomobject]@{
            client = 'dotnet-invoke-webrequest'
            ok = $false
            status_code = $null
            error = [string]$diagnostic.message
            error_detail = [string]$diagnostic.detail
            exception_types = @($diagnostic.exception_types)
        }
    }
}

function Invoke-ToolCurlProbe {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][int]$Timeout
    )

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($null -eq $curl) {
        return [pscustomobject]@{
            client = 'curl.exe'
            ok = $false
            status_code = $null
            error = 'curl.exe nicht gefunden'
            error_detail = 'curl.exe nicht gefunden'
            exception_types = @()
        }
    }

    $output = @(& $curl.Source --head --location --max-time $Timeout --silent --show-error --write-out "`nJOBAGENT_STATUS:%{http_code}" $Url 2>&1)
    $exit = $LASTEXITCODE
    $statusLine = @($output | Where-Object { [string]$_ -like 'JOBAGENT_STATUS:*' } | Select-Object -Last 1)
    $statusCode = if ($statusLine.Count -gt 0) {
        $parsed = 0
        if ([int]::TryParse(([string]$statusLine[0]).Substring(16), [ref]$parsed) -and $parsed -gt 0) { $parsed } else { $null }
    }
    else {
        $null
    }

    [pscustomobject]@{
        client = 'curl.exe'
        ok = ($exit -eq 0 -and $null -ne $statusCode -and $statusCode -ge 100)
        status_code = $statusCode
        error = if ($exit -eq 0) { $null } else { ($output -join "`n") }
        error_detail = if ($exit -eq 0) { $null } else { ($output -join "`n") }
        exception_types = @()
    }
}

function Invoke-ToolWslCurlProbe {
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][int]$Timeout,
        [Parameter()][string]$Distribution = 'Ubuntu-22.04'
    )

    if ($null -eq (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            client = 'wsl-curl'
            ok = $false
            status_code = $null
            error = 'wsl.exe nicht gefunden'
            error_detail = 'wsl.exe nicht gefunden'
            exception_types = @()
        }
    }

    $output = @(& wsl.exe -d $Distribution -- curl -I -L --max-time $Timeout -sS -w "JOBAGENT_STATUS:%{http_code}`n" $Url 2>&1)
    $exit = $LASTEXITCODE
    $statusLine = @($output | Where-Object { [string]$_ -like 'JOBAGENT_STATUS:*' } | Select-Object -Last 1)
    $statusCode = if ($statusLine.Count -gt 0) {
        $parsed = 0
        if ([int]::TryParse(([string]$statusLine[0]).Substring(16), [ref]$parsed) -and $parsed -gt 0) { $parsed } else { $null }
    }
    else {
        $null
    }

    [pscustomobject]@{
        client = 'wsl-curl'
        ok = ($exit -eq 0 -and $null -ne $statusCode -and $statusCode -ge 100)
        status_code = $statusCode
        error = if ($exit -eq 0) { $null } else { ($output -join "`n") }
        error_detail = if ($exit -eq 0) { $null } else { ($output -join "`n") }
        exception_types = @()
    }
}

function Resolve-ToolEnvironmentStatus {
    param([Parameter(Mandatory)][object[]]$Results)

    $dotNet = @($Results | Where-Object { $_.dotnet.ok -eq $true })
    $curl = @($Results | Where-Object { $_.curl.ok -eq $true })
    $wslCurl = @($Results | Where-Object { ($_.PSObject.Properties.Name -contains 'wsl_curl') -and $_.wsl_curl.ok -eq $true })
    if ($dotNet.Count -gt 0) {
        return 'dotnet_fetch_available'
    }
    if ($curl.Count -gt 0) {
        return 'dotnet_fetch_fails_but_curl_succeeds'
    }
    if ($wslCurl.Count -gt 0) {
        return 'schannel_fetch_fails_but_wsl_curl_succeeds'
    }
    return 'all_probe_clients_failed'
}

$inspection = Read-ToolJsonFile -Path $inspectionFilePath
[object[]]$urls = @(Get-ToolInspectionSampleUrls -Inspection $inspection -Limit $MaxUrls)
if ($urls.Count -eq 0) {
    throw 'Inspection-Log enthaelt keine TLS-Beispiel-URLs.'
}

$fixture = if ([string]::IsNullOrWhiteSpace($FixturePath)) {
    $null
}
else {
    $fixturePathFull = if ([IO.Path]::IsPathRooted($FixturePath)) { [IO.Path]::GetFullPath($FixturePath) } else { [IO.Path]::GetFullPath((Join-Path $projectRootPath $FixturePath)) }
    Read-ToolJsonFile -Path $fixturePathFull
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($url in $urls) {
    if ($null -ne $fixture) {
        $row = @($fixture.results | Where-Object { [string]$_.url -eq [string]$url } | Select-Object -First 1)
        if ($row.Count -eq 0) {
            throw "Fixture enthaelt keine Probe fuer URL: $url"
        }
        $results.Add([pscustomobject]@{
                url = [string]$url
                dotnet = $row[0].dotnet
                curl = $row[0].curl
                wsl_curl = if ($row[0].PSObject.Properties.Name -contains 'wsl_curl') { $row[0].wsl_curl } else { [pscustomobject]@{ client = 'wsl-curl'; ok = $false; status_code = $null; error = 'fixture missing wsl_curl'; error_detail = 'fixture missing wsl_curl'; exception_types = @() } }
            })
        continue
    }

    $results.Add([pscustomobject]@{
            url = [string]$url
            dotnet = Invoke-ToolDotNetProbe -Url ([string]$url) -Timeout $TimeoutSeconds
            curl = Invoke-ToolCurlProbe -Url ([string]$url) -Timeout $TimeoutSeconds
            wsl_curl = Invoke-ToolWslCurlProbe -Url ([string]$url) -Timeout $TimeoutSeconds
        })
}

$status = Resolve-ToolEnvironmentStatus -Results @($results.ToArray())
$nextAction = switch ($status) {
    'dotnet_fetch_available' { 'JA-027-Retry erneut laufen lassen; TLS ist fuer mindestens eine Beispiel-URL im produktiven Fetch-Client erreichbar.' }
    'dotnet_fetch_fails_but_curl_succeeds' { 'JA-027-Retry mit Auto-Fallback auf curl.exe erneut laufen lassen; externe Erreichbarkeit ist fuer mindestens eine Beispiel-URL belegt.' }
    'schannel_fetch_fails_but_wsl_curl_succeeds' { 'JA-027-Retry mit Auto-Fallback auf WSL-Curl erneut laufen lassen; externe Erreichbarkeit ist belegt und Schannel bleibt lokal fehlerhaft.' }
    default { 'Netzwerk/TLS ausserhalb des Projekts klaeren, bevor Retrykandidaten erneut verbraucht werden.' }
}

$document = [pscustomobject]@{
    schema_version = 'jobagent/fetch-environment-probe/v1'
    generated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    inspection_path = $inspectionFilePath
    probed_url_count = $results.Count
    status = $status
    next_action = $nextAction
    results = @($results.ToArray())
}

$outputDirectory = Split-Path -Parent $outputFilePath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
$document | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outputFilePath -Encoding UTF8
$document | ConvertTo-Json -Depth 30
