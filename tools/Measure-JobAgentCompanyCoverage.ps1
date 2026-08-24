#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][string]$HtmlRoot = 'html/jobagent',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$CandidateVerificationQueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$WaveConfigPath = 'data/jobagent/company-import-waves.json',
    [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 7,
    [Parameter()][ValidateRange(1, 1000)][int]$MaxPriorityItems = 25
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $repoRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $repoRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-ToolHtmlText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'UNKNOWN'
    }
    return [Net.WebUtility]::HtmlEncode(([string]$Value).Trim())
}

function ConvertTo-ToolMarkdownText {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'UNKNOWN'
    }
    return (([string]$Value).Trim() -replace '\|', '\|' -replace "`r?`n", ' ')
}

function ConvertTo-ToolDisplayLabel {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return 'Unbekannt'
    }
    $text = ([string]$Value).Trim()
    $key = $text.ToUpperInvariant()

    switch ($Domain) {
        'metric' {
            switch ($text) {
                'companies_total' { return 'Unternehmen gesamt' }
                'target_inventory_candidates_total' { return 'Zielgebiet-Kandidaten gesamt' }
                'target_inventory_gap_to_1000' { return 'Luecke bis 1000 Kandidaten' }
                'scannable_without_official_source' { return 'Scanfaehig ohne offiziellen Beleg' }
                'career_url_verified' { return 'Karriere-URL verifiziert' }
                'company_domain_verified' { return 'Firmendomain verifiziert' }
                'unverified' { return 'Nicht verifiziert' }
                'manual_review_required' { return 'Manuell zu pruefen' }
                'retry_required' { return 'Retry erforderlich' }
                'duplicate_groups' { return 'Dubletten-Gruppen' }
                'discovery_hints_total' { return 'Discovery-Hinweise gesamt' }
                'unverified_discovery_hints' { return 'Nicht verifizierte Discovery-Hinweise' }
                'company_fresh' { return 'Firmen frisch' }
                'company_refresh_due' { return 'Firmen faellig' }
                'candidate_refresh_due' { return 'Kandidaten faellig' }
                'candidate_clusters_total' { return 'Kandidaten-Cluster gesamt' }
                'candidate_conflict_clusters' { return 'Kandidaten-Cluster mit Konflikt' }
                'candidate_review_queue_total' { return 'Review-Queue gesamt' }
                'candidate_verification_queue_total' { return 'Verifikationsqueue gesamt' }
                'candidate_verification_ready' { return 'Zur Verifikation bereit' }
                'candidate_verification_verified' { return 'Verifiziert' }
                'candidate_verification_manual_review' { return 'Manueller Review' }
                'candidate_verification_retry_exhausted' { return 'Retry ausgeschoepft' }
                'sources_total' { return 'Quellen gesamt' }
                'official_sources' { return 'Offizielle Quellen' }
                'career_sources' { return 'Karrierequellen' }
                'ats_sources' { return 'ATS-Quellen' }
                'discovery_sources' { return 'Discovery-Hinweise' }
                'verified_sources' { return 'Verifizierte Quellen' }
                'unverified_sources' { return 'Offene Quellen' }
                'blocked_sources' { return 'Blockierte Quellen' }
                'retry_open_sources' { return 'Retry offen' }
                'sources_attempted_latest_run' { return 'Im letzten Lauf versucht' }
                'sources_succeeded_latest_run' { return 'Im letzten Lauf gescannt' }
                'sources_failed_latest_run' { return 'Im letzten Lauf fehlgeschlagen' }
                'never_scanned_sources' { return 'Nie gescannte Quellen' }
                'stale_sources' { return 'Faellige Quellen' }
            }
        }
        'kind' {
            switch ($key) {
                'COMPANY' { return 'Unternehmen' }
                'DISCOVERY_HINT' { return 'Discovery-Hinweis' }
                'REGIONAL_DISCOVERY_HINT' { return 'Regionaler Discovery-Hinweis' }
                'REGISTER_DISCOVERY_HINT' { return 'Register-Discovery-Hinweis' }
                'MANUAL_REVIEW_DISCOVERY' { return 'Discovery-Hinweis pruefen' }
                'CAREER_URL_DISCOVERY' { return 'Karriere-URL finden' }
                'ATS_OR_PORTAL_ADAPTER_REVIEW' { return 'ATS/Portal-Adapter pruefen' }
                'RETRY_LANE_REVIEW' { return 'Retry-Lane pruefen' }
                'STALE_SCAN_ROTATION' { return 'Faelligen Scan wiederholen' }
                'NO_MATCH_RECHECK' { return 'Ohne Treffer erneut pruefen' }
            }
        }
        'target_area' {
            switch ($key) {
                'MUNICH' { return 'Muenchen' }
                'MUNICH_20KM' { return 'Muenchen plus 20 km' }
                'FREISING' { return 'Freising' }
                'REMOTE_WITH_TARGET_REFERENCE' { return 'Remote mit Zielgebietsbezug' }
                'OUT_OF_SCOPE' { return 'Ausserhalb Zielgebiet' }
                'UNKNOWN' { return 'Unbekannt' }
            }
        }
        'status' {
            switch ($key) {
                'CAREER_URL_VERIFIED' { return 'Karriere-URL verifiziert' }
                'COMPANY_DOMAIN_VERIFIED' { return 'Firmendomain verifiziert' }
                'OFFICIAL_ATS_VERIFIED' { return 'Offizielles ATS verifiziert' }
                'MANUAL_REVIEW_REQUIRED' { return 'Manuell zu pruefen' }
                'VERIFIED_WEBSITE_ONLY' { return 'Website verifiziert, Karriere-URL fehlt' }
                'RETRY_REQUIRED' { return 'Retry erforderlich' }
                'NEVER_SCANNED' { return 'Noch nie gescannt' }
                'FRESH' { return 'Aktuell' }
                'REFRESH_DUE' { return 'Refresh faellig' }
                'EXPIRED' { return 'Abgelaufen' }
                'UNKNOWN' { return 'Unbekannt' }
                'UNVERIFIED' { return 'Nicht verifiziert' }
                'VERIFIED' { return 'Verifiziert' }
                'PENDING' { return 'Ausstehend' }
                'RETRY_SCHEDULED' { return 'Retry geplant' }
                'RETRY_EXHAUSTED' { return 'Retry ausgeschoepft' }
            }
        }
        'action' {
            switch ($key) {
                'VERIFY_OFFICIAL_SITE' { return 'Offizielle Website pruefen' }
                'CHECK_LOCATION' { return 'Standort pruefen' }
                'REJECT_DUPLICATE' { return 'Dublette ablehnen' }
                'MANUAL_DECISION' { return 'Manuell entscheiden' }
                'VERIFY_DISCOVERY_HINT' { return 'Discovery-Hinweis pruefen' }
                'FIND_CAREER_URL' { return 'Karriere-URL suchen' }
                'RETRY_SOURCE_SCAN' { return 'Quelle erneut scannen' }
                'SCAN_OFFICIAL_SOURCE' { return 'Offizielle Quelle scannen' }
                'ROTATION_RECHECK' { return 'Regulaer erneut pruefen' }
                'SCAN_ROTATION' { return 'Scan-Rotation' }
            }
        }
        'bool' {
            switch ($key) {
                'TRUE' { return 'Ja' }
                'FALSE' { return 'Nein' }
            }
        }
        'reason' {
            switch ($key) {
                'OFFICIAL_VERIFICATION_REQUIRED' { return 'Offizielle Verifikation erforderlich' }
                'SCHEDULED_REFRESH' { return 'Geplanter Refresh' }
                'MANUAL_REVIEW_DISCOVERY_HINT' { return 'Discovery-Hinweis braucht manuelle Pruefung' }
                'MISSING_CAREER_URL' { return 'Karriere-URL fehlt' }
                'LATEST_SCAN_FAILED' { return 'Letzter Scan ist fehlgeschlagen' }
                'NEVER_SCANNED' { return 'Noch nie gescannt' }
                'STALE_SCAN' { return 'Scan ist faellig' }
                'RECENT_SUCCESS_ROTATION_PENALTY' { return 'Kuerzlich erfolgreich gescannt' }
            }
        }
    }

    return ('Unbekannt ({0})' -f $text)
}

function ConvertTo-ToolDisplayMarkdownText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    return ConvertTo-ToolMarkdownText (ConvertTo-ToolDisplayLabel -Value $Value -Domain $Domain)
}

function ConvertTo-ToolDisplayHtmlText {
    param(
        [Parameter()][AllowNull()][object]$Value,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    return ConvertTo-ToolHtmlText (ConvertTo-ToolDisplayLabel -Value $Value -Domain $Domain)
}

function ConvertTo-ToolMarkdownLink {
    param([Parameter()][AllowNull()][object]$Link)

    if ($null -eq $Link) {
        return 'UNKNOWN'
    }
    $label = ConvertTo-ToolMarkdownText (Get-ToolObjectProperty -Object $Link -Name 'label' -Default 'Link')
    $url = [string](Get-ToolObjectProperty -Object $Link -Name 'url' -Default '')
    $reason = ConvertTo-ToolMarkdownText (Get-ToolObjectProperty -Object $Link -Name 'reason' -Default '')
    if ([bool](Get-ToolObjectProperty -Object $Link -Name 'is_clickable' -Default $false) -and -not [string]::IsNullOrWhiteSpace($url)) {
        $escapedUrl = $url.Replace(')', '%29').Replace(' ', '%20')
        return ('[{0}]({1})' -f $label, $escapedUrl)
    }
    if ([bool](Get-ToolObjectProperty -Object $Link -Name 'review_only' -Default $false)) {
        return ('Review-Hinweis: {0}' -f $reason)
    }
    return $reason
}

function ConvertTo-ToolHtmlLink {
    param([Parameter()][AllowNull()][object]$Link)

    if ($null -eq $Link) {
        return '<span class="link-missing">UNKNOWN</span>'
    }
    $label = ConvertTo-ToolHtmlText (Get-ToolObjectProperty -Object $Link -Name 'label' -Default 'Link')
    $url = [string](Get-ToolObjectProperty -Object $Link -Name 'url' -Default '')
    $reason = ConvertTo-ToolHtmlText (Get-ToolObjectProperty -Object $Link -Name 'reason' -Default '')
    if ([bool](Get-ToolObjectProperty -Object $Link -Name 'is_clickable' -Default $false) -and -not [string]::IsNullOrWhiteSpace($url)) {
        return ('<a class="provider-link" href="{0}" target="_blank" rel="noopener noreferrer">{1}</a>' -f (ConvertTo-ToolHtmlText $url), $label)
    }
    if ([bool](Get-ToolObjectProperty -Object $Link -Name 'review_only' -Default $false)) {
        return ('<span class="review-link">Review-Hinweis</span><span class="link-reason">{0}</span>' -f $reason)
    }
    return ('<span class="link-missing">{0}</span>' -f $reason)
}

function Get-ToolObjectProperty {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object -or $Object.PSObject.Properties.Name -notcontains $Name) {
        return $Default
    }
    return $Object.$Name
}

function New-ToolCompanyLookup {
    param([Parameter(Mandatory)][object]$Coverage)

    $lookup = @{}
    foreach ($company in @($Coverage.companies)) {
        $companyId = [string](Get-ToolObjectProperty -Object $company -Name 'company_id' -Default '')
        if (-not [string]::IsNullOrWhiteSpace($companyId) -and -not $lookup.ContainsKey($companyId)) {
            $lookup[$companyId] = $company
        }
    }
    return $lookup
}

function Get-ToolPrimaryCoverageLink {
    param(
        [Parameter()][AllowNull()][object]$Item,
        [Parameter(Mandatory)][hashtable]$CompanyLookup
    )

    $kind = [string](Get-ToolObjectProperty -Object $Item -Name 'kind' -Default '')
    if ($kind -in @('discovery_hint', 'regional_discovery_hint', 'register_discovery_hint')) {
        return [pscustomobject]@{
            label = 'Review-Hinweis'
            url = $null
            is_clickable = $false
            review_only = $true
            reason = 'Unverifizierter Discovery-Hinweis; offizielle Anbieterquelle noch nicht belegt.'
        }
    }
    $link = Get-ToolObjectProperty -Object $Item -Name 'primary_link'
    if ($null -ne $link) {
        return $link
    }
    $companyId = [string](Get-ToolObjectProperty -Object $Item -Name 'company_id' -Default '')
    if (-not [string]::IsNullOrWhiteSpace($companyId) -and $CompanyLookup.ContainsKey($companyId)) {
        return (Get-ToolObjectProperty -Object $CompanyLookup[$companyId] -Name 'primary_link')
    }
    return [pscustomobject]@{
        label = 'Review-Hinweis'
        url = $null
        is_clickable = $false
        review_only = $true
        reason = 'Unverifizierter Discovery-Hinweis; offizielle Anbieterquelle noch nicht belegt.'
    }
}

function Add-ToolMarkdownCounts {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][AllowNull()][object]$Counts,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    [void]$Lines.Add("### $Title")
    [void]$Lines.Add('| Wert | Anzahl |')
    [void]$Lines.Add('|---|---:|')
    if ($null -eq $Counts) {
        [void]$Lines.Add('| UNKNOWN | 0 |')
        return
    }
    foreach ($property in @($Counts.PSObject.Properties | Sort-Object Name)) {
        [void]$Lines.Add(('| {0} | {1} |' -f (ConvertTo-ToolDisplayMarkdownText $property.Name -Domain $Domain), $property.Value))
    }
}

function ConvertTo-ToolCoverageMarkdown {
    param([Parameter(Mandatory)][object]$Coverage)

    $companyLookup = New-ToolCompanyLookup -Coverage $Coverage
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('# JobAgent Firmen-Coverage-Audit')
    [void]$lines.Add('')
    [void]$lines.Add("- Generiert: $($Coverage.generated_at)")
    [void]$lines.Add("- Hinweis: $($Coverage.approximation_notice)")
    [void]$lines.Add('')
    [void]$lines.Add('## Kernmetriken')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('companies_total', 'target_inventory_candidates_total', 'target_inventory_gap_to_1000', 'scannable_without_official_source', 'career_url_verified', 'company_domain_verified', 'unverified', 'manual_review_required', 'retry_required', 'duplicate_groups', 'discovery_hints_total', 'unverified_discovery_hints', 'company_fresh', 'company_refresh_due', 'candidate_refresh_due', 'candidate_clusters_total', 'candidate_conflict_clusters', 'candidate_review_queue_total', 'candidate_verification_queue_total', 'candidate_verification_ready', 'candidate_verification_verified', 'candidate_verification_manual_review', 'candidate_verification_retry_exhausted')) {
        [void]$lines.Add(('| {0} | {1} |' -f (ConvertTo-ToolDisplayLabel -Value $metric -Domain 'metric'), $Coverage.metrics.$metric))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Quellenbestand')
    [void]$lines.Add('| Metrik | Wert |')
    [void]$lines.Add('|---|---:|')
    foreach ($metric in @('sources_total', 'official_sources', 'career_sources', 'ats_sources', 'discovery_sources', 'verified_sources', 'unverified_sources', 'blocked_sources', 'retry_open_sources', 'sources_attempted_latest_run', 'sources_succeeded_latest_run', 'sources_failed_latest_run', 'never_scanned_sources', 'stale_sources')) {
        [void]$lines.Add(('| {0} | {1} |' -f (ConvertTo-ToolDisplayLabel -Value $metric -Domain 'metric'), $Coverage.metrics.$metric))
    }
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Reviewstatus' -Counts $Coverage.dimensions.by_inventory_state -Domain 'status'
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Zielgebiet' -Counts $Coverage.dimensions.by_target_area -Domain 'target_area'
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Branche' -Counts $Coverage.dimensions.by_industry
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Quellenursprung' -Counts $Coverage.dimensions.by_discovery_origin
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Freshness-Status' -Counts $Coverage.dimensions.by_staleness_status -Domain 'status'
    [void]$lines.Add('')
    Add-ToolMarkdownCounts -Lines $lines -Title 'Refresh-Gruende' -Counts $Coverage.dimensions.by_refresh_reason -Domain 'reason'
    [void]$lines.Add('')
    [void]$lines.Add('## Kandidaten-Freshness')
    [void]$lines.Add('| Status | Kandidat | Firma | Quelle | Ablauf | Naechster Refresh | Grund |')
    [void]$lines.Add('|---|---|---|---|---|---|---|')
    foreach ($item in @($Coverage.candidate_freshness.items | Select-Object -First 25)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f
                (ConvertTo-ToolDisplayMarkdownText $item.staleness_status -Domain 'status'),
                (ConvertTo-ToolMarkdownText $item.candidate_id),
                (ConvertTo-ToolMarkdownText $item.company),
                (ConvertTo-ToolMarkdownText $item.source_id),
                (ConvertTo-ToolMarkdownText $item.expires_at),
                (ConvertTo-ToolMarkdownText $item.next_refresh_at),
                (ConvertTo-ToolDisplayMarkdownText $item.refresh_reason -Domain 'reason')))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Kandidaten-Dedupe')
    [void]$lines.Add('| Cluster | Firma | Grund | Kandidaten |')
    [void]$lines.Add('|---|---|---|---:|')
    foreach ($cluster in @($Coverage.candidate_clusters.review_queue | Select-Object -First 25)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} |' -f
                (ConvertTo-ToolMarkdownText $cluster.identity_cluster_id),
                (ConvertTo-ToolMarkdownText $cluster.canonical_name),
                (ConvertTo-ToolDisplayMarkdownText $cluster.review_queue_reason -Domain 'reason'),
                @($cluster.candidate_ids).Count))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Importwellen')
    [void]$lines.Add('| Welle | Ziel | Kandidaten | Firmen | Verifiziert | Nur Hinweis | Review | Scanfaehig | Annahmequote | Dublettenquote | Coverage-Delta | Gate | Backup |')
    [void]$lines.Add('|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|')
    foreach ($metric in @($Coverage.import_wave_metrics.waves)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} |' -f
                (ConvertTo-ToolMarkdownText $metric.wave_id),
                $metric.target_size,
                $metric.candidates_total,
                $metric.companies_total,
                $metric.verified_total,
                $metric.hint_only_total,
                $metric.review_total,
                $metric.scannable_total,
                $metric.acceptance_rate,
                $metric.duplicate_rate,
                $metric.coverage_delta,
                (ConvertTo-ToolMarkdownText $metric.latest_gate_status),
                (ConvertTo-ToolMarkdownText $metric.latest_backup_path)))
    }
    foreach ($wave in @($Coverage.import_waves.waves)) {
        [void]$lines.Add('')
        [void]$lines.Add("### Welle $($wave.wave_id): $($wave.title)")
        [void]$lines.Add("- Abhaengigkeit: $($wave.dependency)")
        [void]$lines.Add("- Meilenstein: $($wave.milestone)")
        [void]$lines.Add("- Prioritaetsscore: $($wave.priority_score)")
        [void]$lines.Add('| Typ | Firma | Link | Zielgebiet | Branche | Status | Naechster Schritt |')
        [void]$lines.Add('|---|---|---|---|---|---|---|')
        foreach ($candidate in @($wave.candidates)) {
            $candidateLink = Get-ToolPrimaryCoverageLink -Item $candidate -CompanyLookup $companyLookup
            [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f
                    (ConvertTo-ToolDisplayMarkdownText $candidate.kind -Domain 'kind'),
                    (ConvertTo-ToolMarkdownText $candidate.company),
                    (ConvertTo-ToolMarkdownLink $candidateLink),
                    (ConvertTo-ToolDisplayMarkdownText $candidate.target_area -Domain 'target_area'),
                    (ConvertTo-ToolMarkdownText $candidate.industry),
                    (ConvertTo-ToolDisplayMarkdownText $candidate.review_status -Domain 'status'),
                    (ConvertTo-ToolMarkdownText $candidate.next_step)))
        }
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Kandidaten-Verifikationsqueue')
    [void]$lines.Add('| Score | Aktion | Cluster | Kandidat | Firma | Status | Gruende | Quelle | Dedupe |')
    [void]$lines.Add('|---:|---|---|---|---|---|---|---|---|')
    $queueEntries = if ($null -eq $Coverage.candidate_verification_queue) { @() } else { @($Coverage.candidate_verification_queue.queue) }
    foreach ($entry in @($queueEntries | Select-Object -First 25)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |' -f
                $entry.priority_score,
                (ConvertTo-ToolDisplayMarkdownText $entry.next_action -Domain 'action'),
                (ConvertTo-ToolMarkdownText $entry.identity_cluster_id),
                (ConvertTo-ToolMarkdownText $entry.candidate_id),
                (ConvertTo-ToolMarkdownText $entry.canonical_name),
                (ConvertTo-ToolDisplayMarkdownText $entry.status -Domain 'status'),
                (ConvertTo-ToolMarkdownText (@($entry.reason_codes | ForEach-Object { ConvertTo-ToolDisplayLabel -Value $_ -Domain 'reason' }) -join ', ')),
                (ConvertTo-ToolMarkdownText (Get-ToolObjectProperty -Object $entry.source_evidence -Name 'source_id' -Default 'UNKNOWN')),
                (ConvertTo-ToolMarkdownText (@((Get-ToolObjectProperty -Object $entry.dedupe_context -Name 'conflict_flags' -Default @())) -join ', '))))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Review-/Reject-Report')
    [void]$lines.Add('| Entscheidung | Kandidat | Firma | Status | Grund | Naechster Versuch |')
    [void]$lines.Add('|---|---|---|---|---|---|')
    foreach ($entry in @($Coverage.candidate_verification_decision_report.items | Select-Object -First 25)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f
                (ConvertTo-ToolMarkdownText $entry.decision),
                (ConvertTo-ToolMarkdownText $entry.candidate_id),
                (ConvertTo-ToolMarkdownText $entry.canonical_name),
                (ConvertTo-ToolDisplayMarkdownText $entry.queue_status -Domain 'status'),
                (ConvertTo-ToolMarkdownText $entry.reason),
                (ConvertTo-ToolMarkdownText $entry.next_attempt_at)))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Backlog')
    [void]$lines.Add('| Score | Typ | Firma | Link | Begruendung | Naechster Schritt |')
    [void]$lines.Add('|---:|---|---|---|---|---|')
    foreach ($item in @($Coverage.backlog | Select-Object -First 25)) {
        $itemLink = Get-ToolPrimaryCoverageLink -Item $item -CompanyLookup $companyLookup
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f
                $item.priority_score,
                (ConvertTo-ToolDisplayMarkdownText $item.kind -Domain 'kind'),
                (ConvertTo-ToolMarkdownText $item.company),
                (ConvertTo-ToolMarkdownLink $itemLink),
                (ConvertTo-ToolMarkdownText $item.reason),
                (ConvertTo-ToolMarkdownText $item.next_step)))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Scanprioritaeten')
    [void]$lines.Add('| Score | Firma | Link | Aktion | Gruende |')
    [void]$lines.Add('|---:|---|---|---|---|')
    foreach ($item in @($Coverage.scan_priority | Select-Object -First 25)) {
        $itemLink = Get-ToolPrimaryCoverageLink -Item $item -CompanyLookup $companyLookup
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f
                $item.priority_score,
                (ConvertTo-ToolMarkdownText $item.company),
                (ConvertTo-ToolMarkdownLink $itemLink),
                (ConvertTo-ToolDisplayMarkdownText $item.next_action -Domain 'action'),
                (ConvertTo-ToolMarkdownText (@($item.reasons | ForEach-Object { ConvertTo-ToolDisplayLabel -Value $_ -Domain 'reason' }) -join ', '))))
    }
    [void]$lines.Add('')
    [void]$lines.Add('## Firmeninventar')
    [void]$lines.Add('| Firma | Link | Zielgebiet | Verifikation | Freshness | Naechster Refresh | Status | Scanfaehig | Naechster Schritt |')
    [void]$lines.Add('|---|---|---|---|---|---|---|---|---|')
    foreach ($company in @($Coverage.companies | Select-Object -First 250)) {
        [void]$lines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} |' -f
                (ConvertTo-ToolMarkdownText $company.company),
                (ConvertTo-ToolMarkdownLink $company.primary_link),
                (ConvertTo-ToolDisplayMarkdownText $company.target_area -Domain 'target_area'),
                (ConvertTo-ToolDisplayMarkdownText $company.verification_status -Domain 'status'),
                (ConvertTo-ToolDisplayMarkdownText $company.staleness_status -Domain 'status'),
                (ConvertTo-ToolMarkdownText $company.next_refresh_at),
                (ConvertTo-ToolDisplayMarkdownText $company.inventory_state -Domain 'status'),
                (ConvertTo-ToolDisplayMarkdownText $company.has_career_url -Domain 'bool'),
                (ConvertTo-ToolMarkdownText $company.next_step)))
    }
    return ($lines.ToArray() -join "`n")
}

function Add-ToolHtmlCounts {
    param(
        [Parameter(Mandatory)][object]$Lines,
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][AllowNull()][object]$Counts,
        [Parameter()][AllowEmptyString()][string]$Domain = 'generic'
    )

    [void]$Lines.Add('<section><h2>' + (ConvertTo-ToolHtmlText $Title) + '</h2><div class="table-wrap"><table><thead><tr><th>Wert</th><th>Anzahl</th></tr></thead><tbody>')
    foreach ($property in @($Counts.PSObject.Properties | Sort-Object Name)) {
        [void]$Lines.Add('<tr><td>' + (ConvertTo-ToolDisplayHtmlText $property.Name -Domain $Domain) + '</td><td>' + (ConvertTo-ToolHtmlText $property.Value) + '</td></tr>')
    }
    [void]$Lines.Add('</tbody></table></div></section>')
}

function ConvertTo-ToolCoverageHtml {
    param([Parameter(Mandatory)][object]$Coverage)

    $companyLookup = New-ToolCompanyLookup -Coverage $Coverage
    $lines = [System.Collections.Generic.List[string]]::new()
    [void]$lines.Add('<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
    [void]$lines.Add('<title>JobAgent Firmen-Coverage-Audit</title><style>')
    [void]$lines.Add(':root { color-scheme: light; --bg: #eef2f5; --surface: #ffffff; --surface-alt: #f6f8fa; --line: #c8d1dc; --text: #17202a; --muted: #52616f; --accent: #0f6b6d; --accent-alt: #8a5a00; }')
    [void]$lines.Add('* { box-sizing: border-box; } body { margin: 0; font-family: "Segoe UI", Tahoma, sans-serif; background: var(--bg); color: var(--text); } main { max-width: 1440px; margin: 0 auto; padding: 24px 16px 40px; } section { background: var(--surface); border: 1px solid var(--line); border-radius: 8px; padding: 16px; margin-bottom: 16px; } h1, h2, h3 { margin: 0 0 12px; line-height: 1.2; letter-spacing: 0; } h1 { font-size: 2rem; color: var(--accent); } h2 { font-size: 1.25rem; } p { line-height: 1.5; } .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; } .metric { background: var(--surface-alt); border: 1px solid var(--line); border-radius: 6px; padding: 10px; min-width: 0; } .label { display: block; color: var(--muted); font-size: .86rem; } .value { display: block; font-weight: 700; overflow-wrap: anywhere; } .table-wrap { overflow-x: auto; } .table-wrap { overflow-y: auto; max-height: 68vh; border: 1px solid var(--line); } table { width: 100%; min-width: 760px; border-collapse: collapse; } th, td { text-align: left; vertical-align: top; padding: 9px 10px; border-bottom: 1px solid var(--line); overflow-wrap: anywhere; } th { background: #e8eef3; position: sticky; top: 0; z-index: 1; } .provider-link { color: var(--accent); font-weight: 700; text-decoration-thickness: 1px; text-underline-offset: 3px; overflow-wrap: anywhere; } .review-link, .link-missing { display: inline-block; color: var(--accent-alt); font-weight: 700; } .link-reason { display: block; max-width: 36ch; color: var(--muted); font-size: .82rem; line-height: 1.35; overflow-wrap: anywhere; } .wave { border-left: 4px solid var(--accent-alt); padding-left: 12px; margin-top: 14px; } @media (max-width: 800px) { main { padding: 14px 10px 28px; } section { padding: 12px; } table { min-width: 720px; } }')
    [void]$lines.Add('</style></head><body><main>')
    [void]$lines.Add('<section><h1>JobAgent Firmen-Coverage-Audit</h1><p>' + (ConvertTo-ToolHtmlText $Coverage.approximation_notice) + '</p><div class="summary">')
    foreach ($metric in @('companies_total', 'target_inventory_candidates_total', 'target_inventory_gap_to_1000', 'scannable_without_official_source', 'career_url_verified', 'company_domain_verified', 'unverified', 'manual_review_required', 'retry_required', 'duplicate_groups', 'discovery_hints_total', 'unverified_discovery_hints', 'company_fresh', 'company_refresh_due', 'candidate_refresh_due', 'candidate_clusters_total', 'candidate_conflict_clusters', 'candidate_review_queue_total', 'candidate_verification_queue_total', 'candidate_verification_ready', 'candidate_verification_verified', 'candidate_verification_manual_review', 'candidate_verification_retry_exhausted')) {
        [void]$lines.Add('<div class="metric"><span class="label">' + (ConvertTo-ToolDisplayHtmlText $metric -Domain 'metric') + '</span><span class="value">' + (ConvertTo-ToolHtmlText $Coverage.metrics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div></section>')
    [void]$lines.Add('<section><h2>Quellenbestand</h2><div class="summary">')
    foreach ($metric in @('sources_total', 'official_sources', 'career_sources', 'ats_sources', 'discovery_sources', 'verified_sources', 'unverified_sources', 'blocked_sources', 'retry_open_sources', 'sources_attempted_latest_run', 'sources_succeeded_latest_run', 'sources_failed_latest_run', 'never_scanned_sources', 'stale_sources')) {
        [void]$lines.Add('<div class="metric"><span class="label">' + (ConvertTo-ToolDisplayHtmlText $metric -Domain 'metric') + '</span><span class="value">' + (ConvertTo-ToolHtmlText $Coverage.metrics.$metric) + '</span></div>')
    }
    [void]$lines.Add('</div></section>')
    Add-ToolHtmlCounts -Lines $lines -Title 'Reviewstatus' -Counts $Coverage.dimensions.by_inventory_state -Domain 'status'
    Add-ToolHtmlCounts -Lines $lines -Title 'Zielgebiet' -Counts $Coverage.dimensions.by_target_area -Domain 'target_area'
    Add-ToolHtmlCounts -Lines $lines -Title 'Branche' -Counts $Coverage.dimensions.by_industry
    Add-ToolHtmlCounts -Lines $lines -Title 'Freshness-Status' -Counts $Coverage.dimensions.by_staleness_status -Domain 'status'
    Add-ToolHtmlCounts -Lines $lines -Title 'Refresh-Gruende' -Counts $Coverage.dimensions.by_refresh_reason -Domain 'reason'
    [void]$lines.Add('<section><h2>Kandidaten-Freshness</h2><div class="table-wrap"><table><thead><tr><th>Status</th><th>Kandidat</th><th>Firma</th><th>Quellen-ID (Diagnose)</th><th>Ablauf</th><th>Naechster Refresh</th><th>Grund</th></tr></thead><tbody>')
    foreach ($item in @($Coverage.candidate_freshness.items | Select-Object -First 25)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolDisplayHtmlText $item.staleness_status -Domain 'status') + '</td><td>' + (ConvertTo-ToolHtmlText $item.candidate_id) + '</td><td>' + (ConvertTo-ToolHtmlText $item.company) + '</td><td>' + (ConvertTo-ToolHtmlText $item.source_id) + '</td><td>' + (ConvertTo-ToolHtmlText $item.expires_at) + '</td><td>' + (ConvertTo-ToolHtmlText $item.next_refresh_at) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $item.refresh_reason -Domain 'reason') + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section>')
    [void]$lines.Add('<section><h2>Kandidaten-Dedupe</h2><div class="table-wrap"><table><thead><tr><th>Cluster</th><th>Firma</th><th>Grund</th><th>Kandidaten</th></tr></thead><tbody>')
    foreach ($cluster in @($Coverage.candidate_clusters.review_queue | Select-Object -First 25)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $cluster.identity_cluster_id) + '</td><td>' + (ConvertTo-ToolHtmlText $cluster.canonical_name) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $cluster.review_queue_reason -Domain 'reason') + '</td><td>' + (ConvertTo-ToolHtmlText @($cluster.candidate_ids).Count) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section>')
    [void]$lines.Add('<section><h2>Kandidaten-Verifikationsqueue</h2><div class="table-wrap"><table><thead><tr><th>Score</th><th>Aktion</th><th>Cluster</th><th>Kandidat</th><th>Firma</th><th>Status</th><th>Gruende</th><th>Quelle</th><th>Dedupe</th></tr></thead><tbody>')
    $queueEntries = if ($null -eq $Coverage.candidate_verification_queue) { @() } else { @($Coverage.candidate_verification_queue.queue) }
    foreach ($entry in @($queueEntries | Select-Object -First 25)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $entry.priority_score) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $entry.next_action -Domain 'action') + '</td><td>' + (ConvertTo-ToolHtmlText $entry.identity_cluster_id) + '</td><td>' + (ConvertTo-ToolHtmlText $entry.candidate_id) + '</td><td>' + (ConvertTo-ToolHtmlText $entry.canonical_name) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $entry.status -Domain 'status') + '</td><td>' + (ConvertTo-ToolHtmlText (@($entry.reason_codes | ForEach-Object { ConvertTo-ToolDisplayLabel -Value $_ -Domain 'reason' }) -join ', ')) + '</td><td>' + (ConvertTo-ToolHtmlText (Get-ToolObjectProperty -Object $entry.source_evidence -Name 'source_id' -Default 'UNKNOWN')) + '</td><td>' + (ConvertTo-ToolHtmlText (@((Get-ToolObjectProperty -Object $entry.dedupe_context -Name 'conflict_flags' -Default @())) -join ', ')) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section>')
    [void]$lines.Add('<section><h2>Review-/Reject-Report</h2><div class="table-wrap"><table><thead><tr><th>Entscheidung</th><th>Kandidat</th><th>Firma</th><th>Status</th><th>Grund</th><th>Naechster Versuch</th></tr></thead><tbody>')
    foreach ($entry in @($Coverage.candidate_verification_decision_report.items | Select-Object -First 25)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $entry.decision) + '</td><td>' + (ConvertTo-ToolHtmlText $entry.candidate_id) + '</td><td>' + (ConvertTo-ToolHtmlText $entry.canonical_name) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $entry.queue_status -Domain 'status') + '</td><td>' + (ConvertTo-ToolHtmlText $entry.reason) + '</td><td>' + (ConvertTo-ToolHtmlText $entry.next_attempt_at) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section>')
    [void]$lines.Add('<section><h2>Importwellen</h2>')
    [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Welle</th><th>Ziel</th><th>Kandidaten</th><th>Firmen</th><th>Verifiziert</th><th>Nur Hinweis</th><th>Review</th><th>Scanfaehig</th><th>Annahmequote</th><th>Dublettenquote</th><th>Coverage-Delta</th><th>Gate</th><th>Backup</th></tr></thead><tbody>')
    foreach ($metric in @($Coverage.import_wave_metrics.waves)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $metric.wave_id) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.target_size) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.candidates_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.companies_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.verified_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.hint_only_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.review_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.scannable_total) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.acceptance_rate) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.duplicate_rate) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.coverage_delta) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.latest_gate_status) + '</td><td>' + (ConvertTo-ToolHtmlText $metric.latest_backup_path) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div>')
    foreach ($wave in @($Coverage.import_waves.waves)) {
        [void]$lines.Add('<div class="wave"><h3>Welle ' + (ConvertTo-ToolHtmlText $wave.wave_id) + ': ' + (ConvertTo-ToolHtmlText $wave.title) + '</h3><p>Abhaengigkeit: ' + (ConvertTo-ToolHtmlText $wave.dependency) + ' | Meilenstein: ' + (ConvertTo-ToolHtmlText $wave.milestone) + ' | Score: ' + (ConvertTo-ToolHtmlText $wave.priority_score) + '</p>')
        [void]$lines.Add('<div class="table-wrap"><table><thead><tr><th>Typ</th><th>Firma</th><th>Link</th><th>Zielgebiet</th><th>Branche</th><th>Status</th><th>Naechster Schritt</th></tr></thead><tbody>')
        foreach ($candidate in @($wave.candidates)) {
            $candidateLink = Get-ToolPrimaryCoverageLink -Item $candidate -CompanyLookup $companyLookup
            [void]$lines.Add('<tr><td>' + (ConvertTo-ToolDisplayHtmlText $candidate.kind -Domain 'kind') + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.company) + '</td><td>' + (ConvertTo-ToolHtmlLink $candidateLink) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $candidate.target_area -Domain 'target_area') + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.industry) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $candidate.review_status -Domain 'status') + '</td><td>' + (ConvertTo-ToolHtmlText $candidate.next_step) + '</td></tr>')
        }
        [void]$lines.Add('</tbody></table></div></div>')
    }
    [void]$lines.Add('</section><section><h2>Backlog</h2><div class="table-wrap"><table><thead><tr><th>Score</th><th>Typ</th><th>Firma</th><th>Link</th><th>Begruendung</th><th>Naechster Schritt</th></tr></thead><tbody>')
    foreach ($item in @($Coverage.backlog | Select-Object -First 25)) {
        $itemLink = Get-ToolPrimaryCoverageLink -Item $item -CompanyLookup $companyLookup
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $item.kind -Domain 'kind') + '</td><td>' + (ConvertTo-ToolHtmlText $item.company) + '</td><td>' + (ConvertTo-ToolHtmlLink $itemLink) + '</td><td>' + (ConvertTo-ToolHtmlText $item.reason) + '</td><td>' + (ConvertTo-ToolHtmlText $item.next_step) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section><section><h2>Scanprioritaeten</h2><div class="table-wrap"><table><thead><tr><th>Score</th><th>Firma</th><th>Link</th><th>Aktion</th><th>Gruende</th></tr></thead><tbody>')
    foreach ($item in @($Coverage.scan_priority | Select-Object -First 25)) {
        $itemLink = Get-ToolPrimaryCoverageLink -Item $item -CompanyLookup $companyLookup
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $item.priority_score) + '</td><td>' + (ConvertTo-ToolHtmlText $item.company) + '</td><td>' + (ConvertTo-ToolHtmlLink $itemLink) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $item.next_action -Domain 'action') + '</td><td>' + (ConvertTo-ToolHtmlText (@($item.reasons | ForEach-Object { ConvertTo-ToolDisplayLabel -Value $_ -Domain 'reason' }) -join ', ')) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section><section><h2>Firmeninventar</h2><p>Segmentierte Anzeige: maximal 250 sortierte Firmen im HTML-Audit; vollstaendige Daten stehen im JSON-Artefakt.</p><div class="table-wrap"><table><thead><tr><th>Firma</th><th>Link</th><th>Zielgebiet</th><th>Verifikation</th><th>Freshness</th><th>Naechster Refresh</th><th>Status</th><th>Scanfaehig</th><th>Naechster Schritt</th></tr></thead><tbody>')
    foreach ($company in @($Coverage.companies | Select-Object -First 250)) {
        [void]$lines.Add('<tr><td>' + (ConvertTo-ToolHtmlText $company.company) + '</td><td>' + (ConvertTo-ToolHtmlLink $company.primary_link) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $company.target_area -Domain 'target_area') + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $company.verification_status -Domain 'status') + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $company.staleness_status -Domain 'status') + '</td><td>' + (ConvertTo-ToolHtmlText $company.next_refresh_at) + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $company.inventory_state -Domain 'status') + '</td><td>' + (ConvertTo-ToolDisplayHtmlText $company.has_career_url -Domain 'bool') + '</td><td>' + (ConvertTo-ToolHtmlText $company.next_step) + '</td></tr>')
    }
    [void]$lines.Add('</tbody></table></div></section></main></body></html>')
    return ($lines.ToArray() -join "`n")
}

function Get-ToolWaveGateHistory {
    param([Parameter(Mandatory)][string]$Root)

    $logRootPath = Resolve-ToolPath -Root $Root -Path $LogRoot
    if (-not (Test-Path -LiteralPath $logRootPath -PathType Container)) {
        return @()
    }
    $items = foreach ($file in @(Get-ChildItem -LiteralPath $logRootPath -Filter 'company-discovery-import*.json' -File -ErrorAction SilentlyContinue)) {
        try {
            $entry = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json -Depth 100
            if ($null -eq $entry.wave_gate) {
                continue
            }
            [pscustomobject]@{
                ts = [string]$entry.ts
                wave_id = [string]$entry.wave_id
                status = [string]$entry.wave_gate.status
                metrics = $entry.wave_gate.metrics
                violations = @($entry.wave_gate.violations)
                backup_path = [string]$entry.backup_path
                log_path = $file.FullName
            }
        }
        catch {
            continue
        }
    }
    return @($items | Sort-Object ts)
}

$sourceRegistry = $null
$sourceRegistryResolved = Resolve-ToolPath -Root $projectRoot -Path $SourceRegistryPath
if (Test-Path -LiteralPath $sourceRegistryResolved -PathType Leaf) {
    $sourceRegistry = Get-Content -Raw -LiteralPath $sourceRegistryResolved | ConvertFrom-Json -Depth 100
}

$hintStore = $null
$hintStoreResolved = Resolve-ToolPath -Root $projectRoot -Path $HintStorePath
if (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf) {
    $hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
}

$candidateVerificationQueue = $null
$candidateVerificationQueueResolved = Resolve-ToolPath -Root $projectRoot -Path $CandidateVerificationQueuePath
if (Test-Path -LiteralPath $candidateVerificationQueueResolved -PathType Leaf) {
    $candidateVerificationQueue = Get-Content -Raw -LiteralPath $candidateVerificationQueueResolved | ConvertFrom-Json -Depth 100
}

$waveConfig = $null
$waveConfigResolved = Resolve-ToolPath -Root $projectRoot -Path $WaveConfigPath
if (Test-Path -LiteralPath $waveConfigResolved -PathType Leaf) {
    $waveConfig = Get-Content -Raw -LiteralPath $waveConfigResolved | ConvertFrom-Json -Depth 100
}
$waveGateHistory = @(Get-ToolWaveGateHistory -Root $projectRoot)

$generatedAt = [datetime]::UtcNow
$document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$coverage = New-JobAgentCoverageReport -Document $document -SourceRegistry $sourceRegistry -HintStore $hintStore -CandidateVerificationQueue $candidateVerificationQueue -WaveConfig $waveConfig -WaveGateHistory $waveGateHistory -Now $generatedAt -StaleAfterDays $StaleAfterDays -MaxPriorityItems $MaxPriorityItems
$stamp = $generatedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)

$logRootPath = Resolve-ToolPath -Root $projectRoot -Path $LogRoot
$htmlRootPath = Resolve-ToolPath -Root $projectRoot -Path $HtmlRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
New-Item -ItemType Directory -Path $htmlRootPath -Force | Out-Null

$jsonPath = Join-Path $logRootPath "company-coverage-$stamp.json"
$markdownPath = Join-Path $logRootPath "company-coverage-$stamp.md"
$htmlPath = Join-Path $htmlRootPath 'company-coverage.html'

$coverage | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
ConvertTo-ToolCoverageMarkdown -Coverage $coverage | Set-Content -LiteralPath $markdownPath -Encoding UTF8
ConvertTo-ToolCoverageHtml -Coverage $coverage | Set-Content -LiteralPath $htmlPath -Encoding UTF8
if ($null -ne $coverage.candidate_verification_queue) {
    $queuePath = Resolve-ToolPath -Root $projectRoot -Path $CandidateVerificationQueuePath
    New-Item -ItemType Directory -Path (Split-Path -Parent $queuePath) -Force | Out-Null
    $coverage.candidate_verification_queue | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $queuePath -Encoding UTF8
}

[pscustomobject]@{
    status = 'ok'
    generated_at = $coverage.generated_at
    json_path = $jsonPath
    markdown_path = $markdownPath
    html_path = $htmlPath
    candidate_verification_queue_path = if ($null -eq $coverage.candidate_verification_queue) { $null } else { (Resolve-ToolPath -Root $projectRoot -Path $CandidateVerificationQueuePath) }
    companies_total = $coverage.metrics.companies_total
    backlog_items = @($coverage.backlog).Count
    duplicate_groups = $coverage.metrics.duplicate_groups
    target_inventory_candidates_total = $coverage.metrics.target_inventory_candidates_total
    target_inventory_gap_to_1000 = $coverage.metrics.target_inventory_gap_to_1000
    target_inventory_gate_status = $coverage.target_inventory_gate.status
    import_waves = @($coverage.import_waves.waves).Count
    sources_total = $coverage.metrics.sources_total
    official_sources = $coverage.metrics.official_sources
    discovery_sources = $coverage.metrics.discovery_sources
    sources_attempted_latest_run = $coverage.metrics.sources_attempted_latest_run
    import_wave_metrics = $coverage.import_wave_metrics
} | ConvertTo-Json -Depth 6
