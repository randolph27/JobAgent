#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configPath = Join-Path $root '.ci\ci.config.json'
$reviewPath = Join-Path $root 'docs\reviews\SQ-006-toolchain.json'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-PropertyValue {
    param([object]$Object, [string]$Name, [object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Resolve-ContainedPath {
    param([string]$Root, [string]$RelativePath)
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'Artefaktpfad fehlt.'
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) 'Artefaktpfad darf nicht absolut sein.'
    $normalizedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $candidate = [IO.Path]::GetFullPath((Join-Path $normalizedRoot $RelativePath))
    $prefix = $normalizedRoot + [IO.Path]::DirectorySeparatorChar
    Assert-True ($candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) 'Artefaktpfad verlaesst die zulaessige Wurzel.'
    return $candidate
}

function Test-PinnedArtifact {
    param([string]$Root, [object]$Artifact, [switch]$RequireFile)
    $source = [string](Get-PropertyValue $Artifact 'source' '')
    $version = [string](Get-PropertyValue $Artifact 'version' '')
    $expectedHash = [string](Get-PropertyValue $Artifact 'sha256' '')
    Assert-True ($source -match '^https://') 'Artefaktquelle muss HTTPS verwenden.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($version)) 'Artefaktversion fehlt.'
    $path = Resolve-ContainedPath -Root $Root -RelativePath ([string](Get-PropertyValue $Artifact 'relative_path' ''))
    if (-not $RequireFile) { return $path }
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'Erforderliches Artefakt fehlt.'
    Assert-True ($expectedHash -match '^[A-Fa-f0-9]{64}$') 'Installiertes Artefakt besitzt keinen gueltigen SHA-256.'
    $actualHash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    Assert-True ($actualHash -eq $expectedHash.ToUpperInvariant()) 'Artefakthash weicht vom Pin ab.'
    return $path
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json
$sonar = Get-PropertyValue $config 'sonar'
$toolchain = Get-PropertyValue $sonar 'toolchain'
Assert-True (([string](Get-PropertyValue $sonar 'mode')) -eq 'not-supported') 'SQ-007 darf den Scanstatus noch nicht aktivieren.'
Assert-True (([string](Get-PropertyValue $toolchain 'status')) -eq 'verified') 'Beschaffte Artefakte muessen als verifiziert markiert sein.'
Assert-True (([string](Get-PropertyValue $toolchain 'analysis_scope')) -eq 'external-powershell-issues-only') 'Der Analyseumfang ist nicht ehrlich begrenzt.'

$artifactRoot = Resolve-ContainedPath -Root $root -RelativePath ([string](Get-PropertyValue $toolchain 'artifact_root' ''))
$artifacts = @((Get-PropertyValue $toolchain 'artifacts' @()))
Assert-True ($artifacts.Count -eq 3) 'Die SQ-006-Lieferkette muss genau drei Artefakte enthalten.'
Assert-True (@($artifacts.id | Sort-Object) -join ',' -eq 'java-runtime,PSScriptAnalyzer,sonar-scanner-cli') 'Die erwarteten SQ-006-Artefakte fehlen oder sind fremd.'
foreach ($artifact in $artifacts) {
    $package = [pscustomobject]@{ source=(Get-PropertyValue $artifact 'source'); version=(Get-PropertyValue $artifact 'version'); relative_path=(Get-PropertyValue $artifact 'package_relative_path'); sha256=(Get-PropertyValue $artifact 'package_sha256') }
    $null = Test-PinnedArtifact -Root $artifactRoot -Artifact $package -RequireFile
    $null = Test-PinnedArtifact -Root $artifactRoot -Artifact $artifact -RequireFile
}

Assert-True (([string](Get-PropertyValue $review 'status')) -eq 'verified') 'Review-Inventur meldet keinen verifizierten Installationsstatus.'
Assert-True (([string](Get-PropertyValue (Get-PropertyValue $review 'server') 'analysis_scope')) -eq 'external-powershell-issues-only') 'Review-Inventur verliert den Analyseumfang.'
Assert-True (([string](Get-PropertyValue (Get-PropertyValue $review 'local_inventory') 'decision')) -eq 'approved-for-fixture-implementation-only') 'Lokale Inventur darf keine Server-Scanfreigabe behaupten.'

$selfArtifact = [pscustomobject]@{
    source = 'https://example.invalid/sq-006-fixture'
    version = 'fixture'
    relative_path = 'tests/Test-SonarToolchain.ps1'
    sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
}
$null = Test-PinnedArtifact -Root $root -Artifact $selfArtifact -RequireFile

$missingRejected = $false
try {
    $missing = [pscustomobject]@{ source='https://example.invalid/missing'; version='fixture'; relative_path='tests/missing-artifact.ps1'; sha256=('0' * 64) }
    $null = Test-PinnedArtifact -Root $root -Artifact $missing -RequireFile
} catch { $missingRejected = $true }
Assert-True $missingRejected 'Fehlendes Artefakt wurde nicht fail-closed abgewiesen.'

$foreignRejected = $false
try {
    $foreign = [pscustomobject]@{ source='https://example.invalid/foreign'; version='fixture'; relative_path='..\outside.ps1'; sha256=('0' * 64) }
    $null = Test-PinnedArtifact -Root $root -Artifact $foreign -RequireFile
} catch { $foreignRejected = $true }
Assert-True $foreignRejected 'Pfadtraversierung wurde nicht fail-closed abgewiesen.'

$hashRejected = $false
try {
    $mismatch = [pscustomobject]@{ source='https://example.invalid/mismatch'; version='fixture'; relative_path='tests/Test-SonarToolchain.ps1'; sha256=('0' * 64) }
    $null = Test-PinnedArtifact -Root $root -Artifact $mismatch -RequireFile
} catch { $hashRejected = $true }
Assert-True $hashRejected 'Hashabweichung wurde nicht fail-closed abgewiesen.'

[pscustomobject]@{
    status = 'ok'
    cases = @('verified_toolchain_contract', 'artifact_root_containment', 'package_and_entrypoint_hashes', 'missing_artifact_rejected', 'foreign_artifact_rejected', 'hash_mismatch_rejected', 'no_global_toolchain_assumption')
    analysis_scope = 'external-powershell-issues-only'
    secret_sanitized = $true
} | ConvertTo-Json -Depth 4
