function Write-VerifyDigest([object]$digest) { Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") $digest }
function Write-Failbundle([object]$bundle)  { Write-Json (Join-Path $LogsRoot "verify\failbundle-latest.json") $bundle }

function Get-VerifyStatePath() { Join-Path $CiRoot "run\verify.state.json" }
function Get-LoopGuardPath()  { Join-Path $CiRoot "run\loop.guard.json" }

function Load-VerifyState() {
  $p = Get-VerifyStatePath
  $s = Try-ReadJson $p
  if ($null -eq $s) { return @{ last_ts=$null; last_cmd=$null; last_exit=0; last_log_path=$null; fail_signature=$null; fail_streak=0; escalation_level=0 } }
  return $s
}

function Save-VerifyState([object]$s) { Write-Json (Get-VerifyStatePath) $s }

function Load-LoopGuard() {
  $p = Get-LoopGuardPath
  $g = Try-ReadJson $p
  if ($null -eq $g) { return @{ last_ts=$null; last_cmd=$null; last_fail_signature=$null; repeat_count=0 } }
  return $g
}

function Save-LoopGuard([object]$g) { Write-Json (Get-LoopGuardPath) $g }

function Compute-FailSignature([string]$logPath) {
  $tail = (Tail-File $logPath 80) -join "`n"
  if (-not $tail) { return $null }
  return "FSIG-" + (Sha256Text $tail).Substring(0,16)
}

function Update-LoopGuard([string]$cmdName, [string]$failSig) {
  $g = Load-LoopGuard
  $lastCmd = [string](Get-Prop $g "last_cmd" $null)
  $lastSig = [string](Get-Prop $g "last_fail_signature" $null)
  $rep = [int](Get-Prop $g "repeat_count" 0)
  if ($failSig -and $lastCmd -eq $cmdName -and $lastSig -eq $failSig) { $rep = $rep + 1 } else { $rep = 0 }
  Set-ObjProp $g "last_ts" (NowIso)
  $g.last_cmd = $cmdName
  Set-ObjProp $g "last_fail_signature" $failSig
  Set-ObjProp $g "repeat_count" $rep
  Save-LoopGuard $g
  return $rep
}

function Invoke-SelfCheck([string]$logPath=$null) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $issues = New-Object System.Collections.Generic.List[string]
  $lines  = New-Object System.Collections.Generic.List[string]
  $lines.Add("UNIVERSAL CI SELF-CHECK")
  $lines.Add("ts: " + (NowIso))
  $lines.Add("repo: " + $RepoRoot)
  $lines.Add("agent_id: " + (Get-AgentId))
  $lines.Add("")
  $req = @("README.md", "handoff.latest.json", "handoff.latest.md", "todo.state.json", "todo.events.jsonl", "todo.current.md", "todo.master.index.json", "todo.history.digest.json", ".ci\ci.config.json", ".ci\run\verify.state.json", ".ci\run\loop.guard.json", ".ci\run\toolchain.state.json", "logs\verify\verify.digest.json", "logs\verify\failbundle-latest.json", "logs\locks\lock-latest.json")
  foreach ($r in $req) { $p = Join-Path $RepoRoot $r; if (-not (Test-Path $p)) { $issues.Add("missing: " + $r) } }
  $jsonReq = @("handoff.latest.json", "todo.state.json", "todo.master.index.json", "todo.history.digest.json", ".ci\ci.config.json", ".ci\run\verify.state.json", ".ci\run\loop.guard.json", ".ci\run\toolchain.state.json", "logs\verify\verify.digest.json", "logs\verify\failbundle-latest.json", "logs\locks\lock-latest.json")
  foreach ($r in $jsonReq) { $p = Join-Path $RepoRoot $r; if (Test-Path $p) { $j = Try-ReadJson $p; if ($null -eq $j) { $issues.Add("json_corrupt_or_unreadable: " + $r) } } }
  if ([string]$env:CI_BOOTSTRAP_PREVERIFIED -eq "1") {
    $lines.Add("immutable_runtime: central-preverified")
  } else {
    try {
      $pinsPath = Get-ImmutablePinsPath
      if (-not (Test-Path $pinsPath)) { $issues.Add("immutable_pins_missing: .ci\pins\immutable.hashes.json") }
      else {
        $pins = Read-ImmutablePins
        $files = @(Get-Prop $pins "files" @())
        foreach ($f in $files) {
          $rel = [string](Get-Prop $f "path" ""); if (-not $rel) { continue }
          $p = Join-Path $RepoRoot $rel; if (-not (Test-Path $p)) { $issues.Add("immutable_missing: " + $rel); continue }
          $exp = [string](Get-Prop $f "sha256" ""); $act = Sha256Path $p
          if ($exp -and $act -and ($exp.ToLowerInvariant() -ne $act.ToLowerInvariant())) { $issues.Add("immutable_modified: " + $rel) }
          try { if (-not (Get-Item -LiteralPath $p -Force).IsReadOnly) { $issues.Add("immutable_not_readonly: " + $rel) } } catch { $null = $_ }
        }
      }
    } catch { $issues.Add("immutable_check_error: " + $_.Exception.Message) }
  }
  $st = Try-ReadJson (Join-Path $RepoRoot "todo.state.json")
  if ($null -ne $st) {
    $items = @(); try { $items = @($st.items) } catch { $items = @() }
    $active = Get-Prop $st "active_id" $null
    $inProgress = 0
    $ids = @{}
    $activeFound = $false
    foreach ($it in $items) {
      $id = [string](Get-Prop $it "todo_id" "")
      $status = [string](Get-Prop $it "status" "open")
      if (-not $id) { $issues.Add("todo_invariant: item without todo_id"); continue }
      if ($ids.ContainsKey($id)) { $issues.Add("todo_invariant: duplicate todo_id (" + $id + ")") } else { $ids[$id] = $true }
      if ($status -eq "done") { $issues.Add("todo_invariant: done item remains in active state (" + $id + ")") }
      if ($status -eq "in-progress") { $inProgress++ }
      if ($active -and $id -eq [string]$active) { $activeFound = $true }
    }
    if ($inProgress -gt 1) { $issues.Add("todo_invariant: more than one item in-progress (" + $inProgress + ")") }
    if ($active -and -not $activeFound) { $issues.Add("todo_invariant: active_id not found in items (" + $active + ")") }
    if (-not $active -and $inProgress -gt 0) { $issues.Add("todo_invariant: in-progress item without active_id") }
    $currentPath = Join-Path $RepoRoot "todo.current.md"
    if (Test-Path -LiteralPath $currentPath) {
      $expectedCurrent = Render-TodoCurrent $st
      $actualCurrent = Get-Content -Raw -LiteralPath $currentPath
      if ($actualCurrent -ne $expectedCurrent) { $issues.Add("todo_invariant: todo.current.md differs from todo.state.json") }
    }
  }
  $index = Try-ReadJson (Join-Path $RepoRoot "todo.master.index.json")
  if ($null -ne $index) {
    $indexIds = @{}
    $indexInProgress = 0
    foreach ($row in @(Get-Prop $index "todos" @())) {
      $id = [string](Get-Prop $row "todo_id" "")
      if (-not $id) { $issues.Add("todo_index_invariant: row without todo_id"); continue }
      if ($indexIds.ContainsKey($id)) { $issues.Add("todo_index_invariant: duplicate todo_id (" + $id + ")") } else { $indexIds[$id] = $true }
      if ([string](Get-Prop $row "last_status" "") -eq "in-progress") { $indexInProgress++ }
    }
    if ($indexInProgress -gt 1) { $issues.Add("todo_index_invariant: more than one item in-progress (" + $indexInProgress + ")") }
  }
  $eventsPath = Join-Path $RepoRoot "todo.events.jsonl"
  if (Test-Path -LiteralPath $eventsPath) {
    $eventLine = 0
    foreach ($rawLine in (Get-Content -LiteralPath $eventsPath -ErrorAction SilentlyContinue)) {
      $eventLine++
      if (-not $rawLine) { continue }
      try {
        $event = $rawLine | ConvertFrom-Json -ErrorAction Stop
        foreach ($field in @("ts","event_id","todo_id","type","status","prio","source","msg","refs","changed","verified","git")) {
          if ($null -eq $event.PSObject.Properties[$field]) { $issues.Add("todo_event_invariant: line " + $eventLine + " missing " + $field) }
        }
      } catch { $issues.Add("todo_event_invariant: invalid JSON at line " + $eventLine) }
    }
  }
  $checkpointPath = Join-Path $RepoRoot "todo.checkpoint.json"
  if (Test-Path -LiteralPath $checkpointPath) {
    $checkpoint = Try-ReadJson $checkpointPath
    if ($null -ne $checkpoint) {
      $checkpointState = Get-Prop $checkpoint "state" $null
      if ($null -eq $checkpointState -and $null -eq (Get-Prop $checkpoint "items" $null)) { $issues.Add("todo_checkpoint_invariant: unsupported schema") }
      if ($null -ne $checkpointState -and [string](Get-Prop $checkpoint "schema" "") -ne "todo-checkpoint-v2") { $issues.Add("todo_checkpoint_invariant: wrapped checkpoint lacks v2 schema") }
      if ($null -ne $checkpointState -and [string](Get-Prop $checkpoint "schema" "") -eq "todo-checkpoint-v2" -and $null -ne $st) {
        $checkpointLogical = Normalize-TodoState $checkpointState $true | ConvertTo-Json -Compress -Depth 30
        $stateLogical = Normalize-TodoState $st $true | ConvertTo-Json -Compress -Depth 30
        if ($checkpointLogical -ne $stateLogical) { $issues.Add("todo_checkpoint_invariant: checkpoint state differs from current state") }
      }
    }
  }
  $handoff = Try-ReadJson (Join-Path $RepoRoot "handoff.latest.json")
  $handoffMdPath = Join-Path $RepoRoot "handoff.latest.md"
  if ($null -ne $handoff -and (Test-Path -LiteralPath $handoffMdPath)) {
    $git = Get-Prop $handoff "git" $null
    $capsule = Get-Prop $handoff "capsule" $null
    if ($null -eq $git) { $issues.Add("handoff_invariant: git snapshot missing") }
    else {
      foreach ($field in @("branch","head","upstream","ahead","behind","worktree","tracked_changes")) {
        if ($null -eq $git.PSObject.Properties[$field]) { $issues.Add("handoff_invariant: git." + $field + " missing") }
      }
    }
    if ($null -eq $capsule) { $issues.Add("handoff_invariant: capsule missing") }
    else {
      foreach ($field in @("active_id","status","goal","next","route_ok")) {
        if ([string](Get-Prop $handoff $field "") -ne [string](Get-Prop $capsule $field "")) { $issues.Add("handoff_invariant: capsule mismatch for " + $field) }
      }
    }
    if ($null -ne $st) {
      $stateActive = [string](Get-Prop $st "active_id" "")
      if ([string](Get-Prop $handoff "active_id" "") -ne $stateActive) { $issues.Add("handoff_invariant: active_id differs from todo.state.json") }
      if ($stateActive) {
        $stateStatus = ""
        foreach ($item in @(Get-Prop $st "items" @())) {
          if ([string](Get-Prop $item "todo_id" "") -eq $stateActive) { $stateStatus = [string](Get-Prop $item "status" ""); break }
        }
        if ([string](Get-Prop $handoff "status" "") -ne $stateStatus) { $issues.Add("handoff_invariant: status differs from active todo") }
      }
    }
    $md = Get-Content -Raw -LiteralPath $handoffMdPath
    foreach ($value in @([string](Get-Prop $handoff "active_id" ""), [string](Get-Prop $git "branch" ""), [string](Get-Prop $git "head" ""), [string](Get-Prop $git "worktree" ""))) {
      if ($value -and -not $md.Contains($value)) { $issues.Add("handoff_invariant: markdown parity missing value " + $value) }
    }
    $serialized = ConvertTo-Json $handoff -Compress -Depth 20
    if ($serialized -match '(?i)(authorization\s*[:=]|bearer\s+[a-z0-9._-]+|sq_[a-z0-9_-]{8,}|token["'']?\s*[:=]\s*["''][^"'']{8,})') { $issues.Add("handoff_invariant: possible secret material") }
  }
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json")
  if ($null -ne $vd) {
    $exit = Get-Prop $vd "exit" $null; $lp = [string](Get-Prop $vd "log_path" "")
    if ($exit -eq 0 -and $lp) { $abs = $lp; try { if (-not [System.IO.Path]::IsPathRooted($abs)) { $abs = Join-Path $RepoRoot $lp } } catch { $abs = Join-Path $RepoRoot $lp }; if (-not (Test-Path $abs)) { $lines.Add("warn: verify.digest log_path missing (" + $lp + ")") } }
  }
  if ($issues.Count -eq 0) { $lines.Add("result: OK") } else { $lines.Add("result: FAIL"); $lines.Add(""); $lines.Add("issues:"); foreach ($i in $issues) { $lines.Add("- " + $i) } }
  if ($logPath) { Atomic-WriteTextUtf8 $logPath (($lines -join "`r`n") + "`r`n") }
  return @{ exit = $(if ($issues.Count -eq 0) { 0 } else { 1 }); issues=@($issues); report=@($lines) }
}

function Cmd-SelfCheck() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $ts = TsId; $logPath = Join-Path $LogsRoot ("terminal\self-check-" + $ts + ".log"); $sc = Invoke-SelfCheck $logPath
  CI-Info ("self-check: exit=" + $sc.exit + " issues=" + @($sc.issues).Count + " log=" + $logPath)
  if ($sc.exit -ne 0) { throw ("Self-check failed (issues=" + @($sc.issues).Count + "). See log: " + $logPath) }
}

function Cmd-Verify([int]$level) {
  Ensure-CoreFolders; Ensure-BootstrapFiles; CI-Info "verify: init"; $bs = Detect-BuildSystem; $cfg = Try-ReadJson (Get-ConfigPath); $verify = Get-Prop $cfg "verify" $null; $override = Get-Prop $verify "cmd" $null; $ts = TsId; $logPath = Join-Path $LogsRoot ("verify\\verify-$ts.log"); $cmd = $null; $res = $null
  if ($override) {
    $cmd = [string]$override; $envMap = $null; try { $envMap = Get-GradleEnv } catch { $envMap = $null }; $shell = "auto"; try { $shell = [string](Get-Prop $verify "shell" "auto") } catch { $shell = "auto" }
    if ($shell -match '^(?i)powershell$|^(?i)ps$') { $cmd = ("ps: " + $cmd) } elseif ($shell -match '^(?i)cmd$') { $cmd = ("cmd: " + $cmd) }
    CI-Info ("verify: cmd=" + $cmd + " | log=" + $logPath); Write-VerifyDigest @{ ts=NowIso; cmd=$cmd; exit=$null; status="running"; log_path=$logPath }; $res = Run-Cmd $cmd $logPath $envMap
    $blob = ([string]$res.err + "`n" + [string]$res.out)
    if ($res.exit -ne 0 -and $bs -eq "gradle" -and $blob -match '(?i)(The term ''if'' is not recognized|Die Benennung "if")') {
      CI-Warn "verify override failed due to shell mismatch; falling back to default Gradle verify"; $extra = ""; if ($level -ge 1) { $extra = "--stacktrace" }; if ($level -ge 2) { $extra = "--stacktrace --info" }
      $g = Get-GradleCmdRaw; if (-not $g.cmd) { throw "Gradle project detected, but no Gradle command found." }; Persist-GradleInfo $g.mode $g.cmd; $cmd = ((Quote-IfNeeded $g.cmd) + " check --console=plain " + $extra).Trim(); $envMap = Get-GradleEnv; CI-Info ("verify: cmd=" + $cmd + " | log=" + $logPath); Write-VerifyDigest @{ ts=NowIso; cmd=$cmd; exit=$null; status="running"; log_path=$logPath }; $res = Run-Cmd $cmd $logPath $envMap
    }
  } elseif ($bs -eq "gradle") {
    try { Ensure-GradleWrapper } catch { CI-Info ("verify note: " + $_.Exception.Message) }; $extra = ""; if ($level -eq 1) { $extra = "--stacktrace" } elseif ($level -eq 2) { $extra = "--stacktrace --info" }
    $g = Get-GradleCmdRaw; if (-not $g.cmd) { throw "Gradle project detected, but no Gradle command found." }; Persist-GradleInfo $g.mode $g.cmd; $cmd = ((Quote-IfNeeded $g.cmd) + " check --console=plain " + $extra).Trim(); $envMap = Get-GradleEnv; CI-Info ("verify: cmd=" + $cmd + " | log=" + $logPath); Write-VerifyDigest @{ ts=NowIso; cmd=$cmd; exit=$null; status="running"; log_path=$logPath }; $res = Run-Cmd $cmd $logPath $envMap
  } elseif ($bs -eq "node") {
    $cmd = "npm run lint && npm run typecheck && npm run build && npm run test:functions"
    CI-Info ("verify: cmd=" + $cmd + " | log=" + $logPath)
    Write-VerifyDigest @{ ts=NowIso; cmd=$cmd; exit=$null; status="running"; log_path=$logPath }
    $res = Run-Cmd $cmd $logPath
  } else {
    $cmd = "self-check"
    $sc = Invoke-SelfCheck $logPath
    $res = @{ exit=$sc.exit; out=""; err="" }
  }
  $sig = $null; if ($res.exit -ne 0) { $sig = Compute-FailSignature $logPath }; $st = Load-VerifyState; $prevSig = [string](Get-Prop $st "fail_signature" $null); $prevStreak = [int](Get-Prop $st "fail_streak" 0); $streak = 0
  if ($res.exit -ne 0) { if ($sig -and $prevSig -and $sig -eq $prevSig) { $streak = $prevStreak + 1 } else { $streak = 1 } } else { $streak = 0 }
  Set-ObjProp $st "last_ts" (NowIso); Set-ObjProp $st "last_cmd" $cmd; Set-ObjProp $st "last_exit" $res.exit; Set-ObjProp $st "last_log_path" $logPath; Set-ObjProp $st "fail_signature" $sig; Set-ObjProp $st "fail_streak" $streak; Set-ObjProp $st "escalation_level" $level; Save-VerifyState $st
  Write-VerifyDigest @{ ts=NowIso; cmd=$cmd; exit=$res.exit; fail_signature=$sig; fail_streak=$streak; escalation_level=$level; log_path=$logPath }; Write-Failbundle @{ ts=NowIso; cmd=$cmd; exit=$res.exit; fail_signature=$sig; fail_streak=$streak; escalation_level=$level; reason=$null; tail=(Tail-File $logPath 120); log_path=$logPath }; $rep = Update-LoopGuard $cmd $sig; CI-Info ("verify: exit=" + $res.exit + " fail_signature=" + $(if ($sig) { $sig } else { "null" }) + " fail_streak=" + $streak + " log=" + $logPath)
  if ($res.exit -ne 0) { CI-Info "verify tail (last 30):"; (Tail-File $logPath 30) | ForEach-Object { Write-Host $_ }; if ($rep -ge 2) { throw ("Loop-Guard: repeated failure signature for the same command (" + $sig + "). Stop retrying. Next: run #ci lock-triage if lock evidence, otherwise inspect logs/verify/failbundle-latest.json and then #ci stp.") }; throw ("Verify failed: exit=" + $res.exit + " log=" + $logPath + $(if ($sig) { " fail_signature=" + $sig } else { "" })) }
}

function Cmd-GradleAutopsy() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; if (Detect-BuildSystem -ne "gradle") { Cmd-Verify 0; return }; Cmd-Preflight; $last = $null
  for ($lvl=0; $lvl -le 2; $lvl++) { try { Cmd-Verify $lvl; return } catch { $last = $_.Exception.Message } }
  throw ("Gradle autopsy exhausted (level 2). Last: " + $last)
}

function Cmd-LockTriage() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $now = NowIso; $ts = TsId; $suspected = New-Object System.Collections.Generic.List[string]; $fb = Try-ReadJson (Join-Path $LogsRoot "verify\failbundle-latest.json"); $tail = Get-Prop $fb "tail" @()
  foreach ($l in $tail) { if ($l -match '(?i)(FileSystemException|Access is denied|used by another process|cannot access the file|Failed to delete)') { $m = [regex]::Match($l, '([A-Za-z]:\\[^ \t\r\n"]+)'); if ($m.Success) { $suspected.Add($m.Groups[1].Value) } } }
  $suspectedPaths = @($suspected | Select-Object -Unique | Select-Object -First 5); $javaWhere = @(); try { $javaWhere = (& where.exe java 2>$null) } catch { $javaWhere = @() }; $javaVer = ""; try { $javaVer = (& java -version 2>&1 | Out-String).Trim() } catch { $javaVer = "" }; $procs = @()
  try { $raw = Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -in @("java.exe","javaw.exe","gradle.exe") }; foreach ($p in $raw) { $procs += @{ pid=$p.ProcessId; name=$p.Name; parent_pid=$p.ParentProcessId; command_line=$p.CommandLine } } } catch { $procs = @() }
  $payload = @{ ts=$now; suspected_paths=$suspectedPaths; processes=$procs; java=@{ where=$javaWhere; version=$javaVer }; notes=@("evidence-only") }; Write-Json (Join-Path $LogsRoot "locks\lock-latest.json") $payload; Write-Json (Join-Path $LogsRoot ("locks\lock-" + $ts + ".json")) $payload
}

function Cmd-Preflight() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $bs = Detect-BuildSystem; CI-Info ("preflight: build_system=" + $bs)
  if ($bs -eq "gradle") {
    try { Ensure-GradleWrapper } catch { CI-Info ("preflight note: " + $_.Exception.Message) }; $g = Get-GradleCmdRaw
    if ($g.cmd) { Persist-GradleInfo $g.mode $g.cmd; $log = Join-Path $LogsRoot ("terminal\preflight-" + (TsId) + ".log"); $envMap = Get-GradleEnv; $res = Run-Cmd ((Quote-IfNeeded $g.cmd) + " --stop") $log $envMap; CI-Info ("preflight: gradle --stop exit=" + $res.exit + " log=" + $log) }
    else { CI-Info ("preflight: gradle cmd not found (run deps-bootstrap or provide wrapper/gradle).") }
  }
}

