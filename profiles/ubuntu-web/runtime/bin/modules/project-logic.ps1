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
  $commands = @(
    "git -c core.pager=cat -c color.ui=false --no-pager diff --name-only",
    "git -c core.pager=cat -c color.ui=false --no-pager diff --cached --name-only",
    "git -c core.pager=cat -c color.ui=false --no-pager ls-files --others --exclude-standard"
  )
  $paths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  foreach ($command in $commands) {
    $result = Run-Cmd $command $logPath
    if ($result.exit -ne 0) { throw "route-check could not enumerate git changes: $command" }
    foreach ($line in @($result.out -split "`r?`n")) {
      $path = $line.Trim()
      if ($path) { $null = $paths.Add($path) }
    }
  }
  return @($paths | Sort-Object)
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

function Get-GitStatusSnapshot([string]$logPath = $null) {
  $hasRepo = (Test-Path (Join-Path $RepoRoot ".git"))
  if (-not $hasRepo) {
    return @{
      has_repo = $false
      branch = $null
      head = $null
      ahead = 0
      behind = 0
      ahead_behind = "0/0"
      status_short = @()
      changed_files = @()
      log_path = $null
    }
  }

  if (-not $logPath) {
    $logPath = Join-Path $LogsRoot ("terminal\\git-status-" + (TsId) + ".log")
  }

  $statusRes = Run-Cmd "git -c core.pager=cat -c color.ui=false --no-pager status --short --branch --untracked-files=all" $logPath
  $branchRes = Run-Cmd "git -c core.pager=cat -c color.ui=false --no-pager rev-parse --abbrev-ref HEAD" $logPath
  $headRes = Run-Cmd "git -c core.pager=cat -c color.ui=false --no-pager rev-parse HEAD" $logPath
  $ahead = 0
  $behind = 0
  $aheadBehind = "0/0"
  $upstreamRes = Run-Cmd "git -c core.pager=cat -c color.ui=false --no-pager rev-list --left-right --count @{upstream}...HEAD" $logPath
  if ($upstreamRes.exit -eq 0) {
    $text = ([string]$upstreamRes.out).Trim()
    if ($text -match '^(\d+)\s+(\d+)$') {
      $behind = [int]$Matches[1]
      $ahead = [int]$Matches[2]
      $aheadBehind = ($ahead.ToString() + "/" + $behind.ToString())
    }
  }

  $statusLines = @()
  if ($statusRes.exit -eq 0) {
    $statusLines = @($statusRes.out -split "`r?`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ })
  }

  $changed = New-Object System.Collections.Generic.List[string]
  foreach ($line in $statusLines) {
    if ($line.StartsWith("##")) { continue }
    if ($line.Length -lt 4) { continue }
    $pathPart = $line.Substring(3).Trim()
    if (-not $pathPart) { continue }
    if ($pathPart.Contains(" -> ")) {
      $pathPart = $pathPart.Split(@(" -> "), 2, [System.StringSplitOptions]::None)[1]
    }
    $normalized = Normalize-RoutePath $pathPart
    if ($normalized -and -not $changed.Contains($normalized)) {
      $changed.Add($normalized)
    }
  }

  return @{
    has_repo = $true
    branch = $(if ($branchRes.exit -eq 0) { ([string]$branchRes.out).Trim() } else { $null })
    head = $(if ($headRes.exit -eq 0) { ([string]$headRes.out).Trim() } else { $null })
    ahead = $ahead
    behind = $behind
    ahead_behind = $aheadBehind
    status_short = $statusLines
    changed_files = $changed.ToArray()
    log_path = (To-RelPath $logPath)
  }
}

function New-HandoffMarkdown([object]$handoff) {
  $lines = New-Object System.Collections.Generic.List[string]
  $ts = [string](Get-Prop $handoff "ts" "")
  $status = [string](Get-Prop $handoff "status" "")
  $summary = [string](Get-Prop $handoff "summary" "")
  $activeId = [string](Get-Prop $handoff "active_id" "")
  $stopReason = [string](Get-Prop $handoff "stop_reason" "")
  $capsule = Get-Prop $handoff "capsule" $null
  $git = Get-Prop $handoff "git" $null

  $lines.Add("# STP Handoff " + $ts)
  $lines.Add("")
  if ($summary) { $lines.Add($summary); $lines.Add("") }
  $lines.Add("## Status")
  $lines.Add("")
  if ($activeId) { $lines.Add('- active_id: `' + $activeId + '`') }
  if ($status) { $lines.Add('- status: `' + $status + '`') }
  if ($stopReason) { $lines.Add('- stop_reason: `' + $stopReason + '`') }
  if ($git) {
    $branch = [string](Get-Prop $git "branch" "")
    $head = [string](Get-Prop $git "head" "")
    $aheadBehind = [string](Get-Prop $git "ahead_behind" "")
    if ($branch) { $lines.Add('- branch: `' + $branch + '`') }
    if ($head) { $lines.Add('- head: `' + $head + '`') }
    if ($aheadBehind) { $lines.Add('- ahead_behind: `' + $aheadBehind + '`') }
  }

  $nextSteps = @(Get-Prop $handoff "next_steps" @())
  if ($nextSteps.Count -gt 0) {
    $lines.Add("")
    $lines.Add("## Next")
    $lines.Add("")
    foreach ($step in $nextSteps) {
      $text = [string]$step
      if ($text) { $lines.Add("- " + $text) }
    }
  }

  $refs = @(Get-Prop $handoff "refs" @())
  if ($refs.Count -gt 0) {
    $lines.Add("")
    $lines.Add("## Refs")
    $lines.Add("")
    foreach ($ref in $refs) {
      $text = [string]$ref
      if ($text) { $lines.Add("- " + $text) }
    }
  }

  if ($capsule) {
    $lines.Add("")
    $lines.Add("## CAPSULE")
    $lines.Add("")
    $lines.Add('```json')
    $lines.Add((To-Json $capsule))
    $lines.Add('```')
  }

  return ($lines -join "`r`n")
}

function Write-HandoffArtifacts([object]$handoff) {
  $jsonPath = Join-Path $RepoRoot "handoff.latest.json"
  $mdPath = Join-Path $RepoRoot "handoff.latest.md"
  Write-Json $jsonPath $handoff
  Atomic-WriteTextUtf8 $mdPath (New-HandoffMarkdown $handoff)
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
  if ($hasGit) { $changed = @(Try-GitDiffNames $logPath) }

  $rules = Read-PolicyRules
  $noTouch = @(); $forbidPath = @(); $forbidRegex = @()
  try { $noTouch = @($rules.no_touch) } catch { $noTouch = @() }
  try { $forbidPath = @($rules.forbid_path) } catch { $forbidPath = @() }
  try { $forbidRegex = @($rules.forbid_regex) } catch { $forbidRegex = @() }

  $violations = New-Object System.Collections.Generic.List[object]
  foreach ($c in @($changed)) {
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

  $routeOk = ($violations.Count -eq 0)
  $changedCount = @($changed).Count
  $payload = @{ ts=(NowIso); agent_id=(Get-AgentId); mode=$mode; route_ok=$routeOk; changed_count=$changedCount; changed_files=@($changed); violations=$violations.ToArray(); policy=@{ no_touch=@($noTouch); forbid_path=@($forbidPath); forbid_regex=@($forbidRegex) }; git=@{ has_repo=$hasGit; diff_log=(To-RelPath $logPath) } }
  Write-Json (Join-Path $CiRoot "run\route.check.json") $payload

  if (-not $routeOk) {
    $msg = "route-check failed: " + $violations.Count + " violation(s)"
    CI-Info $msg
    throw $msg
  }
  CI-Info ("route-check: ok (changed=" + $changedCount + ")")
}
