#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$SnapshotManifestPath = 'data/jobagent/company-discovery.snapshot.json',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$CandidateQueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$StorePath = 'data/jobagent/store.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRootPath = [IO.Path]::GetFullPath($ProjectRoot)

function Resolve-InventoryPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-InventoryProperty {
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

function ConvertTo-InventorySha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Read-InventoryJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$Depth
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Pflichtdatei fehlt: $Path"
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth $Depth
}

function Write-InventoryJsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value,
        [Parameter()][ValidateRange(2, 100)][int]$Depth = 30
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}

function ConvertTo-InventoryRelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][AllowEmptyString()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    $fullPath = Resolve-InventoryPath -Root $Root -Path $Path
    return [IO.Path]::GetRelativePath($Root, $fullPath).Replace('\', '/')
}

function Get-InventoryInputHash {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][AllowEmptyString()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }
    $fullPath = Resolve-InventoryPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return $null
    }
    return (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-InventoryInputRecordCount {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][AllowEmptyString()][string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return 0
    }
    $fullPath = Resolve-InventoryPath -Root $Root -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return 0
    }

    $extension = [IO.Path]::GetExtension($fullPath).ToLowerInvariant()
    if ($extension -eq '.jsonl') {
        return @((Get-Content -LiteralPath $fullPath) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
    }

    $raw = Get-Content -Raw -LiteralPath $fullPath
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return 0
    }
    $json = $raw | ConvertFrom-Json -Depth 100
    foreach ($property in @('items', 'companies', 'employers', 'organizations', 'records', 'hints')) {
        if ($json.PSObject.Properties.Name -contains $property) {
            return @($json.$property).Count
        }
    }
    if ($json -is [System.Collections.IEnumerable] -and $json -isnot [string]) {
        return @($json).Count
    }
    return 1
}

function New-InventoryCountMap {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Items,
        [Parameter(Mandatory)][string]$PropertyName
    )

    $counts = [ordered]@{}
    foreach ($item in @($Items)) {
        $value = [string](Get-InventoryProperty -Object $item -Name $PropertyName -Default 'UNKNOWN')
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = 'UNKNOWN'
        }
        if (-not $counts.Contains($value)) {
            $counts[$value] = 0
        }
        $counts[$value]++
    }
    return [pscustomobject]$counts
}

function Get-InventoryHintSourceCounts {
    param([Parameter()][AllowNull()][object]$HintStore)

    $counts = [ordered]@{}
    if ($null -eq $HintStore) {
        return [pscustomobject]$counts
    }
    foreach ($hint in @($HintStore.hints)) {
        $sourceId = [string](Get-InventoryProperty -Object $hint -Name 'source_id' -Default 'UNKNOWN')
        if (-not $counts.Contains($sourceId)) {
            $counts[$sourceId] = 0
        }
        $counts[$sourceId]++
    }
    return [pscustomobject]$counts
}

function Get-InventoryQueueSourceCounts {
    param([Parameter()][AllowNull()][object]$Queue)

    $counts = [ordered]@{}
    if ($null -eq $Queue) {
        return [pscustomobject]$counts
    }
    foreach ($entry in @($Queue.queue)) {
        $evidence = Get-InventoryProperty -Object $entry -Name 'source_evidence'
        $sourceId = [string](Get-InventoryProperty -Object $evidence -Name 'source_id' -Default 'UNKNOWN')
        if ([string]::IsNullOrWhiteSpace($sourceId)) {
            $sourceId = 'UNKNOWN'
        }
        if (-not $counts.Contains($sourceId)) {
            $counts[$sourceId] = 0
        }
        $counts[$sourceId]++
    }
    return [pscustomobject]$counts
}

function New-InventorySample {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Hints,
        [Parameter(Mandatory)][string]$SourceId
    )

    $sample = @($Hints |
        Where-Object { [string](Get-InventoryProperty -Object $_ -Name 'source_id' -Default '') -eq $SourceId } |
        Sort-Object { [string](Get-InventoryProperty -Object $_ -Name 'hint_id' -Default '') } |
        Select-Object -First 3)
    return @($sample | ForEach-Object {
            [pscustomobject]@{
                hint_id = [string](Get-InventoryProperty -Object $_ -Name 'hint_id' -Default '')
                employer_name = [string](Get-InventoryProperty -Object $_ -Name 'employer_name' -Default (Get-InventoryProperty -Object $_ -Name 'company_name' -Default 'UNKNOWN'))
                observed_url = [string](Get-InventoryProperty -Object $_ -Name 'observed_url' -Default '')
                candidate_status = [string](Get-InventoryProperty -Object $_ -Name 'candidate_status' -Default 'UNKNOWN')
            }
        })
}

function New-InventorySourceRows {
    param(
        [Parameter(Mandatory)][object]$Registry,
        [Parameter(Mandatory)][object]$SnapshotManifest,
        [Parameter(Mandatory)][object]$HintStore,
        [Parameter(Mandatory)][object]$Queue,
        [Parameter(Mandatory)][object]$Store,
        [Parameter(Mandatory)][string]$Root
    )

    $hints = @($HintStore.hints)
    $queueEntries = @($Queue.queue)
    $hintSourceCounts = Get-InventoryHintSourceCounts -HintStore $HintStore
    $queueSourceCounts = Get-InventoryQueueSourceCounts -Queue $Queue
    $inventoryItems = @($Store.discovery_inventory)
    $urlItems = @($Store.discovered_urls)

    return @($Registry.items | Sort-Object source_id | ForEach-Object {
            $source = $_
            $sourceId = [string]$source.source_id
            $manifestItems = @($SnapshotManifest.items | Where-Object { [string](Get-InventoryProperty -Object $_ -Name 'source_id' -Default '') -eq $sourceId })
            $inputRows = @($manifestItems | ForEach-Object {
                    $inputPath = [string](Get-InventoryProperty -Object $_ -Name 'input_path' -Default '')
                    [pscustomobject]@{
                        kind = [string](Get-InventoryProperty -Object $_ -Name 'kind' -Default 'UNKNOWN')
                        input_path = ConvertTo-InventoryRelativePath -Root $Root -Path $inputPath
                        input_hash = Get-InventoryInputHash -Root $Root -Path $inputPath
                        record_count = Get-InventoryInputRecordCount -Root $Root -Path $inputPath
                        snapshot_id = Get-InventoryProperty -Object $_ -Name 'snapshot_id' -Default $null
                        snapshot_date = Get-InventoryProperty -Object $_ -Name 'snapshot_date' -Default $null
                    }
                })
            $inputRecordMeasure = @($inputRows | Measure-Object -Property record_count -Sum)
            $inputRecordsTotal = if ($inputRecordMeasure.Count -eq 0 -or $null -eq $inputRecordMeasure[0].Sum) { 0 } else { [int]$inputRecordMeasure[0].Sum }
            $hintCount = if ($hintSourceCounts.PSObject.Properties.Name -contains $sourceId) { [int]$hintSourceCounts.$sourceId } else { 0 }
            $queueCount = if ($queueSourceCounts.PSObject.Properties.Name -contains $sourceId) { [int]$queueSourceCounts.$sourceId } else { 0 }
            $retainedInventoryCount = @($inventoryItems | Where-Object { [string](Get-InventoryProperty -Object $_ -Name 'source_id' -Default '') -eq $sourceId }).Count
            $retainedUrlCount = @($urlItems | Where-Object { [string](Get-InventoryProperty -Object $_ -Name 'source_id' -Default '') -eq $sourceId }).Count
            $nextAction = if ([string]$source.import_mode -eq 'REJECT') {
                'blocked'
            }
            elseif ($hintCount -eq 0 -and $manifestItems.Count -eq 0 -and [string]$source.import_mode -in @('BULK_SNAPSHOT', 'FIXTURE_OR_SNAPSHOT_ONLY')) {
                'add_snapshot_or_explain_no_input'
            }
            elseif ($hintCount -gt 0 -and $queueCount -eq 0) {
                'rebuild_candidate_queue'
            }
            elseif ($hintCount -gt 0) {
                'verify_or_research_official_websites'
            }
            elseif ([string]$source.source_class -in @('OFFICIAL_REGISTER', 'OFFICIAL_COMPANY', 'OFFICIAL_ATS')) {
                'targeted_lookup_only'
            }
            else {
                'review_source_contract'
            }

            [pscustomobject]@{
                source_id = $sourceId
                operator = [string]$source.operator
                source_url = [string]$source.source_url
                source_class = [string]$source.source_class
                import_mode = [string]$source.import_mode
                evidence_level = [string]$source.evidence_level
                legal_risk = [string]$source.legal_risk
                review_required = [bool]$source.review_required
                manifest_inputs_total = $manifestItems.Count
                input_records_total = $inputRecordsTotal
                hint_count = $hintCount
                queue_count = $queueCount
                retained_inventory_count = $retainedInventoryCount
                retained_url_count = $retainedUrlCount
                sample_hints = New-InventorySample -Hints $hints -SourceId $sourceId
                inputs = $inputRows
                next_action = $nextAction
            }
        })
}

function New-InventoryResearchMatrix {
    param([Parameter(Mandatory)][datetime]$GeneratedAt)

    $sourceCandidates = @(
        [pscustomobject]@{
            source_id = 'research-candidate:hwk_muenchen_oberbayern_handwerkersuche'
            family = 'Kammer-/Branchenverzeichnis'
            operator = 'Handwerkskammer fuer Muenchen und Oberbayern'
            url = 'https://www.hwk-muenchen.de/74,0,bdbsearch.html'
            observed_fact = 'Oeffentliche Handwerkersuche mit Ort/Umkreis- und Gewerke-Suche; fuer IT-nahe Handwerke nur als Kandidatenhinweis verwendbar.'
            allowed_use_decision = 'manual_or_fixture_snapshot_only'
            next_action = 'Terms/Robots pruefen, Suchmatrix fuer Informationstechniker/Elektrotechniker in Muenchen/Freising definieren, keine personenbezogenen Rollen speichern.'
            risk = 'MEDIUM'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:munich_startup_directory'
            family = 'Startup-/Technologieverzeichnis'
            operator = 'Munich Startup'
            url = 'https://www.munich-startup.de/startups/'
            observed_fact = 'Offizielles Startup-Portal fuer Muenchen und Region mit Startup-Liste/Map und Kategorien.'
            allowed_use_decision = 'fixture_snapshot_candidate_hints'
            next_action = 'Snapshot-Pagination und Kategorien IT/Technologie/SaaS/AI dokumentieren, Firmenwebsites separat offiziell verifizieren.'
            risk = 'LOW'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:izb_startups'
            family = 'Forschungs-/Hochschul-Ausgruendungen'
            operator = 'Innovations- und Gruenderzentrum Biotechnologie IZB'
            url = 'https://www.izb-online.de/hotspot-for-life-sciences/start-ups-im-izb/'
            observed_fact = 'IZB listet aktuell ansaessige Start-ups an den Standorten Martinsried und Weihenstephan.'
            allowed_use_decision = 'fixture_snapshot_candidate_hints'
            next_action = 'Regionale Standorte Planegg/Martinsried/Freising-Weihenstephan trennen, Firmenwebsites/Karrierequellen danach offiziell pruefen.'
            risk = 'LOW'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:biom_company_database'
            family = 'Cluster-/Branchenverzeichnis'
            operator = 'BioM Biotech Cluster Development GmbH'
            url = 'https://www.bio-m.org/en/'
            observed_fact = 'BioM verweist auf eine Company Database fuer Akteure im bayerischen Biotechnologiesektor.'
            allowed_use_decision = 'fixture_snapshot_candidate_hints'
            next_action = 'Firmendatenbank-Seiten und regionale Filter pruefen; Kontakte/E-Mails nicht persistieren, nur Organisations-/Websitehinweise.'
            risk = 'MEDIUM'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:landkreis_muenchen_gruenderzentren'
            family = 'Technologiepark-/Gruenderzentrum-Mitglieder'
            operator = 'Landkreis Muenchen'
            url = 'https://www.landkreis-muenchen.de/themen/wirtschaft-wissenschaft/gruenderzentren/'
            observed_fact = 'Landkreis Muenchen nennt Gruenderzentren wie gate Garching, IZB und WERK1 als wirtschaftliche Infrastruktur.'
            allowed_use_decision = 'source_seed_for_followup_directories'
            next_action = 'Nur als Metaverzeichnis nutzen; pro Gruenderzentrum eigene Mitglieder-/Mieterquelle suchen und separat registrieren.'
            risk = 'LOW'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:stadt_freising_wirtschaft'
            family = 'Kommunale Wirtschaftsinformation'
            operator = 'Stadt Freising'
            url = 'https://www.freising.de/wirtschaft'
            observed_fact = 'Stadt Freising beschreibt Wirtschaftsstandort, Gewerbegebiete und lokale Unternehmernetzwerke.'
            allowed_use_decision = 'manual_research_seed_only'
            next_action = 'Pruefen, ob Seiten/Downloads konkrete Unternehmenslisten enthalten; sonst nur als Quellenansatz dokumentieren.'
            risk = 'LOW'
        }
        [pscustomobject]@{
            source_id = 'research-candidate:ihk_standortportal_bayern'
            family = 'Lizenzierte Organisations-/Standortdaten'
            operator = 'Bayerische IHKs / Bayerisches Wirtschaftsministerium / Invest in Bavaria'
            url = 'https://www.ihk-muenchen.de/politik/standortmanagement/standortportal-bayern/'
            observed_fact = 'Standortportal Bayern ist eine kostenlose Informationsplattform fuer Gewerbestandorte und Gewerbeimmobilien.'
            allowed_use_decision = 'not_company_directory_until_verified'
            next_action = 'Nicht als Firmenliste zaehlen; nur pruefen, ob Gewerbeimmobilien-/Standortdaten einen zulaessigen regionalen Recherchepfad ergeben.'
            risk = 'LOW'
        }
    )

    [pscustomobject]@{
        schema_version = 'jobagent/source-research/v1'
        generated_at = $GeneratedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Diese Matrix dokumentiert recherchierte Quellenansaetze. Sie erzeugt keine offiziellen Karrierequellen und keine produktiven Firmen ohne spaetere Verifikation.'
        source_candidates_total = $sourceCandidates.Count
        source_candidates = $sourceCandidates
    }
}

$generatedAt = [datetime]::UtcNow
$registryPath = Resolve-InventoryPath -Root $projectRootPath -Path $SourceRegistryPath
$snapshotPath = Resolve-InventoryPath -Root $projectRootPath -Path $SnapshotManifestPath
$hintPath = Resolve-InventoryPath -Root $projectRootPath -Path $HintStorePath
$queuePath = Resolve-InventoryPath -Root $projectRootPath -Path $CandidateQueuePath
$storePathResolved = Resolve-InventoryPath -Root $projectRootPath -Path $StorePath
$logRootPath = Resolve-InventoryPath -Root $projectRootPath -Path $LogRoot

$registry = Read-InventoryJsonFile -Path $registryPath -Depth 100
$snapshotManifest = Read-InventoryJsonFile -Path $snapshotPath -Depth 100
$hintStore = Read-InventoryJsonFile -Path $hintPath -Depth 100
$queue = Read-InventoryJsonFile -Path $queuePath -Depth 100
$store = Read-InventoryJsonFile -Path $storePathResolved -Depth 100

$sourceRows = New-InventorySourceRows -Registry $registry -SnapshotManifest $snapshotManifest -HintStore $hintStore -Queue $queue -Store $store -Root $projectRootPath
$hintIds = [Collections.Generic.HashSet[string]]::new([string[]]@($hintStore.hints | ForEach-Object { [string](Get-InventoryProperty -Object $_ -Name 'hint_id' -Default '') }), [StringComparer]::Ordinal)
$queueCandidateIds = [Collections.Generic.HashSet[string]]::new([string[]]@($queue.queue | ForEach-Object { [string](Get-InventoryProperty -Object $_ -Name 'candidate_id' -Default '') }), [StringComparer]::Ordinal)
$hintsWithoutQueue = @($hintStore.hints | Where-Object { -not $queueCandidateIds.Contains([string](Get-InventoryProperty -Object $_ -Name 'hint_id' -Default '')) } | Sort-Object hint_id)
$queueWithoutHint = @($queue.queue | Where-Object { -not $hintIds.Contains([string](Get-InventoryProperty -Object $_ -Name 'candidate_id' -Default '')) } | Sort-Object candidate_id)
$smallHintSources = @($sourceRows | Where-Object { [int]$_.hint_count -gt 0 -and [int]$_.hint_count -le 5 } | Sort-Object hint_count, source_id)

$inventory = [pscustomobject]@{
    schema_version = 'jobagent/source-inventory-ja0272/v1'
    generated_at = $generatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    contract = 'JA-027.2 Read-only-Inventur: Registry, Snapshot-Inputs, Hint-Store, Queue und Retention-Store werden abgeglichen; Zahlen sind Hinweise, keine offiziellen Karrierequellen.'
    source_registry_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $registryPath
    snapshot_manifest_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $snapshotPath
    hint_store_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $hintPath
    queue_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $queuePath
    store_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $storePathResolved
    input_hashes = [pscustomobject]@{
        source_registry = (Get-FileHash -LiteralPath $registryPath -Algorithm SHA256).Hash.ToLowerInvariant()
        snapshot_manifest = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant()
        hint_store = (Get-FileHash -LiteralPath $hintPath -Algorithm SHA256).Hash.ToLowerInvariant()
        queue = (Get-FileHash -LiteralPath $queuePath -Algorithm SHA256).Hash.ToLowerInvariant()
        store = (Get-FileHash -LiteralPath $storePathResolved -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    totals = [pscustomobject]@{
        registry_sources = @($registry.items).Count
        snapshot_manifest_items = @($snapshotManifest.items).Count
        hint_store_hints = @($hintStore.hints).Count
        queue_entries = @($queue.queue).Count
        retained_discovery_inventory = @($store.discovery_inventory).Count
        retained_discovered_urls = @($store.discovered_urls).Count
        hints_without_queue = $hintsWithoutQueue.Count
        queue_without_hint = $queueWithoutHint.Count
    }
    by_source_class = New-InventoryCountMap -Items @($registry.items) -PropertyName 'source_class'
    by_import_mode = New-InventoryCountMap -Items @($registry.items) -PropertyName 'import_mode'
    by_legal_risk = New-InventoryCountMap -Items @($registry.items) -PropertyName 'legal_risk'
    sources = $sourceRows
}

$reconciliation = [pscustomobject]@{
    schema_version = 'jobagent/candidate-reconciliation-ja0272/v1'
    generated_at = $inventory.generated_at
    contract = 'Queue-Reconciliation erklaert Hint-/Queue-Abweichungen. Ein fehlender Queueeintrag loescht keinen Hint und gilt nicht als Quellenerschoepfung.'
    totals = $inventory.totals
    hints_without_queue = @($hintsWithoutQueue | ForEach-Object {
            [pscustomobject]@{
                hint_id = [string](Get-InventoryProperty -Object $_ -Name 'hint_id' -Default '')
                employer_name = [string](Get-InventoryProperty -Object $_ -Name 'employer_name' -Default (Get-InventoryProperty -Object $_ -Name 'company_name' -Default 'UNKNOWN'))
                source_id = [string](Get-InventoryProperty -Object $_ -Name 'source_id' -Default 'UNKNOWN')
                candidate_status = [string](Get-InventoryProperty -Object $_ -Name 'candidate_status' -Default 'UNKNOWN')
                observed_url = [string](Get-InventoryProperty -Object $_ -Name 'observed_url' -Default '')
                explanation = 'Hint ist dauerhaft gespeichert, aber in der aktuellen Verifikationsqueue nicht als candidate_id enthalten; Queue-Neuaufbau oder Filterentscheidung pruefen.'
            }
        })
    queue_without_hint = @($queueWithoutHint | Select-Object -First 50 | ForEach-Object {
            [pscustomobject]@{
                candidate_id = [string](Get-InventoryProperty -Object $_ -Name 'candidate_id' -Default '')
                canonical_name = [string](Get-InventoryProperty -Object $_ -Name 'canonical_name' -Default 'UNKNOWN')
                source_id = [string](Get-InventoryProperty -Object (Get-InventoryProperty -Object $_ -Name 'source_evidence') -Name 'source_id' -Default 'UNKNOWN')
                status = [string](Get-InventoryProperty -Object $_ -Name 'status' -Default 'UNKNOWN')
            }
        })
    small_hint_sources = @($smallHintSources | ForEach-Object {
            [pscustomobject]@{
                source_id = $_.source_id
                source_class = $_.source_class
                hint_count = $_.hint_count
                input_records_total = $_.input_records_total
                next_action = $_.next_action
                explanation = 'Kleiner Bestand ist nur eine lokale Snapshot-/Fixture-Beobachtung und kein Quellenerschoepfungsnachweis.'
            }
        })
}

$research = New-InventoryResearchMatrix -GeneratedAt $generatedAt

$inventoryPath = Join-Path $logRootPath 'JA-027-source-inventory.json'
$researchPath = Join-Path $logRootPath 'JA-027-source-research.json'
$reconciliationPath = Join-Path $logRootPath 'JA-027-candidate-reconciliation.json'
Write-InventoryJsonFile -Path $inventoryPath -Value $inventory -Depth 100
Write-InventoryJsonFile -Path $researchPath -Value $research -Depth 20
Write-InventoryJsonFile -Path $reconciliationPath -Value $reconciliation -Depth 30

$summaryHashInput = ($inventory.input_hashes | ConvertTo-Json -Depth 8) + ($inventory.totals | ConvertTo-Json -Depth 8) + ($research.source_candidates_total)
[pscustomobject]@{
    status = 'ok'
    schema_version = 'jobagent/source-inventory-ja0272-result/v1'
    generated_at = $inventory.generated_at
    inventory_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $inventoryPath
    research_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $researchPath
    reconciliation_path = ConvertTo-InventoryRelativePath -Root $projectRootPath -Path $reconciliationPath
    sources_total = $inventory.totals.registry_sources
    hints_total = $inventory.totals.hint_store_hints
    queue_total = $inventory.totals.queue_entries
    hints_without_queue = $inventory.totals.hints_without_queue
    queue_without_hint = $inventory.totals.queue_without_hint
    research_candidates_total = $research.source_candidates_total
    evidence_hash = ConvertTo-InventorySha256 -Value $summaryHashInput
} | ConvertTo-Json -Depth 8
