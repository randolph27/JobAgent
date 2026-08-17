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

function Find-InboxGradleZip() {
  $inbox = Join-Path $CiRoot "inbox"
  if (-not (Test-Path $inbox)) { return $null }
  $z = Get-ChildItem -LiteralPath $inbox -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^gradle-\d+\.\d+(\.\d+)?-bin\.zip$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($z) { return $z.FullName }
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
  $shaUrl  = $zipUrl + ".sha256"
  return @{ zipName=$zipName; zipUrl=$zipUrl; shaUrl=$shaUrl }
}

function Download-GradleZip([string]$ver) {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $g = Get-Prop $cfg "gradle" $null
  $auto = [bool](Get-Prop $g "auto_download" $true)
  if (-not $auto) { return $null }
  $inbox = Join-Path $CiRoot "inbox"
  Ensure-Dir $inbox
  $u = Get-GradleDistUrls $ver
  $dst = Join-Path $inbox $u.zipName
  Enable-Tls12IfNeeded
  $shaPath = $dst + ".sha256"
  $expected = $null
  $checksumSource = $null
  try {
    $shaText = (Invoke-WebRequest -Uri $u.shaUrl -UseBasicParsing -ErrorAction Stop).Content
    $expected = (($shaText -split '\s+')[0]).Trim().ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') {
      throw ("Gradle checksum response is invalid: " + $u.shaUrl)
    }
    Atomic-WriteTextUtf8 $shaPath ($expected + "`n")
    $checksumSource = $u.shaUrl
  } catch {
    if (Test-Path -LiteralPath $shaPath -PathType Leaf) {
      $expected = (((Get-Content -Raw -LiteralPath $shaPath) -split '\s+')[0]).Trim().ToLowerInvariant()
      if ($expected -match '^[0-9a-f]{64}$') {
        $checksumSource = $shaPath
        CI-Warn ("gradle: checksum service unavailable; using cached checksum " + $shaPath)
      }
    }
    if (-not $checksumSource) {
      throw ("Gradle checksum unavailable and no valid local checksum exists. url=" + $u.shaUrl + " local=" + $shaPath + " error=" + $_.Exception.Message)
    }
  }
  if (Test-Path -LiteralPath $dst -PathType Leaf) {
    $cachedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash.ToLowerInvariant()
    if ($cachedHash -ne $expected) {
      throw ("Cached Gradle checksum mismatch. expected=" + $expected + " actual=" + $cachedHash + " path=" + $dst + " checksum_source=" + $checksumSource)
    }
    return $dst
  }
  CI-Info ("gradle: downloading " + $u.zipUrl)
  $tmp = $dst + ".part"
  try { if (Test-Path $tmp) { Remove-Item -Force $tmp -ErrorAction SilentlyContinue } } catch { $null = $_ }
  $ok = $false
  $err = $null
  for ($i=1; $i -le 3; $i++) {
    try { Invoke-WebRequest -Uri $u.zipUrl -OutFile $tmp -UseBasicParsing -ErrorAction Stop; $ok = $true; break }
    catch { $err = $_.Exception.Message; Start-Sleep -Seconds ([Math]::Min(8, (2 * $i))) }
  }
  if (-not $ok) { throw ("Gradle download failed after retries: " + $err) }
  $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $tmp).Hash.ToLowerInvariant()
  if ($actual -ne $expected) {
    Remove-Item -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
    throw ("Gradle checksum mismatch. expected=" + $expected + " actual=" + $actual)
  }
  Move-Item -Force -LiteralPath $tmp -Destination $dst
  return $dst
}

function Ensure-LocalGradleDist([string]$ver) {
  $tools = Join-Path $CiRoot "tools"
  Ensure-Dir $tools
  $targetDir = Join-Path $tools ("gradle-" + $ver)
  $bat = Join-Path $targetDir "bin\gradle.bat"
  if (Test-Path $bat) { return $bat }
  $zip = Find-InboxGradleZip
  if ($zip) {
    $zipFile = Get-Item -LiteralPath $zip
    $versionMatch = [regex]::Match($zipFile.Name, '^gradle-(\d+\.\d+(?:\.\d+)?)-bin\.zip$')
    if (-not $versionMatch.Success) { throw ("Gradle inbox filename is invalid: " + $zipFile.Name) }
    $zipVersion = $versionMatch.Groups[1].Value
    $zipUrls = Get-GradleDistUrls $zipVersion
    $zipShaPath = $zip + ".sha256"
    $zipExpected = $null
    $zipChecksumSource = $null
    if (Test-Path -LiteralPath $zipShaPath -PathType Leaf) {
      $zipExpected = (((Get-Content -Raw -LiteralPath $zipShaPath) -split '\s+')[0]).Trim().ToLowerInvariant()
      if ($zipExpected -match '^[0-9a-f]{64}$') { $zipChecksumSource = $zipShaPath }
    }
    if (-not $zipChecksumSource) {
      try {
        Enable-Tls12IfNeeded
        $zipShaText = (Invoke-WebRequest -Uri $zipUrls.shaUrl -UseBasicParsing -ErrorAction Stop).Content
        $zipExpected = (($zipShaText -split '\s+')[0]).Trim().ToLowerInvariant()
        if ($zipExpected -notmatch '^[0-9a-f]{64}$') { throw ("Gradle checksum response is invalid: " + $zipUrls.shaUrl) }
        Atomic-WriteTextUtf8 $zipShaPath ($zipExpected + "`n")
        $zipChecksumSource = $zipUrls.shaUrl
      } catch {
        throw ("Gradle inbox ZIP has no valid checksum and the checksum service is unavailable. zip=" + $zip + " url=" + $zipUrls.shaUrl + " error=" + $_.Exception.Message)
      }
    }
    $zipActual = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    if ($zipActual -ne $zipExpected) {
      throw ("Gradle inbox checksum mismatch. expected=" + $zipExpected + " actual=" + $zipActual + " path=" + $zip + " checksum_source=" + $zipChecksumSource)
    }
  } else {
    $zip = Download-GradleZip $ver
  }
  if (-not $zip) { throw ("Gradle wrapper missing and no local Gradle found. Place gradle-" + $ver + "-bin.zip and its .sha256 file into .ci\inbox\ or install Gradle on PATH.") }
  CI-Info ("extracting verified Gradle archive from inbox: " + $zip)
  try { Expand-Archive -LiteralPath $zip -DestinationPath $tools -Force } catch { throw ("Failed to extract Gradle zip: " + $zip) }
  if (-not (Test-Path $bat)) {
    $cand = Find-LocalGradleDistCmd
    if ($cand) { return $cand }
    throw ("Gradle extracted but gradle.bat not found under " + $tools)
  }
  return $bat
}

function Ensure-GradleWrapper() {
  $root = Get-GradleProjectRoot
  if (Wrapper-Ok $root) { return }
  $cfg = Try-ReadJson (Get-ConfigPath)
  $gradleCfg = Get-Prop $cfg "gradle" $null
  $auto = $true
  try { $autoVal = Get-Prop $gradleCfg "wrapper_autorepair" $true; $auto = [bool]$autoVal } catch { $auto = $true }
  if (-not $auto) { return }
  $ver = Get-GradleDesiredVersion
  $g = Get-GradleCmdRaw
  $cmd = $g.cmd
  if (-not $cmd -or $g.mode -eq "unknown" -or $g.mode -eq "wrapper") { $cmd = Ensure-LocalGradleDist $ver }
  CI-Info ("generating Gradle wrapper (version " + $ver + ") using: " + $cmd)
  $log = Join-Path $LogsRoot ("terminal\gradle-wrapper-" + (TsId) + ".log")
  $envMap = Get-GradleEnv
  # Explicitly set GIT_LFS_PATH for the Gradle wrapper generation
  $envMap["GIT_LFS_PATH"] = "C:\Program Files\Git LFS"
  $res = Run-Cmd ((Quote-IfNeeded $cmd) + " wrapper --gradle-version " + $ver + " --distribution-type bin") $log $envMap $root
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

function Is-GradleRequired() {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $toolchain = Get-Prop $cfg "toolchain" $null
  $required = Get-Prop $toolchain "gradle_required" $false
  try { return [bool]$required } catch { return $false }
}

function Detect-BuildSystem() {
  if (Is-GradleProject) { return "gradle" }
  if (Test-Path (Join-Path $RepoRoot "package.json")) { return "node" }
  if (Test-Path (Join-Path $RepoRoot "pom.xml")) { return "maven" }
  return "unknown"
}

function Wrapper-Ok([string]$root=$null) {
  if (-not $root) { $root = Get-GradleProjectRoot; if (-not $root) { $root = $RepoRoot } }
  $gwBat = Join-Path $root "gradlew.bat"
  $props = Join-Path $root "gradle\wrapper\gradle-wrapper.properties"
  $jar   = Join-Path $root "gradle\wrapper\gradle-wrapper.jar"
  return ((Test-Path $gwBat) -and (Test-Path $props) -and (Test-Path $jar))
}

function Find-LocalGradleDistCmd() {
  $roots = @($RepoRoot, (Join-Path $CiRoot "tools"))
  $best = $null
  $bestVer = $null
  foreach ($r in $roots) {
    if (-not (Test-Path $r)) { continue }
    $dirs = Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "gradle-*" }
    foreach ($d in $dirs) {
      $bat = Join-Path $d.FullName "bin\gradle.bat"
      if (-not (Test-Path $bat)) { continue }
      $m = [regex]::Match($d.Name, '^gradle-(\d+)\.(\d+)(?:\.(\d+))?')
      $ver = @(-1,-1,-1)
      if ($m.Success) {
        $patch = 0; try { $patch = [int]$m.Groups[3].Value } catch { $patch = 0 }
        $ver = @([int]$m.Groups[1].Value, [int]$m.Groups[2].Value, $patch)
      }
      if ($null -eq $bestVer) { $bestVer = $ver; $best = $bat; continue }
      for ($i=0; $i -lt 3; $i++) {
        if ($ver[$i] -gt $bestVer[$i]) { $bestVer = $ver; $best = $bat; break }
        if ($ver[$i] -lt $bestVer[$i]) { break }
      }
    }
  }
  return $best
}

function Get-GradleCmdRaw() {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $tc  = Try-ReadJson (Join-Path $CiRoot "run\toolchain.state.json")
  $root = Get-GradleProjectRoot
  if (Wrapper-Ok $root) { return @{ mode="wrapper"; cmd=(Join-Path $root "gradlew.bat"); root=$root } }
  $toolchain = Get-Prop $cfg "toolchain" $null
  $pinned = Get-Prop $toolchain "gradle_cmd" $null
  if ($pinned -and (Test-Path ([string]$pinned))) { return @{ mode="pinned"; cmd=[string]$pinned } }
  $gradleState = Get-Prop $tc "gradle" $null
  $prev = Get-Prop $gradleState "cmd" $null
  if ($prev -and (Test-Path ([string]$prev))) { return @{ mode=(Get-Prop $gradleState "mode" "unknown"); cmd=[string]$prev } }
  $local = Find-LocalGradleDistCmd
  if ($local) { return @{ mode="local-dist"; cmd=$local } }
  $g = Get-Command gradle -ErrorAction SilentlyContinue
  if ($g) { return @{ mode="path"; cmd="gradle" } }
  return @{ mode="unknown"; cmd=$null; root=(Get-GradleProjectRoot) }
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
