#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$FeedPath = 'data/jobagent/company-discovery.official.json',
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][AllowNull()][string]$WaveId = $null,
    [Parameter()][string]$WaveConfigPath = 'data/jobagent/company-import-waves.json'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$resolvedFeedPath = if ([IO.Path]::IsPathRooted($FeedPath)) { $FeedPath } else { Join-Path $projectRoot $FeedPath }
if (-not (Test-Path -LiteralPath $resolvedFeedPath -PathType Leaf)) {
    throw "Discovery-Feed fehlt: $resolvedFeedPath"
}

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function New-ToolStoreBackup {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$DataRootPath,
        [Parameter(Mandatory)][string]$Reason
    )

    $store = Join-Path (Join-Path $Root $DataRootPath) 'store.json'
    if (-not (Test-Path -LiteralPath $store -PathType Leaf)) {
        return $null
    }
    $backupRoot = Join-Path (Join-Path $Root $DataRootPath) 'backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $stamp = [datetime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
    $backupPath = Join-Path $backupRoot ("store-$stamp-$Reason.json")
    Copy-Item -LiteralPath $store -Destination $backupPath -Force
    return $backupPath
}

$importedAt = [datetime]::UtcNow
$nextScanAt = $importedAt.Date.AddDays(1)
$feed = Get-Content -LiteralPath $resolvedFeedPath -Raw | ConvertFrom-Json -Depth 100
$discoveryItems = if ($feed -is [System.Collections.IEnumerable] -and $feed -isnot [string]) { @($feed) } else { @($feed.items) }
if ($discoveryItems.Count -eq 0) {
    throw "Discovery-Feed enthaelt keine Eintraege: $resolvedFeedPath"
}

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRoot -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
    $beforeDocument = $document | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    $importSummary = Import-JobAgentCompanyDiscoveryInventory -Document $document -DiscoveryItems $discoveryItems -ImportedAt $importedAt -NextScanAt $nextScanAt
    $backupPath = $null
    $waveGate = $null
    if (-not [string]::IsNullOrWhiteSpace($WaveId)) {
        $resolvedWaveConfigPath = if ([IO.Path]::IsPathRooted($WaveConfigPath)) { $WaveConfigPath } else { Join-Path $projectRoot $WaveConfigPath }
        if (-not (Test-Path -LiteralPath $resolvedWaveConfigPath -PathType Leaf)) {
            throw "Importwellen-Konfiguration fehlt: $resolvedWaveConfigPath"
        }
        $backupPath = New-ToolStoreBackup -Root $projectRoot -DataRootPath $DataRoot -Reason 'pre-wave-import'
        $waveConfig = Get-Content -Raw -LiteralPath $resolvedWaveConfigPath | ConvertFrom-Json -Depth 100
        $waveGate = Test-JobAgentCompanyImportWaveGate -BeforeDocument $beforeDocument -ImportSummary $importSummary -WaveConfig $waveConfig -WaveId $WaveId -BackupPath $backupPath
        if ([string]$waveGate.status -ne 'passed') {
            throw ('Importwellen-Gate fehlgeschlagen: ' + ((@($waveGate.violations) | Sort-Object) -join ', '))
        }
    }
    $storePath = Write-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot -Document $importSummary.document -CreateBackup:([string]::IsNullOrWhiteSpace($WaveId))
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$after = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$feedName = [IO.Path]::GetFileNameWithoutExtension($resolvedFeedPath)
$logPrefix = if ($feedName -match 'regional') { 'company-discovery-regional-import-' } else { 'company-discovery-import-' }
$logPath = Join-Path $logPathRoot ($logPrefix + $importedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    ts = $importedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    feed_path = $resolvedFeedPath
    store_path = $storePath
    imported_company_ids = @($importSummary.imported)
    added_company_ids = @($importSummary.added)
    updated_company_ids = @($importSummary.updated)
    deduplicated = @($importSummary.deduplicated)
    manual_review_required = @($importSummary.manual_review_required)
    wave_id = if ([string]::IsNullOrWhiteSpace($WaveId)) { $null } else { $WaveId }
    wave_gate = $waveGate
    backup_path = $backupPath
    company_count = @($after.companies).Count
    source_count = @($after.job_sources).Count
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 8
