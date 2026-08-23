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

$fixture = Join-Path $root 'tests\fixtures\jobagent\regional-discovery\regional-directories-snapshot.json'
$result = Import-JobAgentRegionalDirectories -SnapshotPath $fixture -SourceRegistry $registry
Assert-True -Condition ($result.schema_version -eq 'jobagent/regional-discovery/v1') -Message 'Regionalimport hat falsche Schema-Version.'
Assert-True -Condition ($result.sources_read -eq 3) -Message 'Regionalimport liest falsche Quellenanzahl.'
Assert-True -Condition ($result.hints_total -eq 5) -Message 'Regionalimport erzeugt falsche Hint-Anzahl nach Reject/Dedupe.'
Assert-True -Condition ($result.reject_counts.out_of_scope -eq 1) -Message 'Out-of-scope-Reject fehlt.'
Assert-True -Condition ($result.reject_counts.missing_name -eq 1) -Message 'Missing-name-Reject fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.company_name -eq 'Alpha Regional AG' }).Count -eq 1) -Message 'Dubletten werden nicht dedupliziert.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area -eq 'MUNICH' }).Count -ge 1) -Message 'Muenchen-Hints fehlen.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area -eq 'FREISING' }).Count -ge 3) -Message 'Freising-Hints fehlen.'
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
    Assert-True -Condition ($written.hints_total -eq 5) -Message 'Geschriebene Regional-Hints haben falsche Anzahl.'
    Assert-True -Condition ($merged.hints_total -eq 5) -Message 'Gemergter Hint-Store uebernimmt Regional-Hints nicht.'
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
        'target_area_filter',
        'dedupe_by_hint_id',
        'minimal_hash_evidence',
        'no_contact_collection',
        'script_writes_regional_and_merged_hints'
    )
    hints = $result.hints_total
} | ConvertTo-Json -Depth 4
