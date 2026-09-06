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
Assert-True -Condition ($output.sources_total -eq 32) -Message 'Quelleninventur muss alle 32 Registry-Quellen ausweisen.'
Assert-True -Condition ($output.hints_total -eq 1790) -Message 'Quelleninventur zaehlt Discovery-Hints falsch.'
Assert-True -Condition ($output.queue_total -eq 1785) -Message 'Quelleninventur zaehlt Kandidatenqueue falsch.'
Assert-True -Condition ($output.hints_without_queue -eq 5) -Message 'Die fuenf Hints ohne Queueeintrag muessen einzeln erklaert werden.'
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
Assert-True -Condition (@($inventory.sources).Count -eq 32) -Message 'Quelleninventur enthaelt nicht jede Registry-Quelle als Zeile.'
Assert-True -Condition ($inventory.totals.retained_discovery_inventory -ge 2000) -Message 'Retention-Bestand wird in der Quelleninventur nicht mitgefuehrt.'
Assert-True -Condition ($inventory.totals.retained_discovered_urls -ge 1000) -Message 'Retained-URL-Bestand wird in der Quelleninventur nicht mitgefuehrt.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:openstreetmap_overpass_business_names' -and [int]$_.hint_count -ge 1000 }).Count -eq 1) -Message 'OSM-Hinweise werden nicht der Quelle zugeordnet.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:ba_jobsuche' -and [int]$_.hint_count -eq 4 }).Count -eq 1) -Message 'BA-Hinweise werden nicht exakt ausgewiesen.'
Assert-True -Condition (@($inventory.sources | Where-Object { [string]$_.source_id -eq 'source-registry:linkedin_jobs' -and [string]$_.next_action -eq 'blocked' }).Count -eq 1) -Message 'Blockierte Quellen muessen fail-closed ausgewiesen werden.'
Assert-True -Condition (@($inventory.sources | Where-Object { @($_.sample_hints).Count -gt 3 }).Count -eq 0) -Message 'Quellensamples duerfen maximal drei Hints enthalten.'

Assert-True -Condition ($reconciliation.schema_version -eq 'jobagent/candidate-reconciliation-ja0272/v1') -Message 'Reconciliation hat falsches Schema.'
Assert-True -Condition (@($reconciliation.hints_without_queue).Count -eq 5) -Message 'Reconciliation erklaert nicht exakt fuenf Hints ohne Queue.'
Assert-True -Condition (@($reconciliation.hints_without_queue | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.explanation) }).Count -eq 0) -Message 'Hints ohne Queue brauchen eine Erklaerung.'
Assert-True -Condition (@($reconciliation.small_hint_sources | Where-Object { [string]$_.explanation -match 'kein Quellenerschoepfungsnachweis' }).Count -ge 1) -Message 'Kleine Bestaende muessen gegen Quellenerschoepfungsdeutung abgesichert werden.'

Assert-True -Condition ($research.schema_version -eq 'jobagent/source-research/v1') -Message 'Quellenrecherche hat falsches Schema.'
Assert-True -Condition (@($research.source_candidates).Count -ge 6) -Message 'Quellenrecherche enthaelt zu wenige Quellenansaetze.'
foreach ($family in @('Kammer-/Branchenverzeichnis', 'Startup-/Technologieverzeichnis', 'Forschungs-/Hochschul-Ausgruendungen', 'Technologiepark-/Gruenderzentrum-Mitglieder')) {
    Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.family -eq $family }).Count -ge 1) -Message "Quellenfamilie fehlt: $family"
}
Assert-True -Condition (@($research.source_candidates | Where-Object { [string]$_.allowed_use_decision -match 'official' }).Count -eq 0) -Message 'Rechercheansaetze duerfen nicht als offizielle Karrierequellen markiert werden.'

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'source_inventory_writes_required_evidence',
        'all_registry_sources_reconciled',
        'hint_queue_gap_explained',
        'small_source_counts_are_not_exhaustion',
        'research_matrix_has_new_source_approaches',
        'rejected_sources_fail_closed'
    )
    evidence = @($output.inventory_path, $output.research_path, $output.reconciliation_path)
} | ConvertTo-Json -Depth 5
