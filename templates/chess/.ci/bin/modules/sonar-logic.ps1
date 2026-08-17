function Cmd-Sonar() {
  function Resolve-SonarPreflightFailureSignature([string]$statusClass, [bool]$tokenAvailable, [string]$reportedSignature) {
    if ($reportedSignature) {
      if ($reportedSignature -eq "tst431_server_up_auth_missing") {
        return ($tokenAvailable ? "sonar-auth-invalid" : "sonar-auth-missing")
      }
      if ($reportedSignature -ne "") {
        return $reportedSignature
      }
    }

    switch ($statusClass) {
      "server-up-auth-missing" { return ($tokenAvailable ? "sonar-auth-invalid" : "sonar-auth-missing") }
      "server-starting" { return "sonar-server-starting" }
      "server-down" { return "sonar-server-down" }
      default { return "sonar-preflight-failed" }
    }
  }

  function Resolve-SonarAnalysisFailureSignature([string]$tailText) {
    if (-not $tailText) { return "sonar-analysis-failed" }
    if ($tailText -match "Not authorized\.?\s*Please check the user token|Not authorized") {
      return "sonar-auth-missing-or-invalid"
    }
    if ($tailText -match "SonarQube Quality Gate != OK|quality gate\s*!=|Quality Gate status") {
      return "sonar-quality-gate-blocked"
    }
    if ($tailText -match "ceTaskUrl|sonar\.projectKey|projectStatus|ceTask") {
      return "sonar-quality-gate-unavailable"
    }
    return "sonar-analysis-failed"
  }

  Ensure-CoreFolders
  Ensure-BootstrapFiles

  $ts = TsId
  $preflightLog = Join-Path $LogsRoot ("terminal\sonar-auth-preflight-" + $ts + ".log")
  $preflightReportPath = Join-Path $RepoRoot "logs\sonar\tst-431-sonar-auth-preflight-report.json"
  $preflightCommand = "node tests/ci/tst_431_sonar_auth_preflight_function_test.js"

  CI-Info ("sonar: running auth preflight (log=" + $preflightLog + ")")
  $preflightRes = Run-Cmd $preflightCommand $preflightLog
  if ($preflightRes.exit -ne 0) {
    if (Test-Path -LiteralPath $preflightReportPath) {
      try {
        $preflightReport = Get-Content -Raw -LiteralPath $preflightReportPath | ConvertFrom-Json
        $class = [string](Get-Prop $preflightReport "statusClass" "")
        $failSig = [string](Get-Prop $preflightReport "failSignature" "")
        $tokenAvailable = [bool](Get-Prop $preflightReport "tokenAvailable" $false)
        $normalizedSig = Resolve-SonarPreflightFailureSignature -statusClass $class -tokenAvailable $tokenAvailable -reportedSignature $failSig
        if ($class -eq "server-up-auth-missing" -and -not $tokenAvailable) {
          throw ("sonar: missing configuration. Set SONAR_TOKEN or create .private\\sonar.token. See " + $preflightLog + " [failSignature=" + $normalizedSig + "]")
        }
        if ($failSig) {
          throw ("sonar: preflight failed (statusClass=" + $class + ", failSignature=" + $normalizedSig + "). See " + $preflightLog)
        }
        throw ("sonar: preflight failed (statusClass=" + $class + ", failSignature=" + $normalizedSig + "). See " + $preflightLog)
      } catch {
        if ($_.Exception.Message -match "missing configuration") { throw $_.Exception.Message }
        throw ("sonar: preflight failed. See " + $preflightLog)
      }
    }
    throw ("sonar: preflight failed. See " + $preflightLog)
  }

  $sonarHost = [string]$env:SONAR_HOST_URL
  if ([string]::IsNullOrWhiteSpace($sonarHost)) {
    $sonarHost = "http://localhost:9000"
  }

  $logPath = Join-Path $LogsRoot ("terminal\sonar-" + (TsId) + ".log")
  CI-Info ("sonar: running analysis (host=" + $sonarHost + ")")
  $res = Run-Cmd "sonar.cmd" $logPath
  if ($res.exit -ne 0) {
    $tail = (Tail-File $logPath 60) -join "`n"
    $failureSig = Resolve-SonarAnalysisFailureSignature $tail
    if ($tail -match "SONAR_TOKEN") {
      throw ("sonar: missing configuration. Set SONAR_TOKEN or create .private\\sonar.token. See " + $logPath + " [failSignature=" + $failureSig + "]")
    }
    throw ("sonar: analysis failed (exit=" + $res.exit + ", failSignature=" + $failureSig + "). See " + $logPath)
  }

  CI-Info ("sonar: analysis successful. log=" + $logPath)
}

function Cmd-SonarStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "sonar-start: starting or repairing SonarQube server..."
  $logPath = Join-Path $LogsRoot "terminal\ops-407-sonar-start.log"
  $guardLogPath = Join-Path $LogsRoot ("terminal\ops-407-sonar-binding-guard-" + (TsId) + ".log")
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"

  $res = Run-Cmd "cmd: sonar.cmd start" $logPath $null $RepoRoot 180
  if ($res.exit -ne 0) {
    throw ("sonar-start: start/repair failed (exit=" + $res.exit + "). See " + $logPath)
  }

  $guardRes = Run-Cmd "node tests/ci/ops_407_sonar_localhost_binding_function_test.js" $guardLogPath $null $RepoRoot 60
  if ($guardRes.exit -ne 0) {
    throw ("sonar-start: localhost binding guard failed (exit=" + $guardRes.exit + "). See " + $guardLogPath)
  }

  $sonarPidPath = Join-Path $RepoRoot ".sonarqube\sonar.pid.json"
  $pidPayload = @{
    ts = (NowIso)
    cmd = "sonar.cmd start"
    cwd = (Get-Location).Path
    port = 9000
    url = "http://localhost:9000/"
    verified_by = "tests/ci/ops_407_sonar_localhost_binding_function_test.js"
  }
  if (Test-Path -LiteralPath $sonarPidPath) {
    try {
      $j = Get-Content -Raw -LiteralPath $sonarPidPath | ConvertFrom-Json
      $pidPayload["pid"] = (Get-Prop $j "pid" $null)
      $pidPayload["source"] = ".sonarqube/sonar.pid.json"
    } catch {
      $pidPayload["source"] = "ops-407-guard"
    }
  } else {
    $pidPayload["source"] = "ops-407-guard"
  }
  $pidPayload | ConvertTo-Json -Compress | Set-Content -NoNewline -LiteralPath $pidPath

  CI-Info "sonar-start: SonarQube localhost binding verified. log=$logPath"
}

function Cmd-SonarStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "sonar-stop: stopping SonarQube server..."
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"

  # 1) Primär: PID-Datei
  if (Test-Path $pidPath) {
    $j = Get-Content -Raw $pidPath | ConvertFrom-Json
    Stop-Process -Id $j.pid -Force -ErrorAction SilentlyContinue
    Remove-Item $pidPath -ErrorAction SilentlyContinue
    CI-Info "sonar-stop: SonarQube server stopped via PID."
    return
  }

  # 2) Fallback: Port 9000
  $processId = (Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
  if ($processId) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
    CI-Info "sonar-stop: SonarQube server stopped via port scan."
    return
  }

  CI-Warn "sonar-stop: SonarQube server not found or already stopped."
}
