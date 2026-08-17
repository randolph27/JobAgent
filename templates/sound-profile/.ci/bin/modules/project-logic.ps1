function Update-ManualDigest() {
  $digestPath = Join-Path $CiRoot "run\manual.digest.json"
  $manualDir = Join-Path $RepoRoot "manual"
  $candidates = New-Object System.Collections.Generic.List[string]

  $prio = @(
    (Join-Path $manualDir "summary.md"),
    (Join-Path $manualDir "index.md"),
    (Join-Path $manualDir "PROGRAM.md"),
    (Join-Path $RepoRoot "manual.md")
  )
  foreach ($p in $prio) { if ($p -and (Test-Path -LiteralPath $p)) { $candidates.Add($p) } }

  if ((Test-Path -LiteralPath $manualDir)) {
    $more = Get-ChildItem -LiteralPath $manualDir -Filter "*.md" -File -ErrorAction SilentlyContinue | Sort-Object FullName
    foreach ($f in $more) {
      if ($candidates.Contains($f.FullName)) { continue }
      if ($f.Length -le 200kb) { $candidates.Add($f.FullName) }
      if ($candidates.Count -ge 3) { break }
    }
  }

  if ($candidates.Count -eq 0) { return }

  $files = @()
  foreach ($p in $candidates) {
    try {
      $fi = Get-Item -LiteralPath $p -ErrorAction Stop
      if ($fi.Length -gt 200kb) { continue }
      $files += @{
        path   = (To-RelPath $fi.FullName)
        size   = [int64]$fi.Length
        mtime  = ($fi.LastWriteTimeUtc.ToString("o"))
        sha256 = (Sha256Path $fi.FullName)
      }
    } catch { $null = $_ }
    if (@($files).Count -ge 3) { break }
  }

  if (@($files).Count -eq 0) { return }

  $new = @{ ts=(NowIso); files=$files } | ConvertTo-Json -Compress

  try {
    if (Test-Path -LiteralPath $digestPath) {
      $old = (Get-Content -LiteralPath $digestPath -Raw -ErrorAction SilentlyContinue).Trim()
      if ($old -eq $new) { return }
    }
  } catch { $null = $_ }

  Atomic-WriteTextUtf8 $digestPath $new
}

function Update-EnvInventoryDigest() {
  $digestPath = Join-Path $CiRoot "run\env_inventory.digest.json"
  $invPath = Join-Path $RepoRoot "env-inventory.snapshot.md"
  if (-not (Test-Path -LiteralPath $invPath)) { return }

  try {
    $fi = Get-Item -LiteralPath $invPath -ErrorAction Stop
    $new = @{ ts=(NowIso); path=(To-RelPath $fi.FullName); size=[int64]$fi.Length; mtime=($fi.LastWriteTimeUtc.ToString("o")); sha256=(Sha256Path $fi.FullName) } |
      ConvertTo-Json -Compress
    if (Test-Path -LiteralPath $digestPath) {
      $old = (Get-Content -LiteralPath $digestPath -Raw -ErrorAction SilentlyContinue).Trim()
      if ($old -eq $new) { return }
    }
    Atomic-WriteTextUtf8 $digestPath $new
  } catch { $null = $_ }
}

function Ensure-ProjectStubs() {
  $readme = Join-Path $RepoRoot "README.md"
  $roadmap = Join-Path $RepoRoot "Roadmap.md"
  $manualDir = Join-Path $RepoRoot "manual"
  $program = Join-Path $manualDir "PROGRAM.md"

  if (-not (Test-Path -LiteralPath $manualDir)) { Ensure-Dir $manualDir }

  if (-not (Test-Path -LiteralPath $readme)) {
    $t = New-Object System.Collections.Generic.List[string]
    $t.Add("# Project")
    $t.Add("")
    $t.Add("## CI")
    $t.Add("")
    $t.Add('- Run: `.ci\bin\ci.cmd start` (bootstrap + lock + preflight + doctor)')
    $t.Add('- Menu: `.ci\bin\ci.cmd menu`')
    $t.Add('- Checkpoint: `.ci\bin\ci.cmd stp`')
    $t.Add('- Hard rules: `project.policy.hard.md`')
    $t.Add("")
    $t.Add("## Manual")
    $t.Add("")
    $t.Add('- See: `manual\PROGRAM.md`')
    Atomic-WriteTextUtf8 $readme (($t -join "`r`n") + "`r`n")
  }

  if (-not (Test-Path -LiteralPath $program)) {
    $t = New-Object System.Collections.Generic.List[string]
    $t.Add("# PROGRAM.md")
    $t.Add("")
    $t.Add("Put the project start instruction here (what the agent should build, constraints, acceptance criteria).")
    $t.Add("")
    $t.Add("## Must-haves")
    $t.Add("- Deterministic steps")
    $t.Add("- Minimal external dependencies")
    $t.Add("- Clear done-criteria")
    Atomic-WriteTextUtf8 $program (($t -join "`r`n") + "`r`n")
  }

  if (-not (Test-Path -LiteralPath $roadmap)) {
    $t = New-Object System.Collections.Generic.List[string]
    $t.Add("# Roadmap")
    $t.Add("")
    $t.Add("## Phase 0: Setup")
    $t.Add("- [ ] Define scope and acceptance criteria (manual\\PROGRAM.md)")
    $t.Add("- [ ] Decide build system and pin toolchain (toolchain.pins.md)")
    $t.Add("")
    $t.Add("## Phase 1: Build")
    $t.Add("- [ ] Implement the minimal working skeleton")
    $t.Add("- [ ] Add verification command(s)")
    $t.Add("")
    $t.Add("## Phase 2: Polish")
    $t.Add("- [ ] Documentation")
    $t.Add("- [ ] CI stability")
    Atomic-WriteTextUtf8 $roadmap (($t -join "`r`n") + "`r`n")
  }
}

function Read-PolicyRules() {
  $p = Join-Path $RepoRoot "project.policy.hard.md"
  if (-not (Test-Path $p)) { return @{ no_touch=@(); forbid_path=@(); forbid_regex=@() } }

  $rules = @{ no_touch=@(); forbid_path=@(); forbid_regex=@() }
  $section = ""
  foreach ($line in (Get-Content -LiteralPath $p -ErrorAction SilentlyContinue)) {
    $l = $line.Trim()
    if ($l -match '^(NO_TOUCH|FORBID_PATH|FORBID_REGEX)\s*:\s*$') { $section = $Matches[1].ToLowerInvariant(); continue }
    if ($l -match '^\-\s*(.+)\s*$' -and $section) {
      $v = $Matches[1].Trim()
      if ($v) { $rules[$section] += $v }
    }
  }
  return $rules
}

function Try-GitDiffNames([string]$logPath) {
  if (-not (Test-Path (Join-Path $RepoRoot ".git"))) { return @() }
  $r = Run-Cmd "git -c core.pager=cat -c color.ui=false --no-pager diff --name-only" $logPath
  if ($r.exit -ne 0) { return @() }
  return @($r.out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Try-GitGrepFirst([string]$pattern, [string]$logPath) {
  if (-not (Test-Path (Join-Path $RepoRoot ".git"))) { return $null }
  $cmd = "git -c core.pager=cat -c color.ui=false --no-pager grep -n -E " + (Quote-IfNeeded $pattern) + " --"
  $r = Run-Cmd $cmd $logPath
  if ($r.exit -eq 0) {
    $line = @($r.out -split "`r?`n" | Where-Object { $_ } | Select-Object -First 1)
    if ($line) { return $line }
  }
  return $null
}

function Normalize-RoutePath([string]$p) {
  if (-not $p) { return $p }
  return ($p -replace "\\","/")
}

function Test-RouteRule([string]$path, [string]$rule) {
  if (-not $path -or -not $rule) { return $false }
  $p = (Normalize-RoutePath $path).ToLowerInvariant()
  $r = (Normalize-RoutePath $rule).Trim()
  if (-not $r) { return $false }
  $rLower = $r.ToLowerInvariant()
  if ($rLower -match '[\*\?]') {
    return ($p -like $rLower)
  }
  if ($rLower.EndsWith("/")) {
    $base = $rLower.TrimEnd("/")
    if (-not $base) { return $false }
    return ($p -eq $base -or $p.StartsWith(($base + "/")))
  }
  return ($p -eq $rLower)
}

function Test-MarkdownRenderFiles() {
  $violations = New-Object System.Collections.Generic.List[object]
  $utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)
  $excludedSegments = @(
    ".git",
    ".gradle",
    ".sonarqube",
    "build",
    "node_modules",
    "apk"
  )

  $files = @()
  try {
    $files = Get-ChildItem -LiteralPath $RepoRoot -Recurse -Force -File -Filter "*.md" -ErrorAction Stop |
      Where-Object {
        $rel = Normalize-RoutePath (To-RelPath $_.FullName)
        foreach ($segment in $excludedSegments) {
          if ($rel -eq $segment -or $rel.StartsWith(($segment + "/"), [System.StringComparison]::OrdinalIgnoreCase) -or $rel.Contains(("/" + $segment + "/"))) {
            return $false
          }
        }
        return $true
      }
  } catch {
    $violations.Add(@{ kind="markdown_scan_failed"; path="."; rule="markdown_render_guard"; message=[string]$_.Exception.Message })
    return $violations.ToArray()
  }

  foreach ($file in $files) {
    $rel = Normalize-RoutePath (To-RelPath $file.FullName)
    $bytes = $null
    try {
      $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
      $text = $utf8Strict.GetString($bytes)
    } catch {
      $violations.Add(@{ kind="markdown_invalid_utf8"; path=$rel; rule="markdown_render_guard"; message=[string]$_.Exception.Message })
      if ($violations.Count -ge 30) { return $violations.ToArray() }
      continue
    }

    for ($i = 0; $i -lt $bytes.Length; $i++) {
      $b = [int]$bytes[$i]
      if (($b -lt 32) -and ($b -ne 9) -and ($b -ne 10) -and ($b -ne 13)) {
        $violations.Add(@{
          kind="markdown_control_char"
          path=$rel
          rule="markdown_render_guard"
          offset=$i
          byte=("0x{0:X2}" -f $b)
        })
        if ($violations.Count -ge 30) { return $violations.ToArray() }
      }
    }

    $openFence = $null
    $lines = $text -split "\r\n|\n|\r"
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
      $line = [string]$lines[$lineIndex]
      if ($line -match '^\s*(`{3,}|~{3,})') {
        $marker = [string]$Matches[1]
        $markerChar = $marker.Substring(0, 1)
        $markerLength = $marker.Length
        if ($null -eq $openFence) {
          $openFence = @{ line=($lineIndex + 1); marker=$marker; char=$markerChar; length=$markerLength }
        } elseif ([string](Get-Prop $openFence "char" "") -eq $markerChar -and $markerLength -ge [int](Get-Prop $openFence "length" 3)) {
          $openFence = $null
        }
      }
    }
    if ($null -ne $openFence) {
      $violations.Add(@{
        kind="markdown_unclosed_code_fence"
        path=$rel
        rule="markdown_render_guard"
        line=[int](Get-Prop $openFence "line" 0)
        marker=[string](Get-Prop $openFence "marker" "")
      })
      if ($violations.Count -ge 30) { return $violations.ToArray() }
    }
  }
  return $violations.ToArray()
}

function Cmd-RouteCheck() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath)
  $mode = [string](Get-Prop $cfg "route_check" "standard")
  if ($mode -eq "off") {
    $payload = @{ ts=(NowIso); agent_id=(Get-AgentId); mode=$mode; route_ok=$true; changed_count=0; changed_files=@(); violations=@(); policy=@{ no_touch=@(); forbid_path=@(); forbid_regex=@() }; git=@{ has_repo=(Test-Path (Join-Path $RepoRoot ".git")) } }
    Write-Json (Join-Path $CiRoot "run\route.check.json") $payload
    CI-Info "route-check: off"
    return
  }

  $ts = TsId
  $logPath = Join-Path $LogsRoot ("terminal\\route-check-" + $ts + ".log")
  $hasGit = (Test-Path (Join-Path $RepoRoot ".git"))
  $changed = @()
  if ($hasGit) { $changed = Try-GitDiffNames $logPath }
  $changedList = @($changed)
  $changedCount = $changedList.Count

  $rules = Read-PolicyRules
  $noTouch = @(); $forbidPath = @(); $forbidRegex = @()
  try { $noTouch = @($rules.no_touch) } catch { $noTouch = @() }
  try { $forbidPath = @($rules.forbid_path) } catch { $forbidPath = @() }
  try { $forbidRegex = @($rules.forbid_regex) } catch { $forbidRegex = @() }

  $violations = New-Object System.Collections.Generic.List[object]
  foreach ($c in $changedList) {
    $p = Normalize-RoutePath ([string]$c)
    foreach ($r in $noTouch) {
      if (Test-RouteRule $p ([string]$r)) { $violations.Add(@{ kind="no_touch"; path=$p; rule=[string]$r }) }
    }
    foreach ($r in $forbidPath) {
      if (Test-RouteRule $p ([string]$r)) { $violations.Add(@{ kind="forbid_path"; path=$p; rule=[string]$r }) }
    }
    foreach ($r in $forbidRegex) {
      $rx = [string]$r
      if ($rx -and ($p -match $rx)) { $violations.Add(@{ kind="forbid_regex"; path=$p; rule=$rx }) }
    }
  }

  foreach ($v in (Test-MarkdownRenderFiles)) { $violations.Add($v) }

  $routeOk = ($violations.Count -eq 0)
  $payload = @{ ts=(NowIso); agent_id=(Get-AgentId); mode=$mode; route_ok=$routeOk; changed_count=$changedCount; changed_files=$changedList; violations=$violations.ToArray(); policy=@{ no_touch=@($noTouch); forbid_path=@($forbidPath); forbid_regex=@($forbidRegex) }; git=@{ has_repo=$hasGit; diff_log=(To-RelPath $logPath) } }
  Write-Json (Join-Path $CiRoot "run\route.check.json") $payload

  if (-not $routeOk) {
    $msg = "route-check failed: " + $violations.Count + " violation(s)"
    CI-Info $msg
    throw $msg
  }
  CI-Info ("route-check: ok (changed=" + $changedCount + ")")
}
