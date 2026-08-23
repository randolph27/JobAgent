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
Assert-True -Condition ($coverage.metrics.career_url_verified -eq 5) -Message 'Coverage zaehlt CAREER_URL_VERIFIED falsch.'
Assert-True -Condition ($coverage.dimensions.by_target_area.MUNICH -eq 6) -Message 'Coverage zaehlt Zielgebiete falsch.'
Assert-True -Condition ($coverage.dimensions.by_industry.UNKNOWN -eq 6) -Message 'Coverage zaehlt Branchen falsch.'
Assert-True -Condition ($coverage.dimensions.by_inventory_state.MANUAL_REVIEW_REQUIRED -eq 1) -Message 'Coverage zaehlt Reviewstatus falsch.'

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

$duplicateDocument = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-17T09:00:00Z')
$duplicateDocument.companies = @(
    New-TestCoverageCompany -Name 'Duplicate AG' -Domain 'duplicate.example.invalid' -CareerUrl 'https://duplicate.example.invalid/careers' -Priority 70
    New-TestCoverageCompany -Name 'Duplicate GmbH' -Domain 'duplicate.example.invalid' -CareerUrl 'https://duplicate.example.invalid/jobs' -Priority 70
)
$duplicates = Get-JobAgentCoverageDuplicateGroups -Document $duplicateDocument
Assert-True -Condition (@($duplicates | Where-Object { $_.basis -eq 'canonical_domain' -and $_.key -eq 'duplicate.example.invalid' }).Count -eq 1) -Message 'Coverage-Dubletten nach Domain werden nicht erkannt.'

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
Assert-JobAgentDiscoverySourceRegistry -Registry $sourceRegistry
$sourceCoverage = New-JobAgentDiscoverySourceCoverageReport -SourceRegistry $sourceRegistry -Now ([datetime]'2026-08-23T08:30:00Z')
Assert-True -Condition ($sourceCoverage.sources_total -ge 10) -Message 'Discovery-Quellenkatalog enthaelt zu wenige Quellen.'
Assert-True -Condition ($sourceCoverage.class_counts.REGIONAL_DIRECTORY -ge 1) -Message 'Regionale Verzeichnisquellen werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.JOB_BOARD_DISCOVERY -ge 3) -Message 'Sekundaere Jobboersen-Hinweise werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.OFFICIAL_REGISTER -ge 2) -Message 'Offizielle Register-Hinweise werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.OPEN_REGISTER_DUMP -ge 1) -Message 'Open-Register-Dumps werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.class_counts.REJECTED -ge 1) -Message 'Abgelehnte Quellen werden nicht gezaehlt.'
Assert-True -Condition ($sourceCoverage.importable_sources -ge 6) -Message 'Importierbare Quellen werden falsch gezaehlt.'
Assert-True -Condition ($sourceCoverage.manual_review_sources -ge 10) -Message 'Manual-Review-Quellen werden falsch gezaehlt.'
Assert-True -Condition ($sourceCoverage.verification_gap_sources -ge 8) -Message 'Offene Verifikationsluecken werden falsch gezaehlt.'
Assert-True -Condition (@($sourceCoverage.rejected_source_ids | Where-Object { $_ -eq 'source-registry:linkedin_jobs' }).Count -eq 1) -Message 'Abgelehnte Quelle wird nicht ausgewiesen.'
$invalidOfficialSemantics = @($sourceRegistry.items | Where-Object {
        [string]$_.source_class -notin @('OFFICIAL_COMPANY', 'OFFICIAL_ATS') -and
        [string]$_.evidence_level -eq 'PRIMARY_OFFICIAL'
    })
Assert-True -Condition ($invalidOfficialSemantics.Count -eq 0) -Message 'Sekundaerquelle darf keine offizielle Karrierequellen-Semantik erhalten.'
$missingUsageNotes = @($sourceRegistry.items | Where-Object {
        [string]::IsNullOrWhiteSpace([string]$_.allowed_use) -or
        [string]::IsNullOrWhiteSpace([string]$_.forbidden_use) -or
        [string]::IsNullOrWhiteSpace([string]$_.rate_limit_policy) -or
        [string]::IsNullOrWhiteSpace([string]$_.robots_or_terms_note)
    })
Assert-True -Condition ($missingUsageNotes.Count -eq 0) -Message 'Quellen muessen Nutzungs-, Rate- und Robots-Hinweise tragen.'

$invalidSource = $sourceRegistry.items[0].PSObject.Copy()
$invalidSource.PSObject.Properties.Remove('allowed_use')
try {
    Assert-JobAgentDiscoverySource -Source $invalidSource
    throw 'ungueltige Quelle wurde akzeptiert'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'allowed_use') -Message 'Fehlendes allowed_use muss fail-closed abgelehnt werden.'
}

$jobBoardPrimary = $sourceRegistry.items[0].PSObject.Copy()
$jobBoardPrimary.source_id = 'source-registry:test_jobboard_primary'
$jobBoardPrimary.source_class = 'JOB_BOARD_DISCOVERY'
$jobBoardPrimary.evidence_level = 'PRIMARY_OFFICIAL'
$jobBoardPrimary.review_required = $true
try {
    Assert-JobAgentDiscoverySource -Source $jobBoardPrimary
    throw 'Jobboerse als Primaerbeleg wurde akzeptiert'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'Primaerbeleg|Jobboerse') -Message 'Jobboerse als Primaerbeleg muss fail-closed abgelehnt werden.'
}

$hintStorePath = Join-Path $root 'data\jobagent\company-discovery.hints.json'
Assert-True -Condition (Test-Path -LiteralPath $hintStorePath -PathType Leaf) -Message 'Discovery-Hint-Store fehlt.'
$hintStore = Get-Content -Raw -LiteralPath $hintStorePath | ConvertFrom-Json -Depth 100
Assert-True -Condition ($hintStore.schema_version -eq 'jobagent/company-discovery-hints/v1') -Message 'Discovery-Hint-Store hat falsche Schema-Version.'
Assert-True -Condition ($hintStore.search_matrix_count -eq 72) -Message 'Discovery-Hint-Store dokumentiert falsche Suchmatrix-Groesse.'
Assert-True -Condition ($hintStore.hints_total -ge 5) -Message 'Discovery-Hint-Store enthaelt zu wenige Sekundaerhinweise.'
Assert-True -Condition ($hintStore.unverified_hints -eq $hintStore.hints_total) -Message 'Discovery-Hint-Store darf keine verifizierten Hints enthalten.'
Assert-True -Condition (@($hintStore.hints | Where-Object { [string]$_.candidate_status -notin @('DISCOVERY_HINT', 'REGISTER_DISCOVERY_HINT') }).Count -eq 0) -Message 'Discovery-Hint-Store darf nur definierte unverifizierte Kandidatenstatus speichern.'
$jobBoardHints = @($hintStore.hints | Where-Object { [string]$_.candidate_status -eq 'DISCOVERY_HINT' })
Assert-True -Condition (@($jobBoardHints | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.search_parameters.keyword) -or [string]::IsNullOrWhiteSpace([string]$_.observed_url) }).Count -eq 0) -Message 'Jobboersen-Discovery-Hints muessen Suchparameter und Fund-URL tragen.'
$registerHints = @($hintStore.hints | Where-Object { [string]$_.candidate_status -eq 'REGISTER_DISCOVERY_HINT' })
Assert-True -Condition (@($registerHints | Where-Object { [bool]$_.official_verification_required -ne $true -or @($_.dedupe_keys).Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$_.source_snapshot.record_hash) }).Count -eq 0) -Message 'Register-Discovery-Hints muessen Verifikationspflicht, Dedupe-Keys und Snapshot-Hash tragen.'
$hintSourceIds = @($hintStore.hints | ForEach-Object { [string]$_.source_id } | Sort-Object -Unique)
$secondarySourceIds = @($sourceRegistry.items | Where-Object { [string]$_.source_class -in @('JOB_BOARD_DISCOVERY', 'OPEN_REGISTER_DUMP') -and [string]$_.evidence_level -eq 'DISCOVERY_HINT' } | ForEach-Object { [string]$_.source_id })
Assert-True -Condition (@($hintSourceIds | Where-Object { $secondarySourceIds -notcontains $_ }).Count -eq 0) -Message 'Discovery-Hints duerfen nur erlaubte Sekundaerquellen referenzieren.'

$coverageWithInputs = New-JobAgentCoverageReport -Document $document -SourceRegistry $sourceRegistry -HintStore $hintStore -Now ([datetime]'2026-08-23T08:30:00Z')
Assert-True -Condition ($coverageWithInputs.metrics.discovery_hints_total -eq $hintStore.hints_total) -Message 'Coverage uebernimmt Discovery-Hint-Zaehler falsch.'
Assert-True -Condition ($coverageWithInputs.source_coverage.sources_total -eq $sourceCoverage.sources_total) -Message 'Coverage bettet Quellen-Coverage nicht ein.'
Assert-True -Condition (@($coverageWithInputs.import_waves.waves).Count -eq 5) -Message 'Coverage erzeugt nicht alle Importwellen.'
Assert-True -Condition (@($coverageWithInputs.import_waves.waves | Where-Object { $_.wave_id -eq 'D' -and $_.candidates_total -ge 1 }).Count -eq 1) -Message 'Importwelle D enthaelt keine Sekundaerhinweise.'
Assert-True -Condition ($coverageWithInputs.import_waves.contract -match 'unverifizierte Hints') -Message 'Importwellen muessen Hints fail-closed beschreiben.'

$coverageLog = Join-Path $root 'logs\jobagent\ja-023-source-coverage.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $coverageLog) -Force | Out-Null
$sourceCoverage | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $coverageLog -Encoding UTF8

$toolOutput = & (Join-Path $root 'tools\Measure-JobAgentCompanyCoverage.ps1') -ProjectRoot $root -MaxPriorityItems 10 | ConvertFrom-Json -Depth 20
Assert-True -Condition ($toolOutput.status -eq 'ok') -Message 'Coverage-Tool liefert keinen OK-Status.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.json_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein JSON-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.markdown_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein Markdown-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.html_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein HTML-Artefakt.'
$toolJson = Get-Content -Raw -LiteralPath $toolOutput.json_path | ConvertFrom-Json -Depth 100
$toolMarkdown = Get-Content -Raw -LiteralPath $toolOutput.markdown_path
$toolHtml = Get-Content -Raw -LiteralPath $toolOutput.html_path
Assert-True -Condition ($toolJson.approximation_notice -match 'keine vollstaendige Marktdeckung') -Message 'Coverage-Tool-JSON behauptet Vollstaendigkeit oder Hinweis fehlt.'
Assert-True -Condition (@($toolJson.import_waves.waves).Count -eq 5) -Message 'Coverage-Tool-JSON enthaelt keine fuenf Importwellen.'
Assert-True -Condition ($toolMarkdown.Contains('## Importwellen')) -Message 'Coverage-Tool-Markdown enthaelt keine Importwellen.'
Assert-True -Condition ($toolHtml.Contains('<meta name="viewport" content="width=device-width, initial-scale=1">')) -Message 'Coverage-Tool-HTML enthaelt keinen Viewport-Meta-Tag.'
Assert-True -Condition ($toolHtml.Contains('.table-wrap { overflow-x: auto; }')) -Message 'Coverage-Tool-HTML enthaelt keinen Tabellen-Overflow-Schutz.'
Assert-True -Condition (-not ($toolHtml -match '<script\b[^>]*\bsrc=')) -Message 'Coverage-Tool-HTML darf keine externen Skripte laden.'
Assert-True -Condition (-not ($toolHtml -match '<link\b[^>]*\bhref=')) -Message 'Coverage-Tool-HTML darf keine externen Stylesheets laden.'


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
        'coverage_dimensions_by_status_target_industry_and_source',
        'coverage_duplicate_groups_by_domain',
        'coverage_import_wave_plan',
        'daily_report_includes_coverage_and_backlog',
        'discovery_source_registry_schema_valid',
        'discovery_source_coverage_by_class_and_decision',
        'discovery_source_secondary_sources_are_not_official',
        'discovery_source_usage_notes_required',
        'secondary_hint_store_contract',
        'coverage_tool_generates_json_markdown_html_artifacts',
        'coverage_tool_html_has_responsive_guards'
    )
} | ConvertTo-Json -Depth 4
