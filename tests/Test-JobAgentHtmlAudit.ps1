#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function New-TestLocation {
    param([Parameter(Mandatory)][string]$Label)

    [pscustomobject]@{
        label = $Label
        city = 'Muenchen'
        region = 'Bayern'
        country = 'DE'
        target_area = 'MUNICH'
    }
}

function New-TestClassification {
    param(
        [Parameter(Mandatory)][string]$Result,
        [Parameter(Mandatory)][string]$Priority,
        [Parameter(Mandatory)][int]$Score
    )

    [pscustomobject]@{
        result = $Result
        priority = $Priority
        score = $Score
        reasons = @(
            'IT-Gesamtverantwortung ist belegt.',
            'Standort liegt im Zielgebiet.'
        )
        rejected_reasons = @()
        evaluated_at = '2026-08-17T10:00:00.000Z'
    }
}

$scanRunId = 'scanrun:html-audit'
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$document.companies = @(
    [pscustomobject]@{
        company_id = 'company:alpha_ag'
        canonical_name = 'Alpha AG'
        canonical_domain = 'alpha.example.invalid'
        official_website_url = 'https://alpha.example.invalid/'
        career_url = 'https://alpha.example.invalid/careers'
        aliases = @()
        locations = @(New-TestLocation -Label 'Muenchen')
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 90
        next_scan_at = '2026-08-18T10:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = $null
        created_at = '2026-08-17T08:00:00.000Z'
        updated_at = '2026-08-17T08:00:00.000Z'
        last_successful_scan_at = '2026-08-17T08:00:00.000Z'
    }
)
$document.job_sources = @(
    [pscustomobject]@{
        source_id = 'source:alpha_ag_career'
        company_id = 'company:alpha_ag'
        source_type = 'CAREER_PAGE'
        url = 'https://alpha.example.invalid/careers'
        canonical_url = 'https://alpha.example.invalid/careers'
        is_official = $true
        verified_at = '2026-08-17T09:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @()
    }
)
$document.jobs = @(
    [pscustomobject]@{
        job_id = 'job:alpha_long'
        company_id = 'company:alpha_ag'
        official_url = 'https://alpha.example.invalid/jobs/head-it'
        alternative_official_urls = @()
        source_id = 'source:alpha_ag_career'
        external_job_id = 'head-it'
        ats_job_id = 'UNKNOWN'
        title = 'Head of IT mit sehr langem Titel fuer responsiven Layouttest und Ueberlaufpruefung'
        location = New-TestLocation -Label 'Muenchen'
        work_model = 'HYBRID'
        employment_type = 'FULL_TIME'
        status = 'NEW'
        published_at = '2026-08-10T08:00:00.000Z'
        first_seen = '2026-08-17T10:00:00.000Z'
        last_seen = '2026-08-17T10:00:00.000Z'
        changed_at = '2026-08-17T10:00:00.000Z'
        classification = New-TestClassification -Result 'MATCH' -Priority 'A' -Score 96
        priority = 'A'
        requirements = @(
            'Budgetverantwortung fuer einen europaweit verteilten IT-Betrieb mit langen Freitexten zur Layoutpruefung',
            'Fuehrung mehrerer Plattformteams'
        )
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
)
$document.scan_runs = @(
    [pscustomobject]@{
        scan_run_id = $scanRunId
        started_at = '2026-08-17T10:00:00.000Z'
        finished_at = '2026-08-17T10:10:00.000Z'
        status = 'SUCCESS'
        company_ids = @('company:alpha_ag')
        artifact_paths = @()
        errors = @()
    }
)
$document.scan_attempts = @(
    [pscustomobject]@{
        scan_attempt_id = 'scanattempt:alpha'
        scan_run_id = $scanRunId
        company_id = 'company:alpha_ag'
        source_id = 'source:alpha_ag_career'
        started_at = '2026-08-17T10:00:00.000Z'
        finished_at = '2026-08-17T10:00:01.000Z'
        status = 'SUCCESS'
        adapter = 'fixture'
        error_class = 'NONE'
        retry_recommendation = 'NONE'
        http_status = 200
    }
)
$document.job_snapshots = @(
    [pscustomobject]@{
        snapshot_id = 'snapshot:alpha_long'
        job_id = 'job:alpha_long'
        scan_run_id = $scanRunId
        source_id = 'source:alpha_ag_career'
        captured_at = '2026-08-17T10:00:00.000Z'
        content_hash = ('a' * 64)
        status = 'NEW'
        title = 'Head of IT mit sehr langem Titel fuer responsiven Layouttest und Ueberlaufpruefung'
        location = New-TestLocation -Label 'Muenchen'
        official_url = 'https://alpha.example.invalid/jobs/head-it'
        summary = 'Fuehrungsrolle.'
    }
)
$document.change_events = @(
    [pscustomobject]@{
        change_event_id = 'change:alpha_long'
        job_id = 'job:alpha_long'
        scan_run_id = $scanRunId
        event_type = 'JOB_CREATED'
        created_at = '2026-08-17T10:00:00.000Z'
        old_status = $null
        new_status = 'NEW'
        changed_fields = @('status')
        reason = 'Erstmals erkannt.'
    }
)

$report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
$html = ConvertTo-JobAgentDailyReportHtml -Report $report

foreach ($expected in @(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
        '.table-wrap { overflow-x: auto; }',
        'overflow-wrap: anywhere;',
        '@media (max-width: 800px)',
        '<h2>Neue passende Stellen</h2>',
        '<h2>Coverage und Adapter-Backlog</h2>',
        'Head of IT mit sehr langem Titel fuer responsiven Layouttest und Ueberlaufpruefung',
        'Budgetverantwortung fuer einen europaweit verteilten IT-Betrieb mit langen Freitexten zur Layoutpruefung'
    )) {
    Assert-True -Condition ($html.Contains($expected)) -Message "HTML-Audit findet Pflichtinhalt nicht: $expected"
}

Assert-True -Condition (-not ($html -match '<script\b[^>]*\bsrc=')) -Message 'HTML-Report darf keine externen Skripte einbinden.'
Assert-True -Condition (-not ($html -match '<link\b[^>]*\bhref=')) -Message 'HTML-Report darf keine externen Stylesheets einbinden.'
Assert-True -Condition (-not ($html -match '<img\b[^>]*\bsrc=')) -Message 'HTML-Report darf keine externen Bilder einbinden.'
Assert-True -Condition ($html -match '<a href="https://alpha\.example\.invalid/jobs/head-it" target="_blank" rel="noopener noreferrer">') -Message 'Offizielle Links muessen im HTML-Report erhalten bleiben.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'html_report_contains_required_sections',
        'html_report_uses_responsive_overflow_guards',
        'html_report_avoids_external_runtime_resources',
        'html_report_preserves_official_job_links'
    )
} | ConvertTo-Json -Depth 4
