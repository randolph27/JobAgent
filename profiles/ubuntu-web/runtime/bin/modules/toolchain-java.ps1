function Parse-JavaMajor([string]$text) {
  if (-not $text) { return $null }
  $m = [regex]::Match($text, 'version\s+\"(\d+)(?:\.(\d+))?')
  if (-not $m.Success) { return $null }
  if ($m.Groups[1].Value -eq "1" -and $m.Groups[2].Success) { return [int]$m.Groups[2].Value }
  return [int]$m.Groups[1].Value
}

function Get-JavaVersionText() {
  try { return (& java -version 2>&1 | Out-String).Trim() } catch { return $null }
}

function Get-JavaVersionTextFor([string]$javaExe) {
  try { return (& $javaExe -version 2>&1 | Out-String).Trim() } catch { return $null }
}

function Get-JdkHomeFromJavaExe([string]$javaExe) {
  if (-not $javaExe) { return $null }
  try {
    $p = (Resolve-Path -LiteralPath $javaExe -ErrorAction Stop).Path
    $bin = Split-Path -Parent $p
    $jdkHome = Split-Path -Parent $bin
    if (Test-Path -LiteralPath (Join-Path $jdkHome "bin\java.exe")) { return $jdkHome }
  } catch { $null = $_ }
  return $null
}

function Get-JavaHomesFromRegistryKey([string]$keyPath) {
  $out = New-Object System.Collections.Generic.List[string]
  try {
    if (Test-Path -Path $keyPath) {
      try {
        $cv = (Get-ItemProperty -Path $keyPath -Name CurrentVersion -ErrorAction SilentlyContinue).CurrentVersion
        if ($cv) {
          $sub = Join-Path $keyPath $cv
          $jh = (Get-ItemProperty -Path $sub -Name JavaHome -ErrorAction SilentlyContinue).JavaHome
          if ($jh) { $out.Add([string]$jh) }
        }
      } catch { $null = $_ }
      try {
        Get-ChildItem -Path $keyPath -ErrorAction SilentlyContinue | ForEach-Object {
          $jh = (Get-ItemProperty -Path $_.PSPath -Name JavaHome -ErrorAction SilentlyContinue).JavaHome
          if ($jh) { $out.Add([string]$jh) }
        }
      } catch { $null = $_ }
    }
  } catch { $null = $_ }
  return @($out | Select-Object -Unique)
}

function Get-CommonJdkHomes() {
  $out = New-Object System.Collections.Generic.List[string]
  $roots = @()
  if ($env:ProgramFiles) { $roots += $env:ProgramFiles }
  try { if (${env:ProgramFiles(x86)}) { $roots += ${env:ProgramFiles(x86)} } } catch { $null = $_ }
  $patterns = @("Java\jdk*", "Java\jre*", "Eclipse Adoptium\jdk*", "Adoptium\jdk*", "Temurin\jdk*", "Microsoft\jdk-*", "Amazon Corretto\jdk*", "Zulu\zulu-*", "BellSoft\LibericaJDK*", "SapMachine\jdk*", "OpenJDK\*", "OpenLogic\*", "RedHat\*", "IBM\Semeru\*")
  foreach ($r in $roots) {
    foreach ($pat in $patterns) {
      $parent = Split-Path $pat -Parent
      $leaf = Split-Path $pat -Leaf
      $dir = Join-Path $r $parent
      if (-not (Test-Path -LiteralPath $dir)) { continue }
      try {
        Get-ChildItem -LiteralPath $dir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like $leaf } | ForEach-Object {
          $jdkHome = $_.FullName
          if (Test-Path -LiteralPath (Join-Path $jdkHome "bin\java.exe")) { $out.Add($jdkHome) }
        }
      } catch { $null = $_ }
    }
  }
  return @($out | Select-Object -Unique)
}

function Find-LocalJdkHome() {
  $roots = @((Join-Path $CiRoot "tools")) | Select-Object -Unique
  $candidates = New-Object System.Collections.Generic.List[object]
  foreach ($r in $roots) {
    if (-not (Test-Path -LiteralPath $r)) { continue }
    $dirs = Get-ChildItem -LiteralPath $r -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(jdk|temurin|zulu|corretto|openjdk)[-_]?\d+' }
    foreach ($d in $dirs) {
      $javaExe = Join-Path $d.FullName "bin\java.exe"
      if (-not (Test-Path -LiteralPath $javaExe)) { continue }
      $m = [regex]::Match($d.Name, '(\d{1,2})')
      $maj = 0; if ($m.Success) { $maj = [int]$m.Groups[1].Value }
      $candidates.Add(@{ jdkHome=$d.FullName; major=$maj })
    }
  }
  if ($candidates.Count -eq 0) { return $null }
  return ($candidates | Sort-Object major -Descending | Select-Object -First 1).jdkHome
}

function Read-ToolchainPins() {
  $p = Join-Path $RepoRoot "toolchain.pins.md"
  $pins = @{ java=$null; gradle=$null; node=$null }
  if (-not (Test-Path -LiteralPath $p)) { return $pins }
  $t = Get-Content -LiteralPath $p -Raw
  foreach ($k in @("java","gradle","node")) {
    $m = [regex]::Match($t, "(?im)^\s*-\s*$k\s*:\s*([0-9][0-9\.]*)\s*$")
    if ($m.Success) { $pins[$k] = $m.Groups[1].Value.Trim() }
  }
  return $pins
}

function Get-JavaMinMajor() {
  $cfg = Try-ReadJson (Get-ConfigPath)
  $tc = Get-Prop $cfg "toolchain" $null
  $min = Get-Prop $tc "java_min_major" 17
  try { return [int]$min } catch { return 17 }
}

function Get-JavaTargetMajor() {
  $pins = Read-ToolchainPins
  if ($pins.java) { try { return [int]$pins.java } catch { $null = $_ } }
  return (Get-JavaMinMajor)
}

function Select-JdkHomeForTarget([string[]]$homes, [int]$targetMajor) {
  $cands = New-Object System.Collections.Generic.List[object]
  foreach ($h in @($homes | Select-Object -Unique)) {
    if (-not $h) { continue }
    $javaExe = Join-Path $h "bin\java.exe"
    if (-not (Test-Path -LiteralPath $javaExe)) { continue }
    $txt = Get-JavaVersionTextFor $javaExe
    $maj = Parse-JavaMajor $txt
    if ($maj) { $cands.Add(@{ jdkHome=$h; major=$maj; txt=$txt }) }
  }
  if ($cands.Count -eq 0) { return @{ jdkHome=$null; major=$null; txt=$null } }
  $exact = $cands | Where-Object { $_.major -eq $targetMajor } | Select-Object -First 1
  if ($exact) { return $exact }
  $above = $cands | Where-Object { $_.major -gt $targetMajor } | Sort-Object major | Select-Object -First 1
  if ($above) { return $above }
  $below = $cands | Where-Object { $_.major -lt $targetMajor } | Sort-Object major -Descending | Select-Object -First 1
  if ($below) { return $below }
  return ($cands | Sort-Object major | Select-Object -First 1)
}

function Ensure-JavaReady() {
  $min = Get-JavaMinMajor
  $target = Get-JavaTargetMajor
  if ($target -lt $min) { $target = $min }
  $script:JavaSelection = $null
  try {
    $cmdPosix = Get-Command java -ErrorAction SilentlyContinue
    if ($cmdPosix -and $cmdPosix.Source -and -not ($cmdPosix.Source -like "*.exe")) {
      $majPosix = Parse-JavaMajor (Get-JavaVersionText)
      if ($majPosix -ge $min) {
        $script:JavaSelection = @{ source="path-posix"; target_major=$target; min_major=$min; major=$majPosix; jdkHome=$null; java_version_text=Get-JavaVersionText }
        return @{}
      }
    }
  } catch { $null = $_ }

  $homes = New-Object System.Collections.Generic.List[string]
  $pathTxt = Get-JavaVersionText
  $pathMaj = Parse-JavaMajor $pathTxt
  $pathJdkHome = $null
  try {
    $cmd = Get-Command java -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { $pathJdkHome = Get-JdkHomeFromJavaExe $cmd.Source }
  } catch { $null = $_ }
  if ($pathJdkHome -and (Test-Path -LiteralPath (Join-Path $pathJdkHome "bin\java.exe"))) { $homes.Add($pathJdkHome) }
  try { if ($env:JAVA_HOME) { $jh = [string]$env:JAVA_HOME; if (Test-Path (Join-Path $jh "bin\java.exe")) { $homes.Add($jh) } } } catch { $null = $_ }
  foreach ($k in @("HKLM:\SOFTWARE\JavaSoft\JDK", "HKLM:\SOFTWARE\WOW6432Node\JavaSoft\JDK", "HKCU:\SOFTWARE\JavaSoft\JDK", "HKCU:\SOFTWARE\WOW6432Node\JavaSoft\JDK")) {
    foreach ($h in (Get-JavaHomesFromRegistryKey $k)) { if ($h) { $homes.Add($h) } }
  }
  foreach ($h in (Get-CommonJdkHomes)) { if ($h) { $homes.Add($h) } }
  $local = Find-LocalJdkHome
  if ($local) { $homes.Add($local) }
  $sel = Select-JdkHomeForTarget @($homes) $target
  $selJdkHome = [string](Get-Prop $sel "jdkHome" $null)
  $selMaj  = Get-Prop $sel "major" $null
  $selTxt  = [string](Get-Prop $sel "txt" $null)
  if ($selJdkHome -and $selMaj) {
    if ([int]$selMaj -lt $min) {
      $script:JavaSelection = @{ source="discovered"; target_major=$target; min_major=$min; major=$selMaj; jdkHome=$selJdkHome; java_version_text=$selTxt }
      throw ("Java too old (need >= " + $min + ", target " + $target + "). Best found: " + $selJdkHome + " (major " + $selMaj + ")")
    }
    $source = "discovered"
    if ($pathJdkHome -and $selJdkHome -eq $pathJdkHome -and $pathMaj -and $pathMaj -eq $selMaj) { $source = "path" }
    elseif ($local -and $selJdkHome -eq $local) { $source = "local" }
    $script:JavaSelection = @{ source=$source; target_major=$target; min_major=$min; major=$selMaj; jdkHome=$selJdkHome; java_version_text=$selTxt }
    if ($source -eq "path") { return [hashtable]@{} }
    CI-Info ("java selection: target=" + $target + " using " + $selJdkHome + " (major " + $selMaj + ")")
    $newPath = (Join-Path $selJdkHome "bin") + ";" + $env:PATH
    return [hashtable]@{ "JAVA_HOME"=$selJdkHome; "PATH"=$newPath }
  }
  $script:JavaSelection = @{ source="missing"; target_major=$target; min_major=$min; major=$pathMaj; jdkHome=$pathJdkHome; java_version_text=$pathTxt }
  throw ("Java missing. Need JDK >= " + $min + " (target " + $target + "). Fix: install JDK, set JAVA_HOME, or place a portable JDK under .ci\tools\ (e.g. .ci\tools\jdk-" + $min + "\bin\java.exe).")
}
