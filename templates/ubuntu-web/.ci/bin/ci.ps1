# UNIVERSAL CI Runtime (Windows / PowerShell 5.1+)
# Version: v4.8.3 (fully modularized)
# Template runtime: project-agnostic, deterministic, non-interactive.
# NOTE: Treat `.ci/bin/*` as immutable runtime. Update only via patch/zip.
# CI-051: Runtime-Dateien werden ausschliesslich ueber den gepinnten Preload-Vertrag aktualisiert.

[CmdletBinding()]
param(
  [Parameter(Position=0)][string]$Command = "menu",
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Args
)

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

$script:LastExecCmd = ""
$script:LastExecRunner = ""
$script:LastCmdLogPath = ""
$script:ChatHistoryAppended = $false

# ---- OpenAI (optional; used by `critic`) ----
$script:OpenAI_DefaultBaseUrl = "https://api.openai.com/v1"
$script:OpenAI_DefaultModel   = "gpt-5.2"

# normalize command (allow "#ci <cmd>")
try {
  if ($Command -match '^\s*#ci\s+(.+)$') { $Command = $Matches[1] }
  $Command = ([string]$Command).Trim()
} catch { $null = $_ }

$ScriptRoot = $PSScriptRoot
$RepoRoot   = (Resolve-Path (Join-Path $ScriptRoot "..\..")).Path
$CiRoot     = Join-Path $RepoRoot ".ci"
$LogsRoot   = Join-Path $RepoRoot "logs"

# Agent chat flow policy (for Sixth/agents reading handoff.latest.json).
$script:ChatFlowPolicy = @'
Keine Rueckfragen, keine Bestaetigungen, keine Text-Unterbrechungen.
Arbeite sequenziell weiter, bis ein harter Blocker erreicht ist.
Bei Blocker: status=blocked + reproduzierbare Schritte (Commands/Dateien) + ci stp.
'@

# ---- Immutable runtime & policy pins ----
$ImmutableBaseFiles = @(
  ".gitattributes",
  ".ci\bin\ci.ps1",
  ".ci\bin\ci.cmd",
  ".ci\ci.config.json",
  ".ci\tools\observer-daemon.ps1",
  "README.md",
  "manual\PROGRAM.md",
  "Roadmap.md",
  "project.policy.hard.md",
  "toolchain.pins.md",
  "architecture.contract.md",
  "browser-tests.contract.md"
)
$ImmutableRequiredBaseFiles = @(
  ".gitattributes",
  ".ci\ci.config.json"
)

# The loader accepts only the reviewed runtime module set. Adding a module requires
# changing this entrypoint and an explicit pre-load `runtime-update`; a wildcard
# can never make previously unknown code executable during bootstrap or repair.
$ImmutableRuntimeModuleNames = @(
  "browser-logic.ps1",
  "ci-commands-main.ps1",
  "ci-core.ps1",
  "core-utils.ps1",
  "critic-logic.ps1",
  "handoff-logic.ps1",
  "observer-logic.ps1",
  "project-logic.ps1",
  "sonar-logic.ps1",
  "todo-engine.ps1",
  "toolchain-gradle.ps1",
  "toolchain-java.ps1",
  "ui-commands.ps1",
  "verify-logic.ps1"
)
$ImmutableSnapshotMode = "content-addressed-v1"
$ImmutablePinSchema = "ci-immutable-pins/v3"
$LegacyImmutablePinSchema = "ci-immutable-pins/v2"
$ImmutableVerificationOnlyFiles = @(
  ".ci\bin\ci.ps1"
)
$ModulesDir = Join-Path $ScriptRoot "modules"

function Get-ImmutableRuntimeModuleFiles {
  if (-not (Test-Path -LiteralPath $ModulesDir -PathType Container)) { return @() }
  return @(Get-ChildItem -LiteralPath $ModulesDir -Filter "*.ps1" -File | Sort-Object Name)
}

function ConvertTo-ImmutableKey([string]$Path) {
  return ([string]$Path).Replace('/', '\').TrimStart('\').ToLowerInvariant()
}

function ConvertTo-ImmutableDisplayPath([string]$Path) {
  return ([string]$Path).Replace('\','/')
}

function Test-ImmutableVerificationOnlyPath([string]$Path) {
  $candidate = ConvertTo-ImmutableKey $Path
  foreach ($verificationOnlyPath in $ImmutableVerificationOnlyFiles) {
    if ((ConvertTo-ImmutableKey $verificationOnlyPath) -eq $candidate) { return $true }
  }
  return $false
}

function Assert-ExpectedRuntimeModuleSet([object[]]$Files, [bool]$AllowMissing = $false) {
  $actualNames = @($Files | ForEach-Object { [string]$_.Name })
  $issues = New-Object System.Collections.Generic.List[string]
  $expectedNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $actualNameSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  foreach ($expectedName in $ImmutableRuntimeModuleNames) { $null = $expectedNames.Add($expectedName) }
  foreach ($actualName in $actualNames) {
    if (-not $actualNameSet.Add($actualName)) {
      $issues.Add("duplicate_module:.ci/bin/modules/" + $actualName)
    }
    if (-not $expectedNames.Contains($actualName)) {
      $issues.Add("unexpected_module:.ci/bin/modules/" + $actualName)
    }
  }
  if (-not $AllowMissing) {
    foreach ($expectedName in $ImmutableRuntimeModuleNames) {
      if (-not $actualNameSet.Contains($expectedName)) {
        $issues.Add("missing_module:.ci/bin/modules/" + $expectedName)
      }
    }
  }
  if ($issues.Count -gt 0) {
    throw ("immutable verification failed before module load: " + (($issues | Sort-Object -Unique) -join ", "))
  }
}

function Enter-ImmutableRuntimeLock {
  $locksRoot = Join-Path $CiRoot "run\locks"
  New-Item -ItemType Directory -Path $locksRoot -Force | Out-Null
  $lockPath = Join-Path $locksRoot "immutable-runtime.lock"
  $deadline = [DateTime]::UtcNow.AddSeconds(30)
  while ($true) {
    try {
      $stream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $owner = "pid=$PID;utc=" + [DateTimeOffset]::UtcNow.ToString("o") + "`n"
      $ownerBytes = [Text.Encoding]::UTF8.GetBytes($owner)
      $stream.SetLength(0)
      $stream.Write($ownerBytes, 0, $ownerBytes.Length)
      $stream.Flush($true)
      return $stream
    } catch [IO.IOException] {
      if ([DateTime]::UtcNow -ge $deadline) {
        throw "immutable runtime lock timeout: $lockPath"
      }
      Start-Sleep -Milliseconds 100
    }
  }
}

function Exit-ImmutableRuntimeLock($LockStream) {
  if ($null -ne $LockStream) { $LockStream.Dispose() }
}

$immutableRuntimeLock = Enter-ImmutableRuntimeLock
$moduleFiles = @(Get-ImmutableRuntimeModuleFiles)
$preloadCommand = $Command.ToLowerInvariant()
Assert-ExpectedRuntimeModuleSet $moduleFiles ($preloadCommand -eq "restore-immutables")
$script:CiRuntimeFiles = @(
  ".ci\bin\ci.ps1"
  ".ci\bin\ci.cmd"
  foreach ($moduleName in $ImmutableRuntimeModuleNames) {
    ".ci\bin\modules\" + $moduleName
  }
)
$ImmutableFiles = @($ImmutableBaseFiles + $script:CiRuntimeFiles | Sort-Object -Unique)

function Get-ImmutableContainedPath([string]$Root, [string]$RelativePath) {
  $resolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\','/'))
  $resolvedPath = [IO.Path]::GetFullPath((Join-Path $resolvedRoot $RelativePath))
  $prefix = $resolvedRoot + [IO.Path]::DirectorySeparatorChar
  $comparison = $(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal })
  if (-not $resolvedPath.StartsWith($prefix, $comparison)) {
    throw "immutable path escapes configured root: $RelativePath"
  }
  return $resolvedPath
}

function Read-ImmutablePinsBeforeLoad {
  $pinsPath = Join-Path $CiRoot "pins\immutable.hashes.json"
  if (-not (Test-Path -LiteralPath $pinsPath -PathType Leaf)) { return $null }
  try {
    return (Get-Content -Raw -LiteralPath $pinsPath | ConvertFrom-Json)
  } catch {
    throw "immutable verification failed before module load: pins_unreadable"
  }
}

function Get-ImmutableSnapshotMode($Pins) {
  $property = $Pins.PSObject.Properties['snapshot_mode']
  if ($null -eq $property) { return "" }
  return [string]$property.Value
}

function Assert-ImmutablePinSchemaBeforeLoad($Pins) {
  $pinSchema = [string]$Pins.schema
  if ($pinSchema -ne $ImmutablePinSchema -and $pinSchema -ne $LegacyImmutablePinSchema) {
    throw "immutable verification failed before module load: invalid_pin_schema"
  }
  $expectedRuntimeKeys = @($script:CiRuntimeFiles | ForEach-Object { ConvertTo-ImmutableKey $_ } | Sort-Object -Unique)
  $rawPinnedRuntimeKeys = @($Pins.runtime_files | ForEach-Object { ConvertTo-ImmutableKey ([string]$_) })
  $pinnedRuntimeKeys = @($rawPinnedRuntimeKeys | Sort-Object -Unique)
  if ($rawPinnedRuntimeKeys.Count -ne $pinnedRuntimeKeys.Count -or $expectedRuntimeKeys.Count -ne $pinnedRuntimeKeys.Count -or @((Compare-Object -ReferenceObject $expectedRuntimeKeys -DifferenceObject $pinnedRuntimeKeys)).Count -gt 0) {
    throw "immutable verification failed before module load: runtime_manifest_mismatch"
  }
  $pinnedFileKeys = @{}
  foreach ($pin in @($Pins.files)) {
    $key = ConvertTo-ImmutableKey ([string]$pin.path)
    $hash = ([string]$pin.sha256).ToLowerInvariant()
    if (-not $key -or $pinnedFileKeys.ContainsKey($key) -or $hash -notmatch '^[a-f0-9]{64}$') {
      throw "immutable verification failed before module load: invalid_or_duplicate_pin"
    }
    $pinnedFileKeys[$key] = $true
  }
  $snapshotMode = Get-ImmutableSnapshotMode $Pins
  if ($pinSchema -eq $ImmutablePinSchema -and $snapshotMode -ne $ImmutableSnapshotMode) {
    throw "immutable verification failed before module load: invalid_snapshot_mode"
  }
  if ($pinSchema -eq $LegacyImmutablePinSchema -and $snapshotMode -and $snapshotMode -ne $ImmutableSnapshotMode) {
    throw "immutable verification failed before module load: invalid_snapshot_mode"
  }
  foreach ($runtimeKey in $expectedRuntimeKeys) {
    if (-not $pinnedFileKeys.ContainsKey($runtimeKey)) {
      throw "immutable verification failed before module load: runtime_pin_missing"
    }
  }
}

function Assert-ImmutableRuntimeBeforeLoad([bool]$RuntimeOnly = $false) {
  $pins = Read-ImmutablePinsBeforeLoad
  if ($null -eq $pins) {
    throw "immutable verification failed before module load: pins_missing"
  }
  Assert-ImmutablePinSchemaBeforeLoad $pins

  $pinByPath = @{}
  foreach ($pin in @($pins.files)) {
    $key = ConvertTo-ImmutableKey ([string]$pin.path)
    if (-not $key -or $pinByPath.ContainsKey($key)) {
      throw "immutable verification failed before module load: invalid_or_duplicate_pin"
    }
    $pinByPath[$key] = $pin
  }

  $issues = New-Object System.Collections.Generic.List[string]
  $pathsToVerify = $(if ($RuntimeOnly) { @($script:CiRuntimeFiles) } else { @($ImmutableFiles) })
  $runtimeKeys = @{}
  foreach ($runtimePath in @($script:CiRuntimeFiles)) { $runtimeKeys[(ConvertTo-ImmutableKey $runtimePath)] = $true }
  $verifiedKeys = @{}
  foreach ($relativePath in $pathsToVerify) {
    $absolutePath = Get-ImmutableContainedPath $RepoRoot $relativePath
    $key = ConvertTo-ImmutableKey $relativePath
    $verifiedKeys[$key] = $true
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
      if ($runtimeKeys.ContainsKey($key) -or $pinByPath.ContainsKey($key)) {
        $issues.Add("missing:" + (ConvertTo-ImmutableDisplayPath $relativePath))
      }
      continue
    }
    if (-not $pinByPath.ContainsKey($key)) {
      $issues.Add("unpinned:" + (ConvertTo-ImmutableDisplayPath $relativePath))
      continue
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $absolutePath).Hash.ToLowerInvariant()
    $expectedHash = ([string]$pinByPath[$key].sha256).ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
      $issues.Add("hash_mismatch:" + (ConvertTo-ImmutableDisplayPath $relativePath))
    }
  }
  foreach ($pin in @($pins.files)) {
    $relativePath = [string]$pin.path
    if (-not $relativePath) { continue }
    if ($RuntimeOnly -and -not $verifiedKeys.ContainsKey((ConvertTo-ImmutableKey $relativePath))) { continue }
    $absolutePath = Get-ImmutableContainedPath $RepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $absolutePath -PathType Leaf)) {
      $issues.Add("missing:" + (ConvertTo-ImmutableDisplayPath $relativePath))
    }
  }
  if ($issues.Count -gt 0) {
    throw ("immutable verification failed before module load: " + (($issues | Sort-Object -Unique) -join ", "))
  }
}

function Set-ImmutableReadOnlyBeforeLoad([string]$Path, [bool]$ReadOnly) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
  $item = Get-Item -LiteralPath $Path -Force
  $item.IsReadOnly = $ReadOnly
}

function Get-ImmutableBytesHash([byte[]]$Bytes) {
  $sha = [Security.Cryptography.SHA256]::Create()
  try {
    return (-join ($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString("x2") }))
  } finally {
    $sha.Dispose()
  }
}

function Write-ImmutableBytesAtomically([string]$Path, [byte[]]$Bytes) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
  $temporaryPath = $Path + ".tmp." + $PID + "." + [Guid]::NewGuid().ToString("N")
  $backupPath = $Path + ".bak." + $PID + "." + [Guid]::NewGuid().ToString("N")
  $destinationExisted = Test-Path -LiteralPath $Path -PathType Leaf
  $publishVerified = $false
  try {
    $stream = [IO.File]::Open($temporaryPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
      $stream.Write($Bytes, 0, $Bytes.Length)
      $stream.Flush($true)
    } finally {
      $stream.Dispose()
    }
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      Set-ImmutableReadOnlyBeforeLoad $Path $false
      [IO.File]::Replace($temporaryPath, $Path, $backupPath)
    } else {
      [IO.File]::Move($temporaryPath, $Path)
    }
    $expectedHash = Get-ImmutableBytesHash $Bytes
    $publishedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    if ($publishedHash -ne $expectedHash) {
      throw "immutable atomic publish verification failed:$Path"
    }
    $publishVerified = $true
  } catch {
    $publishError = $_
    try {
      if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
          Set-ImmutableReadOnlyBeforeLoad $Path $false
          $failedPublishPath = $Path + ".failed." + $PID + "." + [Guid]::NewGuid().ToString("N")
          [IO.File]::Replace($backupPath, $Path, $failedPublishPath)
          if (Test-Path -LiteralPath $failedPublishPath -PathType Leaf) {
            Remove-Item -Force -LiteralPath $failedPublishPath
          }
        } else {
          [IO.File]::Move($backupPath, $Path)
        }
      } elseif (-not $destinationExisted -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Remove-Item -Force -LiteralPath $Path
      }
    } catch {
      throw "immutable atomic publish failed and rollback failed: $($publishError.Exception.Message); $($_.Exception.Message); backup=$backupPath"
    }
    throw $publishError
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -Force -LiteralPath $temporaryPath
    }
    if ($publishVerified -and (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
      Remove-Item -Force -LiteralPath $backupPath
    }
  }
}

function Get-ImmutableSnapshotObjectPath([string]$Hash) {
  $normalizedHash = ([string]$Hash).ToLowerInvariant()
  if ($normalizedHash -notmatch '^[a-f0-9]{64}$') {
    throw "immutable snapshot object path rejected: invalid_hash"
  }
  $objectsRoot = Join-Path $CiRoot "pins\immutable.objects"
  return Get-ImmutableContainedPath $objectsRoot ($normalizedHash + ".bin")
}

function Get-ImmutableSnapshotSourcePath($Pins, [string]$SnapshotRoot, [string]$RelativePath, [string]$ExpectedHash) {
  if ((Get-ImmutableSnapshotMode $Pins) -eq $ImmutableSnapshotMode) {
    return Get-ImmutableSnapshotObjectPath $ExpectedHash
  }
  return Get-ImmutableContainedPath $SnapshotRoot $RelativePath
}

function Write-ImmutablePinsBeforeLoad {
  Assert-ExpectedRuntimeModuleSet @(Get-ImmutableRuntimeModuleFiles)
  $pinsRoot = Join-Path $CiRoot "pins"
  New-Item -ItemType Directory -Path $pinsRoot -Force | Out-Null
  $existingPins = Read-ImmutablePinsBeforeLoad
  $existingPinKeys = @{}
  if ($null -ne $existingPins) {
    $existingSchema = [string]$existingPins.schema
    if ($existingSchema -ne $ImmutablePinSchema -and $existingSchema -ne $LegacyImmutablePinSchema) {
      throw "immutable pin update failed before module load: invalid_existing_pin_schema"
    }
    foreach ($pin in @($existingPins.files)) {
      $key = ConvertTo-ImmutableKey ([string]$pin.path)
      if (-not $key -or $existingPinKeys.ContainsKey($key)) {
        throw "immutable pin update failed before module load: invalid_or_duplicate_existing_pin"
      }
      $existingPinKeys[$key] = $true
    }
  }
  $requiredKeys = @{}
  foreach ($relativePath in @($ImmutableRequiredBaseFiles + $script:CiRuntimeFiles)) {
    $requiredKeys[(ConvertTo-ImmutableKey $relativePath)] = $true
  }
  $records = @()
  foreach ($relativePath in @($ImmutableFiles | Sort-Object -Unique)) {
    $sourcePath = Get-ImmutableContainedPath $RepoRoot $relativePath
    $key = ConvertTo-ImmutableKey $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
      if ($requiredKeys.ContainsKey($key) -or $existingPinKeys.ContainsKey($key)) {
        throw "immutable pin update failed before module load: missing_required_or_previously_pinned:" + (ConvertTo-ImmutableDisplayPath $relativePath)
      }
      continue
    }
    $sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
    $hash = Get-ImmutableBytesHash $sourceBytes
    $records += @{ path=$relativePath; sha256=$hash }
    if (Test-ImmutableVerificationOnlyPath $relativePath) { continue }
    $objectPath = Get-ImmutableSnapshotObjectPath $hash
    $objectMatches = $false
    if (Test-Path -LiteralPath $objectPath -PathType Leaf) {
      $objectMatches = (Get-FileHash -Algorithm SHA256 -LiteralPath $objectPath).Hash.ToLowerInvariant() -eq $hash
    }
    if (-not $objectMatches) {
      Write-ImmutableBytesAtomically $objectPath $sourceBytes
    }
    Set-ImmutableReadOnlyBeforeLoad $objectPath $true
  }
  $pins = @{
    schema=$ImmutablePinSchema
    snapshot_mode=$ImmutableSnapshotMode
    ts=[DateTimeOffset]::Now.ToString("o")
    agent_id=$(if ($env:CI_AGENT_ID) { [string]$env:CI_AGENT_ID } else { "preload-runtime" })
    runtime_files=@($script:CiRuntimeFiles | Sort-Object -Unique)
    files=$records
  }
  $pinsPath = Join-Path $pinsRoot "immutable.hashes.json"
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $pinsBytes = $utf8.GetBytes((($pins | ConvertTo-Json -Depth 8 -Compress) + "`n"))
  Write-ImmutableBytesAtomically $pinsPath $pinsBytes
  foreach ($record in $records) {
    Set-ImmutableReadOnlyBeforeLoad (Get-ImmutableContainedPath $RepoRoot ([string]$record.path)) $true
  }
}

function Restore-ImmutablePinsBeforeLoad {
  $pins = Read-ImmutablePinsBeforeLoad
  if ($null -eq $pins) {
    throw "immutable restore failed before module load: pins_missing"
  }
  Assert-ImmutablePinSchemaBeforeLoad $pins
  Assert-ExpectedRuntimeModuleSet @(Get-ImmutableRuntimeModuleFiles) $true
  $snapshotRoot = Join-Path $CiRoot "pins\immutable.snapshot"
  $allowedKeys = @{}
  foreach ($relativePath in @($ImmutableFiles)) { $allowedKeys[(ConvertTo-ImmutableKey $relativePath)] = $true }
  foreach ($pin in @($pins.files)) {
    $relativePath = [string]$pin.path
    $key = ConvertTo-ImmutableKey $relativePath
    if (-not $key -or -not $allowedKeys.ContainsKey($key)) {
      throw "immutable restore failed before module load: unexpected_pin_path:$relativePath"
    }
    $expectedHash = ([string]$pin.sha256).ToLowerInvariant()
    if (Test-ImmutableVerificationOnlyPath $relativePath) {
      $verificationPath = Get-ImmutableContainedPath $RepoRoot $relativePath
      if (-not (Test-Path -LiteralPath $verificationPath -PathType Leaf)) {
        throw "immutable restore failed before module load: verification_only_missing:$relativePath"
      }
      $verificationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $verificationPath).Hash.ToLowerInvariant()
      if ($verificationHash -ne $expectedHash) {
        throw "immutable restore failed before module load: verification_only_mismatch:$relativePath"
      }
      continue
    }
    $snapshotPath = Get-ImmutableSnapshotSourcePath $pins $snapshotRoot $relativePath $expectedHash
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) {
      throw "immutable restore failed before module load: snapshot_missing:$relativePath"
    }
    $snapshotHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $snapshotPath).Hash.ToLowerInvariant()
    if ($snapshotHash -ne $expectedHash) {
      throw "immutable restore failed before module load: snapshot_hash_mismatch:$relativePath"
    }
  }
  foreach ($pin in @($pins.files)) {
    $relativePath = [string]$pin.path
    $expectedHash = ([string]$pin.sha256).ToLowerInvariant()
    if (Test-ImmutableVerificationOnlyPath $relativePath) {
      Set-ImmutableReadOnlyBeforeLoad (Get-ImmutableContainedPath $RepoRoot $relativePath) $true
      continue
    }
    $sourcePath = Get-ImmutableSnapshotSourcePath $pins $snapshotRoot $relativePath $expectedHash
    $destinationPath = Get-ImmutableContainedPath $RepoRoot $relativePath
    $snapshotBytes = [IO.File]::ReadAllBytes($sourcePath)
    if ((Get-ImmutableBytesHash $snapshotBytes) -ne $expectedHash) {
      throw "immutable restore failed before module load: snapshot_changed_during_restore:$relativePath"
    }
    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
      $destinationHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash.ToLowerInvariant()
      if ($destinationHash -eq $expectedHash) {
        Set-ImmutableReadOnlyBeforeLoad $destinationPath $true
        continue
      }
    }
    Write-ImmutableBytesAtomically $destinationPath $snapshotBytes
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $destinationPath).Hash.ToLowerInvariant() -ne $expectedHash) {
      throw "immutable restore failed before module load: destination_hash_mismatch:$relativePath"
    }
    Set-ImmutableReadOnlyBeforeLoad $destinationPath $true
  }
}

# Bootstrap creates the first manifest before any module is loaded. Repair and
# updates are handled entirely by this trusted entrypoint and then terminate;
# potentially changed modules are never dot-sourced as part of those commands.
$immutableCommand = $Command.ToLowerInvariant()
$immutablePinsExist = Test-Path -LiteralPath (Join-Path $CiRoot "pins\immutable.hashes.json") -PathType Leaf
$script:ImmutablePinsCreatedBeforeLoad = $false
if ($immutableCommand -eq "restore-immutables") {
  Restore-ImmutablePinsBeforeLoad
  Write-Host "[CI] restore-immutables: ok (pre-load)"
  Exit-ImmutableRuntimeLock $immutableRuntimeLock
  exit 0
}
if ($immutableCommand -eq "repin-immutables") {
  if (-not $immutablePinsExist -and [string]$env:CI_IMMUTABLE_TOFU -ne "1") {
    throw "immutable verification failed before module load: tofu_authorization_required (set CI_IMMUTABLE_TOFU=1 once)"
  }
  if ($immutablePinsExist) { Assert-ImmutableRuntimeBeforeLoad $true }
  Write-ImmutablePinsBeforeLoad
  Write-Host "[CI] repin-immutables: ok (pre-load)"
  Exit-ImmutableRuntimeLock $immutableRuntimeLock
  exit 0
}
if ($immutableCommand -eq "runtime-update") {
  if (-not $immutablePinsExist -and [string]$env:CI_IMMUTABLE_TOFU -ne "1") {
    throw "immutable verification failed before module load: tofu_authorization_required (set CI_IMMUTABLE_TOFU=1 once)"
  }
  Write-ImmutablePinsBeforeLoad
  Write-Host "[CI] runtime-update: ok (pre-load)"
  Exit-ImmutableRuntimeLock $immutableRuntimeLock
  exit 0
}
if (-not $immutablePinsExist) {
  if (@("bootstrap", "start") -notcontains $immutableCommand) {
    throw "immutable verification failed before module load: pins_missing"
  }
  if ([string]$env:CI_IMMUTABLE_TOFU -ne "1") {
    throw "immutable verification failed before module load: tofu_authorization_required (set CI_IMMUTABLE_TOFU=1 once)"
  }
  Write-ImmutablePinsBeforeLoad
  $script:ImmutablePinsCreatedBeforeLoad = $true
}
Assert-ImmutableRuntimeBeforeLoad

# ---- Module Loading ----
if ($moduleFiles.Count -gt 0) {
  # Load core-utils first to ensure Register-CiCommand is available.
  $coreUtils = Join-Path $ModulesDir "core-utils.ps1"
  if (-not (Test-Path -LiteralPath $coreUtils -PathType Leaf)) {
    throw "CI runtime module missing: .ci/bin/modules/core-utils.ps1"
  }
  . $coreUtils
  foreach ($moduleName in $ImmutableRuntimeModuleNames) {
    if (-not [StringComparer]::Ordinal.Equals($moduleName, "core-utils.ps1")) {
      . (Join-Path $ModulesDir $moduleName)
    }
  }
}
Exit-ImmutableRuntimeLock $immutableRuntimeLock


# ---- UI Layout: Visual Regression + UI-Lint (best effort) ----
# Commands:
#   ui-check     : run screenshots + (optional) lint + ImageMagick diff vs baseline
#   ui-baseline  : (re)create baseline screenshots
#   ui-roadmap   : render latest findings as checklist markdown (logs/ui/roadmap.ui.md)
#
# Files:
#   tools/ui/ui-check.mjs           (Playwright runner; writes logs/ui/screens + logs/ui/ui.lint.json)
#   tools/ui/ui-check.config.json   (viewports/thresholds/selectors)
#   ui/baseline/*.png               (versioned baselines)

if (-not (Get-Variable -Name CiCommands -Scope Script -ErrorAction SilentlyContinue)) { $script:CiCommands = @{} }

function Ui-Info([string]$Msg) {
  try {
    if (Get-Command -Name CI-Info -ErrorAction SilentlyContinue) { CI-Info $Msg } else { Write-Host ("[UI] " + $Msg) }
  } catch { Write-Host ("[UI] " + $Msg) }
}

function Ui-EnsureDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Ui-ToRelPath([string]$Path) {
  try {
    if (Get-Command -Name To-RelPath -ErrorAction SilentlyContinue) { return (To-RelPath $Path) }
  } catch { $null = $_ }
  return $Path
}

function Ui-GetFreePort {
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
  $l.Start()
  $p = ($l.LocalEndpoint).Port
  $l.Stop()
  return [int]$p
}

function Ui-GetPythonExe {
  $py = (Get-Command -Name python -ErrorAction SilentlyContinue)
  if ($py) { return "python" }
  $py = (Get-Command -Name py -ErrorAction SilentlyContinue)
  if ($py) { return "py" }
  return $null
}

function Ui-StartServer([string]$Root, [int]$Port) {
  $py = Ui-GetPythonExe
  if (-not $py) { throw "python/py not found (needed to serve built web root). Install Python or wire into existing #ci pyserver-start." }

  # Prefer Python 3.7+ --directory
  $args = @("-m","http.server",[string]$Port,"--bind","127.0.0.1","--directory",$Root)
  Ui-Info ("start server: " + $py + " " + ($args -join " "))
  $startArgs = @{ FilePath=$py; ArgumentList=$args; PassThru=$true }
  if ($IsWindows) { $startArgs["WindowStyle"] = "Hidden" }
  $p = Start-Process @startArgs

  # Wait until ready (max ~5s)
  $url = "http://127.0.0.1:$Port/"
  $ok = $false
  for ($i=0; $i -lt 25; $i++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri $url
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok = $true; break }
    } catch { Start-Sleep -Milliseconds 200 }
  }
  if (-not $ok) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { $null = $_ }
    throw "server did not become ready at $url"
  }
  return @{ proc = $p; url = $url }
}

function Ui-StopServer($Server) {
  if ($null -eq $Server) { return }
  try {
    $p = $Server.proc
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  } catch { $null = $_ }
}

function Ui-DetectServeRoot {
  $candidates = @(
    "ui-web\build\dist\js\productionExecutable",
    "ui-web\build\kotlin-webpack\js\productionExecutable",
    "ui-web\build\processedResources\js\main",
    "web\build\dist\js\productionExecutable",
    "web\build\kotlin-webpack\js\productionExecutable",
    "web\build\processedResources\js\main"
  )
  foreach ($rel in $candidates) {
    $p = Join-Path $RepoRoot $rel
    $idx = Join-Path $p "index.html"
    if (Test-Path -LiteralPath $idx) { return $p }
  }
  return $null
}

function Ui-TryWebBuild {
  $candidates = @()
  if ($IsWindows) { $candidates += (Join-Path $RepoRoot "gradlew.bat") }
  $candidates += (Join-Path $RepoRoot "gradlew")
  $gradlew = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $gradlew) {
    Ui-Info "gradle wrapper not found; skipping build step (assuming assets already built)."
    return
  }
  $tasks = @(":ui-web:jsBrowserProductionWebpack",":ui-web:browserProductionWebpack",":ui-web:jsBrowserDevelopmentWebpack")
  foreach ($t in $tasks) {
    Ui-Info ("build: " + $t)
    & $gradlew $t "--console=plain"
    if ($LASTEXITCODE -eq 0) { return }
  }
  throw "web build failed (tried: $($tasks -join ', '))"
}


function Ui-ReadConfig([string]$ConfigPath) {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "missing config: $ConfigPath" }
  return (Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json)
}

function Ui-RunNode([string]$NodeScript, [string[]]$ArgsList) {
  $node = (Get-Command -Name node -ErrorAction SilentlyContinue)
  if (-not $node) { throw "node not found (required for Playwright runner)." }
  & node $NodeScript @ArgsList
  return $LASTEXITCODE
}

function Ui-CompareImages([string]$Baseline, [string]$Current, [string]$DiffOut) {
  $magick = (Get-Command -Name magick -ErrorAction SilentlyContinue)
  if (-not $magick) { throw "ImageMagick 'magick' not found in PATH." }

  Ui-EnsureDir (Split-Path -Parent $DiffOut)
  # magick compare writes metric to stderr; exit code is not reliable for our purposes.
  $out = & magick compare -metric AE $Baseline $Current $DiffOut 2>&1
  $ae = $null
  if ($out -match '^\s*(\d+)\s*$') { $ae = [int]$Matches[1] }
  elseif ($out -match '(\d+)') { $ae = [int]$Matches[1] }
  else { $ae = $null }
  return $ae
}

function Invoke-UiInternal([string]$Mode) {
  $cfgPath = Join-Path $RepoRoot "tools\ui\ui-check.config.json"
  $cfg = Ui-ReadConfig $cfgPath

  $logsUi = Join-Path $LogsRoot "ui"
  $screens = Join-Path $logsUi "screens"
  $diffs = Join-Path $logsUi "diff"
  Ui-EnsureDir $logsUi
  Ui-EnsureDir $screens
  Ui-EnsureDir $diffs

  if (-not $cfg.no_build) { Ui-TryWebBuild }

  $root = Ui-DetectServeRoot
  if (-not $root) { throw "serve root not found (missing index.html). Build first or adjust candidates in Ui-DetectServeRoot." }

  $webpackDir = Join-Path $RepoRoot "ui-web\build\webpack"
  if (Test-Path -LiteralPath $webpackDir) {
    Get-ChildItem -LiteralPath $webpackDir -Filter "*.js*" | ForEach-Object {
      $dest = Join-Path $root $_.Name
      Copy-Item -Force -LiteralPath $_.FullName -Destination $dest
    }
  }

  $port = Ui-GetFreePort
  $srv = $null
  try {
    $srv = Ui-StartServer $root $port
    $url = [string]$srv.url

    $nodeScript = Join-Path $RepoRoot "tools\ui\ui-check.mjs"
    if (-not (Test-Path -LiteralPath $nodeScript)) { throw "missing node runner: $nodeScript" }

    $lintOut = Join-Path $logsUi "ui.lint.json"
    $exit = Ui-RunNode $nodeScript @("--url",$url,"--out",$logsUi,"--mode",$Mode)

    # Visual diffs (per viewport)
    $baselineDir = Join-Path $RepoRoot "ui\baseline"
    $aeThreshold = 0
    try { $aeThreshold = [int]$cfg.visual.ae_threshold } catch { $aeThreshold = 0 }

    $visual = [ordered]@{ ts = (Get-Date).ToString("s"); mode=$Mode; url=$url; served_root=(Ui-ToRelPath $root); ae_threshold=$aeThreshold; viewports=@(); baseline_missing=@(); failures=@() }
    foreach ($vp in $cfg.viewports) {
      $vpName = [string]$vp.name
      $shot = Join-Path $screens ($vpName + ".png")
      $base = Join-Path $baselineDir ($vpName + ".png")
      $diff = Join-Path $diffs ($vpName + ".png")
      $vpRec = [ordered]@{ name=$vpName; screenshot=(Ui-ToRelPath $shot); baseline=(Ui-ToRelPath $base); ae=$null; diff=(Ui-ToRelPath $diff) }
      if (-not (Test-Path -LiteralPath $shot)) {
        $visual.failures += ("missing screenshot: " + $vpName)
      } elseif ($Mode -eq "baseline") {
        Ui-EnsureDir $baselineDir
        Copy-Item -Force -LiteralPath $shot -Destination $base
        $vpRec.ae = 0
      } else {
        if (-not (Test-Path -LiteralPath $base)) {
          $visual.baseline_missing += $vpName
        } else {
          $ae = Ui-CompareImages $base $shot $diff
          $vpRec.ae = $ae
          if ($aeThreshold -gt 0 -and $ae -ne $null -and $ae -gt $aeThreshold) {
            $visual.failures += ("visual diff AE>${aeThreshold}: " + $vpName + " (AE=" + $ae + ")")
          }
        }
      }
      $visual.viewports += $vpRec
    }

    $digestPath = Join-Path $logsUi "ui.visual.digest.json"
    $visual | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $digestPath

    if ($Mode -eq "check") {
      if ($visual.baseline_missing.Count -gt 0) { Ui-Info ("baseline missing: " + ($visual.baseline_missing -join ", ") + " (run: #ci ui-baseline)"); return 2 }
      if ($visual.failures.Count -gt 0) { Ui-Info ("visual failures: " + ($visual.failures -join " | ")); return 2 }
      if ($exit -ne 0) { return $exit }
    }
    return 0
  } finally {
    Ui-StopServer $srv
  }
}

function Invoke-UiRoadmap {
  $logsUi = Join-Path $LogsRoot "ui"
  $lintPath = Join-Path $logsUi "ui.lint.json"
  $visPath  = Join-Path $logsUi "ui.visual.digest.json"
  if (-not (Test-Path -LiteralPath $lintPath)) { throw "missing $lintPath (run: #ci ui-check)" }

  $lint = Get-Content -Raw -LiteralPath $lintPath | ConvertFrom-Json
  $vis = $null
  if (Test-Path -LiteralPath $visPath) { $vis = Get-Content -Raw -LiteralPath $visPath | ConvertFrom-Json }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# UI Roadmap (auto, ankreuzbar)")
  $lines.Add("")
  $lines.Add("Quelle: logs/ui/ui.lint.json" + ($(if($vis){ " + logs/ui/ui.visual.digest.json" } else { "" })))
  $lines.Add("")

  foreach ($vp in $lint.viewports) {
    $vpName = [string]$vp.name
    $lines.Add("## " + $vpName)
    $lines.Add("")
    $findings = @($vp.findings | Sort-Object severity, code)
    foreach ($f in $findings) {
      $title = [string]$f.title
      $sev = [string]$f.severity
      $code = [string]$f.code
      $e = [string]$f.evidence
      $lines.Add(('- [ ] [{0}] {1} (`{2}`)' -f $sev, $title, $code))
      if ($e) { $lines.Add("  - Evidence: " + $e) }
      if ($f.acceptance) {
        foreach ($a in @($f.acceptance)) { $lines.Add("  - [ ] " + [string]$a) }
      }
    }
    if ($vis) {
      $vpVis = $vis.viewports | Where-Object { $_.name -eq $vpName } | Select-Object -First 1
      if ($vpVis) {
        $lines.Add("")
        $lines.Add("- [ ] Visual Regression: AE <= " + [string]$vis.ae_threshold + " (aktuell: " + [string]$vpVis.ae + ")")
      }
    }
    $lines.Add("")
  }

  $outPath = Join-Path $logsUi "roadmap.ui.md"
  $lines -join "`r`n" | Set-Content -Encoding UTF8 -LiteralPath $outPath
  Ui-Info ("wrote: " + (Ui-ToRelPath $outPath))
}

# Register commands if not already present (do not override project-specific ones).
if (-not $script:CiCommands.ContainsKey("ui-check") -or -not $script:CiCommands["ui-check"]) {
$script:CiCommands["ui-check"] = { $ec = Invoke-UiInternal "check"; if ($ec -is [array]) { $ec = $ec[-1] }; $ec = [int]$ec; if ($ec -ne 0) { throw ("ui-check failed (exit=" + $ec + ")") } }
}
if (-not $script:CiCommands.ContainsKey("ui-baseline") -or -not $script:CiCommands["ui-baseline"]) {
$script:CiCommands["ui-baseline"] = { $ec = Invoke-UiInternal "baseline"; if ($ec -is [array]) { $ec = $ec[-1] }; $ec = [int]$ec; if ($ec -ne 0) { throw ("ui-baseline failed (exit=" + $ec + ")") } }
}
if (-not $script:CiCommands.ContainsKey("ui-roadmap") -or -not $script:CiCommands["ui-roadmap"]) {
  $script:CiCommands["ui-roadmap"] = { Invoke-UiRoadmap }
}

# ---- Supertest (integrates all relevant checks) ----
if (-not $script:CiCommands.ContainsKey("supertest") -or -not $script:CiCommands["supertest"]) {
  $script:CiCommands["supertest"] = {
    CI-Info "Running Supertest (UI-Check)"
    $ec = Invoke-UiInternal "check"
    if ($ec -ne 0) { throw ("Supertest failed (UI-Check exit=" + $ec + ")") }
    # Hier können weitere Tests hinzugefügt werden, z.B. Gradle-Tests
    # CI-Info "Running Gradle Check"
    # & $gradlew check --console=plain
    # if ($LASTEXITCODE -ne 0) { throw "Gradle check failed" }
  }
}

$script:LastCmdName = $Command
$cmdStart = Get-Date
try { CI-Info ("BEGIN: " + $Command) } catch { $null = $_ }
$exitCode = 0
$errMsg = $null

try {
  Ensure-NonInteractiveEnv
  $cmdLower = $Command.ToLowerInvariant()
  $pins = Read-ImmutablePins
  if ($pins) {
    if ($cmdLower -ne "bootstrap" -and $cmdLower -ne "patch-apply" -and $cmdLower -ne "restore-immutables" -and $cmdLower -ne "repin-immutables" -and $cmdLower -ne "runtime-update" -and $cmdLower -ne "menu") {
      Assert-ImmutableClean $cmdLower
    }
  } else {
    if ($cmdLower -ne "bootstrap" -and $cmdLower -ne "start" -and $cmdLower -ne "restore-immutables" -and $cmdLower -ne "repin-immutables" -and $cmdLower -ne "runtime-update" -and $cmdLower -ne "menu") {
      throw "immutable pins missing. Run: .ci\bin\ci.cmd bootstrap"
    }
  }

  $cmdKey = $cmdLower
  $script:CiCommandArgs = @($Args)
  if ($script:CiCommands.ContainsKey($cmdKey)) {
    & $script:CiCommands[$cmdKey]
  } else {
    throw "Unknown command: $Command"
  }
} catch {
  $exitCode = 1
  $errMsg = $_.Exception.Message
  try {
    Ensure-CoreFolders
    Ensure-BootstrapFiles
    $inv = $null; try { $inv = $_.InvocationInfo } catch { $inv = $null }
    $err = @{ ts = NowIso; cmd = $Command; exec_cmd = $script:LastExecCmd; exec_runner = $script:LastExecRunner; message = [string]$_.Exception.Message; exception_type = [string]$_.Exception.GetType().FullName; hresult = $null; category = $null; fqid = $null; script_stack = $null; position = $null; line = $null; offset = $null }
    try { $err.hresult = $_.Exception.HResult } catch { $null = $_ }
    try { $err.category = [string]$_.CategoryInfo } catch { $null = $_ }
    try { $err.fqid = [string]$_.FullyQualifiedErrorId } catch { $null = $_ }
    try { $err.script_stack = [string]$_.ScriptStackTrace } catch { $null = $_ }
    if ($inv) {
      try { $err.position = [string]$inv.PositionMessage } catch { $null = $_ }
      try { $err.line = $inv.ScriptLineNumber } catch { $null = $_ }
      try { $err.offset = $inv.OffsetInLine } catch { $null = $_ }
    }
    $tsId = TsId
    $cmdSafe = [string]$Command
    if (-not $cmdSafe) { $cmdSafe = "unknown" }
    $cmdSafe = ($cmdSafe -replace '[^a-zA-Z0-9_-]','_')
    $jsonPath = Join-Path $LogsRoot 'terminal\error-latest.json'
    $jsonCmdLatest = Join-Path $LogsRoot ("terminal\\error-" + $cmdSafe + "-latest.json")
    $jsonCmdTs = Join-Path $LogsRoot ("terminal\\error-" + $cmdSafe + "-" + $tsId + ".json")
    Write-Json $jsonPath $err
    Write-Json $jsonCmdLatest $err
    try { Write-Json $jsonCmdTs $err } catch { $null = $_ }
    $txtPath = Join-Path $LogsRoot 'terminal\error-latest.txt'
    $txtCmdLatest = Join-Path $LogsRoot ("terminal\\error-" + $cmdSafe + "-latest.txt")
    $txtCmdTs = Join-Path $LogsRoot ("terminal\\error-" + $cmdSafe + "-" + $tsId + ".txt")
    $txt = ($err.message + "`r`n" + ($err.position | Out-String).Trim() + "`r`n" + ($err.script_stack | Out-String).Trim() + "`r`n")
    Atomic-WriteTextUtf8 $txtPath $txt
    Atomic-WriteTextUtf8 $txtCmdLatest $txt
    try { Atomic-WriteTextUtf8 $txtCmdTs $txt } catch { $null = $_ }
    CI-Info ('error details: ' + (To-RelPath $jsonCmdLatest))
  } catch { $null = $_ }
}

try {
  Ensure-NonInteractiveEnv
  $cmdLower = $Command.ToLowerInvariant()
  if ($cmdLower -ne "stp" -and $cmdLower -ne "menu") {
    if (Get-AutoCheckpointEnabled) {
      $st = "open"
      if ($exitCode -ne 0) { $st = "blocked" }
      Write-AutoCheckpoint $cmdLower $st $errMsg
    }
  }
} catch { $null = $_ }

try {
  Ensure-NonInteractiveEnv
  $cmdLower = $Command.ToLowerInvariant()
  if ($cmdLower -ne "menu" -and -not $script:ChatHistoryAppended) {
    $st = $null
    try { $st = Load-TodoState } catch { $st = $null }
    $tid = $null
    try { $tid = [string](Get-Prop $st "active_id" $null) } catch { $tid = $null }
    if (-not $tid) { $tid = "SYSTEM" }
    $eid = New-EventId
    $sum = ("ci " + $cmdLower + ": ok")
    if ($exitCode -ne 0) {
      $em = [string]$errMsg
      if ($em -and $em.Length -gt 140) { $em = $em.Substring(0,140) + "..." }
      if ($em) { $sum = ("ci " + $cmdLower + ": fail: " + $em) } else { $sum = ("ci " + $cmdLower + ": fail") }
    }
    $refs = New-Object System.Collections.Generic.List[string]
    if ($script:LastCmdLogPath) { $refs.Add(("file:" + $script:LastCmdLogPath.Replace("\\","/"))) }
    $refs.Add("file:handoff.latest.json")
    Append-ChatHistoryLine @{ ts=NowIso; event_id=$eid; todo_id=$tid; summary=$sum; refs=@($refs) }
  }
} catch { $null = $_ }

$elapsedSec = 0.0
try { $elapsedSec = [math]::Round(((Get-Date) - $cmdStart).TotalSeconds, 2) } catch { $elapsedSec = 0.0 }
if ($exitCode -eq 0) {
  if ($Command.ToLowerInvariant() -ne "menu") {
    if ($script:LastCmdLogPath) { CI-Info ("log: " + $script:LastCmdLogPath) }
    CI-Info ("OK: " + $Command + " (" + $elapsedSec + "s)")
  }
} else {
  if ($script:LastCmdLogPath) { CI-Info ("log: " + $script:LastCmdLogPath) }
  CI-Info ("FAIL: " + $Command + " (" + $elapsedSec + "s)")
  if ($errMsg) { Write-Error -Message ([string]$errMsg) -Category OperationStopped -ErrorAction Continue } else { Write-Error -Message "unknown error" -Category OperationStopped -ErrorAction Continue }
}
exit $exitCode
