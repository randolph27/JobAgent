#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$FeedPath = 'data/jobagent/company-discovery.official.json',
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent'
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
    $importSummary = Import-JobAgentCompanyDiscoveryInventory -Document $document -DiscoveryItems $discoveryItems -ImportedAt $importedAt -NextScanAt $nextScanAt
    $storePath = Write-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot -Document $importSummary.document -CreateBackup
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$after = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$logPath = Join-Path $logPathRoot ('company-discovery-import-' + $importedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    ts = $importedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    feed_path = $resolvedFeedPath
    store_path = $storePath
    imported_company_ids = @($importSummary.imported)
    added_company_ids = @($importSummary.added)
    updated_company_ids = @($importSummary.updated)
    deduplicated = @($importSummary.deduplicated)
    manual_review_required = @($importSummary.manual_review_required)
    company_count = @($after.companies).Count
    source_count = @($after.job_sources).Count
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 8
