#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-fetch-environment-' + [guid]::NewGuid().ToString('N'))
$logRoot = Join-Path $projectRoot 'logs\jobagent'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
try {
    $inspectionPath = Join-Path $logRoot 'JA-027-fetch-error-inspection-20260908-153700.json'
    [pscustomobject]@{
        schema_version = 'jobagent/fetch-error-inspection/v1'
        by_error_class = @(
            [pscustomobject]@{
                error_class = 'TLS_HANDSHAKE_FAILED'
                fetch_count = 3
                candidate_count = 2
                sample_urls = @('https://alpha.example.invalid/', 'https://beta.example.invalid/')
                sample_details = @('The SSL connection could not be established')
                exception_types = @()
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inspectionPath -Encoding UTF8

    $fixturePath = Join-Path $projectRoot 'probe-fixture.json'
    [pscustomobject]@{
        results = @(
            [pscustomobject]@{
                url = 'https://alpha.example.invalid/'
                dotnet = [pscustomobject]@{
                    client = 'dotnet-invoke-webrequest'
                    ok = $false
                    status_code = $null
                    error = 'The SSL connection could not be established'
                    error_detail = 'The SSL connection could not be established'
                    exception_types = @('System.Net.Http.HttpRequestException')
                }
                curl = [pscustomobject]@{
                    client = 'curl.exe'
                    ok = $true
                    status_code = 200
                    error = $null
                    error_detail = $null
                    exception_types = @()
                }
                wsl_curl = [pscustomobject]@{
                    client = 'wsl-curl'
                    ok = $false
                    status_code = $null
                    error = 'not needed'
                    error_detail = 'not needed'
                    exception_types = @()
                }
            },
            [pscustomobject]@{
                url = 'https://beta.example.invalid/'
                dotnet = [pscustomobject]@{
                    client = 'dotnet-invoke-webrequest'
                    ok = $false
                    status_code = $null
                    error = 'The SSL connection could not be established'
                    error_detail = 'The SSL connection could not be established'
                    exception_types = @('System.Net.Http.HttpRequestException')
                }
                curl = [pscustomobject]@{
                    client = 'curl.exe'
                    ok = $false
                    status_code = $null
                    error = 'Could not resolve host'
                    error_detail = 'Could not resolve host'
                    exception_types = @()
                }
                wsl_curl = [pscustomobject]@{
                    client = 'wsl-curl'
                    ok = $false
                    status_code = $null
                    error = 'Could not resolve host'
                    error_detail = 'Could not resolve host'
                    exception_types = @()
                }
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

    $outputPath = Join-Path $logRoot 'JA-027-fetch-environment-test.json'
    $output = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Test-JobAgentFetchEnvironment.ps1') -ProjectRoot $projectRoot -InspectionPath $inspectionPath -FixturePath $fixturePath -OutputPath $outputPath -MaxUrls 2 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Environment-Probe ist fehlgeschlagen: " + ($output -join "`n"))
    Assert-True -Condition (Test-Path -LiteralPath $outputPath -PathType Leaf) -Message 'Fetch-Environment-Probe schreibt kein Evidence-Log.'
    $result = ($output -join "`n") | ConvertFrom-Json -Depth 30

    Assert-True -Condition ($result.schema_version -eq 'jobagent/fetch-environment-probe/v1') -Message 'Fetch-Environment-Probe schreibt falsche Schema-Version.'
    Assert-True -Condition ($result.probed_url_count -eq 2) -Message 'Fetch-Environment-Probe nutzt die erwarteten TLS-Beispiel-URLs nicht.'
    Assert-True -Condition ($result.status -eq 'dotnet_fetch_fails_but_curl_succeeds') -Message 'Fetch-Environment-Probe unterscheidet DotNet- und Curl-Erreichbarkeit nicht.'
    Assert-True -Condition (@($result.results | Where-Object { $_.url -eq 'https://alpha.example.invalid/' -and $_.dotnet.ok -eq $false -and $_.curl.ok -eq $true }).Count -eq 1) -Message 'Fetch-Environment-Probe verliert Client-spezifische Ergebnisse.'

    [pscustomobject]@{
        results = @(
            [pscustomobject]@{
                url = 'https://alpha.example.invalid/'
                dotnet = [pscustomobject]@{ client = 'dotnet-invoke-webrequest'; ok = $false; status_code = $null; error = 'SEC_E_NO_CREDENTIALS'; error_detail = 'SEC_E_NO_CREDENTIALS'; exception_types = @('System.Net.Http.HttpRequestException') }
                curl = [pscustomobject]@{ client = 'curl.exe'; ok = $false; status_code = $null; error = 'SEC_E_NO_CREDENTIALS'; error_detail = 'SEC_E_NO_CREDENTIALS'; exception_types = @() }
                wsl_curl = [pscustomobject]@{ client = 'wsl-curl'; ok = $true; status_code = 200; error = $null; error_detail = $null; exception_types = @() }
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

    $wslOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Test-JobAgentFetchEnvironment.ps1') -ProjectRoot $projectRoot -InspectionPath $inspectionPath -FixturePath $fixturePath -OutputPath $outputPath -MaxUrls 1 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Environment-Probe-WSL ist fehlgeschlagen: " + ($wslOutput -join "`n"))
    $wslResult = ($wslOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert-True -Condition ($wslResult.status -eq 'schannel_fetch_fails_but_wsl_curl_succeeds') -Message 'Fetch-Environment-Probe erkennt WSL-Curl als kontrollierten Schannel-Fallback nicht.'
    Assert-True -Condition (@($wslResult.results | Where-Object { $_.wsl_curl.ok -eq $true -and $_.curl.ok -eq $false }).Count -eq 1) -Message 'Fetch-Environment-Probe verliert WSL-Curl-Ergebnisse.'

    [pscustomobject]@{
        results = @(
            [pscustomobject]@{
                url = 'https://alpha.example.invalid/'
                dotnet = [pscustomobject]@{ client = 'dotnet-invoke-webrequest'; ok = $true; status_code = 200; error = $null; error_detail = $null; exception_types = @() }
                curl = [pscustomobject]@{ client = 'curl.exe'; ok = $true; status_code = 200; error = $null; error_detail = $null; exception_types = @() }
                wsl_curl = [pscustomobject]@{ client = 'wsl-curl'; ok = $true; status_code = 200; error = $null; error_detail = $null; exception_types = @() }
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $fixturePath -Encoding UTF8

    $successOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Test-JobAgentFetchEnvironment.ps1') -ProjectRoot $projectRoot -InspectionPath $inspectionPath -FixturePath $fixturePath -OutputPath $outputPath -MaxUrls 1 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Environment-Probe-Success ist fehlgeschlagen: " + ($successOutput -join "`n"))
    $successResult = ($successOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert-True -Condition ($successResult.status -eq 'dotnet_fetch_available') -Message 'Fetch-Environment-Probe erkennt wiederhergestellten DotNet-Fetchpfad nicht.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

Write-Host 'OK Test-JobAgentFetchEnvironment'
