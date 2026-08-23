#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestCoverageCompany {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter()][AllowNull()][string]$CareerUrl,
        [Parameter(Mandatory)][int]$Priority,
        [Parameter()][AllowNull()][string]$LastSuccessfulScanAt = $null,
        [Parameter()][object[]]$Ats = @()
    )

    $company = New-JobAgentCompanySeed `
        -CanonicalName $Name `
        -OfficialWebsiteUrl ('https://' + $Domain + '/') `
        -CareerUrl $CareerUrl `
        -Aliases @() `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'UNKNOWN' `
        -ScanPriority $Priority `
        -DiscoverySourceUrl ('https://' + $Domain + '/') `
        -CreatedAt ([datetime]'2026-08-01T00:00:00Z') `
        -NextScanAt ([datetime]'2026-08-17T00:00:00Z') `
        -Ats $Ats
    $company.last_successful_scan_at = $LastSuccessfulScanAt
    return $company
}

$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$document.companies = @(
    New-TestCoverageCompany -Name 'Unknown AG' -Domain 'unknown.example.invalid' -CareerUrl $null -Priority 60
    New-TestCoverageCompany -Name 'Failed AG' -Domain 'failed.example.invalid' -CareerUrl 'https://failed.example.invalid/careers' -Priority 70
    New-TestCoverageCompany -Name 'Stale AG' -Domain 'stale.example.invalid' -CareerUrl 'https://stale.example.invalid/careers' -Priority 80 -LastSuccessfulScanAt '2026-07-01T00:00:00.000Z'
    New-TestCoverageCompany -Name 'Recent AG' -Domain 'recent.example.invalid' -CareerUrl 'https://recent.example.invalid/careers' -Priority 90 -LastSuccessfulScanAt '2026-08-16T00:00:00.000Z'
    New-TestCoverageCompany -Name 'Match AG' -Domain 'match.example.invalid' -CareerUrl 'https://match.example.invalid/careers' -Priority 75 -LastSuccessfulScanAt '2026-08-16T00:00:00.000Z'
    (New-JobAgentCompanySeed `
        -CanonicalName 'Hint AG' `
        -OfficialWebsiteUrl 'https://hint.example.invalid/' `
        -CareerUrl 'https://hint.example.invalid/careers' `
        -Aliases @() `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'UNKNOWN' `
        -ScanPriority 65 `
        -DiscoverySourceUrl 'https://directory.example.invalid/hint' `
        -DiscoverySourceType 'DISCOVERY_HINT' `
        -DiscoveryOrigin 'directory.seed' `
        -DiscoveryEvidenceNote 'Sekundaerquelle, offizielle Verifikation fehlt.' `
        -CreatedAt ([datetime]'2026-08-01T00:00:00Z') `
        -NextScanAt ([datetime]'2026-08-17T00:00:00Z'))
)
$document.scan_attempts = @(
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:failed'; scan_run_id = 'scanrun:1'; company_id = 'company:failed_ag'; source_id = 'source:failed'; started_at = '2026-08-17T08:00:00.000Z'; finished_at = '2026-08-17T08:01:00.000Z'; status = 'FAILED'; adapter = 'fixture'; error_class = 'NOT_REACHABLE'; retry_recommendation = 'RETRY_NEXT_RUN'; http_status = 503 }
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:stale'; scan_run_id = 'scanrun:1'; company_id = 'company:stale_ag'; source_id = 'source:stale'; started_at = '2026-07-01T08:00:00.000Z'; finished_at = '2026-07-01T08:01:00.000Z'; status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200 }
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:recent'; scan_run_id = 'scanrun:1'; company_id = 'company:recent_ag'; source_id = 'source:recent'; started_at = '2026-08-16T08:00:00.000Z'; finished_at = '2026-08-16T08:01:00.000Z'; status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200 }
    [pscustomobject]@{ scan_attempt_id = 'scanattempt:match'; scan_run_id = 'scanrun:1'; company_id = 'company:match_ag'; source_id = 'source:match'; started_at = '2026-08-16T09:00:00.000Z'; finished_at = '2026-08-16T09:01:00.000Z'; status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200 }
)
$document.jobs = @(
    [pscustomobject]@{ job_id = 'job:match'; company_id = 'company:match_ag'; title = 'Head of IT'; status = 'ACTIVE'; priority = 'A'; official_url = 'https://match.example.invalid/jobs/head-it'; location = [pscustomobject]@{ label = 'Muenchen' }; classification = [pscustomobject]@{ result = 'MATCH'; score = 95; reasons = @('IT-Fuehrung') } }
)
$document.scan_runs = @(
    [pscustomobject]@{ scan_run_id = 'scanrun:1'; started_at = '2026-08-16T08:00:00.000Z'; finished_at = '2026-08-16T09:01:00.000Z'; status = 'PARTIAL'; company_ids = @('company:failed_ag', 'company:stale_ag', 'company:recent_ag', 'company:match_ag'); artifact_paths = @(); errors = @('NOT_REACHABLE') }
)
$document.change_events = @()

$coverage = New-JobAgentCoverageReport -Document $document -Now ([datetime]'2026-08-17T12:00:00Z') -StaleAfterDays 7 -MaxPriorityItems 5
Assert-True -Condition ($coverage.metrics.companies_total -eq 6) -Message 'Coverage zaehlt Firmen falsch.'
Assert-True -Condition ($coverage.metrics.without_career_url -eq 1) -Message 'Coverage zaehlt Firmen ohne Karriere-URL falsch.'
Assert-True -Condition ($coverage.metrics.failed_scanned -eq 1) -Message 'Coverage zaehlt fehlgeschlagene Portale falsch.'
Assert-True -Condition ($coverage.metrics.never_scanned -eq 2) -Message 'Coverage zaehlt nie gescannte Firmen falsch.'
Assert-True -Condition ($coverage.metrics.with_matching_jobs -eq 1) -Message 'Coverage zaehlt passende Stellen falsch.'
Assert-True -Condition ($coverage.approximation_notice -match 'keine vollstaendige Marktdeckung') -Message 'Coverage-Hinweis darf keine Vollstaendigkeit behaupten.'
Assert-True -Condition ($coverage.metrics.manual_review_required -eq 1) -Message 'Coverage zaehlt manuell zu pruefende Discovery-Hinweise falsch.'
Assert-True -Condition ($coverage.metrics.verified_without_career_url -eq 1) -Message 'Coverage zaehlt verifizierte Firmen ohne Karriere-URL falsch.'

$backlogKinds = @($coverage.backlog | ForEach-Object { [string]$_.kind })
Assert-True -Condition ($backlogKinds -contains 'MANUAL_REVIEW_DISCOVERY') -Message 'Backlog priorisiert unbestaetigte Discovery-Hinweise nicht.'
Assert-True -Condition ($backlogKinds -contains 'CAREER_URL_DISCOVERY') -Message 'Backlog priorisiert fehlende Karriere-URL nicht.'
Assert-True -Condition ($backlogKinds -contains 'ATS_OR_PORTAL_ADAPTER_REVIEW') -Message 'Backlog priorisiert fehlerhafte Portale nicht.'
Assert-True -Condition ($backlogKinds -contains 'STALE_SCAN_ROTATION') -Message 'Backlog priorisiert lange nicht gepruefte Firmen nicht.'
Assert-True -Condition ($backlogKinds -contains 'NO_MATCH_RECHECK') -Message 'Backlog behaelt erfolgreiche Firmen ohne Match nicht in Rotation.'

$priority = @($coverage.scan_priority)
Assert-True -Condition (($priority | Where-Object company_id -eq 'company:failed_ag').priority_score -gt ($priority | Where-Object company_id -eq 'company:recent_ag').priority_score) -Message 'Fehlerhafte Portale muessen vor kuerzlich erfolgreichen Scans priorisiert werden.'
Assert-True -Condition (@($priority | Where-Object company_id -eq 'company:unknown_ag').Count -eq 1) -Message 'Unbekannte Firmen muessen in der Scanprioritaet enthalten sein.'
Assert-True -Condition ((($priority | Where-Object company_id -eq 'company:hint_ag').next_action) -eq 'verify_discovery_hint') -Message 'Discovery-Hinweise muessen eigene Folgeaktion erhalten.'
Assert-True -Condition (@($priority | Where-Object { $_.company_id -eq 'company:recent_ag' -and (@($_.reasons) -contains 'recent_success_rotation_penalty') }).Count -eq 1) -Message 'Kuerzlich erfolgreiche Firmen muessen Rotationsmalus erhalten.'
Assert-True -Condition ((@($coverage.companies | Where-Object { $_.company_id -eq 'company:hint_ag' })[0].inventory_state) -eq 'MANUAL_REVIEW_REQUIRED') -Message 'Discovery-Hinweis wurde nicht als manueller Review-Fall markiert.'

$report = New-JobAgentDailyReport -Document $document -ScanRunId 'scanrun:1'
$markdown = ConvertTo-JobAgentDailyReportMarkdown -Report $report
Assert-True -Condition ($markdown.Contains('## Coverage und Adapter-Backlog')) -Message 'Markdown-Report enthaelt keinen Coverage-Abschnitt.'
Assert-True -Condition ($markdown.Contains('Coverage-Werte sind operative Naeherungen')) -Message 'Markdown-Report enthaelt keinen Naeherungshinweis.'
Assert-True -Condition ($markdown.Contains('ATS_OR_PORTAL_ADAPTER_REVIEW')) -Message 'Markdown-Report enthaelt keinen Adapter-Backlog.'
Assert-True -Condition ($markdown.Contains('MANUAL_REVIEW_DISCOVERY')) -Message 'Markdown-Report enthaelt keinen Discovery-Review-Backlog.'

$sourceRegistryPath = Join-Path $root 'data\jobagent\company-discovery.sources.json'
$sourceSchemaPath = Join-Path $root 'schemas\jobagent.discovery-source.schema.json'
$sourceRegistryJson = Get-Content -Raw -LiteralPath $sourceRegistryPath
$sourceSchemaJson = Get-Content -Raw -LiteralPath $sourceSchemaPath
Assert-True -Condition (Test-Json -Json $sourceRegistryJson -Schema $sourceSchemaJson) -Message 'Discovery-Quellenkatalog verletzt das JSON-Schema.'
$sourceRegistry = $sourceRegistryJson | ConvertFrom-Json -Depth 20
$sourceCoverage = New-JobAgentDiscoverySourceCoverageReport -SourceRegistry $sourceRegistry -Now ([datetime]'2026-08-23T08:30:00Z')
Assert-True -Condition ($sourceCoverage.sources_total -ge 10) -Message 'Discovery-Quellenkatalog enthaelt zu wenige Quellen.'
Assert-True -Condition ($sourceCoverage.class_counts.OFFICIAL_DIRECTORY -ge 2) -Message 'Offizielle Verzeichnisquellen werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.PUBLIC_JOBBOARD_HINT -ge 3) -Message 'Sekundaere Jobboersen-Hinweise werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.REGISTER_HINT -ge 2) -Message 'Register-Hinweise werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.REJECTED -ge 1) -Message 'Abgelehnte Quellen werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.importable_sources -ge 6) -Message 'Importierbare Quellen werden falsch gezaehlt.'
Assert-True -Condition ($sourceCoverage.manual_review_sources -ge 7) -Message 'Manual-Review-Quellen werden falsch gezaehlt.'
Assert-True -Condition ($sourceCoverage.verification_gap_sources -ge 8) -Message 'Offene Verifikationsluecken werden falsch gezaehlt.'
Assert-True -Condition (@($sourceCoverage.rejected_source_ids | Where-Object { $_ -eq 'source-registry:linkedin_jobs' }).Count -eq 1) -Message 'Abgelehnte Quelle wird nicht ausgewiesen.'
$invalidOfficialSemantics = @($sourceRegistry.items | Where-Object {
        [string]$_.source_class -ne 'OFFICIAL_DIRECTORY' -and
        [string]$_.import_decision -eq 'IMPORT_CANDIDATES' -and
        [string]$_.verification_required -eq 'OFFICIAL_CAREER_URL_REQUIRED'
    })
Assert-True -Condition ($invalidOfficialSemantics.Count -eq 0) -Message 'Sekundaerquelle darf keine offizielle Karrierequellen-Semantik erhalten.'
$missingUsageNotes = @($sourceRegistry.items | Where-Object {
        [string]::IsNullOrWhiteSpace([string]$_.allowed_use) -or
        [string]::IsNullOrWhiteSpace([string]$_.rate_limit_note) -or
        [string]::IsNullOrWhiteSpace([string]$_.robots_note)
    })
Assert-True -Condition ($missingUsageNotes.Count -eq 0) -Message 'Quellen muessen Nutzungs-, Rate- und Robots-Hinweise tragen.'

$coverageLog = Join-Path $root 'logs\jobagent\ja-023-source-coverage.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $coverageLog) -Force | Out-Null
$sourceCoverage | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $coverageLog -Encoding UTF8

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'coverage_metrics_for_inventory_attempts_and_matches',
        'unknown_companies_prioritized',
        'manual_review_discovery_prioritized',
        'stale_companies_prioritized',
        'failed_portals_prioritized_for_adapter_review',
        'recent_success_rotation_penalty',
        'coverage_report_has_approximation_notice',
        'daily_report_includes_coverage_and_backlog',
        'discovery_source_registry_schema_valid',
        'discovery_source_coverage_by_class_and_decision',
        'discovery_source_secondary_sources_are_not_official',
        'discovery_source_usage_notes_required'
    )
} | ConvertTo-Json -Depth 4
