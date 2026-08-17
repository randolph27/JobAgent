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
  $configuredUrl = [string](Get-Prop $bs "url" "")
  if ($configuredUrl) {
    $digestPath = Join-Path $LogsRoot "verify\browser.smoke.digest.json"
    $result = Invoke-BrowserSmokeAssetProbe -RootUrl $configuredUrl -DigestPath $digestPath
    if (-not [bool](Get-Prop $result "ok" $false)) {
      throw ("browser-smoke failed asset/MIME contract. See " + $digestPath)
    }
    return
  }
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
        if ($j) { $mode = "devserver"; $url = [string](Get-Prop $j "url" "http://localhost:8080/"); $port = [int](Get-Prop $j "port" 8080); $null = Wait-PortListening $port 15 }
      } catch { $null = $_ }
    }
    if (-not $mode) { throw "browser-smoke requires browser_smoke.cmd in .ci/ci.config.json OR a runnable contract command in browser-tests.contract.md OR a working pyserver/devserver configuration." }
    $ok = $false
    try {
      CI-Info ("browser-smoke(auto): asset/MIME probe " + $url + " (mode=" + $mode + ")"); Add-Content -LiteralPath $log -Value ("AUTO ASSET PROBE: " + $url + "`r`n") -Encoding UTF8
      $digestPath = Join-Path $LogsRoot "verify\browser.smoke.digest.json"
      $probe = Invoke-BrowserSmokeAssetProbe -RootUrl $url -DigestPath $digestPath
      $ok = [bool](Get-Prop $probe "ok" $false)
      Add-Content -LiteralPath $log -Value ("DIGEST: " + $digestPath + "`r`nOK: " + $ok + "`r`n") -Encoding UTF8
    } catch { Add-Content -LiteralPath $log -Value ("ERROR: " + $_.Exception.Message + "`r`n") -Encoding UTF8; $ok = $false }
    finally { if ($started -and $mode -eq "pyserver") { try { Cmd-PyserverStop } catch { $null = $_ } }; if ($started -and $mode -eq "devserver") { try { Cmd-DevserverStop } catch { $null = $_ } } }
    if (-not $ok) { throw "browser-smoke failed (auto). See $log" }; return
  }
  $res = Run-Cmd ([string]$cmd) $log; if ($res.exit -ne 0) { throw "browser-smoke failed. See $log" }
}

function Resolve-BrowserSmokeUrl([string]$rootUrl, [string]$assetRef) {
  $root = [System.Uri]::new($rootUrl)
  return ([System.Uri]::new($root, $assetRef)).AbsoluteUri
}

function Test-BrowserSmokeSameOrigin([string]$rootUrl, [string]$assetUrl) {
  try {
    $root = [System.Uri]::new($rootUrl)
    $asset = [System.Uri]::new($assetUrl)
    return ($root.Scheme -eq $asset.Scheme -and $root.Host -eq $asset.Host -and $root.Port -eq $asset.Port)
  } catch {
    return $false
  }
}

function Get-BrowserSmokeAssetKind([string]$assetUrl) {
  $path = ""
  try { $path = ([System.Uri]::new($assetUrl)).AbsolutePath.ToLowerInvariant() } catch { $path = ([string]$assetUrl).ToLowerInvariant() }
  if ($path.EndsWith(".wasm")) { return "wasm" }
  if ($path.EndsWith(".js") -or $path.EndsWith(".mjs")) { return "js" }
  return $null
}

function Get-BrowserSmokeAssetRefs([string]$html, [string]$rootUrl, [int]$maxAssets=10) {
  $refs = New-Object System.Collections.Generic.List[string]
  $patterns = @(
    '(?is)<script\b[^>]*\bsrc\s*=\s*["'']([^"'']+)["'']',
    '(?is)<link\b[^>]*\bhref\s*=\s*["'']([^"'']+)["'']',
    '(?is)<[^>]+\b(?:src|href)\s*=\s*["'']([^"'']+\.(?:js|mjs|wasm)(?:\?[^"'']*)?)["'']'
  )
  foreach ($pattern in $patterns) {
    foreach ($match in [regex]::Matches($html, $pattern)) {
      if ($refs.Count -ge $maxAssets) { break }
      $raw = [string]$match.Groups[1].Value
      if (-not $raw) { continue }
      if ($raw -match '^(?i)data:|javascript:|mailto:') { continue }
      $absolute = Resolve-BrowserSmokeUrl $rootUrl $raw
      if (-not (Get-BrowserSmokeAssetKind $absolute)) { continue }
      if (-not (Test-BrowserSmokeSameOrigin -rootUrl $rootUrl -assetUrl $absolute)) { continue }
      if (-not $refs.Contains($absolute)) { $refs.Add($absolute) }
    }
    if ($refs.Count -ge $maxAssets) { break }
  }
  return @($refs)
}

function Get-BrowserSmokeManifestAssetRefs([string]$scriptText, [string]$rootUrl, [string[]]$existingRefs, [int]$maxAssets=10) {
  $refs = New-Object System.Collections.Generic.List[string]
  $seenPaths = @{}
  foreach ($ref in @($existingRefs)) {
    if ($ref -and -not $refs.Contains($ref)) {
      $refs.Add($ref)
      try { $seenPaths[([System.Uri]::new($ref).AbsolutePath.ToLowerInvariant())] = $true } catch { $null = $_ }
    }
  }

  $candidates = New-Object System.Collections.Generic.List[string]
  $webBundleMatch = [regex]::Match($scriptText, '(?is)["'']webBundle["'']\s*:\s*["'']([^"'']+\.(?:js|mjs)(?:\?[^"'']*)?)["'']')
  if ($webBundleMatch.Success) { $candidates.Add([string]$webBundleMatch.Groups[1].Value) }

  $stockfishMatch = [regex]::Match($scriptText, '(?is)["'']stockfishCoreAssets["'']\s*:\s*\[(.*?)\]')
  if ($stockfishMatch.Success) {
    foreach ($match in [regex]::Matches([string]$stockfishMatch.Groups[1].Value, '["'']([^"'']+\.(?:js|mjs|wasm)(?:\?[^"'']*)?)["'']')) {
      $candidates.Add([string]$match.Groups[1].Value)
    }
  }

  if ($candidates.Count -eq 0) {
    foreach ($match in [regex]::Matches($scriptText, '["'']([^"'']+\.(?:js|mjs|wasm)(?:\?[^"'']*)?)["'']')) {
      $candidates.Add([string]$match.Groups[1].Value)
    }
  }

  foreach ($rawCandidate in $candidates) {
    if ($refs.Count -ge $maxAssets) { break }
    $raw = [string]$rawCandidate
    if (-not $raw) { continue }
    $absolute = Resolve-BrowserSmokeUrl $rootUrl $raw
    if (-not (Get-BrowserSmokeAssetKind $absolute)) { continue }
    if (-not (Test-BrowserSmokeSameOrigin -rootUrl $rootUrl -assetUrl $absolute)) { continue }
    $pathKey = ""
    try { $pathKey = ([System.Uri]::new($absolute).AbsolutePath.ToLowerInvariant()) } catch { $pathKey = $absolute.ToLowerInvariant() }
    if ($seenPaths.ContainsKey($pathKey)) { continue }
    if (-not $refs.Contains($absolute)) {
      $refs.Add($absolute)
      $seenPaths[$pathKey] = $true
    }
  }

  return @($refs)
}

function Test-BrowserSmokeHtmlFallback([byte[]]$bytes, [string]$contentType) {
  if ($contentType -match '(?i)\btext/html\b') { return $true }
  if (-not $bytes -or $bytes.Length -eq 0) { return $false }
  $prefixLength = [Math]::Min($bytes.Length, 256)
  $prefix = [Text.Encoding]::UTF8.GetString($bytes, 0, $prefixLength).TrimStart()
  return ($prefix -match '^(?is)<!doctype\s+html\b|<html\b')
}

function Test-BrowserSmokeAssetContentType([string]$kind, [string]$contentType) {
  if (-not $contentType) { return $false }
  if ($kind -eq "wasm") { return ($contentType -match '(?i)\bapplication/wasm\b') }
  if ($kind -eq "js") {
    return ($contentType -match '(?i)\b(application|text)/(javascript|ecmascript|x-javascript)\b')
  }
  return $false
}

function Test-BrowserSmokeWasmMagic([byte[]]$bytes) {
  if (-not $bytes -or $bytes.Length -lt 4) { return $false }
  return ($bytes[0] -eq 0x00 -and $bytes[1] -eq 0x61 -and $bytes[2] -eq 0x73 -and $bytes[3] -eq 0x6d)
}

function Invoke-BrowserSmokeRequest([string]$url) {
  try {
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10 -ErrorAction Stop
    $contentType = ""
    try { $contentType = [string]$resp.Headers["Content-Type"] } catch { $contentType = "" }
    $bytes = [byte[]]@()
    if ($null -ne $resp.RawContentStream) {
      $ms = [IO.MemoryStream]::new()
      $resp.RawContentStream.CopyTo($ms)
      $bytes = $ms.ToArray()
    } elseif ($null -ne $resp.Content) {
      $bytes = [Text.Encoding]::UTF8.GetBytes([string]$resp.Content)
    }
    return @{
      status = [int]$resp.StatusCode
      content_type = $contentType
      bytes = $bytes
      text = [Text.Encoding]::UTF8.GetString($bytes)
      error = $null
    }
  } catch {
    $status = 0
    try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
    return @{
      status = $status
      content_type = ""
      bytes = [byte[]]@()
      text = ""
      error = [string]$_.Exception.Message
    }
  }
}

function Invoke-BrowserSmokeAssetProbe([string]$RootUrl, [string]$DigestPath) {
  $rootResult = Invoke-BrowserSmokeRequest $RootUrl
  $errors = New-Object System.Collections.Generic.List[string]
  if ([int]$rootResult.status -ne 200) { $errors.Add("root_status_" + [string]$rootResult.status) }
  if (Test-BrowserSmokeHtmlFallback -bytes ([byte[]]$rootResult.bytes) -contentType ([string]$rootResult.content_type)) {
    # Root HTML is expected; keep this branch intentionally empty for symmetry with asset checks.
  }

  $assetUrls = New-Object System.Collections.Generic.List[string]
  if ([int]$rootResult.status -eq 200) {
    foreach ($assetUrl in @(Get-BrowserSmokeAssetRefs -html ([string]$rootResult.text) -rootUrl $RootUrl -maxAssets 10)) {
      if (-not $assetUrls.Contains($assetUrl)) { $assetUrls.Add($assetUrl) }
    }
    if ($assetUrls.Count -eq 0) { $errors.Add("asset_inventory_empty") }
  }

  $assets = New-Object System.Collections.Generic.List[object]
  $assetIndex = 0
  while ($assetIndex -lt $assetUrls.Count -and $assetIndex -lt 10) {
    $assetUrl = [string]$assetUrls[$assetIndex]
    $assetIndex++
    $kind = Get-BrowserSmokeAssetKind $assetUrl
    $assetResult = Invoke-BrowserSmokeRequest $assetUrl
    if ($kind -eq "js" -and ([System.Uri]::new($assetUrl).AbsolutePath -match '(?i)/?pwa-assets\.generated\.js$')) {
      $expandedRefs = @(Get-BrowserSmokeManifestAssetRefs -scriptText ([string]$assetResult.text) -rootUrl $RootUrl -existingRefs $assetUrls.ToArray() -maxAssets 10)
      foreach ($expandedRef in $expandedRefs) {
        if ($assetUrls.Count -ge 10) { break }
        if (-not $assetUrls.Contains($expandedRef)) { $assetUrls.Add($expandedRef) }
      }
    }
    $assetErrors = New-Object System.Collections.Generic.List[string]
    if ([int]$assetResult.status -ne 200) { $assetErrors.Add("status_" + [string]$assetResult.status) }
    if (-not (Test-BrowserSmokeAssetContentType -kind $kind -contentType ([string]$assetResult.content_type))) { $assetErrors.Add("content_type_invalid") }
    if (Test-BrowserSmokeHtmlFallback -bytes ([byte[]]$assetResult.bytes) -contentType ([string]$assetResult.content_type)) { $assetErrors.Add("html_fallback") }
    if ($kind -eq "wasm" -and [int]$assetResult.status -eq 200 -and -not (Test-BrowserSmokeWasmMagic ([byte[]]$assetResult.bytes))) { $assetErrors.Add("wasm_magic_invalid") }
    foreach ($assetError in @($assetErrors)) {
      if ($errors.Count -lt 5) { $errors.Add(([System.Uri]::new($assetUrl).AbsolutePath + ":" + $assetError)) }
    }
    $assets.Add([pscustomobject]@{
      url = $assetUrl
      kind = $kind
      status = [int]$assetResult.status
      content_type = [string]$assetResult.content_type
      bytes = ([byte[]]$assetResult.bytes).Length
      ok = ($assetErrors.Count -eq 0)
      errors = @($assetErrors.ToArray())
    })
  }

  $digest = [pscustomobject]@{
    ts = (NowIso)
    ok = ($errors.Count -eq 0)
    root = [pscustomobject]@{
      url = $RootUrl
      status = [int]$rootResult.status
      content_type = [string]$rootResult.content_type
    }
    asset_count = $assets.Count
    assets = @($assets.ToArray())
    errors = @($errors.ToArray() | Select-Object -First 5)
  }
  Write-Json $DigestPath $digest
  return $digest
}

function Get-ListeningPid([int]$port) {
  try { $c = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { return [int]$c.OwningProcess } } catch { $null = $_ }; return $null
}

function Wait-PortListening([int]$port, [int]$timeoutSec=30) {
  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) { $listenPid = Get-ListeningPid $port; if ($listenPid) { return $listenPid }; Start-Sleep -Milliseconds 250 }
  return $null
}

function Cmd-DevserverStart() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $cfg = Try-ReadJson (Get-ConfigPath); $ds = Get-Prop $cfg "devserver" $null; $task = Get-Prop $ds "task" ":web-adapter:jsBrowserDevelopmentRun"; $port = [int](Get-Prop $ds "port" 8080); $timeoutSec = [int](Get-Prop $ds "wait_timeout_sec" 30); $waitReady = [bool](Get-Prop $ds "wait_ready" $true)
  $pidPath = Join-Path $CiRoot "run\devserver.pid.json"; if (Test-Path $pidPath) { Cmd-DevserverStop }
  $logDir = Join-Path $LogsRoot "devserver"; Ensure-Dir $logDir; $logPath = Join-Path $logDir "devserver.log"
  if (Test-Path $logPath) { try { if ((Get-Item -LiteralPath $logPath).Length -gt 200kb) { Move-Item -Force -LiteralPath $logPath -Destination (Join-Path $logDir ("devserver-" + (TsId) + ".log")) } } catch { $null = $_ } }
  $logRel = "logs\devserver\devserver.log"; Ensure-NonInteractiveEnv; $g = Get-GradleCmdRaw; $gradleExe = [string](Get-Prop $g "cmd" $null)
  if (-not $gradleExe) { throw "devserver-start: gradle cmd not available (missing wrapper/pin)" }
  $projectCacheDir = Join-Path $CiRoot "run\\gradle-project-cache"
  Ensure-Dir $projectCacheDir
  $gradleCmd = (Quote-IfNeeded $gradleExe) + " " + $task + " --project-cache-dir `"$projectCacheDir`" --console=plain"; $header = "## $(TsId)`r`nCMD: $gradleCmd`r`nPWD: $($RepoRoot)`r`n"; Set-Content -LiteralPath $logPath -Value $header -Encoding UTF8
  $cmdLine = "$gradleCmd >> $logRel 2>&1"; CI-Info ("run(detached): " + $gradleCmd + " | log=" + $logPath)
  $p = Start-Process -FilePath "cmd.exe" -ArgumentList "/d","/c",$cmdLine -WorkingDirectory $RepoRoot -PassThru -WindowStyle Hidden
  if (-not $p) { throw "devserver-start failed: Start-Process returned null." }
  @{ ts=(Get-Date).ToString("o"); pid=$p.Id; cmd=$gradleCmd; cwd=$RepoRoot; port=$port; url=("http://localhost:" + $port + "/"); log=$logRel } | ConvertTo-Json -Compress | Set-Content -LiteralPath $pidPath -NoNewline -Encoding UTF8
  if ($waitReady) { $lp = Wait-PortListening $port $timeoutSec; if (-not $lp) { throw ("devserver-start: port " + $port + " not listening after " + $timeoutSec + "s. See " + $logPath) } }
  CI-Info ("devserver-start: pid=" + $p.Id + " url=http://localhost:" + $port + "/")
}

function Cmd-DevserverStop() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Join-Path $CiRoot "run\devserver.pid.json"; $killed = $false
  if (Test-Path $pidPath) {
    try { $j = Get-Content -LiteralPath $pidPath -Raw | ConvertFrom-Json; $devPid = [int](Get-Prop $j "pid" 0); if ($devPid -gt 0) { CI-Info ("devserver-stop: taskkill /PID " + $devPid); cmd.exe /d /c ("taskkill /PID " + $devPid + " /T /F >nul 2>&1"); $killed = $true } } catch { $null = $_ }
    try { Remove-Item -Force -LiteralPath $pidPath -ErrorAction SilentlyContinue } catch { $null = $_ }
  }
  $pid2 = Get-ListeningPid 8080; if ($pid2) { CI-Info ("devserver-stop: killing port 8080 pid=" + $pid2); cmd.exe /d /c ("taskkill /PID " + $pid2 + " /T /F >nul 2>&1"); $killed = $true }
  if (-not $killed) { CI-Info "devserver-stop: nothing to stop" }
}

function Cmd-DevserverStatus() {
  Ensure-CoreFolders; Ensure-BootstrapFiles; $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
  if (-not (Test-Path $pidPath)) { CI-Info "devserver-status: not running (no pid file)"; return }
  $j = Try-ReadJson $pidPath; if (-not $j) { CI-Info "devserver-status: pid file corrupt"; return }
  $devPid = [int](Get-Prop $j "pid" 0); $port = [int](Get-Prop $j "port" 8080); $lp = Get-ListeningPid $port
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
