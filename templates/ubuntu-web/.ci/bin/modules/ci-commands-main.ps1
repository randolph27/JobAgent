function Cmd-T2() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "t2: starting master validation..."
  $started = $false
  $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
  if (-not (Test-Path $pidPath)) {
    CI-Info "t2: devserver not running, starting..."
    Cmd-DevserverStart
    $started = $true
  }
  $ts = TsId; $log = Join-Path $LogsRoot ("terminal\t2-$ts.log")
  CI-Info "t2: running master_validation.js"
  $res = Run-Cmd "node tests/ui/master_validation.js" $log
  if ($started) { CI-Info "t2: stopping devserver..."; Cmd-DevserverStop }
  if ($res.exit -ne 0) { throw "t2: master validation failed. See $log" }
  CI-Info "t2: master validation successful."
}

function Cmd-Supertest() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "supertest: verify + local browser smoke + build:release + artifact audit + read-only production smoke"
  Cmd-Verify 0
  $ts = TsId
  $superLog = Join-Path $LogsRoot ("terminal\supertest-" + $ts + ".log")
  CI-Info ("supertest: npm run test:super | log=" + $superLog)
  $supertestTimeouts = @{
    default_timeout_seconds = 2400
    no_output_timeout_seconds = 600
    heartbeat_seconds = 15
  }
  $res = Run-Cmd "npm run test:super" $superLog $null $RepoRoot $supertestTimeouts
  if ($res.exit -ne 0) { throw ("supertest: read-only release suite failed. See " + $superLog) }
  CI-Info ("supertest: ok (log=" + $superLog + ")")
}

function Cmd-Sonar() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $ts = TsId
  $sonarLog = Join-Path $LogsRoot ("terminal\sonar-" + $ts + ".log")
  Clear-SonarCommandOutcome
  CI-Info ("sonar: npm run sonar | log=" + $sonarLog)
  $runErrorMessage = ""
  try {
    $res = Run-Cmd "npm run sonar" $sonarLog $null $RepoRoot @{
      default_timeout_seconds = 3600
      no_output_timeout_seconds = 600
      heartbeat_seconds = 15
    }
  } catch {
    $runErrorMessage = [string]$_.Exception.Message
    $res = @{ exit = 1 }
  }
  if ($res.exit -ne 0) {
    $outcome = Read-SonarCommandOutcome
    if ($outcome) {
      $failureKind = [string]$outcome.failure_kind
      $statusUrl = [string]$outcome.status_url
      $phase = [string]$outcome.phase
      $message = ""
      if ($outcome.error) {
        $message = [string]$outcome.error.message
      }
      $stage = [string](Get-Prop $outcome "stage" "")
      $remediation = [string](Get-Prop $outcome "remediation" "")
      $catalogPath = [string](Get-Prop $outcome "failure_catalog_path" "logs/review/SONAR-156-failure-catalog.md")
      $retryCommand = [string](Get-Prop $outcome "retry_command" "cmd /c .\ci.cmd sonar")
      try {
        $state = Load-TodoState
        $activeId = [string](Get-Prop $state "active_id" "SONAR-156")
        if (-not $activeId) { $activeId = "SONAR-156" }
        $git = Get-GitStatusSnapshot
        Append-TodoEvent @{
          ts = NowIso
          type = "blocked"
          todo_id = $activeId
          status = "blocked"
          prio = "high"
          source = "ci.cmd sonar"
          msg = ("classified sonar failure_kind=" + $failureKind + " stage=" + $stage + " remediation=" + $remediation + " retry=" + $retryCommand)
          refs = @("file:logs/terminal/error-sonar-latest.json", ("file:" + $catalogPath))
          changed = @("logs/terminal/error-sonar-latest.json", $catalogPath, "todo.events.jsonl")
          verified = @([pscustomobject]@{ cmd = "cmd /c .\ci.cmd sonar"; exit = $res.exit })
          git = @{
            branch = [string](Get-Prop $git "branch" "")
            head = [string](Get-Prop $git "head" "")
            ahead_behind = [string](Get-Prop $git "ahead_behind" "0/0")
          }
        } | Out-Null
      } catch {
        $null = $_
      }
      $details = @()
      if ($failureKind) { $details += ("failure_kind=" + $failureKind) }
      if ($stage) { $details += ("stage=" + $stage) }
      if ($phase) { $details += ("phase=" + $phase) }
      if ($statusUrl) { $details += ("status_url=" + $statusUrl) }
      if ($catalogPath) { $details += ("failure_catalog=" + $catalogPath) }
      if ($remediation) { $details += ("remediation=" + $remediation) }
      if ($message) { $details += $message }
      throw ("sonar: " + ($details -join " | "))
    }

    $fallback = "sonar blocked: reason=run_failed log=" + (To-RelPath $sonarLog)
    if ($runErrorMessage) { $fallback += " message=" + $runErrorMessage }
    throw ("sonar: " + $fallback)
  }

  $sonarGuard = Sync-SonarParityCheckpoint -CommandRef 'cmd /c .\ci.cmd sonar' -BaseExit 0 -FailWhenBlocking
  if ($sonarGuard) {
    $summary = [string](Get-Prop $sonarGuard 'summary' 'sonar ok')
    $terminalSummary = [string](Get-SonarGuardSummary (Get-Prop $sonarGuard 'parity' $null))
    $blocking = [bool](Get-Prop $sonarGuard 'blocking' $false)
    $latestJson = Join-Path $LogsRoot 'terminal\error-sonar-latest.json'
    $latestTxt = Join-Path $LogsRoot 'terminal\error-sonar-latest.txt'
    Write-Json $latestJson @{
      ts = NowIso
      cmd = "sonar"
      message = $terminalSummary
      status = $(if ($blocking) { "blocked" } else { "ok" })
      success = (-not $blocking)
    }
    Atomic-WriteTextUtf8 $latestTxt ($terminalSummary + "`r`n")
  }
  if ($sonarGuard -and [bool](Get-Prop $sonarGuard 'blocking' $false)) {
    $summary = [string](Get-Prop $sonarGuard 'summary' 'sonar blocked')
    $parityArtifacts = Get-Prop $sonarGuard 'artifacts' $null
    $parityJson = ''
    if ($parityArtifacts) {
      $parityJson = [string](To-RelPath (Get-Prop $parityArtifacts 'json_path' ''))
    }
    $details = @($summary)
    if ($parityJson) {
      $details += ("evidence=" + $parityJson)
    }
    throw ("sonar: " + ($details -join " | "))
  }
}

function Cmd-Ci050UiReleaseGate() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $ts = TsId
  $logPath = Join-Path $LogsRoot ("terminal\CI-050-ui-release-gate-" + $ts + ".log")
  CI-Info ("ci050-ui-release-gate: node ./scripts/ci050-ui-release-gate.mjs --check | log=" + $logPath)
  $res = Run-Cmd "node ./scripts/ci050-ui-release-gate.mjs --check" $logPath $null $RepoRoot @{
    default_timeout_seconds = 300
    no_output_timeout_seconds = 120
    heartbeat_seconds = 15
  }
  if ($res.exit -ne 0) {
    throw ("ci050-ui-release-gate: mandatory UI release gate failed. See " + $logPath)
  }
  CI-Info ("ci050-ui-release-gate: ok (log=" + $logPath + ")")
}

function Sync-SonarParityCheckpoint(
  [string]$CommandRef,
  [int]$BaseExit = 0,
  [switch]$FailWhenBlocking,
  [switch]$WriteOnlyWhenBlocking
) {
  $parityPayload = Get-SonarParityPayload
  if (-not $parityPayload) {
    return $null
  }

  $artifacts = Write-SonarParityArtifacts $parityPayload
  $blocking = [bool](Get-Prop (Get-Prop $parityPayload 'parity' $null) 'blocking' $false)
  $state = $null
  try {
    $state = Load-TodoState
  } catch {
    $state = $null
  }

  $roadmapPath = Join-Path $RepoRoot 'Roadmap.md'
  $status = Resolve-HandoffSonarCheckpointStatus $state $roadmapPath $blocking
  $blockedTodo = Get-HandoffActiveBlockedTodo $state
  $summary = if ($blockedTodo) {
    [string](Get-Prop $blockedTodo 'blocker' (Get-SonarGuardSummary $parityPayload))
  } else {
    Resolve-HandoffSonarCheckpointSummary (Get-SonarGuardSummary $parityPayload) $status
  }
  $next = if ($status -eq 'done') {
    ''
  } elseif ($blockedTodo) {
    [string](Get-Prop $blockedTodo 'next' '')
  } else {
    Get-SonarGuardNextStep $parityPayload
  }
  $stopReason = if ($blocking) {
    [string](Get-Prop (Get-Prop $parityPayload 'parity' $null) 'blocking_reason' '')
  } elseif ($blockedTodo) {
    'active_todo_blocked'
  } else {
    $null
  }
  $verifiedExit = $(if ($blocking -and $FailWhenBlocking) { 1 } else { $BaseExit })
  $parityJsonRel = Normalize-RoutePath (To-RelPath (Get-Prop $artifacts 'json_path' ''))
  $parityMarkdownRel = Normalize-RoutePath (To-RelPath (Get-Prop $artifacts 'markdown_path' ''))
  $changed = @(
    'logs/review/sonar-readback-latest.json',
    $parityJsonRel,
    $parityMarkdownRel,
    'handoff.latest.json',
    'handoff.latest.md'
  ) | Where-Object { $_ }
  $verified = @([pscustomobject]@{ cmd = $CommandRef; exit = $verifiedExit })
  $refs = @(
    'file:logs/review/sonar-readback-latest.json',
    ('file:' + $parityJsonRel),
    ('file:' + $parityMarkdownRel)
  ) | Where-Object { $_ -and $_ -ne 'file:' }

  $checkpoint = Write-CheckpointArtifacts $summary $state $status $next $stopReason $changed $verified $refs
  $handoff = Get-Prop $checkpoint 'handoff' @{}
  $capsule = Get-Prop $handoff 'capsule' @{}
  $handoff.summary = $summary
  $handoff.status = $status
  $handoff.stop_reason = $stopReason
  $handoff.next_steps = $(if ($next) { @($next) } else { @() })
  $handoff.sonar = $parityPayload

  $mergedRefs = New-Object System.Collections.Generic.List[string]
  foreach ($existingRef in @(Get-Prop $handoff 'refs' @())) {
    $text = [string]$existingRef
    if ($text -and -not $mergedRefs.Contains($text)) {
      $mergedRefs.Add($text)
    }
  }
  foreach ($requiredRef in @($refs)) {
    $text = [string]$requiredRef
    if ($text -and -not $mergedRefs.Contains($text)) {
      $mergedRefs.Add($text)
    }
  }
  $handoff.refs = $mergedRefs.ToArray()

  $capsule.status = $status
  $capsule.goal = $summary
  $capsule.next = $next
  $capsule.changed = $changed
  $capsule.verified = $verified
  $handoff.capsule = $capsule
  Write-HandoffArtifacts $handoff

  return [pscustomobject]@{
    blocking = $blocking
    summary = $summary
    next = $next
    artifacts = $artifacts
    parity = $parityPayload
    handoff = $handoff
  }
}

function Cmd-Dev() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Cmd-DevserverStart
}

function Get-OpenAiSeedRunnerImportReviewStatus([string]$value) {
  $normalized = [string]$value
  if ([string]::IsNullOrWhiteSpace($normalized)) { return "pending" }
  switch ($normalized.Trim().ToLowerInvariant()) {
    "pending" { return "pending" }
    "approved" { return "approved" }
    "rejected" { return "rejected" }
    "imported" { return "imported" }
    default { throw ("openai-seed-runner: unsupported review status '" + $value + "'.") }
  }
}

function Cmd-OpenAiSeedRunner() {
  param([string[]]$CommandArgs)
  Ensure-CoreFolders; Ensure-BootstrapFiles

  $inputPath = "data/openai/CI-021-openai-input.json"
  $budgetUsd = "10.00"
  $keyFile = "D:\_Scripte\_private\OpenAI_API.txt"
  $connectionString = $null
  $reviewStatus = "pending"
  $dryRun = $false
  $skipImport = $false
  $skipStp = $false
  $refreshCache = $false
  $allowShortfall = $true

  for ($index = 0; $index -lt $CommandArgs.Count; $index++) {
    $arg = [string]$CommandArgs[$index]
    switch ($arg) {
      "--input" {
        $index++
        if ($index -ge $CommandArgs.Count) { throw "openai-seed-runner: --input erwartet einen Pfad." }
        $inputPath = [string]$CommandArgs[$index]
      }
      "--budget-usd" {
        $index++
        if ($index -ge $CommandArgs.Count) { throw "openai-seed-runner: --budget-usd erwartet einen Wert." }
        $budgetUsd = [string]$CommandArgs[$index]
      }
      "--key-file" {
        $index++
        if ($index -ge $CommandArgs.Count) { throw "openai-seed-runner: --key-file erwartet einen Pfad." }
        $keyFile = [string]$CommandArgs[$index]
      }
      "--connection-string" {
        $index++
        if ($index -ge $CommandArgs.Count) { throw "openai-seed-runner: --connection-string erwartet einen Wert." }
        $connectionString = [string]$CommandArgs[$index]
      }
      "--review-status" {
        $index++
        if ($index -ge $CommandArgs.Count) { throw "openai-seed-runner: --review-status erwartet einen Wert." }
        $reviewStatus = Get-OpenAiSeedRunnerImportReviewStatus ([string]$CommandArgs[$index])
      }
      "--dry-run" { $dryRun = $true }
      "--skip-import" { $skipImport = $true }
      "--skip-stp" { $skipStp = $true }
      "--refresh-cache" { $refreshCache = $true }
      "--allow-shortfall" { $allowShortfall = $true }
      "--no-allow-shortfall" { $allowShortfall = $false }
      default { throw ("openai-seed-runner: unknown argument '" + $arg + "'.") }
    }
  }

  if ([string]::IsNullOrWhiteSpace($connectionString)) {
    $connectionString = [string]$env:OPENAI_SEED_STAGING_DATABASE_URL
  }
  if ([string]::IsNullOrWhiteSpace($connectionString)) {
    $connectionString = [string]$env:DATABASE_URL
  }
  if ($dryRun -and -not $skipImport -and [string]::IsNullOrWhiteSpace($connectionString)) {
    $skipImport = $true
  }

  $runReportPath = Join-Path $RepoRoot "logs\data\CI-025-openai-seed-run-500.json"
  $runReviewPath = Join-Path $RepoRoot "logs\review\CI-025-openai-seed-run-500.md"
  $importReportPath = Join-Path $RepoRoot "logs\data\CI-025-openai-seed-import-500.json"
  $importReviewPath = Join-Path $RepoRoot "logs\review\CI-025-openai-seed-import-500.md"
  $ts = TsId
  $runLog = Join-Path $LogsRoot ("terminal\openai-seed-runner-" + $ts + ".log")

  $sessionArgs = @(
    "--experimental-transform-types",
    "tools/automation/openai-seed-run-session.ts",
    "--input",
    $inputPath,
    "--run-report",
    $runReportPath,
    "--run-review",
    $runReviewPath,
    "--import-report",
    $importReportPath,
    "--import-review",
    $importReviewPath,
    "--budget-usd",
    $budgetUsd
  )
  if ($dryRun) { $sessionArgs += "--dry-run" }
  if ($skipImport) { $sessionArgs += "--skip-import" }
  if ($refreshCache) { $sessionArgs += "--refresh-cache" }
  if ($allowShortfall) { $sessionArgs += "--allow-shortfall" }
  if (-not [string]::IsNullOrWhiteSpace($keyFile)) {
    $sessionArgs += @("--key-file", $keyFile)
  }
  if (-not [string]::IsNullOrWhiteSpace($connectionString)) {
    $sessionArgs += @("--connection-string", $connectionString)
  }
  if (-not [string]::IsNullOrWhiteSpace($reviewStatus)) {
    $sessionArgs += @("--review-status", $reviewStatus)
  }

  $sessionArgList = @($sessionArgs | ForEach-Object { Quote-PowerShellLiteral ([string]$_) }) -join ", "
  $runCommandLines = @(
    '$ErrorActionPreference = "Stop"',
    ('$repoRoot = ' + (Quote-PowerShellLiteral $RepoRoot)),
    'Set-Location -LiteralPath $repoRoot',
    ('$sessionArgs = @(' + $sessionArgList + ')'),
    '& node @sessionArgs',
    'exit $LASTEXITCODE'
  )
  $terminalTimeouts = @{
    default_timeout_seconds = 14400
    no_output_timeout_seconds = 3600
  }
  $runRes = Run-Cmd ("ps: " + ($runCommandLines -join "`n")) $runLog $null $RepoRoot $terminalTimeouts
  if ($runRes.exit -ne 0) {
    throw ("openai-seed-runner: session failed. See " + $runLog)
  }

  if (-not $skipStp) {
    Cmd-Stp | Out-Null
  }
}

function Get-CodexLoopSyncFiles() {
  return @(
    "handoff.latest.json",
    "handoff.latest.md",
    "todo.current.md",
    "todo.state.json",
    "todo.events.jsonl",
    "todo.master.index.json",
    "todo.history.digest.json",
    ".ci/run/loop.guard.json",
    ".ci/run/route.check.json",
    "logs/verify/verify.digest.json"
  )
}

function Get-ActiveTodoStatus([object]$state, [string]$todoId = $null) {
  $activeId = [string]$todoId
  if (-not $activeId) { $activeId = [string](Get-Prop $state "active_id" $null) }
  $activeStatus = "open"
  if ($state -and $activeId) {
    foreach ($it in @($state.items)) {
      $id = [string](Get-Prop $it "todo_id" (Get-Prop $it "id" ""))
      if ($id -eq $activeId) {
        $activeStatus = [string](Get-Prop $it "status" $activeStatus)
        break
      }
    }
  }
  return @{
    active_id = $activeId
    status = $activeStatus
  }
}

function Write-CheckpointArtifacts(
  [string]$summary,
  [object]$state,
  [string]$status,
  [string]$next = "",
  [string]$stopReason = $null,
  [object[]]$changed = @(),
  [object[]]$verified = @(),
  [object[]]$refs = @()
) {
  $summary = Normalize-HandoffSummaryAnchor $summary
  $now = NowIso
  $agent = Get-AgentId
  $todoContext = Get-ActiveTodoStatus $state
  $activeId = [string](Get-Prop $todoContext "active_id" $null)
  $activeStatus = [string](Get-Prop $todoContext "status" $status)
  $tc = Try-ReadJson (Join-Path $CiRoot "run\toolchain.state.json")
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json")
  $rc = Try-ReadJson (Join-Path $CiRoot "run\route.check.json")
  $git = Get-GitStatusSnapshot
  $proj = (Split-Path $RepoRoot -Leaf)
  $changedFiles = @($changed | ForEach-Object { [string]$_ } | Where-Object { $_ })
  if ($changedFiles.Count -eq 0) { $changedFiles = @($git.changed_files) }
  $verifiedEntries = @($verified)
  $refList = New-Object System.Collections.Generic.List[string]
  foreach ($defaultRef in @("file:todo.current.md", "file:todo.state.json", "file:todo.events.jsonl", "file:todo.master.index.json", "file:handoff.latest.json", "file:handoff.latest.md")) {
    if (-not $refList.Contains($defaultRef)) { $refList.Add($defaultRef) }
  }
  foreach ($extraRef in @($refs)) {
    $text = [string]$extraRef
    if ($text -and -not $refList.Contains($text)) { $refList.Add($text) }
  }

  $capsule = @{
    ts = $now
    agent_id = $agent
    workspace_root = $RepoRoot
    project = $proj
    chat_flow_policy = $script:ChatFlowPolicy
    active_id = $activeId
    status = $activeStatus
    goal = $summary
    changed = $changedFiles
    verified = $verifiedEntries
    route_ok = (Get-Prop $rc "route_ok" $null)
    route_violations = @(Get-Prop $rc "violations" @())
    git = @{
      branch = (Get-Prop $git "branch" $null)
      head = (Get-Prop $git "head" $null)
      ahead_behind = (Get-Prop $git "ahead_behind" "0/0")
    }
    next = $next
    refs = @("todo.current.md", "todo.state.json", "todo.events.jsonl", "todo.master.index.json", "handoff.latest.json", "handoff.latest.md")
    manual_missing = $false
    env_inventory_missing = $false
    env_inventory_used = $false
    env_inventory_path = $null
  }
  if ($stopReason) { $capsule.stop_reason = $stopReason }

  $nextSteps = @()
  if ($next) { $nextSteps = @($next) }

  $handoff = @{
    ts = $now
    agent_id = $agent
    workspace_root = $RepoRoot
    project = $proj
    chat_flow_policy = $script:ChatFlowPolicy
    toolchain = $tc
    active_id = $activeId
    status = $activeStatus
    summary = $summary
    next_steps = $nextSteps
    refs = $refList.ToArray()
    verify_digest = $vd
    route = $rc
    git = $git
    stop_reason = $stopReason
    capsule = $capsule
  }

  Write-HandoffArtifacts $handoff
  return @{
    handoff = $handoff
    capsule = $capsule
    git = $git
  }
}

function New-CodexLoopOutputSchema() {
  $schemaPath = Join-Path $CiRoot "run\codex-loop.output-schema.json"
  $schema = @{
    '$schema' = "https://json-schema.org/draft/2020-12/schema"
    type = "object"
    additionalProperties = $false
    properties = @{
      stop_reason = @{
        type = "string"
        enum = @("slice_done", "real_blocker", "meta_loop_blocked", "resume_missing")
      }
      todo_status = @{
        type = "string"
        enum = @("done", "in-progress", "blocked")
      }
      summary = @{ type = "string" }
      next = @{ type = "string" }
      verified = @{
        type = "array"
        items = @{
          type = "object"
          additionalProperties = $false
          properties = @{
            cmd = @{ type = "string" }
            exit = @{ type = "integer" }
          }
          required = @("cmd", "exit")
        }
      }
      notes = @{
        type = "array"
        items = @{ type = "string" }
      }
    }
    required = @("stop_reason", "todo_status", "summary", "next", "verified", "notes")
  }
  Write-Json $schemaPath $schema
  return $schemaPath
}

function New-CodexLoopPrompt([object]$selection) {
  $promptPath = Join-Path $CiRoot "run\codex-loop.prompt.md"
  $todoId = [string](Get-Prop $selection "todo_id" "")
  $item = Get-Prop $selection "item" $null
  $title = [string](Get-Prop $item "title" "")
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Codex Loop")
  $lines.Add("")
  $lines.Add('Arbeite an genau einem deterministischen Arbeitsslice fuer `' + $todoId + '`.')
  $lines.Add("")
  $lines.Add("## Regeln")
  $lines.Add("")
  $lines.Add("- Bearbeite genau einen atomaren Slice und stoppe danach.")
  $lines.Add('- Kein `supertest` in diesem Lauf.')
  $lines.Add("- Fuehre nur funktionsbezogene Tests aus, wenn du sie fuer den Slice brauchst.")
  $lines.Add('- Aendere diese Statusdateien nicht direkt: `todo.current.md`, `todo.state.json`, `todo.events.jsonl`, `todo.master.index.json`, `handoff.latest.json`, `handoff.latest.md`, `.ci/run/loop.guard.json`.')
  $lines.Add('- Wenn du an einem echten Blocker haengst, gib `stop_reason=real_blocker` zurueck.')
  $lines.Add('- Wenn dir Resume-/Todo-Kontext fehlt oder Meta-Drift blockiert, gib `resume_missing` oder `meta_loop_blocked` zurueck und aendere keine Dateien.')
  $lines.Add('- Wenn der Slice fachlich weitergefuehrt werden kann, gib `stop_reason=slice_done` zurueck.')
  $lines.Add('- `todo_status` darf nur `done`, `in-progress` oder `blocked` sein.')
  $lines.Add("")
  $lines.Add("## Zieltask")
  $lines.Add("")
  $lines.Add('- todo_id: `' + $todoId + '`')
  if ($title) { $lines.Add("- titel: " + $title) }
  $lines.Add("")
  foreach ($path in @("README.md", "Roadmap.md", "todo.current.md", "todo.state.json", "handoff.latest.md")) {
    $abs = Join-Path $RepoRoot $path
    $lines.Add('## Datei: `' + $path + '`')
    $lines.Add("")
    if (Test-Path -LiteralPath $abs) {
      $lines.Add('```text')
      $lines.Add((Get-Content -Raw -LiteralPath $abs))
      $lines.Add('```')
    } else {
      $lines.Add("_fehlt_")
    }
    $lines.Add("")
  }
  Atomic-WriteTextUtf8 $promptPath (($lines -join "`r`n") + "`r`n")
  return $promptPath
}

function Write-CodexLoopReview([object]$guard) {
  $path = Join-Path $LogsRoot "review\\CI-022-codex-loop-contract.md"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# CI-022 Codex Loop Contract")
  $lines.Add("")
  $lines.Add('- ts: `' + [string](Get-Prop $guard "last_ts" "") + '`')
  $lines.Add('- state: `' + [string](Get-Prop $guard "state" "") + '`')
  $lines.Add('- stop_reason: `' + [string](Get-Prop $guard "stop_reason" "") + '`')
  $lines.Add('- active_id: `' + [string](Get-Prop $guard "active_id" "") + '`')
  $codex = Get-Prop $guard "codex" $null
  if ($codex) {
    $lines.Add('- prompt_path: `' + [string](Get-Prop $codex "prompt_path" "") + '`')
    $lines.Add('- output_schema_path: `' + [string](Get-Prop $codex "output_schema_path" "") + '`')
    $lines.Add('- events_path: `' + [string](Get-Prop $codex "events_path" "") + '`')
    $lines.Add('- last_message_path: `' + [string](Get-Prop $codex "last_message_path" "") + '`')
  }
  $resume = Get-Prop $guard "resume_anchor" $null
  if ($resume) {
    $lines.Add("- resume_next: " + [string](Get-Prop $resume "next" ""))
  }
  $lines.Add("")
  $lines.Add('```json')
  $lines.Add((To-Json $guard))
  $lines.Add('```')
  Atomic-WriteTextUtf8 $path (($lines -join "`r`n") + "`r`n")
  return $path
}

function Write-CodexLoopFinishReview([object]$payload) {
  $path = Join-Path $LogsRoot "review\\CI-024-git-autofinish-contract.md"
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# CI-024 Git Auto-Finish Contract")
  $lines.Add("")
  $lines.Add('- ts: `' + (NowIso) + '`')
  $lines.Add('- active_id: `' + [string](Get-Prop $payload "active_id" "") + '`')
  $lines.Add('- commit_message: `' + [string](Get-Prop $payload "commit_message" "") + '`')
  $lines.Add('- log_path: `' + [string](Get-Prop $payload "log_path" "") + '`')
  $lines.Add("")
  $lines.Add("## Staged Files")
  $lines.Add("")
  foreach ($file in @((Get-Prop $payload "staged_files" @()))) {
    $text = [string]$file
    if ($text) { $lines.Add('- `' + $text + '`') }
  }
  $guard = Get-Prop $payload "loop_guard" $null
  if ($guard) {
    $lines.Add("")
    $lines.Add('```json')
    $lines.Add((To-Json $guard))
    $lines.Add('```')
  }
  Atomic-WriteTextUtf8 $path (($lines -join "`r`n") + "`r`n")
  return $path
}

function Cmd-CodexLoop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $requestedTodoId = $null
  foreach ($arg in @($Args)) {
    $text = [string]$arg
    if ($text -and -not $text.StartsWith("-")) {
      $requestedTodoId = $text
      break
    }
  }

  $catalogPath = Write-CodexLoopStopReasonCatalog
  $selection = Resolve-CodexLoopTodoSelection $requestedTodoId
  if (-not (Get-Prop $selection "ok" $false)) {
    $state = Get-Prop $selection "state" (Load-TodoState)
    $summary = [string](Get-Prop $selection "message" "codex-loop blocked")
    $next = "Setze `todo.state.json.active_id` oder starte `#ci codex-loop <TD-...>` mit einem expliziten Zieltask."
    $checkpoint = Write-CheckpointArtifacts $summary $state "blocked" $next ([string](Get-Prop $selection "stop_reason" "meta_loop_blocked")) @("handoff.latest.json", "handoff.latest.md", "todo.current.md", "todo.state.json", "todo.master.index.json") @() @("file:" + (To-RelPath $catalogPath))
    $guard = Load-LoopGuard
    Set-ObjProp $guard "last_ts" (NowIso)
    Set-ObjProp $guard "last_cmd" "codex-loop"
    Set-ObjProp $guard "state" "blocked"
    Set-ObjProp $guard "stop_reason" ([string](Get-Prop $selection "stop_reason" "meta_loop_blocked"))
    Set-ObjProp $guard "active_id" ([string](Get-Prop $selection "previous_active_id" $null))
    Set-ObjProp $guard "last_progress" "blocked"
    Set-ObjProp $guard "resume_anchor" @{ active_id = [string](Get-Prop $selection "previous_active_id" $null); next = $next; stop_reason = [string](Get-Prop $selection "stop_reason" "meta_loop_blocked") }
    Set-ObjProp $guard "codex" @{}
    Set-ObjProp $guard "git" (Get-Prop $checkpoint "git" @{})
    Set-ObjProp $guard "supported_stop_reasons" (Get-CodexLoopStopReasons)
    Save-LoopGuard $guard
    $reviewPath = Write-CodexLoopReview $guard
    Append-TodoEvent @{
      ts = NowIso
      type = "loop_stop"
      todo_id = [string](Get-Prop $selection "previous_active_id" "SYSTEM")
      status = "blocked"
      prio = "high"
      source = "codex-loop"
      msg = $summary
      stop_reason = [string](Get-Prop $selection "stop_reason" "meta_loop_blocked")
      refs = @("file:handoff.latest.json", "file:handoff.latest.md", "file:" + (To-RelPath $catalogPath), "file:" + (To-RelPath $reviewPath))
      changed = @("handoff.latest.json", "handoff.latest.md", "todo.current.md", "todo.state.json", "todo.master.index.json", ".ci/run/loop.guard.json")
      verified = @()
      git = @{
        branch = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "branch" "")
        head = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "head" "")
        ahead_behind = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "ahead_behind" "0/0")
      }
    } | Out-Null
    throw ("codex-loop blocked: " + $summary)
  }

  $null = Set-CodexLoopFocus (Get-Prop $selection "state" $null) ([string](Get-Prop $selection "todo_id" ""))
  $promptPath = New-CodexLoopPrompt $selection
  $schemaPath = New-CodexLoopOutputSchema
  $ts = TsId
  $eventsPath = Join-Path $CiRoot ("run\\codex-loop-events-" + $ts + ".jsonl")
  $lastMessagePath = Join-Path $CiRoot ("run\\codex-loop-last-" + $ts + ".json")
  $logPath = Join-Path $LogsRoot ("terminal\\codex-loop-" + $ts + ".log")
  $commandLines = @(
    '$ErrorActionPreference = "Stop"',
    ('$prompt = Get-Content -Raw -LiteralPath ' + (Quote-PowerShellLiteral $promptPath)),
    ('$eventsPath = ' + (Quote-PowerShellLiteral $eventsPath)),
    ('$lastMessagePath = ' + (Quote-PowerShellLiteral $lastMessagePath)),
    ('$schemaPath = ' + (Quote-PowerShellLiteral $schemaPath)),
    ('$repoRoot = ' + (Quote-PowerShellLiteral $RepoRoot)),
    'if (Test-Path -LiteralPath $eventsPath) { Remove-Item -Force -LiteralPath $eventsPath }',
    '$prompt | codex exec --json --output-schema $schemaPath -o $lastMessagePath --dangerously-bypass-approvals-and-sandbox -C $repoRoot - 2>&1 | Tee-Object -FilePath $eventsPath',
    'exit $LASTEXITCODE'
  )
  $res = Run-Cmd ("ps: " + ($commandLines -join "`n")) $logPath

  $result = Try-ReadJson $lastMessagePath
  if ($null -eq $result) {
    $result = @{
      stop_reason = "real_blocker"
      todo_status = "blocked"
      summary = "codex-loop lieferte keine parsebare Abschlussnachricht."
      next = "Pruefe `logs/terminal/codex-loop-*.log` und `.ci/run/codex-loop-events-*.jsonl`."
      verified = @()
      notes = @("missing_or_invalid_output_schema_result")
    }
  }

  $stopReason = [string](Get-Prop $result "stop_reason" "real_blocker")
  $todoStatus = [string](Get-Prop $result "todo_status" "blocked")
  if ($res.exit -ne 0 -and $stopReason -eq "slice_done") {
    $stopReason = "real_blocker"
    $todoStatus = "blocked"
  }

  $summary = [string](Get-Prop $result "summary" "codex-loop abgeschlossen")
  $next = [string](Get-Prop $result "next" "")
  $verified = @()
  foreach ($entry in @((Get-Prop $result "verified" @()))) {
    $verified += @{
      cmd = [string](Get-Prop $entry "cmd" "")
      exit = [int](Get-Prop $entry "exit" 0)
    }
  }

  $null = Apply-CodexLoopTodoResult ([string](Get-Prop $selection "todo_id" "")) $todoStatus $stopReason $summary $next ([string](Get-Prop $selection "previous_active_id" $null))
  $state = Load-TodoState
  $checkpoint = Write-CheckpointArtifacts $summary $state $todoStatus $next $stopReason @() $verified @("file:" + (To-RelPath $promptPath), "file:" + (To-RelPath $schemaPath), "file:" + (To-RelPath $eventsPath), "file:" + (To-RelPath $lastMessagePath), "file:" + (To-RelPath $catalogPath))
  $git = Get-Prop $checkpoint "git" @{}
  $guard = Load-LoopGuard
  Set-ObjProp $guard "last_ts" (NowIso)
  Set-ObjProp $guard "last_cmd" "codex-loop"
  Set-ObjProp $guard "state" $(if ($stopReason -eq "slice_done") { "completed" } else { "blocked" })
  Set-ObjProp $guard "stop_reason" $stopReason
  Set-ObjProp $guard "active_id" [string](Get-Prop (Get-ActiveTodoStatus $state) "active_id" $null)
  Set-ObjProp $guard "last_progress" $(if ($stopReason -eq "slice_done") { $(if (@(Get-Prop $git "changed_files" @()).Count -gt 0) { "changed" } else { "evidence" }) } else { "blocked" })
  Set-ObjProp $guard "resume_anchor" @{ active_id = [string](Get-Prop (Get-ActiveTodoStatus $state) "active_id" $null); next = $next; stop_reason = $stopReason }
  Set-ObjProp $guard "codex" @{
    prompt_path = (To-RelPath $promptPath)
    output_schema_path = (To-RelPath $schemaPath)
    events_path = (To-RelPath $eventsPath)
    last_message_path = (To-RelPath $lastMessagePath)
    exit_code = $res.exit
  }
  Set-ObjProp $guard "git" $git
  Set-ObjProp $guard "supported_stop_reasons" (Get-CodexLoopStopReasons)
  Save-LoopGuard $guard
  $reviewPath = Write-CodexLoopReview $guard
  $changedFiles = @((Get-Prop $git "changed_files" @()))
  foreach ($metaFile in @("handoff.latest.json", "handoff.latest.md", "todo.current.md", "todo.state.json", "todo.master.index.json", ".ci/run/loop.guard.json")) {
    if ($metaFile -and ($changedFiles -notcontains $metaFile)) { $changedFiles += $metaFile }
  }
  Append-TodoEvent @{
    ts = NowIso
    type = "loop_stop"
    todo_id = [string](Get-Prop $selection "todo_id" "")
    status = (Normalize-TodoStatus $todoStatus "blocked")
    prio = "low"
    source = "codex-loop"
    msg = $summary
    stop_reason = $stopReason
    refs = @("file:handoff.latest.json", "file:handoff.latest.md", "file:" + (To-RelPath $reviewPath), "file:" + (To-RelPath $catalogPath))
    changed = $changedFiles
    verified = $verified
    git = @{
      branch = [string](Get-Prop $git "branch" "")
      head = [string](Get-Prop $git "head" "")
      ahead_behind = [string](Get-Prop $git "ahead_behind" "0/0")
    }
  } | Out-Null

  if ($stopReason -ne "slice_done") {
    throw ("codex-loop blocked: " + $summary)
  }
}

function Cmd-CodexLoopFinish() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $guard = Load-LoopGuard
  $guardState = [string](Get-Prop $guard "state" "")
  $stopReason = [string](Get-Prop $guard "stop_reason" "")
  if ($guardState -ne "completed" -or $stopReason -ne "slice_done") {
    throw "codex-loop-finish: loop.guard is not in a finishable slice_done state."
  }

  foreach ($requiredFile in @("handoff.latest.json", "handoff.latest.md", "todo.current.md", "todo.state.json", "todo.events.jsonl")) {
    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $requiredFile))) {
      throw ("codex-loop-finish: missing required sync file '" + $requiredFile + "'.")
    }
  }

  $handoff = Try-ReadJson (Join-Path $RepoRoot "handoff.latest.json")
  $handoffTs = [string](Get-Prop $handoff "ts" "")
  $loopTs = [string](Get-Prop $guard "last_ts" "")
  if ($loopTs -and $handoffTs -and ($handoffTs -lt $loopTs)) {
    throw "codex-loop-finish: handoff.latest.json is older than the current loop.guard state."
  }

  Cmd-RouteCheck
  $routePayload = Try-ReadJson (Join-Path $CiRoot "run\route.check.json")
  $routeLogRel = [string](Get-Prop (Get-Prop $routePayload "git" $null) "diff_log" "")
  if ($routeLogRel) {
    $routeLogPath = Join-Path $RepoRoot $routeLogRel
    if (Test-Path -LiteralPath $routeLogPath) {
      try { Remove-Item -Force -LiteralPath $routeLogPath } catch { $null = $_ }
    }
  }

  $activeId = [string](Get-Prop $guard "active_id" "")
  $commitMessage = "ci(loop): finish " + $(if ($activeId) { $activeId } else { "slice" })
  $ts = TsId
  $logPath = Join-Path $LogsRoot ("terminal\\codex-loop-finish-" + $ts + ".log")
  Set-ObjProp $guard "finish_ts" (NowIso)
  Set-ObjProp $guard "state" "finishing"
  Set-ObjProp $guard "finish_log_path" (To-RelPath $logPath)
  Save-LoopGuard $guard
  $reviewPath = Write-CodexLoopFinishReview @{
    active_id = $activeId
    commit_message = $commitMessage
    staged_files = @()
    log_path = (To-RelPath $logPath)
    loop_guard = $guard
  }
  Append-TodoEvent @{
    ts = NowIso
    type = "loop_finish"
    todo_id = $(if ($activeId) { $activeId } else { "SYSTEM" })
    status = "done"
    prio = "low"
    source = "codex-loop-finish"
    msg = "git-safe loop finish prepared"
    refs = @("file:" + (To-RelPath $reviewPath), "file:handoff.latest.json", "file:handoff.latest.md")
    changed = @(".ci/run/loop.guard.json", "todo.events.jsonl", (To-RelPath $reviewPath))
    verified = @(
      @{ cmd = "cmd /c .\\ci.cmd route-check"; exit = 0 }
    )
    git = @{
      branch = [string](Get-Prop (Get-GitStatusSnapshot) "branch" "")
      head = [string](Get-Prop (Get-GitStatusSnapshot) "head" "")
      ahead_behind = [string](Get-Prop (Get-GitStatusSnapshot) "ahead_behind" "0/0")
    }
  } | Out-Null

  $gitBefore = Get-GitStatusSnapshot
  $allowed = New-Object System.Collections.Generic.List[string]
  foreach ($path in @((Get-Prop (Get-Prop $guard "git" $null) "changed_files" @()))) {
    $text = Normalize-RoutePath ([string]$path)
    if ($text -and -not $allowed.Contains($text)) { $allowed.Add($text) }
  }
  foreach ($path in (Get-CodexLoopSyncFiles)) {
    $text = Normalize-RoutePath ([string]$path)
    if ($text -and -not $allowed.Contains($text)) { $allowed.Add($text) }
  }
  foreach ($path in @((To-RelPath $reviewPath))) {
    $text = Normalize-RoutePath ([string]$path)
    if ($text -and -not $allowed.Contains($text)) { $allowed.Add($text) }
  }

  $unexpected = New-Object System.Collections.Generic.List[string]
  foreach ($path in @((Get-Prop $gitBefore "changed_files" @()))) {
    $normalized = Normalize-RoutePath ([string]$path)
    if ($normalized -and -not $allowed.Contains($normalized)) { $unexpected.Add($normalized) }
  }
  if ($unexpected.Count -gt 0) {
    throw ("codex-loop-finish: unexpected worktree drift outside the current slice: " + ($unexpected -join ", "))
  }

  $stageFiles = New-Object System.Collections.Generic.List[string]
  foreach ($path in @((Get-Prop $gitBefore "changed_files" @()))) {
    $normalized = Normalize-RoutePath ([string]$path)
    if ($normalized -and $allowed.Contains($normalized) -and -not $stageFiles.Contains($normalized)) {
      $stageFiles.Add($normalized)
    }
  }
  if ($stageFiles.Count -eq 0) {
    throw "codex-loop-finish: no finishable file set found in git status."
  }

  $reviewPath = Write-CodexLoopFinishReview @{
    active_id = $activeId
    commit_message = $commitMessage
    staged_files = $stageFiles.ToArray()
    log_path = (To-RelPath $logPath)
    loop_guard = $guard
  }
  $stageLiteralList = @($stageFiles | ForEach-Object { Quote-PowerShellLiteral $_ }) -join ", "
  $commandLines = @(
    '$ErrorActionPreference = "Stop"',
    ('$repoRoot = ' + (Quote-PowerShellLiteral $RepoRoot)),
    ('$paths = @(' + $stageLiteralList + ')'),
    'Set-Location -LiteralPath $repoRoot',
    'git -c core.pager=cat -c color.ui=false --no-pager add -- @paths',
    ('git -c core.pager=cat -c color.ui=false --no-pager commit -m ' + (Quote-PowerShellLiteral $commitMessage)),
    'git -c core.pager=cat -c color.ui=false --no-pager push'
  )
  $res = Run-Cmd ("ps: " + ($commandLines -join "`n")) $logPath
  if ($res.exit -ne 0) {
    throw ("codex-loop-finish: git commit/push failed. See " + $logPath)
  }

  $gitAfter = Get-GitStatusSnapshot
  if (@((Get-Prop $gitAfter "changed_files" @())).Count -gt 0) {
    throw "codex-loop-finish: worktree is not clean after commit/push."
  }
}

function Cmd-CodexLoopAuto() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Cmd-CodexLoop

  $guard = Load-LoopGuard
  $guardState = [string](Get-Prop $guard "state" "")
  $stopReason = [string](Get-Prop $guard "stop_reason" "")
  if ($guardState -ne "completed" -or $stopReason -ne "slice_done") {
    throw "codex-loop-auto: loop is not in a finishable slice_done state."
  }

  Cmd-Stp | Out-Null
  Cmd-CodexLoopFinish
}

function Cmd-Stp() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $sonarGuard = Sync-SonarParityCheckpoint -CommandRef 'cmd /c .\ci.cmd stp' -BaseExit 0
  if ($sonarGuard) {
    $now = NowIso
    $handoff = Get-Prop $sonarGuard 'handoff' @{}
    $capsule = Get-Prop (Get-Prop $sonarGuard 'handoff' @{}) 'capsule' @{}
    $todoIdForEv = "SYSTEM"; $activeId = [string](Get-Prop $capsule "active_id" $null); if ($activeId) { $todoIdForEv = $activeId }
    $activeStatus = [string](Get-Prop $capsule "status" "open")
    $ev = $null; try { $ev = Append-TodoEvent @{ ts=$now; type="stp"; todo_id=$todoIdForEv; status=$activeStatus; prio="low"; source="stp"; msg=([string](Get-Prop $handoff "summary" "sync checkpoint")); refs=@("file:todo.events.jsonl","file:handoff.latest.json","file:handoff.latest.md"); changed=@((Get-Prop $capsule "changed" @())); verified=@((Get-Prop $capsule "verified" @())); git=@{ branch = [string](Get-Prop (Get-Prop $handoff "git" $null) "branch" ""); head = [string](Get-Prop (Get-Prop $handoff "git" $null) "head" ""); ahead_behind = [string](Get-Prop (Get-Prop $handoff "git" $null) "ahead_behind" "0/0") } } } catch { $null = $_ }
    try { $eid = $null; if ($ev) { $eid = [string](Get-Prop $ev "event_id" $null) }; if (-not $eid) { $eid = New-EventId }; Append-ChatHistoryLine @{ ts=$now; event_id=$eid; todo_id=$todoIdForEv; summary=([string](Get-Prop $handoff "summary" "sync checkpoint")); refs=@("file:todo.events.jsonl","file:handoff.latest.json") } } catch { $null = $_ }
    Cmd-WsLockRelease | Out-Null
    Write-Output ("CAPSULE:" + (To-Json $capsule))
    return
  }
  $now = NowIso; $st = $null
  try { $st = Load-TodoState } catch { $st = $null }
  if ($st) { try { Save-TodoState $st } catch { $null = $_ } }
  $checkpoint = Write-CheckpointArtifacts "stp sync" $st "open" "" $null @() @() @("file:logs/verify/verify.digest.json")
  $capsule = Get-Prop $checkpoint "capsule" @{}
  $todoIdForEv = "SYSTEM"; $activeId = [string](Get-Prop $capsule "active_id" $null); if ($activeId) { $todoIdForEv = $activeId }
  $activeStatus = [string](Get-Prop $capsule "status" "open")
  $ev = $null; try { $ev = Append-TodoEvent @{ ts=$now; type="stp"; todo_id=$todoIdForEv; status=$activeStatus; prio="low"; source="stp"; msg="sync checkpoint"; refs=@("file:todo.events.jsonl","file:handoff.latest.json","file:handoff.latest.md"); changed=@((Get-Prop $capsule "changed" @())); verified=@((Get-Prop $capsule "verified" @())); git=@{ branch = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "branch" ""); head = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "head" ""); ahead_behind = [string](Get-Prop (Get-Prop $checkpoint "git" $null) "ahead_behind" "0/0") } } } catch { $null = $_ }
  try { $eid = $null; if ($ev) { $eid = [string](Get-Prop $ev "event_id" $null) }; if (-not $eid) { $eid = New-EventId }; Append-ChatHistoryLine @{ ts=$now; event_id=$eid; todo_id=$todoIdForEv; summary="stp sync"; refs=@("file:todo.events.jsonl","file:handoff.latest.json") } } catch { $null = $_ }
  Cmd-WsLockRelease | Out-Null; Write-Output ("CAPSULE:" + (To-Json $capsule))
}

function Cmd-Menu() {
@"
#ci start              (bootstrap + lock + preflight + doctor)
#ci menu               (Kurzmenü)
#ci bootstrap          (create-if-missing: CI-Ordner + Truth-Dateien + Stubs)
#ci ws-lock-acquire    (Workspace exklusiv sperren)
#ci ws-lock-release    (Workspace-Sperre lösen)
#ci preflight          (Daemons stoppen, Basischecks)
#ci deps-bootstrap     (Portable Toolchain sicherstellen)
#ci verify             (Node: lint+build+test:functions; Gradle: check; unknown => self-check)
#ci self-check         (Invarianten + Truth-Dateien prüfen)
#ci gradle-autopsy     (Verify + Eskalation bis Stufe 2; tolerant)
#ci lock-triage        (Windows Lock Evidence sammeln)
#ci observer-baseline  (Baseline Hashes erzeugen)
#ci observer-check     (Diff gegen Baseline)
#ci patch-apply        (1 Patch dry-run+apply, danach Verify)
#ci restore-immutables  (Immutable Dateien aus Snapshot zurückspielen)
#ci route-check        (Verify-Gate prüfen)
#ci ci050-ui-release-gate (Fail-closed UI Release Gate)
#ci codex-loop         (Headless Codex-Slice fuer genau einen Todo-Task)
#ci codex-loop-finish  (Git-sicherer STP/Commit/Push-Abschluss fuer den letzten Slice)
#ci codex-loop-auto    (codex-loop plus unmittelbares codex-loop-finish)
#ci browser-smoke      (Browser-Smoke via config/contract)
#ci dev                (Alias fuer devserver-start)
#ci openai-seed-runner (CLI-Only 500er Seed-Run inkl. Autark-Fetch, Import/STP)
#ci devserver-start    (Gradle Devserver detached + devserver.log)
#ci devserver-stop     (Stop Gradle Devserver)
#ci devserver-status   (Status Gradle Devserver)
#ci sonar              (Alias fuer npm run sonar)
#ci pyserver-start     (Python http.server detached; auto-detect dist)
#ci pyserver-stop      (Stop Python http.server)
#ci pyserver-status    (Status Python http.server)
#ci scholars           (Schäfermatt UI Test)
#ci t                  (Kurzform für scholars)
#ci t2                 (Master-Validierung)
#ci supertest          (verify + lokaler Smoke + build:release + Deploy + produktiver Live-Smoke)
#ci todo-seed          (Roadmap -> todo.state.json, wenn leer)
#ci todo-compact       (todo.state.json normalisieren)
#ci todo-prune         (done-events aus todo.events.jsonl entfernen)
#ci todo-rotate        (todo.events.jsonl rotieren + checkpoint)
#ci todo-rebuild       (todo.state.json aus checkpoint)
#ci todo-sanitize      (Truth-Dateien reparieren / rerender)
#ci doctor             (Status/Toolchain anzeigen)
#ci env-inventory      (Umgebungs-Snapshot schreiben)
#ci stp                (Sync-Checkpoint: Handoff + CAPSULE schreiben)
#ci event <chat|terminal> "<msg>" (Event loggt; optional auto-tick)
#ci tick               (Observer Tick; triggert critic bei Bedarf)
#ci o                  (Kurzsignal: tick --force)
#ci critic             (OpenAI Critic Call; schreibt logs/critic/*)
#ci autopatch          (Patch aus critic.latest.json -> .ci/inbox -> patch-apply)
#ci drift-check        (immutables + observer-check + route-check)
#ci observerd-start    (Daemon: tick zyklisch)
#ci observerd-status   (Daemon status)
#ci observerd-stop     (Daemon stoppen)
"@
}

function Write-AutoCheckpoint([string]$cmdName, [string]$status, [string]$errorMsg=$null) {
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json")
  $fb = Try-ReadJson (Join-Path $LogsRoot "verify\failbundle-latest.json")
  $summary = "auto checkpoint after " + $cmdName
  if ($errorMsg) { $summary = "blocked: " + $cmdName }
  $next = ""
  if ($status -eq "blocked") { $next = "Open `logs/verify/failbundle-latest.json`, fuehre bei Lock-Indizien `#ci lock-triage` aus und synchronisiere danach per `#ci stp`." } else { $next = "Run `#ci doctor` und synchronisiere bei Bedarf per `#ci stp`." }
  $state = $null
  try { $state = Load-TodoState } catch { $state = $null }
  $checkpoint = Write-CheckpointArtifacts $summary $state $status $next $null @() @() @()
  $handoff = Get-Prop $checkpoint "handoff" @{}
  $handoff.last_cmd = $cmdName
  $handoff.failbundle = $fb
  $handoff.evidence_refs = @((Get-Prop $vd "log_path" $null), (Get-Prop $fb "log_path" $null), $script:LastCmdLogPath) | Where-Object { $_ }
  Write-HandoffArtifacts $handoff
}

function Cmd-Start() {
  Cmd-Bootstrap; $cfg = Try-ReadJson (Get-ConfigPath); $wl = Get-Prop $cfg "workspace_lock" $null; $lockOn = $true
  try { $lockOn = [bool](Get-Prop $wl "on" $true) } catch { $lockOn = $true }; if ($lockOn) { Cmd-WsLockAcquire }
  Cmd-Preflight; try { Update-ManualDigest } catch { $null = $_ }; try { Update-EnvInventoryDigest } catch { $null = $_ }; Cmd-Doctor
}

function Cmd-Bootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-ProjectStubs
  if ($script:ImmutablePinsCreatedBeforeLoad) {
    try { Pin-ImmutableFiles | Out-Null } catch { throw ("bootstrap: could not complete immutable pins: " + $_.Exception.Message) }
    try { Assert-ImmutableClean "bootstrap" } catch { throw $_ }
  } elseif (-not (Test-Path -LiteralPath (Get-ImmutablePinsPath))) {
    try { Pin-ImmutableFiles | Out-Null } catch { throw ("bootstrap: could not pin immutables: " + $_.Exception.Message) }
    if (-not (Test-Path -LiteralPath (Get-ImmutablePinsPath))) { throw "bootstrap: immutable pins missing after pin attempt" }
    try { Assert-ImmutableClean "bootstrap" } catch { throw $_ }
  } else { try { Assert-ImmutableClean "bootstrap" } catch { throw $_ } }
  $st = Load-TodoState; if (@($st.items).Count -eq 0) { try { Cmd-TodoSeed } catch { CI-Info ("WARN: bootstrap: todo seed failed (ignored): " + $_.Exception.Message) } }
  CI-Info "bootstrap: ok"
}

function Cmd-Doctor() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; try { $st = Load-TodoState; if (@($st.items).Count -eq 0) { Cmd-TodoSeed } } catch { $null = $_ }; $bs = Detect-BuildSystem; $min = Get-JavaMinMajor; try { $null = Ensure-JavaReady } catch { $null = $_ }; $src  = [string](HGet $script:JavaSelection "source" "unknown"); $maj  = HGet $script:JavaSelection "major" $null; $jdkHome = [string](HGet $script:JavaSelection "jdkHome" $null); $jtxt = [string](HGet $script:JavaSelection "java_version_text" $null); $whereJava = @(); try { $whereJava = (& where.exe java 2>$null) } catch { $whereJava = @() }; $g = $null; $mode = "n/a"; $cmd  = "n/a"
  if ($bs -eq "gradle") { $g = Get-GradleCmdRaw; if ($g -and $g.cmd) { Persist-GradleInfo $g.mode $g.cmd; $mode = $g.mode; $cmd = $g.cmd } }
  $lines = New-Object System.Collections.Generic.List[string]; $lines.Add("repo_root: " + $RepoRoot); $lines.Add("build_system: " + $bs); $lines.Add(""); $lines.Add("java.min_major: " + $min); $lines.Add("java.source: " + $src); if ($maj)  { $lines.Add("java.major: " + $maj) }; if ($jdkHome) { $lines.Add("java.jdkHome: " + $jdkHome) }; if ($whereJava -and $whereJava.Count -gt 0) { $lines.Add("java.where: " + ($whereJava -join "; ")) }; if ($jtxt) { $lines.Add("java.version: " + (($jtxt -split "`r?`n")[0])) }; $lines.Add(""); $lines.Add("gradle.wrapper_ok: " + (Wrapper-Ok)); $lines.Add("gradle.mode: " + $mode); $lines.Add("gradle.cmd: " + $cmd); $lines.Add("gradle.user_home: " + (Join-Path $CiRoot "run\gradle-user-home")); $lines.Add(""); $lines.Add("ci.config: " + (Get-ConfigPath)); $lines.Add("toolchain.state: " + (Join-Path $CiRoot "run\toolchain.state.json")); $lines.Add("verify.digest: " + (Join-Path $LogsRoot "verify\verify.digest.json")); $lines.Add("handoff.latest: " + (Join-Path $RepoRoot "handoff.latest.json"))
  return ($lines -join "`r`n")
}

function Cmd-EnvInventory() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; try { $null = Ensure-JavaReady } catch { $null = $_ }; $ts = TsId; $whereJava = @(); try { $whereJava = (& where.exe java 2>$null) } catch { $whereJava = @() }; $javaVer = $null; try { $javaVer = (& java -version 2>&1 | Out-String).Trim() } catch { $javaVer = $null }; $whereGradle = @(); try { $whereGradle = (& where.exe gradle 2>$null) } catch { $whereGradle = @() }; $gradleVer = $null; try { $gradleVer = (& gradle -v 2>&1 | Out-String).Trim() } catch { $gradleVer = $null }; $whereNode = @(); try { $whereNode = (& where.exe node 2>$null) } catch { $whereNode = @() }; $nodeVer = $null; try { $nodeVer = (& node -v 2>$null | Out-String).Trim() } catch { $nodeVer = $null }; $os = $null; try { $os = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop) } catch { $os = $null }
  $payload = @{ ts=NowIso; agent_id=(Get-AgentId); workspace_root=$RepoRoot; ps_version=("$($PSVersionTable.PSVersion)"); os_caption=$(if ($os) { [string]$os.Caption } else { $null }); os_version=$(if ($os) { [string]$os.Version } else { [string][Environment]::OSVersion.VersionString }); java=@{ where=$whereJava; version_text=$javaVer; env_java_home=([string]$env:JAVA_HOME); selection=$script:JavaSelection }; gradle=@{ where=$whereGradle; version_text=$gradleVer; wrapper_ok=(Wrapper-Ok) }; node=@{ where=$whereNode; version_text=$nodeVer } }
  $jsonPath = Join-Path $LogsRoot ("terminal\env-inventory-" + $ts + ".json"); Write-Json $jsonPath $payload; $md = New-Object System.Collections.Generic.List[string]; $md.Add('# env-inventory.snapshot.md'); $md.Add(''); $md.Add("- ts: " + $payload.ts); $md.Add("- agent_id: " + $payload.agent_id); $md.Add("- workspace_root: " + $payload.workspace_root); $md.Add("- ps_version: " + $payload.ps_version); if ($payload.os_caption) { $md.Add("- os: " + $payload.os_caption + " (" + $payload.os_version + ")") } else { $md.Add("- os: " + $payload.os_version) }; $md.Add(''); $md.Add('## Java'); $md.Add("selection: " + (To-Json $payload.java.selection)); $md.Add(''); $md.Add('```text'); $md.Add('where java:'); foreach ($l in $whereJava) { $md.Add($l) }; $md.Add(''); $md.Add('java -version:'); if ($javaVer) { $md.Add($javaVer) }; $md.Add(''); $md.Add("JAVA_HOME: " + [string]$env:JAVA_HOME); $md.Add('```'); $md.Add(''); $md.Add('## Gradle'); $md.Add("wrapper_ok: " + (Wrapper-Ok)); $md.Add('```text'); $md.Add('where gradle:'); foreach ($l in $whereGradle) { $md.Add($l) }; $md.Add(''); $md.Add('gradle -v:'); if ($gradleVer) { $md.Add($gradleVer) }; $md.Add('```'); $md.Add(''); $md.Add('## Node'); $md.Add('```text'); $md.Add('where node:'); foreach ($l in $whereNode) { $md.Add($l) }; $md.Add(''); $md.Add('node -v:'); if ($nodeVer) { $md.Add($nodeVer) }; $md.Add('```'); $md.Add(''); $mdPath = Join-Path $RepoRoot "env-inventory.snapshot.md"; Atomic-WriteTextUtf8 $mdPath (($md -join "`r`n") + "`r`n"); CI-Info ("env-inventory: wrote " + $mdPath + " and " + $jsonPath)
}

function Cmd-RestoreImmutables() {
  throw "restore-immutables must be handled by ci.ps1 before module load"
}

function Cmd-RepinImmutables() {
  throw "repin-immutables/runtime-update must be handled by ci.ps1 before module load"
}

function Cmd-DepsBootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $bs = Detect-BuildSystem; CI-Info ("deps-bootstrap: build_system=" + $bs); $envMap = Ensure-JavaReady; $src  = [string](HGet $script:JavaSelection "source" "unknown"); $maj  = HGet $script:JavaSelection "major" $null; $jdkHome = [string](HGet $script:JavaSelection "jdkHome" $null); $msg = "deps-bootstrap: java_source=" + $src; if ($maj)  { $msg += " java_major=" + $maj }; if ($jdkHome) { $msg += " java_home=" + $jdkHome }; CI-Info $msg
  if ($bs -eq "gradle" -or (Is-GradleRequired)) { $ver = Get-GradleDesiredVersion; try { $bat = Ensure-LocalGradleDist $ver; Persist-GradleInfo "local-dist" $bat (Get-GradleProjectRoot); CI-Info ("deps-bootstrap: gradle dist ok cmd=" + $bat) } catch { Report-Priority "toolchain.gradle" ("Gradle provisioning failed: " + $_.Exception.Message) @{ step="deps-bootstrap"; version=$ver }; throw }; if (Is-GradleProject) { Ensure-GradleWrapper; CI-Info ("deps-bootstrap: gradle wrapper ok=" + (Wrapper-Ok (Get-GradleProjectRoot))) } else { CI-Warn "deps-bootstrap: gradle build markers not found yet (wrapper not generated)." } }
}

function Cmd-GradleBootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Cmd-Preflight; $ver = Get-GradleDesiredVersion; $root = Get-GradleProjectRoot; if (-not $root) { $root = $RepoRoot }; CI-Info ("gradle-bootstrap: desired_version=" + $ver + " root=" + $root); $bat = $null
  try { $bat = Ensure-LocalGradleDist $ver; Persist-GradleInfo "local-dist" $bat $root } catch { Report-Priority "toolchain.gradle" ("Gradle provisioning failed: " + $_.Exception.Message) @{ step="gradle-bootstrap"; version=$ver; root=$root }; throw }; if (Is-GradleProject) { try { Ensure-GradleWrapper } catch { Report-Priority "toolchain.gradle" ("Gradle wrapper repair failed: " + $_.Exception.Message) @{ step="wrapper"; version=$ver; root=$root }; throw } } else { CI-Warn "gradle-bootstrap: no Gradle build markers found yet (wrapper not generated)." }; CI-Info "gradle-bootstrap: ok"
}

Register-CiCommand "start" { Cmd-Start }
Register-CiCommand "bootstrap" { Cmd-Bootstrap }
Register-CiCommand "ws-lock-acquire" { Cmd-WsLockAcquire; CI-Info "ws-lock-acquire: ok" }
Register-CiCommand "ws-lock-release" { Cmd-WsLockRelease; CI-Info "ws-lock-release: ok" }
Register-CiCommand "preflight" { Cmd-Preflight }
Register-CiCommand "deps-bootstrap" { Cmd-DepsBootstrap }
Register-CiCommand "verify" { Cmd-Verify 0 }
Register-CiCommand "self-check" { Cmd-SelfCheck }
Register-CiCommand "gradle-autopsy" { Cmd-GradleAutopsy }
Register-CiCommand "gradle-bootstrap" { Cmd-GradleBootstrap }
Register-CiCommand "lock-triage" { Cmd-LockTriage }
Register-CiCommand "observer-baseline" { Cmd-ObserverBaseline }
Register-CiCommand "observer-check" { Cmd-ObserverCheck }
Register-CiCommand "patch-apply" { Cmd-PatchApply }
Register-CiCommand "restore-immutables" { Cmd-RestoreImmutables }
Register-CiCommand "repin-immutables" { Cmd-RepinImmutables }
Register-CiCommand "runtime-update" { Cmd-RepinImmutables }
Register-CiCommand "route-check" { Cmd-RouteCheck }
Register-CiCommand "ci050-ui-release-gate" { Cmd-Ci050UiReleaseGate }
Register-CiCommand "codex-loop" { Cmd-CodexLoop }
Register-CiCommand "codex-loop-finish" { Cmd-CodexLoopFinish }
Register-CiCommand "codex-loop-auto" { Cmd-CodexLoopAuto }
Register-CiCommand "browser-smoke" { Cmd-BrowserSmoke }
Register-CiCommand "dev" { Cmd-Dev }
Register-CiCommand "openai-seed-runner" { Cmd-OpenAiSeedRunner $script:CiCommandArgs }
Register-CiCommand "seed-runner" { Cmd-OpenAiSeedRunner $script:CiCommandArgs }
Register-CiCommand "devserver-start" { Cmd-DevserverStart }
Register-CiCommand "devserver-stop" { Cmd-DevserverStop }
Register-CiCommand "devserver-status" { Cmd-DevserverStatus }
Register-CiCommand "sonar" { Cmd-Sonar }
Register-CiCommand "pyserver-start" { Cmd-PyserverStart }
Register-CiCommand "pyserver-stop" { Cmd-PyserverStop }
Register-CiCommand "pyserver-status" { Cmd-PyserverStatus }
Register-CiCommand "todo-seed" { Cmd-TodoSeed }
Register-CiCommand "todo-compact" { Cmd-TodoCompact }
Register-CiCommand "todo-prune" { Cmd-TodoPrune }
Register-CiCommand "todo-rotate" { Cmd-TodoRotate }
Register-CiCommand "todo-rebuild" { Cmd-TodoRebuild }
Register-CiCommand "todo-sanitize" { Cmd-TodoSanitize }
Register-CiCommand "doctor" { Cmd-Doctor }
Register-CiCommand "env-inventory" { Cmd-EnvInventory }
Register-CiCommand "event" { Cmd-Event $Args }
Register-CiCommand "tick" { Cmd-Tick $Args }
Register-CiCommand "o" { Cmd-Tick @("--force") }
Register-CiCommand "obs" { Cmd-Tick @("--force") }
Register-CiCommand "critic" { Cmd-Critic }
Register-CiCommand "autopatch" { Cmd-Autopatch }
Register-CiCommand "drift-check" { Cmd-DriftCheck }
Register-CiCommand "observerd-start" { Cmd-ObserverdStart }
Register-CiCommand "observerd-stop" { Cmd-ObserverdStop }
Register-CiCommand "observerd-status" { Cmd-ObserverdStatus }
Register-CiCommand "scholars" { node tests/ui/scholars_mate_test.js }
Register-CiCommand "t" { node tests/ui/scholars_mate_test.js }
Register-CiCommand "t2" { Cmd-T2 }
Register-CiCommand "supertest" { Cmd-Supertest }
Register-CiCommand "test-full" { Cmd-T2 }
Register-CiCommand "stp" { Cmd-Stp }
Register-CiCommand "menu" { Cmd-Menu }
Register-CiCommand "sonar-start" { Cmd-SonarStart }
Register-CiCommand "sonar-stop" { Cmd-SonarStop }
