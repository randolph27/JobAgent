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
        city = if ($Label -eq 'UNKNOWN') { 'UNKNOWN' } else { 'Muenchen' }
        region = if ($Label -eq 'UNKNOWN') { 'UNKNOWN' } else { 'Bayern' }
        country = 'DE'
        target_area = if ($Label -eq 'UNKNOWN') { 'UNKNOWN' } else { 'MUNICH' }
    }
}

function New-TestClassification {
    param(
        [Parameter(Mandatory)][string]$Result,
        [Parameter(Mandatory)][string]$Priority,
        [Parameter(Mandatory)][int]$Score,
        [Parameter()][string[]]$Reasons = @()
    )

    [pscustomobject]@{
        result = $Result
        priority = $Priority
        score = $Score
        reasons = @($Reasons)
        rejected_reasons = @()
        evaluated_at = '2026-08-17T10:00:00.000Z'
    }
}

function New-TestJob {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Priority,
        [Parameter(Mandatory)][int]$Score,
        [Parameter()][string]$Location = 'Muenchen',
        [Parameter()][string]$WorkModel = 'UNKNOWN',
        [Parameter()][string]$EmploymentType = 'UNKNOWN',
        [Parameter()][string[]]$Requirements = @(),
        [Parameter()][string]$Description = 'Offizielle Kurzbeschreibung mit Aufgaben und Verantwortung.'
    )

    [pscustomobject]@{
        job_id = $Id
        company_id = $CompanyId
        official_url = "https://$($CompanyId.Substring(8)).example.invalid/jobs/$($Id.Substring(4))"
        alternative_official_urls = @()
        source_id = "source:$($CompanyId.Substring(8))_career"
        external_job_id = $Id.Substring(4)
        ats_job_id = 'UNKNOWN'
        title = $Title
        location = New-TestLocation -Label $Location
        work_model = $WorkModel
        employment_type = $EmploymentType
        description = $Description
        description_source = if ($Description -eq 'UNKNOWN') { 'NONE' } else { 'OFFICIAL_SOURCE' }
        status = $Status
        published_at = 'UNKNOWN'
        first_seen = '2026-08-17T10:00:00.000Z'
        last_seen = '2026-08-17T10:00:00.000Z'
        changed_at = '2026-08-17T10:00:00.000Z'
        classification = New-TestClassification -Result 'MATCH' -Priority $Priority -Score $Score -Reasons @('IT-Gesamtverantwortung ist belegt.', 'Standort liegt im Zielgebiet.')
        priority = $Priority
        requirements = @($Requirements)
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

function New-TestCompany {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$CreatedAt
    )

    [pscustomobject]@{
        company_id = $Id
        canonical_name = $Name
        canonical_domain = "$($Id.Substring(8)).example.invalid"
        official_website_url = "https://$($Id.Substring(8)).example.invalid/"
        career_url = "https://$($Id.Substring(8)).example.invalid/careers"
        aliases = @()
        locations = @(New-TestLocation -Label 'Muenchen')
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 80
        next_scan_at = '2026-08-18T10:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = [pscustomobject]@{
            type = 'OFFICIAL_WEBSITE'
            url = "https://$($Id.Substring(8)).example.invalid/"
            observed_at = $CreatedAt
            verification_url = "https://$($Id.Substring(8)).example.invalid/careers"
            discovery_origin = 'seed.manual'
            target_area = 'MUNICH'
            industry_hint = 'UNKNOWN'
            evidence_note = 'Offizielle Firmenquelle wurde manuell gepflegt.'
        }
        created_at = $CreatedAt
        updated_at = $CreatedAt
        last_successful_scan_at = $CreatedAt
    }
}

$scanRunId = 'scanrun:20260817T100000000Z'
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$document.companies = @(
    New-TestCompany -Id 'company:alpha_ag' -Name 'Alpha AG' -CreatedAt '2026-08-01T08:00:00.000Z'
    New-TestCompany -Id 'company:beta_ag' -Name 'Beta AG' -CreatedAt '2026-08-17T10:05:00.000Z'
)
$document.jobs = @(
    New-TestJob -Id 'job:alpha_new' -CompanyId 'company:alpha_ag' -Title 'Head of IT' -Status 'NEW' -Priority 'A' -Score 91 -WorkModel 'HYBRID' -EmploymentType 'FULL_TIME' -Requirements @('Budgetverantwortung')
    New-TestJob -Id 'job:alpha_active' -CompanyId 'company:alpha_ag' -Title 'IT Director' -Status 'ACTIVE' -Priority 'B' -Score 78
    New-TestJob -Id 'job:alpha_updated' -CompanyId 'company:alpha_ag' -Title 'Head of Information Technology' -Status 'UPDATED' -Priority 'B' -Score 83 -Location 'UNKNOWN' -Description 'UNKNOWN'
    New-TestJob -Id 'job:beta_removed' -CompanyId 'company:beta_ag' -Title 'CIO' -Status 'REMOVED' -Priority 'A' -Score 96
    New-TestJob -Id 'job:beta_rejected' -CompanyId 'company:beta_ag' -Title 'Software Engineer' -Status 'NEW' -Priority 'UNRATED' -Score 0
)
$document.jobs[0].published_at = '2026-08-10T08:00:00.000Z'
$document.jobs[0].salary = '120000 EUR'
$document.jobs[2].source_id = 'source:alpha_ag_ats'
$document.jobs[4].classification = New-TestClassification -Result 'REJECTED' -Priority 'UNRATED' -Score 0 -Reasons @()
$document.job_sources = @(
    [pscustomobject]@{ source_id = 'source:alpha_ag_career'; company_id = 'company:alpha_ag'; source_type = 'CAREER_PAGE'; url = 'https://alpha_ag.example.invalid/careers'; canonical_url = 'https://alpha_ag.example.invalid/careers'; is_official = $true; verified_at = '2026-08-17T09:00:00.000Z'; verification_basis = 'CAREER_URL'; verification_evidence = @([pscustomobject]@{ status = 'VERIFIED'; evidence_type = 'CAREER_URL'; url = 'https://alpha_ag.example.invalid/careers'; basis_url = 'https://alpha_ag.example.invalid/'; redirect_chain = @(); observed_at = '2026-08-17T09:00:00.000Z'; reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.' }) }
    [pscustomobject]@{ source_id = 'source:alpha_ag_ats'; company_id = 'company:alpha_ag'; source_type = 'OFFICIAL_ATS'; url = 'https://jobs.alpha_ag.example.invalid/search'; canonical_url = 'https://jobs.alpha_ag.example.invalid/search'; is_official = $true; verified_at = '2026-08-17T09:00:00.000Z'; verification_basis = 'COMPANY_LINKED_ATS'; verification_evidence = @([pscustomobject]@{ status = 'VERIFIED'; evidence_type = 'COMPANY_LINKED_ATS'; url = 'https://jobs.alpha_ag.example.invalid/search'; basis_url = 'https://alpha_ag.example.invalid/careers'; redirect_chain = @(); observed_at = '2026-08-17T09:00:00.000Z'; reason = 'ATS-Quelle wurde ueber Karriere-URL belegt.' }) }
    [pscustomobject]@{ source_id = 'source:beta_ag_career'; company_id = 'company:beta_ag'; source_type = 'CAREER_PAGE'; url = 'https://beta_ag.example.invalid/careers'; canonical_url = 'https://beta_ag.example.invalid/careers'; is_official = $true; verified_at = '2026-08-17T09:00:00.000Z'; verification_basis = 'CAREER_URL'; verification_evidence = @([pscustomobject]@{ status = 'VERIFIED'; evidence_type = 'CAREER_URL'; url = 'https://beta_ag.example.invalid/careers'; basis_url = 'https://beta_ag.example.invalid/'; redirect_chain = @(); observed_at = '2026-08-17T09:00:00.000Z'; reason = 'Karriere-URL wurde als offizielle Firmenquelle gepflegt.' }) }
)
$document.scan_runs = @([pscustomobject]@{
        scan_run_id = $scanRunId
        started_at = '2026-08-17T10:00:00.000Z'
        finished_at = '2026-08-17T10:10:00.000Z'
        status = 'PARTIAL'
        company_ids = @('company:alpha_ag', 'company:beta_ag')
        artifact_paths = @('logs/jobagent/daily-run-test.json')
        errors = @()
    })
$document.scan_attempts = @(
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:alpha'; scan_run_id = $scanRunId; company_id = 'company:alpha_ag'; source_id = 'source:alpha_ag_career'; started_at = '2026-08-17T10:00:00.000Z'; finished_at = '2026-08-17T10:00:01.000Z'; status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200 }
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:beta'; scan_run_id = $scanRunId; company_id = 'company:beta_ag'; source_id = 'source:beta_ag_career'; started_at = '2026-08-17T10:00:00.000Z'; finished_at = '2026-08-17T10:00:01.000Z'; status = 'FAILED'; adapter = 'fixture'; error_class = 'NOT_REACHABLE'; retry_recommendation = 'RETRY_NEXT_RUN'; http_status = 503 }
)
$document.job_snapshots = @(
    [pscustomobject]@{ snapshot_id = 'snapshot:alpha_new'; job_id = 'job:alpha_new'; scan_run_id = $scanRunId; source_id = 'source:alpha_ag_career'; captured_at = '2026-08-17T10:00:00.000Z'; content_hash = ('a' * 64); status = 'NEW'; title = 'Head of IT'; location = New-TestLocation -Label 'Muenchen'; official_url = 'https://alpha.example.invalid/jobs/alpha_new'; summary = 'Fuehrung.' }
    [pscustomobject]@{ snapshot_id = 'snapshot:alpha_updated'; job_id = 'job:alpha_updated'; scan_run_id = $scanRunId; source_id = 'source:alpha_ag_career'; captured_at = '2026-08-17T10:00:00.000Z'; content_hash = ('b' * 64); status = 'UPDATED'; title = 'Head of Information Technology'; location = New-TestLocation -Label 'UNKNOWN'; official_url = 'https://alpha.example.invalid/jobs/alpha_updated'; summary = 'Strategie.' }
)
$document.change_events = @(
    [pscustomobject]@{ change_event_id = 'change:alpha_new'; job_id = 'job:alpha_new'; scan_run_id = $scanRunId; event_type = 'JOB_CREATED'; created_at = '2026-08-17T10:00:00.000Z'; old_status = $null; new_status = 'NEW'; changed_fields = @('status'); reason = 'Erstmals erkannt.' }
    [pscustomobject]@{ change_event_id = 'change:alpha_updated'; job_id = 'job:alpha_updated'; scan_run_id = $scanRunId; event_type = 'JOB_UPDATED'; created_at = '2026-08-17T10:00:00.000Z'; old_status = 'ACTIVE'; new_status = 'UPDATED'; changed_fields = @('title', 'status'); reason = 'Titel geaendert.' }
    [pscustomobject]@{ change_event_id = 'change:beta_removed'; job_id = 'job:beta_removed'; scan_run_id = $scanRunId; event_type = 'JOB_REMOVED'; created_at = '2026-08-17T10:00:00.000Z'; old_status = 'ACTIVE'; new_status = 'REMOVED'; changed_fields = @('status'); reason = 'Nicht mehr auffindbar.' }
    [pscustomobject]@{ change_event_id = 'change:beta_rejected'; job_id = 'job:beta_rejected'; scan_run_id = $scanRunId; event_type = 'JOB_CREATED'; created_at = '2026-08-17T10:00:00.000Z'; old_status = $null; new_status = 'NEW'; changed_fields = @('status'); reason = 'Erstmals erkannt.' }
)

$report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
Assert-True -Condition (@($report.sections.new_matching_jobs).Count -eq 1) -Message 'Neue passende Stellen werden nicht korrekt gefiltert.'
Assert-True -Condition (@($report.sections.active_matching_jobs).Count -eq 1) -Message 'Unveraenderte aktive passende Stellen werden nicht kompakt getrennt ausgegeben.'
Assert-True -Condition (@($report.sections.changed_jobs).Count -eq 1) -Message 'Geaenderte passende Stellen fehlen.'
Assert-True -Condition (@($report.sections.closed_or_removed_jobs).Count -eq 1) -Message 'Entfernte passende Stellen fehlen.'
Assert-True -Condition (@($report.sections.new_companies).Count -eq 1) -Message 'Neue Unternehmen im Lauf werden nicht erkannt.'
Assert-True -Condition (@($report.sections.source_issues).Count -eq 1) -Message 'Fehler oder unsichere Quellen fehlen im Report.'
Assert-True -Condition ($report.statistics.errors -eq 1) -Message 'Recherche-Statistik zaehlt Adapterfehler nicht.'
Assert-True -Condition ($report.statistics.checked_jobs -eq 2) -Message 'Recherche-Statistik zaehlt gepruefte Stellen falsch.'
Assert-True -Condition ($report.statistics.active_matching_jobs -eq 1) -Message 'Recherche-Statistik zaehlt aktive passende Stellen falsch.'
Assert-True -Condition ($report.statistics.new_companies -eq 1) -Message 'Recherche-Statistik zaehlt neue Unternehmen falsch.'
Assert-True -Condition ($report.statistics.unreachable_career_pages -eq 1) -Message 'Nicht erreichbare Karriereportale werden nicht ausgewiesen.'
Assert-True -Condition ([string]$report.sections.changed_jobs[0].location -eq 'UNKNOWN') -Message 'Fehlende optionale Felder muessen UNKNOWN bleiben.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].priority_explanation -match 'Prioritaet A') -Message 'A/B/C-Priorisierung wird nicht erklaert.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].published_at -eq '2026-08-10T08:00:00.000Z') -Message 'Veroeffentlichungsdatum fehlt im Reporteintrag.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].salary -eq '120000 EUR') -Message 'Gehalt fehlt im Reporteintrag.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].requirements_text -match 'Budgetverantwortung') -Message 'Wichtigste Anforderungen fehlen im Reporteintrag.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].description -match 'Offizielle Kurzbeschreibung') -Message 'Kurzbeschreibung fehlt im Reporteintrag.'
Assert-True -Condition ($report.sections.changed_jobs[0].description -eq 'Keine Beschreibung aus offizieller Quelle verfuegbar') -Message 'Fehlende Beschreibung braucht stabilen Leerwert.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].age_basis -eq 'published_at') -Message 'Altersbasis fuer aktive Stellen ist falsch.'
Assert-True -Condition ([int]$report.sections.new_matching_jobs[0].age_days -ge 7) -Message 'Alter der Stelle wird nicht berechnet.'
Assert-True -Condition ($report.sections.source_issues[0].category -eq 'NICHT_ERREICHBAR') -Message 'Fehlerkategorie fuer nicht erreichbare Karriereportale ist falsch.'
Assert-True -Condition ($report.sections.new_matching_jobs[0].provider_url -eq 'https://alpha_ag.example.invalid/careers') -Message 'Provider-Link nutzt nicht die offizielle Karrierequelle.'
Assert-True -Condition ($report.sections.changed_jobs[0].provider_url -eq 'https://jobs.alpha_ag.example.invalid/search') -Message 'Provider-Link bevorzugt nicht die offizielle ATS-Quelle der Stelle.'

$markdown = ConvertTo-JobAgentDailyReportMarkdown -Report $report
foreach ($expected in @('## Neue passende Stellen', '## Aktive passende Stellen', '## Aenderungen', '## Geschlossene oder entfernte Stellen', '## Neue Unternehmen', '## Fehler und unsichere Quellen', '## Recherche-Statistik', '### Quellenbestand', 'Quellen gesamt', 'Offizielle Quellen', 'Im letzten Lauf gescannt', '| Titel | Firma | Standort | Prioritaet | Status | Offizielle Stellen-URL | Karriere-URL | Quelle |', '120000 EUR', 'Budgetverantwortung', 'Kurzprofil', 'Offizielle Kurzbeschreibung mit Aufgaben und Verantwortung.', 'Keine Beschreibung aus offizieller Quelle verfuegbar', 'Veroeffentlicht', '[Quelle](https://beta_ag.example.invalid/careers)', '[Offizielle Stellen-URL](https://alpha_ag.example.invalid/jobs/alpha_new)', '[Karriere-URL](https://alpha_ag.example.invalid/careers)', '[Karriere](https://alpha_ag.example.invalid/careers)', '[ATS](https://jobs.alpha_ag.example.invalid/search)')) {
    Assert-True -Condition ($markdown.Contains($expected)) -Message "Markdown-Report enthaelt erwarteten Inhalt nicht: $expected"
}
Assert-True -Condition (-not $markdown.Contains('Software Engineer')) -Message 'Abgelehnte Stellen duerfen nicht als passende Stellen gerendert werden.'
foreach ($rawLabel in @('checked_jobs', 'active_matching_jobs', 'uncertain_sources', 'unreachable_career_pages', 'published_at')) {
    Assert-True -Condition (-not $markdown.Contains($rawLabel)) -Message "Markdown-Report darf technische Metriklabels nicht primaer anzeigen: $rawLabel"
}

$report.sections.new_matching_jobs[0].title = '<script>alert(1)</script>'
$report.sections.new_matching_jobs[0].description = '<img src=x onerror=alert(1)>Beschreibung'
$html = ConvertTo-JobAgentDailyReportHtml -Report $report
foreach ($expected in @('<!DOCTYPE html>', '<h2>Neue passende Stellen</h2>', '<h2>Fehler und unsichere Quellen</h2>', '<h3>Quellenbestand</h3>', 'Quellen gesamt', 'Offizielle Quellen', 'Im letzten Lauf gescannt', 'JobAgent Daily-Run-Bericht', '<th>Titel</th><th>Firma</th><th>Standort</th><th>Prioritaet</th><th>Status</th><th>Offizielle Stellen-URL</th><th>Karriere-URL</th><th>Quelle</th>', '120000 EUR', 'Budgetverantwortung', 'Kurzprofil', 'Beschreibung', 'href="https://beta_ag.example.invalid/careers" target="_blank" rel="noopener noreferrer">Quelle</a>', 'href="https://alpha_ag.example.invalid/jobs/alpha_new" target="_blank" rel="noopener noreferrer">Offizielle Stellen-URL</a>', 'href="https://alpha_ag.example.invalid/careers" target="_blank" rel="noopener noreferrer">Karriere-URL</a>', 'href="https://alpha_ag.example.invalid/careers" target="_blank" rel="noopener noreferrer">Karriere</a>', 'href="https://jobs.alpha_ag.example.invalid/search" target="_blank" rel="noopener noreferrer">ATS</a>')) {
    Assert-True -Condition ($html.Contains($expected)) -Message "HTML-Report enthaelt erwarteten Inhalt nicht: $expected"
}
Assert-True -Condition (-not $html.Contains('<script>alert(1)</script>')) -Message 'HTML-Report muss unescaped Script-Titel verhindern.'
Assert-True -Condition ($html.Contains('&lt;script&gt;alert(1)&lt;/script&gt;')) -Message 'HTML-Report escaped problematische Inhalte nicht.'
Assert-True -Condition (-not $html.Contains('<img src=x onerror=alert(1)>')) -Message 'HTML-Report muss unsanitisiertes Beschreibungs-Markup escapen.'
foreach ($rawLabel in @('checked_jobs', 'active_matching_jobs', 'uncertain_sources', 'unreachable_career_pages', 'published_at')) {
    Assert-True -Condition (-not $html.Contains($rawLabel)) -Message "HTML-Report darf technische Metriklabels nicht primaer anzeigen: $rawLabel"
}

$document.job_sources += [pscustomobject]@{ source_id = 'source:beta_ag_board'; company_id = 'company:beta_ag'; source_type = 'JOB_BOARD_DISCOVERY'; url = 'https://jobs.example.invalid/beta'; canonical_url = 'https://jobs.example.invalid/beta'; is_official = $false; verified_at = $null; verification_basis = 'DISCOVERY_HINT'; verification_evidence = @() }
$document.scan_attempts += [pscustomobject]@{ scan_attempt_id = 'scanattempt:beta-board'; scan_run_id = $scanRunId; company_id = 'company:beta_ag'; source_id = 'source:beta_ag_board'; started_at = '2026-08-17T10:00:00.000Z'; finished_at = '2026-08-17T10:00:01.000Z'; status = 'FAILED'; adapter = 'fixture'; error_class = 'TECHNICAL_LIMITATION'; retry_recommendation = 'MANUAL_REVIEW'; http_status = 599 }
$issueReport = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
$unofficialIssue = @($issueReport.sections.source_issues | Where-Object { [string]$_.source_id -eq 'source:beta_ag_board' })[0]
Assert-True -Condition (-not [bool]$unofficialIssue.source_link.is_clickable) -Message 'Unoffizielle Quellen-Issues duerfen nicht klickbar sein.'
Assert-True -Condition ($unofficialIssue.source_review_reason -match 'nicht als offizielle JobSource') -Message 'Unoffizielle Quellen-Issues brauchen einen Review-Grund.'
$issueMarkdown = ConvertTo-JobAgentDailyReportMarkdown -Report $issueReport
$issueHtml = ConvertTo-JobAgentDailyReportHtml -Report $issueReport
Assert-True -Condition (-not $issueMarkdown.Contains('[Quelle](https://jobs.example.invalid/beta)')) -Message 'Markdown darf unoffizielle Quellen nicht verlinken.'
Assert-True -Condition (-not $issueHtml.Contains('href="https://jobs.example.invalid/beta"')) -Message 'HTML darf unoffizielle Quellen nicht verlinken.'

$empty = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$empty.scan_runs = @($document.scan_runs[0])
$emptyReport = New-JobAgentDailyReport -Document $empty -ScanRunId $scanRunId
$emptyMarkdown = ConvertTo-JobAgentDailyReportMarkdown -Report $emptyReport
Assert-True -Condition ($emptyMarkdown.Contains('Keine neuen passenden Stellen im Lauf.')) -Message 'Leere Reports erhalten keinen stabilen Leerzustand.'
$emptyHtml = ConvertTo-JobAgentDailyReportHtml -Report $emptyReport
Assert-True -Condition ($emptyHtml.Contains('Keine neuen passenden Stellen im Lauf.')) -Message 'Leere HTML-Reports erhalten keinen stabilen Leerzustand.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'report_sections_for_new_active_changed_removed_and_new_companies',
        'report_filters_rejected_jobs',
        'report_explains_a_b_c_priority',
        'report_preserves_unknown_optional_values',
        'report_renders_markdown_and_html',
        'report_renders_source_inventory_metrics',
        'report_renders_secure_job_provider_and_source_links',
        'report_blocks_unofficial_source_issue_links',
        'report_escapes_html_content',
        'report_renders_empty_state'
    )
} | ConvertTo-Json -Depth 4
