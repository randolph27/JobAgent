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

function Resolve-AndroidSupertestCommand([object]$gradleInfo=$null) {
  if ($null -eq $gradleInfo) { $gradleInfo = Get-GradleCmdRaw }
  $gradleCmd = [string](Get-Prop $gradleInfo "cmd" $null)
  if (-not $gradleCmd) { throw "supertest: kein Gradle-Command gefunden." }
  return ((Quote-IfNeeded $gradleCmd) + " supertest --console=plain --no-daemon").Trim()
}

function Resolve-CiPowerShellExecutable() {
  try {
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { return "pwsh" }
  } catch { $null = $_ }
  return "powershell.exe"
}

function New-CiPowerShellScriptCommand([string]$scriptPath, [string]$commandLabel, [string[]]$arguments = @()) {
  $parts = New-Object System.Collections.Generic.List[string]
  $parts.Add((Quote-IfNeeded (Resolve-CiPowerShellExecutable)))
  $parts.Add("-NoProfile")
  $parts.Add("-ExecutionPolicy")
  $parts.Add("Bypass")
  $parts.Add("-File")
  $parts.Add((Quote-IfNeeded $scriptPath))
  foreach ($argument in @($arguments)) {
    if (-not [string]::IsNullOrWhiteSpace($argument)) { $parts.Add($argument) }
  }
  if (-not [string]::IsNullOrWhiteSpace($commandLabel)) {
    $parts.Add("-CommandLabel")
    $parts.Add((Quote-IfNeeded $commandLabel))
  }
  return (($parts.ToArray()) -join " ")
}

function Get-Tst450EvidencePath() {
  return (Join-Path $LogsRoot "verify\tst-450-human-visual-supertest.md")
}

function Get-Tst450DefaultHumanEvidenceDir() {
  return (Join-Path $LogsRoot "verify\tst-448-human-journey")
}

function Get-Tst450AndroidEnv() {
  $envMap = Get-GradleEnv
  $androidHome = [string]$env:ANDROID_HOME
  if (-not $androidHome) { $androidHome = [string]$env:ANDROID_SDK_ROOT }
  if (-not $androidHome) { $androidHome = Get-DefaultAndroidSdkPath }
  if ($androidHome) {
    $envMap["ANDROID_HOME"] = $androidHome
    $envMap["ANDROID_SDK_ROOT"] = $androidHome
  }
  return $envMap
}

function Resolve-Tst450AdbPath() {
  $command = Get-Command adb.exe -ErrorAction SilentlyContinue
  if ($command -and (Test-Path -LiteralPath $command.Source)) { return $command.Source }
  $command = Get-Command adb -ErrorAction SilentlyContinue
  if ($command -and (Test-Path -LiteralPath $command.Source)) { return $command.Source }

  $sdkRoots = @(
    [string]$env:ANDROID_HOME,
    [string]$env:ANDROID_SDK_ROOT,
    [string](Get-DefaultAndroidSdkPath)
  ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
  foreach ($sdkRoot in $sdkRoots) {
    $candidate = Join-Path $sdkRoot "platform-tools\adb.exe"
    if (Test-Path -LiteralPath $candidate) { return $candidate }
  }
  return $null
}

function Get-Tst450AdbTargetFromDevicesText([string]$devicesText, [string]$requestedSerial = $null) {
  $deviceRows = New-Object System.Collections.Generic.List[object]
  $otherRows = New-Object System.Collections.Generic.List[object]
  foreach ($rawLine in (($devicesText -split "`r?`n") | Where-Object { $_ })) {
    $line = ([string]$rawLine).Trim()
    if (-not $line -or $line -match '^List of devices attached') { continue }
    if ($line -match '^(\S+)\s+(\S+)') {
      $row = @{ serial = [string]$Matches[1]; state = [string]$Matches[2]; raw = $line }
      if ($row.state -eq "device") { $deviceRows.Add($row) } else { $otherRows.Add($row) }
    }
  }
  $otherRowsArray = $otherRows.ToArray()

  if ($requestedSerial) {
    $match = @($deviceRows | Where-Object { [string](Get-Prop $_ "serial" "") -eq $requestedSerial })
    if ($match.Count -eq 1) {
      return @{ ok=$true; status="ready"; serial=$requestedSerial; device_count=$deviceRows.Count; requested_serial=$requestedSerial; raw=$devicesText; error=$null; other_rows=$otherRowsArray }
    }
    $nonReady = @($otherRows | Where-Object { [string](Get-Prop $_ "serial" "") -eq $requestedSerial } | Select-Object -First 1)
    if ($nonReady.Count -gt 0) {
      $nonReadyState = [string](Get-Prop ($nonReady[0]) "state" "")
      return @{ ok=$false; status="blocked"; serial=$null; device_count=$deviceRows.Count; requested_serial=$requestedSerial; raw=$devicesText; error=("requested adb serial is not ready: " + $nonReadyState); other_rows=$otherRowsArray }
    }
    return @{ ok=$false; status="blocked"; serial=$null; device_count=$deviceRows.Count; requested_serial=$requestedSerial; raw=$devicesText; error="requested adb serial not found"; other_rows=$otherRowsArray }
  }

  if ($deviceRows.Count -eq 1) {
    $singleSerial = [string](Get-Prop ($deviceRows[0]) "serial" "")
    return @{ ok=$true; status="ready"; serial=$singleSerial; device_count=1; requested_serial=$null; raw=$devicesText; error=$null; other_rows=$otherRowsArray }
  }
  $emulatorRows = @($deviceRows | Where-Object { [string](Get-Prop $_ "serial" "") -match '^emulator-\d+$' })
  if ($emulatorRows.Count -eq 1) {
    $emulatorSerial = [string](Get-Prop ($emulatorRows[0]) "serial" "")
    return @{ ok=$true; status="ready"; serial=$emulatorSerial; device_count=$deviceRows.Count; requested_serial=$null; raw=$devicesText; error=$null; other_rows=$otherRowsArray; auto_selected_serial=$emulatorSerial; auto_selection_reason="single_ready_emulator" }
  }
  if ($deviceRows.Count -eq 0) {
    return @{ ok=$false; status="blocked"; serial=$null; device_count=0; requested_serial=$null; raw=$devicesText; error="no adb device in state device"; other_rows=$otherRowsArray }
  }
  return @{ ok=$false; status="blocked"; serial=$null; device_count=$deviceRows.Count; requested_serial=$null; raw=$devicesText; error=("multiple adb devices in state device without a unique emulator target: " + ($deviceRows.Count)); other_rows=$otherRowsArray }
}

function Test-Tst450AdbTarget([string]$requestedSerial = $null) {
  $adb = Resolve-Tst450AdbPath
  if (-not $adb) {
    return @{ ok=$false; status="blocked"; adb=$null; serial=$null; device_count=0; requested_serial=$requestedSerial; raw=""; error="adb not found"; other_rows=@() }
  }
  try {
    $output = @(& $adb devices 2>&1)
    $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    $target = Get-Tst450AdbTargetFromDevicesText $text $requestedSerial
    $target.adb = $adb
    return $target
  } catch {
    return @{ ok=$false; status="blocked"; adb=$adb; serial=$null; device_count=0; requested_serial=$requestedSerial; raw=""; error=("adb devices failed: " + [string]$_.Exception.Message); other_rows=@() }
  }
}

function Invoke-Tst450RunStep([string]$name, [string]$cmd, [string]$logPath, [hashtable]$envMap = $null) {
  try {
    $res = Run-Cmd $cmd $logPath $envMap
    return @{ name=$name; cmd=$cmd; exit=[int](Get-Prop $res "exit" 1); log=(To-RelPath $logPath); error=$null; duration_seconds=(Get-Prop $res "duration_seconds" $null) }
  } catch {
    return @{ name=$name; cmd=$cmd; exit=1; log=(To-RelPath $logPath); error=[string]$_.Exception.Message; duration_seconds=$null }
  }
}

function Get-Tst450JsonLineCount([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { return 0 }
  return @((Get-Content -LiteralPath $path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })).Count
}

function Get-Tst450FileCount([string]$path, [string]$filter = "*") {
  if (-not (Test-Path -LiteralPath $path)) { return 0 }
  return @((Get-ChildItem -LiteralPath $path -File -Filter $filter -ErrorAction SilentlyContinue)).Count
}

function Get-Tst450HumanJourneySummary([string]$evidenceDir) {
  $summaryPath = Join-Path (Split-Path -Parent $evidenceDir) ((Split-Path -Leaf $evidenceDir) + ".md")
  $assertionsPath = Join-Path $evidenceDir "assertions.jsonl"
  $screensDir = Join-Path $evidenceDir "screens"
  $uiDir = Join-Path $evidenceDir "ui"
  $status = "unknown"
  $stepCount = Get-Tst450JsonLineCount $assertionsPath
  $postFrontloadPermissionDialogClicks = 0
  if (Test-Path -LiteralPath $summaryPath) {
    $text = Get-Content -Raw -LiteralPath $summaryPath
    if ($text -match 'Status:\s*`+([^`\r\n]+)`+') { $status = [string]$Matches[1] }
    if ($text -match 'Steps:\s*`+(\d+)`+') { $stepCount = [int]$Matches[1] }
  }
  if (Test-Path -LiteralPath $assertionsPath) {
    foreach ($line in (Get-Content -LiteralPath $assertionsPath)) {
      if ([string]::IsNullOrWhiteSpace([string]$line)) { continue }
      try {
        $record = [string]$line | ConvertFrom-Json
        foreach ($dialog in @((Get-Prop $record "dismissedSystemDialogs" @()))) {
          if ([string]$dialog -match 'permission_deny|Don.t allow|textContains:Don|Nicht zulassen|Deny') {
            $postFrontloadPermissionDialogClicks += 1
          }
        }
      } catch {
        $postFrontloadPermissionDialogClicks += 1
      }
    }
  }
  return @{
    status=$status
    step_count=$stepCount
    post_frontload_permission_dialog_clicks=$postFrontloadPermissionDialogClicks
    summary=(To-RelPath $summaryPath)
    assertions=(To-RelPath $assertionsPath)
    screenshots=Get-Tst450FileCount $screensDir "*.png"
    ui_xml=Get-Tst450FileCount $uiDir "*.xml"
    screens_dir=(To-RelPath $screensDir)
    ui_dir=(To-RelPath $uiDir)
  }
}

function Get-Tst450VisualAuditSummary([string]$evidenceDir) {
  $auditJson = Join-Path $evidenceDir "audit.json"
  $auditMd = Join-Path $evidenceDir "audit.md"
  $summary = @{ status="unknown"; issue_count=$null; ui_xml=$null; screenshots=$null; required_routes=$null; audit_json=(To-RelPath $auditJson); audit_markdown=(To-RelPath $auditMd) }
  if (Test-Path -LiteralPath $auditJson) {
    try {
      $json = Get-Content -Raw -LiteralPath $auditJson | ConvertFrom-Json
      $summary.status = [string](Get-Prop $json "status" "unknown")
      $summary.issue_count = Get-Prop $json "issueCount" $null
      $ui = Get-Prop $json "ui" $null
      $shot = Get-Prop $json "screenshot" $null
      $summary.ui_xml = Get-Prop $ui "xmlFiles" $null
      $summary.screenshots = Get-Prop $shot "screenshots" $null
      $summary.required_routes = Get-Prop $shot "requiredRoutes" $null
    } catch { $summary.status = "unreadable" }
  }
  return $summary
}

function New-Tst450HumanVisualReportLines([object]$summary) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# TST-450 Human Visual Supertest")
  $lines.Add("")
  $lines.Add("- status=$([string](Get-Prop $summary "status" "unknown"))")
  $lines.Add("- ts: " + [string](Get-Prop $summary "ts" (NowIso)))
  $lines.Add("- git_head: " + [string](Get-Prop $summary "git_head" "unknown"))
  $lines.Add("- final_exitcode: " + [string](Get-Prop $summary "exit_code" 1))
  $lines.Add("- sonar_status: " + [string](Get-Prop (Get-Prop $summary "sonar" $null) "status" "UNKNOWN"))
  $lines.Add("- adb_serial: " + [string](Get-Prop (Get-Prop $summary "adb" $null) "serial" "<none>"))
  $lines.Add("- apk_path: app/build/outputs/apk/core/debug/app-core-debug.apk")
  $lines.Add("- human_journey_stepcount: " + [string](Get-Prop (Get-Prop $summary "human" $null) "step_count" 0))
  $lines.Add("- human_journey_post_frontload_permission_dialog_clicks: " + [string](Get-Prop (Get-Prop $summary "human" $null) "post_frontload_permission_dialog_clicks" 0))
  $lines.Add("- visual_audit_issues: " + [string](Get-Prop (Get-Prop $summary "visual" $null) "issue_count" "unknown"))
  $lines.Add("- screenshots: " + [string](Get-Prop (Get-Prop $summary "human" $null) "screens_dir" "logs/verify/tst-448-human-journey/screens"))
  $lines.Add("- ui_xml: " + [string](Get-Prop (Get-Prop $summary "human" $null) "ui_dir" "logs/verify/tst-448-human-journey/ui"))
  $lines.Add("- audit_json: " + [string](Get-Prop (Get-Prop $summary "visual" $null) "audit_json" "logs/verify/tst-448-human-journey/audit.json"))
  $lines.Add("- audit_markdown: " + [string](Get-Prop (Get-Prop $summary "visual" $null) "audit_markdown" "logs/verify/tst-448-human-journey/audit.md"))
  $lines.Add("")
  $lines.Add("## Gradle-Slices")
  foreach ($step in @((Get-Prop $summary "steps" @()))) {
    $stepName = [string](Get-Prop $step "name" "")
    $stepExit = [string](Get-Prop $step "exit" "")
    $stepLog = [string](Get-Prop $step "log" "")
    $lines.Add(("- {0}: exit={1} log={2}" -f $stepName, $stepExit, $stepLog))
  }
  $errors = @((Get-Prop $summary "errors" @()) | Where-Object { $_ })
  if ($errors.Count -gt 0) {
    $lines.Add("")
    $lines.Add("## Fehler")
    foreach ($err in $errors) { $lines.Add("- " + [string]$err) }
  }
  if ([string](Get-Prop $summary "status" "") -eq "blocked") {
    $lines.Add("")
    $lines.Add("## Reproduktion")
    $lines.Add("1. `$env:ANDROID_HOME='C:\Users\ralph\AppData\Local\Android\Sdk'; `$env:ANDROID_SDK_ROOT=`$env:ANDROID_HOME")
    $lines.Add("2. `& `"$env:ANDROID_HOME\platform-tools\adb.exe`" devices` muss genau eine Emulator-Zeile im Status `device` zeigen oder der fokussierte Lauf muss `-Serial <serial>` setzen.")
    $lines.Add("3. Bei mehreren Geraeten `tests\emulator\human-journey\run-human-journey.ps1 -Serial <serial>` fokussiert ausfuehren und danach `.\ci.cmd supertest` wiederholen.")
  }
  return $lines.ToArray()
}

function Write-Tst450HumanVisualReport([object]$summary, [string]$path = $(Get-Tst450EvidencePath)) {
  $lines = New-Tst450HumanVisualReportLines $summary
  Atomic-WriteTextUtf8 $path (($lines -join "`r`n") + "`r`n")
  return $path
}

function Invoke-Tst450HumanVisualSupertest([object]$gradleInfo) {
  $ts = TsId
  $envMap = Get-Tst450AndroidEnv
  $steps = New-Object System.Collections.Generic.List[object]
  $errors = New-Object System.Collections.Generic.List[string]
  $evidenceDir = Get-Tst450DefaultHumanEvidenceDir
  $summary = @{
    ts=NowIso
    status="fail"
    exit_code=1
    git_head="unknown"
    sonar=@{ status="UNKNOWN"; ok=$false; content=$null; error=$null }
    adb=@{ serial="<none>"; device_count=0; error=$null }
    human=Get-Tst450HumanJourneySummary $evidenceDir
    visual=Get-Tst450VisualAuditSummary $evidenceDir
    steps=@()
    errors=@()
  }
  try { $summary.git_head = (git -c core.pager=cat -c color.ui=false --no-pager rev-parse --short HEAD 2>$null | Select-Object -First 1) } catch { $summary.git_head = "unknown" }

  $statusUrl = Get-SonarStatusUrl
  $sonarSnapshot = Get-SonarStatusSnapshot $statusUrl 10
  if (-not [bool](Get-Prop $sonarSnapshot "ok" $false)) {
    try {
      Cmd-SonarStart
      $sonarSnapshot = Get-SonarStatusSnapshot $statusUrl 10
    } catch {
      $errors.Add("SonarQube nicht erreichbar und Start fehlgeschlagen: " + [string]$_.Exception.Message)
    }
  }
  $summary.sonar = $sonarSnapshot

  $gradleLog = Join-Path $LogsRoot ("terminal\supertest-" + $ts + ".log")
  $gradleCmd = Resolve-AndroidSupertestCommand $gradleInfo
  $gradleStep = Invoke-Tst450RunStep "gradle-supertest" $gradleCmd $gradleLog $envMap
  $steps.Add($gradleStep)
  if ([int](Get-Prop $gradleStep "exit" 1) -ne 0) {
    $errors.Add("Gradle-Supertest fehlgeschlagen: " + [string](Get-Prop $gradleStep "log" ""))
    $summary.steps = $steps.ToArray()
    $summary.errors = $errors.ToArray()
    $summary.exit_code = 1
    $summary.status = "fail"
    $null = Write-Tst450HumanVisualReport $summary
    Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") @{ ts=NowIso; cmd=".\ci.cmd supertest"; exit=1; status="fail"; fail_signature="tst450_gradle_supertest_failed"; failed_tasks=@("gradle-supertest"); log_path=(To-RelPath (Get-Tst450EvidencePath)); terminal_log=(To-RelPath $gradleLog) }
    return $summary
  }

  $adbTarget = Test-Tst450AdbTarget ([string]$env:ANDROID_SERIAL)
  $summary.adb = $adbTarget
  if (-not [bool](Get-Prop $adbTarget "ok" $false)) {
    $errors.Add("ADB-Blocker: " + [string](Get-Prop $adbTarget "error" "unknown"))
    $summary.steps = $steps.ToArray()
    $summary.errors = $errors.ToArray()
    $summary.exit_code = 1
    $summary.status = "blocked"
    $null = Write-Tst450HumanVisualReport $summary
    Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") @{ ts=NowIso; cmd=".\ci.cmd supertest"; exit=1; status="blocked"; fail_signature="tst450_adb_target_blocked"; failed_tasks=@("human-journey","visual-audit"); log_path=(To-RelPath (Get-Tst450EvidencePath)); adb_error=[string](Get-Prop $adbTarget "error" "unknown"); adb_devices=[string](Get-Prop $adbTarget "raw" "") }
    return $summary
  }

  $serial = [string](Get-Prop $adbTarget "serial" "")
  $humanEnvMap = @{}
  foreach ($key in $envMap.Keys) { $humanEnvMap[$key] = $envMap[$key] }
  $humanEnvMap["ANDROID_SERIAL"] = $serial
  $freshEvidenceDir = $evidenceDir + "-fresh"
  $freshLog = Join-Path $LogsRoot ("terminal\tst-450-human-journey-fresh-" + $ts + ".log")
  $freshCmd = 'pwsh -NoProfile -ExecutionPolicy Bypass -File tests\emulator\human-journey\run-human-journey.ps1 -Serial "' + $serial + '" -PermissionLane Fresh -OutputDir "' + $freshEvidenceDir + '" -FailOnPermissionDialog'
  $freshStep = Invoke-Tst450RunStep "human-journey-fresh" $freshCmd $freshLog $humanEnvMap
  $steps.Add($freshStep)
  if ([int](Get-Prop $freshStep "exit" 1) -ne 0) {
    $errors.Add("Human-Journey Fresh-Lane fehlgeschlagen: " + [string](Get-Prop $freshStep "log" ""))
  }
  $humanLog = Join-Path $LogsRoot ("terminal\tst-450-human-journey-" + $ts + ".log")
  $humanCmd = 'pwsh -NoProfile -ExecutionPolicy Bypass -File tests\emulator\human-journey\run-human-journey.ps1 -Serial "' + $serial + '" -PermissionLane Granted -OutputDir "' + $evidenceDir + '" -FailOnMissingRoute -FailOnPermissionDialog'
  $humanStep = Invoke-Tst450RunStep "human-journey-granted" $humanCmd $humanLog $humanEnvMap
  $steps.Add($humanStep)
  $summary.human = Get-Tst450HumanJourneySummary $evidenceDir
  if ([int](Get-Prop $humanStep "exit" 1) -ne 0) { $errors.Add("Human-Journey fehlgeschlagen: " + [string](Get-Prop $humanStep "log" "")) }

  if ([int](Get-Prop $humanStep "exit" 1) -eq 0) {
    $visualLog = Join-Path $LogsRoot ("terminal\tst-450-visual-audit-" + $ts + ".log")
    $visualCmd = 'pwsh -NoProfile -ExecutionPolicy Bypass -File tests\emulator\visual-audit\run-visual-audit.ps1 -EvidenceDir "' + $evidenceDir + '" -Rules "tests\emulator\visual-audit\visual-rules.json" -Strict'
    $visualStep = Invoke-Tst450RunStep "visual-audit" $visualCmd $visualLog $envMap
    $steps.Add($visualStep)
    $summary.visual = Get-Tst450VisualAuditSummary $evidenceDir
    if ([int](Get-Prop $visualStep "exit" 1) -ne 0) { $errors.Add("Visual-Audit fehlgeschlagen: " + [string](Get-Prop $visualStep "log" "")) }
  }

  if (-not [bool](Get-Prop $sonarSnapshot "ok" $false)) {
    $errors.Add("SonarQube-Status nicht UP: " + [string](Get-Prop $sonarSnapshot "status" "UNKNOWN"))
  }

  $summary.steps = $steps.ToArray()
  $summary.errors = $errors.ToArray()
  $summary.exit_code = $(if ($errors.Count -eq 0) { 0 } else { 1 })
  $summary.status = $(if ($errors.Count -eq 0) { "pass" } else { "fail" })
  $null = Write-Tst450HumanVisualReport $summary
  Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") @{ ts=NowIso; cmd=".\ci.cmd supertest"; exit=$summary.exit_code; status=$summary.status; fail_signature=$(if ($summary.exit_code -eq 0) { $null } else { "tst450_human_visual_failed" }); failed_tasks=@($errors); log_path=(To-RelPath (Get-Tst450EvidencePath)); adb_serial=$serial; sonar_status=[string](Get-Prop $sonarSnapshot "status" "UNKNOWN"); human_steps=Get-Prop $summary.human "step_count" 0; visual_issues=Get-Prop $summary.visual "issue_count" $null }
  return $summary
}

function Cmd-Supertest() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $jobAgentSupertest = Join-Path $RepoRoot "tests\Test-JobAgentSupertest.ps1"
  if (Test-Path -LiteralPath $jobAgentSupertest -PathType Leaf) {
    CI-Info "supertest: JobAgent function suite"
    & pwsh -NoProfile -File $jobAgentSupertest
    if ($LASTEXITCODE -ne 0) { throw "supertest: JobAgent function suite failed." }
    return
  }
  CI-Info "supertest: Gradle Android release-readiness suite + TST-450 human visual audit"
  $g = Get-GradleCmdRaw
  if (-not $g.cmd) { throw "supertest: kein Gradle-Command gefunden." }
  Persist-GradleInfo $g.mode $g.cmd
  $summary = Invoke-Tst450HumanVisualSupertest $g
  $exitCode = [int](Get-Prop $summary "exit_code" 1)
  if ($exitCode -ne 0) {
    throw ("supertest: TST-450 human visual suite failed. See " + (To-RelPath (Get-Tst450EvidencePath)))
  }
  CI-Info ("supertest: ok (evidence=" + (To-RelPath (Get-Tst450EvidencePath)) + ")")
}

function Cmd-JobAgentDailyRun([string[]]$ForwardArgs = @()) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $scriptPath = Join-Path $RepoRoot "tools\Invoke-JobAgentDailyRun.ps1"
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "daily-run: Skript fehlt: " + $scriptPath }
  & pwsh -NoProfile -File $scriptPath @ForwardArgs
  if ($LASTEXITCODE -ne 0) { throw "daily-run: fehlgeschlagen." }
}

function Cmd-JobAgentDailyRunStatus([string[]]$ForwardArgs = @()) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $scriptPath = Join-Path $RepoRoot "tools\Get-JobAgentDailyRunStatus.ps1"
  if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) { throw "daily-run-status: Skript fehlt: " + $scriptPath }
  & pwsh -NoProfile -File $scriptPath @ForwardArgs
  if ($LASTEXITCODE -ne 0) { throw "daily-run-status: fehlgeschlagen." }
}

function Cmd-SuperVpTest([string[]]$ForwardArgs = @()) {
  Ensure-CoreFolders
  Ensure-BootstrapFiles
  CI-Info "super-vp-test: all configured viewports on all ready ADB devices"
  if ($null -eq $ForwardArgs) { $ForwardArgs = @() }
  $envMap = Get-Tst450AndroidEnv
  $scriptPath = Join-Path $RepoRoot "tests\ci\super-vp-test.ps1"
  if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "super-vp-test: tests\ci\super-vp-test.ps1 fehlt."
  }
  $parts = New-Object System.Collections.Generic.List[string]
  $parts.Add((Quote-IfNeeded (Resolve-CiPowerShellExecutable)))
  $parts.Add("-NoProfile")
  $parts.Add("-ExecutionPolicy")
  $parts.Add("Bypass")
  $parts.Add("-File")
  $parts.Add((Quote-IfNeeded $scriptPath))
  foreach ($arg in @($ForwardArgs)) {
    if (-not [string]::IsNullOrWhiteSpace([string]$arg)) {
      $parts.Add((Quote-IfNeeded ([string]$arg)))
    }
  }
  $outputRoot = Join-Path $LogsRoot "verify\super-vp-test"
  for ($i = 0; $i -lt @($ForwardArgs).Count; $i++) {
    if ([string]$ForwardArgs[$i] -eq "-OutputRoot" -and ($i + 1) -lt @($ForwardArgs).Count) {
      $candidateOutputRoot = [string]$ForwardArgs[$i + 1]
      if ([System.IO.Path]::IsPathRooted($candidateOutputRoot)) {
        $outputRoot = $candidateOutputRoot
      } else {
        $outputRoot = Join-Path $RepoRoot $candidateOutputRoot
      }
    }
  }
  $cmd = ($parts.ToArray() -join " ")
  $logPath = Join-Path $LogsRoot ("terminal\super-vp-test-" + (TsId) + ".log")
  $previousRunCmdTimeout = [string][Environment]::GetEnvironmentVariable("CI_RUN_CMD_TIMEOUT_SECONDS", "Process")
  try {
    [Environment]::SetEnvironmentVariable("CI_RUN_CMD_TIMEOUT_SECONDS", "172800", "Process")
    $result = Run-Cmd $cmd $logPath $envMap
  } finally {
    [Environment]::SetEnvironmentVariable("CI_RUN_CMD_TIMEOUT_SECONDS", $previousRunCmdTimeout, "Process")
  }
  $summaryPath = Join-Path $outputRoot "super-vp-test.json"
  $summaryMarkdownPath = Join-Path $outputRoot "super-vp-test.md"
  $summary = $null
  if (Test-Path -LiteralPath $summaryPath) {
    try { $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json } catch { $summary = $null }
  }
  $status = "fail"
  if ($result.exit -eq 0) { $status = "pass" }
  Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") @{
    ts=NowIso
    cmd=".\ci.cmd super-vp-test"
    exit=$result.exit
    status=$status
    fail_signature=$(if ($result.exit -eq 0) { $null } else { "super_vp_test_failed" })
    failed_tasks=$(if ($result.exit -eq 0) { @() } else { @("super-vp-test") })
    log_path=(To-RelPath $summaryMarkdownPath)
    terminal_log=(To-RelPath $logPath)
    device_count=$(if ($summary) { Get-Prop $summary "deviceCount" $null } else { $null })
    viewport_count=$(if ($summary) { Get-Prop $summary "viewportCount" $null } else { $null })
    expected_cells=$(if ($summary) { Get-Prop $summary "expectedCells" $null } else { $null })
    failed_cells=$(if ($summary) { Get-Prop $summary "failedCells" $null } else { $null })
  }
  if ($result.exit -ne 0) {
    throw ("super-vp-test fehlgeschlagen. Siehe " + (To-RelPath $summaryMarkdownPath) + " und " + (To-RelPath $logPath))
  }
  CI-Info ("super-vp-test: ok (evidence=" + (To-RelPath $summaryMarkdownPath) + ")")
}

function Get-DefaultAndroidSdkPath() {
  $candidate = "C:\Users\ralph\AppData\Local\Android\Sdk"
  if (Test-Path -LiteralPath $candidate) { return $candidate }
  return $null
}

function Get-SonarEnv() {
  $envMap = Get-GradleEnv

  $hostUrl = [string]$env:SONAR_HOST_URL
  if (-not $hostUrl) { $hostUrl = "http://localhost:9000" }
  $envMap["SONAR_HOST_URL"] = $hostUrl

  $token = [string]$script:SonarResolvedToken
  if (-not $token) { $token = [string]$env:SONAR_TOKEN }
  if ($token) { $envMap["SONAR_TOKEN"] = $token }

  $androidHome = [string]$env:ANDROID_HOME
  if (-not $androidHome) { $androidHome = [string]$env:ANDROID_SDK_ROOT }
  if (-not $androidHome) { $androidHome = Get-DefaultAndroidSdkPath }
  if ($androidHome) {
    $envMap["ANDROID_HOME"] = $androidHome
    $envMap["ANDROID_SDK_ROOT"] = $androidHome
  }

  return $envMap
}

function Get-SonarBaseUrl() {
  $hostUrl = [string]$env:SONAR_HOST_URL
  if (-not $hostUrl) { $hostUrl = "http://localhost:9000" }
  return $hostUrl.TrimEnd("/")
}

function Get-SonarPrivateJsonToken() {
  $privatePath = Join-Path $RepoRoot ".ci\private\sonarqube.json"
  if (-not (Test-Path -LiteralPath $privatePath)) { return $null }

  try {
    $json = Get-Content -Raw -LiteralPath $privatePath | ConvertFrom-Json
    $token = [string](Get-Prop $json "token" "")
    if ($token) { return $token }
  } catch {
    return $null
  }

  return $null
}

function Get-SonarTokenCandidates([bool]$IncludeFallback = $true) {
  $raw = New-Object System.Collections.Generic.List[object]
  $raw.Add(@{ source = "process-env"; token = [string]$env:SONAR_TOKEN })
  if ($IncludeFallback) {
    $raw.Add(@{ source = "private-json"; token = [string](Get-SonarPrivateJsonToken) })
    $raw.Add(@{ source = "user-env"; token = [string][Environment]::GetEnvironmentVariable("SONAR_TOKEN", "User") })
    $raw.Add(@{ source = "machine-env"; token = [string][Environment]::GetEnvironmentVariable("SONAR_TOKEN", "Machine") })
  }

  $seen = @{}
  $candidates = New-Object System.Collections.Generic.List[object]
  foreach ($entry in $raw) {
    $token = [string](Get-Prop $entry "token" "")
    if (-not $token) { continue }
    if ($seen.ContainsKey($token)) { continue }
    $seen[$token] = $true
    $candidates.Add(@{ source = [string](Get-Prop $entry "source" "unknown"); token = $token })
  }

  return $candidates.ToArray()
}

function New-SonarApiHeadersFromToken([string]$token) {
  if (-not $token) {
    throw "sonar: SONAR_TOKEN fehlt; Quality Gate kann ohne API-Authentifizierung nicht verifiziert werden."
  }

  $pair = $token + ":"
  $basic = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
  return @{ Authorization = ("Basic " + $basic) }
}

function Get-SonarProjectKey() {
  $envKey = [string]$env:SONAR_PROJECT_KEY
  if ($envKey) { return $envKey }

  $propsPath = Join-Path $RepoRoot "sonar-project.properties"
  if (Test-Path -LiteralPath $propsPath) {
    foreach ($line in (Get-Content -LiteralPath $propsPath)) {
      if ($line -match '^\s*sonar\.projectKey\s*=\s*(.+?)\s*$') {
        return [string]$Matches[1]
      }
    }
  }

  return "soundprofile_android"
}

function Get-SonarApiHeaders() {
  $token = [string]$script:SonarResolvedToken
  if (-not $token) { $token = [string]$env:SONAR_TOKEN }
  return New-SonarApiHeadersFromToken $token
}

function Get-SonarProjectAnalysesEndpoint([string]$projectKey) {
  $encodedKey = [System.Uri]::EscapeDataString($projectKey)
  return (Get-SonarBaseUrl) + "/api/project_analyses/search?project=" + $encodedKey + "&ps=1"
}

function Get-SonarProjectSearchEndpoint([string]$projectKey) {
  $encodedKey = [System.Uri]::EscapeDataString($projectKey)
  return (Get-SonarBaseUrl) + "/api/projects/search?projects=" + $encodedKey
}

function Get-SonarFailureEvidencePath() {
  return (Join-Path $LogsRoot "verify\sq-413-sonar-failure-evidence.md")
}

function Get-SonarFailureNextCheck([object]$authResult) {
  $endpoint = [string](Get-Prop $authResult "endpoint" "")
  if (-not $endpoint) {
    $projectKey = [string](Get-Prop $authResult "project_key" (Get-SonarProjectKey))
    $endpoint = Get-SonarProjectAnalysesEndpoint $projectKey
  }
  return ('curl.exe -s -u <local-token>: --max-time 10 "' + $endpoint + '"')
}

function Get-SonarFailureHandoffInfo([object]$verifyDigest = $null) {
  if ($null -eq $verifyDigest) {
    $verifyDigest = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json")
  }
  if ($null -eq $verifyDigest) {
    return @{ has_evidence=$false; ref=$null; next=$null; error_class=$null; evidence_path=$null }
  }

  $errorClass = [string](Get-Prop $verifyDigest "error_class" (Get-Prop $verifyDigest "fail_signature" ""))
  $evidencePath = [string](Get-Prop $verifyDigest "evidence_path" (Get-Prop $verifyDigest "log_path" ""))
  if (-not $evidencePath) {
    $fallback = Get-SonarFailureEvidencePath
    if (Test-Path -LiteralPath $fallback) { $evidencePath = To-RelPath $fallback }
  }

  $isSonarFailure = $false
  if ($errorClass -match '^sonar_') { $isSonarFailure = $true }
  if ($evidencePath -match 'sq-413-sonar-failure-evidence\.md$') { $isSonarFailure = $true }
  if (-not $isSonarFailure -or -not $evidencePath) {
    return @{ has_evidence=$false; ref=$null; next=$null; error_class=$errorClass; evidence_path=$evidencePath }
  }

  $nextCheck = [string](Get-Prop $verifyDigest "next_api_auth_check" "")
  if (-not $nextCheck) {
    $projectKey = [string](Get-Prop $verifyDigest "project_key" (Get-SonarProjectKey))
    $nextCheck = Get-SonarFailureNextCheck @{ project_key=$projectKey }
  }
  $nextText = "Naechster kleinster Check: authentifizierten SonarQube-API-Read mit gueltigem lokalem Token wiederholen: " + $nextCheck
  return @{
    has_evidence = $true
    ref = ("file:" + (($evidencePath -replace "\\","/").TrimStart("/")))
    next = $nextText
    error_class = $errorClass
    evidence_path = $evidencePath
  }
}

function Write-SonarFailureEvidence {
  param(
    [Parameter(Mandatory=$true)][object]$AuthResult,
    [string]$CommandUnderTest = ".\ci.cmd sonar",
    [int]$ExitCode = 1,
    [string]$StatusUrl = $null,
    [object]$StatusSnapshot = $null,
    [bool]$GradleStarted = $false,
    [string]$TerminalErrorPath = "logs\terminal\error-sonar-latest.json",
    [string]$EvidencePath = $null,
    [bool]$UpdateVerifyDigest = $true
  )

  if (-not $EvidencePath) { $EvidencePath = Get-SonarFailureEvidencePath }
  if (-not $StatusUrl) {
    try {
      if (Get-Command -Name Get-SonarStatusUrl -ErrorAction SilentlyContinue) { $StatusUrl = Get-SonarStatusUrl }
    } catch { $StatusUrl = $null }
  }
  if (-not $StatusUrl) { $StatusUrl = ((Get-SonarBaseUrl) + "/api/system/status") }
  if ($null -eq $StatusSnapshot) {
    try {
      if (Get-Command -Name Get-SonarStatusSnapshot -ErrorAction SilentlyContinue) {
        $StatusSnapshot = Get-SonarStatusSnapshot $StatusUrl 5
      }
    } catch { $StatusSnapshot = $null }
  }

  $errorClass = [string](Get-Prop $AuthResult "error_class" "sonar_api_unreachable")
  $endpoint = [string](Get-Prop $AuthResult "endpoint" "")
  if (-not $endpoint) {
    $endpoint = Get-SonarProjectAnalysesEndpoint ([string](Get-Prop $AuthResult "project_key" (Get-SonarProjectKey)))
  }
  $statusCode = Get-Prop $AuthResult "status_code" $null
  $statusText = "n/a"
  if ($null -ne $statusCode -and [string]$statusCode -ne "") { $statusText = [string]$statusCode }
  $projectKey = [string](Get-Prop $AuthResult "project_key" (Get-SonarProjectKey))
  $tokenPresent = $false
  try { $tokenPresent = [bool](Get-Prop $AuthResult "token_present" $false) } catch { $tokenPresent = $false }
  $serverStatus = [string](Get-Prop $StatusSnapshot "status" "")
  if (-not $serverStatus) {
    $serverStatus = $(if ([bool](Get-Prop $StatusSnapshot "ok" $false)) { "UP" } else { "UNKNOWN" })
  }
  $statusResult = [string](Get-Prop $StatusSnapshot "content" "")
  if (-not $statusResult) {
    $statusResult = [string](Get-Prop $StatusSnapshot "error" "")
  }
  if (-not $statusResult) {
    $statusResult = ("status=" + $serverStatus)
  }
  $nextCheck = Get-SonarFailureNextCheck $AuthResult
  $terminalRel = $TerminalErrorPath
  try {
    if ($terminalRel -and [System.IO.Path]::IsPathRooted($terminalRel)) { $terminalRel = To-RelPath $terminalRel }
  } catch { $null = $_ }
  if ($terminalRel) { $terminalRel = $terminalRel -replace "\\","/" }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# SQ-413 SonarQube Failure Evidence")
  $lines.Add("")
  $lines.Add("- ts: " + (NowIso))
  $lines.Add('- command_under_test: `' + $CommandUnderTest + '`')
  $lines.Add('- exit: `' + $ExitCode + '`')
  $lines.Add('- blocker_class: `' + $errorClass + '`')
  $lines.Add('- status_url: `' + $StatusUrl + '`')
  $lines.Add('- server_status: `' + $serverStatus + '`')
  $lines.Add('- status_result: `' + $statusResult + '`')
  $lines.Add('- project_key: `' + $projectKey + '`')
  $lines.Add('- api_endpoint: `' + $endpoint + '`')
  $lines.Add('- http_status: `' + $statusText + '`')
  $lines.Add('- token_present: `' + ([string]$tokenPresent).ToLowerInvariant() + '`')
  $lines.Add('- gradle_started: `' + ([string]$GradleStarted).ToLowerInvariant() + '`')
  $lines.Add('- secret_sanitized: `true`')
  $lines.Add('- wrapper_stackstelle: `Cmd-Sonar -> Test-SonarApiAuthentication -> Format-SonarAuthPreflightFailure`')
  if ($terminalRel) { $lines.Add('- terminal_error_json: `' + $terminalRel + '`') }
  $lines.Add('- next_api_auth_check: `' + $nextCheck + '`')
  $lines.Add("")
  $lines.Add("## Failure Classification")
  $lines.Add("")
  $lines.Add("| Field | Value |")
  $lines.Add("| --- | --- |")
  $lines.Add('| class | `' + $errorClass + '` |')
  $lines.Add('| api_http_status | `' + $statusText + '` |')
  $lines.Add('| gradle_analysis_started | `' + ([string]$GradleStarted).ToLowerInvariant() + '` |')
  $lines.Add('| server_reachable | `' + ([string]($serverStatus -eq "UP")).ToLowerInvariant() + '` |')
  $lines.Add("")
  $lines.Add("## Reproduction")
  $lines.Add("")
  $lines.Add('1. Serverstatus lesen: `curl.exe -s --max-time 10 ' + $StatusUrl + '`')
  $lines.Add('2. Mit gueltigem lokalem Token den API-Read wiederholen: `' + $nextCheck + '`')
  $lines.Add('3. Erst nach HTTP `200` den Gradle-Sonar-Lauf starten: `.\ci.cmd sonar`')
  $lines.Add("")
  $lines.Add("## Sanitizing Audit")
  $lines.Add("")
  $lines.Add('- token_value_logged: `false`')
  $lines.Add('- auth_header_logged: `false`')
  $lines.Add('- basic_auth_fragment_logged: `false`')
  $lines.Add('- token_length_logged: `false`')
  $lines.Add('- secret_sanitized: `true`')
  Atomic-WriteTextUtf8 $EvidencePath (($lines -join "`r`n") + "`r`n")

  $evidenceRel = To-RelPath $EvidencePath
  $digest = @{
    ts = NowIso
    cmd = $CommandUnderTest
    exit = $ExitCode
    status = "blocked"
    fail_signature = $errorClass
    error_class = $errorClass
    failed_tasks = @()
    log_path = $evidenceRel
    evidence_path = $evidenceRel
    status_url = $StatusUrl
    server_status = $serverStatus
    api_endpoint = $endpoint
    http_status = $statusText
    project_key = $projectKey
    gradle_started = $GradleStarted
    token_present = $tokenPresent
    secret_sanitized = $true
    next_api_auth_check = $nextCheck
  }
  if ($UpdateVerifyDigest) {
    Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") $digest
    Write-Json (Join-Path $LogsRoot "verify\failbundle-latest.json") @{
      ts = NowIso
      cmd = $CommandUnderTest
      exit = $ExitCode
      fail_signature = $errorClass
      reason = $errorClass
      tail = @("SonarQube failure evidence: " + $evidenceRel, "Gradle started: " + ([string]$GradleStarted).ToLowerInvariant())
      log_path = $evidenceRel
    }
  }

  return @{ path=$EvidencePath; rel_path=$evidenceRel; digest=$digest; next_api_auth_check=$nextCheck; error_class=$errorClass }
}

function Get-SonarHttpStatusCodeFromError([object]$errorRecord) {
  if ($null -eq $errorRecord) { return $null }
  $ex = $null
  try { $ex = $errorRecord.Exception } catch { $ex = $null }
  while ($null -ne $ex) {
    $response = $null
    try { $response = $ex.Response } catch { $response = $null }
    if ($null -ne $response) {
      $statusValue = Get-Prop $response "StatusCode" $null
      if ($null -ne $statusValue) {
        try { return [int]$statusValue } catch { $null = $_ }
        $statusText = [string]$statusValue
        if ($statusText -match '^\d+$') { return [int]$statusText }
      }
    }
    try { $ex = $ex.InnerException } catch { $ex = $null }
  }

  $message = ""
  try { $message = [string]$errorRecord.Exception.Message } catch { $message = "" }
  if ($message -match '(?<!\d)(401|403|404|408|429|500|502|503|504)(?!\d)') { return [int]$Matches[1] }
  return $null
}

function Test-SonarTimeoutError([object]$errorRecord) {
  if ($null -eq $errorRecord) { return $false }
  $text = ""
  try { $text = [string]$errorRecord.Exception.Message } catch { $text = "" }
  try { $text += "`n" + [string]$errorRecord.FullyQualifiedErrorId } catch { $null = $_ }
  return ($text -match '(?i)\b(time[- ]?out|timed out|operation has timed out|task was canceled)\b')
}

function Get-SonarApiAuthErrorClass([object]$statusCode, [string]$message = "") {
  if ($null -ne $statusCode -and [string]$statusCode -ne "") {
    $code = [int]$statusCode
    if ($code -eq 401) { return "sonar_auth_unauthorized" }
    if ($code -eq 403) { return "sonar_auth_forbidden" }
    if ($code -eq 404) { return "sonar_project_missing" }
    if ($code -eq 408 -or $code -eq 504) { return "sonar_api_timeout" }
    return ("sonar_api_http_" + $code)
  }
  if ($message -match '(?i)\b(time[- ]?out|timed out|operation has timed out|task was canceled)\b') {
    return "sonar_api_timeout"
  }
  return "sonar_api_unreachable"
}

function Test-SonarApiAuthentication(
  [string]$projectKey = $(Get-SonarProjectKey),
  [scriptblock]$Request = $null,
  [int]$TimeoutSec = 10,
  [object[]]$TokenCandidates = $null
) {
  $hostUrl = Get-SonarBaseUrl
  $endpoint = Get-SonarProjectSearchEndpoint $projectKey
  if ($null -eq $TokenCandidates) {
    $TokenCandidates = @(Get-SonarTokenCandidates -IncludeFallback:($null -eq $Request))
  }
  $tokenPresent = (@($TokenCandidates).Count -gt 0)
  $base = [ordered]@{
    ok = $false
    error_class = $null
    endpoint = $endpoint
    status_code = $null
    project_key = $projectKey
    host = $hostUrl
    token_present = $tokenPresent
    token_source = $null
    attempted_token_sources = @()
    timeout_sec = $TimeoutSec
  }

  if (-not $tokenPresent) {
    $base.error_class = "sonar_token_missing"
    return $base
  }

  foreach ($candidate in @($TokenCandidates)) {
    $source = [string](Get-Prop $candidate "source" "unknown")
    $token = [string](Get-Prop $candidate "token" "")
    if (-not $token) { continue }
    $base.attempted_token_sources = @($base.attempted_token_sources) + @($source)

    try {
      $headers = New-SonarApiHeadersFromToken $token
      $response = $null
      if ($null -ne $Request) {
        $response = & $Request $endpoint $headers $TimeoutSec
      } else {
        $response = Invoke-RestMethod -Headers $headers -Uri $endpoint -TimeoutSec $TimeoutSec
      }
      $componentProp = $null
      try { $componentProp = $response.PSObject.Properties["components"] } catch { $componentProp = $null }
      if ($null -ne $componentProp -and @($componentProp.Value).Count -eq 0) {
        $base.ok = $false
        $base.error_class = "sonar_project_missing"
        $base.status_code = 404
        $base.token_source = $source
        $script:SonarResolvedToken = $token
        $script:SonarResolvedTokenSource = $source
        $env:SONAR_TOKEN = $token
        return $base
      }
      $base.ok = $true
      $base.error_class = "ok"
      $base.status_code = 200
      $base.token_source = $source
      $script:SonarResolvedToken = $token
      $script:SonarResolvedTokenSource = $source
      $env:SONAR_TOKEN = $token
      return $base
    } catch {
      $statusCode = Get-SonarHttpStatusCodeFromError $_
      $message = ""
      try { $message = [string]$_.Exception.Message } catch { $message = "" }
      if ((Test-SonarTimeoutError $_) -and ($null -eq $statusCode)) {
        $base.error_class = "sonar_api_timeout"
      } else {
        $base.error_class = Get-SonarApiAuthErrorClass $statusCode $message
      }
      $base.status_code = $statusCode
      $base.token_source = $source
      if ($base.error_class -ne "sonar_auth_unauthorized" -and $base.error_class -ne "sonar_auth_forbidden") {
        return $base
      }
    }
  }

  if (-not $base.error_class) { $base.error_class = "sonar_token_missing" }
  return $base
}

function Format-SonarAuthPreflightFailure([object]$result) {
  $class = [string](Get-Prop $result "error_class" "sonar_api_unreachable")
  $endpoint = [string](Get-Prop $result "endpoint" "")
  $statusCode = Get-Prop $result "status_code" $null
  $projectKey = [string](Get-Prop $result "project_key" "")
  $hostUrl = [string](Get-Prop $result "host" "")
  $next = "authentifizierten SonarQube-API-Read mit gueltigem lokalem Token wiederholen."
  if ($class -eq "sonar_token_missing") { $next = "lokalen SonarQube-Token setzen und denselben API-Read wiederholen." }
  elseif ($class -eq "sonar_auth_unauthorized") { $next = "lokalen Token erneuern oder Berechtigungen pruefen; Gradle-Analyse wurde nicht gestartet." }
  elseif ($class -eq "sonar_auth_forbidden") { $next = "Token-Berechtigungen fuer den Projekt-Key pruefen; Gradle-Analyse wurde nicht gestartet." }
  elseif ($class -eq "sonar_project_missing") { $next = "Projekt-Key und SonarQube-Projektanlage pruefen; Gradle-Analyse wurde nicht gestartet." }
  elseif ($class -eq "sonar_api_timeout") { $next = "SonarQube-Erreichbarkeit pruefen und denselben API-Read wiederholen; Gradle-Analyse wurde nicht gestartet." }

  $statusText = "n/a"
  if ($null -ne $statusCode -and [string]$statusCode -ne "") { $statusText = [string]$statusCode }
  return ("sonar: auth preflight failed: " + $class + "; endpoint=" + $endpoint + "; status_code=" + $statusText + "; project_key=" + $projectKey + "; host=" + $hostUrl + "; next=" + $next)
}

function Invoke-SonarApiJson([string]$relativeUrl) {
  $url = (Get-SonarBaseUrl) + $relativeUrl
  try {
    return Invoke-RestMethod -Headers (Get-SonarApiHeaders) -Uri $url -TimeoutSec 20
  } catch {
    throw ("sonar: API request failed for " + $url + ": " + $_.Exception.Message)
  }
}

function Get-SonarLatestAnalysis([string]$projectKey) {
  $encodedKey = [System.Uri]::EscapeDataString($projectKey)
  $resp = Invoke-SonarApiJson ("/api/project_analyses/search?project=" + $encodedKey + "&ps=1")
  $analysis = $null
  try { $analysis = @($resp.analyses)[0] } catch { $analysis = $null }
  if ($null -eq $analysis) {
    return @{ key = $null; date = $null }
  }

  return @{
    key = [string](Get-Prop $analysis "key" $null)
    date = [string](Get-Prop $analysis "date" $null)
  }
}

function Wait-SonarQualityGate([string]$projectKey, [string]$previousAnalysisKey, [int]$timeoutSec = 120) {
  $encodedKey = [System.Uri]::EscapeDataString($projectKey)
  $deadline = (Get-Date).AddSeconds($timeoutSec)

  do {
    $analysis = Get-SonarLatestAnalysis $projectKey
    $hasNewAnalysis = $false
    if ($analysis.key) {
      if (-not $previousAnalysisKey) { $hasNewAnalysis = $true }
      elseif ($analysis.key -ne $previousAnalysisKey) { $hasNewAnalysis = $true }
    }

    if ($hasNewAnalysis) {
      $statusResp = Invoke-SonarApiJson ("/api/qualitygates/project_status?projectKey=" + $encodedKey)
      return @{
        analysis = $analysis
        projectStatus = $statusResp.projectStatus
        timed_out = $false
      }
    }

    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)

  return @{
    analysis = Get-SonarLatestAnalysis $projectKey
    projectStatus = (Invoke-SonarApiJson ("/api/qualitygates/project_status?projectKey=" + $encodedKey)).projectStatus
    timed_out = $true
  }
}

function Format-SonarFailedConditions([object]$projectStatus) {
  $failed = New-Object System.Collections.Generic.List[string]
  foreach ($condition in @($projectStatus.conditions)) {
    $status = [string](Get-Prop $condition "status" "")
    if ($status -ne "ERROR") { continue }

    $metric = [string](Get-Prop $condition "metricKey" "")
    $actual = [string](Get-Prop $condition "actualValue" "")
    $threshold = [string](Get-Prop $condition "errorThreshold" "")
    $comparator = [string](Get-Prop $condition "comparator" "")
    $parts = New-Object System.Collections.Generic.List[string]
    if ($metric) { $parts.Add($metric) }
    if ($actual) { $parts.Add("actual=" + $actual) }
    if ($comparator) { $parts.Add("comparator=" + $comparator) }
    if ($threshold) { $parts.Add("threshold=" + $threshold) }
    if ($parts.Count -gt 0) { $failed.Add(($parts -join " ")) }
  }

  return $failed.ToArray()
}

function Get-SonarRiskGateSnapshot([string]$projectKey) {
  $encodedKey = [System.Uri]::EscapeDataString($projectKey)
  $metricKeys = "security_rating,reliability_rating,security_hotspots_reviewed"
  $measureResponse = Invoke-SonarApiJson ("/api/measures/component?component=" + $encodedKey + "&metricKeys=" + $metricKeys)
  $measures = @{}
  foreach ($measure in @((Get-Prop (Get-Prop $measureResponse "component" $null) "measures" @()))) {
    $measures[[string](Get-Prop $measure "metric" "")] = [string](Get-Prop $measure "value" "")
  }
  $hotspotResponse = Invoke-SonarApiJson ("/api/hotspots/search?projectKey=" + $encodedKey + "&status=TO_REVIEW&ps=1")
  $unreviewed = [int](Get-Prop (Get-Prop $hotspotResponse "paging" $null) "total" -1)
  $securityRating = [string](Get-Prop $measures "security_rating" "")
  $reliabilityRating = [string](Get-Prop $measures "reliability_rating" "")
  $hotspotsReviewed = [decimal](Get-Prop $measures "security_hotspots_reviewed" "0")
  if ($securityRating -ne "1.0" -or $reliabilityRating -ne "1.0" -or $hotspotsReviewed -lt 100 -or $unreviewed -ne 0) {
    throw ("sonar: QA-602 risk gate failed: security_rating=" + $securityRating +
      "; reliability_rating=" + $reliabilityRating +
      "; security_hotspots_reviewed=" + $hotspotsReviewed +
      "; unreviewed_hotspots=" + $unreviewed)
  }
  return @{
    security_rating = $securityRating
    reliability_rating = $reliabilityRating
    security_hotspots_reviewed = $hotspotsReviewed
    unreviewed_hotspots = $unreviewed
  }
}

function Cmd-Sonar() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $statusUrl = Get-SonarStatusUrl
  if (-not (Test-SonarServerHealthy $statusUrl).ok) {
    throw ("sonar: SonarQube ist nicht gesund erreichbar unter " + $statusUrl + ". Starte zuerst .\\ci.cmd sonar-start")
  }

  $g = Get-GradleCmdRaw
  if (-not $g.cmd) { throw "sonar: kein Gradle-Command gefunden." }
  Persist-GradleInfo $g.mode $g.cmd

  $projectKey = Get-SonarProjectKey
  $authPreflight = Test-SonarApiAuthentication $projectKey
  if (-not [bool](Get-Prop $authPreflight "ok" $false)) {
    $null = Write-SonarFailureEvidence -AuthResult $authPreflight -CommandUnderTest ".\ci.cmd sonar" -ExitCode 1 -StatusUrl $statusUrl -GradleStarted $false -TerminalErrorPath "logs\terminal\error-sonar-latest.json"
    throw (Format-SonarAuthPreflightFailure $authPreflight)
  }
  $previousAnalysis = Get-SonarLatestAnalysis $projectKey
  $envMap = Get-SonarEnv
  $ts = TsId
  $sonarLog = Join-Path $LogsRoot ("terminal\sonar-" + $ts + ".log")
  $gradleCmd = ((Quote-IfNeeded $g.cmd) + " sonar --console=plain -Dsonar.gradle.skipCompile=true").Trim()
  CI-Info ("sonar: " + $gradleCmd + " | log=" + $sonarLog)
  $res = Run-Cmd $gradleCmd $sonarLog $envMap
  if ($res.exit -ne 0) { throw ("sonar: Gradle-Sonar-Lauf fehlgeschlagen. See " + $sonarLog) }

  $quality = Wait-SonarQualityGate $projectKey ([string](Get-Prop $previousAnalysis "key" $null))
  $projectStatus = Get-Prop $quality "projectStatus" $null
  $analysis = Get-Prop $quality "analysis" $null
  $analysisKey = [string](Get-Prop $analysis "key" $null)
  $status = [string](Get-Prop $projectStatus "status" "")
  $failedConditions = @(Format-SonarFailedConditions $projectStatus)
  if ([bool](Get-Prop $quality "timed_out" $false)) {
    throw ("sonar: Analyse fuer " + $projectKey + " wurde nicht rechtzeitig bestaetigt. Letzter Quality-Gate-Status=" + $status + $(if ($analysisKey) { " analysis=" + $analysisKey } else { "" }))
  }
  if ($status -ne "OK") {
    $detail = "no failed conditions returned"
    if ($failedConditions.Count -gt 0) { $detail = ($failedConditions -join "; ") }
    throw ("sonar: Quality Gate failed for " + $projectKey + ": " + $detail)
  }
  $riskGate = Get-SonarRiskGateSnapshot $projectKey
  Write-Json (Join-Path $LogsRoot "verify\verify.digest.json") @{
    ts = NowIso
    cmd = ".\ci.cmd sonar"
    exit = 0
    status = "ok"
    fail_signature = $null
    failed_tasks = @()
    log_path = (To-RelPath $sonarLog)
    project_key = $projectKey
    analysis_key = $analysisKey
    quality_gate_status = $status
    security_rating = [string](Get-Prop $riskGate "security_rating" "")
    reliability_rating = [string](Get-Prop $riskGate "reliability_rating" "")
    security_hotspots_reviewed = [decimal](Get-Prop $riskGate "security_hotspots_reviewed" 0)
    unreviewed_hotspots = [int](Get-Prop $riskGate "unreviewed_hotspots" -1)
    gradle_started = $true
    gradle_exit = 0
    secret_sanitized = $true
  }
  CI-Info ("sonar: Quality Gate OK fuer " + $projectKey + $(if ($analysisKey) { " analysis=" + $analysisKey } else { "" }))
}

function Cmd-ReworkTest() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  throw "rework-test ist in diesem nativen Android-Projekt inaktiv; nutze gezielte Gradle-Testgruppen oder .\gradlew.bat supertest --console=plain --no-daemon."
}

function Cmd-Dev() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Cmd-DevserverStart
}

function Invoke-StpGit([string[]]$arguments) {
  try {
    $output = @(& git -C $RepoRoot @arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($output | ForEach-Object { [string]$_ }) -join "`n").TrimEnd()
  } catch { return $null }
}

function Get-StpGitSnapshot() {
  if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot ".git"))) {
    return @{ has_repo=$false; branch=$null; detached=$false; head=$null; upstream=$null; remote=$null; ahead=$null; behind=$null; worktree="not-a-repository"; tracked_changes=@() }
  }

  $branch = Invoke-StpGit @("symbolic-ref", "--quiet", "--short", "HEAD")
  $detached = (-not $branch)
  if ($detached) { $branch = "DETACHED" }
  $head = Invoke-StpGit @("rev-parse", "--short=12", "HEAD")
  $upstream = Invoke-StpGit @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}")
  $ahead = $null
  $behind = $null
  if ($upstream) {
    $counts = Invoke-StpGit @("rev-list", "--left-right", "--count", ("HEAD..." + $upstream))
    if ($counts -match '^(\d+)\s+(\d+)$') { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2] }
  }

  $tracked = New-Object System.Collections.Generic.List[string]
  $trackedStatus = Invoke-StpGit @("status", "--porcelain=v1", "--untracked-files=no")
  foreach ($line in @($trackedStatus -split "`n")) {
    if (-not $line -or $line.Length -lt 4) { continue }
    $path = $line.Substring(3).Trim()
    if ($path -match '\s+->\s+(.+)$') { $path = [string]$Matches[1] }
    $path = $path.Trim('"').Replace("\\", "/")
    if ($path -and -not [System.IO.Path]::IsPathRooted($path)) { $tracked.Add($path) }
  }
  $allStatus = Invoke-StpGit @("status", "--porcelain=v1")
  $remote = $null
  if ($upstream -and $upstream.Contains("/")) { $remote = $upstream.Split('/')[0] }
  return @{
    has_repo=$true
    branch=$branch
    detached=$detached
    head=$head
    upstream=$upstream
    remote=$remote
    ahead=$ahead
    behind=$behind
    worktree=$(if ($allStatus) { "dirty" } else { "clean" })
    tracked_changes=@($tracked | Select-Object -Unique)
  }
}

function Get-StpVerification([object]$verifyDigest) {
  if ($null -eq $verifyDigest) { return @() }
  $cmd = [string](Get-Prop $verifyDigest "cmd" "")
  $exit = Get-Prop $verifyDigest "exit" $null
  if (-not $cmd -and $null -eq $exit) { return @() }
  $entry = @{ cmd=$cmd; exit=$exit; status=[string](Get-Prop $verifyDigest "status" "") }
  $logPath = [string](Get-Prop $verifyDigest "log_path" "")
  if ($logPath -and -not [System.IO.Path]::IsPathRooted($logPath)) { $entry.log_path = $logPath.Replace("\\", "/") }
  return @($entry)
}

function Get-StpGoalAndNext([object]$state) {
  $activeId = [string](Get-Prop $state "active_id" "")
  $goal = ""
  $next = ""
  $seenActive = $false
  foreach ($item in @(Get-Prop $state "items" @())) {
    $id = [string](Get-Prop $item "todo_id" "")
    $title = [string](Get-Prop $item "title" "")
    if ($id -eq $activeId) { $goal = $title; $seenActive = $true; continue }
    if (-not $next -and (($seenActive -and [string](Get-Prop $item "status" "") -eq "open") -or (-not $activeId -and [string](Get-Prop $item "status" "") -eq "open"))) {
      $next = $title
    }
  }
  return @{ goal=$goal; next=$next }
}

function Render-StpHandoffMarkdown([object]$handoff) {
  $git = Get-Prop $handoff "git" @{}
  $verified = @(Get-Prop $handoff "verified" @())
  $changed = @(Get-Prop $handoff "changed" @())
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# Handoff latest")
  $lines.Add("")
  $lines.Add("Stand: " + [string](Get-Prop $handoff "ts" ""))
  $lines.Add("")
  $lines.Add("## Zustand")
  $lines.Add("")
  $lines.Add('- Active: `' + [string](Get-Prop $handoff "active_id" "") + '`')
  $lines.Add('- Status: `' + [string](Get-Prop $handoff "status" "") + '`')
  $lines.Add("- Ziel: " + [string](Get-Prop $handoff "goal" ""))
  $lines.Add('- Branch: `' + [string](Get-Prop $git "branch" "") + '`')
  $lines.Add('- HEAD: `' + [string](Get-Prop $git "head" "") + '`')
  $lines.Add('- Upstream: `' + [string](Get-Prop $git "upstream" "") + '`')
  $lines.Add('- Ahead/Behind: `' + [string](Get-Prop $git "ahead" "") + '/' + [string](Get-Prop $git "behind" "") + '`')
  $lines.Add('- Worktree: `' + [string](Get-Prop $git "worktree" "") + '`')
  $lines.Add('- Route: `' + [string](Get-Prop $handoff "route_ok" "") + '`')
  $lines.Add("")
  $lines.Add("## Versionierte Aenderungen")
  $lines.Add("")
  if ($changed.Count -eq 0) { $lines.Add("- Keine") } else { foreach ($path in $changed) { $lines.Add('- `' + [string]$path + '`') } }
  $lines.Add("")
  $lines.Add("## Verifikation")
  $lines.Add("")
  if ($verified.Count -eq 0) { $lines.Add("- Keine Verify-Evidence vorhanden") } else { foreach ($entry in $verified) { $lines.Add('- `' + [string](Get-Prop $entry "cmd" "") + '` -> Exit `' + [string](Get-Prop $entry "exit" "") + '`') } }
  $lines.Add("")
  $lines.Add("## Naechster Anker")
  $lines.Add("")
  $lines.Add([string](Get-Prop $handoff "next" ""))
  return ($lines -join "`r`n") + "`r`n"
}

function Cmd-Stp() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  Cmd-TodoCompact
  Cmd-TodoPrune
  $now = NowIso
  $agent = Get-AgentId
  $st = Normalize-TodoState (Load-TodoState) $true
  $activeId = [string](Get-Prop $st "active_id" "")
  $activeStatus = "open"
  if ($st -and $activeId) {
    try { foreach ($it in @($st.items)) { if ([string](Get-Prop $it "todo_id" "") -eq $activeId) { $activeStatus = [string](Get-Prop $it "status" $activeStatus); break } } } catch { $null = $_ }
  }
  $tc = Try-ReadJson (Join-Path $CiRoot "run\toolchain.state.json")
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json")
  $rc = Try-ReadJson (Join-Path $CiRoot "run\route.check.json")
  $proj = (Split-Path $RepoRoot -Leaf)
  $git = Get-StpGitSnapshot
  $changed = @(Get-Prop $git "tracked_changes" @())
  $verified = @(Get-StpVerification $vd)
  $routeOk = Get-Prop $rc "route_ok" $null
  $routeViolations = @(Get-Prop $rc "violations" @())
  $anchors = Get-StpGoalAndNext $st
  $sonarInfo = Get-SonarFailureHandoffInfo $vd
  $capsuleRefs = @("todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.json")
  $handoffRefs = @("file:todo.current.md", "file:todo.state.json", "file:todo.events.jsonl", "file:handoff.latest.json", "file:logs/verify/verify.digest.json")
  $nextSteps = @()
  $nextText = [string](Get-Prop $anchors "next" "")
  if ($nextText) { $nextSteps += $nextText }
  if ([bool](Get-Prop $sonarInfo "has_evidence" $false)) {
    $sonarRef = [string](Get-Prop $sonarInfo "ref" "")
    $sonarPath = [string](Get-Prop $sonarInfo "evidence_path" "")
    if ($sonarRef) { $handoffRefs += $sonarRef }
    if ($sonarPath) { $capsuleRefs += $sonarPath }
    $sonarNext = [string](Get-Prop $sonarInfo "next" "")
    if ($sonarNext) { $nextSteps = @($sonarNext) + $nextSteps }
  }
  $todoIdForEv = "SYSTEM"; if ($activeId) { $todoIdForEv = $activeId }
  $ev = Append-TodoEvent @{ ts=$now; type="stp"; todo_id=$todoIdForEv; status=$activeStatus; prio="low"; source="stp"; msg="sync checkpoint"; refs=@("file:todo.events.jsonl","file:handoff.latest.json"); changed=$changed; verified=$verified; git=$git }
  Cmd-TodoRotate
  $st = Load-TodoState
  $capsule = @{ ts=$now; agent_id=$agent; workspace_root="."; project=$proj; chat_flow_policy=$script:ChatFlowPolicy; active_id=$activeId; status=$activeStatus; goal=[string](Get-Prop $anchors "goal" ""); changed=$changed; verified=$verified; route_ok=$routeOk; route_violations=$routeViolations; git=$git; next=$nextText; refs=@($capsuleRefs | Select-Object -Unique); manual_missing=$false; env_inventory_missing=$false; env_inventory_used=(Test-Path -LiteralPath (Join-Path $RepoRoot "env-inventory.snapshot.md")); env_inventory_path=$(if (Test-Path -LiteralPath (Join-Path $RepoRoot "env-inventory.snapshot.md")) { "env-inventory.snapshot.md" } else { $null }) }
  $handoff = @{ ts=$now; agent_id=$agent; workspace_root="."; project=$proj; chat_flow_policy=$script:ChatFlowPolicy; toolchain=$tc; active_id=$activeId; status=$activeStatus; summary="stp sync"; goal=$capsule.goal; next=$nextText; next_steps=@($nextSteps); changed=$changed; verified=$verified; git=$git; route_ok=$routeOk; route_violations=$routeViolations; refs=@($handoffRefs | Select-Object -Unique); verify_digest=$vd; route=$rc; capsule=$capsule }
  Write-Json (Join-Path $RepoRoot "handoff.latest.json") $handoff
  Atomic-WriteTextUtf8 (Join-Path $RepoRoot "handoff.latest.md") (Render-StpHandoffMarkdown $handoff)
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
#ci verify             (Gradle: check; unknown => self-check)
#ci rework-test        (inaktiv in diesem nativen Android-Projekt)
#ci self-check         (Invarianten + Truth-Dateien prüfen)
#ci gradle-autopsy     (Verify + Eskalation bis Stufe 2; tolerant)
#ci lock-triage        (Windows Lock Evidence sammeln)
#ci observer-baseline  (Baseline Hashes erzeugen)
#ci observer-check     (Diff gegen Baseline)
#ci patch-apply        (1 Patch dry-run+apply, danach Verify)
#ci restore-immutables  (Immutable Dateien aus Snapshot zurückspielen)
#ci route-check        (Verify-Gate prüfen)
#ci browser-smoke      (Browser-Smoke via config/contract)
#ci dev                (Alias fuer devserver-start)
#ci devserver-start    (Gradle Devserver detached + devserver.log)
#ci devserver-stop     (Stop Gradle Devserver)
#ci devserver-status   (Status Gradle Devserver)
#ci daily-run          (JobAgent Daily-Run, fixturebasiert bis Live-Lane aktiv ist)
#ci daily-run-status   (JobAgent Daily-Run-Status als JSON)
#ci sonar              (Gradle-Sonar-Lauf fuer das Android-Repository)
#ci pyserver-start     (Python http.server detached; auto-detect dist)
#ci pyserver-stop      (Stop Python http.server)
#ci pyserver-status    (Status Python http.server)
#ci scholars           (Schäfermatt UI Test)
#ci t                  (Kurzform für scholars)
#ci t2                 (Master-Validierung)
#ci supertest          (Gradle Android supertest)
#ci super-vp-test      (Super VP Test: alle Viewports auf allen ADB-Geraeten)
#ci permission-test    (fokussierte Live-Permission-Suite fuer ANDROID_SERIAL)
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
  $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json"); $fb = Try-ReadJson (Join-Path $LogsRoot "verify\failbundle-latest.json"); $route = Try-ReadJson (Join-Path $CiRoot "run\route.check.json"); $toolchain = Try-ReadJson (Join-Path $CiRoot "run\toolchain.state.json"); $lock = Try-ReadJson (Join-Path $CiRoot "locks\workspace.lock.json")
  $failSig = Get-Prop $vd "fail_signature" $null; $failStreak = Get-Prop $vd "fail_streak" 0; $esc = Get-Prop $vd "escalation_level" 0; $routeOk = Get-Prop $route "route_ok" $null
  $sonarInfo = Get-SonarFailureHandoffInfo $vd
  $evidence = @()
  $sonarNext = $null
  if ([bool](Get-Prop $sonarInfo "has_evidence" $false)) {
    $sonarPath = [string](Get-Prop $sonarInfo "evidence_path" "")
    if ($sonarPath) { $evidence += $sonarPath }
    $sonarNext = [string](Get-Prop $sonarInfo "next" "")
  }
  $capsule = @{ ts=NowIso; agent_id=(Get-AgentId); workspace_root=$RepoRoot; active=$null; status=$status; changed=@(); verified=@(); evidence=@($evidence); fail_signature=$failSig; fail_streak=$failStreak; escalation_level=$esc; route_ok=$routeOk; lock=$lock; notes=@() }
  if ($errorMsg) { $capsule.notes = @($errorMsg) }; $summary = "auto checkpoint after " + $cmdName; if ($errorMsg) { $summary = "blocked: " + $cmdName }; $next = @()
  if ($status -eq "blocked") { $next = @("open logs/verify/failbundle-latest.json", "run lock-triage if file-lock signatures", "run stp after resolution") } else { $next = @("run doctor", "run stp when ready") }
  if ($sonarNext) { $next = @($sonarNext) + $next }
  $handoff = @{ ts=NowIso; agent_id=(Get-AgentId); workspace_root=$RepoRoot; last_cmd=$cmdName; status=$status; summary=$summary; next_steps=$next; refs=@(); evidence_refs=@((Get-Prop $vd "log_path" $null), (Get-Prop $fb "log_path" $null), $script:LastCmdLogPath, $evidence) | Where-Object { $_ } | Select-Object -Unique; toolchain=$toolchain; capsule=$capsule; verify_digest=$vd; failbundle=$fb }
  Write-Json (Join-Path $RepoRoot "handoff.latest.json") $handoff
}

function Cmd-Start() {
  Cmd-Bootstrap; $cfg = Try-ReadJson (Get-ConfigPath); $wl = Get-Prop $cfg "workspace_lock" $null; $lockOn = $true
  try { $lockOn = [bool](Get-Prop $wl "on" $true) } catch { $lockOn = $true }; if ($lockOn) { Cmd-WsLockAcquire }
  Cmd-Preflight; try { Update-ManualDigest } catch { $null = $_ }; try { Update-EnvInventoryDigest } catch { $null = $_ }; Cmd-Doctor
}

function Cmd-Bootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Ensure-ProjectStubs
  if (-not (Test-Path -LiteralPath (Get-ImmutablePinsPath))) {
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
  Ensure-CoreFolders; Ensure-BootstrapFiles; $snapRoot = Join-Path $CiRoot "pins\immutable.snapshot"; if (-not (Test-Path -LiteralPath $snapRoot)) { throw "immutable snapshot missing. Run: .ci\bin\ci.cmd bootstrap" }
  foreach ($rel in $ImmutableFiles) { $src = Join-Path $snapRoot $rel; $dst = Join-Path $RepoRoot $rel; if (Test-Path -LiteralPath $src) { Ensure-Dir (Split-Path -Parent $dst); Set-ReadOnlyFlag $dst $false; Copy-Item -Force -LiteralPath $src -Destination $dst; Set-ReadOnlyFlag $dst $true } }
  Pin-ImmutableFiles | Out-Null; CI-Info "restore-immutables: ok"
}

function Cmd-RepinImmutables() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pinsPath = Get-ImmutablePinsPath; $snapRoot = Join-Path $CiRoot "pins\immutable.snapshot"
  try { if (Test-Path -LiteralPath $pinsPath) { Remove-Item -Force -LiteralPath $pinsPath } } catch { $null = $_ }; try { if (Test-Path -LiteralPath $snapRoot) { Remove-Item -Force -Recurse -LiteralPath $snapRoot } } catch { $null = $_ }
  Pin-ImmutableFiles | Out-Null; CI-Info "repin-immutables: ok"
}

function Cmd-DepsBootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $bs = Detect-BuildSystem; CI-Info ("deps-bootstrap: build_system=" + $bs); $envMap = Ensure-JavaReady; $src  = [string](HGet $script:JavaSelection "source" "unknown"); $maj  = HGet $script:JavaSelection "major" $null; $jdkHome = [string](HGet $script:JavaSelection "jdkHome" $null); $msg = "deps-bootstrap: java_source=" + $src; if ($maj)  { $msg += " java_major=" + $maj }; if ($jdkHome) { $msg += " java_home=" + $jdkHome }; CI-Info $msg
  if ($bs -eq "gradle" -or (Is-GradleRequired)) { $ver = Get-GradleDesiredVersion; try { $bat = Ensure-LocalGradleDist $ver; Persist-GradleInfo "local-dist" $bat (Get-GradleProjectRoot); CI-Info ("deps-bootstrap: gradle dist ok cmd=" + $bat) } catch { Report-Priority "toolchain.gradle" ("Gradle provisioning failed: " + $_.Exception.Message) @{ step="deps-bootstrap"; version=$ver }; throw }; if (Is-GradleProject) { Ensure-GradleWrapper; CI-Info ("deps-bootstrap: gradle wrapper ok=" + (Wrapper-Ok (Get-GradleProjectRoot))) } else { CI-Warn "deps-bootstrap: gradle build markers not found yet (wrapper not generated)." } }
}

function Cmd-GradleBootstrap() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; Cmd-Preflight; $ver = Get-GradleDesiredVersion; $root = Get-GradleProjectRoot; if (-not $root) { $root = $RepoRoot }; CI-Info ("gradle-bootstrap: desired_version=" + $ver + " root=" + $root); $bat = $null
  try { $bat = Ensure-LocalGradleDist $ver; Persist-GradleInfo "local-dist" $bat $root } catch { Report-Priority "toolchain.gradle" ("Gradle provisioning failed: " + $_.Exception.Message) @{ step="gradle-bootstrap"; version=$ver; root=$root }; throw }; if (Is-GradleProject) { try { Ensure-GradleWrapper } catch { Report-Priority "toolchain.gradle" ("Gradle wrapper repair failed: " + $_.Exception.Message) @{ step="wrapper"; version=$ver; root=$root }; throw } } else { CI-Warn "gradle-bootstrap: no Gradle build markers found yet (wrapper not generated)." }; CI-Info "gradle-bootstrap: ok"
}

function Cmd-PermissionTest() {
  Ensure-CoreFolders
  Ensure-BootstrapFiles
  $requestedSerial = [string]$env:ANDROID_SERIAL
  if ([string]::IsNullOrWhiteSpace($requestedSerial)) {
    $requestedSerial = "emulator-5554"
  }
  $adbTarget = Test-Tst450AdbTarget $requestedSerial
  if (-not $adbTarget.ok) {
    throw ("permission-test: " + [string]$adbTarget.error)
  }

  $serial = [string]$adbTarget.serial
  $lane = if ($serial.StartsWith("emulator-", [System.StringComparison]::OrdinalIgnoreCase)) {
    "emulator"
  } else {
    "physical"
  }
  $gradleInfo = Get-GradleCmdRaw
  $gradleCmd = [string](Get-Prop $gradleInfo "cmd" $null)
  if (-not $gradleCmd) {
    throw "permission-test: kein Gradle-Command gefunden."
  }

  $buildLog = Join-Path $LogsRoot ("terminal\permission-test-build-" + (TsId) + ".log")
  $build = Run-Cmd ((Quote-IfNeeded $gradleCmd) + " :app:assembleCoreDebug --console=plain --no-daemon") $buildLog
  if ($build.exit -ne 0) {
    throw ("permission-test: APK-Build fehlgeschlagen. Siehe " + $buildLog)
  }

  $scriptPath = Join-Path $RepoRoot "tests\ci\perm-588-live-permission-suite.ps1"
  $suiteCommand = @(
    (Quote-IfNeeded (Resolve-CiPowerShellExecutable)),
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Quote-IfNeeded $scriptPath),
    "-Lane",
    $lane,
    "-Serial",
    (Quote-IfNeeded $serial)
  ) -join " "
  $suiteLog = Join-Path $LogsRoot ("terminal\permission-test-suite-" + (TsId) + ".log")
  $suite = Run-Cmd $suiteCommand $suiteLog
  if ($suite.exit -ne 0) {
    throw ("permission-test: Live-Permission-Suite fehlgeschlagen. Siehe " + $suiteLog)
  }

  CI-Info ("permission-test: ok lane=" + $lane + " serial=" + $serial)
}

Register-CiCommand "start" { Cmd-Start }
Register-CiCommand "bootstrap" { Cmd-Bootstrap }
Register-CiCommand "ws-lock-acquire" { Cmd-WsLockAcquire; CI-Info "ws-lock-acquire: ok" }
Register-CiCommand "ws-lock-release" { Cmd-WsLockRelease; CI-Info "ws-lock-release: ok" }
Register-CiCommand "preflight" { Cmd-Preflight }
Register-CiCommand "deps-bootstrap" { Cmd-DepsBootstrap }
Register-CiCommand "verify" { Cmd-Verify 0 }
Register-CiCommand "rework-test" { Cmd-ReworkTest }
Register-CiCommand "self-check" { Cmd-SelfCheck }
Register-CiCommand "bootstrap-verify" { Cmd-SelfCheck }
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
Register-CiCommand "browser-smoke" { Cmd-BrowserSmoke }
Register-CiCommand "dev" { Cmd-Dev }
Register-CiCommand "devserver-start" { Cmd-DevserverStart }
Register-CiCommand "devserver-stop" { Cmd-DevserverStop }
Register-CiCommand "devserver-status" { Cmd-DevserverStatus }
Register-CiCommand "daily-run" { Cmd-JobAgentDailyRun $Args }
Register-CiCommand "daily-run-status" { Cmd-JobAgentDailyRunStatus $Args }
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
Register-CiCommand "super-vp-test" { Cmd-SuperVpTest $script:Args }
Register-CiCommand "super-vp" { Cmd-SuperVpTest $script:Args }
Register-CiCommand "permission-test" { Cmd-PermissionTest }
Register-CiCommand "test-full" { Cmd-T2 }
Register-CiCommand "stp" { Cmd-Stp }
Register-CiCommand "menu" { Cmd-Menu }
Register-CiCommand "sonar-start" { Cmd-SonarStart }
Register-CiCommand "sonar-stop" { Cmd-SonarStop }
