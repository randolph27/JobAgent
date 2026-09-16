#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Supertest.psm1') -Force
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("jobagent-supertest-contract-" + [guid]::NewGuid().ToString('N'))

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-ChildScript {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Body)
    $path = Join-Path $testRoot ("children\$Name.ps1")
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    Set-Content -LiteralPath $path -Value $Body -Encoding utf8NoBOM
    return "children\$Name.ps1"
}

function Invoke-ContractCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object[]]$Plan,
        [Parameter(Mandatory)][string]$ExpectedStatus,
        [Parameter(Mandatory)][int]$ExpectedPassed,
        [Parameter(Mandatory)][int]$ExpectedFailed,
        [Parameter(Mandatory)][int]$ExpectedBlocked,
        [Parameter(Mandatory)][int]$ExpectedNotRun,
        [string]$ExpectedErrorKind,
        [int]$TimeoutSeconds = 2
    )

    $reportPath = Join-Path $testRoot ("reports\$Name.json")
    $evidenceHashes = [pscustomobject]@{ inventory_sha256 = ('a' * 64); matrix_sha256 = ('b' * 64); source_sha256 = ('c' * 64); source_file_count = $Plan.Count }
    $report = Invoke-JobAgentSupertestRunner -TestPlan $Plan -RepositoryRoot $testRoot -ReportPath $reportPath -EvidenceHashes $evidenceHashes -TimeoutSeconds $TimeoutSeconds
    Assert-True -Condition (Test-Path -LiteralPath $reportPath -PathType Leaf) -Message "$Name hat keinen atomar geschriebenen Bericht erzeugt."
    $stored = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($stored.status -eq $ExpectedStatus) -Message "$Name hat Status $($stored.status) statt $ExpectedStatus."
    Assert-True -Condition ($stored.passed -eq $ExpectedPassed -and $stored.failed -eq $ExpectedFailed -and $stored.blocked -eq $ExpectedBlocked -and $stored.not_run -eq $ExpectedNotRun) -Message "$Name hat ungueltige Summenzaehler."
    Assert-True -Condition ($stored.planned_test_count -eq $Plan.Count) -Message "$Name hat eine ungueltige Sollanzahl."
    Assert-True -Condition ($stored.evidence_hashes.inventory_sha256 -eq ('a' * 64) -and $stored.evidence_hashes.matrix_sha256 -eq ('b' * 64) -and $stored.evidence_hashes.source_sha256 -eq ('c' * 64)) -Message "$Name protokolliert keine vollstaendigen Evidenzhashes."
    Assert-True -Condition (@($stored.tests).Count -eq $Plan.Count) -Message "$Name hat keine vollstaendige Ergebnisliste."
    if (-not [string]::IsNullOrWhiteSpace($ExpectedErrorKind)) {
        Assert-True -Condition ($stored.tests[0].error_kind -eq $ExpectedErrorKind) -Message "$Name hat Fehlerart $($stored.tests[0].error_kind) statt $ExpectedErrorKind."
    }
    if ($ExpectedStatus -ne 'passed') {
        Assert-True -Condition ($stored.tests[-1].status -eq 'not-run' -or $Plan.Count -eq 1) -Message "$Name markiert Restfaelle nicht als not-run."
    }
    foreach ($result in @($stored.tests | Where-Object { $_.status -ne 'not-run' })) {
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$result.started_at) -and -not [string]::IsNullOrWhiteSpace([string]$result.ended_at)) -Message "$Name protokolliert keine Zeitstempel."
        Assert-True -Condition ([string]$result.working_directory -eq $testRoot) -Message "$Name protokolliert ein falsches Arbeitsverzeichnis."
        Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$result.pwsh_version)) -Message "$Name protokolliert keine PowerShell-Version."
    }
}

try {
    [IO.Directory]::CreateDirectory($testRoot) | Out-Null
    $success = New-ChildScript -Name 'success' -Body "[Console]::Out.WriteLine('success')`nexit 0"
    $nonzero = New-ChildScript -Name 'nonzero' -Body "[Console]::Error.WriteLine('nonzero')`nexit 7"
    $exception = New-ChildScript -Name 'exception' -Body "throw 'expected child exception'"
    $timeout = New-ChildScript -Name 'timeout' -Body "Start-Sleep -Seconds 10`nexit 0"
    $aborted = New-ChildScript -Name 'aborted' -Body "[Console]::Error.WriteLine('aborted')`nexit 130"

    Invoke-ContractCase -Name 'success' -Plan @([pscustomobject]@{ roadmap_id = 'success'; test_file = $success }) -ExpectedStatus 'passed' -ExpectedPassed 1 -ExpectedFailed 0 -ExpectedBlocked 0 -ExpectedNotRun 0
    Invoke-ContractCase -Name 'nonzero' -Plan @([pscustomobject]@{ roadmap_id = 'nonzero'; test_file = $nonzero }, [pscustomobject]@{ roadmap_id = 'rest'; test_file = $success }) -ExpectedStatus 'failed' -ExpectedPassed 0 -ExpectedFailed 1 -ExpectedBlocked 0 -ExpectedNotRun 1 -ExpectedErrorKind 'nonzero-exit'
    Invoke-ContractCase -Name 'exception' -Plan @([pscustomobject]@{ roadmap_id = 'exception'; test_file = $exception }, [pscustomobject]@{ roadmap_id = 'rest'; test_file = $success }) -ExpectedStatus 'failed' -ExpectedPassed 0 -ExpectedFailed 1 -ExpectedBlocked 0 -ExpectedNotRun 1 -ExpectedErrorKind 'nonzero-exit'
    Invoke-ContractCase -Name 'invalid-result-data' -Plan @([pscustomobject]@{ roadmap_id = 'invalid' }, [pscustomobject]@{ roadmap_id = 'rest'; test_file = $success }) -ExpectedStatus 'failed' -ExpectedPassed 0 -ExpectedFailed 1 -ExpectedBlocked 0 -ExpectedNotRun 1 -ExpectedErrorKind 'invalid-result-data'
    Invoke-ContractCase -Name 'timeout' -Plan @([pscustomobject]@{ roadmap_id = 'timeout'; test_file = $timeout }, [pscustomobject]@{ roadmap_id = 'rest'; test_file = $success }) -ExpectedStatus 'blocked' -ExpectedPassed 0 -ExpectedFailed 0 -ExpectedBlocked 1 -ExpectedNotRun 1 -ExpectedErrorKind 'timeout' -TimeoutSeconds 1
    Invoke-ContractCase -Name 'aborted' -Plan @([pscustomobject]@{ roadmap_id = 'aborted'; test_file = $aborted }, [pscustomobject]@{ roadmap_id = 'rest'; test_file = $success }) -ExpectedStatus 'blocked' -ExpectedPassed 0 -ExpectedFailed 0 -ExpectedBlocked 1 -ExpectedNotRun 1 -ExpectedErrorKind 'aborted'

    [pscustomobject]@{ status = 'ok'; cases = @('success', 'nonzero', 'exception', 'invalid-result-data', 'timeout', 'aborted') } | ConvertTo-Json -Depth 5
} finally {
    if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
}
