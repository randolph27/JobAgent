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

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-fetch-error-inspection-' + [guid]::NewGuid().ToString('N'))
$logRoot = Join-Path $projectRoot 'logs\jobagent'
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null
try {
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification/v1'
        run_id = '20260908-120000'
        fetch_error_summary = [pscustomobject]@{
            schema_version = 'jobagent/fetch-error-summary/v1'
            failed_fetch_total = 3
            error_class_total = 2
            by_error_class = @(
                [pscustomobject]@{
                    error_class = 'TLS_CREDENTIAL_UNAVAILABLE'
                    fetch_count = 2
                    candidate_count = 2
                    sample_urls = @('https://alpha.example.invalid/', 'https://beta.example.invalid/')
                    sample_details = @('SEC_E_NO_CREDENTIALS')
                    exception_types = @('System.Net.Http.HttpRequestException')
                },
                [pscustomobject]@{
                    error_class = 'HTTP_STATUS'
                    fetch_count = 1
                    candidate_count = 1
                    sample_urls = @('https://gamma.example.invalid/')
                    sample_details = @('HTTP 503')
                    exception_types = @()
                }
            )
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $logRoot 'JA-027-batch-20260908-120000.json') -Encoding UTF8

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-website-discovery/v1'
        run_id = '20260908-121000'
        fetch_error_summary = [pscustomobject]@{
            schema_version = 'jobagent/fetch-error-summary/v1'
            failed_fetch_total = 1
            error_class_total = 1
            by_error_class = @(
                [pscustomobject]@{
                    error_class = 'TLS_CREDENTIAL_UNAVAILABLE'
                    fetch_count = 1
                    candidate_count = 1
                    sample_urls = @('https://alpha.example.invalid/')
                    sample_details = @('SEC_E_NO_CREDENTIALS')
                    exception_types = @('System.Security.Authentication.AuthenticationException')
                }
            )
        }
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $logRoot 'company-candidate-website-discovery-20260908-121000.json') -Encoding UTF8

    $output = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Inspect-JobAgentFetchErrors.ps1') -ProjectRoot $projectRoot -DominancePercent 60 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Error-Inspection ist fehlgeschlagen: " + ($output -join "`n"))
    $result = ($output -join "`n") | ConvertFrom-Json -Depth 30

    Assert-True -Condition ($result.schema_version -eq 'jobagent/fetch-error-inspection/v1') -Message 'Inspection schreibt falsche Schema-Version.'
    Assert-True -Condition ($result.inspected_file_count -eq 2) -Message 'Inspection beruecksichtigt nicht beide Logtypen.'
    Assert-True -Condition ($result.failed_fetch_total -eq 4) -Message 'Inspection aggregiert failed_fetch_total falsch.'
    Assert-True -Condition ($result.dominant_error_class -eq 'TLS_CREDENTIAL_UNAVAILABLE') -Message 'Inspection erkennt dominante TLS-Fehlerklasse nicht.'
    Assert-True -Condition ($result.status -eq 'environment_tls_check_required') -Message 'Inspection leitet aus dominanten TLS-Credentials keinen Environment-Check ab.'
    Assert-True -Condition (@($result.by_error_class | Where-Object { $_.error_class -eq 'TLS_CREDENTIAL_UNAVAILABLE' -and $_.fetch_count -eq 3 -and $_.candidate_count -eq 3 }).Count -eq 1) -Message 'Inspection aggregiert TLS-Fehler ueber Laeufe falsch.'
    Assert-True -Condition (@($result.by_error_class | Where-Object { $_.error_class -eq 'TLS_CREDENTIAL_UNAVAILABLE' -and @($_.sample_urls | Where-Object { $_ -eq 'https://alpha.example.invalid/' }).Count -eq 1 }).Count -eq 1) -Message 'Inspection dedupliziert Beispiel-URLs nicht korrekt.'
    Assert-True -Condition (@($result.by_error_class | Where-Object { $_.error_class -eq 'TLS_CREDENTIAL_UNAVAILABLE' -and @($_.exception_types | Where-Object { $_ -eq 'System.Security.Authentication.AuthenticationException' }).Count -eq 1 }).Count -eq 1) -Message 'Inspection erhaelt Exception-Typen aus Website-Discovery nicht.'
    Assert-True -Condition (@($result.runs | Where-Object { $_.kind -eq 'candidate_verification' }).Count -eq 1) -Message 'Inspection klassifiziert Candidate-Batch nicht.'
    Assert-True -Condition (@($result.runs | Where-Object { $_.kind -eq 'website_discovery' }).Count -eq 1) -Message 'Inspection klassifiziert Website-Discovery nicht.'

    Remove-Item -LiteralPath (Join-Path $logRoot 'JA-027-batch-20260908-120000.json') -Force
    Remove-Item -LiteralPath (Join-Path $logRoot 'company-candidate-website-discovery-20260908-121000.json') -Force
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification/v1'
        run_id = '20260908-122000'
        results = @(
            [pscustomobject]@{
                candidate_id = 'hint:fallback'
                fetches = @(
                    [pscustomobject]@{
                        url = 'https://fallback.example.invalid/'
                        error_class = 'DNS_RESOLUTION_FAILED'
                        error_detail = 'No such host'
                        exception_types = @('System.Net.Http.HttpRequestException')
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $logRoot 'JA-027-batch-20260908-122000.json') -Encoding UTF8

    $fallbackOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Inspect-JobAgentFetchErrors.ps1') -ProjectRoot $projectRoot 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Error-Inspection-Fallback ist fehlgeschlagen: " + ($fallbackOutput -join "`n"))
    $fallbackResult = ($fallbackOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert-True -Condition ($fallbackResult.dominant_error_class -eq 'DNS_RESOLUTION_FAILED') -Message 'Inspection baut keine Fallback-Summary aus Result-Fetches.'
    Assert-True -Condition (@($fallbackResult.runs | Where-Object { $_.summary_source -eq 'results_fallback' }).Count -eq 1) -Message 'Inspection weist Fallback-Summary-Quelle nicht aus.'

    Remove-Item -LiteralPath (Join-Path $logRoot 'JA-027-batch-20260908-122000.json') -Force
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification/v1'
        run_id = '20260908-123000'
        results = @(
            [pscustomobject]@{
                candidate_id = 'hint:legacy'
                fetches = @(
                    [pscustomobject]@{
                        url = 'https://legacy.example.invalid/'
                        error = 'The SSL connection could not be established, see inner exception.'
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $logRoot 'JA-027-batch-20260908-123000.json') -Encoding UTF8

    $legacyOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Inspect-JobAgentFetchErrors.ps1') -ProjectRoot $projectRoot 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Fetch-Error-Inspection-Legacy ist fehlgeschlagen: " + ($legacyOutput -join "`n"))
    $legacyResult = ($legacyOutput -join "`n") | ConvertFrom-Json -Depth 30
    Assert-True -Condition ($legacyResult.dominant_error_class -eq 'TLS_HANDSHAKE_FAILED') -Message 'Inspection klassifiziert Legacy-Fetches ohne error_class nicht.'
    Assert-True -Condition ($legacyResult.status -eq 'environment_tls_check_required') -Message 'Inspection leitet aus dominanten Legacy-TLS-Fehlern keinen Environment-Check ab.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

Write-Host 'OK Test-JobAgentFetchErrorInspection'
