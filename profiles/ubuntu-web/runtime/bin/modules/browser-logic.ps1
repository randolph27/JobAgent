function Cmd-BrowserSmoke() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath); $bs = Get-Prop $cfg "browser_smoke" $null
  $requiresVerify = Get-Prop $bs "requires_verify" $true
  if ($requiresVerify) {
    $vdPath = Join-Path $LogsRoot "verify\verify.digest.json"; $vd = Try-ReadJson $vdPath; $exitProp = $null
    if ($vd) { $exitProp = Get-Prop $vd "exit" $null }
    if (-not $vd -or $null -eq $exitProp) { throw "browser-smoke blocked: verify digest missing. Run: .ci\bin\ci.cmd verify" }
    $vx = [int]$exitProp; if ($vx -ne 0) { throw ("browser-smoke blocked: verify exit=" + $vx + ". Fix build first.") }
  }
  $cmd = Get-Prop $bs "cmd" $null
  if (-not $cmd) {
    $contract = Join-Path $RepoRoot "browser-tests.contract.md"
    if (Test-Path $contract) {
      $lines = @(); try { $lines = Get-Content -LiteralPath $contract -ErrorAction SilentlyContinue } catch { $lines = @() }
      for ($i=0; $i -lt $lines.Count; $i++) {
        $t = ([string]$lines[$i]).Trim(); if (-not $t) { continue }
        if ($t -match '^(?i)(cmd|command)\s*:\s*(.+)$') { $cmd = $Matches[2].Trim(); break }
        if ($t -match '^(?i)(cmd|command)\s*:\s*$' -or $t -match '^(?i)<cmd>\s*$') {
          if (($i+1) -lt $lines.Count -and ([string]$lines[$i+1]).Trim().StartsWith('```')) {
            $j = $i + 2; $buf = New-Object System.Collections.Generic.List[string]
            while ($j -lt $lines.Count) { $x = [string]$lines[$j]; if ($x.Trim().StartsWith('```')) { break }; $buf.Add($x); $j++ }
            $cmd = ($buf -join "`n").Trim(); break
          }
        }
      }
    }
  }
  $ts = TsId; $log = Join-Path $LogsRoot ("terminal\browser-smoke-$ts.log")
  if (-not $cmd) {
    $started = $false; $mode = $null
    try {
      $pidPath = Join-Path $CiRoot "run\pyserver.pid.json"
      if (-not (Test-Path $pidPath)) { Cmd-PyserverStart; $started = $true }
      $j = Try-ReadJson $pidPath
      if ($j) { $mode = "pyserver"; $url = [string](Get-Prop $j "url" "http://127.0.0.1:8000/"); $port = [int](Get-Prop $j "port" 8000); $null = Wait-PortListening $port 10 }
    } catch { $null = $_ }
    if (-not $mode) {
      try {
        $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
        if (-not (Test-Path $pidPath)) { Cmd-DevserverStart; $started = $true }
        $j = Try-ReadJson $pidPath
        if ($j) { $mode = "devserver"; $url = [string](Get-Prop $j "url" "http://localhost:8200/"); $port = [int](Get-Prop $j "port" 8200); $null = Wait-PortListening $port 15 }
      } catch { $null = $_ }
    }
    if (-not $mode) { throw "browser-smoke requires browser_smoke.cmd in .ci/ci.config.json OR a runnable contract command in browser-tests.contract.md OR a working pyserver/devserver configuration." }
    $ok = $false
    try {
      CI-Info ("browser-smoke(auto): GET " + $url + " (mode=" + $mode + ")"); Add-Content -LiteralPath $log -Value ("AUTO GET: " + $url + "`r`n") -Encoding UTF8
      $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10; $code = 0; try { $code = [int]$resp.StatusCode } catch { $code = 0 }
      if ($code -eq 200) { $ok = $true }; Add-Content -LiteralPath $log -Value ("HTTP " + $code + "`r`n") -Encoding UTF8
    } catch { Add-Content -LiteralPath $log -Value ("ERROR: " + $_.Exception.Message + "`r`n") -Encoding UTF8; $ok = $false }
    finally { if ($started -and $mode -eq "pyserver") { try { Cmd-PyserverStop } catch { $null = $_ } }; if ($started -and $mode -eq "devserver") { try { Cmd-DevserverStop } catch { $null = $_ } } }
    if (-not $ok) { throw "browser-smoke failed (auto). See $log" }; return
  }
  $res = Run-Cmd ([string]$cmd) $log; if ($res.exit -ne 0) { throw "browser-smoke failed. See $log" }
}
function Get-ListeningPid([int]$port) {
  try { $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { return [int]$c.OwningProcess } } catch { $null = $_ }; return $null
}

function Wait-PortListening([int]$port, [int]$timeoutSec=30) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) { $listenPid = Get-ListeningPid $port; if ($listenPid) { return $listenPid }; Start-Sleep -Milliseconds 250 }
  return $null
}

function Get-DevserverHealth([string]$baseUrl, [int]$timeoutSec=10) {
  $healthUrl = ([string]$baseUrl).TrimEnd('/') + "/__devserver/health"
  $response = $null
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $healthUrl -TimeoutSec $timeoutSec -ErrorAction Stop
  } catch {
    $webResponse = $null
    try { $webResponse = $_.Exception.Response } catch { $webResponse = $null }
    if (-not $webResponse) { throw }
    $content = $null
    try {
      $stream = $webResponse.GetResponseStream()
      if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Dispose()
      }
    } catch { $content = $null }
    $response = @{
      StatusCode = [int]$webResponse.StatusCode
      Content = $content
    }
  }
  $payload = $null
  try { $payload = $response.Content | ConvertFrom-Json } catch { $payload = $null }
  return @{
    url = $healthUrl
    statusCode = [int]$response.StatusCode
    payload = $payload
  }
}

function Cmd-DevserverStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath); $ds = Get-Prop $cfg "devserver" $null; $port = [int](Get-Prop $ds "port" 8200); $timeoutSec = [int](Get-Prop $ds "wait_timeout_sec" 30); $waitReady = [bool](Get-Prop $ds "wait_ready" $true)
  $cmdOverride = Get-Prop $ds "cmd" $null
  $cwdOverride = Get-Prop $ds "cwd" $null
  $bs = Detect-BuildSystem
  $pidPath = Join-Path $CiRoot "run\devserver.pid.json"; if (Test-Path $pidPath) { Cmd-DevserverStop }
  $logDir = Join-Path $LogsRoot "devserver"; Ensure-Dir $logDir; $logPath = Join-Path $logDir "devserver.log"
  if (Test-Path $logPath) { try { if ((Get-Item -LiteralPath $logPath).Length -gt 200kb) { Move-Item -Force -LiteralPath $logPath -Destination (Join-Path $logDir ("devserver-" + (TsId) + ".log")) } } catch { $null = $_ } }
  $logRel = "logs\devserver\devserver.log"; Ensure-NonInteractiveEnv
  $devCwd = $RepoRoot
  if ($cwdOverride) {
    $overrideText = [string]$cwdOverride
    if ([System.IO.Path]::IsPathRooted($overrideText)) { $devCwd = $overrideText } else { $devCwd = Join-Path $RepoRoot $overrideText }
  } elseif ($bs -eq "node") {
    $nestedWebDir = Join-Path $RepoRoot "web"
    if ((Test-Path (Join-Path $nestedWebDir "App.tsx")) -and (Test-Path (Join-Path $nestedWebDir "package.json"))) { $devCwd = $nestedWebDir }
  }
  if (-not (Test-Path -LiteralPath $devCwd)) { throw ("devserver-start: working directory does not exist: " + $devCwd) }

  $cmd = $null
  if ($cmdOverride) {
    $cmd = [string]$cmdOverride
  } elseif ($bs -eq "node") {
    $cmd = "npm run dev"
  } elseif ($bs -eq "gradle") {
    $task = Get-Prop $ds "task" ":web-adapter:jsBrowserDevelopmentRun"
    $g = Get-GradleCmdRaw; $gradleExe = [string](Get-Prop $g "cmd" $null)
    if (-not $gradleExe) { throw "devserver-start: gradle cmd not available (missing wrapper/pin)" }
    $projectCacheDir = Join-Path $CiRoot "run\\gradle-project-cache"
    Ensure-Dir $projectCacheDir
    $cmd = (Quote-IfNeeded $gradleExe) + " " + $task + " --project-cache-dir `"$projectCacheDir`" --console=plain"
  } else {
    throw "devserver-start: unsupported build system. Set .ci/ci.config.json -> devserver.cmd"
  }

  $header = "## $(TsId)`r`nCMD: $cmd`r`nPWD: $($devCwd)`r`n"
  try {
    Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  } catch {
    $fallbackName = "devserver-" + (TsId) + ".log"
    $logPath = Join-Path $logDir $fallbackName
    $logRel = "logs\devserver\" + $fallbackName
    Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  }
  $cmdLine = "$cmd >> `"$logPath`" 2>&1"; CI-Info ("run(detached): " + $cmd + " | cwd=" + $devCwd + " | log=" + $logPath)
  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/d","/c",$cmdLine -WorkingDirectory $devCwd -PassThru -WindowStyle Hidden
  if (-not $p) { throw "devserver-start failed: Start-Process returned null." }
  @{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=$devCwd; port=$port; url=("http://localhost:" + $port + "/"); log=$logRel } | ConvertTo-Json -Compress | Set-Content -LiteralPath $pidPath -NoNewline -Encoding UTF8
  if ($waitReady) {
    $lp = Wait-PortListening $port $timeoutSec
    if (-not $lp) { throw ("devserver-start: port " + $port + " not listening after " + $timeoutSec + "s. See " + $logPath) }
    $health = $null
    try { $health = Get-DevserverHealth ("http://localhost:" + $port) 10 } catch { throw ("devserver-start: health check failed for http://localhost:" + $port + "/__devserver/health. See " + $logPath + " :: " + $_.Exception.Message) }
    $healthPayload = Get-Prop $health "payload" $null
    $healthOk = $true
    if ($healthPayload) {
      try { $healthOk = [bool](Get-Prop $healthPayload "ok" $true) } catch { $healthOk = $true }
    }
    if (-not $healthOk) {
      $issues = @()
      try {
        $assetAudit = Get-Prop $healthPayload "assetAudit" $null
        if ($assetAudit) {
          $assetIssues = @(Get-Prop $assetAudit "issues" @())
          foreach ($issue in $assetIssues) { if ($issue) { $issues += [string]$issue } }
        }
      } catch { $null = $_ }
      $startupFailure = $null
      try { $startupFailure = [string](Get-Prop (Get-Prop $healthPayload "startupFailure" $null) "message" $null) } catch { $startupFailure = $null }
      if ($startupFailure) { $issues += $startupFailure }
      $issueText = if ($issues.Count -gt 0) { $issues -join "; " } else { "recovery mode active" }
      throw ("devserver-start: asset contract failed; recovery page active at http://localhost:" + $port + "/ :: " + $issueText + ". See " + $logPath)
    }
  }
  CI-Info ("devserver-start: pid=" + $p.Id + " url=http://localhost:" + $port + "/")
}

function Cmd-DevserverStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $cfg = Try-ReadJson (Get-ConfigPath); $ds = Get-Prop $cfg "devserver" $null; $port = [int](Get-Prop $ds "port" 8200); $pidPath = Join-Path $CiRoot "run\devserver.pid.json"; $killed = $false
  if (Test-Path $pidPath) {
    try { $j = Get-Content -LiteralPath $pidPath -Raw | ConvertFrom-Json; $devPid = [int](Get-Prop $j "pid" 0); if ($devPid -gt 0) { CI-Info ("devserver-stop: taskkill /PID " + $devPid); cmd.exe /d /c ("taskkill /PID " + $devPid + " /T /F >nul 2>&1"); $killed = $true } } catch { $null = $_ }
    try { Remove-Item -Force -LiteralPath $pidPath -ErrorAction SilentlyContinue } catch { $null = $_ }
  }
  $pid2 = Get-ListeningPid $port; if ($pid2) { CI-Info ("devserver-stop: killing port " + $port + " pid=" + $pid2); cmd.exe /d /c ("taskkill /PID " + $pid2 + " /T /F >nul 2>&1"); $killed = $true }
  if (-not $killed) { CI-Info "devserver-stop: nothing to stop" }
}

function Cmd-DevserverStatus() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
  if (-not (Test-Path $pidPath)) { CI-Info "devserver-status: not running (no pid file)"; return }
  $j = Try-ReadJson $pidPath; if (-not $j) { CI-Info "devserver-status: pid file corrupt"; return }
  $devPid = [int](Get-Prop $j "pid" 0); $port = [int](Get-Prop $j "port" 8200); $lp = Get-ListeningPid $port
  CI-Info ("devserver-status: pid=" + $devPid + " port=" + $port + " listening=" + [string]([bool]$lp) + " url=" + (Get-Prop $j "url" ""))
}

function Cmd-PyserverStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $cfg = Try-ReadJson (Get-ConfigPath); $ps = Get-Prop $cfg "pyserver" $null; $root = Get-Prop $ps "root" $null
  if (-not $root) {
    $candidates = @("web-adapter\build\dist\js\productionExecutable", "web-adapter\build\dist\js\developmentExecutable", "web-adapter\build\kotlin-webpack\js\productionExecutable", "web-adapter\build\kotlin-webpack\js\developmentExecutable", "web-adapter\build\processedResources\js\main", "web\build\dist\js\productionExecutable", "web\build\dist\js\developmentExecutable", "web\build\kotlin-webpack\js\productionExecutable", "web\build\kotlin-webpack\js\developmentExecutable", "web\build\processedResources\js\main", "build\dist\js\productionExecutable", "build\dist\js\developmentExecutable", "build\kotlin-webpack\js\productionExecutable", "build\kotlin-webpack\js\developmentExecutable", "build\processedResources\js\main")
    foreach ($c in $candidates) { if (Test-Path (Join-Path $RepoRoot $c)) { $root = $c; break } }
  }
  if (-not $root) { throw "pyserver-start: root folder not found. Set .ci/ci.config.json -> pyserver.root" }
  $port = [int](Get-Prop $ps "port" 8000); $pidPath = Join-Path $CiRoot "run\pyserver.pid.json"; if (Test-Path $pidPath) { Cmd-PyserverStop }
  $logDir = Join-Path $LogsRoot "devserver"; Ensure-Dir $logDir; $logPath = Join-Path $logDir "pyserver.log"; $logRel = "logs\devserver\pyserver.log"; $cwdAbs = Join-Path $RepoRoot $root
  $cmd = "python -m http.server $port --bind 127.0.0.1"; $header = "## $(TsId)`r`nCMD: $cmd`r`nPWD: $cwdAbs`r`n"; Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  $cmdLine = "$cmd >> $logRel 2>&1"; CI-Info ("run(detached): " + $cmd + " | log=" + $logPath)
  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/d","/c",$cmdLine -WorkingDirectory $cwdAbs -PassThru -WindowStyle Hidden
  if (-not $p) { throw "pyserver-start failed: Start-Process returned null." }
  @{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$cmd; cwd=$cwdAbs; port=$port; url=("http://127.0.0.1:" + $port + "/"); log=$logRel } | ConvertTo-Json -Compress | Set-Content -LiteralPath $pidPath -NoNewline -Encoding UTF8
  $waitReady = [bool](Get-Prop $ps "wait_ready" $true)
  if ($waitReady) { $timeoutSec = [int](Get-Prop $ps "wait_timeout_sec" 10); $lp = Wait-PortListening $port $timeoutSec; if (-not $lp) { CI-Warn ("pyserver-start: port " + $port + " not listening after " + $timeoutSec + "s. See " + $logPath) } }
  CI-Info ("pyserver-start: pid=" + $p.Id + " url=http://127.0.0.1:" + $port + "/")
}

function Cmd-PyserverStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Join-Path $CiRoot "run\pyserver.pid.json"; $killed = $false
  if (Test-Path $pidPath) {
    try { $j = Get-Content -LiteralPath $pidPath -Raw | ConvertFrom-Json; $pyPid = [int](Get-Prop $j "pid" 0); if ($pyPid -gt 0) { CI-Info ("pyserver-stop: taskkill /PID " + $pyPid); cmd.exe /d /c ("taskkill /PID " + $pyPid + " /T /F >nul 2>&1"); $killed = $true } } catch { $null = $_ }
    try { Remove-Item -Force -LiteralPath $pidPath -ErrorAction SilentlyContinue } catch { $null = $_ }
  }
  $pid2 = Get-ListeningPid 8000; if ($pid2) { CI-Info ("pyserver-stop: killing port 8000 pid=" + $pid2); cmd.exe /d /c ("taskkill /PID " + $pid2 + " /T /F >nul 2>&1"); $killed = $true }
  if (-not $killed) { CI-Info "pyserver-stop: nothing to stop" }
}

function Cmd-PyserverStatus() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Join-Path $CiRoot "run\pyserver.pid.json"
  if (-not (Test-Path $pidPath)) { CI-Info "pyserver-status: not running (no pid file)"; return }
  $j = Try-ReadJson $pidPath; if (-not $j) { CI-Info "pyserver-status: pid file corrupt"; return }
  $pyPid = [int](Get-Prop $j "pid" 0); $port = [int](Get-Prop $j "port" 8000); $lp = Get-ListeningPid $port
  CI-Info ("pyserver-status: pid=" + $pyPid + " port=" + $port + " listening=" + [string]([bool]$lp) + " url=" + (Get-Prop $j "url" ""))
}
