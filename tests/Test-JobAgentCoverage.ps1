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
$document.job_sources = @(
    [pscustomobject]@{ source_id = 'source:match_ats'; company_id = 'company:match_ag'; source_type = 'OFFICIAL_ATS'; url = 'https://ats.match.example.invalid/jobs'; canonical_url = 'https://ats.match.example.invalid/jobs'; is_official = $true; verified_at = '2026-08-16T08:00:00.000Z'; verification_basis = 'COMPANY_LINKED_ATS'; verification_evidence = @([pscustomobject]@{ status = 'VERIFIED'; evidence_type = 'COMPANY_LINKED_ATS'; url = 'https://ats.match.example.invalid/jobs'; basis_url = 'https://match.example.invalid/careers'; redirect_chain = @(); observed_at = '2026-08-16T08:00:00.000Z'; reason = 'ATS ist von der offiziellen Karriere-Seite verlinkt.' }) }
    [pscustomobject]@{ source_id = 'source:ignored_jobboard'; company_id = 'company:hint_ag'; source_type = 'CAREER_PAGE'; url = 'https://jobs.example.invalid/hint-ag'; canonical_url = 'https://jobs.example.invalid/hint-ag'; is_official = $false; verified_at = '2026-08-16T08:00:00.000Z'; verification_basis = 'CAREER_URL'; verification_evidence = @([pscustomobject]@{ status = 'UNVERIFIED'; evidence_type = 'UNVERIFIED'; url = 'https://jobs.example.invalid/hint-ag'; basis_url = 'https://directory.example.invalid/hint'; redirect_chain = @(); observed_at = '2026-08-16T08:00:00.000Z'; reason = 'Sekundaerer Jobboersen-Hinweis.' }) }
)
$document.scan_runs = @(
    [pscustomobject]@{ scan_run_id = 'scanrun:1'; started_at = '2026-08-16T08:00:00.000Z'; finished_at = '2026-08-16T09:01:00.000Z'; status = 'PARTIAL'; company_ids = @('company:failed_ag', 'company:stale_ag', 'company:recent_ag', 'company:match_ag'); artifact_paths = @(); errors = @('NOT_REACHABLE') }
)
$document.change_events = @()

$coverage = New-JobAgentCoverageReport -Document $document -Now ([datetime]'2026-08-17T12:00:00Z') -StaleAfterDays 7 -MaxPriorityItems 5
Assert-True -Condition ($coverage.metrics.companies_total -eq 6) -Message 'Coverage zaehlt Firmen falsch.'
Assert-True -Condition ($coverage.metrics.sources_total -eq 2) -Message 'Coverage zaehlt Quellenbestand aus JobSources falsch.'
Assert-True -Condition ($coverage.metrics.official_sources -eq 1) -Message 'Coverage zaehlt offizielle Quellen falsch.'
Assert-True -Condition ($coverage.metrics.ats_sources -eq 1) -Message 'Coverage zaehlt ATS-Quellen falsch.'
Assert-True -Condition ($coverage.metrics.unverified_sources -eq 1) -Message 'Coverage zaehlt offene Quellen falsch.'
Assert-True -Condition ($coverage.metrics.never_scanned_sources -eq 2) -Message 'Coverage zaehlt nie gescannte Quellen falsch.'
Assert-True -Condition ($coverage.metrics.without_career_url -eq 1) -Message 'Coverage zaehlt Firmen ohne Karriere-URL falsch.'
Assert-True -Condition ($coverage.metrics.failed_scanned -eq 1) -Message 'Coverage zaehlt fehlgeschlagene Portale falsch.'
Assert-True -Condition ($coverage.metrics.never_scanned -eq 2) -Message 'Coverage zaehlt nie gescannte Firmen falsch.'
Assert-True -Condition ($coverage.metrics.with_matching_jobs -eq 1) -Message 'Coverage zaehlt passende Stellen falsch.'
Assert-True -Condition ($coverage.approximation_notice -match 'keine vollstaendige Marktdeckung') -Message 'Coverage-Hinweis darf keine Vollstaendigkeit behaupten.'
Assert-True -Condition ($coverage.metrics.manual_review_required -eq 1) -Message 'Coverage zaehlt manuell zu pruefende Discovery-Hinweise falsch.'
Assert-True -Condition ($coverage.metrics.verified_without_career_url -eq 1) -Message 'Coverage zaehlt verifizierte Firmen ohne Karriere-URL falsch.'
Assert-True -Condition ($coverage.metrics.career_url_verified -eq 5) -Message 'Coverage zaehlt CAREER_URL_VERIFIED falsch.'
Assert-True -Condition ($coverage.metrics.company_refresh_due -ge 2) -Message 'Coverage zaehlt refresh-faellige Firmen nicht.'
Assert-True -Condition ($coverage.dimensions.by_staleness_status.EXPIRED -ge 1) -Message 'Coverage weist abgelaufene Firmen-Freshness nicht aus.'
Assert-True -Condition ($coverage.dimensions.by_refresh_reason.official_verification_required -ge 1) -Message 'Coverage zaehlt Refresh-Gruende nicht.'
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
$recentLinks = @((@($coverage.companies | Where-Object { $_.company_id -eq 'company:recent_ag' })[0]).links)
Assert-True -Condition (@($recentLinks | Where-Object { [string]$_.link_type -eq 'career' -and [bool]$_.is_clickable -and [string]$_.url -eq 'https://recent.example.invalid/careers' }).Count -eq 1) -Message 'Coverage-Linkvertrag gibt Karriere-URL nicht als klickbaren offiziellen Link aus.'
$unknownLinks = @((@($coverage.companies | Where-Object { $_.company_id -eq 'company:unknown_ag' })[0]).links)
Assert-True -Condition (@($unknownLinks | Where-Object { [string]$_.link_type -eq 'website' -and [bool]$_.is_clickable -and [string]$_.source_field -eq 'company.official_website_url' }).Count -eq 1) -Message 'Coverage-Linkvertrag nutzt verifizierte Website-only-Firmen nicht als offiziellen Link.'
$matchLinks = @((@($coverage.companies | Where-Object { $_.company_id -eq 'company:match_ag' })[0]).links)
Assert-True -Condition (@($matchLinks | Where-Object { [string]$_.link_type -eq 'ats' -and [bool]$_.is_clickable -and [string]$_.source_id -eq 'source:match_ats' }).Count -eq 1) -Message 'Coverage-Linkvertrag uebernimmt offizielle ATS-Quellen nicht.'
$hintLinks = @((@($coverage.companies | Where-Object { $_.company_id -eq 'company:hint_ag' })[0]).links)
Assert-True -Condition (@($hintLinks | Where-Object { [string]$_.link_type -eq 'review_hint' -and [bool]$_.review_only -and -not [bool]$_.is_clickable }).Count -eq 1) -Message 'Coverage-Linkvertrag markiert Discovery-Hints nicht als nicht-produktiven Review-Hinweis.'
Assert-True -Condition (@($hintLinks | Where-Object { [string]$_.url -eq 'https://jobs.example.invalid/hint-ag' }).Count -eq 0) -Message 'Coverage-Linkvertrag darf unoffizielle Jobboersen-Hints nicht als Anbieterlink uebernehmen.'
$missingLinks = @(Get-JobAgentCoverageCompanyLinks -Company ([pscustomobject]@{ company_id = 'company:missing'; canonical_name = 'Missing AG'; verification_status = 'UNVERIFIED'; career_url = $null; official_website_url = $null; discovery_source = [pscustomobject]@{ type = 'MANUAL_REVIEW'; url = $null; discovery_origin = 'test' } }) -JobSources @())
Assert-True -Condition (@($missingLinks | Where-Object { [string]$_.link_type -eq 'missing' -and [string]$_.reason -match 'Keine verifizierte' }).Count -eq 1) -Message 'Coverage-Linkvertrag muss fehlende offizielle Links fail-closed ausweisen.'

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
Assert-True -Condition ($markdown.Contains('ATS/Portal-Adapter pruefen')) -Message 'Markdown-Report enthaelt keinen Adapter-Backlog.'
Assert-True -Condition ($markdown.Contains('Discovery-Hinweis pruefen')) -Message 'Markdown-Report enthaelt keinen Discovery-Review-Backlog.'
foreach ($rawLabel in @('ATS_OR_PORTAL_ADAPTER_REVIEW', 'MANUAL_REVIEW_DISCOVERY', 'checked_jobs', 'active_matching_jobs')) {
    Assert-True -Condition (-not $markdown.Contains($rawLabel)) -Message "Markdown-Report darf technische Labels nicht sichtbar ausgeben: $rawLabel"
}

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
Assert-True -Condition (@($hintStore.hints | Where-Object { [string]$_.candidate_status -notin @('DISCOVERY_HINT', 'REGISTER_DISCOVERY_HINT', 'REGIONAL_DISCOVERY_HINT') }).Count -eq 0) -Message 'Discovery-Hint-Store darf nur definierte unverifizierte Kandidatenstatus speichern.'
$jobBoardHints = @($hintStore.hints | Where-Object { [string]$_.candidate_status -eq 'DISCOVERY_HINT' })
Assert-True -Condition (@($jobBoardHints | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.search_parameters.keyword) -or [string]::IsNullOrWhiteSpace([string]$_.observed_url) }).Count -eq 0) -Message 'Jobboersen-Discovery-Hints muessen Suchparameter und Fund-URL tragen.'
$registerHints = @($hintStore.hints | Where-Object { [string]$_.candidate_status -eq 'REGISTER_DISCOVERY_HINT' })
Assert-True -Condition (@($registerHints | Where-Object { [bool]$_.official_verification_required -ne $true -or @($_.dedupe_keys).Count -lt 1 -or [string]::IsNullOrWhiteSpace([string]$_.source_snapshot.record_hash) }).Count -eq 0) -Message 'Register-Discovery-Hints muessen Verifikationspflicht, Dedupe-Keys und Snapshot-Hash tragen.'
$regionalHints = @($hintStore.hints | Where-Object { [string]$_.candidate_status -eq 'REGIONAL_DISCOVERY_HINT' })
Assert-True -Condition (@($regionalHints | Where-Object { [bool]$_.official_verification_required -ne $true -or [string]::IsNullOrWhiteSpace([string]$_.region_reference) -or [string]::IsNullOrWhiteSpace([string]$_.source_record_hash) }).Count -eq 0) -Message 'Regional-Discovery-Hints muessen Verifikationspflicht, Region und Snapshot-Hash tragen.'
$hintSourceIds = @($hintStore.hints | ForEach-Object { [string]$_.source_id } | Sort-Object -Unique)
$secondarySourceIds = @($sourceRegistry.items | Where-Object { [string]$_.source_class -in @('JOB_BOARD_DISCOVERY', 'OPEN_REGISTER_DUMP', 'REGIONAL_DIRECTORY', 'PUBLIC_INSTITUTION_DIRECTORY') -and [string]$_.evidence_level -in @('DISCOVERY_HINT', 'SECONDARY_OFFICIAL_DIRECTORY') } | ForEach-Object { [string]$_.source_id })
Assert-True -Condition (@($hintSourceIds | Where-Object { $secondarySourceIds -notcontains $_ }).Count -eq 0) -Message 'Discovery-Hints duerfen nur erlaubte Sekundaerquellen referenzieren.'

$candidateVerificationQueue = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-verification-queue/v1'
    generated_at = '2026-08-23T08:30:00.000Z'
    queue = @(
        [pscustomobject]@{
            identity_cluster_id = 'identity-cluster:domain_example_invalid'
            candidate_id = 'hint:queue-verified'
            candidate_ids = @('hint:queue-verified')
            canonical_name = 'Queue Verified AG'
            source_count = 1
            priority_score = 90
            target_area_basis = @('JOB_LOCATION_IN_TARGET')
            status = 'VERIFIED'
            review_reason = 'READY_FOR_OFFICIAL_VERIFICATION'
            retry_count = 0
            last_attempt_at = '2026-08-23T08:00:00.000Z'
            next_attempt_at = $null
            last_status = 'CAREER_URL_VERIFIED'
            last_reason = 'Karriere-URL liegt auf offizieller Firmendomain.'
        },
        [pscustomobject]@{
            identity_cluster_id = 'identity-cluster:domain_retry_invalid'
            candidate_id = 'hint:queue-retry'
            candidate_ids = @('hint:queue-retry')
            canonical_name = 'Queue Retry AG'
            source_count = 1
            priority_score = 80
            target_area_basis = @('JOB_LOCATION_IN_TARGET')
            status = 'RETRY_SCHEDULED'
            review_reason = 'READY_FOR_OFFICIAL_VERIFICATION'
            retry_count = 1
            last_attempt_at = '2026-08-23T08:00:00.000Z'
            next_attempt_at = '2026-08-24T08:00:00.000Z'
            last_status = 'UNVERIFIED'
            last_reason = 'Kein offiziell belegter Karriere- oder ATS-Link wurde gefunden.'
        },
        [pscustomobject]@{
            identity_cluster_id = 'identity-cluster:domain_review_invalid'
            candidate_id = 'hint:queue-review'
            candidate_ids = @('hint:queue-review')
            canonical_name = 'Queue Review AG'
            source_count = 1
            priority_score = 70
            target_area_basis = @('TARGET_AREA_UNCERTAIN')
            status = 'MANUAL_REVIEW_REQUIRED'
            review_reason = 'TARGET_AREA_REVIEW_REQUIRED'
            retry_count = 0
            last_attempt_at = '2026-08-23T08:00:00.000Z'
            next_attempt_at = $null
            last_status = 'MANUAL_REVIEW_REQUIRED'
            last_reason = 'Standortbezug muss manuell geprueft werden.'
        }
    )
}
$coverageWithInputs = New-JobAgentCoverageReport -Document $document -SourceRegistry $sourceRegistry -HintStore $hintStore -CandidateVerificationQueue $candidateVerificationQueue -Now ([datetime]'2026-08-23T08:30:00Z') -MaxPriorityItems 250
Assert-True -Condition ($coverageWithInputs.metrics.discovery_hints_total -eq $hintStore.hints_total) -Message 'Coverage uebernimmt Discovery-Hint-Zaehler falsch.'
Assert-True -Condition ($coverageWithInputs.target_inventory_gate.schema_version -eq 'jobagent/company-target-inventory-gate/v1') -Message 'Coverage erzeugt keinen JA-025-Zielinventar-Gate.'
Assert-True -Condition ($coverageWithInputs.metrics.target_inventory_candidates_total -eq ($coverageWithInputs.metrics.companies_total + $coverageWithInputs.metrics.candidate_clusters_total)) -Message 'Zielinventar-Gate zaehlt Firmen und Kandidatencluster inkonsistent.'
Assert-True -Condition ($coverageWithInputs.metrics.target_inventory_gap_to_1000 -eq [Math]::Max(0, 1000 - [int]$coverageWithInputs.metrics.target_inventory_candidates_total)) -Message 'Zielinventar-Gate berechnet die 1000er-Luecke falsch.'
Assert-True -Condition (@($coverageWithInputs.target_inventory_gate.violations | Where-Object { $_ -eq 'INVENTORY_CANDIDATES_BELOW_1000' }).Count -eq 1) -Message 'Zielinventar-Gate meldet fehlende Kandidatenbasis nicht fail-closed.'
Assert-True -Condition ($coverageWithInputs.metrics.scannable_without_official_source -ge 1) -Message 'Zielinventar-Gate erkennt scanfaehige Firmen ohne offiziellen Beleg nicht.'
Assert-True -Condition ($coverageWithInputs.source_inventory.schema_version -eq 'jobagent/source-inventory/v1') -Message 'Coverage erzeugt keinen Quellenbestand.'
Assert-True -Condition ($coverageWithInputs.metrics.sources_total -eq (@($document.job_sources).Count + @($sourceRegistry.items).Count + @($hintStore.hints).Count)) -Message 'Quellenbestand muss JobSources, Source Registry und Discovery-Hints zaehlen.'
Assert-True -Condition ($coverageWithInputs.metrics.discovery_sources -ge @($hintStore.hints).Count) -Message 'Quellenbestand zaehlt Discovery-Hinweise nicht.'
Assert-True -Condition ($coverageWithInputs.metrics.sources_attempted_latest_run -eq 0) -Message 'Quellenbestand darf ohne passenden letzten ScanRun keine Quellen als versucht markieren.'
Assert-True -Condition ($coverageWithInputs.source_coverage.sources_total -eq $sourceCoverage.sources_total) -Message 'Coverage bettet Quellen-Coverage nicht ein.'
Assert-True -Condition ($coverageWithInputs.source_coverage.PSObject.Properties.Name -contains 'refresh_due_sources') -Message 'Quellen-Coverage weist Refresh-Faelligkeit nicht aus.'
Assert-True -Condition ($coverageWithInputs.candidate_freshness.schema_version -eq 'jobagent/candidate-freshness/v1') -Message 'Coverage erzeugt keinen Kandidaten-Freshness-Report.'
Assert-True -Condition ($coverageWithInputs.candidate_freshness.candidates_total -eq $hintStore.hints_total) -Message 'Coverage zaehlt Kandidaten-Freshness falsch.'
Assert-True -Condition ($coverageWithInputs.metrics.candidate_clusters_total -gt 0) -Message 'Coverage erzeugt keine Kandidaten-Cluster-Metrik.'
Assert-True -Condition ($coverageWithInputs.candidate_clusters.candidates_total -eq $hintStore.hints_total) -Message 'Coverage-Dedupe uebernimmt Hint-Kandidaten falsch.'
Assert-True -Condition ($coverageWithInputs.candidate_clusters.review_queue_total -gt 0) -Message 'Coverage-Dedupe weist keine Review-Queue aus.'
Assert-True -Condition ($coverageWithInputs.candidate_clusters.dimensions.by_target_area_basis.REGISTER_SEAT_IN_TARGET -ge 1) -Message 'Coverage-Dedupe zaehlt Register-Standortbasis nicht.'
Assert-True -Condition ($coverageWithInputs.candidate_clusters.dimensions.by_conflict_flag.STAFFING_AGENCY_REVIEW -ge 1) -Message 'Coverage-Dedupe zaehlt Personaldienstleister-Konflikte nicht.'
Assert-True -Condition ($coverageWithInputs.metrics.candidate_verification_queue_total -eq $coverageWithInputs.candidate_verification_queue.clusters_total) -Message 'Coverage erzeugt die Kandidaten-Verifikationsqueue nicht aus allen Clustern.'
Assert-True -Condition ($coverageWithInputs.metrics.candidate_verification_ready -gt 0) -Message 'Coverage zaehlt offene Verifikationskandidaten falsch.'
Assert-True -Condition ($coverageWithInputs.metrics.candidate_verification_manual_review -gt 0) -Message 'Coverage zaehlt manuelle Review-Kandidaten falsch.'
Assert-True -Condition (@($coverageWithInputs.candidate_verification_queue.queue | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.next_action) -or @($_.reason_codes).Count -lt 1 -or $null -eq $_.source_evidence -or $null -eq $_.dedupe_context }).Count -eq 0) -Message 'Kandidaten-Review-Queue enthaelt nicht alle Pflichtfelder.'
Assert-True -Condition (@($coverageWithInputs.candidate_verification_queue.queue | Where-Object { [string]$_.next_action -eq 'VERIFY_OFFICIAL_SITE' }).Count -gt 0) -Message 'Kandidaten-Review-Queue enthaelt keine offiziellen Verifikationsaktionen.'
Assert-True -Condition (@($coverageWithInputs.candidate_verification_queue.queue | Where-Object { [string]$_.next_action -in @('CHECK_LOCATION', 'REJECT_DUPLICATE', 'MANUAL_DECISION') }).Count -gt 0) -Message 'Kandidaten-Review-Queue enthaelt keine fail-closed Review-Aktionen.'
Assert-True -Condition ($coverageWithInputs.candidate_verification_decision_report.productive_upsert_allowed_total -eq 1) -Message 'Coverage-Decision-Report zaehlt produktive Upserts falsch.'
Assert-True -Condition ($coverageWithInputs.candidate_verification_decision_report.fail_closed_total -eq 1) -Message 'Coverage-Decision-Report zaehlt fail-closed Review falsch.'
Assert-True -Condition ($coverageWithInputs.candidate_verification_decision_report.retry_deferred_total -eq 1) -Message 'Coverage-Decision-Report zaehlt Retry-Reject falsch.'
Assert-True -Condition (@($coverageWithInputs.import_waves.waves).Count -eq 5) -Message 'Coverage erzeugt nicht alle Importwellen.'
Assert-True -Condition (@($coverageWithInputs.import_waves.waves | Where-Object { $_.wave_id -eq 'D' -and $_.candidates_total -ge 1 }).Count -eq 1) -Message 'Importwelle D enthaelt keine Sekundaerhinweise.'
Assert-True -Condition ($coverageWithInputs.import_waves.contract -match 'unverifizierte Hints') -Message 'Importwellen muessen Hints fail-closed beschreiben.'

$coverageLog = Join-Path $root 'logs\jobagent\ja-023-source-coverage.json'
New-Item -ItemType Directory -Path (Split-Path -Parent $coverageLog) -Force | Out-Null
$sourceCoverage | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $coverageLog -Encoding UTF8

$toolOutput = & (Join-Path $root 'tools\Measure-JobAgentCompanyCoverage.ps1') -ProjectRoot $root -MaxPriorityItems 10 | ConvertFrom-Json -Depth 20
Assert-True -Condition ($toolOutput.status -eq 'ok') -Message 'Coverage-Tool liefert keinen OK-Status.'
Assert-True -Condition ($toolOutput.sources_total -gt 0) -Message 'Coverage-Tool gibt Quellenanzahl nicht direkt aus.'
Assert-True -Condition ($toolOutput.official_sources -gt 0) -Message 'Coverage-Tool gibt offizielle Quellen nicht direkt aus.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.json_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein JSON-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.markdown_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein Markdown-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.html_path -PathType Leaf) -Message 'Coverage-Tool erzeugt kein HTML-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $toolOutput.candidate_verification_queue_path -PathType Leaf) -Message 'Coverage-Tool erzeugt keine Kandidaten-Review-Queue.'
$toolJson = Get-Content -Raw -LiteralPath $toolOutput.json_path | ConvertFrom-Json -Depth 100
$toolMarkdown = Get-Content -Raw -LiteralPath $toolOutput.markdown_path
$toolHtml = Get-Content -Raw -LiteralPath $toolOutput.html_path
$toolQueue = Get-Content -Raw -LiteralPath $toolOutput.candidate_verification_queue_path | ConvertFrom-Json -Depth 100
Assert-True -Condition ($toolJson.approximation_notice -match 'keine vollstaendige Marktdeckung') -Message 'Coverage-Tool-JSON behauptet Vollstaendigkeit oder Hinweis fehlt.'
Assert-True -Condition ($toolOutput.target_inventory_candidates_total -eq $toolJson.metrics.target_inventory_candidates_total) -Message 'Coverage-Tool gibt die Zielgebiet-Kandidatenzahl nicht direkt aus.'
Assert-True -Condition ($toolOutput.target_inventory_gate_status -eq $toolJson.target_inventory_gate.status) -Message 'Coverage-Tool gibt den Zielinventar-Gate-Status inkonsistent aus.'
Assert-True -Condition ($toolMarkdown.Contains('Zielgebiet-Kandidaten gesamt')) -Message 'Coverage-Tool-Markdown enthaelt keine Zielinventar-Metrik.'
Assert-True -Condition ($toolHtml.Contains('Luecke bis 1000 Kandidaten')) -Message 'Coverage-Tool-HTML enthaelt keine 1000er-Luecke.'
Assert-True -Condition (@($toolJson.import_waves.waves).Count -eq 4) -Message 'Coverage-Tool-JSON folgt nicht der produktiven A-D-Wellenkonfiguration.'
Assert-True -Condition ($toolJson.import_wave_metrics.schema_version -eq 'jobagent/company-import-wave-metrics/v1') -Message 'Coverage-Tool-JSON enthaelt keine Importwellen-Metriken.'
Assert-True -Condition (@($toolJson.import_wave_metrics.waves | Where-Object { [string]$_.wave_id -eq 'D' -and [int]$_.hint_only_total -ge 1 }).Count -eq 1) -Message 'Importwellen-Metriken weisen Welle-D-Hints nicht aus.'
Assert-True -Condition (@($toolJson.import_wave_metrics.waves | Where-Object { [string]$_.wave_id -eq 'A' -and [double]$_.verification_rate -ge 0 }).Count -eq 1) -Message 'Importwellen-Metriken enthalten keine Verifikationsquote.'
Assert-True -Condition ($toolJson.metrics.candidate_clusters_total -gt 0) -Message 'Coverage-Tool-JSON enthaelt keine Kandidaten-Cluster-Metrik.'
Assert-True -Condition (@($toolJson.candidate_clusters.review_queue).Count -gt 0) -Message 'Coverage-Tool-JSON enthaelt keine Dedupe-Review-Queue.'
Assert-True -Condition ($toolQueue.schema_version -eq 'jobagent/company-candidate-verification-queue/v1') -Message 'Kandidaten-Review-Queue hat falsche Schema-Version.'
Assert-True -Condition ($toolQueue.queue_type -eq 'review') -Message 'Kandidaten-Review-Queue markiert den Queue-Typ nicht.'
Assert-True -Condition (@($toolQueue.queue).Count -eq $toolJson.metrics.candidate_verification_queue_total) -Message 'Kandidaten-Review-Queue und Coverage-Metrik widersprechen sich.'
Assert-True -Condition (@($toolQueue.queue | Where-Object { [int]$_.priority_score -lt 0 -or [int]$_.priority_score -gt 100 -or [string]::IsNullOrWhiteSpace([string]$_.next_action) -or @($_.reason_codes).Count -lt 1 -or $null -eq $_.source_evidence -or $null -eq $_.dedupe_context }).Count -eq 0) -Message 'Kandidaten-Review-Queue enthaelt unvollstaendige Priorisierungsdaten.'
Assert-True -Condition ($toolMarkdown.Contains('## Importwellen')) -Message 'Coverage-Tool-Markdown enthaelt keine Importwellen.'
Assert-True -Condition ($toolMarkdown.Contains('## Quellenbestand')) -Message 'Coverage-Tool-Markdown enthaelt keinen Quellenbestand.'
Assert-True -Condition ($toolMarkdown.Contains('Quellen gesamt')) -Message 'Coverage-Tool-Markdown enthaelt keine Gesamtzahl der Quellen.'
Assert-True -Condition ($toolMarkdown.Contains('Annahmequote')) -Message 'Coverage-Tool-Markdown enthaelt keine Wellen-Annahmequote.'
Assert-True -Condition ($toolMarkdown.Contains('## Firmeninventar')) -Message 'Coverage-Tool-Markdown enthaelt kein segmentiertes Firmeninventar.'
Assert-True -Condition ($toolMarkdown.Contains('## Kandidaten-Dedupe')) -Message 'Coverage-Tool-Markdown enthaelt keinen Kandidaten-Dedupe-Abschnitt.'
Assert-True -Condition ($toolMarkdown.Contains('## Kandidaten-Freshness')) -Message 'Coverage-Tool-Markdown enthaelt keinen Kandidaten-Freshness-Abschnitt.'
Assert-True -Condition ($toolMarkdown.Contains('### Freshness-Status')) -Message 'Coverage-Tool-Markdown enthaelt keine Freshness-Dimension.'
Assert-True -Condition ($toolMarkdown.Contains('## Kandidaten-Verifikationsqueue')) -Message 'Coverage-Tool-Markdown enthaelt keine Kandidaten-Verifikationsqueue.'
Assert-True -Condition ($toolMarkdown.Contains('| Score | Aktion | Cluster | Kandidat | Firma | Status | Gruende | Quelle | Dedupe |')) -Message 'Coverage-Tool-Markdown enthaelt keine priorisierte Queue-Tabelle.'
Assert-True -Condition ($toolMarkdown.Contains('## Review-/Reject-Report')) -Message 'Coverage-Tool-Markdown enthaelt keinen Review-/Reject-Report.'
Assert-True -Condition ($toolHtml.Contains('<meta name="viewport" content="width=device-width, initial-scale=1">')) -Message 'Coverage-Tool-HTML enthaelt keinen Viewport-Meta-Tag.'
Assert-True -Condition ($toolHtml.Contains('<h2>Kandidaten-Dedupe</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Kandidaten-Dedupe-Abschnitt.'
Assert-True -Condition ($toolHtml.Contains('<h2>Quellenbestand</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Quellenbestand.'
Assert-True -Condition ($toolHtml.Contains('Offizielle Quellen')) -Message 'Coverage-Tool-HTML weist offizielle Quellen nicht sichtbar aus.'
Assert-True -Condition ($toolHtml.Contains('<h2>Kandidaten-Freshness</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Kandidaten-Freshness-Abschnitt.'
Assert-True -Condition ($toolHtml.Contains('<h2>Freshness-Status</h2>')) -Message 'Coverage-Tool-HTML enthaelt keine Freshness-Status-Tabelle.'
Assert-True -Condition ($toolHtml.Contains('<h2>Firmeninventar</h2>')) -Message 'Coverage-Tool-HTML enthaelt kein Firmeninventar.'
Assert-True -Condition ($toolHtml.Contains('position: sticky')) -Message 'Coverage-Tool-HTML enthaelt keine Sticky-Tabellenkoepfe fuer grosse Listen.'
Assert-True -Condition ($toolHtml.Contains('<h2>Kandidaten-Verifikationsqueue</h2>')) -Message 'Coverage-Tool-HTML enthaelt keine Kandidaten-Verifikationsqueue.'
Assert-True -Condition ($toolHtml.Contains('<th>Aktion</th>')) -Message 'Coverage-Tool-HTML enthaelt keine Aktionsspalte fuer die Queue.'
Assert-True -Condition ($toolHtml.Contains('<h2>Review-/Reject-Report</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Review-/Reject-Report.'
Assert-True -Condition ($toolHtml.Contains('.table-wrap { overflow-x: auto; }')) -Message 'Coverage-Tool-HTML enthaelt keinen Tabellen-Overflow-Schutz.'
Assert-True -Condition (-not ($toolHtml -match '<script\b[^>]*\bsrc=')) -Message 'Coverage-Tool-HTML darf keine externen Skripte laden.'
Assert-True -Condition (-not ($toolHtml -match '<link\b[^>]*\bhref=')) -Message 'Coverage-Tool-HTML darf keine externen Stylesheets laden.'
Assert-True -Condition ($toolMarkdown.Contains('| Firma | Link | Zielgebiet |')) -Message 'Coverage-Tool-Markdown enthaelt keine Linkspalte im Firmeninventar.'
Assert-True -Condition ($toolMarkdown.Contains('| Score | Firma | Link | Aktion | Gruende |')) -Message 'Coverage-Tool-Markdown enthaelt keine Linkspalte in Scanprioritaeten.'
Assert-True -Condition ($toolMarkdown.Contains('[Karriere](https://')) -Message 'Coverage-Tool-Markdown enthaelt keine klickbaren Karriere-Links.'
Assert-True -Condition ($toolMarkdown.Contains('Review-Hinweis: Unverifizierter Discovery-Hinweis')) -Message 'Coverage-Tool-Markdown markiert Discovery-Hints nicht als Review-Hinweis.'
Assert-True -Condition ($toolHtml.Contains('<h2>Backlog</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Backlog-Abschnitt.'
Assert-True -Condition ($toolHtml.Contains('<h2>Scanprioritaeten</h2>')) -Message 'Coverage-Tool-HTML enthaelt keinen Scanprioritaeten-Abschnitt.'
Assert-True -Condition ($toolHtml -match '<a class="provider-link" href="https://[^"]+" target="_blank" rel="noopener noreferrer">Karriere</a>') -Message 'Coverage-Tool-HTML enthaelt keine sicheren klickbaren Anbieterlinks.'
Assert-True -Condition ($toolHtml.Contains('<span class="review-link">Review-Hinweis</span>')) -Message 'Coverage-Tool-HTML markiert Discovery-Hints nicht sichtbar als Review-Hinweis.'
Assert-True -Condition (-not ($toolHtml -match '<td>Discovery-Hinweis</td>.*?<a class="provider-link"')) -Message 'Coverage-Tool-HTML darf unverifizierte Discovery-Hints nicht als offiziellen Anbieterlink ausgeben.'
Assert-True -Condition (-not ($toolMarkdown -match '\| Discovery-Hinweis \|[^\r\n]*\[Karriere\]\(')) -Message 'Coverage-Tool-Markdown darf unverifizierte Discovery-Hints nicht als offiziellen Anbieterlink ausgeben.'
foreach ($rawLabel in @('discovery_hint', 'MUNICH_20KM', 'NEVER_SCANNED', 'RETRY_REQUIRED', 'source_id', 'priority_score', 'scan_rotation')) {
    Assert-True -Condition (-not $toolHtml.Contains($rawLabel)) -Message "Coverage-Tool-HTML darf technische Labels nicht sichtbar ausgeben: $rawLabel"
}

$dedupeToolOutput = & (Join-Path $root 'tools\Measure-JobAgentCompanyCandidateDedupe.ps1') -ProjectRoot $root -MaxReviewItems 10 | ConvertFrom-Json -Depth 20
Assert-True -Condition ($dedupeToolOutput.status -eq 'ok') -Message 'Kandidaten-Dedupe-Tool liefert keinen OK-Status.'
Assert-True -Condition ($dedupeToolOutput.candidates_total -eq $hintStore.hints_total) -Message 'Kandidaten-Dedupe-Tool zaehlt Hints falsch.'
Assert-True -Condition ($dedupeToolOutput.clusters_total -gt 0) -Message 'Kandidaten-Dedupe-Tool erzeugt keine Cluster.'
Assert-True -Condition ($dedupeToolOutput.review_queue_total -gt 0) -Message 'Kandidaten-Dedupe-Tool erzeugt keine Review-Queue.'
Assert-True -Condition ($dedupeToolOutput.performance_ms -lt 10000) -Message 'Kandidaten-Dedupe-Tool ist fuer kleine Hint-Stores zu langsam.'
Assert-True -Condition (Test-Path -LiteralPath $dedupeToolOutput.json_path -PathType Leaf) -Message 'Kandidaten-Dedupe-Tool schreibt kein JSON-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $dedupeToolOutput.markdown_path -PathType Leaf) -Message 'Kandidaten-Dedupe-Tool schreibt kein Markdown-Artefakt.'
Assert-True -Condition (Test-Path -LiteralPath $dedupeToolOutput.enriched_hints_path -PathType Leaf) -Message 'Kandidaten-Dedupe-Tool schreibt keine angereicherten Hints.'
$dedupeToolJson = Get-Content -Raw -LiteralPath $dedupeToolOutput.json_path | ConvertFrom-Json -Depth 100
$dedupeToolMarkdown = Get-Content -Raw -LiteralPath $dedupeToolOutput.markdown_path
$enrichedHints = Get-Content -Raw -LiteralPath $dedupeToolOutput.enriched_hints_path | ConvertFrom-Json -Depth 100
Assert-True -Condition ($dedupeToolJson.schema_version -eq 'jobagent/company-candidate-clusters/v1') -Message 'Kandidaten-Dedupe-Tool-JSON hat falsche Schema-Version.'
Assert-True -Condition ($dedupeToolMarkdown.Contains('## Review-Queue')) -Message 'Kandidaten-Dedupe-Tool-Markdown enthaelt keine Review-Queue.'
Assert-True -Condition (@($enrichedHints.hints | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.identity_cluster_id) }).Count -eq 0) -Message 'Angereicherte Hints enthalten fehlende Cluster-IDs.'

$sourceToolOutput = & (Join-Path $root 'tools\Measure-JobAgentSourceCoverage.ps1') -ProjectRoot $root | ConvertFrom-Json -Depth 20
Assert-True -Condition ($sourceToolOutput.status -eq 'ok') -Message 'Quellenbestand-Tool liefert keinen OK-Status.'
Assert-True -Condition ($sourceToolOutput.sources_total -eq ($sourceToolOutput.by_group.job_source + $sourceToolOutput.by_group.source_registry + $sourceToolOutput.by_group.discovery_hint)) -Message 'Quellenbestand-Tool weist inkonsistente Gesamtzahl aus.'
$sourceToolMarkdown = & (Join-Path $root 'tools\Measure-JobAgentSourceCoverage.ps1') -ProjectRoot $root -Markdown
Assert-True -Condition ($sourceToolMarkdown.Contains('Quellen gesamt')) -Message 'Quellenbestand-Tool-Markdown beantwortet die Quellenanzahl nicht.'

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
        'coverage_freshness_metrics_for_companies_sources_and_candidates',
        'coverage_company_link_contract_for_career_website_ats_review_and_missing',
        'coverage_duplicate_groups_by_domain',
        'coverage_import_wave_plan',
        'daily_report_includes_coverage_and_backlog',
        'discovery_source_registry_schema_valid',
        'discovery_source_coverage_by_class_and_decision',
        'discovery_source_secondary_sources_are_not_official',
        'discovery_source_usage_notes_required',
        'secondary_hint_store_contract',
        'coverage_tool_generates_json_markdown_html_artifacts',
        'source_inventory_metrics_for_job_sources_registry_and_hints',
        'source_coverage_tool_outputs_json_and_markdown',
        'coverage_tool_html_has_responsive_guards',
        'coverage_tool_renders_clickable_provider_links',
        'coverage_tool_marks_discovery_hints_review_only',
        'coverage_candidate_cluster_metrics',
        'coverage_candidate_verification_decision_report',
        'coverage_target_inventory_gate',
        'candidate_dedupe_tool_generates_json_markdown_and_enriched_hints'
    )
} | ConvertTo-Json -Depth 4
