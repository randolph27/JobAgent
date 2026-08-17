function Get-SonarStatusUrl() {
  $baseUrl = [string]$env:SONAR_HOST_URL
  if (-not $baseUrl) { $baseUrl = "http://127.0.0.1:9000" }
  return ($baseUrl.TrimEnd("/") + "/api/system/status")
}

function Test-SonarServerHealthy([string]$statusUrl = $(Get-SonarStatusUrl), [int]$timeoutSec = 5) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $statusUrl -TimeoutSec $timeoutSec
    if ($resp.Content -match '"status":"UP"') {
      return @{ ok = $true; content = [string]$resp.Content }
    }
  } catch { $null = $_ }
  return @{ ok = $false; content = $null }
}

function Get-SonarStatusSnapshot([string]$statusUrl = $(Get-SonarStatusUrl), [int]$timeoutSec = 5) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $statusUrl -TimeoutSec $timeoutSec
    $content = [string]$resp.Content
    $status = "UNKNOWN"
    try {
      $json = $content | ConvertFrom-Json
      $statusValue = [string](Get-Prop $json "status" "")
      if ($statusValue) { $status = $statusValue }
    } catch { $null = $_ }
    return @{ ok = ($status -eq "UP"); exit = 0; status = $status; content = $content; error = $null }
  } catch {
    return @{ ok = $false; exit = 1; status = "UNREACHABLE"; content = $null; error = [string]$_.Exception.Message }
  }
}

function Test-SonarDockerEngineBlocker([int]$exitCode, [string]$text) {
  if ($exitCode -eq 127) { return $true }
  if (-not $text) { return $false }
  return (
    $text -match 'docker_engine_unavailable' -or
    $text -match 'dockerDesktopLinuxEngine' -or
    $text -match 'The system cannot find the file specified'
  )
}

function Write-SonarDockerEngineEvidence([string]$logPath, [int]$exitCode, [string]$combinedOutput, [hashtable]$statusSnapshot) {
  $evidencePath = Join-Path $LogsRoot "verify\sq-004-sonarqube-docker-engine.md"
  $statusText = ""
  if ($statusSnapshot) {
    if ($statusSnapshot.content) { $statusText = [string]$statusSnapshot.content }
    elseif ($statusSnapshot.error) { $statusText = [string]$statusSnapshot.error }
  }
  if (-not $statusText) { $statusText = "not available" }

  $blockerClass = "docker_engine_unavailable"
  if (-not (Test-SonarDockerEngineBlocker $exitCode $combinedOutput)) { $blockerClass = "sonar_start_failed" }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# SQ-004 SonarQube Docker Engine Evidence")
  $lines.Add("")
  $lines.Add("- ts: " + (NowIso))
  $lines.Add("- blocker_class: " + $blockerClass)
  $lines.Add("- command: .\ci.cmd sonar-start")
  $lines.Add("- wrapper_command: sonar.cmd start")
  $lines.Add("- wrapper_exit: " + $exitCode)
  $lines.Add('- docker_preflight: docker version --format "{{.Server.Version}}"')
  $lines.Add("- docker_pipe: npipe:////./pipe/dockerDesktopLinuxEngine")
  $lines.Add("- expected_user_action: Docker Desktop starten")
  $lines.Add("- retry_command: .\ci.cmd sonar-start")
  $lines.Add("- status_check: curl.exe -s --max-time 10 http://localhost:9000/api/system/status")
  $lines.Add("- status_result: " + $statusText)
  $lines.Add("- terminal_log: " + (To-RelPath $logPath))
  $lines.Add("")
  $lines.Add("## Wrapper Output")
  $lines.Add("")
  $lines.Add('```text')
  if ($combinedOutput) {
    foreach ($line in (($combinedOutput -split "`r?`n") | Where-Object { $_ })) { $lines.Add([string]$line) }
  } else {
    $lines.Add("(empty)")
  }
  $lines.Add('```')
  Atomic-WriteTextUtf8 $evidencePath (($lines -join "`r`n") + "`r`n")
  return $evidencePath
}

function Invoke-SonarDockerReadOnly([string[]]$argsList) {
  try {
    $output = @(& docker @argsList 2>&1)
    return @{ exit = [int]$LASTEXITCODE; output = (($output | ForEach-Object { [string]$_ }) -join "`n") }
  } catch {
    return @{ exit = 1; output = [string]$_.Exception.Message }
  }
}

function Invoke-SonarExternalReadOnly([string]$exe, [string[]]$argsList) {
  $cmdText = $exe
  if ($argsList) { $cmdText = ($cmdText + " " + ($argsList -join " ")) }
  try {
    $output = @(& $exe @argsList 2>&1)
    $text = (($output | ForEach-Object { [string]$_ }) -join "`n") -replace "`0", ""
    return @{ cmd = $cmdText; exit = [int]$LASTEXITCODE; output = $text }
  } catch {
    return @{ cmd = $cmdText; exit = 1; output = ([string]$_.Exception.Message -replace "`0", "") }
  }
}

function Test-SonarUbuntu2204Available([string]$wslListOutput) {
  if (-not $wslListOutput) { return $false }
  $normalized = ($wslListOutput -replace "`0", "")
  return ($normalized -match '(^|\s)Ubuntu-22\.04(\s|$)')
}

function Get-SonarFirstIpv4([string]$text) {
  if (-not $text) { return $null }
  $m = [regex]::Match($text, '\b(?:\d{1,3}\.){3}\d{1,3}\b')
  if ($m.Success) { return [string]$m.Value }
  return $null
}

function Test-SonarPortProxy9000Mapping([string]$portProxyOutput, [string]$wslIp = $null) {
  if (-not $portProxyOutput) { return $false }
  $normalized = ($portProxyOutput -replace "`0", "")
  foreach ($line in ($normalized -split "`r?`n")) {
    $l = [string]$line
    if ($l -notmatch '\b9000\b') { continue }
    if ($wslIp -and $l -notmatch [regex]::Escape($wslIp)) { continue }
    if ($l -match '(\b127\.0\.0\.1\b|\b0\.0\.0\.0\b|\*)' -or $l -match '\b9000\b') { return $true }
  }
  return $false
}

function Get-SonarWslFallbackDecision([hashtable]$diag) {
  $status = Get-Prop $diag "status" $null
  if ([bool](Get-Prop $status "ok" $false)) {
    return @{ blocker_class = "none"; next_command = ""; reusable = $true }
  }

  $wslList = Get-Prop $diag "wsl_list" $null
  if ([int](Get-Prop $wslList "exit" 1) -ne 0) {
    return @{ blocker_class = "wsl_missing"; next_command = "wsl.exe --install -d Ubuntu-22.04"; reusable = $false }
  }

  if (-not [bool](Get-Prop $diag "ubuntu_2204" $false)) {
    return @{ blocker_class = "ubuntu_2204_missing"; next_command = "wsl.exe --install -d Ubuntu-22.04"; reusable = $false }
  }

  $wslIp = Get-Prop $diag "wsl_ip" $null
  if ([int](Get-Prop $wslIp "exit" 1) -ne 0 -or -not [string](Get-Prop $diag "wsl_ip_value" "")) {
    return @{ blocker_class = "wsl_ip_missing"; next_command = 'wsl.exe -d Ubuntu-22.04 -- sh -lc "hostname -I | awk ''{print $1}''"'; reusable = $false }
  }

  $portProxy = Get-Prop $diag "portproxy" $null
  if ([int](Get-Prop $portProxy "exit" 1) -ne 0 -or -not [bool](Get-Prop $diag "portproxy_has_9000" $false)) {
    $ip = [string](Get-Prop $diag "wsl_ip_value" "<WSL-IP>")
    return @{ blocker_class = "portproxy_missing"; next_command = ("netsh interface portproxy add v4tov4 listenport=9000 listenaddress=127.0.0.1 connectport=9000 connectaddress=" + $ip); reusable = $false }
  }

  $statusName = [string](Get-Prop $status "status" "")
  if ($statusName -eq "UNREACHABLE") {
    return @{ blocker_class = "sonarqube_wsl_not_started"; next_command = 'wsl.exe -d Ubuntu-22.04 -- sh -lc "su -s /bin/bash sonar -c ''.sonarqube/dist/sonarqube-26.1.0.118079/bin/linux-x86-64/sonar.sh start''"'; reusable = $false }
  }

  return @{ blocker_class = "localhost_status_unreachable"; next_command = "curl.exe -s --max-time 10 http://localhost:9000/api/system/status"; reusable = $false }
}

function Get-SonarWslFallbackDiagnostics([string]$statusUrl) {
  $wslList = Invoke-SonarExternalReadOnly "wsl.exe" @("-l", "-v")
  $ubuntu = $false
  if ([int](Get-Prop $wslList "exit" 1) -eq 0) { $ubuntu = Test-SonarUbuntu2204Available ([string](Get-Prop $wslList "output" "")) }

  $wslIp = @{ cmd = 'wsl.exe -d Ubuntu-22.04 -- sh -lc "hostname -I"'; exit = 1; output = "" }
  $wslIpValue = $null
  if ($ubuntu) {
    $wslIp = Invoke-SonarExternalReadOnly "wsl.exe" @("-d", "Ubuntu-22.04", "--", "sh", "-lc", "hostname -I")
    if ([int](Get-Prop $wslIp "exit" 1) -eq 0) { $wslIpValue = Get-SonarFirstIpv4 ([string](Get-Prop $wslIp "output" "")) }
  }

  $portProxy = Invoke-SonarExternalReadOnly "netsh" @("interface", "portproxy", "show", "v4tov4")
  $hasMapping = $false
  if ([int](Get-Prop $portProxy "exit" 1) -eq 0) { $hasMapping = Test-SonarPortProxy9000Mapping ([string](Get-Prop $portProxy "output" "")) $wslIpValue }

  $status = Get-SonarStatusSnapshot $statusUrl 10
  return @{
    wsl_list = $wslList
    ubuntu_2204 = $ubuntu
    wsl_ip = $wslIp
    wsl_ip_value = $wslIpValue
    portproxy = $portProxy
    portproxy_has_9000 = $hasMapping
    status = $status
  }
}

function Add-SonarEvidenceCommandBlock([System.Collections.Generic.List[string]]$lines, [string]$title, [hashtable]$result) {
  $lines.Add("### " + $title)
  $lines.Add("")
  $lines.Add("- command: " + [string](Get-Prop $result "cmd" ""))
  $lines.Add("- exit: " + [string](Get-Prop $result "exit" ""))
  $lines.Add("")
  $lines.Add('```text')
  $output = [string](Get-Prop $result "output" "")
  if ($output) {
    foreach ($line in ($output -split "`r?`n")) { if ($line) { $lines.Add($line) } }
  } else {
    $lines.Add("(empty)")
  }
  $lines.Add('```')
  $lines.Add("")
}

function Write-SonarWslFallbackEvidence([string]$logPath, [int]$dockerExitCode, [string]$combinedOutput, [string]$statusUrl) {
  $evidencePath = Join-Path $LogsRoot "verify\sq-005-sonarqube-wsl-fallback.md"
  $diag = Get-SonarWslFallbackDiagnostics $statusUrl
  $decision = Get-SonarWslFallbackDecision $diag
  $statusSnapshot = Get-Prop $diag "status" $null
  $statusText = [string](Get-Prop $statusSnapshot "content" "")
  if (-not $statusText) { $statusText = [string](Get-Prop $statusSnapshot "error" "not available") }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# SQ-005 SonarQube WSL Portproxy Fallback")
  $lines.Add("")
  $lines.Add("- ts: " + (NowIso))
  $lines.Add("- command: .\ci.cmd sonar-start")
  $lines.Add("- docker_exit: " + $dockerExitCode)
  $lines.Add("- blocker_class: " + [string](Get-Prop $decision "blocker_class" ""))
  $lines.Add("- next_command: " + [string](Get-Prop $decision "next_command" ""))
  $lines.Add("- status_url: " + $statusUrl)
  $lines.Add("- status_result: " + $statusText)
  $lines.Add("- wsl_ip: " + [string](Get-Prop $diag "wsl_ip_value" ""))
  $lines.Add("- portproxy_has_9000: " + [string](Get-Prop $diag "portproxy_has_9000" $false))
  $lines.Add("- terminal_log: " + (To-RelPath $logPath))
  $lines.Add("")
  $lines.Add("## Read-only checks")
  $lines.Add("")
  Add-SonarEvidenceCommandBlock $lines "WSL distros" (Get-Prop $diag "wsl_list" $null)
  Add-SonarEvidenceCommandBlock $lines "WSL IP" (Get-Prop $diag "wsl_ip" $null)
  Add-SonarEvidenceCommandBlock $lines "Portproxy" (Get-Prop $diag "portproxy" $null)
  $lines.Add("### Status endpoint")
  $lines.Add("")
  $lines.Add("- command: curl.exe -s --max-time 10 http://localhost:9000/api/system/status")
  $lines.Add("- exit: " + [string](Get-Prop $statusSnapshot "exit" ""))
  $lines.Add("- status: " + [string](Get-Prop $statusSnapshot "status" ""))
  $lines.Add("")
  $lines.Add('```text')
  $lines.Add($statusText)
  $lines.Add('```')
  $lines.Add("")
  $lines.Add("## Docker wrapper output")
  $lines.Add("")
  $lines.Add('```text')
  if ($combinedOutput) {
    foreach ($line in (($combinedOutput -split "`r?`n") | Where-Object { $_ })) { $lines.Add([string]$line) }
  } else {
    $lines.Add("(empty)")
  }
  $lines.Add('```')
  Atomic-WriteTextUtf8 $evidencePath (($lines -join "`r`n") + "`r`n")

  return @{
    path = $evidencePath
    diagnostics = $diag
    decision = $decision
    status_snapshot = $statusSnapshot
    reusable = [bool](Get-Prop $decision "reusable" $false)
    blocker_class = [string](Get-Prop $decision "blocker_class" "")
  }
}

function Write-SonarStartSuccessEvidence([string]$logPath, [hashtable]$statusSnapshot) {
  $evidencePath = Join-Path $LogsRoot "verify\sq-004-sonarqube-docker-engine.md"
  $serverVersion = Invoke-SonarDockerReadOnly @("version", "--format", "{{.Server.Version}}")
  $containerStatus = Invoke-SonarDockerReadOnly @("ps", "-a", "--filter", "name=soundprofile-sonarqube-local", "--format", "{{.Names}}`t{{.Status}}`t{{.Ports}}")
  $statusText = [string](Get-Prop $statusSnapshot "content" "")
  if (-not $statusText) { $statusText = [string](Get-Prop $statusSnapshot "error" "not available") }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# SQ-004 SonarQube Docker Engine Evidence")
  $lines.Add("")
  $lines.Add("- ts: " + (NowIso))
  $lines.Add("- blocker_class: none")
  $lines.Add("- command: .\ci.cmd sonar-start")
  $lines.Add("- wrapper_command: sonar.cmd start")
  $lines.Add("- wrapper_exit: 0")
  $lines.Add('- docker_preflight: docker version --format "{{.Server.Version}}"')
  $lines.Add("- docker_server_version_exit: " + [string](Get-Prop $serverVersion "exit" ""))
  $lines.Add("- docker_server_version: " + [string](Get-Prop $serverVersion "output" ""))
  $lines.Add("- status_check: curl.exe -s --max-time 10 http://localhost:9000/api/system/status")
  $lines.Add("- status_result: " + $statusText)
  $lines.Add("- container_status_exit: " + [string](Get-Prop $containerStatus "exit" ""))
  $lines.Add("- terminal_log: " + (To-RelPath $logPath))
  $lines.Add("")
  $lines.Add("## Container Status")
  $lines.Add("")
  $lines.Add('```text')
  $containerOutput = [string](Get-Prop $containerStatus "output" "")
  if ($containerOutput) { foreach ($line in ($containerOutput -split "`r?`n")) { if ($line) { $lines.Add($line) } } }
  else { $lines.Add("(empty)") }
  $lines.Add('```')
  Atomic-WriteTextUtf8 $evidencePath (($lines -join "`r`n") + "`r`n")
  return $evidencePath
}

function Write-SonarRuntimeState([string]$cmd, [string]$logPath, [string]$statusUrl, [bool]$reused, [string]$status = $null, [string]$statusContent = $null) {
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"
  $baseUrl = $statusUrl -replace '/api/system/status$','/'
  Write-Json $pidPath @{
    ts = (NowIso)
    cmd = $cmd
    cwd = (Get-Location).Path
    port = 9000
    url = $baseUrl
    status_url = $statusUrl
    reused = $reused
    log = $logPath
    status = $status
    status_content = $statusContent
  }
}

function Cmd-SonarStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $statusUrl = Get-SonarStatusUrl
  $health = Test-SonarServerHealthy $statusUrl
  $logPath = Join-Path $LogsRoot ("terminal\sonar-start-" + (TsId) + ".log")
  New-Item -ItemType Directory -Force .ci/run, logs/terminal | Out-Null
  if ($health.ok) {
    Atomic-WriteTextUtf8 $logPath ("[sonar-start] reusing healthy SonarQube at " + $statusUrl + "`r`n")
    $statusSnapshot = Get-SonarStatusSnapshot $statusUrl 5
    $wslFallback = Write-SonarWslFallbackEvidence $logPath 0 "healthy status precheck reused existing SonarQube endpoint" $statusUrl
    if ([bool](Get-Prop $wslFallback "reusable" $false)) {
      Write-SonarRuntimeState "wsl-portproxy-reuse" $logPath $statusUrl $true "UP" ([string]$health.content)
    } else {
      Write-SonarRuntimeState "reuse" $logPath $statusUrl $true "UP" ([string]$health.content)
      $null = Write-SonarStartSuccessEvidence $logPath $statusSnapshot
    }
    CI-Info ("sonar-start: reusing healthy SonarQube at " + $statusUrl)
    return
  }

  CI-Info "sonar-start: starting SonarQube server..."
  $sonarCmdPath = Join-Path $RepoRoot "sonar.cmd"
  if (-not (Test-Path -LiteralPath $sonarCmdPath)) {
    throw "sonar-start: missing local wrapper '$sonarCmdPath'"
  }

  $res = $null
  try {
    $res = Run-Cmd ("cmd: `"" + $sonarCmdPath + "`" start") $logPath
  } catch {
    $logText = ""
    try {
      if (Test-Path -LiteralPath $logPath) { $logText = Get-Content -Raw -LiteralPath $logPath }
    } catch { $null = $_ }
    $exitCode = 1
    $msg = [string]$_.Exception.Message
    if ($msg -match 'exit code\s+(\d+)') { $exitCode = [int]$Matches[1] }
    elseif ($logText -match '"exit"\s*:\s*127') { $exitCode = 127 }
    $res = @{ exit = $exitCode; out = $logText; err = $msg }
  }
  if ($res.exit -ne 0) {
    $combined = ([string]$res.out + "`r`n" + [string]$res.err)
    $statusSnapshot = Get-SonarStatusSnapshot $statusUrl 10
    $evidencePath = Write-SonarDockerEngineEvidence $logPath ([int]$res.exit) $combined $statusSnapshot
    if (Test-SonarDockerEngineBlocker ([int]$res.exit) $combined) {
      $wslFallback = Write-SonarWslFallbackEvidence $logPath ([int]$res.exit) $combined $statusUrl
      $wslEvidencePath = [string](Get-Prop $wslFallback "path" $null)
      $wslStatusSnapshot = Get-Prop $wslFallback "status_snapshot" $statusSnapshot
      $statusContent = [string](Get-Prop $wslStatusSnapshot "content" $null)
      if (-not $statusContent) { $statusContent = [string](Get-Prop $wslStatusSnapshot "error" $null) }
      if ([bool](Get-Prop $wslFallback "reusable" $false)) {
        Write-SonarRuntimeState "wsl-portproxy-reuse" $logPath $statusUrl $true "UP" $statusContent
        CI-Info ("sonar-start: reusing WSL/portproxy SonarQube at " + $statusUrl + " evidence=" + (To-RelPath $wslEvidencePath))
        return
      }
      $blockerClass = [string](Get-Prop $wslFallback "blocker_class" "unknown")
      Write-SonarRuntimeState ("docker-engine-blocked+wsl-fallback-" + $blockerClass) $logPath $statusUrl $false ("BLOCKED_" + $blockerClass.ToUpperInvariant()) $statusContent
      throw ("sonar-start: docker_engine_unavailable; wsl_fallback=" + $blockerClass + ". Evidence: " + (To-RelPath $wslEvidencePath))
    }
    throw ("sonar-start: sonar.cmd start failed. Evidence: " + (To-RelPath $evidencePath))
  }

  $deadline = (Get-Date).AddSeconds(120)
  $ready = $false
  $lastSnapshot = $null
  while ((Get-Date) -lt $deadline) {
    $lastSnapshot = Get-SonarStatusSnapshot $statusUrl 5
    if ([bool](Get-Prop $lastSnapshot "ok" $false)) {
      $ready = $true
      break
    }
    Start-Sleep -Seconds 2
  }

  if (-not $ready) {
    CI-Warn ("sonar-start: status endpoint noch nicht UP (" + $statusUrl + "). Sonar kann noch warm-up laufen.")
  }

  $statusValue = [string](Get-Prop $lastSnapshot "status" "UNKNOWN")
  $statusContent = [string](Get-Prop $lastSnapshot "content" $null)
  Write-SonarRuntimeState "sonar.cmd start" $logPath $statusUrl $false $statusValue $statusContent
  $null = Write-SonarStartSuccessEvidence $logPath $lastSnapshot
  CI-Info ("sonar-start: local wrapper executed. log=" + $logPath)
}

function Cmd-SonarStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  CI-Info "sonar-stop: stopping SonarQube server..."
  $pidPath = Join-Path $CiRoot "run\sonar.pid.json"
  $logPath = Join-Path $LogsRoot ("terminal\sonar-stop-" + (TsId) + ".log")
  $sonarCmdPath = Join-Path $RepoRoot "sonar.cmd"

  if (Test-Path -LiteralPath $sonarCmdPath) {
    $res = Run-Cmd ("cmd: `"" + $sonarCmdPath + "`" stop") $logPath
    Remove-Item $pidPath -ErrorAction SilentlyContinue
    if ($res.exit -ne 0) {
      throw ("sonar-stop: sonar.cmd stop failed. See " + $logPath)
    }
    CI-Info ("sonar-stop: local wrapper executed. log=" + $logPath)
    return
  }

  $processId = (Get-NetTCPConnection -LocalPort 9000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty OwningProcess)
  if ($processId) {
    Stop-Process -Id $processId -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $pidPath -ErrorAction SilentlyContinue
  CI-Warn "sonar-stop: fallback used (local sonar.cmd missing)."
}
