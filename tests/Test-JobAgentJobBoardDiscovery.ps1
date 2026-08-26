#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.JobBoardDiscovery.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

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

$stepstoneSource = Get-JobAgentJobBoardSource -SourceRegistry $registry -SourceId 'source-registry:stepstone_muenchen'
Assert-True -Condition ([string]$stepstoneSource.evidence_level -eq 'DISCOVERY_HINT') -Message 'StepStone muss Discovery-Hint bleiben.'

try {
    Get-JobAgentJobBoardSource -SourceRegistry $registry -SourceId 'source-registry:indeed_de' | Out-Null
    throw 'Indeed wurde ohne Freigabe importierbar gemacht.'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'Live-Abruf|freigegeben') -Message 'Blockierte Jobboerse muss fail-closed melden.'
}

$blockedSource = $registry.items[0].PSObject.Copy()
$blockedSource.source_id = 'source-registry:blocked_jobs'
$blockedSource.source_class = 'JOB_BOARD_DISCOVERY'
$blockedSource.import_mode = 'REJECT'
$blockedSource.evidence_level = 'DISCOVERY_HINT'
$blockedSource.review_required = $true
try {
    Assert-JobAgentJobBoardSource -Source $blockedSource
    throw 'Reject-Quelle wurde akzeptiert.'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'blockiert') -Message 'Reject-Quelle muss blockiert sein.'
}

Assert-True -Condition (Test-JobAgentJobBoardStaffingEmployer -EmployerName 'Hays Professional Solutions GmbH') -Message 'Personaldienstleister wird nicht erkannt.'
Assert-True -Condition (-not (Test-JobAgentJobBoardStaffingEmployer -EmployerName 'Siemens AG')) -Message 'Normale Arbeitgeber werden faelschlich als Personaldienstleister markiert.'
Assert-True -Condition ((Get-JobAgentJobBoardTargetArea -Location 'Garching b. Muenchen') -eq 'MUNICH') -Message 'Randgebiet Muenchen wird nicht erkannt.'
Assert-True -Condition ((Get-JobAgentJobBoardTargetArea -Location 'Freising') -eq 'FREISING') -Message 'Freising wird nicht erkannt.'
Assert-True -Condition ((Get-JobAgentJobBoardTargetArea -Location 'Hamburg') -eq 'OUT_OF_SCOPE') -Message 'Fremder Ort wird nicht ausgeschlossen.'

$companies = Get-JobAgentCompanySeedInventory -CreatedAt ([datetime]'2026-08-23T08:00:00Z') -NextScanAt ([datetime]'2026-08-24T06:00:00Z')
$fixture = Join-Path $root 'tests\fixtures\jobagent\jobboard-discovery\stepstone-muenchen-snapshot.json'
$result = Import-JobAgentJobBoardEmployers -SnapshotPath $fixture -SourceRegistry $registry -KnownCompanies $companies
Assert-True -Condition ($result.schema_version -eq 'jobagent/jobboard-discovery/v1') -Message 'Jobboersenimport hat falsche Schema-Version.'
Assert-True -Condition ($result.pages_read -eq 2) -Message 'Pagination-Grenze wird nicht eingehalten.'
Assert-True -Condition ($result.records_read -eq 4) -Message 'Erwartete Records aus zwei Seiten fehlen.'
Assert-True -Condition ($result.hints_total -eq 3) -Message 'Dubletten werden nicht verdichtet.'
Assert-True -Condition ($result.staffing_agency_hints -eq 1) -Message 'Personaldienstleister-Zaehler ist falsch.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.employer_name -eq 'Siemens AG' }).Count -eq 1) -Message 'Siemens-Dublette wurde nicht zusammengefuehrt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.employer_name -eq 'Out Of Scope AG' }).Count -eq 0) -Message 'Out-of-scope-Treffer wurde nicht entfernt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.candidate_status -ne 'DISCOVERY_HINT' -or [string]$_.verification_status -ne 'UNVERIFIED' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'Jobboersen-Hints muessen unverifiziert bleiben.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.observed_url -notmatch '^https://www\.stepstone\.de/' }).Count -eq 0) -Message 'Posting-URLs werden nicht absolut normalisiert.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.source_record_hash -notmatch '^[a-f0-9]{64}$' -or [string]$_.evidence_snippet_hash -notmatch '^[a-f0-9]{64}$' }).Count -eq 0) -Message 'Hash-Evidenz fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.raw_retention_policy -ne 'minimal_metadata_only_no_full_posting_content' }).Count -eq 0) -Message 'Retention-Policy fehlt.'
Assert-True -Condition (@($result.hints | Where-Object { $_.PSObject.Properties.Name -contains 'description' -or $_.PSObject.Properties.Name -contains 'full_text' -or $_.PSObject.Properties.Name -contains 'recruiter' }).Count -eq 0) -Message 'Unzulaessige Anzeigen-/Personendaten wurden persistiert.'
Assert-True -Condition (@($result.hints | Where-Object { [string]$_.known_company_id -eq 'company:siemens_ag' }).Count -eq 1) -Message 'Bekannte Firma wird nicht markiert.'

$baFixture = Join-Path $root 'tests\fixtures\jobagent\jobboard-discovery\ba-jobsuche-muenchen-snapshot.json'
$baResult = Import-JobAgentJobBoardEmployers -SnapshotPath $baFixture -SourceRegistry $registry -KnownCompanies $companies
Assert-True -Condition ($baResult.source_id -eq 'source-registry:ba_jobsuche') -Message 'BA-Jobsuche-Snapshot wird nicht als eigene Quelle gefuehrt.'
Assert-True -Condition ($baResult.records_read -eq 2) -Message 'BA-Jobsuche-Import filtert Zielgebiet oder Pflichtfelder falsch.'
Assert-True -Condition ($baResult.hints_total -eq 2) -Message 'BA-Jobsuche-Import erzeugt falsche Hint-Anzahl.'
Assert-True -Condition (@($baResult.hints | Where-Object { [string]$_.observed_url -notmatch '^https://www\.arbeitsagentur\.de/jobsuche/jobdetail/' }).Count -eq 0) -Message 'BA-Jobsuche-URLs werden nicht absolut normalisiert.'
Assert-True -Condition (@($baResult.hints | Where-Object { [string]$_.posting_url -match 'stepstone|indeed' }).Count -eq 0) -Message 'BA-Jobsuche-Hints duerfen keine Jobboersenfremd-URL uebernehmen.'
Assert-True -Condition (@($baResult.hints | Where-Object { [string]$_.candidate_status -ne 'DISCOVERY_HINT' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'BA-Jobsuche-Hints muessen unverifizierte Arbeitgeber-Hinweise bleiben.'
Assert-True -Condition (@($baResult.hints | Where-Object { [string]$_.known_company_id -eq 'company:stadtwerke_muenchen_gmbh' }).Count -eq 1) -Message 'BA-Jobsuche-Hint markiert bekannte Arbeitgeberfirma nicht.'

$freisingFixture = Join-Path $root 'tests\fixtures\jobagent\jobboard-discovery\stepstone-freising-snapshot.json'
$freisingResult = Import-JobAgentJobBoardEmployers -SnapshotPath $freisingFixture -SourceRegistry $registry -KnownCompanies $companies
Assert-True -Condition ($freisingResult.source_id -eq 'source-registry:stepstone_freising') -Message 'StepStone-Freising-Snapshot wird nicht als eigene Quelle gefuehrt.'
Assert-True -Condition ($freisingResult.records_read -eq 2) -Message 'StepStone-Freising-Import filtert Zielgebiet oder Pflichtfelder falsch.'
Assert-True -Condition ($freisingResult.hints_total -eq 2) -Message 'StepStone-Freising-Import erzeugt falsche Hint-Anzahl.'
Assert-True -Condition (@($freisingResult.hints | Where-Object { [string]$_.target_area -ne 'FREISING' }).Count -eq 0) -Message 'StepStone-Freising-Hints muessen als Freising-Zielgebiet markiert werden.'
Assert-True -Condition (@($freisingResult.hints | Where-Object { [string]$_.observed_url -notmatch '^https://www\.stepstone\.de/' }).Count -eq 0) -Message 'StepStone-Freising-URLs werden nicht absolut normalisiert.'
Assert-True -Condition (@($freisingResult.hints | Where-Object { [string]$_.candidate_status -ne 'DISCOVERY_HINT' -or [bool]$_.official_verification_required -ne $true }).Count -eq 0) -Message 'StepStone-Freising-Hints muessen unverifizierte Arbeitgeber-Hinweise bleiben.'
Assert-True -Condition (@($freisingResult.hints | Where-Object { [string]$_.employer_name -eq 'Out Of Scope Freising Search AG' }).Count -eq 0) -Message 'StepStone-Freising-Out-of-scope-Treffer wurde nicht entfernt.'

$emptyFixture = Join-Path $root 'tests\fixtures\jobagent\jobboard-discovery\stepstone-empty-snapshot.json'
$emptyResult = Import-JobAgentJobBoardEmployers -SnapshotPath $emptyFixture -SourceRegistry $registry -KnownCompanies $companies
Assert-True -Condition ($emptyResult.hints_total -eq 0 -and $emptyResult.records_read -eq 0) -Message 'Leere Ergebnisse werden falsch behandelt.'

$blockedFixture = Join-Path $root 'tests\fixtures\jobagent\jobboard-discovery\indeed-blocked-snapshot.json'
try {
    Import-JobAgentJobBoardEmployers -SnapshotPath $blockedFixture -SourceRegistry $registry -KnownCompanies $companies | Out-Null
    throw 'Manual-review-only-Quelle wurde importiert.'
}
catch {
    Assert-True -Condition ([string]$_.Exception.Message -match 'Live-Abruf|freigegeben') -Message 'Manual-review-only-Quelle muss blockiert werden.'
}

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-jobboard-import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
try {
    New-Item -ItemType Directory -Path (Join-Path $projectRoot 'data\jobagent') -Force | Out-Null
    Copy-Item -LiteralPath $registryPath -Destination (Join-Path $projectRoot 'data\jobagent\company-discovery.sources.json') -Force
    $store = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-23T08:00:00Z')
    $seeded = Add-JobAgentCompanySeedInventory -Document $store -Seeds $companies -SeededAt ([datetime]'2026-08-23T08:00:00Z')
    Write-JobAgentStore -ProjectRoot $projectRoot -Document $seeded.document | Out-Null
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

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentJobBoardEmployers.ps1') -ProjectRoot $projectRoot -SnapshotPath $fixture 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Jobboersen-Import-Script ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($scriptResult.status -eq 'ok') -Message 'Jobboersen-Import-Script liefert keinen OK-Status.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.output_path) -PathType Leaf) -Message 'Jobboersen-Import-Script schreibt keine Jobboard-Datei.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.merged_hints_path) -PathType Leaf) -Message 'Jobboersen-Import-Script schreibt keinen gemergten Hint-Store.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.log_path) -PathType Leaf) -Message 'Jobboersen-Import-Script schreibt kein Logartefakt.'
    $written = Get-Content -LiteralPath ([string]$scriptResult.output_path) -Raw | ConvertFrom-Json -Depth 100
    $merged = Get-Content -LiteralPath ([string]$scriptResult.merged_hints_path) -Raw | ConvertFrom-Json -Depth 100
    $postStore = Read-JobAgentStore -ProjectRoot $projectRoot
    Assert-True -Condition ($written.hints_total -eq 3) -Message 'Geschriebene Jobboersen-Hints haben falsche Anzahl.'
    Assert-True -Condition ($merged.hints_total -eq 3) -Message 'Gemergter Hint-Store uebernimmt Jobboersen-Hints nicht.'
    Assert-True -Condition (@($postStore.job_sources).Count -eq @($seeded.document.job_sources).Count) -Message 'Jobboersenimport darf keine JobSources erzeugen.'
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'source_registry_jobboard_contract',
        'manual_review_only_source_blocked',
        'reject_source_blocked',
        'html_employer_extraction',
        'pagination_limit',
        'dedupe_by_hint_id',
        'target_area_filter',
        'staffing_agency_marking',
        'ba_jobsuche_snapshot_import',
        'stepstone_freising_snapshot_import',
        'minimal_hash_evidence',
        'empty_results',
        'no_jobsource_side_effect',
        'script_writes_jobboard_and_merged_hints'
    )
    hints = $result.hints_total
} | ConvertTo-Json -Depth 4
