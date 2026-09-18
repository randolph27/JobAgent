#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-publication-' + [guid]::NewGuid().ToString('N'))
try {
    $reportPath = Join-Path $projectRoot 'html\jobagent\daily-run-fixture.html'
    $storePath = Join-Path $projectRoot 'data\jobagent\store.json'
    New-Item -ItemType Directory -Path (Split-Path -Parent $reportPath) -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $storePath) -Force | Out-Null
    $reportHtml = '<!DOCTYPE html><html lang="de"><body><section id="jobagent-search">Stellenangebot</section></body></html>'
    [IO.File]::WriteAllText($reportPath, $reportHtml, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($storePath, '{"schema_version":"fixture"}', [Text.UTF8Encoding]::new($false))

    $publication = Write-JobAgentDailyRunPublication -ProjectRoot $projectRoot -ScanRunId 'scanrun:publication-fixture' -HtmlReportPath $reportPath -StorePath $storePath
    Assert-True -Condition (Test-Path -LiteralPath $publication.jobboard_path -PathType Leaf) -Message 'Publikation schreibt keinen stabilen Einstieg.'
    Assert-True -Condition (Test-Path -LiteralPath $publication.publication_manifest_path -PathType Leaf) -Message 'Publikation schreibt kein Manifest.'
    Assert-True -Condition (([IO.File]::ReadAllText($publication.jobboard_path)) -eq $reportHtml) -Message 'Stabiler Einstieg unterscheidet sich vom gerenderten Report.'
    $manifest = Get-Content -LiteralPath $publication.publication_manifest_path -Raw | ConvertFrom-Json -Depth 20
    Assert-True -Condition ($manifest.scan_run_id -eq 'scanrun:publication-fixture') -Message 'Manifest verweist auf die falsche Generation.'
    Assert-True -Condition ($manifest.jobboard_path -eq 'html/jobagent/index.html') -Message 'Manifest verwendet keinen stabilen Einstiegspfad.'
    Assert-True -Condition ($manifest.hashes.source_html_sha256 -eq $manifest.hashes.jobboard_sha256) -Message 'Manifest erkennt keine einheitliche HTML-Generation.'

    $previousHtml = [IO.File]::ReadAllText($publication.jobboard_path)
    $interrupted = $false
    try {
        Write-JobAgentDailyRunPublication -ProjectRoot $projectRoot -ScanRunId 'scanrun:interrupted' -HtmlReportPath $reportPath -StorePath $storePath -FaultInjector {
            param([string]$Point)
            if ($Point -eq 'before_jobboard_publish') {
                throw 'fixture interruption'
            }
        } | Out-Null
    }
    catch {
        $interrupted = $_.Exception.Message -match 'fixture interruption'
    }
    Assert-True -Condition $interrupted -Message 'Unterbrochene Publikation wird nicht abgebrochen.'
    Assert-True -Condition (([IO.File]::ReadAllText($publication.jobboard_path)) -eq $previousHtml) -Message 'Unterbrochene Publikation ersetzt den letzten gueltigen Einstieg.'

    [pscustomobject]@{
        status = 'ok'
        cases = @('stable_jobboard_path', 'manifest_hashes_single_generation', 'interrupted_publish_preserves_previous_entry')
    } | ConvertTo-Json -Depth 4
}
finally {
    if (Test-Path -LiteralPath $projectRoot) {
        Remove-Item -LiteralPath $projectRoot -Recurse -Force
    }
}
