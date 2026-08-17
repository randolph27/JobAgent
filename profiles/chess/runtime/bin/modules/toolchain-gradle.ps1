function Get-GradleDesiredVersion() {
  $pins = Read-ToolchainPins
  if ($pins.gradle) { return [string]$pins.gradle }
  $cfg = Try-ReadJson (Get-ConfigPath)
  $g = Get-Prop $cfg "gradle" $null
  $v = Get-Prop $g "wrapper_default_version" $null
  if ($v) { return [string]$v }
  $tc = Get-Prop $cfg "toolchain" $null
  $v2 = Get-Prop $tc "gradle_default_version" "8.1.1"
  return [string]$v2
}

function Find-InboxGradleZip([string]$ver) {
  $inbox = Join-Path $CiRoot "inbox"
  $zipName = "gradle-" + $ver + "-bin.zip"
  $zipPath = Join-Path $inbox $zipName
  if (Test-Path -LiteralPath $zipPath -PathType Leaf) { return $zipPath }
  return $null
}

function Enable-Tls12IfNeeded() {
  try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol } catch { $null = $_ }
}

function Get-GradleDistUrls([string]$ver) {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $g = Get-Prop $cfg "gradle" $null
  $base = [string](Get-Prop $g "dist_base_url" "https://services.gradle.org/distributions/")
  if (-not $base.EndsWith("/")) { $base += "/" }
  $zipName = "gradle-" + $ver + "-bin.zip"
  $zipUrl  = $base + $zipName
  return @{ zipName=$zipName; zipUrl=$zipUrl }
}

function Read-CanonicalGradleWrapperProperties([string]$propertiesPath) {
  if (-not (Test-Path -LiteralPath $propertiesPath -PathType Leaf)) {
    throw ("Gradle distribution trust is missing: " + $propertiesPath)
  }
  $properties = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
  foreach ($line in (Get-Content -LiteralPath $propertiesPath)) {
    $raw = [string]$line
    $trimmed = $raw.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#") -or $trimmed.StartsWith("!")) { continue }
    if ($raw -ne $trimmed -or $raw -match '\\u[0-9a-fA-F]{4}') {
      throw "Gradle wrapper properties must use canonical, unescaped keys without surrounding whitespace."
    }
    $trailingBackslashes = 0
    for ($i = $raw.Length - 1; $i -ge 0 -and $raw[$i] -eq '\'; $i--) { $trailingBackslashes++ }
    if (($trailingBackslashes % 2) -ne 0) {
      throw "Gradle wrapper property continuations are not allowed."
    }
    $match = [regex]::Match($raw, '^([A-Za-z][A-Za-z0-9._-]*)=(.*)$')
    if (-not $match.Success) {
      throw "Gradle wrapper properties must use canonical key=value syntax."
    }
    $key = $match.Groups[1].Value
    if ($properties.ContainsKey($key)) {
      throw ("Gradle wrapper property must occur exactly once: " + $key)
    }
    $properties.Add($key, $match.Groups[2].Value)
  }
  return $properties
}

function Get-GradleDistributionTrust([string]$ver) {
  if (-not $ver -or $ver -notmatch '^\d+\.\d+(?:\.\d+)?$') {
    throw ("Gradle distribution version is invalid: " + $ver)
  }
  $root = Get-GradleProjectRoot
  if (-not $root) { $root = $RepoRoot }
  $propertiesPath = Join-Path $root "gradle\wrapper\gradle-wrapper.properties"
  $properties = Read-CanonicalGradleWrapperProperties $propertiesPath
  if (-not $properties.ContainsKey("distributionUrl")) {
    throw ("Gradle distributionUrl is missing in " + $propertiesPath)
  }
  $distributionUrlValue = [string]$properties["distributionUrl"]
  if ($distributionUrlValue -notmatch '^https\\://[^\s\\]+$') {
    throw "Gradle distributionUrl must use canonical escaped-HTTPS syntax."
  }
  $distributionUrl = $distributionUrlValue.Replace('\:', ':')
  $expectedSha256 = $null
  if ($properties.ContainsKey("distributionSha256Sum")) {
    $expectedSha256 = [string]$properties["distributionSha256Sum"]
  }
  if (-not $expectedSha256 -or $expectedSha256 -notmatch '^[0-9a-fA-F]{64}$') {
    throw ("Gradle distributionSha256Sum is missing or invalid in " + $propertiesPath)
  }

  $urls = Get-GradleDistUrls $ver
  $uri = $null
  try { $uri = [Uri]$distributionUrl } catch { $uri = $null }
  if ($null -eq $uri -or -not $uri.IsAbsoluteUri -or $uri.Scheme -ne "https") {
    throw "Gradle distributionUrl must be an absolute HTTPS URL."
  }
  if ($uri.UserInfo -or $uri.Query -or $uri.Fragment) {
    throw "Gradle distributionUrl must not contain credentials, query parameters, or fragments."
  }
  if ($uri.AbsoluteUri -ne ([Uri]$urls.zipUrl).AbsoluteUri) {
    throw ("Gradle distribution trust tuple mismatch for version " + $ver + ".")
  }
  if ([Uri]::UnescapeDataString((Split-Path -Leaf $uri.AbsolutePath)) -ne $urls.zipName) {
    throw ("Gradle distribution filename does not match version " + $ver + ".")
  }
  return @{
    version = $ver
    zipName = $urls.zipName
    zipUrl = $uri.AbsoluteUri
    sha256 = $expectedSha256.ToLowerInvariant()
    propertiesPath = $propertiesPath
  }
}

function Assert-GradleDistributionArchive([string]$archivePath, [hashtable]$trust) {
  if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    throw ("Gradle distribution archive is missing: " + $archivePath)
  }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
  if ($actual -ne $trust.sha256) {
    throw ("Gradle distribution checksum mismatch. expected=" + $trust.sha256 + " actual=" + $actual)
  }
  return $archivePath
}

function Remove-GradlePartialArchive([string]$partialPath) {
  if (-not $partialPath) { return }
  try {
    if (Test-Path -LiteralPath $partialPath) {
      Remove-Item -Force -LiteralPath $partialPath -ErrorAction Stop
    }
  } catch {
    throw ("Failed to remove partial Gradle distribution: " + $partialPath)
  }
}

function Invoke-GradleDistributionDownload([string]$uri, [string]$outFile, [int]$timeoutSec) {
  Invoke-WebRequest -Uri $uri -OutFile $outFile -UseBasicParsing -TimeoutSec $timeoutSec -ErrorAction Stop | Out-Null
}

function Wait-GradleDownloadRetry([int]$attempt) {
  Start-Sleep -Seconds ([Math]::Min(8, (2 * $attempt)))
}

function Download-GradleZip([string]$ver) {
  $trust = Get-GradleDistributionTrust $ver
  $cfg = Try-ReadJson (Get-ConfigPath)
  $g = Get-Prop $cfg "gradle" $null
  $inbox = Join-Path $CiRoot "inbox"
  Ensure-Dir $inbox
  $dst = Join-Path $inbox $trust.zipName
  $existingArchive = Find-InboxGradleZip $ver
  if ($existingArchive) {
    try { return (Assert-GradleDistributionArchive $existingArchive $trust) }
    catch {
      $integrityFailure = $_
      Remove-Item -Force -LiteralPath $existingArchive -ErrorAction Stop
      throw $integrityFailure
    }
  }
  $auto = [bool](Get-Prop $g "auto_download" $true)
  if (-not $auto) { return $null }
  $timeoutSec = 120
  try { $timeoutSec = [int](Get-Prop $g "download_timeout_sec" 120) } catch { $timeoutSec = 120 }
  if ($timeoutSec -lt 1) { $timeoutSec = 120 }
  Enable-Tls12IfNeeded
  CI-Info ("gradle: downloading " + $trust.zipUrl)
  $tmp = $dst + ".part." + $PID + "." + [Guid]::NewGuid().ToString("N")
  Remove-GradlePartialArchive $tmp
  $ok = $false
  try {
    for ($i=1; $i -le 3; $i++) {
      Remove-GradlePartialArchive $tmp
      try {
        Invoke-GradleDistributionDownload $trust.zipUrl $tmp $timeoutSec
        $ok = $true
        break
      } catch {
        if ($i -lt 3) { Wait-GradleDownloadRetry $i }
      }
    }
    if (-not $ok) { throw "Gradle distribution download failed after 3 attempts." }
    Assert-GradleDistributionArchive $tmp $trust | Out-Null
    Move-Item -LiteralPath $tmp -Destination $dst -ErrorAction Stop
    return $dst
  } finally {
    Remove-GradlePartialArchive $tmp
  }
}

function Get-GradleInstallMarkerPath([string]$targetDir) {
  return (Join-Path $targetDir ".distribution-integrity.json")
}

function Get-VerifiedGradleToolsRoot() {
  return (Join-Path $CiRoot "run\gradle-user-home\verified-tools")
}

function Enter-GradleVersionLock([string]$ver, [int]$timeoutSeconds=30) {
  $lockDir = Join-Path (Get-VerifiedGradleToolsRoot) ".locks"
  Ensure-Dir $lockDir
  $lockPath = Join-Path $lockDir ("gradle-" + $ver + ".lock")
  $deadline = (Get-Date).AddSeconds($timeoutSeconds)
  while ($true) {
    try {
      return [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch [IO.IOException] {
      if ((Get-Date) -ge $deadline) {
        throw ("Timed out waiting for Gradle distribution lock: " + $ver)
      }
      Start-Sleep -Milliseconds 100
    }
  }
}

function Get-GradleStreamSha256([IO.Stream]$stream) {
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $hash = $sha256.ComputeHash($stream)
    return (-join ($hash | ForEach-Object { $_.ToString("x2") }))
  } finally {
    $sha256.Dispose()
  }
}

function Test-GradleInstallationTree([string]$targetDir, [string]$archivePath, [hashtable]$trust) {
  if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) { return $false }
  try { Assert-GradleDistributionArchive $archivePath $trust | Out-Null } catch { return $false }
  try {
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
  } catch { return $false }
  $archive = $null
  try {
    $archive = [IO.Compression.ZipFile]::OpenRead($archivePath)
    $rootPrefix = "gradle-" + $trust.version + "/"
    $entries = New-Object 'System.Collections.Generic.Dictionary[string,System.IO.Compression.ZipArchiveEntry]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $archive.Entries) {
      $entryName = ([string]$entry.FullName).Replace('\', '/')
      if ($entryName.EndsWith("/")) { continue }
      if (-not $entryName.StartsWith($rootPrefix, [StringComparison]::Ordinal)) { return $false }
      $relative = $entryName.Substring($rootPrefix.Length).Replace('/', '\')
      if (-not $relative -or $relative -match '(^|\\)\.\.(\\|$)' -or [IO.Path]::IsPathRooted($relative)) { return $false }
      if ($entries.ContainsKey($relative)) { return $false }
      $entries.Add($relative, $entry)
    }
    if ($entries.Count -eq 0) { return $false }

    $markerPath = [IO.Path]::GetFullPath((Get-GradleInstallMarkerPath $targetDir))
    $actualFiles = @(Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force -ErrorAction Stop | Where-Object { [IO.Path]::GetFullPath($_.FullName) -ne $markerPath })
    if ($actualFiles.Count -ne $entries.Count) { return $false }
    $targetPrefix = [IO.Path]::GetFullPath($targetDir).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    foreach ($file in $actualFiles) {
      $fullPath = [IO.Path]::GetFullPath($file.FullName)
      if (-not $fullPath.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) { return $false }
      $relative = $fullPath.Substring($targetPrefix.Length)
      if (-not $entries.ContainsKey($relative)) { return $false }
      $entry = $entries[$relative]
      if ([long]$file.Length -ne [long]$entry.Length) { return $false }
      $entryStream = $null
      try {
        $entryStream = $entry.Open()
        $entrySha256 = Get-GradleStreamSha256 $entryStream
      } finally {
        if ($null -ne $entryStream) { $entryStream.Dispose() }
      }
      $fileSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $fullPath).Hash.ToLowerInvariant()
      if ($fileSha256 -ne $entrySha256) { return $false }
    }
    return $true
  } catch {
    return $false
  } finally {
    if ($null -ne $archive) { $archive.Dispose() }
  }
}

function Test-GradleInstallationTrust([string]$targetDir, [hashtable]$trust, [string]$archivePath) {
  $launcher = Join-Path $targetDir "bin\gradle.bat"
  $launcherJar = Join-Path $targetDir ("lib\gradle-launcher-" + $trust.version + ".jar")
  $markerPath = Get-GradleInstallMarkerPath $targetDir
  if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { return $false }
  if (-not (Test-Path -LiteralPath $launcherJar -PathType Leaf)) { return $false }
  if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) { return $false }
  $marker = $null
  try { $marker = Get-Content -Raw -LiteralPath $markerPath | ConvertFrom-Json } catch { return $false }
  if ([int](Get-Prop $marker "schema" 0) -ne 1) { return $false }
  if ([string](Get-Prop $marker "version" "") -ne $trust.version) { return $false }
  if ([string](Get-Prop $marker "distribution_url" "") -ne $trust.zipUrl) { return $false }
  if ([string](Get-Prop $marker "distribution_sha256" "") -ne $trust.sha256) { return $false }
  if ([string](Get-Prop $marker "archive_name" "") -ne $trust.zipName) { return $false }
  $launcherSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcher).Hash.ToLowerInvariant()
  if ([string](Get-Prop $marker "launcher_sha256" "") -ne $launcherSha256) { return $false }
  $launcherJarSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $launcherJar).Hash.ToLowerInvariant()
  if ([string](Get-Prop $marker "launcher_jar_sha256" "") -ne $launcherJarSha256) { return $false }
  return (Test-GradleInstallationTree $targetDir $archivePath $trust)
}

function Remove-GradleManagedDirectory([string]$path, [string]$allowedLeafPattern) {
  if (-not $path -or -not (Test-Path -LiteralPath $path)) { return }
  $toolsRoot = [IO.Path]::GetFullPath((Get-VerifiedGradleToolsRoot))
  $fullPath = [IO.Path]::GetFullPath($path)
  $toolsPrefix = $toolsRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $fullPath.StartsWith($toolsPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw ("Refusing to remove Gradle directory outside CI tools: " + $fullPath)
  }
  $leaf = Split-Path -Leaf $fullPath
  if ($leaf -notmatch $allowedLeafPattern) {
    throw ("Refusing to remove unexpected Gradle directory: " + $fullPath)
  }
  Remove-Item -Recurse -Force -LiteralPath $fullPath -ErrorAction Stop
}

function Restore-GradleInstallationAfterInterruptedSwap([string]$tools, [string]$targetDir, [string]$archivePath, [hashtable]$trust) {
  foreach ($stageDir in @(Get-ChildItem -LiteralPath $tools -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ".gradle-stage-*" })) {
    Remove-GradleManagedDirectory $stageDir.FullName '^\.gradle-stage-'
  }
  $backups = @(Get-ChildItem -LiteralPath $tools -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like (".gradle-backup-" + $trust.version + "-*") } | Sort-Object LastWriteTime -Descending)
  if (Test-GradleInstallationTrust $targetDir $trust $archivePath) {
    foreach ($backup in $backups) { Remove-GradleManagedDirectory $backup.FullName '^\.gradle-backup-' }
    return $true
  }
  foreach ($backup in $backups) {
    if (-not (Test-GradleInstallationTrust $backup.FullName $trust $archivePath)) {
      Remove-GradleManagedDirectory $backup.FullName '^\.gradle-backup-'
      continue
    }
    if (Test-Path -LiteralPath $targetDir) {
      Remove-GradleManagedDirectory $targetDir ('^gradle-' + [regex]::Escape($trust.version) + '$')
    }
    Move-Item -LiteralPath $backup.FullName -Destination $targetDir -ErrorAction Stop
    foreach ($remaining in $backups) {
      if ($remaining.FullName -ne $backup.FullName -and (Test-Path -LiteralPath $remaining.FullName)) {
        Remove-GradleManagedDirectory $remaining.FullName '^\.gradle-backup-'
      }
    }
    return (Test-GradleInstallationTrust $targetDir $trust $archivePath)
  }
  return $false
}

function Install-VerifiedGradleDistribution([string]$archivePath, [hashtable]$trust) {
  Assert-GradleDistributionArchive $archivePath $trust | Out-Null
  $tools = Get-VerifiedGradleToolsRoot
  Ensure-Dir $tools
  $nonce = [Guid]::NewGuid().ToString("N")
  $stageRoot = Join-Path $tools (".gradle-stage-" + $nonce)
  $backupDir = Join-Path $tools (".gradle-backup-" + $trust.version + "-" + $nonce)
  $targetDir = Join-Path $tools ("gradle-" + $trust.version)
  $stagedDir = Join-Path $stageRoot ("gradle-" + $trust.version)
  $backupCreated = $false
  try {
    Ensure-Dir $stageRoot
    Expand-Archive -LiteralPath $archivePath -DestinationPath $stageRoot -ErrorAction Stop
    $topDirectories = @(Get-ChildItem -LiteralPath $stageRoot -Directory -Force -ErrorAction Stop)
    $topFiles = @(Get-ChildItem -LiteralPath $stageRoot -File -Force -ErrorAction Stop)
    if ($topDirectories.Count -ne 1 -or $topFiles.Count -ne 0 -or $topDirectories[0].Name -ne ("gradle-" + $trust.version)) {
      throw ("Gradle archive root does not match version " + $trust.version + ".")
    }
    $stagedLauncher = Join-Path $stagedDir "bin\gradle.bat"
    $stagedLauncherJar = Join-Path $stagedDir ("lib\gradle-launcher-" + $trust.version + ".jar")
    if (-not (Test-Path -LiteralPath $stagedLauncher -PathType Leaf) -or -not (Test-Path -LiteralPath $stagedLauncherJar -PathType Leaf)) {
      throw "Gradle archive is incomplete: launcher files are missing."
    }
    $marker = [ordered]@{
      schema = 1
      version = $trust.version
      distribution_url = $trust.zipUrl
      distribution_sha256 = $trust.sha256
      archive_name = $trust.zipName
      launcher_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $stagedLauncher).Hash.ToLowerInvariant()
      launcher_jar_sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $stagedLauncherJar).Hash.ToLowerInvariant()
    }
    Write-Json (Get-GradleInstallMarkerPath $stagedDir) $marker
    if (-not (Test-GradleInstallationTrust $stagedDir $trust $archivePath)) {
      throw "Gradle staging integrity marker validation failed."
    }

    if (Test-Path -LiteralPath $targetDir) {
      Move-Item -LiteralPath $targetDir -Destination $backupDir -ErrorAction Stop
      $backupCreated = $true
    }
    try {
      Move-Item -LiteralPath $stagedDir -Destination $targetDir -ErrorAction Stop
      if (-not (Test-GradleInstallationTrust $targetDir $trust $archivePath)) {
        throw "Installed Gradle distribution failed integrity validation."
      }
    } catch {
      if (Test-Path -LiteralPath $targetDir) {
        Remove-GradleManagedDirectory $targetDir ('^gradle-' + [regex]::Escape($trust.version) + '$')
      }
      if ($backupCreated -and (Test-Path -LiteralPath $backupDir)) {
        Move-Item -LiteralPath $backupDir -Destination $targetDir -ErrorAction Stop
        $backupCreated = $false
      }
      throw
    }
    if ($backupCreated) {
      Remove-GradleManagedDirectory $backupDir '^\.gradle-backup-'
      $backupCreated = $false
    }
    return (Join-Path $targetDir "bin\gradle.bat")
  } finally {
    if (Test-Path -LiteralPath $stageRoot) {
      Remove-GradleManagedDirectory $stageRoot '^\.gradle-stage-'
    }
  }
}

function Ensure-LocalGradleDist([string]$ver) {
  $tools = Get-VerifiedGradleToolsRoot
  Ensure-Dir $tools
  $lock = Enter-GradleVersionLock $ver
  try {
    $targetDir = Join-Path $tools ("gradle-" + $ver)
    $bat = Join-Path $targetDir "bin\gradle.bat"
    $trust = Get-GradleDistributionTrust $ver
    $zip = Download-GradleZip $ver
    if (-not $zip) { throw ("Verified Gradle distribution unavailable. Place gradle-" + $ver + "-bin.zip into .ci\inbox\; global Gradle installations are not accepted.") }
    if (Restore-GradleInstallationAfterInterruptedSwap $tools $targetDir $zip $trust) { return $bat }
    CI-Info ("extracting Gradle from inbox: " + $zip)
    return (Install-VerifiedGradleDistribution $zip $trust)
  } finally {
    if ($null -ne $lock) { $lock.Dispose() }
  }
}

function Ensure-GradleWrapper() {
  $root = Get-GradleProjectRoot
  if (Wrapper-FilesPresent $root) {
    Get-GradleDistributionTrust (Get-GradleDesiredVersion) | Out-Null
    return
  }
  $cfg = Try-ReadJson (Get-ConfigPath)
  $gradleCfg = Get-Prop $cfg "gradle" $null
  $auto = $true
  try { $autoVal = Get-Prop $gradleCfg "wrapper_autorepair" $true; $auto = [bool]$autoVal } catch { $auto = $true }
  if (-not $auto) { return }
  $ver = Get-GradleDesiredVersion
  $trust = Get-GradleDistributionTrust $ver
  $g = Get-GradleCmdRaw
  $cmd = $g.cmd
  if (-not $cmd -or $g.mode -eq "unknown" -or $g.mode -eq "wrapper") { $cmd = Ensure-LocalGradleDist $ver }
  CI-Info ("generating Gradle wrapper (version " + $ver + ") using: " + $cmd)
  $log = Join-Path $LogsRoot ("terminal\gradle-wrapper-" + (TsId) + ".log")
  $envMap = Get-GradleEnv
  # Explicitly set GIT_LFS_PATH for the Gradle wrapper generation
  $envMap["GIT_LFS_PATH"] = "C:\Program Files\Git LFS"
  $wrapperArgs = " wrapper --gradle-version " + $ver + " --distribution-type bin --gradle-distribution-url " + $trust.zipUrl + " --gradle-distribution-sha256-sum " + $trust.sha256
  $res = Run-Cmd ((Quote-IfNeeded $cmd) + $wrapperArgs) $log $envMap $root
  if ($res.exit -ne 0) { throw ("Gradle wrapper generation failed. See " + $log) }
  if (-not (Wrapper-Ok $root)) { throw ("Gradle wrapper generation reported success, but wrapper files are still missing.") }
}

function Get-GradleEnv() {
  $envMap = Ensure-JavaReady
  $gh = Join-Path $CiRoot "run\gradle-user-home"
  Ensure-Dir $gh
  $envMap["GRADLE_USER_HOME"] = $gh
  $envMap["CI"] = "true"
  return $envMap
}

function Is-GradleProject() {
  $root = Get-GradleProjectRoot
  if (-not $root) { return $false }
  return $true
}

function Detect-BuildSystem() {
  if (Is-GradleProject) { return "gradle" }
  if (Test-Path (Join-Path $RepoRoot "package.json")) { return "node" }
  if (Test-Path (Join-Path $RepoRoot "pom.xml")) { return "maven" }
  return "unknown"
}

function Wrapper-Ok([string]$root=$null) {
  if (-not (Wrapper-FilesPresent $root)) { return $false }
  try {
    Get-GradleDistributionTrust (Get-GradleDesiredVersion) | Out-Null
    return $true
  } catch {
    return $false
  }
}

function Wrapper-FilesPresent([string]$root=$null) {
  if (-not $root) { $root = Get-GradleProjectRoot; if (-not $root) { $root = $RepoRoot } }
  $gwBat = Join-Path $root "gradlew.bat"
  $props = Join-Path $root "gradle\wrapper\gradle-wrapper.properties"
  $jar   = Join-Path $root "gradle\wrapper\gradle-wrapper.jar"
  return ((Test-Path -LiteralPath $gwBat -PathType Leaf) -and (Test-Path -LiteralPath $props -PathType Leaf) -and (Test-Path -LiteralPath $jar -PathType Leaf))
}

function Find-LocalGradleDistCmd([string]$ver=$null) {
  if (-not $ver) { $ver = Get-GradleDesiredVersion }
  $trust = Get-GradleDistributionTrust $ver
  $archivePath = Find-InboxGradleZip $ver
  if (-not $archivePath) { return $null }
  try { Assert-GradleDistributionArchive $archivePath $trust | Out-Null } catch { return $null }
  $targetDir = Join-Path (Get-VerifiedGradleToolsRoot) ("gradle-" + $ver)
  if (-not (Test-GradleInstallationTrust $targetDir $trust $archivePath)) { return $null }
  return (Join-Path $targetDir "bin\gradle.bat")
}

function Get-GradleCmdRaw() {
  $root = Get-GradleProjectRoot
  $ver = Get-GradleDesiredVersion
  if (Wrapper-FilesPresent $root) {
    Get-GradleDistributionTrust $ver | Out-Null
  }
  $local = Ensure-LocalGradleDist $ver
  return @{ mode="local-dist"; cmd=$local; root=$root }
}

function Persist-GradleInfo([string]$mode, [string]$cmd, [string]$root=$RepoRoot) {
  $p = Join-Path $CiRoot "run\toolchain.state.json"
  $st = Try-ReadJson $p
  if ($null -eq $st) { $st = @{ ts=NowIso; gradle=@{ mode="unknown"; cmd=$null; root=$null } } }
  $st.ts = NowIso
  $gradle = Get-Prop $st "gradle" $null
  if ($null -eq $gradle) { $st | Add-Member -NotePropertyName "gradle" -NotePropertyValue (@{ mode="unknown"; cmd=$null; root=$null }) -Force; $gradle = $st.gradle }
  $gradle.mode = $mode
  $gradle.cmd  = $cmd
  $gradle.root = $root
  Write-Json $p $st
}

$script:GradleRoot = $null

function Find-GradleProjectRoot([int]$maxDepth=10) {
  $names = @("settings.gradle","settings.gradle.kts","build.gradle","build.gradle.kts","gradlew.bat")
  $deny = @(".ci",".git","node_modules",".gradle","build","out",".idea",".vs")
  $q = New-Object System.Collections.Generic.Queue[object]
  $q.Enqueue(@($RepoRoot, 0))
  while ($q.Count -gt 0) {
    $it = $q.Dequeue()
    $dir = [string]$it[0]
    $depth = [int]$it[1]
    foreach ($n in $names) { $p = Join-Path $dir $n; if (Test-Path $p) { return $dir } }
    if ($depth -ge $maxDepth) { continue }
    $kids = @()
    try { $kids = Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue } catch { $kids = @() }
    foreach ($k in $kids) { if ($deny -contains $k.Name) { continue }; $q.Enqueue(@($k.FullName, ($depth + 1))) }
  }
  return $null
}

function Get-GradleProjectRoot() {
  if ($script:GradleRoot) { return $script:GradleRoot }
  $cfg = Try-ReadJson (Get-ConfigPath)
  $g = Get-Prop $cfg "gradle" $null
  $ov = Get-Prop $g "project_root" $null
  if ($ov) {
    $p = Join-Path $RepoRoot ([string]$ov)
    if (Test-Path $p) { try { $script:GradleRoot = (Resolve-Path $p).Path } catch { $script:GradleRoot = $p }; return $script:GradleRoot }
  }
  $depth = 10
  try { $depth = [int](Get-Prop $g "project_search_depth" 10) } catch { $depth = 10 }
  if ($depth -lt 0) { $depth = 0 }
  $found = Find-GradleProjectRoot $depth
  if ($found) { $script:GradleRoot = $found; return $found }
  return $null
}
