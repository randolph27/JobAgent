#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
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

function New-TestWaveCompany {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Domain,
        [Parameter()][AllowNull()][string]$CareerUrl = $null,
        [Parameter()][string]$DiscoveryType = 'OFFICIAL_WEBSITE'
    )

    [pscustomobject]@{
        canonical_name = $Name
        official_website_url = 'https://' + $Domain + '/'
        career_url = $CareerUrl
        aliases = @($Name)
        locations = @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH'))
        industry = 'Technology'
        scan_priority = 85
        discovery_type = $DiscoveryType
        discovery_url = if ($null -eq $CareerUrl) { 'https://' + $Domain + '/' } else { $CareerUrl }
        discovery_origin = 'test.import-wave'
        evidence_note = 'Offizielle Testquelle fuer Importwellen-Gate.'
    }
}

$waveConfigPath = Join-Path $root 'data\jobagent\company-import-waves.json'
Assert-True -Condition (Test-Path -LiteralPath $waveConfigPath -PathType Leaf) -Message 'Importwellen-Konfiguration fehlt.'
$waveConfig = Get-Content -Raw -LiteralPath $waveConfigPath | ConvertFrom-Json -Depth 100
Assert-True -Condition ($waveConfig.schema_version -eq 'jobagent/company-import-waves/v1') -Message 'Importwellen-Konfiguration hat falsche Schema-Version.'
Assert-True -Condition (@($waveConfig.waves).Count -eq 4) -Message 'Importwellen-Konfiguration definiert nicht A-D.'
Assert-True -Condition (@($waveConfig.waves | Where-Object { [string]$_.wave_id -eq 'C' -and @($_.required_evidence) -contains 'career_url' }).Count -eq 1) -Message 'Welle C verlangt keine Karriere-URL.'
Assert-True -Condition (@($waveConfig.waves | Where-Object { [string]$_.wave_id -eq 'D' -and [bool]$_.productive_upsert_allowed -eq $false }).Count -eq 1) -Message 'Welle D ist nicht fail-closed fuer produktive Upserts.'

$before = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-23T08:00:00Z')
$officialItems = @(
    (New-TestWaveCompany -Name 'Wave Official AG' -Domain 'wave-official.invalid' -CareerUrl 'https://wave-official.invalid/careers')
)
$officialSummary = Import-JobAgentCompanyDiscoveryInventory -Document ($before | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100) -DiscoveryItems $officialItems -ImportedAt ([datetime]'2026-08-23T08:00:00Z') -NextScanAt ([datetime]'2026-08-24T06:00:00Z')
$backupPath = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-wave-backup-' + [guid]::NewGuid().ToString('N') + '.json')
$before | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $backupPath -Encoding UTF8
try {
    $passedGate = Test-JobAgentCompanyImportWaveGate -BeforeDocument $before -ImportSummary $officialSummary -WaveConfig $waveConfig -WaveId 'A' -BackupPath $backupPath
    Assert-True -Condition ($passedGate.status -eq 'passed') -Message 'Offizielle Welle A besteht das Gate nicht.'
    Assert-True -Condition ($passedGate.metrics.added -eq 1) -Message 'Gate zaehlt hinzugefuegte Firmen falsch.'
    Assert-True -Condition ($passedGate.metrics.coverage_delta -eq 1) -Message 'Gate zaehlt Coverage-Delta falsch.'

    $hintSummary = Import-JobAgentCompanyDiscoveryInventory -Document ($before | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100) -DiscoveryItems @(
        (New-TestWaveCompany -Name 'Wave Hint AG' -Domain 'wave-hint.invalid' -DiscoveryType 'DISCOVERY_HINT')
    ) -ImportedAt ([datetime]'2026-08-23T08:00:00Z') -NextScanAt ([datetime]'2026-08-24T06:00:00Z')
    $failedGate = Test-JobAgentCompanyImportWaveGate -BeforeDocument $before -ImportSummary $hintSummary -WaveConfig $waveConfig -WaveId 'A' -BackupPath $backupPath
    Assert-True -Condition ($failedGate.status -eq 'failed') -Message 'Unverifizierter Hint wurde produktiv importierbar.'
    Assert-True -Condition (@($failedGate.violations | Where-Object { $_ -match 'VERIFICATION_STATUS_NOT_ALLOWED|SECONDARY_SOURCE_PRODUCTIVE_UPSERT|MANUAL_REVIEW_RATE_EXCEEDED' }).Count -ge 1) -Message 'Gate meldet keinen fail-closed Grund fuer Hint.'

    $missingBackupGate = Test-JobAgentCompanyImportWaveGate -BeforeDocument $before -ImportSummary $officialSummary -WaveConfig $waveConfig -WaveId 'A' -BackupPath (Join-Path ([IO.Path]::GetTempPath()) 'missing-wave-backup.json')
    Assert-True -Condition (@($missingBackupGate.violations | Where-Object { $_ -eq 'ROLLBACK_BACKUP_MISSING' }).Count -eq 1) -Message 'Gate verlangt keinen Rollback-Backup.'
}
finally {
    if (Test-Path -LiteralPath $backupPath) {
        Remove-Item -LiteralPath $backupPath -Force
    }
}

$scriptProjectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-wave-script-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scriptProjectRoot -Force | Out-Null
try {
    Write-JobAgentStore -ProjectRoot $scriptProjectRoot -Document (New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-23T08:00:00Z')) | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scriptProjectRoot 'data\jobagent') -Force | Out-Null
    Copy-Item -LiteralPath $waveConfigPath -Destination (Join-Path $scriptProjectRoot 'data\jobagent\company-import-waves.json') -Force
    $feedPath = Join-Path $scriptProjectRoot 'wave-feed.json'
    [pscustomobject]@{
        items = @(
            (New-TestWaveCompany -Name 'Wave Script AG' -Domain 'wave-script.invalid' -CareerUrl 'https://wave-script.invalid/careers')
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $feedPath -Encoding UTF8

    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentCompanyDiscovery.ps1') -ProjectRoot $scriptProjectRoot -FeedPath $feedPath -WaveId 'A' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Wellen-Import-Script ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 100
    Assert-True -Condition ($scriptResult.wave_id -eq 'A') -Message 'Wellen-Import-Script meldet keine Wellen-ID.'
    Assert-True -Condition ($scriptResult.wave_gate.status -eq 'passed') -Message 'Wellen-Import-Script meldet kein bestandenes Gate.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.backup_path) -PathType Leaf) -Message 'Wellen-Import-Script erzeugt keinen Rollback-Backup.'

    $blockedFeedPath = Join-Path $scriptProjectRoot 'wave-blocked-feed.json'
    [pscustomobject]@{
        items = @(
            (New-TestWaveCompany -Name 'Wave Blocked AG' -Domain 'wave-blocked.invalid' -DiscoveryType 'DISCOVERY_HINT')
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $blockedFeedPath -Encoding UTF8
    $blockedOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentCompanyDiscovery.ps1') -ProjectRoot $scriptProjectRoot -FeedPath $blockedFeedPath -WaveId 'A' 2>&1)
    Assert-True -Condition ($LASTEXITCODE -ne 0) -Message 'Wellen-Import-Script akzeptiert unverifizierten Hint.'
    $blockedStore = Read-JobAgentStore -ProjectRoot $scriptProjectRoot
    Assert-True -Condition (@($blockedStore.companies | Where-Object { [string]$_.company_id -eq 'company:wave_blocked_ag' }).Count -eq 0) -Message 'Fail-Closed-Gate hat Store trotzdem veraendert.'
}
finally {
    if (Test-Path -LiteralPath $scriptProjectRoot) {
        Remove-Item -LiteralPath $scriptProjectRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'wave_config_contract',
        'wave_gate_allows_official_evidence',
        'wave_gate_rejects_unverified_productive_upsert',
        'wave_gate_requires_rollback_backup',
        'wave_import_script_writes_backup_and_gate_report',
        'wave_import_script_fail_closed_without_store_change'
    )
} | ConvertTo-Json -Depth 4
