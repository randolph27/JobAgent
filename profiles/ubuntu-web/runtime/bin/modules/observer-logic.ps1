function Normalize-Rel([string]$rel) {
  if (-not $rel) { return $rel }
  return ($rel -replace "\\","/")
}

function Get-ObserverSourcePaths() {
  return @(
    "README.md",
    "Roadmap.md",
    "project.policy.hard.md",
    "toolchain.pins.md",
    "architecture.contract.md",
    "browser-tests.contract.md",
    "manual\PROGRAM.md",
    ".ci\ci.config.json",
    ".ci\pins\immutable.hashes.json",
    ".ci\run\manual.digest.json",
    ".ci\run\env_inventory.digest.json"
  )
}

function Read-ObserverSources() {
  $out = New-Object System.Collections.Generic.List[object]
  foreach ($rel in @(Get-ObserverSourcePaths)) {
    $abs = Join-Path $RepoRoot $rel
    if (Test-Path $abs) {
      try {
        $h = (Get-FileHash -LiteralPath $abs -Algorithm SHA256).Hash.ToLowerInvariant()
        $fi = Get-Item -LiteralPath $abs -Force
        $out.Add(@{ path=(Normalize-Rel $rel); sha256=$h; len=[int]$fi.Length; missing=$false })
      } catch {
        $out.Add(@{ path=(Normalize-Rel $rel); sha256=$null; len=0; missing=$true })
      }
    } else {
      $out.Add(@{ path=(Normalize-Rel $rel); sha256=$null; len=0; missing=$true })
    }
  }
  return $out
}

function Compute-ObserverSourcesHash([object[]]$entries) {
  if (-not $entries) { return $null }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($e in @($entries | Sort-Object { $_.path })) {
    $p = [string](Get-Prop $e "path" "")
    $h = [string](Get-Prop $e "sha256" "")
    $m = [string]([bool](Get-Prop $e "missing" $false))
    $l = [string](Get-Prop $e "len" 0)
    $lines.Add(($p + "|" + $h + "|" + $m + "|" + $l))
  }
  $txt = ($lines -join "`n")
  try {
    $ms = [IO.MemoryStream]::new([Text.Encoding]::UTF8.GetBytes($txt))
    return (Get-FileHash -InputStream $ms -Algorithm SHA256).Hash.ToLowerInvariant()
  } catch { return $null }
}

function Get-ObserverStatePath() { Join-Path $CiRoot "run\observer.state.json" }
function Get-EventsPath() { Join-Path $LogsRoot "events\events.jsonl" }

function Read-TextTrunc([string]$path, [int]$maxChars=12000) {
  if (-not (Test-Path $path)) { return $null }
  try {
    $t = Get-Content -LiteralPath $path -Raw -ErrorAction Stop
    if ($t.Length -le $maxChars) { return $t }
    return ($t.Substring(0, $maxChars) + "`n...[truncated]...")
  } catch { return $null }
}

function Read-LastJsonl([string]$path, [int]$maxLines=10) {
  if (-not (Test-Path $path)) { return @() }
  try {
    $lines = Get-Content -LiteralPath $path -Tail $maxLines -ErrorAction Stop
    $out = @()
    foreach ($ln in $lines) {
      $s = $ln.Trim()
      if (-not $s) { continue }
      try { $out += (ConvertFrom-Json $s) } catch { $out += @{ raw=$s } }
    }
    return $out
  } catch { return @() }
}

function Append-Jsonl([string]$path, [object]$obj) {
  Ensure-Dir (Split-Path -Parent $path)
  $line = (To-Json $obj) + "`n"
  Add-Content -LiteralPath $path -Value $line -Encoding UTF8
}

function Cmd-ObserverBaseline() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $ts = TsId; $entries = Read-ObserverSources; $h = Compute-ObserverSourcesHash $entries
  $payload = @{ ts=NowIso; agent_id=(Get-AgentId); sources_hash=$h; sources=$entries }; Write-Json (Join-Path $CiRoot "run\observer.baseline.json") $payload; Ensure-Dir (Join-Path $LogsRoot "handoff"); Write-Json (Join-Path $LogsRoot ("handoff\observer.baseline." + $ts + ".json")) $payload; CI-Info ("observer-baseline: ok (sources=" + $entries.Count + ")")
}

function Cmd-ObserverCheck_Impl() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $basePath = Join-Path $CiRoot "run\observer.baseline.json"; $base = Try-ReadJson $basePath; if ($null -eq $base) { Cmd-ObserverBaseline; $base = Try-ReadJson $basePath }; $baseHash = [string](Get-Prop $base "sources_hash" ""); $baseEntries = @(); try { $baseEntries = @($base.sources) } catch { $baseEntries = @() }; $cur = Read-ObserverSources; $curHash = Compute-ObserverSourcesHash $cur; $diff = New-Object System.Collections.ArrayList; $baseMap = @{}; foreach ($e in @($baseEntries)) { $baseMap[[string](Get-Prop $e "path" "")] = $e }
  foreach ($e in @($cur)) { $p = [string](Get-Prop $e "path" ""); $b = $null; if ($baseMap.ContainsKey($p)) { $b = $baseMap[$p] }; $from = $null; $to = $null; $fromMissing=$null; $toMissing=$null; if ($b) { $from = [string](Get-Prop $b "sha256" $null); $fromMissing = [bool](Get-Prop $b "missing" $false) }; $to = [string](Get-Prop $e "sha256" $null); $toMissing = [bool](Get-Prop $e "missing" $false); if ($from -ne $to -or $fromMissing -ne $toMissing) { [void]$diff.Add(@{ path=$p; from=$from; to=$to; from_missing=$fromMissing; to_missing=$toMissing }) } }
  $baselineOutdated = ($baseHash -and $curHash -and ($baseHash -ne $curHash)); $payload = @{ ts=NowIso; agent_id=(Get-AgentId); baseline_hash=$baseHash; current_hash=$curHash; baseline_outdated=$baselineOutdated; changed_sources=$diff.Count; diff=($diff.ToArray()) }; Write-Json (Join-Path $CiRoot "run\observer.check.json") $payload; Write-Json (Join-Path $CiRoot "run\observer.diff.json") $payload; return $payload
}

function Cmd-ObserverCheck {
  try { Cmd-ObserverCheck_Impl @args } catch {
    try { $err = $_; $root = (Get-Location).Path; $dir = Join-Path $root "logs\terminal"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }; $ts = Get-Date -Format "yyyyMMdd-HHmmss"; $obj = [ordered]@{ ts = (Get-Date).ToString("o"); cmd = "observer-check"; message = $err.Exception.Message; type = $err.Exception.GetType().FullName; script = $err.InvocationInfo.ScriptName; line = $err.InvocationInfo.ScriptLineNumber; position = $err.InvocationInfo.OffsetInLine; positionMessage = $err.InvocationInfo.PositionMessage; stack = $err.ScriptStackTrace }; $json = ($obj | ConvertTo-Json -Depth 8); $p1 = Join-Path $dir ("error-observer-check-$ts.json"); $p2 = Join-Path $dir "error-observer-check-latest.json"; Set-Content -LiteralPath $p1 -Value $json -Encoding UTF8; Set-Content -LiteralPath $p2 -Value $json -Encoding UTF8 } catch { }
    throw
  }
}

function Get-DriftStatePath() { Join-Path $CiRoot "run\drift.state.json" }

function Load-DriftState() {
  $p = Get-DriftStatePath; $st = Try-ReadJson $p; if ($null -eq $st) { $st = @{ last_event_count=0; last_drift_ts=$null }; Write-Json $p $st }; if ($null -eq (Get-Prop $st "last_event_count" $null)) { $st.last_event_count = 0 }; return $st
}

function Save-DriftState([object]$st) { Write-Json (Get-DriftStatePath) $st }

function Get-DriftConfig() {
  $cfg = Try-ReadJson (Get-ConfigPath); $dc = Get-Prop $cfg "driftcheck" $null; if ($null -eq $dc) { $dc = @{} }; if ($null -eq (Get-Prop $dc "enabled" $null)) { $dc.enabled = $true }; if ($null -eq (Get-Prop $dc "interval_events" $null)) { $dc.interval_events = 10 }; if ($null -eq (Get-Prop $dc "interval_minutes" $null)) { $dc.interval_minutes = 15 }; if ($null -eq (Get-Prop $dc "auto_stp_on_drift" $null)) { $dc.auto_stp_on_drift = $true }; if ($null -eq (Get-Prop $dc "auto_create_todo" $null)) { $dc.auto_create_todo = $true }; if ($null -eq (Get-Prop $dc "auto_create_inbox_task" $null)) { $dc.auto_create_inbox_task = $true }; return $dc
}

function Ensure-DriftTodo([object]$driftPayload) {
  $title = "CI: Resolve drift (observer/route/immutables)"; $st = Load-TodoState
  foreach ($it in @($st.items)) { if ([string](Get-Prop $it "title" "") -eq $title) { $sid = [string](Get-Prop $it "status" "open"); if ($sid -ne "done") { if ($sid -ne "open") { $it.status = "open" }; try { Save-TodoState $st } catch { $null = $_ }; return [string](Get-Prop $it "id" $null) } } }
  $id = Next-TodoId $st; $it = @{ todo_id=$id; status="open"; title=$title; source="driftcheck"; created_ts=NowIso; refs=@("logs/observer/drift-latest.json") }; $st.items = @($st.items) + @($it); Save-TodoState $st
  try { Append-TodoEvent @{ ts=NowIso; type="drift"; todo_id=$id; status="open"; prio="high"; source="driftcheck"; msg="drift detected"; refs=@("file:logs/observer/drift-latest.json"); changed=@(); verified=@(); git=@{} } | Out-Null } catch { $null = $_ }
  return $id
}

function Write-DriftInboxTask([object]$driftPayload, [string]$todoId=$null) {
  Ensure-Dir (Join-Path $CiRoot "inbox"); $ts = TsId; $p = Join-Path $CiRoot ("inbox\drift-task-" + $ts + ".json")
  $task = @{ ts=NowIso; kind="task_request"; source="driftcheck"; todo_id=$todoId; title="Resolve drift"; hint="rehydrate sources, rerun stp, then continue"; refs=@("file:logs/observer/drift-latest.json","file:handoff.latest.json"); drift=$driftPayload }; Write-Json $p $task; return $p
}

function Run-TaskHookDetached([string]$cmd, [string]$name="task-hook") {
  if (-not $cmd) { return }; Ensure-NonInteractiveEnv; $ts = TsId; $logDir = Join-Path $LogsRoot "observer"; Ensure-Dir $logDir; $logPath = Join-Path $logDir ($name + "-" + $ts + ".log"); $logRel = "logs\observer\" + ($name + "-" + $ts + ".log"); $header = "## $(TsId)`r`nCMD: $cmd`r`nPWD: $($RepoRoot)`r`n"; Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8; $cmdLine = "$cmd >> $logRel 2>&1"
  try { $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/d","/c",$cmdLine -WorkingDirectory $RepoRoot -PassThru -WindowStyle Hidden; if ($p) { CI-Info ("hook(detached): pid=" + $p.Id + " cmd=" + $cmd) } } catch { $null = $_ }
}

function Cmd-DriftCheck() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $dc = Get-DriftConfig; if (-not [bool](Get-Prop $dc "enabled" $true)) { CI-Info "drift-check: disabled in .ci/ci.config.json"; return }
  $ts = TsId; $immOk = $true; $immErr = $null; try { Assert-ImmutableClean "drift-check" } catch { $immOk = $false; $immErr = $_.Exception.Message }; $obs = $null; try { $obs = Cmd-ObserverCheck } catch { $obs = Try-ReadJson (Join-Path $CiRoot "run\observer.check.json") }; $routeOk = $true; $routeErr = $null; try { Cmd-RouteCheck } catch { $routeOk = $false; $routeErr = $_.Exception.Message }; $rc = Try-ReadJson (Join-Path $CiRoot "run\route.check.json"); $baselineOutdated = [bool](Get-Prop $obs "baseline_outdated" $false); $changedSources = [int](Get-Prop $obs "changed_sources" 0)
  if ($rc) { try { $routeOk = [bool](Get-Prop $rc "route_ok" $routeOk) } catch { $null = $_ } }; $drift = ((-not $immOk) -or (-not $routeOk) -or $baselineOutdated -or ($changedSources -gt 0)); $payload = @{ ts=NowIso; agent_id=(Get-AgentId); drift=$drift; immutables_ok=$immOk; immutables_error=$immErr; observer=$obs; route_ok=$routeOk; route_error=$routeErr; route=$rc }; Ensure-Dir (Join-Path $LogsRoot "observer"); Write-Json (Join-Path $LogsRoot "observer\drift-latest.json") $payload; Write-Json (Join-Path $LogsRoot ("observer\drift-" + $ts + ".json")) $payload; Write-Json (Join-Path $CiRoot "run\drift.latest.json") $payload
  if ($drift) { $todoId = $null; if ([bool](Get-Prop $dc "auto_create_todo" $true)) { try { $todoId = Ensure-DriftTodo $payload } catch { $null = $_ } }; if ([bool](Get-Prop $dc "auto_create_inbox_task" $true)) { try { $null = Write-DriftInboxTask $payload $todoId } catch { $null = $_ } }; $hook = Get-Prop $dc "task_hook" $null; if ($hook -and [bool](Get-Prop $hook "enabled" $false)) { $cmd = [string](Get-Prop $hook "cmd" $null); if ($cmd) { Run-TaskHookDetached $cmd "drift-task-hook" } }; if ([bool](Get-Prop $dc "auto_stp_on_drift" $true)) { try { Cmd-Stp } catch { $null = $_ } }; throw "drift detected. See logs/observer/drift-latest.json" }
  CI-Info "drift-check: ok"
}

function Get-PriorityStatePath() { return (Join-Path $LogsRoot "observer\priority.state.json") }

function Load-PriorityState() {
  $p = Get-PriorityStatePath; $st = Try-ReadJson $p; if ($null -eq $st) { return @{ ts=NowIso; last=@{} } }; if ($null -eq (Get-Prop $st "last" $null)) { $st | Add-Member -NotePropertyName "last" -NotePropertyValue @{} -Force }; return $st
}

function Save-PriorityState($st) { $st.ts = NowIso; Write-Json (Get-PriorityStatePath) $st }

function Get-LastEventType() {
  $p = Get-EventsPath; if (-not (Test-Path $p)) { return $null }; $line = $null; try { $line = Get-Content -LiteralPath $p -Tail 1 -ErrorAction SilentlyContinue } catch { $line = $null }; if (-not $line) { return $null }; try { $o = $line | ConvertFrom-Json -ErrorAction Stop; return [string]$o.type } catch { return $null }
}

function Report-Priority([string]$kind, [string]$summary, [hashtable]$data=$null) {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $cfg = Try-ReadJson (Get-ConfigPath); $pc  = Get-Prop $cfg "priority" $null; $enabled = [bool](Get-Prop $pc "enabled" $true); if (-not $enabled) { return }; $dedupeMin = 240; try { $dedupeMin = [int](Get-Prop $pc "dedupe_minutes" 240) } catch { $dedupeMin = 240 }; if ($dedupeMin -lt 0) { $dedupeMin = 0 }; $st = Load-PriorityState; $lastMap = Get-Prop $st "last" $null; if ($null -eq $lastMap) { $lastMap = @{}; $st.last = $lastMap }; $now = Get-Date; $prevIso = $null; try { $prevIso = $lastMap[$kind] } catch { $prevIso = $null }; if ($prevIso) { try { $ageMin = (($now - (Get-Date $prevIso)).TotalMinutes); if ($ageMin -lt $dedupeMin) { return } } catch { $null = $_ } }; $payload = @{ ts = NowIso; kind = $kind; summary = $summary; repo_root = $RepoRoot; cmd = $script:LastCmdName; data = $data }; $p = Join-Path $LogsRoot "observer\priority-latest.json"; Write-Json $p $payload; try { $lastMap[$kind] = NowIso; Save-PriorityState $st } catch { $null = $_ }; try { Cmd-Event @("priority." + $kind, $summary) } catch { $null = $_ }
}

function Cmd-Tick([string[]]$argv) {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $force = $false; if ($argv) { foreach ($a in $argv) { if ($a -and ($a -eq "--force" -or $a -eq "-f")) { $force = $true } } }; $cfg = Try-ReadJson (Get-ConfigPath); $obs = Get-Prop $cfg "observer" $null; $cr  = Get-Prop $cfg "critic" $null; $interval = [int](Get-Prop $obs "event_interval" 10); $tickSec  = [int](Get-Prop $obs "tick_interval_seconds" 120); $autoPatch= [bool](Get-Prop $cr "auto_patch" $false); $dcCfg = Get-Prop $cfg "driftcheck" $null; $driftEnabled = [bool](Get-Prop $dcCfg "enabled" $true); $driftInterval = [int](Get-Prop $dcCfg "interval_events" 10); $driftMin = [int](Get-Prop $dcCfg "interval_minutes" 15); if ($driftMin -lt 1) { $driftMin = 1 }; $driftSec = $driftMin * 60; Ensure-Dir (Join-Path $LogsRoot "observer"); $statePath = Get-ObserverStatePath; $st = Try-ReadJson $statePath; if (-not $st) { $st = @{ last_event_count=0; last_critic_ts=$null } }; $driftSt = Load-DriftState; $eventsPath = Get-EventsPath; $eventCount = 0; if (Test-Path $eventsPath) { try { $eventCount = (Get-Content -LiteralPath $eventsPath -ErrorAction Stop).Count } catch { $eventCount = 0 } }; $lastCount = [int](Get-Prop $st "last_event_count" 0); $dueCriticByEvents = (($eventCount - $lastCount) -ge $interval); $dueCriticByTime = $false; $lastTs = Get-Prop $st "last_critic_ts" $null
  if ($lastTs) { try { $age = ((Get-Date) - (Get-Date $lastTs)).TotalSeconds; if ($age -ge $tickSec -and $eventCount -gt $lastCount) { $dueCriticByTime = $true } } catch { $dueCriticByTime = $false } } else { if ($eventCount -gt 0) { $dueCriticByTime = $true } }; $dueCritic = ($force -or $dueCriticByEvents -or $dueCriticByTime); $forceOnPriority = $true; try { $forceOnPriority = [bool](Get-Prop $obs "force_critic_on_priority" $true) } catch { $forceOnPriority = $true }; if ($forceOnPriority) { $lt = Get-LastEventType; if ($lt -and $lt -match '^(?i)priority(\.|$)') { $dueCritic = $true } }; $dueDrift = $false; $lastDriftCount = [int](Get-Prop $driftSt "last_event_count" 0); $dueDriftByEvents = (($eventCount - $lastDriftCount) -ge $driftInterval); $dueDriftByTime = $false; $lastDts = Get-Prop $driftSt "last_drift_ts" $null
  if ($lastDts) { try { $ageD = ((Get-Date) - (Get-Date $lastDts)).TotalSeconds; if ($ageD -ge $driftSec -and $eventCount -gt $lastDriftCount) { $dueDriftByTime = $true } } catch { $dueDriftByTime = $false } } else { if ($eventCount -gt 0) { $dueDriftByTime = $true } }; if ($driftEnabled) { $dueDrift = ($force -or $dueDriftByEvents -or $dueDriftByTime) }; $due = ($dueCritic -or $dueDrift); $tickLog = @{ ts=NowIso; agent_id=(Get-AgentId); events=$eventCount; last_events=$lastCount; interval=$interval; drift_enabled=$driftEnabled; drift_events=$driftInterval; drift_minutes=$driftMin; due=$due; due_critic=$dueCritic; due_drift=$dueDrift; force=$force }; Append-Jsonl (Join-Path $LogsRoot "observer\tick.jsonl") $tickLog; if (-not $due) { CI-Info ("tick: skip (events=" + $eventCount + " last=" + $lastCount + ")"); return }
  try { Cmd-WsLockAcquire } catch { CI-Info ("tick: workspace busy (skip): " + $_.Exception.Message); return }
  try { if ($dueDrift) { try { Cmd-DriftCheck } catch { $driftSt.last_event_count = $eventCount; $driftSt.last_drift_ts = NowIso; try { Save-DriftState $driftSt } catch { $null = $_ }; CI-Info ("tick: drift detected (skip critic): " + $_.Exception.Message); return }; $driftSt.last_event_count = $eventCount; $driftSt.last_drift_ts = NowIso; try { Save-DriftState $driftSt } catch { $null = $_ } }; if ($dueCritic) { Cmd-Critic; if ($autoPatch) { Cmd-Autopatch }; $st.last_event_count = $eventCount; $st.last_critic_ts = NowIso; Write-Json $statePath $st } else { CI-Info "tick: drift only (critic not due)" } } finally { try { Cmd-WsLockRelease } catch { $null = $_ } }
}

function Get-ObserverdPidPath() { Join-Path $CiRoot "run\observerd.pid" }
function Get-ObserverdLogPath() { Join-Path $LogsRoot "observer\observerd.log" }

function Cmd-ObserverdStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-NonInteractiveEnv; $pidPath = Get-ObserverdPidPath
  if (Test-Path $pidPath) { $obsPid = [int]((Get-Content -LiteralPath $pidPath -Raw).Trim()); try { $p = Get-Process -Id $obsPid -ErrorAction Stop; CI-Info ("observerd: already running pid=" + $obsPid); return } catch { try { Remove-Item -Force -LiteralPath $pidPath } catch { $null = $_ } } }
  $cfg = Try-ReadJson (Get-ConfigPath); $obs = Get-Prop $cfg "observer" $null; $tickSec = [int](Get-Prop $obs "tick_interval_seconds" 120); $daemonPs1 = Join-Path $CiRoot "tools\observer-daemon.ps1"; if (-not (Test-Path $daemonPs1)) { throw "observerd: missing .ci/tools/observer-daemon.ps1" }; $logPath = Get-ObserverdLogPath; Ensure-Dir (Split-Path -Parent $logPath)
  try { if (Test-Path $logPath) { if ((Get-Item -LiteralPath $logPath).Length -gt 200kb) { Move-Item -Force -LiteralPath $logPath -Destination (Join-Path (Split-Path -Parent $logPath) ("observerd-" + (TsId) + ".log")) } } } catch { $null = $_ }
  $logRel = "logs\observer\observerd.log"; $psExe = $null; try { $psExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source } catch { $psExe = $null }; if (-not $psExe) { try { $psExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source } catch { $psExe = $null } }; if (-not $psExe) { $psExe = "powershell" }; $psArgs = @("-NoProfile","-NonInteractive","-File",$daemonPs1,"-IntervalSeconds",$tickSec); $psCmd = (Quote-IfNeeded $psExe) + " " + (($psArgs | ForEach-Object { Quote-IfNeeded ([string]$_) }) -join " "); $cmdLine = "$psCmd >> $logRel 2>&1"; $proc = Start-Process -FilePath "cmd.exe" -ArgumentList "/d","/c",$cmdLine -WorkingDirectory $RepoRoot -PassThru -WindowStyle Hidden
  if (-not $proc) { throw "observerd-start failed: Start-Process returned null." }; Atomic-WriteTextUtf8 $pidPath ([string]$proc.Id); CI-Info ("observerd: started pid=" + $proc.Id + " interval=" + $tickSec + "s log=" + $logPath)
}

function Cmd-ObserverdStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Get-ObserverdPidPath; if (-not (Test-Path $pidPath)) { CI-Info "observerd: not running"; return }; $obsPid = [int]((Get-Content -LiteralPath $pidPath -Raw).Trim())
  try { Stop-Process -Id $obsPid -Force -ErrorAction Stop; CI-Info ("observerd: stopped pid=" + $obsPid) } catch { CI-Info ("observerd: stop failed pid=" + $obsPid + " (" + $_.Exception.Message + ")") }; try { Remove-Item -Force -LiteralPath $pidPath } catch { $null = $_ }
}

function Cmd-ObserverdStatus() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Get-ObserverdPidPath; if (-not (Test-Path $pidPath)) { CI-Info "observerd: not running"; return }; $obsPid = [int]((Get-Content -LiteralPath $pidPath -Raw).Trim())
  try { $p = Get-Process -Id $obsPid -ErrorAction Stop; CI-Info ("observerd: running pid=" + $obsPid + " cpu=" + $p.CPU) } catch { CI-Info ("observerd: stale pid file (pid=" + $obsPid + ")"); try { Remove-Item -Force -LiteralPath $pidPath } catch { $null = $_ } }
}
