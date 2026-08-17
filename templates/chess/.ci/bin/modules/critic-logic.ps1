function Cmd-Event([string[]]$argv) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath); $obs = Get-Prop $cfg "observer" $null
  $type = "generic"; $msg = ""
  if ($argv -and $argv.Count -ge 1) { $type = [string]$argv[0] }
  if ($argv -and $argv.Count -ge 2) { $msg = ($argv[1..($argv.Count-1)] -join " ") }
  $ev = @{ ts=NowIso; agent_id=(Get-AgentId); type=$type; msg=$msg; cmd=$script:LastCmdName }
  Append-Jsonl (Get-EventsPath) $ev; CI-Info ("event: type=" + $type + " len=" + ($msg.Length))
  $auto = [bool](Get-Prop $obs "auto_tick_on_event" $true); if ($auto) { Cmd-Tick @() }
}

function Get-LastTerminalLogs([int]$maxLines=120) {
  $dir = Join-Path $LogsRoot "terminal"; if (-not (Test-Path $dir)) { return @() }
  try {
    $f = Get-ChildItem -LiteralPath $dir -Filter "*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 3
    $out = @(); foreach ($x in $f) { $out += @{ path=("logs/terminal/" + $x.Name); tail=(Tail-File $x.FullName $maxLines) } }
    return $out
  } catch { return @() }
}

function Build-CriticCapsule() {
  $cfg = Try-ReadJson (Get-ConfigPath); $cr = Get-Prop $cfg "critic" $null; $maxEv = [int](Get-Prop $cr "max_events" 10); $maxTerm = [int](Get-Prop $cr "max_terminal_lines" 200)
  $program = Read-TextTrunc (Join-Path $RepoRoot "manual\PROGRAM.md") 24000; $policy  = Read-TextTrunc (Join-Path $RepoRoot "project.policy.hard.md") 16000; $roadmap = Read-TextTrunc (Join-Path $RepoRoot "Roadmap.md") 12000; $arch    = Read-TextTrunc (Join-Path $RepoRoot "architecture.contract.md") 12000; $browser = Read-TextTrunc (Join-Path $RepoRoot "browser-tests.contract.md") 12000
  $events = Read-LastJsonl (Get-EventsPath) $maxEv; $term   = Get-LastTerminalLogs $maxTerm
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json"); $fb = Try-ReadJson (Join-Path $LogsRoot "verify\failbundle-latest.json"); $rc = Try-ReadJson (Join-Path $CiRoot "run\route.check.json")
  $git = @{ status=$null; diff_stat=$null; diff_patch=$null; changed_paths=@() }
  try {
    if (Test-Path (Join-Path $RepoRoot ".git")) {
      $ts = TsId; $log = Join-Path $LogsRoot ("terminal\critic-git-$ts.log")
      $git.status = (Run-GitCmd "status --porcelain=v1" $log).out
      $git.diff_stat = (Run-GitCmd "diff --stat" $log).out
      $git.changed_paths = Try-GitDiffNames $log
      $patch = (Run-GitCmd "diff" $log).out
      if ($patch -and $patch.Length -gt 50000) { $patch = $patch.Substring(0,50000) + "`n...[truncated]..." }
      $git.diff_patch = $patch
    }
  } catch { $null = $_ }
  return @{ ts=NowIso; agent_id=(Get-AgentId); project_kind="dj"; sources=@{ priority=@("manual/*.md","Roadmap.md","project.policy.hard.md","toolchain.pins.md","architecture.contract.md","browser-tests.contract.md","manual/* (non-md)","rest (last resort)") }; manual=@{ program=$program }; policy=@{ hard=$policy }; roadmap=$roadmap; contracts=@{ architecture=$arch; browser_tests=$browser }; events=$events; terminal=$term; verify_digest=$vd; failbundle=$fb; route_check=$rc; git=$git }
}

function Invoke-OpenAiChat([string]$systemPrompt, [string]$userPrompt, [string]$model) {
  $systemPrompt = $systemPrompt.Replace("`r`n", "`n"); $userPrompt = $userPrompt.Replace("`r`n", "`n"); $cfg = $null; try { $cfg = Try-ReadJson (Get-ConfigPath) } catch { $cfg = $null }; $oa = Get-OpenAiRuntimeConfig $cfg
  $key = [string]$oa.api_key; $urlBase = [string]$oa.base_url; $timeoutSec = [int]$oa.timeout_sec
  if (-not $model) { $model = [string]$oa.model_override; if (-not $model) { $model = [string]$script:OpenAI_DefaultBaseUrl } }
  $url = $urlBase.TrimEnd('/') + "/chat/completions"
  $body = @{ model = $model; temperature = 0; messages = @( @{ role="system"; content=$systemPrompt }, @{ role="user"; content=$userPrompt } ) } | ConvertTo-Json -Depth 30
  $headers = @{ Authorization = ("Bearer " + $key) }
  return Invoke-RestMethod -Method Post -Uri $url -Headers $headers -ContentType "application/json" -Body $body -TimeoutSec $timeoutSec
}

function Cmd-Critic() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $cfg = Try-ReadJson (Get-ConfigPath); $cr = Get-Prop $cfg "critic" $null; $enabled = [bool](Get-Prop $cr "enabled" $true)
  if (-not $enabled) { CI-Info "critic: disabled"; return }
  Ensure-Dir (Join-Path $LogsRoot "critic\requests"); Ensure-Dir (Join-Path $LogsRoot "critic\responses"); Ensure-Dir (Join-Path $LogsRoot "critic"); Ensure-Dir (Join-Path $LogsRoot "observer"); Ensure-Dir (Join-Path $RepoRoot "wiki\ci-issues")
  $ts = TsId; $capsule = Build-CriticCapsule; $reqPath = Join-Path $LogsRoot ("critic\requests\req-" + $ts + ".json"); Write-Json $reqPath $capsule
  $model = [string](Get-Prop $cr "model" $script:OpenAI_DefaultModel); if (-not $model) { $model = $script:OpenAI_DefaultModel }
  $system = "Du bist der CI-Observer/Critic. Ziel: deterministische Korrekturvorschläge für den Workflow ohne Drift.`n`nRegeln:`n- Keine interaktiven Schritte vorschlagen (CI=true, stdin ist geschlossen).`n- Keine Background-Prozesse ohne PID-Tracking + Stop-Command.`n- Respektiere NO_TOUCH/FORBID_PATH/FORBID_REGEX.`n- Priorisiere: lock/io > infra/tooling > buildscript > tests/lint > refactor.`n- Antworte ausschließlich als JSON (kein Fließtext)."; $user = "CAPSULE_JSON:`n" + (To-Json $capsule); $raw = $null; $parsed = $null; $status = "blocked"; $risk = "high"; $classification = "unknown"; $failSig = Get-Prop (Get-Prop $capsule "verify_digest" $null) "fail_signature" $null
  try {
    $resp = Invoke-OpenAiChat $system $user $model; $raw = $resp
    try { $content = $resp.choices[0].message.content; $parsed = $content | ConvertFrom-Json -ErrorAction Stop; $status = [string](Get-Prop $parsed "status" "fixable"); $risk = [string](Get-Prop $parsed "risk" "medium"); $classification = [string](Get-Prop $parsed "classification" "unknown") }
    catch { $parsed = @{ status="blocked"; risk="high"; classification="unknown"; notes=@("critic output was not valid json") ; raw=($resp | ConvertTo-Json -Depth 12) } }
  } catch { $parsed = @{ status="blocked"; risk="high"; classification="unknown"; notes=@($_.Exception.Message) } }
  $resPath = Join-Path $LogsRoot ("critic\responses\res-" + $ts + ".json"); Write-Json $resPath $raw; $latestPath = Join-Path $LogsRoot "critic\critic.latest.json"; Write-Json $latestPath $parsed
  $idx = @{ ts=NowIso; model=$model; status=$status; risk=$risk; classification=$classification; fail_signature=$failSig; request=("logs/critic/requests/req-" + $ts + ".json"); response=("logs/critic/responses/res-" + $ts + ".json"); latest="logs/critic/critic.latest.json" }; Append-Jsonl (Join-Path $LogsRoot "critic\index.jsonl") $idx
  if ($failSig) { $wiki = Join-Path $RepoRoot ("wiki\ci-issues\" + $failSig + ".md"); if (-not (Test-Path $wiki)) { Atomic-WriteTextUtf8 $wiki ("# CI Issue: " + $failSig + "`r`n`r`n## Seen`r`n- " + (NowIso) + "`r`n") } else { Add-Content -LiteralPath $wiki -Value ("- " + (NowIso) + "`r`n") -Encoding UTF8 } }
  CI-Info ("critic: status=" + $status + " risk=" + $risk + " class=" + $classification)
}

function Parse-UnifiedDiffTouchedFiles([string]$diffText) {
  $files = New-Object System.Collections.Generic.List[string]; if (-not $diffText) { return @() }
  foreach ($ln in ($diffText -split "`r?`n")) { if ($ln -match '^\+\+\+\s+b/(.+)$') { $files.Add($Matches[1].Trim()); continue } }
  return @($files | Select-Object -Unique)
}

function Is-PathDenied([string]$path, [string[]]$denyList) {
  if (-not $path) { return $true }
  foreach ($d in $denyList) {
    if (-not $d) { continue }; $p = $d.Replace('\','/').TrimEnd('/'); $c = $path.Replace('\','/')
    if ($p.EndsWith("/")) { if ($c.StartsWith($p)) { return $true } }
    else { if ($c -ieq $p) { return $true }; if ($p.EndsWith("/**") -and $c.StartsWith($p.Substring(0,$p.Length-3))) { return $true }; if ($p.EndsWith("/*") -and $c.StartsWith($p.Substring(0,$p.Length-1))) { return $true }; if ($p.EndsWith("/") -and $c.StartsWith($p)) { return $true }; if ($c.StartsWith($p + "/")) { return $true } }
  }
  return $false
}

function Cmd-Autopatch() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $cfg = Try-ReadJson (Get-ConfigPath); $cr = Get-Prop $cfg "critic" $null; $deny = @()
  foreach ($x in @((Get-Prop $cr "autopatch_deny_paths" @()))) { if ($x) { $deny += [string]$x } }
  $rules = Read-PolicyRules; foreach ($x in @($rules.no_touch)) { if ($x) { $deny += [string]$x } }; foreach ($x in @($rules.forbid_path)) { if ($x) { $deny += [string]$x } }
  $latest = Try-ReadJson (Join-Path $LogsRoot "critic\critic.latest.json"); if (-not $latest) { throw "autopatch: critic.latest missing. Run: .ci\bin\ci.cmd critic" }
  $patchObj = Get-Prop $latest "patch" $null; $diff = [string](Get-Prop $patchObj "diff_unified" ""); if (-not $diff) { throw "autopatch: no diff_unified in critic.latest.json" }
  $files = Parse-UnifiedDiffTouchedFiles $diff; if (-not $files -or $files.Count -eq 0) { throw "autopatch: cannot determine touched files" }
  foreach ($f in $files) { if (Is-PathDenied $f $deny) { throw ("autopatch denied: " + $f) } }
  Ensure-Dir (Join-Path $CiRoot "inbox"); $ts = TsId; $patchPath = Join-Path $CiRoot ("inbox\critic-" + $ts + ".patch"); Atomic-WriteTextUtf8 $patchPath $diff; CI-Info ("autopatch: wrote " + $patchPath); Cmd-PatchApply
  $autoCommit = [bool](Get-Prop $cr "auto_commit" $false); $autoPush = [bool](Get-Prop $cr "auto_push" $false)
  if ($autoCommit -and (Test-Path (Join-Path $RepoRoot ".git"))) {
    $log = Join-Path $LogsRoot ("terminal\autopatch-git-" + $ts + ".log")
    Run-GitCmd "add -A" $log | Out-Null
    $msg = "ci(autopatch): apply critic patch"
    Run-GitCmd ("commit -m " + (Quote-IfNeeded $msg)) $log | Out-Null
    if ($autoPush) { Run-GitCmd "push" $log | Out-Null }
  }
}
