# UNIVERSAL CI Runtime (Windows / PowerShell 5.1+)
# Version: v4.8.3 (fully modularized)
# Template runtime: project-agnostic, deterministic, non-interactive.
# NOTE: Treat `.ci/bin/*` as immutable runtime. Update only via patch/zip.

# ---- UI Layout: Visual Regression + UI-Lint (best effort) ----
# Commands:
#   ui-check     : run screenshots + (optional) lint + ImageMagick diff vs baseline
#   ui-baseline  : (re)create baseline screenshots
#   ui-roadmap   : render latest findings as checklist markdown (logs/ui/roadmap.ui.md)
#
# Files:
#   tools/ui/ui-check.mjs           (Playwright runner; writes logs/ui/screens + logs/ui/ui.lint.json)
#   tools/ui/ui-check.config.json   (viewports/thresholds/selectors)
#   ui/baseline/*.png               (versioned baselines)

if (-not (Get-Variable -Name CiCommands -Scope Script -ErrorAction SilentlyContinue)) { $script:CiCommands = @{} }

function Ui-Info([string]$Msg) {
  try {
    if (Get-Command -Name CI-Info -ErrorAction SilentlyContinue) { CI-Info $Msg } else { Write-Host ("[UI] " + $Msg) }
  } catch { Write-Host ("[UI] " + $Msg) }
}

function Ui-EnsureDir([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

function Ui-ToRelPath([string]$Path) {
  try {
    if (Get-Command -Name To-RelPath -ErrorAction SilentlyContinue) { return (To-RelPath $Path) }
  } catch { $null = $_ }
  return $Path
}

function Ui-GetFreePort {
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
  $l.Start()
  $p = ($l.LocalEndpoint).Port
  $l.Stop()
  return [int]$p
}

function Ui-GetPythonExe {
  $py = (Get-Command -Name python -ErrorAction SilentlyContinue)
  if ($py) { return "python" }
  $py = (Get-Command -Name py -ErrorAction SilentlyContinue)
  if ($py) { return "py" }
  return $null
}

function Ui-StartServer([string]$Root, [int]$Port) {
  $py = Ui-GetPythonExe
  if (-not $py) { throw "python/py not found (needed to serve built web root). Install Python or wire into existing #ci pyserver-start." }

  # Prefer Python 3.7+ --directory
  $args = @("-m","http.server",[string]$Port,"--bind","127.0.0.1","--directory",$Root)
  Ui-Info ("start server: " + $py + " " + ($args -join " "))
  $startArgs = @{ FilePath=$py; ArgumentList=$args; PassThru=$true }
  if ($IsWindows) { $startArgs["WindowStyle"] = "Hidden" }
  $p = Start-Process @startArgs

  # Wait until ready (max ~5s)
  $url = "http://127.0.0.1:$Port/"
  $ok = $false
  for ($i=0; $i -lt 25; $i++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri $url
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { $ok = $true; break }
    } catch { Start-Sleep -Milliseconds 200 }
  }
  if (-not $ok) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch { $null = $_ }
    throw "server did not become ready at $url"
  }
  return @{ proc = $p; url = $url }
}

function Ui-StopServer($Server) {
  if ($null -eq $Server) { return }
  try {
    $p = $Server.proc
    if ($p -and -not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
  } catch { $null = $_ }
}

function Ui-DetectServeRoot {
  $candidates = @(
    "ui-web\build\dist\js\productionExecutable",
    "ui-web\build\kotlin-webpack\js\productionExecutable",
    "ui-web\build\processedResources\js\main",
    "web\build\dist\js\productionExecutable",
    "web\build\kotlin-webpack\js\productionExecutable",
    "web\build\processedResources\js\main"
  )
  foreach ($rel in $candidates) {
    $p = Join-Path $RepoRoot $rel
    $idx = Join-Path $p "index.html"
    if (Test-Path -LiteralPath $idx) { return $p }
  }
  return $null
}

function Ui-TryWebBuild {
  $candidates = @()
  if ($IsWindows) { $candidates += (Join-Path $RepoRoot "gradlew.bat") }
  $candidates += (Join-Path $RepoRoot "gradlew")
  $gradlew = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (-not $gradlew) {
    Ui-Info "gradle wrapper not found; skipping build step (assuming assets already built)."
    return
  }
  $tasks = @(":ui-web:jsBrowserProductionWebpack",":ui-web:jsBrowserDevelopmentWebpack") # Removed :ui-web:browserProductionWebpack as it was not found
  foreach ($t in $tasks) {
    Ui-Info ("build: " + $t)
    & $gradlew $t "--console=plain"
    if ($LASTEXITCODE -eq 0) { return }
  }
  throw "web build failed (tried: $($tasks -join ', '))"
}


function Ui-ReadConfig([string]$ConfigPath) {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "missing config: $ConfigPath" }
  return (Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json)
}

function Ui-RunNode([string]$NodeScript, [string[]]$ArgsList) {
  $node = (Get-Command -Name node -ErrorAction SilentlyContinue)
  if (-not $node) { throw "node not found (required for Playwright runner)." }
  & node $NodeScript @ArgsList
  return $LASTEXITCODE
}

function Ui-CompareImages([string]$Baseline, [string]$Current, [string]$DiffOut) {
  $magick = (Get-Command -Name magick -ErrorAction SilentlyContinue)
  if (-not $magick) { throw "ImageMagick 'magick' not found in PATH." }

  Ui-EnsureDir (Split-Path -Parent $DiffOut)
  # magick compare writes metric to stderr; exit code is not reliable for our purposes.
  $out = & magick compare -metric AE $Baseline $Current $DiffOut 2>&1
  $ae = $null
  if ($out -match '^\s*(\d+)\s*$') { $ae = [int]$Matches[1] }
  elseif ($out -match '(\d+)') { $ae = [int]$Matches[1] }
  else { $ae = $null }
  return $ae
}

function Invoke-UiInternal([string]$Mode) {
  $cfgPath = Join-Path $RepoRoot "tools\ui\ui-check.config.json"
  $cfg = Ui-ReadConfig $cfgPath

  $logsUi = Join-Path $LogsRoot "ui"
  $screens = Join-Path $logsUi "screens"
  $diffs = Join-Path $logsUi "diff"
  Ui-EnsureDir $logsUi
  Ui-EnsureDir $screens
  Ui-EnsureDir $diffs

  if (-not $cfg.no_build) { Ui-TryWebBuild }

  $root = Ui-DetectServeRoot
  if (-not $root) { throw "serve root not found (missing index.html). Build first or adjust candidates in Ui-DetectServeRoot." }

  $webpackDir = Join-Path $RepoRoot "ui-web\build\webpack"
  if (Test-Path -LiteralPath $webpackDir) {
    Get-ChildItem -LiteralPath $webpackDir -Filter "*.js*" | ForEach-Object {
      $dest = Join-Path $root $_.Name
      Copy-Item -Force -LiteralPath $_.FullName -Destination $dest
    }
  }

  $port = Ui-GetFreePort
  $srv = $null
  try {
    $srv = Ui-StartServer $root $port
    $url = [string]$srv.url

    $nodeScript = Join-Path $RepoRoot "tools\ui\ui-check.mjs"
    if (-not (Test-Path -LiteralPath $nodeScript)) { throw "missing node runner: $nodeScript" }

    $lintOut = Join-Path $logsUi "ui.lint.json"
    $exit = Ui-RunNode $nodeScript @("--url",$url,"--out",$logsUi,"--mode",$Mode)

    # Visual diffs (per viewport)
    $baselineDir = Join-Path $RepoRoot "ui\baseline"
    $aeThreshold = 0
    try { $aeThreshold = [int]$cfg.visual.ae_threshold } catch { $aeThreshold = 0 }

    $visual = [ordered]@{ ts = (Get-Date).ToString("s"); mode=$Mode; url=$url; served_root=(Ui-ToRelPath $root); ae_threshold=$aeThreshold; viewports=@(); baseline_missing=@(); failures=@() }
    foreach ($vp in $cfg.viewports) {
      $vpName = [string]$vp.name
      $shot = Join-Path $screens ($vpName + ".png")
      $base = Join-Path $baselineDir ($vpName + ".png")
      $diff = Join-Path $diffs ($vpName + ".png")
      $vpRec = [ordered]@{ name=$vpName; screenshot=(Ui-ToRelPath $shot); baseline=(Ui-ToRelPath $base); ae=$null; diff=(Ui-ToRelPath $diff) }
      if (-not (Test-Path -LiteralPath $shot)) {
        $visual.failures += ("missing screenshot: " + $vpName)
      } elseif ($Mode -eq "baseline") {
        Ui-EnsureDir $baselineDir
        Copy-Item -Force -LiteralPath $shot -Destination $base
        $vpRec.ae = 0
      } else {
        if (-not (Test-Path -LiteralPath $base)) {
          $visual.baseline_missing += $vpName
        } else {
          $ae = Ui-CompareImages $base $shot $diff
          $vpRec.ae = $ae
          if ($aeThreshold -gt 0 -and $ae -ne $null -and $ae -gt $aeThreshold) {
            $visual.failures += ("visual diff AE>${aeThreshold}: " + $vpName + " (AE=" + $ae + ")")
          }
        }
      }
      $visual.viewports += $vpRec
    }

    $digestPath = Join-Path $logsUi "ui.visual.digest.json"
    $visual | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 -NoNewline -LiteralPath $digestPath

    if ($Mode -eq "check") {
      if ($visual.baseline_missing.Count -gt 0) { Ui-Info ("baseline missing: " + ($visual.baseline_missing -join ", ") + " (run: #ci ui-baseline)"); return 2 }
      if ($visual.failures.Count -gt 0) { Ui-Info ("visual failures: " + ($visual.failures -join " | ")); return 2 }
      if ($exit -ne 0) { return $exit }
    }
    return 0
  } finally {
    Ui-StopServer $srv
  }
}

function Invoke-UiRoadmap {
  $logsUi = Join-Path $LogsRoot "ui"
  $lintPath = Join-Path $logsUi "ui.lint.json"
  $visPath  = Join-Path $logsUi "ui.visual.digest.json"
  if (-not (Test-Path -LiteralPath $lintPath)) { throw "missing $lintPath (run: #ci ui-check)" }

  $lint = Get-Content -Raw -LiteralPath $lintPath | ConvertFrom-Json
  $vis = $null
  if (Test-Path -LiteralPath $visPath) { $vis = Get-Content -Raw -LiteralPath $visPath | ConvertFrom-Json }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# UI Roadmap (auto, ankreuzbar)")
  $lines.Add("")
  $lines.Add("Quelle: logs/ui/ui.lint.json" + ($(if($vis){ " + logs/ui/ui.visual.digest.json" } else { "" })))
  $lines.Add("")

  foreach ($vp in $lint.viewports) {
    $vpName = [string]$vp.name
    $lines.Add("## " + $vpName)
    $lines.Add("")
    $findings = @($vp.findings | Sort-Object severity, code)
    foreach ($f in $findings) {
      $title = [string]$f.title
      $sev = [string]$f.severity
      $code = [string]$f.code
      $e = [string]$f.evidence
      $lines.Add(('- [ ] [{0}] {1} (`{2}`)' -f $sev, $title, $code))
      if ($e) { $lines.Add("  - Evidence: " + $e) }
      if ($f.acceptance) {
        foreach ($a in @($f.acceptance)) { $lines.Add("  - [ ] " + [string]$a) }
      }
    }
    if ($vis) {
      $vpVis = $vis.viewports | Where-Object { $_.name -eq $vpName } | Select-Object -First 1
      if ($vpVis) {
        $lines.Add("")
        $lines.Add("- [ ] Visual Regression: AE <= " + [string]$vis.ae_threshold + " (aktuell: " + [string]$vpVis.ae + ")")
      }
    }
    $lines.Add("")
  }

  $outPath = Join-Path $logsUi "roadmap.ui.md"
  $lines -join "`r`n" | Set-Content -Encoding UTF8 -LiteralPath $outPath
  Ui-Info ("wrote: " + (Ui-ToRelPath $outPath))
}

# Register commands if not already present (do not override project-specific ones).
if (-not $script:CiCommands.ContainsKey("ui-check") -or -not $script:CiCommands["ui-check"]) {
$script:CiCommands["ui-check"] = { $ec = Invoke-UiInternal "check"; if ($ec -is [array]) { $ec = $ec[-1] }; $ec = [int]$ec; if ($ec -ne 0) { throw ("ui-check failed (exit=" + $ec + ")") } }
}
if (-not $script:CiCommands.ContainsKey("ui-baseline") -or -not $script:CiCommands["ui-baseline"]) {
$script:CiCommands["ui-baseline"] = { $ec = Invoke-UiInternal "baseline"; if ($ec -is [array]) { $ec = $ec[-1] }; $ec = [int]$ec; if ($ec -ne 0) { throw ("ui-baseline failed (exit=" + $ec + ")") } }
}
if (-not $script:CiCommands.ContainsKey("ui-roadmap") -or -not $script:CiCommands["ui-roadmap"]) {
  $script:CiCommands["ui-roadmap"] = { Invoke-UiRoadmap }
}
