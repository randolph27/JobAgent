#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.StatusMachine.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestRawJob {
    param(
        [string]$Title = 'Head of IT',
        [string]$DetailUrl = 'https://example.invalid/careers/head-it-123',
        [string]$ExternalJobId = '123',
        [string]$Summary = 'IT-Gesamtverantwortung mit Strategie und Fuehrung.',
        [string]$LocationLabel = 'Muenchen',
        [string]$WorkTime = 'UNKNOWN',
        [string[]]$Requirements = @(),
        [string]$Salary = 'UNKNOWN'
    )

    [pscustomobject]@{
        title = $Title
        detail_url = $DetailUrl
        external_job_id = $ExternalJobId
        ats_job_id = 'UNKNOWN'
        location_label = $LocationLabel
        summary = $Summary
        work_time = $WorkTime
        requirements = @($Requirements)
        salary = $Salary
        extraction_confidence = 90
    }
}

function New-TestScanAttempt {
    param(
        [string]$ScanRunId,
        [string]$Status = 'SUCCESS',
        [string]$ErrorClass = 'NONE',
        [string]$Suffix = 'default',
        [string]$CompanyId = 'company:example_ag',
        [string]$SourceId = 'source:example_ag_career',
        [bool]$ScanComplete = $true
    )

    [pscustomobject]@{
        scan_attempt_id = 'scanattempt:example_ag_' + $Suffix
        scan_run_id = $ScanRunId
        company_id = $CompanyId
        source_id = $SourceId
        started_at = '2026-08-17T10:00:00.000Z'
        finished_at = '2026-08-17T10:00:01.000Z'
        status = $Status
        adapter = 'fixture-adapter'
        error_class = $ErrorClass
        retry_recommendation = if ($ErrorClass -eq 'NONE') { 'NONE' } else { 'RETRY_NEXT_RUN' }
        http_status = if ($ErrorClass -eq 'NONE') { 200 } else { $null }
        scan_complete = $ScanComplete
    }
}

function New-TestAdapterResult {
    param(
        [string]$ScanRunId,
        [object[]]$RawJobs = @((New-TestRawJob)),
        [string]$Status = 'SUCCESS',
        [string]$ErrorClass = 'NONE',
        [string]$Suffix = 'default',
        [string]$CompanyId = 'company:example_ag',
        [string]$SourceId = 'source:example_ag_career',
        [string]$OfficialSourceUrl = 'https://example.invalid/careers',
        [bool]$ScanComplete = $true
    )

    [pscustomobject]@{
        adapter = 'fixture-adapter'
        company_id = $CompanyId
        source_id = $SourceId
        official_source_url = $OfficialSourceUrl
        status = $Status
        error_class = $ErrorClass
        retry_recommendation = if ($ErrorClass -eq 'NONE') { 'NONE' } else { 'RETRY_NEXT_RUN' }
        scan_complete = $ScanComplete
        raw_jobs = @($RawJobs)
        scan_attempt = New-TestScanAttempt -ScanRunId $ScanRunId -Status $Status -ErrorClass $ErrorClass -Suffix $Suffix -CompanyId $CompanyId -SourceId $SourceId -ScanComplete $ScanComplete
        artifact_paths = @()
    }
}

$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')

$first = Invoke-JobAgentStatusMachine `
    -Document $document `
    -ScanRunId 'scanrun:20260817T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260817T100000Z' -Suffix 'first')) `
    -ObservedAt ([datetime]'2026-08-17T10:00:00Z')
Assert-True -Condition (@($first.jobs).Count -eq 1) -Message 'Erster Lauf hat keinen Job erzeugt.'
Assert-True -Condition ($first.jobs[0].status -eq 'NEW') -Message 'Erster Lauf setzt Status nicht auf NEW.'
Assert-True -Condition ($first.jobs[0].description -eq 'IT-Gesamtverantwortung mit Strategie und Fuehrung.') -Message 'Erster Lauf speichert keine offizielle Beschreibung am Job.'
Assert-True -Condition ($first.job_snapshots[0].description -eq 'IT-Gesamtverantwortung mit Strategie und Fuehrung.') -Message 'Snapshot speichert keine Beschreibung.'
Assert-True -Condition (@($first.change_events | Where-Object event_type -eq 'JOB_CREATED').Count -eq 1) -Message 'Erster Lauf erzeugt kein JOB_CREATED-Event.'
Assert-True -Condition ($first.jobs[0].first_seen -eq $first.jobs[0].last_seen) -Message 'first_seen und last_seen weichen im ersten Lauf ab.'

$second = Invoke-JobAgentStatusMachine `
    -Document $first `
    -ScanRunId 'scanrun:20260818T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260818T100000Z' -Suffix 'second')) `
    -ObservedAt ([datetime]'2026-08-18T10:00:00Z')
Assert-True -Condition (@($second.jobs).Count -eq 1) -Message 'Unveraenderter zweiter Lauf erzeugt Duplikat.'
Assert-True -Condition ($second.jobs[0].status -eq 'ACTIVE') -Message 'Unveraenderter zweiter Lauf setzt Status nicht auf ACTIVE.'
Assert-True -Condition ($second.jobs[0].first_seen -eq '2026-08-17T10:00:00.000Z') -Message 'first_seen wurde im zweiten Lauf ueberschrieben.'
Assert-True -Condition ($second.jobs[0].last_seen -eq '2026-08-18T10:00:00.000Z') -Message 'last_seen wurde im zweiten Lauf nicht aktualisiert.'

$updatedRaw = New-TestRawJob -Title 'Director Information Technology' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123'
$third = Invoke-JobAgentStatusMachine `
    -Document $second `
    -ScanRunId 'scanrun:20260819T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260819T100000Z' -RawJobs @($updatedRaw) -Suffix 'third')) `
    -ObservedAt ([datetime]'2026-08-19T10:00:00Z')
Assert-True -Condition ($third.jobs[0].status -eq 'UPDATED') -Message 'Titelwechsel setzt Status nicht auf UPDATED.'
Assert-True -Condition (@($third.change_events | Where-Object { ($_.event_type -eq 'JOB_UPDATED') -and (@($_.changed_fields) -contains 'title') }).Count -eq 1) -Message 'Titelwechsel erzeugt kein JOB_UPDATED mit changed_fields=title.'

$descriptionRaw = New-TestRawJob -Title 'Director Information Technology' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123' -Summary '<p>IT-Leitung mit Budget, Plattformbetrieb und Lieferantensteuerung.</p>'
$descriptionUpdated = Invoke-JobAgentStatusMachine `
    -Document $third `
    -ScanRunId 'scanrun:20260819T120000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260819T120000Z' -RawJobs @($descriptionRaw) -Suffix 'description-updated')) `
    -ObservedAt ([datetime]'2026-08-19T12:00:00Z')
Assert-True -Condition ($descriptionUpdated.jobs[0].status -eq 'UPDATED') -Message 'Beschreibungsaenderung setzt Status nicht auf UPDATED.'
Assert-True -Condition ($descriptionUpdated.jobs[0].description -eq 'IT-Leitung mit Budget, Plattformbetrieb und Lieferantensteuerung.') -Message 'Beschreibungsaenderung wird nicht normalisiert gespeichert.'
Assert-True -Condition (@($descriptionUpdated.change_events | Where-Object { ($_.event_type -eq 'JOB_UPDATED') -and (@($_.changed_fields) -contains 'description') }).Count -eq 1) -Message 'Beschreibungsaenderung erzeugt kein JOB_UPDATED mit changed_fields=description.'

$failed = Invoke-JobAgentStatusMachine `
    -Document $descriptionUpdated `
    -ScanRunId 'scanrun:20260820T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260820T100000Z' -RawJobs @() -Status 'FAILED' -ErrorClass 'TIMEOUT' -Suffix 'failed')) `
    -ObservedAt ([datetime]'2026-08-20T10:00:00Z')
Assert-True -Condition ($failed.jobs[0].status -eq 'UPDATED') -Message 'Fehlgeschlagener Scan hat bestehenden Job faelschlich entfernt oder geaendert.'
Assert-True -Condition (@($failed.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Fehlgeschlagener Scan erzeugt faelschlich JOB_REMOVED.'
Assert-True -Condition ($failed.jobs[0].last_seen -eq $descriptionUpdated.jobs[0].last_seen) -Message 'Fehlgeschlagener Scan darf last_seen nicht fortschreiben.'

$removed = Invoke-JobAgentStatusMachine `
    -Document $failed `
    -ScanRunId 'scanrun:20260821T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260821T100000Z' -RawJobs @() -Status 'SUCCESS' -ErrorClass 'NONE' -Suffix 'empty_success')) `
    -ObservedAt ([datetime]'2026-08-21T10:00:00Z')
Assert-True -Condition ($removed.jobs[0].status -eq 'REMOVED') -Message 'Erfolgreicher leerer Scan setzt fehlenden Job nicht auf REMOVED.'
Assert-True -Condition (@($removed.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 1) -Message 'Erfolgreiche Entfernung erzeugt kein JOB_REMOVED.'

$partialBase = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260821T110000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260821T110000Z' -Suffix 'partial-base')) `
    -ObservedAt ([datetime]'2026-08-21T11:00:00Z')
$partialEmpty = Invoke-JobAgentStatusMachine `
    -Document $partialBase `
    -ScanRunId 'scanrun:20260821T120000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260821T120000Z' -RawJobs @() -Status 'SUCCESS' -ErrorClass 'NONE' -ScanComplete $false -Suffix 'incomplete_success')) `
    -ObservedAt ([datetime]'2026-08-21T12:00:00Z')
Assert-True -Condition ($partialEmpty.jobs[0].status -ne 'REMOVED' -and @($partialEmpty.change_events | Where-Object { $_.scan_run_id -eq 'scanrun:20260821T120000Z' -and $_.event_type -eq 'JOB_REMOVED' }).Count -eq 0) -Message 'Unvollstaendiger Erfolg darf keinen fehlenden Job entfernen.'
Assert-True -Condition ($partialEmpty.jobs[0].last_seen -eq $partialBase.jobs[0].last_seen) -Message 'PARTIAL-Quelle darf last_seen nicht fortschreiben.'

$reappeared = Invoke-JobAgentStatusMachine `
    -Document $removed `
    -ScanRunId 'scanrun:20260822T090000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260822T090000Z' -RawJobs @((New-TestRawJob -Title 'Director Information Technology' -Summary 'IT-Leitung mit Budget, Plattformbetrieb und Lieferantensteuerung.')) -Suffix 'reappeared')) `
    -ObservedAt ([datetime]'2026-08-22T09:00:00Z')
Assert-True -Condition ($reappeared.jobs[0].status -eq 'ACTIVE') -Message "Wiederaufgetauchte Stelle wird nicht als ACTIVE reaktiviert: $($reappeared.jobs[0].status)."
Assert-True -Condition ($reappeared.jobs[0].last_seen -eq '2026-08-22T09:00:00.000Z') -Message 'Wiederaufgetauchte Stelle aktualisiert last_seen nicht.'

$reclassifiedRaw = New-TestRawJob -Title 'IT Manager' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123' -LocationLabel 'Freising'
$reclassifiedRaw | Add-Member -NotePropertyName classification -NotePropertyValue ([pscustomobject]@{ result = 'MATCH'; priority = 'A'; score = 95; reasons = @('Aktualisierte Bewertung.'); rejected_reasons = @(); evaluated_at = '2026-08-21T13:00:00.000Z' })
$reclassifiedRaw | Add-Member -NotePropertyName priority -NotePropertyValue 'A'
$reclassifiedRaw | Add-Member -NotePropertyName work_model -NotePropertyValue 'HYBRID'
$reclassifiedRaw | Add-Member -NotePropertyName employment_type -NotePropertyValue 'FULL_TIME'
$reclassifiedRaw | Add-Member -NotePropertyName job_validity -NotePropertyValue ([pscustomobject]@{ result = 'VALID'; reasons = @(); evaluated_at = '2026-08-21T13:00:00.000Z' })
$reclassifiedRaw | Add-Member -NotePropertyName regional_scope -NotePropertyValue ([pscustomobject]@{ result = 'IN_SCOPE'; target_area = 'FREISING'; reasons = @('Stellenort liegt im Zielgebiet.'); evaluated_at = '2026-08-21T13:00:00.000Z' })
$reclassified = Invoke-JobAgentStatusMachine `
    -Document $descriptionUpdated `
    -ScanRunId 'scanrun:20260821T130000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260821T130000Z' -RawJobs @($reclassifiedRaw) -Suffix 'reclassified')) `
    -ObservedAt ([datetime]'2026-08-21T13:00:00Z')
Assert-True -Condition ($reclassified.jobs[0].classification.result -eq 'MATCH' -and $reclassified.jobs[0].priority -eq 'A' -and $reclassified.jobs[0].work_model -eq 'HYBRID' -and $reclassified.jobs[0].employment_type -eq 'FULL_TIME') -Message 'Aktuelle Klassifikation und Arbeitsdaten werden nicht atomar uebernommen.'
Assert-True -Condition ($reclassified.jobs[0].job_validity.result -eq 'VALID' -and $reclassified.jobs[0].regional_scope.result -eq 'IN_SCOPE') -Message 'Gueltigkeit und Gebiet werden nicht getrennt gespeichert.'
Assert-True -Condition (@($reclassified.change_events | Where-Object { $_.event_type -eq 'JOB_UPDATED' -and @($_.changed_fields) -contains 'classification' -and @($_.changed_fields) -contains 'work_model' }).Count -eq 1) -Message 'Aktualisierte Bewertung erzeugt kein vollstaendiges JOB_UPDATED-Event.'

$invalidRaw = [pscustomobject]@{
    title = ''
    detail_url = 'not-a-url'
    external_job_id = 'UNKNOWN'
    ats_job_id = 'UNKNOWN'
    location_label = 'UNKNOWN'
    summary = 'ungueltiges Fixture'
    extraction_confidence = 20
}
$invalid = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260822T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260822T100000Z' -RawJobs @($invalidRaw) -Status 'PARTIAL' -ErrorClass 'PARSING_ERROR' -Suffix 'invalid')) `
    -ObservedAt ([datetime]'2026-08-22T10:00:00Z')
Assert-True -Condition (@($invalid.jobs).Count -eq 0) -Message 'Invalider Treffer wurde als Job gespeichert.'
Assert-True -Condition (@($invalid.change_events | Where-Object event_type -eq 'JOB_INVALIDATED').Count -eq 1) -Message 'Invalider Treffer erzeugt kein JOB_INVALIDATED.'

$navigationRaw = New-TestRawJob -Title 'Karriere' -DetailUrl 'https://example.invalid/careers'
$navigationRaw | Add-Member -NotePropertyName job_validity -NotePropertyValue ([pscustomobject]@{ result = 'REJECTED'; reasons = @('Quellkennzeichen NAVIGATION bezeichnet keine Stelle.'); evaluated_at = '2026-08-22T10:00:00.000Z' })
$navigationRejected = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260822T110000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260822T110000Z' -RawJobs @($navigationRaw) -Status 'PARTIAL' -ErrorClass 'PARSING_ERROR' -Suffix 'navigation')) `
    -ObservedAt ([datetime]'2026-08-22T11:00:00Z')
Assert-True -Condition (@($navigationRejected.jobs).Count -eq 0) -Message 'Explizit ungueltiger Navigationseintrag wurde gespeichert.'

$multiSourceDocument = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$multiSourceFirst = Invoke-JobAgentStatusMachine `
    -Document $multiSourceDocument `
    -ScanRunId 'scanrun:20260823T100000Z' `
    -AdapterResults @(
        (New-TestAdapterResult -ScanRunId 'scanrun:20260823T100000Z' -Suffix 'multi-a-first' -RawJobs @(
                (New-TestRawJob -DetailUrl 'https://example.invalid/careers/job-a-1' -ExternalJobId 'a-1')
            ))
        (New-TestAdapterResult -ScanRunId 'scanrun:20260823T100000Z' -Suffix 'multi-b-first' -SourceId 'source:example_ag_ats' -OfficialSourceUrl 'https://jobs.example.invalid/search' -RawJobs @(
                (New-TestRawJob -DetailUrl 'https://jobs.example.invalid/posting/b-1' -ExternalJobId 'b-1')
            ))
    ) `
    -ObservedAt ([datetime]'2026-08-23T10:00:00Z')
Assert-True -Condition (@($multiSourceFirst.jobs).Count -eq 2) -Message 'Mehrquellenlauf hat nicht beide Jobs angelegt.'

$multiSourceSecond = Invoke-JobAgentStatusMachine `
    -Document $multiSourceFirst `
    -ScanRunId 'scanrun:20260824T100000Z' `
    -AdapterResults @(
        (New-TestAdapterResult -ScanRunId 'scanrun:20260824T100000Z' -Suffix 'multi-a-second' -RawJobs @())
    ) `
    -ObservedAt ([datetime]'2026-08-24T10:00:00Z')
$careerJob = @($multiSourceSecond.jobs | Where-Object { [string]$_.source_id -eq 'source:example_ag_career' })[0]
$atsJob = @($multiSourceSecond.jobs | Where-Object { [string]$_.source_id -eq 'source:example_ag_ats' })[0]
Assert-True -Condition ($careerJob.status -eq 'REMOVED') -Message 'Quellbezogene Entfernung markiert den betroffenen Quelljob nicht als REMOVED.'
Assert-True -Condition ($atsJob.status -ne 'REMOVED') -Message 'Quellbezogene Entfernung hat den Job einer anderen Quelle faelschlich entfernt.'

$closedFirst = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260825T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260825T100000Z' -Suffix 'closed-first')) `
    -ObservedAt ([datetime]'2026-08-25T10:00:00Z')
$closedRaw = New-TestRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123'
$closedRaw | Add-Member -NotePropertyName source_status -NotePropertyValue 'CLOSED' -Force
$closedSecond = Invoke-JobAgentStatusMachine `
    -Document $closedFirst `
    -ScanRunId 'scanrun:20260826T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260826T100000Z' -RawJobs @($closedRaw) -Suffix 'closed-second')) `
    -ObservedAt ([datetime]'2026-08-26T10:00:00Z')
Assert-True -Condition ($closedSecond.jobs[0].status -eq 'CLOSED') -Message 'Explizites Closed-Signal setzt Status nicht auf CLOSED.'
Assert-True -Condition (@($closedSecond.change_events | Where-Object event_type -eq 'JOB_CLOSED').Count -eq 1) -Message 'Explizites Closed-Signal erzeugt kein JOB_CLOSED.'

$publishedRaw = New-TestRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123'
$publishedRaw | Add-Member -NotePropertyName published_at -NotePropertyValue '2026-08-01T08:30:00+02:00'
$publishedFirst = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260827T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260827T100000Z' -RawJobs @($publishedRaw) -Suffix 'published-first')) `
    -ObservedAt ([datetime]'2026-08-27T10:00:00Z')
Assert-True -Condition ($publishedFirst.jobs[0].published_at -eq '2026-08-01T06:30:00.000Z') -Message 'Belegtes Publikationsdatum wird nicht normalisiert gespeichert.'

$publishedUnchanged = New-TestRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/head-it-123' -ExternalJobId '123'
$publishedSecond = Invoke-JobAgentStatusMachine `
    -Document $publishedFirst `
    -ScanRunId 'scanrun:20260828T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260828T100000Z' -RawJobs @($publishedUnchanged) -Suffix 'published-second')) `
    -ObservedAt ([datetime]'2026-08-28T10:00:00Z')
Assert-True -Condition ($publishedSecond.jobs[0].published_at -eq '2026-08-01T06:30:00.000Z') -Message 'Fehlendes Publikationsdatum darf vorhandenen Quellenwert nicht loeschen.'

$dateOnlyRaw = New-TestRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/head-it-124' -ExternalJobId '124'
$dateOnlyRaw | Add-Member -NotePropertyName published_at -NotePropertyValue '2026-08-01'
$dateOnly = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260829T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260829T100000Z' -RawJobs @($dateOnlyRaw) -Suffix 'published-date-only')) `
    -ObservedAt ([datetime]'2026-08-29T10:00:00Z')
Assert-True -Condition (($dateOnly.jobs[0].PSObject.Properties.Name -notcontains 'published_at') -and ($dateOnly.jobs[0].published_on -eq '2026-08-01')) -Message 'Tagesgenaues Quelldatum darf nicht als Mitternachtszeitpunkt gespeichert werden.'

$offsetMissingRaw = New-TestRawJob -Title 'Head of IT' -DetailUrl 'https://example.invalid/careers/head-it-125' -ExternalJobId '125'
$offsetMissingRaw | Add-Member -NotePropertyName published_at -NotePropertyValue '2026-08-01T10:00:00'
$offsetMissing = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260830T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260830T100000Z' -RawJobs @($offsetMissingRaw) -Suffix 'published-offset-missing')) `
    -ObservedAt ([datetime]'2026-08-30T10:00:00Z')
Assert-True -Condition (($offsetMissing.jobs[0].PSObject.Properties.Name -notcontains 'published_at') -and ($offsetMissing.jobs[0].PSObject.Properties.Name -notcontains 'published_on')) -Message 'Zeitpunkt ohne Offset darf nicht als belegte Publikationszeit gespeichert werden.'

$enrichedFirst = Invoke-JobAgentStatusMachine `
    -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')) `
    -ScanRunId 'scanrun:20260831T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260831T100000Z' -RawJobs @((New-TestRawJob -WorkTime 'VOLLZEIT' -Requirements @('ITIL') -Salary '90000 EUR')) -Suffix 'enriched-first')) `
    -ObservedAt ([datetime]'2026-08-31T10:00:00Z')
$enrichedSecond = Invoke-JobAgentStatusMachine `
    -Document $enrichedFirst `
    -ScanRunId 'scanrun:20260901T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260901T100000Z' -RawJobs @((New-TestRawJob -WorkTime 'TEILZEIT' -Requirements @('ITIL', 'CISSP') -Salary '100000 EUR')) -Suffix 'enriched-second')) `
    -ObservedAt ([datetime]'2026-09-01T10:00:00Z')
$enrichedEvent = @($enrichedSecond.change_events | Where-Object { $_.scan_run_id -eq 'scanrun:20260901T100000Z' })[0]
Assert-True -Condition ((@($enrichedEvent.changed_fields) -join ',') -match 'work_time' -and (@($enrichedEvent.changed_fields) -join ',') -match 'requirements' -and (@($enrichedEvent.changed_fields) -join ',') -match 'salary') -Message 'Archivierte Fachfelder muessen als ein JOB_UPDATED-Event erkannt werden.'
Assert-True -Condition ($enrichedSecond.job_snapshots[-1].work_time -eq 'TEILZEIT' -and (@($enrichedSecond.job_snapshots[-1].requirements) -join ',') -eq 'ITIL,CISSP' -and $enrichedSecond.job_snapshots[-1].salary -eq '100000 EUR') -Message 'Neue Snapshots muessen Arbeitszeit, Anforderungen und Gehalt vollstaendig archivieren.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'first_run_new',
        'second_run_active',
        'updated_run_changed_fields',
        'description_changed_fields',
        'failed_scan_no_removal',
        'successful_empty_scan_removed',
        'incomplete_success_no_removal',
        'failed_or_partial_scan_does_not_advance_last_seen',
        'reappeared_job_reactivated',
        'updated_classification_and_work_fields',
        'separate_validity_and_regional_scope',
        'invalid_hit_invalidated',
        'navigation_entry_invalidated',
        'source_scoped_removal',
        'explicit_closed_signal',
        'published_at_normalization_and_retention',
        'published_date_precision_and_missing_offset',
        'snapshot_archives_whitelisted_job_content_fields'
    )
} | ConvertTo-Json -Depth 4
