#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent'
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath($ProjectRoot)
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

$seededAt = [datetime]::UtcNow
$nextScanAt = $seededAt.Date.AddDays(1)
$seeds = @(Get-JobAgentCompanySeedInventory -CreatedAt $seededAt -NextScanAt $nextScanAt)
$result = Invoke-JobAgentStoreTransaction -ProjectRoot $root -DataRoot $DataRoot -CreateBackup -ScriptBlock {
    param($document)
    (Add-JobAgentCompanySeedInventory -Document $document -Seeds $seeds -SeededAt $seededAt).document
}

$after = Read-JobAgentStore -ProjectRoot $root -DataRoot $DataRoot
$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $root $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$logPath = Join-Path $logPathRoot ('company-seed-' + $seededAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    ts = $seededAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    store_path = $result.store_path
    seed_count = $seeds.Count
    company_count = @($after.companies).Count
    source_count = @($after.job_sources).Count
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 6
