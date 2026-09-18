[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

$fixturePath = Join-Path $PSScriptRoot 'fixtures\jobagent\job-change-history.json'
$fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json -Depth 20
$document = [pscustomobject]@{
    job_snapshots = @($fixture.job_snapshots)
    change_events = @($fixture.change_events)
}
$history = @(Get-JobAgentReportChangeHistory -Document $document -JobId $fixture.job_id)
Assert-True -Condition ($history.Count -eq 2) -Message 'Die Fixture muss genau Erfassung und fachliche Aenderung projizieren.'
Assert-True -Condition ($history[0].change_event_id -eq 'change:history_fixture_updated') -Message 'Die neueste Aenderung muss zuerst erscheinen.'
Assert-True -Condition ((@($history[0].changed_fields) -join ',') -eq 'title,description') -Message 'Ein Mehrfelddiff muss ein Chronikereignis mit beiden Feldern bleiben.'
$descriptionChange = @($history[0].fields | Where-Object field -eq 'description')[0]
Assert-True -Condition ($descriptionChange.before -eq 'Keine Remote-Arbeit.' -and $descriptionChange.after -eq 'Keine Remote-Arbeit und Budgetverantwortung.') -Message 'HTML, Zeilenenden und Whitespace muessen sicher als Klartext projiziert werden.'
Assert-True -Condition ($history[1].label -eq 'Erstmals erfasst') -Message 'Erstbeobachtung braucht eine eigenstaendige Quellenchronikbezeichnung.'

$missingPrevious = [pscustomobject]@{
    job_snapshots = @($fixture.job_snapshots[1])
    change_events = @($fixture.change_events[1])
}
$missingHistory = @(Get-JobAgentReportChangeHistory -Document $missingPrevious -JobId $fixture.job_id)
Assert-True -Condition ((@($missingHistory[0].fields | Where-Object field -eq 'title')[0].before) -eq 'Vorheriger Inhalt nicht archiviert') -Message 'Fehlende Altsnapshots duerfen nicht rekonstruiert werden.'

$manyEvents = [System.Collections.Generic.List[object]]::new()
for ($index = 1; $index -le 21; $index++) {
    $manyEvents.Add([pscustomobject]@{
            change_event_id = ('change:history_fixture_same_time_{0:d2}' -f $index)
            job_id = $fixture.job_id
            scan_run_id = 'scanrun:20260918T080000Z'
            event_type = 'JOB_UPDATED'
            created_at = '2026-09-18T09:00:00.000Z'
            old_status = 'ACTIVE'
            new_status = 'UPDATED'
            changed_fields = @('title')
            reason = 'Feste Reihenfolge pruefen.'
        })
}
$manyDocument = [pscustomobject]@{ job_snapshots = @($fixture.job_snapshots); change_events = @($manyEvents.ToArray()) }
$limited = @(Get-JobAgentReportChangeHistory -Document $manyDocument -JobId $fixture.job_id -MaximumEntries 20)
Assert-True -Condition ($limited.Count -eq 20) -Message 'Die Detailansicht darf initial hoechstens 20 Chronikeintraege liefern.'
Assert-True -Condition ($limited[0].change_event_id -eq 'change:history_fixture_same_time_01') -Message 'Zeitgleichstand muss stabil nach Ereignis-ID aufgeloest werden.'
Assert-True -Condition ((Get-JobAgentReportChangeHistory -Document $document -JobId $fixture.job_id | ConvertTo-Json -Depth 20 -Compress) -eq (Get-JobAgentReportChangeHistory -Document $document -JobId $fixture.job_id | ConvertTo-Json -Depth 20 -Compress)) -Message 'Gleiche Generation muss idempotent dieselbe Chronik liefern.'

[pscustomobject]@{
    status = 'ok'
    cases = @('initial_capture_and_multi_field_change', 'safe_plain_text_projection', 'missing_previous_snapshot', 'twenty_of_twenty_one_history_limit', 'deterministic_same_timestamp_order', 'idempotent_projection')
} | ConvertTo-Json -Depth 4
