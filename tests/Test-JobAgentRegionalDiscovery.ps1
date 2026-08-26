#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.RegionalDiscovery.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

$registryPath = Join-Path $root 'data\jobagent\company-discovery.sources.json'
$registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -Depth 100

$munichSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:stadt_muenchen_boersennotierte_unternehmen'
Assert-True -Condition ([string]$munichSource.source_class -eq 'REGIONAL_DIRECTORY') -Message 'Muenchner Regionalquelle wurde nicht geladen.'
$freisingSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:landkreis_freising_wirtschaft'
Assert-True -Condition ([string]$freisingSource.source_class -eq 'PUBLIC_INSTITUTION_DIRECTORY') -Message 'Freisinger Institutionsquelle wurde nicht geladen.'
$techGithubSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:tech_companies_munich_github'
Assert-True -Condition ([string]$techGithubSource.evidence_level -eq 'DISCOVERY_HINT') -Message 'Tech-Companies-Munich-Quelle darf keine offizielle Evidenz erhalten.'
$awesomeMlSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:awesome_ml_startups_munich_github'
Assert-True -Condition ([string]$awesomeMlSource.evidence_level -eq 'DISCOVERY_HINT' -and [string]$awesomeMlSource.source_class -eq 'REGIONAL_DIRECTORY') -Message 'Awesome-ML-Startups-Munich-Quelle wurde nicht als unverifizierte regionale Discovery-Quelle geladen.'
$klimapaktSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:munich_business_klimapakt3_companies'
Assert-True -Condition ([string]$klimapaktSource.source_class -eq 'PUBLIC_INSTITUTION_DIRECTORY' -and [string]$klimapaktSource.evidence_level -eq 'SECONDARY_OFFICIAL_DIRECTORY') -Message 'Klimapakt-3-Quelle wurde nicht als oeffentliche Institutionsquelle geladen.'
$startupSource = Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:munich_startup_platform_ecosystem'
Assert-True -Condition ([string]$startupSource.source_class -eq 'REGIONAL_DIRECTORY' -and [string]$startupSource.evidence_level -eq 'DISCOVERY_HINT') -Message 'Munich-Startup-Quelle wurde nicht als regionale Discovery-Quelle geladen.'

try {
    Get-JobAgentRegionalSource -SourceRegistry $registry -SourceId 'source-registry:manual_review_list' | Out-Null
    throw 'Manual-Review-Quelle wurde als Regionalimport akzeptiert.'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'regionale Discovery|Snapshot-Import|Regionale Quelle') -Message 'Nicht-regionale Quelle muss fail-closed melden.'
}

Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Muenchen') -eq 'MUNICH') -Message 'Muenchen-Zielgebiet fehlt.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Flughafen Muenchen / Freising') -eq 'FREISING') -Message 'Freising/Flughafen-Zielgebiet fehlt.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Garching') -eq 'MUNICH_20KM') -Message '20-km-Zielgebiet fehlt.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location '') -eq 'TARGET_AREA_UNCERTAIN') -Message 'Leerer Ort muss unsicher bleiben.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Hamburg') -eq 'OUT_OF_SCOPE') -Message 'Fremder Ort wird nicht ausgeschlossen.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Gewerbegebiet' -Latitude 48.134 -Longitude 11.363) -eq 'MUNICH_20KM') -Message 'Koordinatenbasierter Muenchen-20-km-Bezug fehlt.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Campus' -Latitude '48,401' -Longitude '11,742') -eq 'FREISING') -Message 'Koordinaten mit Dezimalkomma werden nicht fuer Freising erkannt.'
Assert-True -Condition ((Get-JobAgentRegionalTargetArea -Location 'Gewerbegebiet' -Latitude 48.3705 -Longitude 10.8978) -eq 'OUT_OF_SCOPE') -Message 'Koordinatenbasierter Fremdort wird nicht ausgeschlossen.'

$fixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\regional-directories-snapshot.json'
$result = Import-JobAgentRegionalDirectories -SnapshotPath $fixture -SourceRegistry $registry
Assert-True -Condition ($result.schema_version -eq 'jobagent/regional-discovery/v1') -Message 'Regionalimport hat falsche Schema-Version.'
Assert-True -Condition ($result.sources_read -eq 3) -Message 'Regionalimport liest falsche Quellenanzahl.'
Assert-True -Condition ($result.hints_total -eq 6) -Message 'Regionalimport erzeugt falsche Hint-Anzahl nach Reject/Dedupe.'
Assert-True -Condition ($result.reject_counts.out_of_scope -eq 1) -Message 'Out-of-scope-Reject fehlt.'
Assert-True -Condition ($result.reject_counts.missing_name -eq 1) -Message 'Missing-name-Reject fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.company_name -eq 'Alpha Regional AG' }).Count -eq 1) -Message 'Dubletten werden nicht dedupliziert.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area -eq 'MUNICH' }).Count -ge 1) -Message 'Muenchen-Hints fehlen.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area -eq 'FREISING' }).Count -ge 3) -Message 'Freising-Hints fehlen.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.company_name -eq 'Coordinate Park GmbH' -and [string]$_.target_area -eq 'MUNICH_20KM' }).Count -eq 1) -Message 'Koordinatenbasierter Regional-Hint fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area -eq 'TARGET_AREA_UNCERTAIN' }).Count -eq 1) -Message 'Unsicherer Standort muss Review-Hint bleiben.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.candidate_status -ne 'REGIONAL_DISCOVERY_HINT' -or [string]$_.verification_status -ne 'UNVERIFIED' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Regional-Hints muessen unverifiziert bleiben.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.source_record_hash -notmatch '^[a-f0-9]{64}$' }).Count -eq 0) -Message 'Hash-Evidenz fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { $_.PSObject.Properties.Name -contains 'email' -or $_.PSObject.Properties.Name -contains 'phone' -or $_.PSObject.Properties.Name -contains 'contact' }).Count -eq 0) -Message 'Kontaktfelder duerfen nicht persistiert werden.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.raw_retention_policy -ne 'minimal_regional_metadata_only_no_contact_collection' }).Count -eq 0) -Message 'Retention-Policy fehlt.'

$blockedFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\regional-blocked-snapshot.json'
try {
    Import-JobAgentRegionalDirectories -SnapshotPath $blockedFixture -SourceRegistry $registry | Out-Null
    throw 'Blockierte Regionalquelle wurde importiert.'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'regionale Discovery|Snapshot-Import|Regionale Quelle') -Message 'Blockierte Quelle muss fail-closed melden.'
}

$techFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\tech-companies-munich-github-snapshot.json'
$techResult = Import-JobAgentRegionalDirectories -SnapshotPath $techFixture -SourceRegistry $registry
Assert-True -Condition ($techResult.hints_total -ge 80) -Message 'Tech-Companies-Munich-Snapshot erzeugt zu wenige Arbeitgeberhints.'
Assert-True -Condition ($techResult.source_counts.'source-registry:tech_companies_munich_github' -eq $techResult.hints_total) -Message 'Tech-Companies-Munich-Hints werden nicht der neuen Quelle zugeordnet.'
Assert-True -Condition (@($techResult.hints | Where-Object { [string]$_.officialness_level -ne 'CURATED_DISCOVERY_HINT' -or [string]$_.target_area -ne 'MUNICH' }).Count -eq 0) -Message 'Community-Tech-Hints muessen unverifizierte Muenchen-Hints bleiben.'
Assert-True -Condition (@($techResult.hints | Where-Object { $_.PSObject.Properties.Name -contains 'career_hint' -or $_.PSObject.Properties.Name -contains 'website_hint' }).Count -eq 0) -Message 'Tech-Companies-Munich-Links duerfen nicht als offizielle Felder persistiert werden.'

$listedFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\stadt-muenchen-boersennotierte-unternehmen-snapshot.json'
$listedResult = Import-JobAgentRegionalDirectories -SnapshotPath $listedFixture -SourceRegistry $registry
Assert-True -Condition ($listedResult.hints_total -eq 26) -Message 'Boersennotierte-Muenchen-Snapshot erzeugt falsche Arbeitgeberanzahl.'
Assert-True -Condition (@($listedResult.hints | Where-Object { [string]$_.company_name -eq 'Alpha Regional AG' }).Count -eq 0) -Message 'Produktiver Boersennotierte-Snapshot darf keine Testfirma enthalten.'
Assert-True -Condition (@($listedResult.hints | Where-Object { [string]$_.target_area -notin @('MUNICH', 'MUNICH_20KM') }).Count -eq 0) -Message 'Boersennotierte-Muenchen-Hints muessen Muenchen- oder 20-km-Bezug behalten.'

$freisingEconomyFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\landkreis-freising-wirtschaft-snapshot.json'
$freisingEconomyResult = Import-JobAgentRegionalDirectories -SnapshotPath $freisingEconomyFixture -SourceRegistry $registry
Assert-True -Condition ($freisingEconomyResult.hints_total -eq 5) -Message 'Landkreis-Freising-Wirtschaft-Snapshot erzeugt falsche Arbeitgeberanzahl.'
Assert-True -Condition (@($freisingEconomyResult.hints | Where-Object { [string]$_.company_name -in @('Airport Logistics GmbH', 'Weihenstephan Research GmbH') }).Count -eq 0) -Message 'Produktiver Landkreis-Freising-Snapshot darf keine Testfirmen enthalten.'
Assert-True -Condition (@($freisingEconomyResult.hints | Where-Object { [string]$_.target_area -ne 'FREISING' }).Count -eq 0) -Message 'Landkreis-Freising-Hints muessen Freising-Bezug behalten.'

$klimapaktFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\munich-business-klimapakt3-snapshot.json'
$klimapaktResult = Import-JobAgentRegionalDirectories -SnapshotPath $klimapaktFixture -SourceRegistry $registry
Assert-True -Condition ($klimapaktResult.hints_total -eq 20) -Message 'Klimapakt-3-Snapshot erzeugt falsche Arbeitgeberanzahl.'
Assert-True -Condition ($klimapaktResult.source_counts.'source-registry:munich_business_klimapakt3_companies' -eq 20) -Message 'Klimapakt-3-Hints werden nicht der neuen Quelle zugeordnet.'
Assert-True -Condition (@($klimapaktResult.hints | Where-Object { [string]$_.officialness_level -ne 'SECONDARY_OFFICIAL_DIRECTORY' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Klimapakt-3-Hints muessen unverifizierte Sekundaerhinweise bleiben.'
Assert-True -Condition (@($klimapaktResult.hints | Where-Object { [string]$_.target_area -notin @('MUNICH', 'FREISING') }).Count -eq 0) -Message 'Klimapakt-3-Hints muessen Muenchen- oder Freising-Bezug behalten.'

$startupFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\munich-startup-platform-ecosystem-snapshot.json'
$startupResult = Import-JobAgentRegionalDirectories -SnapshotPath $startupFixture -SourceRegistry $registry
Assert-True -Condition ($startupResult.hints_total -eq 30) -Message 'Munich-Startup-Snapshot erzeugt falsche Arbeitgeberanzahl.'
Assert-True -Condition ($startupResult.source_counts.'source-registry:munich_startup_platform_ecosystem' -eq 30) -Message 'Munich-Startup-Hints werden nicht der neuen Quelle zugeordnet.'
Assert-True -Condition (@($startupResult.hints | Where-Object { [string]$_.officialness_level -ne 'CURATED_DISCOVERY_HINT' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Munich-Startup-Hints muessen unverifizierte Discovery-Hints bleiben.'
Assert-True -Condition (@($startupResult.hints | Where-Object { [string]$_.target_area -ne 'MUNICH' }).Count -eq 0) -Message 'Munich-Startup-Hints muessen Muenchen-Bezug behalten.'

$awesomeMlFixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\awesome-ml-startups-munich-github-snapshot.json'
$awesomeMlResult = Import-JobAgentRegionalDirectories -SnapshotPath $awesomeMlFixture -SourceRegistry $registry
Assert-True -Condition ($awesomeMlResult.hints_total -eq 89) -Message 'Awesome-ML-Startups-Munich-Snapshot erzeugt falsche Arbeitgeberanzahl.'
Assert-True -Condition ($awesomeMlResult.source_counts.'source-registry:awesome_ml_startups_munich_github' -eq 89) -Message 'Awesome-ML-Startups-Munich-Hints werden nicht der neuen Quelle zugeordnet.'
Assert-True -Condition (@($awesomeMlResult.hints | Where-Object { [string]$_.officialness_level -ne 'CURATED_DISCOVERY_HINT' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Awesome-ML-Startups-Munich-Hints muessen unverifizierte Discovery-Hints bleiben.'
Assert-True -Condition (@($awesomeMlResult.hints | Where-Object { [string]$_.target_area -ne 'MUNICH' }).Count -eq 0) -Message 'Awesome-ML-Startups-Munich-Hints muessen Muenchen-Bezug behalten.'
Assert-True -Condition (@($awesomeMlResult.hints | Where-Object { $_.PSObject.Properties.Name -contains 'career_hint' -or $_.PSObject.Properties.Name -contains 'website_hint' }).Count -eq 0) -Message 'Awesome-ML-Startups-Munich-Links duerfen nicht als offizielle Felder persistiert werden.'

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-regional-import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
try {
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'data\jobagent') -Force | Out-Null
    Copy-Item -LiteralPath $registryPath -Destination (Join-Path $projectRoot 'data\jobagent\company-discovery.sources.json') -Force
    [pscustomobject]@{
        schema_version = 'jobagent/company-discovery-hints/v1'
        generated_at = '2026-08-23T08:00:00.000Z'
        contract = 'Sekundaerquellen erzeugen ausschliesslich unverifizierte Discovery-Hints; sie duerfen keine JobSource und keine offizielle Karriere-URL erzeugen.'
        search_matrix_count = 0
        hints_total = 0
        known_company_hints = 0
        unverified_hints = 0
        source_counts = [pscustomobject]@{}
        hints = @()
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $projectRoot 'data\jobagent\company-discovery.hints.json') -Encoding UTF8

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentRegionalDirectories.ps1') -ProjectRoot $projectRoot -SnapshotPath $fixture 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Regional-Import-Script ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($scriptResult.status -eq 'ok') -Message 'Regional-Import-Script liefert keinen OK-Status.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.output_path) -PathType Leaf) -Message 'Regional-Import-Script schreibt keine Regional-Hint-Datei.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.merged_hints_path) -PathType Leaf) -Message 'Regional-Import-Script schreibt keinen gemergten Hint-Store.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.log_path) -PathType Leaf) -Message 'Regional-Import-Script schreibt kein Logartefakt.'
    $written = Get-Content -LiteralPath ([string]$scriptResult.output_path) -Raw | ConvertFrom-Json -Depth 100
    $merged = Get-Content -LiteralPath ([string]$scriptResult.merged_hints_path) -Raw | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($written.hints_total -eq 6) -Message 'Geschriebene Regional-Hints haben falsche Anzahl.'
    Assert-True -Condition ($merged.hints_total -eq 6) -Message 'Gemergter Hint-Store uebernimmt Regional-Hints nicht.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'regional_source_registry_contract',
        'non_regional_source_blocked',
        'table_html_parser',
        'card_html_parser',
        'json_snapshot_parser',
        'coordinate_target_area_filter',
        'community_tech_directory_snapshot',
        'target_area_filter',
        'dedupe_by_hint_id',
        'minimal_hash_evidence',
        'no_contact_collection',
        'production_stock_listed_snapshot',
        'production_freising_economy_snapshot',
        'production_klimapakt3_snapshot',
        'production_munich_startup_snapshot',
        'production_awesome_ml_startups_munich_snapshot',
        'script_writes_regional_and_merged_hints'
    )
    hints = $result.hints_total
} | ConvertTo-Json -Depth 4
