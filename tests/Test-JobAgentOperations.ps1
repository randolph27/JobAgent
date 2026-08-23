#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Operations.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestProjectRoot {
    $path = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-operations-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    return $path
}

$projectRoot = New-TestProjectRoot
try {
    $first = Invoke-JobAgentManagedDailyRun -ProjectRoot $projectRoot -ScriptBlock {
        [pscustomobject]@{
            status = 'SUCCESS'
            scan_run_id = 'scanrun:test'
            report_path = 'logs/jobagent/report.json'
            markdown_report_path = 'logs/jobagent/report.md'
            html_report_path = 'html/jobagent/report.html'
        }
    } -StartedAt ([datetime]'2026-08-17T10:00:00Z') -RetainLogs 10

    Assert-True -Condition ($first.status -eq 'SUCCEEDED') -Message 'Managed Daily-Run meldet keinen Erfolg.'
    Assert-True -Condition (Test-Path -LiteralPath $first.status_path) -Message 'Statusdatei wurde nicht geschrieben.'
    Assert-True -Condition (Test-Path -LiteralPath $first.run_log_path) -Message 'Run-Log wurde nicht geschrieben.'

    $status = Get-JobAgentDailyRunOperationalStatus -ProjectRoot $projectRoot
    Assert-True -Condition ($status.state -eq 'SUCCEEDED') -Message 'Statusabfrage erkennt letzten Erfolg nicht.'
    Assert-True -Condition (-not $status.is_running) -Message 'Statusabfrage markiert abgeschlossenen Lauf als RUNNING.'
    Assert-True -Condition ($status.last_status.scan_run_id -eq 'scanrun:test') -Message 'Statusdatei enthaelt keine ScanRun-ID.'
    Assert-True -Condition ($status.last_status.html_report_path -eq 'html/jobagent/report.html') -Message 'Statusdatei enthaelt keinen HTML-Report-Pfad.'

    $failure = Invoke-JobAgentManagedDailyRun -ProjectRoot $projectRoot -ScriptBlock {
        throw 'fixture failure'
    } -StartedAt ([datetime]'2026-08-17T11:00:00Z') -RetainLogs 10
    Assert-True -Condition ($failure.status -eq 'FAILED') -Message 'Managed Daily-Run meldet Fehler nicht.'
    Assert-True -Condition ($failure.exit_code -eq 1) -Message 'Fehlerlauf setzt keinen Exitcode 1.'

    foreach ($index in 0..4) {
        $path = Join-Path $projectRoot ("logs/jobagent/daily-run-old-$index.log")
        Set-Content -LiteralPath $path -Value "old-$index" -Encoding UTF8
        (Get-Item -LiteralPath $path).LastWriteTimeUtc = ([datetime]'2026-08-17T09:00:00Z').AddMinutes($index)
    }
    Invoke-JobAgentLogRotation -LogRoot (Join-Path $projectRoot 'logs/jobagent') -RetainLogs 3 | Out-Null
    $remainingLogs = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'logs/jobagent') -Filter 'daily-run-*.log')
    Assert-True -Condition ($remainingLogs.Count -le 3) -Message 'Logrotation behaelt zu viele Daily-Run-Logs.'

    $lockStatusScript = {
        param([string]$ProjectRoot, [string]$RepoRoot)
        Import-Module (Join-Path $RepoRoot 'src\JobAgent.Operations.psm1') -Force -DisableNameChecking
        Invoke-JobAgentManagedDailyRun -ProjectRoot $ProjectRoot -ScriptBlock {
            Start-Sleep -Seconds 4
            [pscustomobject]@{ status = 'SUCCESS'; scan_run_id = 'scanrun:slow' }
        } | ConvertTo-Json -Depth 20
    }
    $job = Start-Job -ScriptBlock $lockStatusScript -ArgumentList $projectRoot, $root
    foreach ($attempt in 1..20) {
        $runningStatus = Get-JobAgentDailyRunOperationalStatus -ProjectRoot $projectRoot
        if ($runningStatus.is_running) {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    $blocked = $false
    try {
        Invoke-JobAgentManagedDailyRun -ProjectRoot $projectRoot -ScriptBlock { [pscustomobject]@{ status = 'SUCCESS' } } | Out-Null
    }
    catch {
        $blocked = $_.Exception.Message -match 'Daily-Run laeuft bereits'
    }
    Wait-Job -Job $job | Out-Null
    $jobOutput = Receive-Job -Job $job
    Remove-Job -Job $job
    Assert-True -Condition $blocked -Message 'Paralleler Daily-Run wurde nicht blockiert.'
    Assert-True -Condition (($jobOutput -join "`n") -match 'SUCCEEDED') -Message 'Langsamer Hintergrundlauf wurde nicht erfolgreich abgeschlossen.'

    [pscustomobject]@{
        status = 'ok'
        cases = @(
            'managed_daily_run_writes_status_and_log',
            'daily_run_status_reads_last_state',
            'managed_daily_run_failure_sets_exit_code',
            'daily_run_log_rotation_retains_limit',
            'parallel_daily_run_is_blocked'
        )
    } | ConvertTo-Json -Depth 4
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}
