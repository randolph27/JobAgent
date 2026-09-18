#requires -Version 7.4

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$document = Get-Content -Raw -LiteralPath (Join-Path $root 'tests\fixtures\jobagent\valid.json') | ConvertFrom-Json -Depth 100
$contract = Get-Content -Raw -LiteralPath (Join-Path $root 'tests\fixtures\jobagent\calendar.json') | ConvertFrom-Json -Depth 20
$document.companies[0].next_scan_at = '2026-10-26T12:00:00.000Z'
$run = $document.scan_runs[0]
$run.scan_run_id = 'scanrun:calendar'
$run.started_at = '2026-10-25T21:30:00.000Z'
$run.finished_at = '2026-10-26T09:00:00.000Z'
$document.change_events[0].scan_run_id = 'scanrun:calendar'
$document.change_events[0].job_id = 'job:created-one'
$document.change_events += [pscustomobject]@{ change_event_id = 'change:created-two'; job_id = 'job:created-two'; scan_run_id = 'scanrun:calendar'; event_type = 'JOB_CREATED'; created_at = '2026-10-26T00:30:00.000Z'; old_status = $null; new_status = 'NEW'; changed_fields = @('status'); reason = 'Fixture' }
$base = $document.scan_attempts[0]
$document.scan_attempts = @(
    [pscustomobject]@{ scan_attempt_id = 'attempt:failed-one'; scan_run_id = 'scanrun:calendar'; company_id = 'company:example_ag'; source_id = $base.source_id; started_at = '2026-10-25T21:30:00.000Z'; finished_at = '2026-10-25T21:35:00.000Z'; status = 'FAILED'; adapter = 'fixture'; error_class = 'TIMEOUT'; retry_recommendation = 'RETRY_NEXT_RUN'; http_status = 504; scan_complete = $false },
    [pscustomobject]@{ scan_attempt_id = 'attempt:failed-two'; scan_run_id = 'scanrun:calendar'; company_id = 'company:example_ag'; source_id = $base.source_id; started_at = '2026-10-25T22:00:00.000Z'; finished_at = '2026-10-25T22:05:00.000Z'; status = 'FAILED'; adapter = 'fixture'; error_class = 'TIMEOUT'; retry_recommendation = 'RETRY_NEXT_RUN'; http_status = 504; scan_complete = $false },
    [pscustomobject]@{ scan_attempt_id = 'attempt:success'; scan_run_id = 'scanrun:calendar'; company_id = 'company:example_ag'; source_id = $base.source_id; started_at = '2026-10-25T23:50:00.000Z'; finished_at = '2026-10-26T00:10:00.000Z'; status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200; scan_complete = $true }
)

$report = New-JobAgentDailyReport -Document $document -ScanRunId 'scanrun:calendar'
$attempts = @($report.calendar.attempts)
Assert-True -Condition ($attempts.Count -eq [int]$contract.expected.retry_oracle.attempts) -Message 'Retryversuche werden nicht einzeln projiziert.'
Assert-True -Condition ((@($attempts | Select-Object -ExpandProperty company_id -Unique)).Count -eq [int]$contract.expected.retry_oracle.companies) -Message 'Firmenzaehler der Retryprojektion ist falsch.'
Assert-True -Condition ((@($attempts | Where-Object status -eq 'FAILED')).Count -eq [int]$contract.expected.retry_oracle.failures) -Message 'Fehlerzaehler der Retryprojektion ist falsch.'
Assert-True -Condition ((@($attempts | Where-Object { $_.event_id -eq 'attempt:success' })[0].new_job_ids).Count -eq [int]$contract.expected.retry_oracle.new_jobs) -Message 'Neue Stellen werden nicht distinct je Lauf projektiert.'
Assert-True -Condition (@($report.calendar.planned_scans).Count -eq [int]$contract.expected.planned_scan_count) -Message 'Aktuelle Firmenplanung fehlt oder ist doppelt.'
Assert-True -Condition (([datetime]$report.calendar.reference_time).ToUniversalTime() -eq ([datetime]$contract.reference_time).ToUniversalTime()) -Message 'Kalenderreferenz ist nicht stabil am Reportabschluss gebunden.'
$html = ConvertTo-JobAgentDailyReportHtml -Report $report
foreach ($token in @('jobagent-tab-calendar', 'jobagent-calendar', 'calendarMode', 'Keine gespeicherten Abrufe', 'Gespeicherte Abrufe', 'calendar-static-fallback')) {
    Assert-True -Condition ($html.Contains($token)) -Message "Kalendervertrag fehlt im HTML: $token"
}

@{ status = 'ok'; cases = @('retry_oracle', 'midnight_finish_uses_finish_day', 'current_planning', 'stable_report_reference', 'calendar_html_contract') } | ConvertTo-Json -Depth 8
