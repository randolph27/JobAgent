#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$toolPath = Join-Path $root 'tools\Measure-JobAgentDiscoverySourceInventory.ps1'
$output = & $toolPath -ProjectRoot $root | ConvertFrom-Json -Depth 100

Assert-True -Condition ($output.status -eq 'ok') -Message 'JA-027.2 Quelleninventur liefert keinen OK-Status.'
Assert-True -Condition ($output.sources_total -eq 35) -Message 'Quelleninventur muss alle 35 Registry-Quellen ausweisen.'
Assert-True -Condition ($output.hints_total -eq 1833) -Message 'Quelleninventur zaehlt Discovery-Hints falsch.'
Assert-True -Condition ($output.queue_total -eq 1831) -Message 'Quelleninventur zaehlt Kandidatenqueue falsch.'
Assert-True -Condition ($output.hints_without_queue -eq 0) -Message 'Alle Hints muessen ueber candidate_id oder candidate_ids in der Queue erreichbar sein.'
Assert-True -Condition ($output.research_candidates_total -ge 6) -Message 'Quellenrecherche muss mindestens sechs neue Ansaetze dokumentieren.'

foreach ($pathProperty in @('inventory_path', 'research_path', 'reconciliation_path')) {
    $relativePath = [string]$output.$pathProperty
    $fullPath = Join-Path $root $relativePath
    Assert-True -Condition (Test-Path -LiteralPath $fullPath -PathType Leaf) -Message "Evidence-Datei fehlt: $relativePath"
}

$inventory = Get-Content -Raw -LiteralPath (Join-Path $root ([string]$output.inventory_path)) | ConvertFrom-Json -Depth 100
$research = Get-Content -Raw -LiteralPath (Join-Path $root ([string]$output.research_path)) | ConvertFrom-Json -Depth 100
$reconciliation = Get-Content -Raw -LiteralPath (Join-Path $root ([string]$output.reconciliation_path)) | ConvertFrom-Json -Depth 100

Assert-True -Condition ($inventory.schema_version -eq 'jobagent/source-inventory-ja0272/v1') -Message 'Quelleninventur hat falsches Schema.'
Assert-True -Condition (@($inventory.sources).Count -eq 35) -Message 'Quelleninventur enthaelt nicht jede Registry-Quelle als Zeile.'
Assert-True -Condition ($inventory.totals.retained_discovery_inventory -ge 2000) -Message 'Retention-Bestand wird in der Quelleninventur nicht mitgefuehrt.'
Assert-True -Condition ($inventory.totals.retained_discovered_urls -ge 1000) -Message 'Retained-URL-Bestand wird in der Quelleninventur nicht mitgefuehrt.'
Assert-True -Condition ($inventory.totals.PSObject.Properties.Name -contains 'structured_url_hints') -Message 'Quelleninventur weist strukturierte Website-/Karrierehinweise nicht aus.'
Assert-True -Condition (@($inventory.sources | Where-Object { $_.PSObject.Properties.Name -contains 'structured_url_hint_count' }).Count -eq 35) -Message 'Quelleninventur muss je Quelle strukturierte URL-Hints zaehlen.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:openstreetmap_overpass_business_names' -and [int]$_.hint_count -ge 1000 }).Count -eq 1) -Message 'OSM-Hinweise werden nicht der Quelle zugeordnet.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:ba_jobsuche' -and [int]$_.hint_count -eq 4 }).Count -eq 1) -Message 'BA-Hinweise werden nicht exakt ausgewiesen.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:stepstone_freising' -and [int]$_.hint_count -eq 2 -and [int]$_.queue_count -eq 2 }).Count -eq 1) -Message 'Nicht-primaere Cluster-Kandidaten muessen ihrer Quelle in der Queue zugeordnet bleiben.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:izb_startups' -and [int]$_.hint_count -eq 27 -and [int]$_.queue_count -eq 27 }).Count -eq 1) -Message 'IZB-Startup-Quelle wird nicht nachgefuehrt.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:landkreis_muenchen_gruenderzentren' -and [int]$_.hint_count -eq 4 -and [int]$_.queue_count -eq 4 }).Count -eq 1) -Message 'Landkreis-Muenchen-Gruenderzentren werden nicht nachgefuehrt.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:stadt_muenchen_gruenderzentren' -and [int]$_.hint_count -eq 12 -and [int]$_.queue_count -eq 12 }).Count -eq 1) -Message 'Stadt-Muenchen-Gruenderzentren werden nicht nachgefuehrt.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:linkedin_jobs' -and [string]$_.next_action -eq 'blocked' }).Count -eq 1) -Message 'Blockierte Quellen muessen fail-closed ausgewiesen werden.'
Assert-True -Condition (@($inventory.sources | Where-Object { @($_.sample_hints).Count -gt 3 }).Count -eq 0) -Message 'Quellensamples duerfen maximal drei Hints enthalten.'

Assert-True -Condition ($reconciliation.schema_version -eq 'jobagent/candidate-reconciliation-ja0272/v1') -Message 'Reconciliation hat falsches Schema.'
Assert-True -Condition (@($reconciliation.hints_without_queue).Count -eq 0) -Message 'Reconciliation darf keine bereits in candidate_ids enthaltenen Hints als fehlend melden.'
Assert-True -Condition (@($reconciliation.hints_without_queue | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.explanation) }).Count -eq 0) -Message 'Hints ohne Queue brauchen eine Erklaerung.'
Assert-True -Condition (@($reconciliation.small_hint_sources | Where-Object { [string]$_.explanation -match 'kein Quellenerschoepfungsnachweis' }).Count -ge 1) -Message 'Kleine Bestaende muessen gegen Quellenerschoepfungsdeutung abgesichert werden.'

Assert-True -Condition ($research.schema_version -eq 'jobagent/source-research/v1') -Message 'Quellenrecherche hat falsches Schema.'
Assert-True -Condition (@($research.source_candidates).Count -ge 6) -Message 'Quellenrecherche enthaelt zu wenige Quellenansaetze.'
Assert-True -Condition ([int]$research.final_decisions_total -ge 4) -Message 'Quellenrecherche muss die vier offenen JA-027.2-Quellen final entscheiden.'
foreach ($family in @('Kammer-/Branchenverzeichnis', 'Startup-/Technologieverzeichnis', 'Forschungs-/Hochschul-Ausgruendungen', 'Technologiepark-/Gruenderzentrum-Mitglieder')) {
    Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.family -eq $family }).Count -ge 1) -Message "Quellenfamilie fehlt: $family"
}
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.allowed_use_decision -match 'official' }).Count -eq 0) -Message 'Rechercheansaetze duerfen nicht als offizielle Karrierequellen markiert werden.'
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.source_id -eq 'research-candidate:hwk_muenchen_oberbayern_handwerkersuche' -and [string]$_.decision_status -eq 'blocked_for_automated_import' }).Count -eq 1) -Message 'HWK-Handwerkersuche muss fuer automatisierten Import blockiert sein.'
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.source_id -eq 'research-candidate:biom_company_database' -and [string]$_.decision_status -eq 'deferred_for_parser_contract' }).Count -eq 1) -Message 'BioM muss bis zum Snapshot-/Parservertrag geparkt sein.'
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.source_id -eq 'research-candidate:stadt_freising_wirtschaft' -and [string]$_.source_decision -eq 'covered_by_existing_specific_source' }).Count -eq 1) -Message 'Stadt-Freising-Wirtschaft muss durch spezifische Quelle statt neue Allgemeinquelle entschieden sein.'
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.source_id -eq 'research-candidate:ihk_standortportal_bayern' -and [string]$_.decision_status -eq 'not_registered_for_import' }).Count -eq 1) -Message 'IHK-Standortportal darf ohne Export/API nicht fuer Import registriert sein.'
Assert-True -Condition (@($research.source_candidates | Where-Object { $_.PSObject.Properties.Name -contains 'source_decision' -and @($_.evidence_urls).Count -lt 1 }).Count -eq 0) -Message 'Final entschiedene Quellen brauchen Evidence-URLs.'

$refillRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-discovery-refill-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $refillRoot 'data\jobagent') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $refillRoot 'snapshots') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $refillRoot 'logs\jobagent') -Force | Out-Null
try {
    $fixtureSource = [pscustomobject]@{
        source_id = 'source-registry:refill_regional'
        source_class = 'REGIONAL_DIRECTORY'
        source_url = 'https://directory.example.invalid/companies'
        operator = 'Fixture Directory'
        allowed_use = 'Fixture snapshot only.'
        forbidden_use = 'No live crawl.'
        rate_limit_policy = 'Fixture.'
        robots_or_terms_note = 'Fixture.'
        expected_fields = @('company_name', 'source_url')
        evidence_level = 'SECONDARY_OFFICIAL_DIRECTORY'
        freshness_policy = 'Fixture.'
        retention_policy = 'Minimal fixture metadata.'
        import_mode = 'FIXTURE_OR_SNAPSHOT_ONLY'
        review_required = $true
        legal_risk = 'LOW'
    }
    [pscustomobject]@{
        schema_version = 'jobagent/discovery-source/v2'
        generated_at = '2026-09-13T08:00:00.000Z'
        items = @(
            $fixtureSource,
            [pscustomobject]@{
                source_id = 'source-registry:blocked_refill'
                source_class = 'REJECTED'
                source_url = 'https://blocked.example.invalid/'
                operator = 'Blocked'
                allowed_use = 'Nicht verwenden.'
                forbidden_use = 'Automatisierter Abruf ist blockiert.'
                rate_limit_policy = 'Blocked.'
                robots_or_terms_note = 'Blocked.'
                expected_fields = @('company_name')
                evidence_level = 'NOT_IMPORTABLE'
                freshness_policy = 'Nicht importieren.'
                retention_policy = 'Nur Entscheidung.'
                import_mode = 'REJECT'
                review_required = $true
                legal_risk = 'BLOCKED'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $refillRoot 'data\jobagent\company-discovery.sources.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-snapshot-manifest/v1'
        generated_at = '2026-09-13T08:00:00.000Z'
        contract = 'Fixture'
        items = @(
            [pscustomobject]@{
                kind = 'regional'
                source_id = 'source-registry:refill_regional'
                input_path = 'snapshots/regional.json'
            },
            [pscustomobject]@{
                kind = 'regional'
                source_id = 'source-registry:blocked_refill'
                input_path = 'snapshots/blocked.json'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $refillRoot 'data\jobagent\company-discovery.snapshot.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/regional-directory-snapshot/v1'
        generated_at = '2026-09-13T08:00:00.000Z'
        sources = @(
            [pscustomobject]@{
                source_id = 'source-registry:refill_regional'
                format = 'json_items'
                source_page = 'https://directory.example.invalid/companies'
                region_reference = 'Muenchen'
                items = @(
                    [pscustomobject]@{
                        organization_name = 'Refill Alpha GmbH'
                        sector = 'Technology'
                        location = 'Muenchen'
                        website_hint = 'https://refill-alpha.example.invalid/'
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $refillRoot 'snapshots\regional.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/regional-directory-snapshot/v1'
        generated_at = '2026-09-13T08:00:00.000Z'
        sources = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $refillRoot 'snapshots\blocked.json') -Encoding UTF8
    [pscustomobject]@{
        schema_version = 'jobagent/store/v1'
        companies = @()
        job_sources = @()
        jobs = @()
        scan_attempts = @()
        scan_runs = @()
        job_snapshots = @()
        change_events = @()
        discovery_inventory = @()
        discovered_urls = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $refillRoot 'data\jobagent\store.json') -Encoding UTF8

    $refillOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDiscoveryRefill.ps1') -ProjectRoot $refillRoot -MaxSources 2 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Discovery-Refill ist fehlgeschlagen: " + ($refillOutput -join "`n"))
    $refill = ($refillOutput -join "`n") | ConvertFrom-Json -Depth 100
    $refillHints = Get-Content -Raw -LiteralPath (Join-Path $refillRoot 'data\jobagent\company-discovery.hints.json') | ConvertFrom-Json -Depth 100
    $refillQueue = Get-Content -Raw -LiteralPath (Join-Path $refillRoot 'data\jobagent\company-candidate-verification.queue.json') | ConvertFrom-Json -Depth 100
    $refillState = Get-Content -Raw -LiteralPath (Join-Path $refillRoot 'data\jobagent\company-discovery.refill.state.json') | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($refill.status -eq 'COMPLETED') -Message 'Discovery-Refill meldet keinen abgeschlossenen Quellenlauf.'
    Assert-True -Condition ($refill.imported_sources_total -eq 1) -Message 'Discovery-Refill darf blockierte Quellen nicht importieren.'
    Assert-True -Condition (@($refillHints.hints | Where-Object { [string]$_.company_name -eq 'Refill Alpha GmbH' -and [string]$_.website_hint -eq 'https://refill-alpha.example.invalid/' }).Count -eq 1) -Message 'Discovery-Refill transportiert Snapshot-Hints nicht in den Hint-Store.'
    Assert-True -Condition (@($refillQueue.queue | Where-Object { [string]$_.candidate_id -match 'refill_alpha' }).Count -eq 1) -Message 'Discovery-Refill baut die Kandidatenqueue nicht nach.'
    Assert-True -Condition (@($refillState.imports | Where-Object { [string]$_.source_id -eq 'source-registry:refill_regional' -and -not [string]::IsNullOrWhiteSpace([string]$_.input_hash) }).Count -eq 1) -Message 'Discovery-Refill persistiert keinen Quellen-Cursor mit Inputhash.'

    $secondRefillOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Invoke-JobAgentDiscoveryRefill.ps1') -ProjectRoot $refillRoot -MaxSources 2 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Discovery-Refill-Zweitlauf ist fehlgeschlagen: " + ($secondRefillOutput -join "`n"))
    $secondRefill = ($secondRefillOutput -join "`n") | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($secondRefill.imported_sources_total -eq 0) -Message 'Discovery-Refill darf unveraenderte Snapshotquellen nicht erneut importieren.'
}
finally {
    if (Test-Path -LiteralPath $refillRoot) {
        Remove-Item -LiteralPath $refillRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'source_inventory_writes_required_evidence',
        'all_registry_sources_reconciled',
        'cluster_candidate_ids_count_as_queue_coverage',
        'small_source_counts_are_not_exhaustion',
        'structured_url_hint_counts',
        'research_matrix_has_new_source_approaches',
        'ja0272_open_sources_have_final_decisions',
        'rejected_sources_fail_closed',
        'discovery_refill_imports_changed_allowed_snapshot',
        'discovery_refill_rebuilds_candidate_queue',
        'discovery_refill_skips_blocked_and_unchanged_sources'
    )
    evidence = @($output.inventory_path, $output.research_path, $output.reconciliation_path)
} | ConvertTo-Json -Depth 5
