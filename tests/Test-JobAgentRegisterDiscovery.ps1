#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.RegisterDiscovery.psm1') -Force -DisableNameChecking

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
$source = Assert-JobAgentRegisterSourceRegistry -Registry $registry
Assert-True -Condition ([string]$source.source_id -eq 'source-registry:offeneregister_dump') -Message 'OffeneRegister-Quelle wurde nicht gefunden.'

Assert-True -Condition ((Normalize-JobAgentRegisterCity -City 'München') -eq 'Muenchen') -Message 'Umlaut-Ortsnormalisierung fehlt.'
Assert-True -Condition ((Get-JobAgentRegisterTargetAreaMatch -City 'Munich') -eq 'MUNICH') -Message 'Munich wird nicht als Muenchen erkannt.'
Assert-True -Condition ((Get-JobAgentRegisterTargetAreaMatch -City 'Garching b. München') -eq 'MUNICH_20KM') -Message 'Randgemeinde wird nicht als 20-km-Zielgebiet erkannt.'
Assert-True -Condition ((Get-JobAgentRegisterTargetAreaMatch -City '') -eq 'TARGET_AREA_UNCERTAIN') -Message 'Leerer Ort muss unsicher bleiben.'
Assert-True -Condition ((Get-JobAgentRegisterTargetAreaMatch -City 'Hamburg') -eq 'OUT_OF_SCOPE') -Message 'Fremder Ort wird nicht ausgeschlossen.'

$fixture = Join-Path $root 'tests\fixtures\jobagent\register-discovery\offeneregister-sample.jsonl'
$result = Import-JobAgentRegisterCandidates `
    -InputPath $fixture `
    -SourceRegistry $registry `
    -SnapshotId 'offeneregister-sample-2026-08' `
    -SnapshotDate ([datetime]'2026-08-01T00:00:00Z') `
    -ObservedAt ([datetime]'2026-08-23T08:00:00Z')

Assert-True -Condition ($result.schema_version -eq 'jobagent/register-discovery/v1') -Message 'Registerimport hat falsche Schema-Version.'
Assert-True -Condition ($result.records_read -eq 8) -Message 'Registerimport liest falsche Record-Anzahl.'
Assert-True -Condition ($result.hints_total -eq 5) -Message 'Registerimport erzeugt falsche Hint-Anzahl nach Reject/Dedupe.'
Assert-True -Condition ($result.reject_counts.out_of_scope -eq 1) -Message 'Out-of-scope-Reject fehlt.'
Assert-True -Condition ($result.reject_counts.missing_name -eq 1) -Message 'Missing-name-Reject fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.register_name -eq 'Alpha Technik GmbH' }).Count -eq 1) -Message 'Dubletten werden nicht dedupliziert.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area_match -eq 'MUNICH' }).Count -ge 2) -Message 'Muenchen-Hints fehlen.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area_match -eq 'FREISING' }).Count -eq 1) -Message 'Freising-Hint fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.target_area_match -eq 'MUNICH_20KM' }).Count -eq 1) -Message '20-km-Hint fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Register-Hints muessen offizielle Verifikation verlangen.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.candidate_status -ne 'REGISTER_DISCOVERY_HINT' }).Count -eq 0) -Message 'Register-Hints haben falschen Kandidatenstatus.'
Assert-True -Condition (@($result.hints | Where-Object { @($_.dedupe_keys).Count -lt 1 }).Count -eq 0) -Message 'Register-Hints brauchen Dedupe-Keys.'
Assert-True -Condition (@($result.hints | Where-Object { @($_.dedupe_keys | Where-Object { [string]$_ -match '^name:' }).Count -ne 1 -or @($_.dedupe_keys | Where-Object { [string]$_ -match '^register:' }).Count -ne 1 }).Count -eq 0) -Message 'Register-Hints brauchen getrennte Name- und Register-Dedupe-Keys.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.source_snapshot.record_hash -notmatch '^[a-f0-9]{64}$' }).Count -eq 0) -Message 'Record-Hashes fehlen oder sind ungueltig.'
Assert-True -Condition (@($result.hints | Where-Object { $_.PSObject.Properties.Name -match 'geschäft|geschaeft|director|shareholder|person' }).Count -eq 0) -Message 'Personenbezogene Registerrollen duerfen nicht persistiert werden.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.review_status -eq 'MANUAL_REVIEW_REQUIRED' }).Count -eq 1) -Message 'Geloeschte Registereintraege muessen Review-Faelle bleiben.'

$stale = Import-JobAgentRegisterCandidates `
    -InputPath $fixture `
    -SourceRegistry $registry `
    -SnapshotId 'offeneregister-stale' `
    -SnapshotDate ([datetime]'2020-01-01T00:00:00Z') `
    -ObservedAt ([datetime]'2026-08-23T08:00:00Z')
Assert-True -Condition (@($stale.hints | Where-Object { [string]$_.source_freshness -ne 'STALE' }).Count -eq 0) -Message 'Veralteter Snapshot wird nicht als stale markiert.'

$future = Import-JobAgentRegisterCandidates `
    -InputPath $fixture `
    -SourceRegistry $registry `
    -SnapshotId 'offeneregister-future' `
    -SnapshotDate ([datetime]'2030-01-01T00:00:00Z') `
    -ObservedAt ([datetime]'2026-08-23T08:00:00Z')
Assert-True -Condition ($future.hints_total -eq 0 -and $future.reject_counts.future_snapshot -eq 7) -Message 'Zukuenftiger Snapshot muss fail-closed abgelehnt werden.'

$csvFixture = Join-Path $root 'tests\fixtures\jobagent\register-discovery\offeneregister-sample.csv'
$csvResult = Import-JobAgentRegisterCandidates `
    -InputPath $csvFixture `
    -SourceRegistry $registry `
    -SnapshotId 'offeneregister-csv-2026-08' `
    -SnapshotDate ([datetime]'2026-08-01T00:00:00Z') `
    -ObservedAt ([datetime]'2026-08-23T08:00:00Z')
Assert-True -Condition ($csvResult.records_read -eq 3 -and $csvResult.hints_total -eq 2) -Message 'CSV-Import verarbeitet Zielgebiet/Rejects falsch.'

$badRegistry = [pscustomobject]@{
    schema_version = 'jobagent/discovery-source/v2'
    items = @()
}
try {
    Import-JobAgentRegisterCandidates -InputPath $fixture -SourceRegistry $badRegistry -SnapshotId 'bad' -SnapshotDate ([datetime]'2026-08-01T00:00:00Z') | Out-Null
    throw 'fehlende Source Registry wurde akzeptiert'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'Registerquelle|Source Registry|Quelle') -Message 'Fehlende Source Registry muss fail-closed melden.'
}

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-register-import-' + [guid]::NewGuid().ToString('N'))
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

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentRegisterCandidates.ps1') -ProjectRoot $projectRoot -InputPath $fixture -SnapshotId 'tool-snapshot' -SnapshotDate '2026-08-01T00:00:00Z' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Register-Import-Script ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($scriptResult.status -eq 'ok') -Message 'Register-Import-Script liefert keinen OK-Status.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.output_path) -PathType Leaf) -Message 'Register-Import-Script schreibt keine Register-Hint-Datei.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.merged_hints_path) -PathType Leaf) -Message 'Register-Import-Script schreibt keinen gemergten Hint-Store.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.log_path) -PathType Leaf) -Message 'Register-Import-Script schreibt kein Logartefakt.'
    $written = Get-Content -LiteralPath ([string]$scriptResult.output_path) -Raw | ConvertFrom-Json -Depth 100
    $merged = Get-Content -LiteralPath ([string]$scriptResult.merged_hints_path) -Raw | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($written.hints_total -eq 5) -Message 'Geschriebene Register-Hints haben falsche Anzahl.'
    Assert-True -Condition ($merged.hints_total -eq 5) -Message 'Gemergter Hint-Store uebernimmt Register-Hints nicht.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'source_registry_fail_closed',
        'jsonl_stream_import',
        'csv_import',
        'target_area_mapping',
        'dedupe_keys',
        'snapshot_hashes',
        'stale_snapshot',
        'future_snapshot_rejected',
        'no_personal_register_roles',
        'script_writes_register_and_merged_hints'
    )
    hints = $result.hints_total
} | ConvertTo-Json -Depth 4
