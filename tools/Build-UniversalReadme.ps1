#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$bootstrapRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$introPath = Join-Path $bootstrapRoot 'docs\README-UNIVERSAL-INTRO.md'
$managerPath = Join-Path $bootstrapRoot 'docs\BOOTSTRAP-MANAGER.md'
$destinationPath = Join-Path $bootstrapRoot 'README.md'
$profiles = @(
    [ordered]@{ id = 'ubuntu-web'; title = 'Ubuntu Web / Quiz'; repairFence = $true },
    [ordered]@{ id = 'chess'; title = 'Chess / Kotlin-Multiplatform / Viewport'; repairFence = $true },
    [ordered]@{ id = 'sound-profile'; title = 'Sound Profile / Android / ADB'; repairFence = $false }
)

function Get-NormalizedProfileReadme {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][bool]$RepairFence
    )

    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in [IO.File]::ReadAllLines($Path)) { $lines.Add($line) }
    $fenceCount = @($lines | Where-Object { $_ -match '^```' }).Count
    if ($RepairFence -and ($fenceCount % 2) -ne 0) {
        $unixIndex = -1
        for ($index = 0; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -eq 'Unix (Start, detached):') {
                $unixIndex = $index
                break
            }
        }
        if ($unixIndex -lt 0) { throw "Fence-Reparaturanker fehlt: $Path" }
        $lines.Insert($unixIndex, '<!-- BOOTSTRAP-FENCE-REPAIR: fehlenden Abschluss vor Unix-Beispiel ergaenzt -->')
        $lines.Insert($unixIndex + 1, '```')
    }
    $finalFenceCount = @($lines | Where-Object { $_ -match '^```' }).Count
    if (($finalFenceCount % 2) -ne 0) { throw "README besitzt weiterhin ungerade Code-Fences: $Path" }
    return $lines -join "`n"
}

$parts = [Collections.Generic.List[string]]::new()
$parts.Add(([IO.File]::ReadAllText($introPath).TrimEnd()))
foreach ($profile in $profiles) {
    $templateRoot = Join-Path $bootstrapRoot ("templates\{0}" -f [string]$profile.id)
    $readmePath = Join-Path $templateRoot 'README.md'
    $manifestPath = Join-Path $templateRoot 'template.manifest.json'
    if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) { throw "Profil-README fehlt: $readmePath" }
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $body = Get-NormalizedProfileReadme -Path $readmePath -RepairFence ([bool]$profile.repairFence)
    $sourceState = if ([string]$manifest.source_selected_worktree -eq 'clean') { 'aus Git-HEAD' } else { 'einschliesslich der im Manifest ausgewiesenen lokalen Aenderungen' }
    $parts.Add(@"
<!-- BEGIN FULL PROFILE CONTRACT: $($profile.id) -->

## Vollstaendiger Profilvertrag: $($profile.title)

Quelle: $($manifest.source_root), Git-HEAD $($manifest.source_git_head), $sourceState. Dieser Abschnitt ist vollstaendig; die einzige redaktionelle Aenderung ist gegebenenfalls ein markierter fehlender Markdown-Fence-Abschluss.

$body

<!-- END FULL PROFILE CONTRACT: $($profile.id) -->
"@.Trim())
}
$parts.Add(@"
## Zentrale Bootstrap-Verwaltung

Der folgende Abschnitt dokumentiert Manager, Installation, Update, Repair, Integritaet und Tests. Er ergaenzt die Projektvertraege und ersetzt keine ihrer fachlichen Regeln.

$([IO.File]::ReadAllText($managerPath).TrimEnd())
"@.Trim())

$content = ($parts -join "`n`n") + "`n"
[IO.File]::WriteAllText($destinationPath, $content, [Text.UTF8Encoding]::new($false))
[pscustomobject]@{
    path = $destinationPath
    lines = @($content -split "`n").Count
    bytes = (Get-Item -LiteralPath $destinationPath).Length
    profiles = $profiles.Count
} | Format-List
