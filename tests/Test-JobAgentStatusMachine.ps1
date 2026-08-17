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
        [string]$LocationLabel = 'Muenchen'
    )

    [pscustomobject]@{
        title = $Title
        detail_url = $DetailUrl
        external_job_id = $ExternalJobId
        ats_job_id = 'UNKNOWN'
        location_label = $LocationLabel
        summary = $Summary
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
        [string]$SourceId = 'source:example_ag_career'
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
        [string]$OfficialSourceUrl = 'https://example.invalid/careers'
    )

    [pscustomobject]@{
        adapter = 'fixture-adapter'
        company_id = $CompanyId
        source_id = $SourceId
        official_source_url = $OfficialSourceUrl
        status = $Status
        error_class = $ErrorClass
        retry_recommendation = if ($ErrorClass -eq 'NONE') { 'NONE' } else { 'RETRY_NEXT_RUN' }
        raw_jobs = @($RawJobs)
        scan_attempt = New-TestScanAttempt -ScanRunId $ScanRunId -Status $Status -ErrorClass $ErrorClass -Suffix $Suffix -CompanyId $CompanyId -SourceId $SourceId
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

$failed = Invoke-JobAgentStatusMachine `
    -Document $third `
    -ScanRunId 'scanrun:20260820T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260820T100000Z' -RawJobs @() -Status 'FAILED' -ErrorClass 'TIMEOUT' -Suffix 'failed')) `
    -ObservedAt ([datetime]'2026-08-20T10:00:00Z')
Assert-True -Condition ($failed.jobs[0].status -eq 'UPDATED') -Message 'Fehlgeschlagener Scan hat bestehenden Job faelschlich entfernt oder geaendert.'
Assert-True -Condition (@($failed.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 0) -Message 'Fehlgeschlagener Scan erzeugt faelschlich JOB_REMOVED.'

$removed = Invoke-JobAgentStatusMachine `
    -Document $failed `
    -ScanRunId 'scanrun:20260821T100000Z' `
    -AdapterResults @((New-TestAdapterResult -ScanRunId 'scanrun:20260821T100000Z' -RawJobs @() -Status 'SUCCESS' -ErrorClass 'NONE' -Suffix 'empty_success')) `
    -ObservedAt ([datetime]'2026-08-21T10:00:00Z')
Assert-True -Condition ($removed.jobs[0].status -eq 'REMOVED') -Message 'Erfolgreicher leerer Scan setzt fehlenden Job nicht auf REMOVED.'
Assert-True -Condition (@($removed.change_events | Where-Object event_type -eq 'JOB_REMOVED').Count -eq 1) -Message 'Erfolgreiche Entfernung erzeugt kein JOB_REMOVED.'

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

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'first_run_new',
        'second_run_active',
        'updated_run_changed_fields',
        'failed_scan_no_removal',
        'successful_empty_scan_removed',
        'invalid_hit_invalidated',
        'source_scoped_removal',
        'explicit_closed_signal'
    )
} | ConvertTo-Json -Depth 4
