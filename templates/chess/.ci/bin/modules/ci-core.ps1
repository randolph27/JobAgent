function Ensure-CoreFolders() {
  Ensure-Dir $CiRoot
  Ensure-Dir (Join-Path $CiRoot "run")
  Ensure-Dir (Join-Path $CiRoot "locks")
  Ensure-Dir (Join-Path $CiRoot "markers")
  Ensure-Dir (Join-Path $CiRoot "patches")
  Ensure-Dir (Join-Path $CiRoot "inbox")
  Ensure-Dir (Join-Path $CiRoot "tools")
  Ensure-Dir (Join-Path $CiRoot "bin")
  Ensure-Dir (Join-Path $CiRoot "pins")
  Ensure-Dir $LogsRoot
  Ensure-Dir (Join-Path $LogsRoot "verify")
  Ensure-Dir (Join-Path $LogsRoot "terminal")
  Ensure-Dir (Join-Path $LogsRoot "locks")
  Ensure-Dir (Join-Path $LogsRoot "todo")
  Ensure-Dir (Join-Path $LogsRoot "handoff")
  Ensure-Dir (Join-Path $LogsRoot "corrupt")
  Ensure-Dir (Join-Path $LogsRoot "patches")
}

function Ensure-BootstrapFiles() {
  $now = NowIso
  $agent = Get-AgentId
  $todoState  = Join-Path $RepoRoot "todo.state.json"
  $todoEvents = Join-Path $RepoRoot "todo.events.jsonl"
  $todoCurrent= Join-Path $RepoRoot "todo.current.md"
  $todoMaster = Join-Path $RepoRoot "todo.master.index.json"
  $todoHist   = Join-Path $RepoRoot "todo.history.digest.json"
  $handoff    = Join-Path $RepoRoot "handoff.latest.json"
  $verifyState = Join-Path $CiRoot "run\verify.state.json"
  $loopGuard   = Join-Path $CiRoot "run\loop.guard.json"
  $toolchainState = Join-Path $CiRoot "run\toolchain.state.json"
  $verifyDigest = Join-Path $LogsRoot "verify\verify.digest.json"
  $failbundle   = Join-Path $LogsRoot "verify\failbundle-latest.json"
  $lockLatest   = Join-Path $LogsRoot "locks\lock-latest.json"
  $cfgPath      = Get-ConfigPath
  if (-not (Test-Path -LiteralPath $todoState))  { Write-Json $todoState @{ cursor=0; active_id=$null; items=@() } }
  if (-not (Test-Path -LiteralPath $todoEvents)) {
    $ev = @{ ts=$now; event_id="EV-BOOTSTRAP"; todo_id="BOOTSTRAP"; type="checkpoint"; status="open"; prio="low"; source="bootstrap"; msg="bootstrap init"; refs=@("file:todo.state.json"); changed=@(); verified=@(); git=@{} }
    Atomic-WriteTextUtf8 $todoEvents ((To-Json $ev) + "`n")
  }
  if (-not (Test-Path -LiteralPath $todoMaster)) { Write-Json $todoMaster @{ ts=$now; todos=@() } }
  if (-not (Test-Path -LiteralPath $todoHist))   { Write-Json $todoHist @{ ts=$now; done_total=0; done_last_30d=0; recent_done=@(); last_prune_ts=$null; last_rotation_ts=$null } }
  if (-not (Test-Path -LiteralPath $handoff))    { Write-Json $handoff @{ ts=$now; agent_id=$agent; workspace_root=$RepoRoot; capsule=@{} } }
  else {
    $h = Try-ReadJson $handoff; $fix = $false; $aid = [string](Get-Prop $h "agent_id" ""); $wr  = [string](Get-Prop $h "workspace_root" "")
    if ($null -eq $h) { $fix = $true } elseif ($aid.StartsWith("<") -or $wr.StartsWith("<")) { $fix = $true }
    if ($fix) { Write-Json $handoff @{ ts=$now; agent_id=$agent; workspace_root=$RepoRoot; capsule=@{} } }
  }
  if (-not (Test-Path -LiteralPath $verifyState)) { Write-Json $verifyState @{ ts=$now; agent_id=$agent; last_cmd=$null; last_fail_signature=$null; fail_streak=0; escalation_level=0; last_log_path=$null; last_exit=$null } }
  if (-not (Test-Path -LiteralPath $loopGuard))   { Write-Json $loopGuard @{ ts=$now; agent_id=$agent; last_cmd=$null; last_fail_signature=$null; repeat_count=0; last_progress=$null } }
  if (-not (Test-Path -LiteralPath $toolchainState)) { Write-Json $toolchainState @{ ts=$now; gradle=@{ mode="unknown"; cmd=$null; root=$null } } }
  if (-not (Test-Path -LiteralPath $verifyDigest)) { Write-Json $verifyDigest @{} }
  if (-not (Test-Path -LiteralPath $failbundle))   { Write-Json $failbundle @{} }
  if (-not (Test-Path -LiteralPath $lockLatest))   { Write-Json $lockLatest @{} }
  if (-not (Test-Path -LiteralPath $cfgPath)) {
    Write-Json $cfgPath @{
      ts=$now; features=@{ browser_tests="staged"; observer="staged" }; verify=@{ cmd=$null }; route_check="standard"; browser_smoke=@{ cmd=$null; interval_minutes=15 }; devserver=@{ cmd=$null }; pyserver=@{ cmd=$null }; todo=@{ autoseed_from_roadmap=$true; seed_max_items=8 }; deps_bootstrap=@{ auto_install=$true; allow_choco=$true }; toolchain=@{ gradle_cmd=$null; gradle_default_version="8.13"; java_min_major=17 }; workspace_lock=@{ on=$true; stale_minutes=30 }; gradle=@{ wrapper_autorepair=$true; wrapper_default_version="8.13" }
    }
  }
  $st = Try-ReadJson $todoState; if ($null -eq $st) { $st = @{ cursor=0; active_id=$null; items=@() } }
  Atomic-WriteTextUtf8 $todoCurrent (Render-TodoCurrent $st)
  $cfg = Try-ReadJson $cfgPath; $features = Get-Prop $cfg "features" $null; $bt = [string](Get-Prop $features "browser_tests" "staged")
  if ($bt -ne "off") {
    $bc = Join-Path $RepoRoot "browser-tests.contract.md"
    if (-not (Test-Path -LiteralPath $bc)) {
      $t2 = New-Object System.Collections.Generic.List[string]; $t2.Add('# browser-tests.contract.md'); $t2.Add(''); $t2.Add('## Command (Pflicht sobald aktiv)'); $t2.Add('CMD:'); $t2.Add('```shell'); $t2.Add('# Beispiel:'); $t2.Add('npm ci && npx playwright test'); $t2.Add('```'); $template = ($t2 -join "`r`n") + "`r`n"; Atomic-WriteTextUtf8 $bc $template
    }
  }
}

function Get-LockPath() { Join-Path $CiRoot "locks\workspace.lock.json" }

function Cmd-WsLockAcquire() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath); $wl = Get-Prop $cfg "workspace_lock" $null; $staleMin = [int](Get-Prop $wl "stale_minutes" 30)
  $p = Get-LockPath; $agent = Get-AgentId; $now = NowIso; $hostName = $env:COMPUTERNAME; $procId = $PID
  if (-not (Test-Path -LiteralPath $p)) { Write-Json $p @{ ts=$now; agent_id=$agent; host=$hostName; pid=$procId }; return }
  $cur = Try-ReadJson $p; $ts = Get-Prop $cur "ts" $null; $ageMin = 999999
  if ($ts) { try { $ageMin = [math]::Floor(((Get-Date) - (Get-Date $ts)).TotalMinutes) } catch { $ageMin = 999999 } }
  if ($ageMin -ge $staleMin) {
    $staleCopy = Join-Path $LogsRoot ("locks\stale-workspace-lock-" + (TsId) + ".json"); try { Copy-Item -Force -LiteralPath $p -Destination $staleCopy } catch { $null = $_ }
    Write-Json $p @{ ts=$now; agent_id=$agent; host=$hostName; pid=$procId }; return
  }
  throw ("workspace.lock active (age " + $ageMin + "m).")
}

function Cmd-WsLockRelease() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $p = Get-LockPath; if (Test-Path -LiteralPath $p) { try { Remove-Item -Force -LiteralPath $p } catch { $null = $_ } }
}

function Get-ImmutablePinsPath() { Join-Path $CiRoot "pins\immutable.hashes.json" }

function Set-ReadOnlyFlag([string]$path, [bool]$ro) {
  try { if (Test-Path -LiteralPath $path) { $fi = Get-Item -LiteralPath $path -Force; $fi.IsReadOnly = $ro } } catch { $null = $_ }
}

function Pin-ImmutableFiles() {
  Ensure-Dir (Join-Path $CiRoot "pins"); $snapRoot = Join-Path $CiRoot "pins\immutable.snapshot"; Ensure-Dir $snapRoot
  $files = @()
  foreach ($rel in $ImmutableFiles) {
    $p = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $p) {
      $h = Sha256Path $p; if ($h) { $files += @{ path=$rel; sha256=$h } }
      try { $dest = Join-Path $snapRoot $rel; Ensure-Dir (Split-Path -Parent $dest); Copy-Item -Force -LiteralPath $p -Destination $dest } catch { $null = $_ }
      Set-ReadOnlyFlag $p $true
    }
  }
  $pins = @{ ts=NowIso; agent_id=(Get-AgentId); files=$files }; Write-Json (Get-ImmutablePinsPath) $pins; return $pins
}

function Read-ImmutablePins() {
  $p = Get-ImmutablePinsPath; if (-not (Test-Path -LiteralPath $p)) { return $null }; return (Try-ReadJson $p)
}

function Assert-ImmutableClean([string]$context="") {
  $pins = Read-ImmutablePins; if ($null -eq $pins) { return }
  $files = @(Get-Prop $pins "files" @())
  foreach ($f in $files) { $rel = [string](Get-Prop $f "path" ""); if (-not $rel) { continue }; $p = Join-Path $RepoRoot $rel; if (Test-Path -LiteralPath $p) { Set-ReadOnlyFlag $p $true } }
}

function With-ImmutableWrite([scriptblock]$action) {
  $pins = Read-ImmutablePins
  if ($pins) { foreach ($f in @(Get-Prop $pins "files" @())) { $rel = [string](Get-Prop $f "path" ""); if ($rel) { Set-ReadOnlyFlag (Join-Path $RepoRoot $rel) $false } } }
  try { & $action } finally {
    if ($pins) { foreach ($f in @(Get-Prop $pins "files" @())) { $rel = [string](Get-Prop $f "path" ""); if ($rel) { Set-ReadOnlyFlag (Join-Path $RepoRoot $rel) $true } } }
  }
}

function Cmd-PatchApply() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Assert-ImmutableClean "before patch-apply"

  With-ImmutableWrite {
    $patch = $null
    $c1 = Get-ChildItem -LiteralPath (Join-Path $CiRoot "patches") -Filter "*.patch" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $c2 = Get-ChildItem -LiteralPath (Join-Path $CiRoot "inbox")   -Filter "*.patch" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($c1) { $patch = $c1.FullName } elseif ($c2) { $patch = $c2.FullName }
    if (-not $patch) { throw "No patch found in .ci/patches or .ci/inbox." }

    $ts = TsId
    $log = Join-Path $LogsRoot ("terminal\patch-apply-$ts.log")

    $check = Run-GitCmd ("apply --check " + (Quote-IfNeeded $patch)) $log
    if ($check.exit -ne 0) { throw "git apply --check failed. See $log" }

    $apply = Run-GitCmd ("apply " + (Quote-IfNeeded $patch)) $log
    if ($apply.exit -ne 0) { throw "git apply failed. See $log" }

    Ensure-Dir (Join-Path $LogsRoot "patches")
    Copy-Item -Force -LiteralPath $patch -Destination (Join-Path $LogsRoot ("patches\applied-" + $ts + ".patch"))

    # re-pin immutables AFTER patch was applied
    try { Pin-ImmutableFiles | Out-Null } catch { throw ("patch-apply: cannot pin immutables: " + $_.Exception.Message) }

    Cmd-Verify 0
  }
}
