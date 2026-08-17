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
  CI-Info "supertest: ui runner"
  $ts = ((TsId) + "-pid" + [string]$PID)
  $uiLog = Join-Path $LogsRoot ("terminal\supertest-ui-" + $ts + ".log")
  $started = $false
  $supertestEnv = @{ SUPERTEST_RESTART_DEVSERVER = "0" }
  if (-not [Environment]::GetEnvironmentVariable("SUPERTEST_RUN_ID", "Process")) {
    $supertestEnv["SUPERTEST_RUN_ID"] = ("ci-" + $ts)
  }
  $supertestTimeoutSec = 21600
  $runnerArgs = @($script:CommandArgs)
  if (-not $runnerArgs -or $runnerArgs.Count -eq 0) {
    $runnerArgs = @("--tier=pr-smoke")
  }
  $runnerArgLine = (($runnerArgs | ForEach-Object { Quote-IfNeeded ([string]$_) }) -join " ")
  $supertestCmd = ("node tests/ui/run-supertest.js " + $runnerArgLine).Trim()
  $listOnly = @($runnerArgs | Where-Object { ([string]$_) -eq "--list" -or ([string]$_) -like "--list=*" }).Count -gt 0
  $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
  if ((-not $listOnly) -and (-not (Test-Path $pidPath))) {
    Cmd-DevserverStart
    $started = $true
  }
  try {
    CI-Info ("supertest: " + $supertestCmd + " | log=" + $uiLog)
    $res = Run-Cmd $supertestCmd $uiLog $supertestEnv $RepoRoot $supertestTimeoutSec
    if ($res.exit -ne 0) { throw ("supertest: ui suite failed. See " + $uiLog) }
  } finally {
    if ($started) { try { Cmd-DevserverStop } catch { $null = $_ } }
  }
  CI-Info ("supertest: ok (ui log=" + $uiLog + ")")
}

function Cmd-TestLanePlan([string]$laneId) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $runnerArgs = @($script:CommandArgs)
  if (-not ($runnerArgs -contains "--plan-only")) {
    $runnerArgs = @("--plan-only") + $runnerArgs
  }
  $argLine = (($runnerArgs | ForEach-Object { Quote-IfNeeded ([string]$_) }) -join " ")
  $ts = TsId
  $log = Join-Path $LogsRoot ("terminal\" + $laneId + "-" + $ts + ".log")
  $cmd = ("node tools/quality/tst_493_lane_plan.mjs --lane=" + $laneId + " " + $argLine).Trim()
  CI-Info ($laneId + ": " + $cmd + " | log=" + $log)
  $res = Run-Cmd $cmd $log $null $RepoRoot 600
  if ($res.exit -ne 0) { throw ($laneId + ": plan failed. See " + $log) }
  CI-Info ($laneId + ": plan ok")
}

function Cmd-ComprehensiveViewportTest() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $runnerArgs = @($script:CommandArgs)
  $planOnly = @($runnerArgs | Where-Object { ([string]$_) -eq "--plan-only" }).Count -gt 0
  $argLine = (($runnerArgs | ForEach-Object { Quote-IfNeeded ([string]$_) }) -join " ")
  $ts = ((TsId) + "-pid" + [string]$PID)
  $log = Join-Path $LogsRoot ("terminal\comprehensive-viewport-test-" + $ts + ".log")
  $cmd = ("node tools/quality/tst_495_comprehensive_viewport_device_test.js " + $argLine).Trim()
  $started = $false
  $pidPath = Join-Path $CiRoot "run\devserver.pid.json"
  if ((-not $planOnly) -and (-not (Test-Path $pidPath))) {
    Cmd-DevserverStart
    $started = $true
  }
  try {
    CI-Info ("comprehensive-viewport-test: " + $cmd + " | log=" + $log)
    $res = Run-Cmd $cmd $log $null $RepoRoot 43200
    if ($res.exit -ne 0) { throw ("comprehensive-viewport-test failed. See " + $log) }
  } finally {
    if ($started) { try { Cmd-DevserverStop } catch { $null = $_ } }
  }
  CI-Info ("comprehensive-viewport-test: ok (log=" + $log + ")")
}

function Test-VpTestLocalUrl([string]$url) {
  if (-not $url) { return $false }
  try {
    $uri = [Uri]$url
    $uriHost = [string]$uri.Host
    if (-not $uriHost) { return $false }
    $normalized = $uriHost.Trim().ToLowerInvariant()
    return ($normalized -eq "localhost" -or $normalized -eq "127.0.0.1" -or $normalized -eq "::1" -or $normalized -eq "0.0.0.0")
  } catch {
    return $false
  }
}

function Get-VpTestCaptureMode() {
  $value = [string]([Environment]::GetEnvironmentVariable("VP_TEST_CAPTURE_MODE", "Process"))
  if (-not $value) { return "auto" }
  $normalized = $value.Trim().ToLowerInvariant()
  if ($normalized -eq "lookup-only") { return "lookup-only" }
  return "auto"
}

function Get-VpTestCaptureUrl([string]$uploadBaseUrl) {
  $override = [string]([Environment]::GetEnvironmentVariable("VP_TEST_CAPTURE_URL", "Process"))
  if ($override) { return $override.Trim() }
  if (-not $uploadBaseUrl) { return $null }
  return ($uploadBaseUrl.TrimEnd("/") + "/?autodebug=1")
}

function Test-VpTestBabachessBcTestTarget([string]$url) {
  if (-not $url) { return $false }
  try {
    $uri = [Uri]$url
    $uriHost = [string]$uri.Host
    $path = [string]$uri.AbsolutePath
    if (-not $uriHost) { return $false }
    $normalizedHost = $uriHost.Trim().ToLowerInvariant()
    if (@("babachess.com", "www.babachess.com") -notcontains $normalizedHost) { return $false }
    if (-not $path) { return $false }
    return ($path.Trim().ToLowerInvariant() -match '^/bc-test(/|$)')
  } catch {
    return $false
  }
}

function Test-VpTestRequireLocalhostCompare([string]$uploadBaseUrl, [bool]$isLocalTarget) {
  $raw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_REQUIRE_LOCALHOST_COMPARE", "Process"))
  if ($raw) {
    $normalized = $raw.Trim().ToLowerInvariant()
    if (@("0", "false", "no", "off") -contains $normalized) { return $false }
    return $true
  }
  if ($isLocalTarget) { return $false }
  return (Test-VpTestBabachessBcTestTarget $uploadBaseUrl)
}

function Test-VpTestCompareLocalhostEnabled([string]$uploadBaseUrl, [bool]$isLocalTarget) {
  $raw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_COMPARE_LOCALHOST", "Process"))
  if ($raw) {
    $normalized = $raw.Trim().ToLowerInvariant()
    if (@("0", "false", "no", "off") -contains $normalized) { return $false }
    return $true
  }
  if ($isLocalTarget) { return $false }
  return (Test-VpTestBabachessBcTestTarget $uploadBaseUrl)
}

function Get-VpTestCompareLocalhostUrl() {
  $override = [string]([Environment]::GetEnvironmentVariable("VP_TEST_COMPARE_LOCAL_URL", "Process"))
  if ($override) { return $override.Trim() }
  return "http://localhost:8080/?autodebug=1"
}

function Test-VpTestParallelCompareEnabled() {
  $raw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_PARALLEL_COMPARE", "Process"))
  if (-not $raw) { return $false }
  $normalized = $raw.Trim().ToLowerInvariant()
  return ($normalized -ne "" -and @("0", "false", "no", "off") -notcontains $normalized)
}

function Get-VpTestToolPath([string]$envName, [string]$defaultRelativePath) {
  $override = [string]([Environment]::GetEnvironmentVariable($envName, "Process"))
  if ($override) {
    $trimmed = $override.Trim()
    if ([System.IO.Path]::IsPathRooted($trimmed)) { return $trimmed }
    return (Join-Path $RepoRoot $trimmed)
  }
  return (Join-Path $RepoRoot $defaultRelativePath)
}

function Get-VpTestCaptureTimeoutMs() {
  $captureTimeoutMs = 45000
  $captureTimeoutRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_CAPTURE_TIMEOUT_MS", "Process"))
  if ($captureTimeoutRaw) {
    try { $captureTimeoutMs = [Math]::Max(10000, [int]$captureTimeoutRaw) } catch { $captureTimeoutMs = 45000 }
  }
  return $captureTimeoutMs
}

function New-VpTestLocalhostCaptureEnv($report) {
  $localhostCaptureEnv = @{}
  $compareViewportProfile = Get-VpTestCaptureViewportProfile (Get-Prop $report.bundleLookup "capture" $null)
  $compareViewportWidth = Get-VpTestOptionalIntValue $compareViewportProfile "width"
  $compareViewportHeight = Get-VpTestOptionalIntValue $compareViewportProfile "height"
  $existingViewportWidthRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_VIEWPORT_WIDTH", "Process"))
  $existingViewportHeightRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_VIEWPORT_HEIGHT", "Process"))
  if (-not $existingViewportWidthRaw -and $null -ne $compareViewportWidth) {
    $localhostCaptureEnv["VP_TEST_VIEWPORT_WIDTH"] = [string]$compareViewportWidth
  }
  if (-not $existingViewportHeightRaw -and $null -ne $compareViewportHeight) {
    $localhostCaptureEnv["VP_TEST_VIEWPORT_HEIGHT"] = [string]$compareViewportHeight
  }
  $localhostPreCaptureSetupRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_COMPARE_LOCAL_PRECAPTURE_SETUP_JSON", "Process"))
  if (-not $localhostPreCaptureSetupRaw) {
    $localhostPreCaptureSetupRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_PRECAPTURE_SETUP_JSON", "Process"))
  }
  if (-not $localhostPreCaptureSetupRaw) {
    $defaultComparePreCaptureSetup = Get-VpTestDefaultCompareLocalPreCaptureSetup `
      ([string](Get-Prop $report.bundleLookup "mode" "")) `
      (Get-Prop $report.bundleLookup "selectedCandidate" $null) `
      (Get-Prop $report.bundleLookup "capture" $null)
    if ($defaultComparePreCaptureSetup) {
      $localhostPreCaptureSetupRaw = ($defaultComparePreCaptureSetup | ConvertTo-Json -Depth 8 -Compress)
    }
  }
  if ($localhostPreCaptureSetupRaw) {
    $localhostCaptureEnv["VP_TEST_PRECAPTURE_SETUP_JSON"] = $localhostPreCaptureSetupRaw
  }
  return $localhostCaptureEnv
}

function Start-VpTestLocalhostCompareJob(
  [string]$captureCmd,
  [string]$captureLog,
  [hashtable]$captureEnv,
  [string]$capturePath,
  [string]$analyzeToolPath,
  [string]$analysisReportPath,
  [string]$analysisSummaryPath,
  [string]$analyzeLog,
  [int]$captureTimeoutMs
) {
  return Start-Job -Name ("vp-test-localhost-compare-" + (TsId)) -ScriptBlock {
    param(
      [string]$repoRoot,
      [string]$ciRoot,
      [string]$logsRoot,
      [string]$captureCmd,
      [string]$captureLog,
      [hashtable]$captureEnv,
      [string]$capturePath,
      [string]$analyzeToolPath,
      [string]$analysisReportPath,
      [string]$analysisSummaryPath,
      [string]$analyzeLog,
      [int]$captureTimeoutMs
    )
    $script:RepoRoot = $repoRoot
    $script:CiRoot = $ciRoot
    $script:LogsRoot = $logsRoot
    . (Join-Path $repoRoot ".ci\bin\modules\core-utils.ps1")

    $result = [ordered]@{
      stage = "capture"
      startedAt = NowIso
      finishedAt = $null
      captureLog = $captureLog
      analyzeLog = $analyzeLog
      exit = 1
      error = $null
    }
    try {
      $captureTimeoutSec = [Math]::Max(15, [int][Math]::Ceiling($captureTimeoutMs / 1000) + 10)
      $capture = Run-Cmd $captureCmd $captureLog $captureEnv $repoRoot $captureTimeoutSec
      if ($capture.exit -ne 0) { throw ("localhost compare capture failed. See " + $captureLog) }
      $capturePayload = Try-ReadJson $capturePath
      if ($null -eq $capturePayload) { throw "localhost compare capture report is unreadable." }
      $localExportPath = [string](Get-Prop $capturePayload "localExportPath" "")
      if (-not $localExportPath) { throw "localhost compare capture did not write a local export payload." }
      $analysisInputPath = $localExportPath
      if (-not [System.IO.Path]::IsPathRooted($analysisInputPath)) {
        $analysisInputPath = Join-Path $repoRoot $analysisInputPath
      }
      $analyzeCmd = @(
        "node",
        (Quote-IfNeeded $analyzeToolPath),
        "--input", (Quote-IfNeeded $analysisInputPath),
        "--report", (Quote-IfNeeded $analysisReportPath),
        "--summary", (Quote-IfNeeded $analysisSummaryPath)
      ) -join " "
      $result.stage = "analyze"
      $analyze = Run-Cmd $analyzeCmd $analyzeLog $null $repoRoot
      if ($analyze.exit -ne 0) { throw ("localhost compare analysis failed. See " + $analyzeLog) }
      $result.stage = "complete"
      $result.exit = 0
    } catch {
      $result.error = [string]$_.Exception.Message
    }
    $result.finishedAt = NowIso
    return $result
  } -ArgumentList $RepoRoot, $CiRoot, $LogsRoot, $captureCmd, $captureLog, $captureEnv, $capturePath, $analyzeToolPath, $analysisReportPath, $analysisSummaryPath, $analyzeLog, $captureTimeoutMs
}

function Receive-VpTestLocalhostCompareJob($job) {
  if ($null -eq $job) {
    return [ordered]@{ exit = 1; error = "localhost compare job missing." }
  }
  Wait-Job -Job $job | Out-Null
  $output = @(Receive-Job -Job $job -ErrorAction SilentlyContinue)
  Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
  $result = $null
  foreach ($entry in $output) {
    if ($entry -is [System.Collections.IDictionary] -or ($entry -and $entry.PSObject.Properties["exit"])) {
      $result = $entry
    }
  }
  if ($null -eq $result) {
    return [ordered]@{ exit = 1; error = "localhost compare job returned no result." }
  }
  return $result
}

function Get-VpTestCaptureViewportDimension([string]$name, [int]$defaultValue) {
  $raw = [string]([Environment]::GetEnvironmentVariable($name, "Process"))
  if (-not $raw) { return $defaultValue }
  try {
    $value = [int]$raw
    if ($value -gt 0) { return $value }
  } catch {
    $null = $_
  }
  return $defaultValue
}

function Test-VpTestExpectationEnabled([string]$name) {
  $raw = [string]([Environment]::GetEnvironmentVariable($name, "Process"))
  if (-not $raw) { return $false }
  $normalized = $raw.Trim().ToLowerInvariant()
  return ($normalized -ne "" -and @("0", "false", "no", "off") -notcontains $normalized)
}

function ConvertTo-VpTestNullableBool($value) {
  if ($null -eq $value) { return $null }
  $normalized = [string]$value
  if (-not $normalized) { return $null }
  $normalized = $normalized.Trim().ToLowerInvariant()
  if (-not $normalized) { return $null }
  if (@("1", "true", "yes", "on") -contains $normalized) { return $true }
  if (@("0", "false", "no", "off") -contains $normalized) { return $false }
  return $null
}

function Get-VpTestOptionalDoubleValue($source, [string]$name) {
  $raw = Get-Prop $source $name $null
  if ($null -eq $raw) { return $null }
  $text = [string]$raw
  if (-not $text) { return $null }
  $trimmed = $text.Trim()
  if (-not $trimmed) { return $null }
  try {
    return [double]$trimmed
  } catch {
    return $null
  }
}

function Get-VpTestOptionalIntValue($source, [string]$name) {
  $raw = Get-Prop $source $name $null
  if ($null -eq $raw) { return $null }
  $text = [string]$raw
  if (-not $text) { return $null }
  $trimmed = $text.Trim()
  if (-not $trimmed) { return $null }
  try {
    return [int][Math]::Round([double]$trimmed)
  } catch {
    return $null
  }
}

function Get-VpTestRoundedDouble($value, [int]$digits = 3) {
  if ($null -eq $value) { return $null }
  try {
    return [Math]::Round([double]$value, $digits)
  } catch {
    return $null
  }
}

function Get-VpTestLegacyExpectedLiveStatsQualities() {
  return @(
    "BRILLIANT",
    "GREAT",
    "BEST",
    "EXCELLENT",
    "GOOD",
    "BOOK",
    "INACCURACY",
    "MISTAKE",
    "MISS",
    "BLUNDER"
  )
}

function Get-VpTestLegacyDerivedLiveLabelFontSizePx($lineHeightPx) {
  if ($null -eq $lineHeightPx) { return $null }
  try {
    return [Math]::Round([Math]::Max(11.0, ([double]$lineHeightPx - 4.0)), 3)
  } catch {
    return $null
  }
}

function Get-VpTestLegacyAnalyzeSnapshot($debugJson) {
  if ($null -eq $debugJson) { return $null }
  $snapshot = Get-Prop $debugJson "analyzeRightRailSnapshot" $null
  if ($null -eq $snapshot) {
    $snapshot = Get-Prop (Get-Prop $debugJson "capture" $null) "analyzeRightRailSnapshot" $null
  }
  return $snapshot
}

function Get-VpTestLegacyRailTypographyMetrics($debugJson) {
  $snapshot = Get-VpTestLegacyAnalyzeSnapshot $debugJson
  if ($null -eq $snapshot) { return $null }

  $liveLabelLineHeightPx = Get-VpTestOptionalDoubleValue $snapshot "liveStatsMaxLabelHeightPx"
  if ($null -eq $liveLabelLineHeightPx) { return $null }

  return [ordered]@{
    glickoValueFontSizePx = $null
    clockTitleFontSizePx = $null
    clockDigitsFontSizePx = $null
    explorerSourceLabelFontSizePx = $null
    explorerMoveFontSizePx = $null
    explorerEloFontSizePx = $null
    movesTitleFontSizePx = $null
    liveLabelFontSizePx = Get-VpTestLegacyDerivedLiveLabelFontSizePx $liveLabelLineHeightPx
    liveLabelLineHeightPx = Get-VpTestRoundedDouble $liveLabelLineHeightPx
  }
}

function Get-VpTestLegacyLiveStatsMetrics($debugJson) {
  $snapshot = Get-VpTestLegacyAnalyzeSnapshot $debugJson
  if ($null -eq $snapshot) { return $null }

  $expectedQualities = @(Get-VpTestLegacyExpectedLiveStatsQualities)
  $expectedCategoryCount = @($expectedQualities).Count
  $visibleCategoryCountRaw = Get-VpTestOptionalIntValue $snapshot "liveStatsRowCount"
  if ($null -eq $visibleCategoryCountRaw) { return $null }
  $visibleCategoryCount = [Math]::Max(0, [Math]::Min($expectedCategoryCount, [int]$visibleCategoryCountRaw))
  $uniqueCategoryCount = $visibleCategoryCount
  $panelHeightPx = Get-VpTestOptionalDoubleValue (Get-Prop $snapshot "liveStatsPanelRect" $null) "height"
  if ($null -eq $panelHeightPx) {
    $panelHeightPx = Get-VpTestOptionalDoubleValue $snapshot "liveStatsRowHeightTotalPx"
  }
  $bottomSlackPx = Get-VpTestOptionalDoubleValue $snapshot "liveToRailBottomGapPx"
  $rowHeightTotalPx = Get-VpTestOptionalDoubleValue $snapshot "liveStatsRowHeightTotalPx"
  $averageRowHeightPx = $null
  if (($null -ne $rowHeightTotalPx) -and $visibleCategoryCount -gt 0) {
    $averageRowHeightPx = $rowHeightTotalPx / $visibleCategoryCount
  }
  $rowBudgetPx = $null
  if ($null -ne $panelHeightPx) {
    $rowBudgetPx = $panelHeightPx / $expectedCategoryCount
  } elseif ($null -ne $averageRowHeightPx) {
    $rowBudgetPx = $averageRowHeightPx
  }
  $maxAllowedLineHeightPx = $null
  if ($null -ne $rowBudgetPx) {
    $maxAllowedLineHeightPx = $rowBudgetPx + 0.5
  }
  $maxLabelLineHeightPx = Get-VpTestOptionalDoubleValue $snapshot "liveStatsMaxLabelHeightPx"
  $rowOverlapPx = $null
  if (($null -ne $maxLabelLineHeightPx) -and ($null -ne $averageRowHeightPx)) {
    $rowOverlapPx = [Math]::Max(0.0, ($maxLabelLineHeightPx - $averageRowHeightPx))
  }
  $maxFontHeightShareOfRow = $null
  if (($null -ne $maxLabelLineHeightPx) -and ($null -ne $averageRowHeightPx) -and $averageRowHeightPx -gt 0) {
    $maxFontHeightShareOfRow = $maxLabelLineHeightPx / $averageRowHeightPx
  }
  $headerToBodyGapPx = Get-VpTestOptionalDoubleValue $snapshot "liveStatsTitleToBodyGapPx"
  $bodyUsageShare = Get-VpTestOptionalDoubleValue $snapshot "liveStatsRowUsageShareOfBody"
  $derivedFontSizePx = Get-VpTestLegacyDerivedLiveLabelFontSizePx $maxLabelLineHeightPx
  $iconSizePx = $null
  if ($null -ne $averageRowHeightPx) {
    $iconSizePx = [Math]::Round([Math]::Min(16.0, $averageRowHeightPx), 3)
  }

  $missingQualities = @()
  if ($visibleCategoryCount -lt $expectedCategoryCount) {
    $missingQualities = @($expectedQualities[$visibleCategoryCount..($expectedCategoryCount - 1)])
  }

  $rows = @()
  if ($visibleCategoryCount -gt 0) {
    $visibleQualities = @($expectedQualities[0..($visibleCategoryCount - 1)])
    foreach ($quality in $visibleQualities) {
      $rows += [ordered]@{
        quality = $quality
        rowHeightPx = Get-VpTestRoundedDouble $averageRowHeightPx
        labelFontSizePx = $derivedFontSizePx
        labelLineHeightPx = Get-VpTestRoundedDouble $maxLabelLineHeightPx
        counterFontSizePx = $derivedFontSizePx
        counterLineHeightPx = Get-VpTestRoundedDouble $maxLabelLineHeightPx
        iconSizePx = $iconSizePx
        fontHeightShareOfRow = Get-VpTestRoundedDouble $maxFontHeightShareOfRow 4
        textOverlapPx = Get-VpTestRoundedDouble $rowOverlapPx
        fullyVisible = $true
      }
    }
  }

  return [ordered]@{
    expectedCategoryCount = $expectedCategoryCount
    visibleCategoryCount = $visibleCategoryCount
    uniqueCategoryCount = $uniqueCategoryCount
    missingQualities = @($missingQualities)
    hasAllExpectedQualities = (@($missingQualities).Count -eq 0)
    panelHeightPx = Get-VpTestRoundedDouble $panelHeightPx
    bottomSlackPx = Get-VpTestRoundedDouble $bottomSlackPx
    rowBudgetPx = Get-VpTestRoundedDouble $rowBudgetPx
    maxAllowedLineHeightPx = Get-VpTestRoundedDouble $maxAllowedLineHeightPx
    maxTextOverlapPx = Get-VpTestRoundedDouble $rowOverlapPx
    rowOverlapPx = Get-VpTestRoundedDouble $rowOverlapPx
    maxLabelLineHeightPx = Get-VpTestRoundedDouble $maxLabelLineHeightPx
    maxFontHeightShareOfRow = Get-VpTestRoundedDouble $maxFontHeightShareOfRow 4
    headerToBodyGapPx = Get-VpTestRoundedDouble $headerToBodyGapPx
    bodyUsageShare = Get-VpTestRoundedDouble $bodyUsageShare 4
    rows = @($rows)
  }
}

function Get-VpTestLegacyBottomSeamMetrics($debugJson) {
  $snapshot = Get-VpTestLegacyAnalyzeSnapshot $debugJson
  if ($null -eq $snapshot) { return $null }

  $moveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $snapshot "moveListGridToLiveHeaderGapPx"
  $moveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $snapshot "moveListLastVisibleRowToLiveHeaderGapPx"
  $moveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestOptionalDoubleValue $snapshot "moveListLastVisibleRowToLiveWrapperGapPx"
  $moveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $snapshot "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
  $moveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $snapshot "moveListLastVisibleRowOverflowBeyondScrollPx"
  $moveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $snapshot "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
  $movesToLiveGapPx = Get-VpTestOptionalDoubleValue $snapshot "movesToLiveGapPx"
  $moveListBodyBottomSlackPx = Get-VpTestOptionalDoubleValue $snapshot "moveListBodyBottomSlackPx"

  $moveListScrollRect = Get-Prop $snapshot "moveListScrollRect" $null
  $movesWrapperRect = Get-Prop $snapshot "movesWrapperRect" $null
  $liveStatsWrapperRect = Get-Prop $snapshot "liveStatsWrapperRect" $null

  $moveListScrollBottom = Get-VpTestOptionalDoubleValue $moveListScrollRect "bottom"
  $movesWrapperBottom = Get-VpTestOptionalDoubleValue $movesWrapperRect "bottom"
  $liveStatsWrapperTop = Get-VpTestOptionalDoubleValue $liveStatsWrapperRect "top"

  if ($null -eq $movesToLiveGapPx) {
    if (($null -ne $liveStatsWrapperTop) -and ($null -ne $movesWrapperBottom)) {
      $movesToLiveGapPx = $liveStatsWrapperTop - $movesWrapperBottom
    }
  }

  $scrollToLiveWrapperGapPx = $null
  if (($null -ne $liveStatsWrapperTop) -and ($null -ne $moveListScrollBottom)) {
    $scrollToLiveWrapperGapPx = $liveStatsWrapperTop - $moveListScrollBottom
  }

  $moveListScrollToWrapperBottomGapPx = $null
  if (($null -ne $movesWrapperBottom) -and ($null -ne $moveListScrollBottom)) {
    $moveListScrollToWrapperBottomGapPx = $movesWrapperBottom - $moveListScrollBottom
  }

  $legacyLastVisibleRowToHeaderGapPx = $null
  if ($null -ne $scrollToLiveWrapperGapPx) {
    $legacyLastVisibleRowToHeaderGapPx = $scrollToLiveWrapperGapPx
    if ($null -ne $moveListBodyBottomSlackPx) {
      $legacyLastVisibleRowToHeaderGapPx += $moveListBodyBottomSlackPx
    }
  } elseif ($null -ne $movesToLiveGapPx) {
    $legacyLastVisibleRowToHeaderGapPx = $movesToLiveGapPx
    if ($null -ne $moveListBodyBottomSlackPx) {
      $legacyLastVisibleRowToHeaderGapPx += $moveListBodyBottomSlackPx
    }
  }

  if ($null -eq $moveListGridToLiveHeaderGapPx) {
    $moveListGridToLiveHeaderGapPx = $legacyLastVisibleRowToHeaderGapPx
  }
  if ($null -eq $moveListLastVisibleRowToLiveHeaderGapPx) {
    $moveListLastVisibleRowToLiveHeaderGapPx = $legacyLastVisibleRowToHeaderGapPx
  }
  if ($null -eq $moveListLastVisibleRowToLiveWrapperGapPx) {
    $moveListLastVisibleRowToLiveWrapperGapPx = $legacyLastVisibleRowToHeaderGapPx
  }
  if ($null -eq $moveListLastVisibleRowOverlapIntoLiveHeaderPx) {
    if ($null -ne $moveListLastVisibleRowToLiveHeaderGapPx) {
      $moveListLastVisibleRowOverlapIntoLiveHeaderPx = [Math]::Max(0.0, -1.0 * $moveListLastVisibleRowToLiveHeaderGapPx)
    } elseif ($null -ne $moveListBodyBottomSlackPx) {
      $moveListLastVisibleRowOverlapIntoLiveHeaderPx = [Math]::Max(0.0, -1.0 * $moveListBodyBottomSlackPx)
    }
  }
  if ($null -eq $moveListLastVisibleRowOverflowBeyondScrollPx -and $null -ne $moveListBodyBottomSlackPx) {
    $moveListLastVisibleRowOverflowBeyondScrollPx = [Math]::Max(0.0, -1.0 * $moveListBodyBottomSlackPx)
  }
  if ($null -eq $moveListLastVisibleRowOverflowBeyondMovesPanelPx) {
    if (($null -ne $moveListLastVisibleRowOverflowBeyondScrollPx) -and ($null -ne $moveListScrollToWrapperBottomGapPx)) {
      $moveListLastVisibleRowOverflowBeyondMovesPanelPx = [Math]::Max(0.0, $moveListLastVisibleRowOverflowBeyondScrollPx - [Math]::Max(0.0, $moveListScrollToWrapperBottomGapPx))
    } elseif ($null -ne $moveListLastVisibleRowOverflowBeyondScrollPx) {
      $moveListLastVisibleRowOverflowBeyondMovesPanelPx = $moveListLastVisibleRowOverflowBeyondScrollPx
    }
  }

  $hasMetrics =
    $null -ne $moveListGridToLiveHeaderGapPx -or
    $null -ne $moveListLastVisibleRowToLiveHeaderGapPx -or
    $null -ne $moveListLastVisibleRowToLiveWrapperGapPx -or
    $null -ne $moveListLastVisibleRowOverlapIntoLiveHeaderPx -or
    $null -ne $moveListLastVisibleRowOverflowBeyondScrollPx -or
    $null -ne $moveListLastVisibleRowOverflowBeyondMovesPanelPx -or
    $null -ne $movesToLiveGapPx
  if (-not $hasMetrics) { return $null }

  return [ordered]@{
    moveListGridToLiveHeaderGapPx = Get-VpTestRoundedDouble $moveListGridToLiveHeaderGapPx
    moveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestRoundedDouble $moveListLastVisibleRowToLiveHeaderGapPx
    moveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestRoundedDouble $moveListLastVisibleRowToLiveWrapperGapPx
    moveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestRoundedDouble $moveListLastVisibleRowOverlapIntoLiveHeaderPx
    moveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestRoundedDouble $moveListLastVisibleRowOverflowBeyondScrollPx
    moveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestRoundedDouble $moveListLastVisibleRowOverflowBeyondMovesPanelPx
    movesToLiveGapPx = Get-VpTestRoundedDouble $movesToLiveGapPx
  }
}

function Get-VpTestWarningSurfaceSignal($playMetrics, $movesPanelMetrics) {
  $warningSurfaceKey = [string](Get-Prop $playMetrics "warningSurfaceKey" "")
  if (-not $warningSurfaceKey) {
    $warningSurfaceKey = [string](Get-Prop $movesPanelMetrics "warningSurfaceKey" "")
  }
  $warningSurfaceState = [string](Get-Prop $playMetrics "warningSurfaceState" "")
  if (-not $warningSurfaceState) {
    $warningSurfaceState = [string](Get-Prop $movesPanelMetrics "warningSurfaceState" "")
  }
  $warningSurfaceMetricVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningSurfaceVisible" $null)
  $warningShellVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningShellVisible" $null)
  $warningCoachVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningCoachVisible" $null)
  $warningSlotVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningSlotVisible" $null)
  $warningTopslotVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningTopslotVisible" $null)
  $movesWarningBadgePresent = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "movesWarningBadgePresent" $null)
  $warningHasVisibleWarning = ConvertTo-VpTestNullableBool (Get-Prop $movesPanelMetrics "warningHasVisibleWarning" $null)
  $warningPresent = ConvertTo-VpTestNullableBool (Get-Prop $movesPanelMetrics "warningPresent" $null)
  $warningCoachPresent = ConvertTo-VpTestNullableBool (Get-Prop $movesPanelMetrics "warningCoachPresent" $null)
  $playTopslotKind = [string](Get-Prop $playMetrics "topSlotKind" "")
  $warningBadgeLevel = [string](Get-Prop $playMetrics "movesWarningBadgeLevel" "")
  if (-not $warningBadgeLevel) {
    $warningBadgeLevel = [string](Get-Prop $playMetrics "warningLevel" "")
  }
  $warningText = [string](Get-Prop $playMetrics "warningText" "")
  if (-not $warningText) {
    $warningText = [string](Get-Prop $playMetrics "movesWarningText" "")
  }
  $warningTopslotVariant = [string](Get-Prop $playMetrics "warningTopslotVariant" "")
  $warningTextLineCount = $null
  $warningShellHeightPx = $null
  $warningTextBlockHeightPx = $null
  try { $warningTextLineCount = [double](Get-Prop $playMetrics "warningTextLineCount" $null) } catch { $warningTextLineCount = $null }
  try { $warningShellHeightPx = [double](Get-Prop $playMetrics "warningShellHeightPx" $null) } catch { $warningShellHeightPx = $null }
  try { $warningTextBlockHeightPx = [double](Get-Prop $playMetrics "warningTextBlockHeightPx" $null) } catch { $warningTextBlockHeightPx = $null }

  if (-not $warningSurfaceKey) {
    if (
      $null -ne $warningShellVisible -or
      $null -ne $warningTopslotVisible -or
      $null -ne $warningHasVisibleWarning -or
      ($null -ne $warningPresent -and $null -ne $warningCoachPresent) -or
      ($playTopslotKind -and $playTopslotKind.Trim().ToLowerInvariant().StartsWith("warning"))
    ) {
      $warningSurfaceKey = "rightRailWarningTopslotVisible"
    } elseif ($null -ne $movesWarningBadgePresent) {
      $warningSurfaceKey = "movesWarningBadgePresent"
    }
  }

  $warningShellActive = $null
  if ($null -ne $warningShellVisible) {
    $warningShellActive = $warningShellVisible
  } elseif ($null -ne $warningSurfaceMetricVisible) {
    $warningShellActive = $warningSurfaceMetricVisible
  } elseif ($playTopslotKind -and $playTopslotKind.Trim().ToLowerInvariant().StartsWith("warning")) {
    $warningShellActive = $true
  } elseif ($null -ne $warningPresent -and $null -ne $warningCoachPresent) {
    $warningShellActive = ($warningPresent -and $warningCoachPresent)
  } elseif ($null -ne $warningHasVisibleWarning) {
    $warningShellActive = $warningHasVisibleWarning
  } elseif ($null -ne $warningTopslotVisible) {
    $warningShellActive = $warningTopslotVisible
  }

  $warningContentVisible = $null
  if ($null -ne $warningTopslotVisible) {
    $warningContentVisible = $warningTopslotVisible
  } elseif ($null -ne $warningHasVisibleWarning) {
    $warningContentVisible = $warningHasVisibleWarning
  } elseif ($null -ne $warningSlotVisible -and $null -ne $warningCoachVisible) {
    $warningContentVisible = ($warningSlotVisible -and $warningCoachVisible)
  } elseif ($null -ne $warningSlotVisible) {
    $warningContentVisible = $warningSlotVisible
  }

  $normalizedWarningSurfaceState = ""
  if ($warningSurfaceState) {
    $normalizedWarningSurfaceState = $warningSurfaceState.Trim().ToLowerInvariant()
  }

  if ($warningShellActive -eq $true -and $warningContentVisible -eq $true) {
    if ((-not $warningSurfaceState) -or (@("missing", "hidden", "absent", "inactive", "shell-visible", "shell-only") -contains $normalizedWarningSurfaceState)) {
      $warningSurfaceState = "visible"
      $normalizedWarningSurfaceState = "visible"
    }
  } elseif ($warningShellActive -eq $true) {
    if ((-not $warningSurfaceState) -or (@("missing", "hidden", "absent", "inactive") -contains $normalizedWarningSurfaceState)) {
      $warningSurfaceState = "shell-visible"
      $normalizedWarningSurfaceState = "shell-visible"
    }
  } elseif (-not $warningSurfaceState) {
    if ($null -ne $warningShellActive) {
      $warningSurfaceState = $(if ($warningShellActive) { "visible" } else { "missing" })
    } elseif ($null -ne $movesWarningBadgePresent) {
      $warningSurfaceState = $(if ($movesWarningBadgePresent) { "visible" } else { "missing" })
    }
    if ($warningSurfaceState) {
      $normalizedWarningSurfaceState = $warningSurfaceState.Trim().ToLowerInvariant()
    }
  }

  $warningSurfaceVisible = $null
  if ($warningSurfaceState) {
    $normalizedState = $warningSurfaceState.Trim().ToLowerInvariant()
    if (@("visible", "present", "active", "shown") -contains $normalizedState) {
      $warningSurfaceVisible = $true
    } elseif (@("shell-visible", "shell-only", "empty", "slot-only") -contains $normalizedState) {
      $warningSurfaceVisible = $true
    } elseif (@("missing", "hidden", "absent", "inactive") -contains $normalizedState) {
      $warningSurfaceVisible = $false
    }
  }
  if ($null -eq $warningSurfaceVisible) {
    if ($null -ne $warningShellActive) {
      $warningSurfaceVisible = $warningShellActive
    } elseif ($null -ne $movesWarningBadgePresent) {
      $warningSurfaceVisible = $movesWarningBadgePresent
    }
  }

  $normalizedWarningTopslotVariant = ""
  if ($warningTopslotVariant) {
    $normalizedWarningTopslotVariant = $warningTopslotVariant.Trim().ToLowerInvariant()
  }
  if (
    $warningShellActive -eq $true -and
    $warningContentVisible -ne $true -and
    ((-not $warningTopslotVariant) -or ($normalizedWarningTopslotVariant -eq "missing"))
  ) {
    $warningTopslotVariant = "shell-only"
  } elseif (
    ((-not $warningTopslotVariant) -or ($normalizedWarningTopslotVariant -eq "missing")) -and
    $warningContentVisible -eq $true -and
    $warningSurfaceVisible -eq $true -and
    $null -ne $warningTextLineCount
  ) {
    if ($warningTextLineCount -ge 2.7 -and $warningTextLineCount -le 3.25) {
      $warningTopslotVariant = "three-line"
    } else {
      $warningTopslotVariant = "topslot-visible"
    }
  }

  return [ordered]@{
    key = $warningSurfaceKey
    state = $warningSurfaceState
    visible = $warningSurfaceVisible
    shellVisible = $warningShellActive
    contentVisible = $warningContentVisible
    warningShellVisible = $warningShellVisible
    warningCoachVisible = $warningCoachVisible
    warningSlotVisible = $warningSlotVisible
    topslotVisible = $warningTopslotVisible
    topSlotKind = $playTopslotKind
    movesWarningBadgePresent = $movesWarningBadgePresent
    warningHasVisibleWarning = $warningHasVisibleWarning
    warningPresent = $warningPresent
    warningCoachPresent = $warningCoachPresent
    level = $warningBadgeLevel
    text = $warningText
    variant = $warningTopslotVariant
    textLineCount = $warningTextLineCount
    shellHeightPx = $warningShellHeightPx
    textBlockHeightPx = $warningTextBlockHeightPx
  }
}

function Test-VpTestPlayWarningTopslotExpected($playMetrics, $warningSurface) {
  if ($null -eq $playMetrics) { return $false }

  $playActive = [bool](Get-Prop $playMetrics "active" $false)
  if (-not $playActive) { return $false }

  $topSlotKind = [string](Get-Prop $playMetrics "topSlotKind" "")
  if ($topSlotKind) {
    $normalizedTopSlotKind = $topSlotKind.Trim().ToLowerInvariant()
    if ($normalizedTopSlotKind.StartsWith("warning")) { return $true }
    if ($normalizedTopSlotKind -eq "clock-header") { return $false }
  }

  $warningSurfaceState = [string](Get-Prop $warningSurface "state" "")
  if ($warningSurfaceState) {
    $normalizedWarningSurfaceState = $warningSurfaceState.Trim().ToLowerInvariant()
    if (@("visible", "present", "active", "shown", "shell-visible", "shell-only", "empty", "slot-only") -contains $normalizedWarningSurfaceState) {
      return $true
    }
  }

  $warningTopslotVisible = ConvertTo-VpTestNullableBool (Get-Prop $playMetrics "warningTopslotVisible" $null)
  if ($warningTopslotVisible -eq $true) { return $true }

  return $false
}

function Test-VpTestAutoForbidPlayWarningSurface($routeMarkers, $playMetrics) {
  if ($null -eq $playMetrics) { return $false }

  $playActive = [bool](Get-Prop $playMetrics "active" $false)
  if (-not $playActive) { return $false }

  $hostname = [string](Get-Prop $routeMarkers "hostname" "")
  if (-not $hostname) { return $false }
  $normalizedHost = $hostname.Trim().ToLowerInvariant()
  if (@("babachess.com", "www.babachess.com") -notcontains $normalizedHost) { return $false }

  $isBcTestPath = [bool](Get-Prop $routeMarkers "isBcTestPath" $false)
  if (-not $isBcTestPath) { return $false }

  $hasAutodebug = ConvertTo-VpTestNullableBool (Get-Prop $routeMarkers "hasAutodebug" $null)
  if ($null -ne $hasAutodebug -and -not $hasAutodebug) { return $false }

  return $true
}

function Get-VpTestDefaultLocalPreCaptureSetup([int]$viewportWidth, [int]$viewportHeight) {
  $context = $null
  if ($viewportWidth -le 900 -and $viewportHeight -ge $viewportWidth) {
    $context = @{
      hasTouch = $true
      isMobile = $false
      screenOrientation = "portrait-primary"
    }
  }

  $setup = [ordered]@{
    resetGame = $true
    mode = "ANALYZE"
    compactRailTarget = "right-rail"
    clearMatthiasWarning = $true
    clockConfig = @{
      whiteMs = 600000
      blackMs = 600000
      whiteEnabled = $true
      blackEnabled = $true
    }
    seedMoves = @(
      @("e2", "e4"),
      @("e7", "e5"),
      @("g1", "f3"),
      @("b8", "c6"),
      @("f1", "c4"),
      @("f8", "c5")
    )
  }

  if ($context) {
    $setup["context"] = $context
  }

  return $setup
}

function Get-VpTestCaptureViewportProfile($capture) {
  if ($null -eq $capture) { return $null }

  $viewport = Get-Prop $capture "viewport" $null
  $viewportContext = Get-Prop $capture "viewportContext" $null
  $resolvedViewport = Get-Prop $viewportContext "resolvedViewport" $null
  $screen = Get-Prop $viewportContext "screen" $null
  $input = Get-Prop $viewportContext "input" $null
  $pointer = Get-Prop $input "pointer" $null

  $width = Get-VpTestOptionalIntValue $viewport "width"
  if ($null -eq $width) {
    $width = Get-VpTestOptionalIntValue $resolvedViewport "width"
  }
  if ($null -eq $width) {
    $width = Get-VpTestOptionalIntValue $viewportContext "innerWidth"
  }

  $height = Get-VpTestOptionalIntValue $viewport "height"
  if ($null -eq $height) {
    $height = Get-VpTestOptionalIntValue $resolvedViewport "height"
  }
  if ($null -eq $height) {
    $height = Get-VpTestOptionalIntValue $viewportContext "innerHeight"
  }

  $deviceScaleFactor = Get-VpTestOptionalDoubleValue $viewportContext "devicePixelRatio"
  $screenOrientation = [string](Get-Prop (Get-Prop $screen "orientation" $null) "type" "")
  if (-not $screenOrientation) {
    $screenOrientation = [string](Get-Prop $resolvedViewport "screenOrientationType" "")
  }
  $maxTouchPoints = Get-VpTestOptionalIntValue $input "maxTouchPoints"
  $pointerCoarse = ConvertTo-VpTestNullableBool (Get-Prop $pointer "coarse" $null)
  $touchLike = ConvertTo-VpTestNullableBool (Get-Prop $resolvedViewport "isTouchLike" $null)
  $hasTouch = ($touchLike -eq $true) -or ($pointerCoarse -eq $true) -or ($null -ne $maxTouchPoints -and $maxTouchPoints -gt 0)

  $context = [ordered]@{}
  if ($hasTouch) {
    $context["hasTouch"] = $true
    $context["isMobile"] = $false
  }
  if ($null -ne $deviceScaleFactor) {
    $context["deviceScaleFactor"] = $deviceScaleFactor
  }
  if ($screenOrientation) {
    $context["screenOrientation"] = $screenOrientation
  }

  if ($null -eq $width -and $null -eq $height -and $context.Count -eq 0) { return $null }

  return [ordered]@{
    width = $width
    height = $height
    context = $(if ($context.Count -gt 0) { $context } else { $null })
  }
}

function Get-VpTestDefaultCompareLocalPreCaptureSetup([string]$lookupMode, $selectedCandidateSummary, $capture) {
  if ($null -eq $selectedCandidateSummary -and $null -eq $capture) { return $null }

  $viewportProfile = Get-VpTestCaptureViewportProfile $capture
  $viewportContext = Get-Prop $viewportProfile "context" $null
  $routeMode = ""
  $analyzeCapture = Get-Prop $capture "analyzeRightRailMetrics" $null
  $playCapture = Get-Prop $capture "playRightRailMetrics" $null
  $analyzeActive = [bool](Get-Prop $analyzeCapture "active" $false)
  $playActive = [bool](Get-Prop $playCapture "active" $false)
  if ($analyzeActive -and -not $playActive) {
    $routeMode = "ANALYZE"
  } elseif ($playActive -and -not $analyzeActive) {
    $routeMode = "PLAY"
  }

  if (-not $routeMode -and $lookupMode -ne "fresh-capture") {
    $routeMode = [string](Get-Prop $selectedCandidateSummary "routeMode" "")
    if (-not $routeMode) {
      $selectedReason = [string](Get-Prop $selectedCandidateSummary "selectedReason" "")
      if ($selectedReason -match 'routeMode=([a-zA-Z]+)') {
        $routeMode = [string]$Matches[1]
      }
    }
    if (-not $routeMode) {
      $selectionReasons = @(@(Get-Prop $selectedCandidateSummary "selectionReasons" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
      foreach ($selectionReason in $selectionReasons) {
        if ([string]$selectionReason -match 'routeMode=([a-zA-Z]+)') {
          $routeMode = [string]$Matches[1]
          break
        }
      }
    }
  }
  if (-not $routeMode) {
    if ($null -ne $viewportContext) {
      return [ordered]@{
        context = $viewportContext
      }
    }
    return $null
  }

  $normalizedRouteMode = $routeMode.Trim().ToUpperInvariant()
  if ($normalizedRouteMode -ne "ANALYZE") {
    if ($null -ne $viewportContext) {
      return [ordered]@{
        context = $viewportContext
      }
    }
    return $null
  }

  $setup = [ordered]@{
    resetGame = $true
    mode = "ANALYZE"
    compactRailTarget = "right-rail"
    clearMatthiasWarning = $true
  }
  if ($null -ne $viewportContext) {
    $setup["context"] = $viewportContext
  }
  return $setup
}

function Get-VpTestLocalUmamiConfig() {
  $cachedVar = Get-Variable -Name VpTestLocalUmamiConfigCache -Scope Script -ErrorAction SilentlyContinue
  if ($cachedVar) {
    return $cachedVar.Value
  }

  $config = @{}
  $jsonPath = Join-Path $RepoRoot ".private\umami.json"
  if (Test-Path -LiteralPath $jsonPath) {
    $json = Try-ReadJson $jsonPath
    if ($json) {
      foreach ($key in @("UMAMI_BASE_URL", "UMAMI_API_BASE_URL", "UMAMI_WEBSITE_ID", "UMAMI_BEARER_TOKEN", "UMAMI_API_TOKEN", "UMAMI_USERNAME", "UMAMI_PASSWORD")) {
        $value = [string](Get-Prop $json $key "")
        if (-not $value) {
          $value = [string](Get-Prop $json ($key.ToLowerInvariant()) "")
        }
        if ($value) { $config[$key] = $value.Trim() }
      }
    }
  }

  $envPath = Join-Path $RepoRoot ".private\umami.env"
  if (Test-Path -LiteralPath $envPath) {
    foreach ($line in @(Get-Content -LiteralPath $envPath)) {
      $trimmed = [string]$line
      if (-not $trimmed) { continue }
      $trimmed = $trimmed.Trim()
      if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }
      $separator = $trimmed.IndexOf("=")
      if ($separator -le 0) { continue }
      $key = $trimmed.Substring(0, $separator).Trim()
      $value = $trimmed.Substring($separator + 1).Trim()
      if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2).Trim()
      }
      if ($key -and $value) { $config[$key] = $value }
    }
  }

  $script:VpTestLocalUmamiConfigCache = $config
  return $config
}

function Get-VpTestUmamiValue([string]$name, [string]$defaultValue = "") {
  $envValue = [string]([Environment]::GetEnvironmentVariable($name, "Process"))
  if ($envValue) { return $envValue }
  $localConfig = Get-VpTestLocalUmamiConfig
  $localValue = [string](Get-Prop $localConfig $name "")
  if ($localValue) { return $localValue }
  return $defaultValue
}

function Get-VpTestFlaggedHeuristicIds($analysis) {
  $flagged = @()
  foreach ($heuristic in @($analysis.heuristics)) {
    if ([string](Get-Prop $heuristic "status" "") -eq "flag") {
      $id = [string](Get-Prop $heuristic "id" "")
      if ($id) { $flagged += $id }
    }
  }
  return @($flagged)
}

function Get-VpTestDeadlockContract([string[]]$flaggedIds) {
  $flaggedLookup = @{}
  foreach ($id in @($flaggedIds)) {
    if ($id) { $flaggedLookup[[string]$id] = $true }
  }

  $blockingHeuristics = @()
  $deadlockSignatures = @()

  if ($flaggedLookup.ContainsKey("interactivity-deadlock")) {
    $blockingHeuristics += "interactivity-deadlock"
    $deadlockSignatures += "interactivity-deadlock"
  }
  if ($flaggedLookup.ContainsKey("overlay-blocker")) {
    $blockingHeuristics += "overlay-blocker"
  }
  if ($flaggedLookup.ContainsKey("orientation-mismatch")) {
    $blockingHeuristics += "orientation-mismatch"
  }
  if ($flaggedLookup.ContainsKey("overlay-blocker") -and $flaggedLookup.ContainsKey("orientation-mismatch")) {
    $deadlockSignatures += "touch-deadlock-overlay-orientation"
  }

  return [ordered]@{
    isBlocking = (@($deadlockSignatures).Count -gt 0)
    blockingHeuristics = @($blockingHeuristics | Select-Object -Unique)
    deadlockSignatures = @($deadlockSignatures | Select-Object -Unique)
  }
}

function Write-VpTestLocalhostPlaceholderArtifacts(
  [string]$capturePath,
  [string]$analysisReportPath,
  [string]$analysisSummaryPath,
  [string]$compareUrl,
  [string]$timestamp,
  [string]$reasonCode,
  [string]$reasonMessage
) {
  $capturePlaceholder = [ordered]@{
    tool = "vp-test-localhost-placeholder"
    generatedAt = $timestamp
    pageUrl = $compareUrl
    status = "missing"
    uploadStatus = "missing"
    localMode = $true
    bundleId = ""
    firstInputCaptured = $false
    inputTraceLength = 0
    tappableTargetCount = 0
    localExportPath = $null
    reasonCode = $reasonCode
    reason = $reasonMessage
  }
  Write-Json $capturePath $capturePlaceholder

  $analysisPlaceholder = [ordered]@{
    tool = "vp-test-localhost-placeholder"
    generatedAt = $timestamp
    bundleId = ""
    verdict = "needs-attention"
    reasonCode = $reasonCode
    reason = $reasonMessage
    inputs = [ordered]@{
      screenshotPath = ""
    }
    heuristics = @(
      [ordered]@{
        id = $reasonCode
        status = "flag"
        summary = $reasonMessage
      }
    )
  }
  Write-Json $analysisReportPath $analysisPlaceholder

  $summaryLines = @(
    "# VP Test Localhost Analysis",
    "",
    "- Generated: " + $timestamp,
    "- Verdict: needs-attention",
    "- Reason code: " + $reasonCode,
    "- Reason: " + $reasonMessage
  ) -join "`r`n"
  Atomic-WriteTextUtf8 $analysisSummaryPath ($summaryLines + "`r`n")
}

function Get-VpTestAnalyzeRightRailCaptureHeuristics($metrics, $movesPanelMetrics = $null) {
  $flags = @()
  if ($null -eq $metrics) { return @($flags) }
  $active = [bool](Get-Prop $metrics "active" $false)
  if (-not $active) { return @($flags) }

  $clockCornerCovered = [bool](Get-Prop $metrics "clockCornerCovered" $false)
  $playLikeRuntimeTitle = [bool](Get-Prop $metrics "playLikeRuntimeTitle" $false)
  $boardGreenRisk = [bool](Get-Prop $metrics "boardGreenRisk" $false)
  $rowBudget = $null
  $visibleMoveRows = $null
  $visibleRowsByHeight = $null
  $extraMoveRowsPossible = $null
  $movesToLiveGapPx = $null
  $movesPanelBodySlackPx = $null
  $movesPanelUnusedHeightPx = $null
  $moveListBodyBottomSlackPx = $null
  $moveListEmptySlotCount = $null
  $moveListFirstRowHeightPx = $null
  $rowHeightPx = $null
  $rowBloatPx = $null
  $rowHeightRatio = $null
  $moveListGridToLiveHeaderGapPx = $null
  $moveListLastVisibleRowToLiveHeaderGapPx = $null
  $moveListLastVisibleRowOverlapIntoLiveHeaderPx = $null
  $moveListLastVisibleRowOverflowBeyondScrollPx = $null
  $moveListLastVisibleRowOverflowBeyondMovesPanelPx = $null
  $headerToBoardGapPx = $null
  $headerBoardOverlapPx = $null
  $rowUsageShare = $null
  $labelHeight = $null
  $titleGap = $null

  try { $rowBudget = [int](Get-Prop $metrics "rowBudget" $null) } catch { $rowBudget = $null }
  try { $visibleMoveRows = [int](Get-Prop $metrics "visibleMoveRows" $null) } catch { $visibleMoveRows = $null }
  try { $visibleRowsByHeight = [int](Get-Prop $metrics "visibleRowsByHeight" $null) } catch { $visibleRowsByHeight = $null }
  try { $extraMoveRowsPossible = [int](Get-Prop $metrics "extraMoveRowsPossible" $null) } catch { $extraMoveRowsPossible = $null }
  try { $movesToLiveGapPx = [double](Get-Prop $metrics "movesToLiveGapPx" $null) } catch { $movesToLiveGapPx = $null }
  try { $movesPanelBodySlackPx = [double](Get-Prop $movesPanelMetrics "movesPanelUnusedHeightPx" $null) } catch { $movesPanelBodySlackPx = $null }
  try { $moveListBodyBottomSlackPx = [double](Get-Prop $metrics "moveListBodyBottomSlackPx" $null) } catch { $moveListBodyBottomSlackPx = $null }
  try { $moveListEmptySlotCount = [int](Get-Prop $movesPanelMetrics "moveListEmptySlotCount" $null) } catch { $moveListEmptySlotCount = $null }
  try { $moveListFirstRowHeightPx = [double](Get-Prop $movesPanelMetrics "moveListFirstRowHeightPx" $null) } catch { $moveListFirstRowHeightPx = $null }
  try { $rowHeightPx = [double](Get-Prop $metrics "rowHeight" $null) } catch { $rowHeightPx = $null }
  if ($null -eq $rowHeightPx) {
    try { $rowHeightPx = [double](Get-Prop $movesPanelMetrics "rowHeight" $null) } catch { $rowHeightPx = $null }
  }
  if ($null -ne $rowHeightPx -and $null -ne $moveListFirstRowHeightPx) {
    $rowBloatPx = [math]::Round(($moveListFirstRowHeightPx - $rowHeightPx), 2)
    if ($rowHeightPx -gt 0) {
      $rowHeightRatio = [math]::Round(($moveListFirstRowHeightPx / $rowHeightPx), 4)
    }
  }
  try { $movesPanelUnusedHeightPx = [double](Get-Prop $movesPanelMetrics "gridUnusedInScrollPx" $null) } catch { $movesPanelUnusedHeightPx = $null }
  if ($null -eq $movesPanelUnusedHeightPx) {
    try { $movesPanelUnusedHeightPx = [double](Get-Prop $metrics "moveListBodyBottomSlackPx" $null) } catch { $movesPanelUnusedHeightPx = $null }
  }
  $moveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $metrics "moveListGridToLiveHeaderGapPx"
  if ($null -eq $moveListGridToLiveHeaderGapPx) {
    $moveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $movesPanelMetrics "moveListGridToLiveHeaderGapPx"
  }
  $moveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $metrics "moveListLastVisibleRowToLiveHeaderGapPx"
  if ($null -eq $moveListLastVisibleRowToLiveHeaderGapPx) {
    $moveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $movesPanelMetrics "moveListLastVisibleRowToLiveHeaderGapPx"
  }
  $moveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $metrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
  if ($null -eq $moveListLastVisibleRowOverlapIntoLiveHeaderPx) {
    $moveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $movesPanelMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
  }
  $moveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $metrics "moveListLastVisibleRowOverflowBeyondScrollPx"
  if ($null -eq $moveListLastVisibleRowOverflowBeyondScrollPx) {
    $moveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $movesPanelMetrics "moveListLastVisibleRowOverflowBeyondScrollPx"
  }
  $moveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $metrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
  if ($null -eq $moveListLastVisibleRowOverflowBeyondMovesPanelPx) {
    $moveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $movesPanelMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
  }
  try { $headerToBoardGapPx = [double](Get-Prop $metrics "headerToBoardGapPx" $null) } catch { $headerToBoardGapPx = $null }
  try { $headerBoardOverlapPx = [double](Get-Prop $metrics "headerBoardOverlapPx" $null) } catch { $headerBoardOverlapPx = $null }
  try { $rowUsageShare = [double](Get-Prop $metrics "liveStatsRowUsageShareOfBody" $null) } catch { $rowUsageShare = $null }
  try { $labelHeight = [double](Get-Prop $metrics "liveStatsMaxLabelHeightPx" $null) } catch { $labelHeight = $null }
  try { $titleGap = [double](Get-Prop $metrics "liveStatsTitleToBodyGapPx" $null) } catch { $titleGap = $null }

  if ($clockCornerCovered) { $flags += "analyze-clock-top-overlap" }
  if ($playLikeRuntimeTitle) { $flags += "analyze-play-topslot" }
  if (
    ($null -ne $headerToBoardGapPx -and $headerToBoardGapPx -lt 4) -or
    ($null -ne $headerBoardOverlapPx -and $headerBoardOverlapPx -gt 0.5)
  ) {
    $flags += "analyze-header-board-gap"
  }
  if ($boardGreenRisk) { $flags += "analyze-board-outline" }
  if (
    ($null -ne $rowBudget -and $null -ne $visibleMoveRows -and ($rowBudget - $visibleMoveRows) -ge 1) -or
    ($null -ne $visibleRowsByHeight -and $null -ne $visibleMoveRows -and ($visibleRowsByHeight - $visibleMoveRows) -ge 1) -or
    ($null -ne $extraMoveRowsPossible -and $extraMoveRowsPossible -ge 1) -or
    ($null -ne $moveListEmptySlotCount -and $moveListEmptySlotCount -gt 0) -or
    ($null -ne $movesToLiveGapPx -and $movesToLiveGapPx -gt 2) -or
    ($null -ne $movesPanelUnusedHeightPx -and $movesPanelUnusedHeightPx -gt 2) -or
    ($null -ne $movesPanelBodySlackPx -and $movesPanelBodySlackPx -gt 2) -or
    ($null -ne $rowBloatPx -and $rowBloatPx -gt 2) -or
    ($null -ne $rowHeightRatio -and $rowHeightRatio -gt 1.1)
  ) {
    $flags += "analyze-move-list-underfill"
  }
  if (
    ($null -ne $moveListGridToLiveHeaderGapPx -and (($moveListGridToLiveHeaderGapPx -lt 0) -or ($moveListGridToLiveHeaderGapPx -gt 2))) -or
    ($null -ne $moveListLastVisibleRowToLiveHeaderGapPx -and (($moveListLastVisibleRowToLiveHeaderGapPx -lt 0) -or ($moveListLastVisibleRowToLiveHeaderGapPx -gt 2))) -or
    ($null -ne $moveListLastVisibleRowOverlapIntoLiveHeaderPx -and $moveListLastVisibleRowOverlapIntoLiveHeaderPx -gt 0.5) -or
    ($null -ne $moveListLastVisibleRowOverflowBeyondScrollPx -and $moveListLastVisibleRowOverflowBeyondScrollPx -gt 0.5) -or
    ($null -ne $moveListLastVisibleRowOverflowBeyondMovesPanelPx -and $moveListLastVisibleRowOverflowBeyondMovesPanelPx -gt 0.5)
  ) {
    $flags += "analyze-bottom-seam-overlap"
  }
  if (
    ($null -ne $rowUsageShare -and $rowUsageShare -lt 0.9) -or
    ($null -ne $labelHeight -and $labelHeight -lt 9.5) -or
    ($null -ne $titleGap -and $titleGap -gt 4)
  ) {
    $flags += "analyze-live-stats-density"
  }

  return @($flags | Where-Object { $_ } | Select-Object -Unique)
}

function Get-VpTestPlayRightRailCaptureAssessment($metrics) {
  $assessment = [ordered]@{
    status = "unavailable"
    summary = "Der Capture-Pfad liefert keine Play-Right-Rail-Metriken."
    runtimeTitleText = ""
    topSlotToken = ""
    topSlotKind = ""
    clockHeaderTopToRailPx = $null
    clockHeaderMarginTopPx = $null
    clockHeaderMergedWithRuntime = $null
    clockHeaderToBodyGapPx = $null
    failures = @()
  }
  if ($null -eq $metrics) { return $assessment }

  $runtimeTitleText = [string](Get-Prop $metrics "runtimeTitleText" "")
  $runtimeCardVisible = [bool](Get-Prop $metrics "runtimeCardVisible" $false)
  $runtimeSurfaceVisible = [bool](Get-Prop $metrics "runtimeSurfaceVisible" $false)
  $warningShellVisible = ConvertTo-VpTestNullableBool (Get-Prop $metrics "warningShellVisible" $null)
  $warningTopslotVisible = ConvertTo-VpTestNullableBool (Get-Prop $metrics "warningTopslotVisible" $null)
  $clockHeaderMergedWithRuntime = [bool](Get-Prop $metrics "clockHeaderMergedWithRuntime" $false)
  $topSlotKind = [string](Get-Prop $metrics "topSlotKind" "")
  $topSlotIdentity = Get-Prop $metrics "topSlotIdentity" $null
  if ($warningShellVisible -eq $true) {
    $topSlotKind = "warning-shell"
    $topSlotIdentity = Get-Prop $metrics "warningShellIdentity" $topSlotIdentity
  }
  $topSlotToken = [string](Get-Prop $topSlotIdentity "testId" "")
  if (-not $topSlotToken) { $topSlotToken = [string](Get-Prop $topSlotIdentity "role" "") }
  if (-not $topSlotToken) { $topSlotToken = [string](Get-Prop $topSlotIdentity "tagName" "") }
  $clockHeaderTopToRailPx = $null
  $clockHeaderMarginTopPx = $null
  $clockHeaderToBodyGapPx = $null
  try { $clockHeaderTopToRailPx = [double](Get-Prop $metrics "clockHeaderTopToRailPx" $null) } catch { $clockHeaderTopToRailPx = $null }
  try { $clockHeaderMarginTopPx = [double](Get-Prop $metrics "clockHeaderMarginTopPx" $null) } catch { $clockHeaderMarginTopPx = $null }
  try { $clockHeaderToBodyGapPx = [double](Get-Prop $metrics "clockHeaderToBodyGapPx" $null) } catch { $clockHeaderToBodyGapPx = $null }

  $failures = @()
  if ($warningShellVisible -eq $true) {
    $failures += "warning-surface-visible-in-play"
  }
  if ($runtimeCardVisible -or $runtimeSurfaceVisible -or -not [string]::IsNullOrWhiteSpace($runtimeTitleText)) {
    $failures += "runtime-topslot-visible"
  }
  if ($clockHeaderMergedWithRuntime) {
    $failures += "clock-header-merged"
  }
  if ($warningShellVisible -ne $true) {
    if ($null -ne $clockHeaderTopToRailPx -and [Math]::Abs($clockHeaderTopToRailPx) -gt 1) {
      $failures += "clock-header-offset"
    }
    if ($null -ne $clockHeaderMarginTopPx -and $clockHeaderMarginTopPx -lt 0) {
      $failures += "clock-header-negative-margin"
    }
  }

  $assessment.runtimeTitleText = $runtimeTitleText
  $assessment.topSlotToken = $topSlotToken
  $assessment.topSlotKind = $topSlotKind
  $assessment.clockHeaderTopToRailPx = $clockHeaderTopToRailPx
  $assessment.clockHeaderMarginTopPx = $clockHeaderMarginTopPx
  $assessment.clockHeaderMergedWithRuntime = $clockHeaderMergedWithRuntime
  $assessment.clockHeaderToBodyGapPx = $clockHeaderToBodyGapPx
  $assessment.failures = @($failures)

  if (@($failures).Count -eq 0) {
    $assessment.status = "verified-clean"
    $assessment.summary =
      "Der aktuelle Capture-Pfad zeigt keinen sichtbaren Runtime-Topslot mehr; die Uhr startet eigenstaendig am Rail-Top."
  } elseif (@($failures) -contains "warning-surface-visible-in-play") {
    $assessment.status = "visible-drift"
    $assessment.summary =
      ("Der aktuelle Capture-Pfad zeigt im SPIELEN-Modus weiterhin eine sichtbare WARNUNG-Flaeche (" + ((@($failures) -join ", ")) + ").")
  } else {
    $assessment.status = "visible-drift"
    $assessment.summary =
      ("Der aktuelle Capture-Pfad zeigt weiterhin Play-Topslot-/Clock-Seam-Drift (" + ((@($failures) -join ", ")) + ").")
  }

  return $assessment
}

function Get-VpTestBundleExportCapture($bundleExport, [string]$fallbackPageUrl = "") {
  if ($null -eq $bundleExport) { return $null }
  $artifacts = Get-Prop $bundleExport "artifacts" $null
  $debugArtifact = Get-Prop $artifacts "debug" $null
  $debugJson = Get-Prop $debugArtifact "json" $null
  if ($null -eq $debugJson) { return $null }
  $legacyBottomSeamMetrics = Get-VpTestLegacyBottomSeamMetrics $debugJson
  $analyzeRightRailMetrics = Get-Prop $debugJson "analyzeRightRailSnapshot" $null
  if (($null -ne $legacyBottomSeamMetrics) -and ($null -ne $analyzeRightRailMetrics)) {
    foreach ($field in @(
        "moveListGridToLiveHeaderGapPx",
        "moveListLastVisibleRowToLiveHeaderGapPx",
        "moveListLastVisibleRowToLiveWrapperGapPx",
        "moveListLastVisibleRowOverlapIntoLiveHeaderPx",
        "moveListLastVisibleRowOverflowBeyondScrollPx",
        "moveListLastVisibleRowOverflowBeyondMovesPanelPx",
        "movesToLiveGapPx"
      )) {
      $currentValue = Get-Prop $analyzeRightRailMetrics $field $null
      if ($null -eq $currentValue) {
        $legacyValue = Get-Prop $legacyBottomSeamMetrics $field $null
        if ($null -ne $legacyValue) {
          if ($analyzeRightRailMetrics.PSObject.Properties.Name -contains $field) {
            $analyzeRightRailMetrics.$field = $legacyValue
          } else {
            $analyzeRightRailMetrics | Add-Member -NotePropertyName $field -NotePropertyValue $legacyValue
          }
        }
      }
    }
  }

  $meta = Get-Prop $debugJson "meta" $null
  $pageUrl = [string](Get-Prop $meta "url" "")
  if (-not $pageUrl) { $pageUrl = $fallbackPageUrl }

  $inputTrace = Get-Prop $debugJson "inputTrace" @()
  $tappableTargets = Get-Prop $debugJson "tappableTargets" @()
  $tappableTargetCount = 0
  if ($tappableTargets -is [System.Collections.IDictionary]) {
    try { $tappableTargetCount = [int]$tappableTargets.Count } catch { $tappableTargetCount = 0 }
  } else {
    try { $tappableTargetCount = [int](@($tappableTargets).Count) } catch { $tappableTargetCount = 0 }
  }

  return [ordered]@{
    pageUrl = $pageUrl
    bundleId = [string](Get-Prop $bundleExport "bundleId" "")
    manifestHint = [string](Get-Prop (Get-Prop $bundleExport "manifest" $null) "manifestPath" "")
    uploadStatus = "downloaded-export"
    firstInputCaptured = [bool](
      [bool](Get-Prop $meta "firstInputCaptured" $false) -or
      @($inputTrace).Count -gt 0
    )
    firstInputEventType = [string](Get-Prop $meta "firstInputEventType" "")
    inputTraceLength = @($inputTrace).Count
    tappableTargetCount = $tappableTargetCount
    movesPanelMetrics = Get-Prop $debugJson "movesPanelMetrics" $null
    analyzeRightRailMetrics = $analyzeRightRailMetrics
    playRightRailMetrics = Get-Prop $debugJson "playRightRailSnapshot" $null
    supplementalPanelMetrics = Get-Prop $debugJson "supplementalPanelMetrics" $null
    railTypographyMetrics = $(if ($null -ne (Get-Prop $debugJson "railTypographyMetrics" $null)) {
        Get-Prop $debugJson "railTypographyMetrics" $null
      } else {
        Get-VpTestLegacyRailTypographyMetrics $debugJson
      })
    liveStatsContractMetrics = $(if ($null -ne (Get-Prop $debugJson "liveStatsContractMetrics" $null)) {
        Get-Prop $debugJson "liveStatsContractMetrics" $null
      } else {
        Get-VpTestLegacyLiveStatsMetrics $debugJson
      })
    viewport = Get-Prop $debugJson "viewport" $null
    viewportContext = Get-Prop $debugJson "viewportContext" $null
    routeMarkers = Get-Prop $debugJson "routeMarkers" $null
    buildMarkers = Get-Prop $debugJson "buildMarkers" $null
    preCaptureSetup = $null
    localExportPath = [string](Get-Prop $debugArtifact "localPath" "")
  }
}

function Get-VpTestLookupCandidateSummary($candidate) {
  if ($null -eq $candidate) { return $null }
  $eventData = Get-Prop $candidate "eventData" $null
  $signals = Get-Prop $candidate "signals" $null
  return [ordered]@{
    bundleId = [string](Get-Prop $candidate "bundleId" "")
    createdAt = [string](Get-Prop $candidate "createdAt" "")
    source = [string](Get-Prop $candidate "source" "umami-live")
    routeMode = [string](Get-Prop $signals "routeMode" "")
    selectionClass = [string](Get-Prop $signals "selectionClass" "")
    playEligible = [bool](Get-Prop $signals "playEligible" $false)
    stage = [string](Get-Prop $signals "stage" "")
    firstInput = [string](Get-Prop $signals "firstInput" "")
    warningSurfaceKey = [string](Get-Prop $signals "warningSurfaceKey" "")
    warningSurfaceState = [string](Get-Prop $signals "warningSurfaceState" "")
    warningSurfaceVisible = Get-Prop $signals "warningSurfaceVisible" $null
    warningTopslotVariant = [string](Get-Prop $signals "warningTopslotVariant" "")
    warningTextLineCount = Get-Prop $signals "warningTextLineCount" $null
    playRightRailContext = [string](Get-Prop $signals "playRightRailContext" "")
    rightRailContext = [string](Get-Prop $signals "rightRailContext" "")
    analyzeMoveRows = [string](Get-Prop $eventData "analyzeMoveRows" "")
    analyzeLiveDensity = [string](Get-Prop $eventData "analyzeLiveDensity" "")
    selectedReason = [string](Get-Prop (Get-Prop $candidate "selection" $null) "reason" "")
    selectionReasons = @(@(Get-Prop $signals "selectionReasons" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
  }
}

function Format-VpTestLookupCandidateSummary($candidate) {
  if ($null -eq $candidate) { return "(missing)" }
  $reasons = @(@(Get-Prop $candidate "selectionReasons" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
  $warningSurfaceKey = [string](Get-Prop $candidate "warningSurfaceKey" "")
  $warningSurfaceState = [string](Get-Prop $candidate "warningSurfaceState" "")
  $warningSurfaceVisible = Get-Prop $candidate "warningSurfaceVisible" $null
  $warningTopslotVariant = [string](Get-Prop $candidate "warningTopslotVariant" "")
  $warningTextLineCount = Get-Prop $candidate "warningTextLineCount" $null
  return (
    [string](Get-Prop $candidate "bundleId" "") +
    $(if ([string](Get-Prop $candidate "source" "")) { " | source=" + [string](Get-Prop $candidate "source" "") } else { "" }) +
    " | class=" + [string](Get-Prop $candidate "selectionClass" "") +
    " | route=" + [string](Get-Prop $candidate "routeMode" "") +
    " | playEligible=" + [string](Get-Prop $candidate "playEligible" $null) +
    " | firstInput=" + $(if ([string](Get-Prop $candidate "firstInput" "")) { [string](Get-Prop $candidate "firstInput" "") } else { "(none)" }) +
    " | stage=" + $(if ([string](Get-Prop $candidate "stage" "")) { [string](Get-Prop $candidate "stage" "") } else { "(none)" }) +
    $(if ($warningSurfaceKey -or $warningSurfaceState) {
      " | warningSurface=" + $(if ($warningSurfaceState) { $warningSurfaceState } else { "unknown" }) +
        "@" + $(if ($warningSurfaceKey) { $warningSurfaceKey } else { "unspecified" }) +
        " | warningVisible=" + [string]$warningSurfaceVisible
    } else { "" }) +
    $(if ($warningTopslotVariant) { " | warningVariant=" + $warningTopslotVariant } else { "" }) +
    $(if ($null -ne $warningTextLineCount) { " | warningLines=" + [string]$warningTextLineCount } else { "" }) +
    " | analyzeRows=" + $(if ([string](Get-Prop $candidate "analyzeMoveRows" "")) { [string](Get-Prop $candidate "analyzeMoveRows" "") } else { "(n/a)" }) +
    $(if (@($reasons).Count -gt 0) { " | reasons=" + (@($reasons) -join "; ") } else { "" })
  )
}

function Format-VpTestWarningSurfaceSummary($warningSurface) {
  if ($null -eq $warningSurface) { return "(missing)" }
  $text = [string](Get-Prop $warningSurface "text" "")
  return (
    "state=" + $(if ([string](Get-Prop $warningSurface "state" "")) { [string](Get-Prop $warningSurface "state" "") } else { "(unknown)" }) +
      " | key=" + $(if ([string](Get-Prop $warningSurface "key" "")) { [string](Get-Prop $warningSurface "key" "") } else { "(missing)" }) +
      " | visible=" + [string](Get-Prop $warningSurface "visible" $null) +
      " | level=" + $(if ([string](Get-Prop $warningSurface "level" "")) { [string](Get-Prop $warningSurface "level" "") } else { "(empty)" }) +
      " | variant=" + $(if ([string](Get-Prop $warningSurface "variant" "")) { [string](Get-Prop $warningSurface "variant" "") } else { "(unknown)" }) +
      " | lines=" + [string](Get-Prop $warningSurface "textLineCount" $null) +
      " | shell=" + [string](Get-Prop $warningSurface "shellHeightPx" $null) + "px" +
      " | textBlock=" + [string](Get-Prop $warningSurface "textBlockHeightPx" $null) + "px" +
      $(if ($text) { " | text=" + $text } else { "" })
  )
}

function Format-VpTestUnderfillMetricsSummary($underfillMetrics) {
  if ($null -eq $underfillMetrics) { return "(missing)" }
  $hasMetrics =
    $null -ne (Get-Prop $underfillMetrics "panelUnusedPx" $null) -or
    $null -ne (Get-Prop $underfillMetrics "bodySlackPx" $null) -or
    $null -ne (Get-Prop $underfillMetrics "visibleMoveRows" $null) -or
    $null -ne (Get-Prop $underfillMetrics "rowBudget" $null) -or
    $null -ne (Get-Prop $underfillMetrics "visibleRowsByHeight" $null) -or
    $null -ne (Get-Prop $underfillMetrics "movesToLiveGapPx" $null)
  if (-not $hasMetrics) { return "(missing)" }
  return (
    "panelUnused=" + [string](Get-Prop $underfillMetrics "panelUnusedPx" $null) +
      "px | bodySlack=" + [string](Get-Prop $underfillMetrics "bodySlackPx" $null) +
      "px | rows=" + [string](Get-Prop $underfillMetrics "visibleMoveRows" $null) +
      "/" + [string](Get-Prop $underfillMetrics "rowBudget" $null) +
      " | visibleByHeight=" + [string](Get-Prop $underfillMetrics "visibleRowsByHeight" $null) +
      " | seam=" + [string](Get-Prop $underfillMetrics "movesToLiveGapPx" $null) + "px"
  )
}

function Format-VpTestBottomSeamMetricsSummary($bottomSeamMetrics) {
  if ($null -eq $bottomSeamMetrics) { return "(missing)" }
  $hasMetrics =
    $null -ne (Get-Prop $bottomSeamMetrics "moveListGridToLiveHeaderGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveHeaderGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveWrapperGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondScrollPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx" $null)
  if (-not $hasMetrics) { return "(missing)" }
  return (
    "gridToHeader=" + [string](Get-Prop $bottomSeamMetrics "moveListGridToLiveHeaderGapPx" $null) +
      "px | lastRowToHeader=" + [string](Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveHeaderGapPx" $null) +
      "px | lastRowToWrapper=" + [string](Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveWrapperGapPx" $null) +
      "px | overlap=" + [string](Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx" $null) +
      "px | overflowScroll=" + [string](Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondScrollPx" $null) +
      "px | overflowPanel=" + [string](Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx" $null) + "px"
  )
}

function Format-VpTestTypographyMetricsSummary($typographyMetrics) {
  if ($null -eq $typographyMetrics) { return "(missing)" }
  $hasMetrics =
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "glickoValueFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "clockTitleFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "clockDigitsFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerSourceLabelFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerMoveFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerEloFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "movesTitleFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelLineHeightPx")
  if (-not $hasMetrics) { return "(missing)" }
  $glickoValueFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "glickoValueFontSizePx"
  $clockTitleFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "clockTitleFontSizePx"
  $clockDigitsFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "clockDigitsFontSizePx"
  $explorerSourceLabelFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "explorerSourceLabelFontSizePx"
  $explorerMoveFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "explorerMoveFontSizePx"
  $explorerEloFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "explorerEloFontSizePx"
  $movesTitleFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "movesTitleFontSizePx"
  $liveLabelFontSizePx = Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelFontSizePx"
  $liveLabelLineHeightPx = Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelLineHeightPx"
  return (
    "glicko=" + $(if ($null -ne $glickoValueFontSizePx) { [string]$glickoValueFontSizePx } else { "n/a" }) +
      "px | clock=" + $(if ($null -ne $clockTitleFontSizePx) { [string]$clockTitleFontSizePx } else { "n/a" }) +
      "/" + $(if ($null -ne $clockDigitsFontSizePx) { [string]$clockDigitsFontSizePx } else { "n/a" }) +
      "px | explorer=" + $(if ($null -ne $explorerSourceLabelFontSizePx) { [string]$explorerSourceLabelFontSizePx } else { "n/a" }) +
      "/" + $(if ($null -ne $explorerMoveFontSizePx) { [string]$explorerMoveFontSizePx } else { "n/a" }) +
      "/" + $(if ($null -ne $explorerEloFontSizePx) { [string]$explorerEloFontSizePx } else { "n/a" }) +
      "px | movesTitle=" + $(if ($null -ne $movesTitleFontSizePx) { [string]$movesTitleFontSizePx } else { "n/a" }) +
      "px | live=" + $(if ($null -ne $liveLabelFontSizePx) { [string]$liveLabelFontSizePx } else { "n/a" }) +
      "/" + $(if ($null -ne $liveLabelLineHeightPx) { [string]$liveLabelLineHeightPx } else { "n/a" }) + "px"
  )
}

function Format-VpTestLiveStatsMetricsSummary($liveStatsMetrics) {
  if ($null -eq $liveStatsMetrics) { return "(missing)" }
  $missingQualities = @(
    @((Get-Prop $liveStatsMetrics "missingQualities" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ }
  )
  $rows = @((Get-Prop $liveStatsMetrics "rows" @()))
  $rowOverlapPx = Get-VpTestOptionalDoubleValue $liveStatsMetrics "rowOverlapPx"
  if ($null -eq $rowOverlapPx) {
    $rowOverlapPx = Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxTextOverlapPx"
  }
  $hasMetrics =
    $null -ne (Get-Prop $liveStatsMetrics "expectedCategoryCount" $null) -or
    $null -ne (Get-Prop $liveStatsMetrics "visibleCategoryCount" $null) -or
    $null -ne (Get-Prop $liveStatsMetrics "uniqueCategoryCount" $null) -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "panelHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "bottomSlackPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "rowBudgetPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxAllowedLineHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxTextOverlapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "rowOverlapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxLabelLineHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxFontHeightShareOfRow") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "headerToBodyGapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "bodyUsageShare") -or
    @($missingQualities).Count -gt 0 -or
    @($rows).Count -gt 0
  if (-not $hasMetrics) { return "(missing)" }
  return (
    "categories=" + [string](Get-Prop $liveStatsMetrics "visibleCategoryCount" $null) +
      "/" + [string](Get-Prop $liveStatsMetrics "expectedCategoryCount" $null) +
      " | unique=" + [string](Get-Prop $liveStatsMetrics "uniqueCategoryCount" $null) +
      " | missing=" + $(if (@($missingQualities).Count -gt 0) { (@($missingQualities) -join ",") } else { "none" }) +
      " | overlap=" + [string]$rowOverlapPx +
      "px | lineHeight=" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxLabelLineHeightPx") +
      "/" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxAllowedLineHeightPx") +
      "px | fontShare=" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxFontHeightShareOfRow") +
      " | bottomSlack=" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "bottomSlackPx") +
      "px | headerToBody=" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "headerToBodyGapPx") +
      "px | bodyUsage=" + [string](Get-VpTestOptionalDoubleValue $liveStatsMetrics "bodyUsageShare")
  )
}

function Test-VpTestUnderfillMetricsComparable($underfillMetrics) {
  if ($null -eq $underfillMetrics) { return $false }
  return (
    $null -ne (Get-Prop $underfillMetrics "panelUnusedPx" $null) -or
    $null -ne (Get-Prop $underfillMetrics "bodySlackPx" $null) -or
    $null -ne (Get-Prop $underfillMetrics "visibleMoveRows" $null) -or
    $null -ne (Get-Prop $underfillMetrics "rowBudget" $null) -or
    $null -ne (Get-Prop $underfillMetrics "visibleRowsByHeight" $null) -or
    $null -ne (Get-Prop $underfillMetrics "movesToLiveGapPx" $null)
  )
}

function Test-VpTestBottomSeamMetricsComparable($bottomSeamMetrics) {
  if ($null -eq $bottomSeamMetrics) { return $false }
  return (
    $null -ne (Get-Prop $bottomSeamMetrics "moveListGridToLiveHeaderGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveHeaderGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowToLiveWrapperGapPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx" $null) -or
    $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondScrollPx" $null) -or
      $null -ne (Get-Prop $bottomSeamMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx" $null)
  )
}

function Test-VpTestTypographyMetricsComparable($typographyMetrics) {
  if ($null -eq $typographyMetrics) { return $false }
  return (
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "glickoValueFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "clockTitleFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "clockDigitsFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerSourceLabelFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerMoveFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "explorerEloFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "movesTitleFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelFontSizePx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $typographyMetrics "liveLabelLineHeightPx")
  )
}

function Test-VpTestLiveStatsMetricsComparable($liveStatsMetrics) {
  if ($null -eq $liveStatsMetrics) { return $false }
  $missingQualities = @(Get-Prop $liveStatsMetrics "missingQualities" @())
  $rows = @(Get-Prop $liveStatsMetrics "rows" @())
  return (
    $null -ne (Get-Prop $liveStatsMetrics "expectedCategoryCount" $null) -or
    $null -ne (Get-Prop $liveStatsMetrics "visibleCategoryCount" $null) -or
    $null -ne (Get-Prop $liveStatsMetrics "uniqueCategoryCount" $null) -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "panelHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "bottomSlackPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "rowBudgetPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxAllowedLineHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxTextOverlapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "rowOverlapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxLabelLineHeightPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "maxFontHeightShareOfRow") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "headerToBodyGapPx") -or
    $null -ne (Get-VpTestOptionalDoubleValue $liveStatsMetrics "bodyUsageShare") -or
    @($missingQualities).Count -gt 0 -or
    @($rows).Count -gt 0
  )
}

function Get-VpTestCompareEffectiveHeuristics($heuristics, $suppressedHeuristics) {
  $suppressedLookup = @{}
  foreach ($heuristic in @($suppressedHeuristics)) {
    $normalized = [string]$heuristic
    if (-not $normalized) { continue }
    $suppressedLookup[$normalized] = $true
  }

  return @(
    @($heuristics) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ -and (-not $suppressedLookup.ContainsKey([string]$_)) } |
      Select-Object -Unique
  )
}

function Get-VpTestCompareSuppressionContract($bcTarget, $localhostTarget) {
  $bcUnderfillComparable = Test-VpTestUnderfillMetricsComparable (Get-Prop $bcTarget "underfillMetrics" $null)
  $bcBottomSeamComparable = Test-VpTestBottomSeamMetricsComparable (Get-Prop $bcTarget "bottomSeamMetrics" $null)
  $bcTypographyComparable = Test-VpTestTypographyMetricsComparable (Get-Prop $bcTarget "typographyMetrics" $null)
  $bcLiveStatsComparable = Test-VpTestLiveStatsMetricsComparable (Get-Prop $bcTarget "liveStatsMetrics" $null)
  $localhostUnderfillComparable = Test-VpTestUnderfillMetricsComparable (Get-Prop $localhostTarget "underfillMetrics" $null)
  $localhostBottomSeamComparable = Test-VpTestBottomSeamMetricsComparable (Get-Prop $localhostTarget "bottomSeamMetrics" $null)
  $localhostTypographyComparable = Test-VpTestTypographyMetricsComparable (Get-Prop $localhostTarget "typographyMetrics" $null)
  $localhostLiveStatsComparable = Test-VpTestLiveStatsMetricsComparable (Get-Prop $localhostTarget "liveStatsMetrics" $null)

  $combinedHeuristics = @()
  $combinedHeuristics += @((Get-Prop $bcTarget "captureHeuristics" @()))
  $combinedHeuristics += @((Get-Prop $bcTarget "flaggedHeuristics" @()))
  $combinedHeuristics += @((Get-Prop $localhostTarget "captureHeuristics" @()))
  $combinedHeuristics += @((Get-Prop $localhostTarget "flaggedHeuristics" @()))
  $combinedHeuristics = @(
    @($combinedHeuristics) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ } |
      Select-Object -Unique
  )

  $suppressedHeuristics = @()
  $suppressedDetails = @()
  if ((@($combinedHeuristics) -contains "analyze-bottom-seam-overlap") -and (-not $bcBottomSeamComparable -or -not $localhostBottomSeamComparable)) {
    $suppressedHeuristics += "analyze-bottom-seam-overlap"
    $suppressionReason = $(if (-not $bcBottomSeamComparable -and -not $localhostBottomSeamComparable) {
        "bc-test-and-localhost-missing-bottom-seam-metrics"
      } elseif (-not $bcBottomSeamComparable) {
        "bc-test-missing-bottom-seam-metrics"
      } else {
        "localhost-missing-bottom-seam-metrics"
      })
    $suppressedDetails += [ordered]@{
      heuristic = "analyze-bottom-seam-overlap"
      reason = $suppressionReason
      bcComparable = $bcBottomSeamComparable
      localhostComparable = $localhostBottomSeamComparable
    }
  }
  if ((@($combinedHeuristics) -contains "rail-typography-oversize") -and (-not $bcTypographyComparable -or -not $localhostTypographyComparable)) {
    $suppressedHeuristics += "rail-typography-oversize"
    $suppressionReason = $(if (-not $bcTypographyComparable -and -not $localhostTypographyComparable) {
        "bc-test-and-localhost-missing-typography-metrics"
      } elseif (-not $bcTypographyComparable) {
        "bc-test-missing-typography-metrics"
      } else {
        "localhost-missing-typography-metrics"
      })
    $suppressedDetails += [ordered]@{
      heuristic = "rail-typography-oversize"
      reason = $suppressionReason
      bcComparable = $bcTypographyComparable
      localhostComparable = $localhostTypographyComparable
    }
  }
  foreach ($liveStatsHeuristic in @("live-stats-missing-categories", "live-stats-row-overlap")) {
    if ((@($combinedHeuristics) -contains $liveStatsHeuristic) -and (-not $bcLiveStatsComparable -or -not $localhostLiveStatsComparable)) {
      $suppressedHeuristics += $liveStatsHeuristic
      $suppressionReason = $(if (-not $bcLiveStatsComparable -and -not $localhostLiveStatsComparable) {
          "bc-test-and-localhost-missing-live-stats-metrics"
        } elseif (-not $bcLiveStatsComparable) {
          "bc-test-missing-live-stats-metrics"
        } else {
          "localhost-missing-live-stats-metrics"
        })
      $suppressedDetails += [ordered]@{
        heuristic = $liveStatsHeuristic
        reason = $suppressionReason
        bcComparable = $bcLiveStatsComparable
        localhostComparable = $localhostLiveStatsComparable
      }
    }
  }

  return [ordered]@{
    suppressedHeuristics = @($suppressedHeuristics | Select-Object -Unique)
    details = @($suppressedDetails)
    support = [ordered]@{
      bcTest = [ordered]@{
        underfillComparable = $bcUnderfillComparable
        bottomSeamComparable = $bcBottomSeamComparable
        typographyComparable = $bcTypographyComparable
        liveStatsComparable = $bcLiveStatsComparable
      }
      localhost = [ordered]@{
        underfillComparable = $localhostUnderfillComparable
        bottomSeamComparable = $localhostBottomSeamComparable
        typographyComparable = $localhostTypographyComparable
        liveStatsComparable = $localhostLiveStatsComparable
      }
    }
  }
}

function Format-VpTestMetricSupportSummary($metricSupport) {
  if ($null -eq $metricSupport) { return "(missing)" }
  return (
    "underfill=" + [string](Get-Prop $metricSupport "underfillComparable" $null) +
      " | bottomSeam=" + [string](Get-Prop $metricSupport "bottomSeamComparable" $null) +
      " | typography=" + [string](Get-Prop $metricSupport "typographyComparable" $null) +
      " | liveStats=" + [string](Get-Prop $metricSupport "liveStatsComparable" $null)
  )
}

function Get-VpTestMetricSupportDifferences($metricSupport) {
  if ($null -eq $metricSupport) { return @() }
  $bcSupport = Get-Prop $metricSupport "bcTest" $null
  $localhostSupport = Get-Prop $metricSupport "localhost" $null
  if ($null -eq $bcSupport -or $null -eq $localhostSupport) { return @() }

  $differences = @()
  foreach ($field in @("underfillComparable", "bottomSeamComparable", "typographyComparable", "liveStatsComparable")) {
    $bcValue = Get-Prop $bcSupport $field $null
    $localhostValue = Get-Prop $localhostSupport $field $null
    if ([string]$bcValue -ne [string]$localhostValue) {
      $differences += $field
    }
  }
  return @($differences)
}

function Format-VpTestCompareMetricSupportSummary($metricSupport) {
  if ($null -eq $metricSupport) { return "(missing)" }
  $bcSupport = Format-VpTestMetricSupportSummary (Get-Prop $metricSupport "bcTest" $null)
  $localhostSupport = Format-VpTestMetricSupportSummary (Get-Prop $metricSupport "localhost" $null)
  return "bc-test: " + $bcSupport + " || localhost: " + $localhostSupport
}

function Format-VpTestSuppressedHeuristicDetails($details) {
  if ($null -eq $details) { return "none" }
  $entries = @(
    @($details) |
      Where-Object { $_ } |
      ForEach-Object {
        $heuristic = [string](Get-Prop $_ "heuristic" "")
        $reason = [string](Get-Prop $_ "reason" "")
        if (-not $heuristic) { return }
        $heuristic +
          $(if ($reason) { ":" + $reason } else { "" }) +
          " (bc=" + [string](Get-Prop $_ "bcComparable" $null) +
          ", localhost=" + [string](Get-Prop $_ "localhostComparable" $null) + ")"
      } |
      Where-Object { $_ }
  )
  if (@($entries).Count -eq 0) { return "none" }
  return (@($entries) -join " | ")
}

function Get-VpTestPathReconciliationTargetMetadata($routeMarkers) {
  $hostname = [string](Get-Prop $routeMarkers "hostname" "")
  $normalizedHostname = $hostname.Trim().ToLowerInvariant()
  $isBcTestPath = [bool](Get-Prop $routeMarkers "isBcTestPath" $false)
  $pathWithSearch = [string](Get-Prop $routeMarkers "pathWithSearch" "")
  $kind = "capture"
  $label = "Capture-Pfad"

  if (@("localhost", "127.0.0.1", "::1", "0.0.0.0") -contains $normalizedHostname) {
    $kind = "localhost"
    $label = "Localhost-Capture"
  } elseif ($isBcTestPath) {
    $kind = "bc-test"
    $label = "bc-test-Zielpfad"
  } elseif ($normalizedHostname) {
    $kind = "remote"
  }

  return [ordered]@{
    kind = $kind
    label = $label
    hostname = $hostname
    pathWithSearch = $pathWithSearch
  }
}

function Format-VpTestPlayRightRailDetail($playAssessment) {
  if ($null -eq $playAssessment) { return "(missing)" }
  $failures = @(
    @((Get-Prop $playAssessment "failures" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ }
  )
  return (
    "status=" + [string](Get-Prop $playAssessment "status" "") +
      " | topSlot=" + [string](Get-Prop $playAssessment "topSlotToken" "") +
      " | kind=" + [string](Get-Prop $playAssessment "topSlotKind" "") +
      " | runtimeTitle=" + $(if ([string](Get-Prop $playAssessment "runtimeTitleText" "")) { [string](Get-Prop $playAssessment "runtimeTitleText" "") } else { "(empty)" }) +
      " | clockTop=" + [string](Get-Prop $playAssessment "clockHeaderTopToRailPx" $null) +
      " | merged=" + [string](Get-Prop $playAssessment "clockHeaderMergedWithRuntime" $null) +
      " | seam=" + [string](Get-Prop $playAssessment "clockHeaderToBodyGapPx" $null) +
      $(if (@($failures).Count -gt 0) { " | failures=" + (@($failures) -join ",") } else { "" })
  )
}

function Set-VpTestLookupContext($report, $lookupPayload, [bool]$preserveCurrentBundleMode = $false) {
  if ($null -eq $report -or $null -eq $lookupPayload) { return $null }

  $selectedLookupCandidate = Get-Prop $lookupPayload "selected" $null
  if ($null -eq $selectedLookupCandidate) {
    $selectedLookupCandidate = Get-Prop $lookupPayload "latest" $null
  }
  $latestLookupCandidate = Get-Prop $lookupPayload "latest" $null
  $latestPlayLookupCandidate = Get-Prop $lookupPayload "latestPlay" $null
  $latestAnalyzeLookupCandidate = Get-Prop $lookupPayload "latestAnalyze" $null
  $seededPlayLookupCandidate = Get-Prop $lookupPayload "seededPlay" $null
  $lookupSelection = Get-Prop $lookupPayload "selection" $null
  $selectedBundleId = [string](Get-Prop $selectedLookupCandidate "bundleId" "")
  $selectionMode = [string](Get-Prop $lookupSelection "mode" "")
  if (-not $selectionMode) { $selectionMode = "latest-umami" }

  if (-not $preserveCurrentBundleMode) {
    $report.bundleLookup.mode = $selectionMode
    if ($selectedBundleId) {
      $report.bundleLookup.bundleId = $selectedBundleId
    }
  }

  $report.bundleLookup.selection = @{
    selectedReason = [string](Get-Prop $lookupSelection "selectedReason" "")
    latestRawBundleId = [string](Get-Prop $lookupSelection "latestRawBundleId" "")
    latestPlayBundleId = [string](Get-Prop $lookupSelection "latestPlayBundleId" "")
    latestAnalyzeBundleId = [string](Get-Prop $lookupSelection "latestAnalyzeBundleId" "")
    seededPlayBundleId = [string](Get-Prop $lookupSelection "seededPlayBundleId" "")
    playCandidateCount = $(try { [int](Get-Prop $lookupSelection "playCandidateCount" 0) } catch { 0 })
    analyzeCandidateCount = $(try { [int](Get-Prop $lookupSelection "analyzeCandidateCount" 0) } catch { 0 })
    rawLatestSelectionClass = [string](Get-Prop $lookupSelection "rawLatestSelectionClass" "")
    selectedSelectionClass = [string](Get-Prop $lookupSelection "selectedSelectionClass" "")
    selectedWarningSurfaceKey = [string](Get-Prop $lookupSelection "selectedWarningSurfaceKey" "")
    selectedWarningSurfaceState = [string](Get-Prop $lookupSelection "selectedWarningSurfaceState" "")
    selectedWarningTopslotVariant = [string](Get-Prop $lookupSelection "selectedWarningTopslotVariant" "")
    selectedWarningTextLineCount = Get-Prop $lookupSelection "selectedWarningTextLineCount" $null
    selectedWarningShellHeightPx = Get-Prop $lookupSelection "selectedWarningShellHeightPx" $null
    selectedWarningTextBlockHeightPx = Get-Prop $lookupSelection "selectedWarningTextBlockHeightPx" $null
    selectedWarningSurfaceMissing = [bool](Get-Prop $lookupSelection "selectedWarningSurfaceMissing" $false)
    selectedWarningSurfaceVisibleInPlay = [bool](Get-Prop $lookupSelection "selectedWarningSurfaceVisibleInPlay" $false)
    decisionCodes = @(
      @((Get-Prop $lookupSelection "decisionCodes" @())) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ } |
        Select-Object -Unique
    )
  }
  $report.bundleLookup.selectedCandidate = Get-VpTestLookupCandidateSummary $selectedLookupCandidate
  $report.bundleLookup.rawLatestCandidate = Get-VpTestLookupCandidateSummary $latestLookupCandidate
  $report.bundleLookup.latestPlayCandidate = Get-VpTestLookupCandidateSummary $latestPlayLookupCandidate
  $report.bundleLookup.latestAnalyzeCandidate = Get-VpTestLookupCandidateSummary $latestAnalyzeLookupCandidate
  $report.bundleLookup.seededPlayCandidate = Get-VpTestLookupCandidateSummary $seededPlayLookupCandidate

  return [ordered]@{
    selectedBundleId = $selectedBundleId
    selectionMode = $selectionMode
  }
}

function Cmd-VpTest() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $reportPath = Join-Path $RepoRoot "logs\ops\vp-test-report.json"
  $summaryPath = Join-Path $RepoRoot "logs\ops\vp-test-summary.md"
  $bcTestReportPath = Join-Path $RepoRoot "logs\ops\vp-test-bctest-report.json"
  $bcTestSummaryPath = Join-Path $RepoRoot "logs\ops\vp-test-bctest-summary.md"
  $localhostReportPath = Join-Path $RepoRoot "logs\ops\vp-test-localhost-report.json"
  $localhostSummaryPath = Join-Path $RepoRoot "logs\ops\vp-test-localhost-summary.md"
  $lookupPath = Join-Path $RepoRoot "logs\ops\vp-test-latest-bundle.json"
  $capturePath = Join-Path $RepoRoot "logs\ops\vp-test-capture.json"
  $localhostCapturePath = Join-Path $RepoRoot "logs\ops\vp-test-localhost-capture.json"
  $analysisReportPath = Join-Path $RepoRoot "logs\ops\ops-303-codex-bundle-analysis-report.json"
  $analysisSummaryPath = Join-Path $RepoRoot "logs\ops\ops-303-codex-bundle-analysis-summary.md"
  $localhostAnalysisReportPath = Join-Path $RepoRoot "logs\ops\vp-test-localhost-analysis-report.json"
  $localhostAnalysisSummaryPath = Join-Path $RepoRoot "logs\ops\vp-test-localhost-analysis-summary.md"
  $captureToolPath = Get-VpTestToolPath "VP_TEST_CAPTURE_TOOL_PATH" "tools\vp_test_capture_bundle.mjs"
  $lookupToolPath = Get-VpTestToolPath "VP_TEST_LOOKUP_TOOL_PATH" "tools\umami_latest_bundle.mjs"
  $analyzeToolPath = Get-VpTestToolPath "VP_TEST_ANALYZE_TOOL_PATH" "tools\codex_analyze_bundle.mjs"
  $invokeToolPath = Get-VpTestToolPath "VP_TEST_INVOKE_TOOL_PATH" "tools\codex_invoke.ps1"
  $parallelCompareRequested = Test-VpTestParallelCompareEnabled
  $timestamp = NowIso
  $ts = TsId
  $uploadBaseUrl = [string]([Environment]::GetEnvironmentVariable("BC_DEBUG_UPLOAD_BASE_URL", "Process"))
  if (-not $uploadBaseUrl) { $uploadBaseUrl = "https://babachess.com/bc-test" }
  $umamiBaseUrl = Get-VpTestUmamiValue "UMAMI_BASE_URL"
  if (-not $umamiBaseUrl) { $umamiBaseUrl = "https://analytics.babachess.com" }
  $umamiApiBaseUrl = Get-VpTestUmamiValue "UMAMI_API_BASE_URL"
  if (-not $umamiApiBaseUrl) { $umamiApiBaseUrl = ($umamiBaseUrl.TrimEnd("/") + "/api") }
  $websiteId = Get-VpTestUmamiValue "UMAMI_WEBSITE_ID"
  if (-not $websiteId) { $websiteId = "5f8dbd11-42f9-4286-bb25-19ae0377e44a" }
  $allowLocal = [string]([Environment]::GetEnvironmentVariable("VP_TEST_ALLOW_LOCALHOST", "Process"))
  $allowLocalEnabled = (-not [string]::IsNullOrWhiteSpace($allowLocal)) -and (@("0", "false", "no") -notcontains $allowLocal.Trim().ToLowerInvariant())
  $isLocalTarget = ([string]$uploadBaseUrl -match '^(?i)https?://(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0)(:\d+)?(/|$)')
  $requireLocalhostCompare = Test-VpTestRequireLocalhostCompare $uploadBaseUrl $isLocalTarget
  $compareLocalhostEnabled = Test-VpTestCompareLocalhostEnabled $uploadBaseUrl $isLocalTarget
  $compareLocalhostUrl = Get-VpTestCompareLocalhostUrl
  $uploadBasePath = ""
  try { $uploadBasePath = [string]([Uri]$uploadBaseUrl).AbsolutePath } catch { $uploadBasePath = "" }
  $uploadBaseHasBcTestPath = ($uploadBasePath -match '^(?i)/bc-test(/|$)')
  $captureMode = Get-VpTestCaptureMode
  $captureUrl = Get-VpTestCaptureUrl $uploadBaseUrl
  $expectRightRailWarning = Test-VpTestExpectationEnabled "VP_TEST_EXPECT_RIGHT_RAIL_WARNING"
  $expectCompactLiveStats = Test-VpTestExpectationEnabled "VP_TEST_EXPECT_COMPACT_LIVE_STATS"
  $token = Get-VpTestUmamiValue "UMAMI_BEARER_TOKEN"
  if (-not $token) { $token = Get-VpTestUmamiValue "UMAMI_API_TOKEN" }
  $username = Get-VpTestUmamiValue "UMAMI_USERNAME"
  $password = Get-VpTestUmamiValue "UMAMI_PASSWORD"
  $lookbackHours = 48
  $lookbackRaw = [string]([Environment]::GetEnvironmentVariable("VP_TEST_LOOKBACK_HOURS", "Process"))
  if ($lookbackRaw) {
    try { $lookbackHours = [Math]::Abs([int]$lookbackRaw) } catch { $lookbackHours = 48 }
  }
  $endAt = (Get-Date).ToUniversalTime()
  $startAt = $endAt.AddHours(-1 * $lookbackHours)
  $bundleId = $null
  $lookupMode = "latest-umami"
  if ($script:CommandArgs -and $script:CommandArgs.Count -gt 0) {
    $bundleId = [string]$script:CommandArgs[0]
    if ($bundleId) { $lookupMode = "explicit" }
  }
  $useLocalFreshCapture = ($isLocalTarget -and $allowLocalEnabled -and -not $uploadBaseHasBcTestPath -and -not $bundleId -and $captureMode -ne "lookup-only")
  $localExportPath = $null
  $localhostCompareJob = $null
  $localhostCompareTimestamp = $null
  $localhostCaptureLog = $null
  $localhostAnalyzeLog = $null

  $report = @{
    tool = "vp-test"
    generatedAt = $timestamp
    status = "running"
    target = @{
      uploadBaseUrl = $uploadBaseUrl
      umamiBaseUrl = $umamiBaseUrl
      umamiApiBaseUrl = $umamiApiBaseUrl
      websiteId = $websiteId
      mode = $(if ($useLocalFreshCapture) { "local-dev" } else { "prod" })
      localOverride = [bool]$allowLocalEnabled
      captureMode = $captureMode
      captureUrl = $captureUrl
      compareLocalhost = [bool]$compareLocalhostEnabled
      requireLocalhostCompare = [bool]$requireLocalhostCompare
      compareLocalhostUrl = $compareLocalhostUrl
      expectRightRailWarning = [bool]$expectRightRailWarning
      expectCompactLiveStats = [bool]$expectCompactLiveStats
    }
    bundleLookup = @{
      mode = $lookupMode
      bundleId = $bundleId
      lookupReport = $(if (Test-Path -LiteralPath $lookupPath) { To-RelPath $lookupPath } else { "logs/ops/vp-test-latest-bundle.json" })
      captureReport = $(if (Test-Path -LiteralPath $capturePath) { To-RelPath $capturePath } else { "logs/ops/vp-test-capture.json" })
      startAt = $startAt.ToString("o")
      endAt = $endAt.ToString("o")
    }
    analysis = @{
      reportPath = "logs/ops/ops-303-codex-bundle-analysis-report.json"
      summaryPath = "logs/ops/ops-303-codex-bundle-analysis-summary.md"
      verdict = $null
      flaggedHeuristics = @()
      flaggedHeuristicSummaries = @()
      captureHeuristics = @()
      captureUnderfillMetrics = $null
      captureBottomSeamMetrics = $null
      captureTypographyMetrics = $null
      captureLiveStatsMetrics = $null
      blockingHeuristics = @()
      deadlockSignatures = @()
    }
    error = $null
    comparison = @{
      enabled = [bool]$compareLocalhostEnabled
      status = $(if ($compareLocalhostEnabled) { "pending" } elseif ($requireLocalhostCompare) { "needs-attention" } else { "off" })
      compareUrl = $compareLocalhostUrl
      decisionCodes = $(if ($requireLocalhostCompare -and -not $compareLocalhostEnabled) { @("localhost-compare-required", "localhost-compare-disabled") } else { @() })
      summary = $(if ($compareLocalhostEnabled) {
        "Localhost-vs-bc-test Vergleich steht noch aus."
      } elseif ($requireLocalhostCompare) {
        "Localhost-Vergleich ist fuer diesen bc-test-Vertrag verpflichtend, wurde aber deaktiviert und liefert keine lokalen Artefakte."
      } else {
        "Localhost-Vergleich ist deaktiviert."
      })
      parallel = [ordered]@{
        requested = [bool]$parallelCompareRequested
        enabled = $false
        eligible = $false
        mode = "serial"
        decisionCodes = @()
      }
      bcTest = $null
      localhost = $null
    }
  }

  try {
    if ($isLocalTarget -and -not $allowLocalEnabled) {
      throw "vp-test refuses local/dev targets. It is intended for prod/live bundles. Use VP_TEST_ALLOW_LOCALHOST=1 only for function tests."
    }
    if (-not $useLocalFreshCapture -and (-not $token -and (-not $username -or -not $password))) {
      throw "vp-test requires Umami auth for live bundle lookup. Set UMAMI_BEARER_TOKEN/UMAMI_API_TOKEN or UMAMI_USERNAME + UMAMI_PASSWORD."
    }

    if (-not $bundleId -and $captureMode -ne "lookup-only") {
      $captureLog = Join-Path $LogsRoot ("terminal\vp-test-capture-" + $ts + ".log")
      $captureTimeoutMs = Get-VpTestCaptureTimeoutMs
      $captureEnv = @{}
      $existingPreCaptureSetup = [string]([Environment]::GetEnvironmentVariable("VP_TEST_PRECAPTURE_SETUP_JSON", "Process"))
      if ($useLocalFreshCapture -and -not $existingPreCaptureSetup) {
        $captureViewportWidth = Get-VpTestCaptureViewportDimension "VP_TEST_VIEWPORT_WIDTH" 1366
        $captureViewportHeight = Get-VpTestCaptureViewportDimension "VP_TEST_VIEWPORT_HEIGHT" 900
        $defaultPreCaptureSetup = Get-VpTestDefaultLocalPreCaptureSetup $captureViewportWidth $captureViewportHeight
        $captureEnv["VP_TEST_PRECAPTURE_SETUP_JSON"] = ($defaultPreCaptureSetup | ConvertTo-Json -Depth 8 -Compress)
      }
      $captureCmd = @(
        "node",
        (Quote-IfNeeded $captureToolPath),
        "--url", (Quote-IfNeeded $captureUrl),
        "--out-json", (Quote-IfNeeded $capturePath),
        "--timeout-ms", $captureTimeoutMs
      ) -join " "
      if ($useLocalFreshCapture) {
        $captureCmd += " --local-export-root " + (Quote-IfNeeded "logs/ops/vp-test")
      }
      $capture = Run-Cmd $captureCmd $captureLog $captureEnv
      if ($capture.exit -ne 0) { throw ("vp-test fresh capture failed. See " + $captureLog) }
      $capturePayload = Try-ReadJson $capturePath
      $bundleId = [string](Get-Prop $capturePayload "bundleId" "")
      $uploadStatus = [string](Get-Prop $capturePayload "uploadStatus" "")
      $firstInputCaptured = [bool](Get-Prop $capturePayload "firstInputCaptured" $false)
      $inputTraceLength = 0
      $tappableTargetCount = 0
      $movesPanelMetrics = Get-Prop $capturePayload "movesPanelMetrics" $null
      $analyzeRightRailMetrics = Get-Prop $capturePayload "analyzeRightRailMetrics" $null
      $playRightRailMetrics = Get-Prop $capturePayload "playRightRailMetrics" $null
      $routeMarkers = Get-Prop $capturePayload "routeMarkers" $null
      $buildMarkers = Get-Prop $capturePayload "buildMarkers" $null
      $preCaptureSetup = Get-Prop $capturePayload "preCaptureSetup" $null
      $feedback = Get-Prop $capturePayload "feedback" $null
      $localExportPath = [string](Get-Prop $capturePayload "localExportPath" "")
      $captureDomains = Get-Prop $capturePayload "captureDomains" @()
      $captureDomainSummary = Get-Prop $capturePayload "captureDomainSummary" $null
      try { $inputTraceLength = [int](Get-Prop $capturePayload "inputTraceLength" 0) } catch { $inputTraceLength = 0 }
      try { $tappableTargetCount = [int](Get-Prop $capturePayload "tappableTargetCount" 0) } catch { $tappableTargetCount = 0 }
      if (-not $bundleId) { throw "vp-test fresh capture did not return a bundleId." }
      if (-not $firstInputCaptured) { throw "vp-test fresh capture finished without first-input evidence." }
      if ($useLocalFreshCapture) {
        if ([string]$uploadStatus -ne "local-exported") {
          throw ("vp-test local fresh capture did not complete the local export (status=" + $uploadStatus + ").")
        }
        if (-not $localExportPath) { throw "vp-test local fresh capture did not write a local export payload." }
      } elseif ([string]$uploadStatus -ne "uploaded") {
        throw ("vp-test fresh capture did not upload successfully (status=" + $uploadStatus + ").")
      }
      if ($inputTraceLength -le 0) { throw "vp-test fresh capture finished without inputTrace evidence." }
      if ($tappableTargetCount -le 0) { throw "vp-test fresh capture finished without tappableTargets evidence." }
      $report.bundleLookup.mode = "fresh-capture"
      $report.bundleLookup.bundleId = $bundleId
      $report.bundleLookup.capture = @{
        pageUrl = [string](Get-Prop $capturePayload "pageUrl" $captureUrl)
        bundleId = $bundleId
        manifestHint = [string](Get-Prop $capturePayload "manifestHint" "")
        uploadStatus = $uploadStatus
        firstInputCaptured = $firstInputCaptured
        firstInputEventType = [string](Get-Prop $capturePayload "firstInputEventType" "")
        inputTraceLength = $inputTraceLength
        tappableTargetCount = $tappableTargetCount
        movesPanelMetrics = $movesPanelMetrics
        analyzeRightRailMetrics = $analyzeRightRailMetrics
        playRightRailMetrics = $playRightRailMetrics
        supplementalPanelMetrics = Get-Prop $capturePayload "supplementalPanelMetrics" $null
        railTypographyMetrics = Get-Prop $capturePayload "railTypographyMetrics" $null
        liveStatsContractMetrics = Get-Prop $capturePayload "liveStatsContractMetrics" $null
        routeMarkers = $routeMarkers
        buildMarkers = $buildMarkers
        captureDomains = $captureDomains
        captureDomainSummary = $captureDomainSummary
        preCaptureSetup = $preCaptureSetup
        feedback = $feedback
        localExportPath = $localExportPath
      }
    }

    $shouldRunLookup = (-not $useLocalFreshCapture -and $lookupMode -ne "explicit")
    if ($shouldRunLookup) {
      $lookupLog = Join-Path $LogsRoot ("terminal\vp-test-lookup-" + $ts + ".log")
      $lookupCmd = @(
        "node",
        (Quote-IfNeeded $lookupToolPath),
        "--out-json", (Quote-IfNeeded $lookupPath),
        "--start-at", (Quote-IfNeeded $startAt.ToString("o")),
        "--end-at", (Quote-IfNeeded $endAt.ToString("o")),
        "--upload-base-url", (Quote-IfNeeded $uploadBaseUrl),
        "--umami-base-url", (Quote-IfNeeded $umamiBaseUrl),
        "--umami-api-base-url", (Quote-IfNeeded $umamiApiBaseUrl),
        "--website-id", (Quote-IfNeeded $websiteId)
      ) -join " "
      $lookup = Run-Cmd $lookupCmd $lookupLog
      if ($lookup.exit -ne 0) {
        if (-not $bundleId) {
          throw ("vp-test lookup failed. See " + $lookupLog)
        }
      } else {
        $lookupPayload = Try-ReadJson $lookupPath
        $lookupContext = Set-VpTestLookupContext $report $lookupPayload ($report.bundleLookup.mode -eq "fresh-capture")
        if (-not $bundleId) {
          $bundleId = [string](Get-Prop $lookupContext "selectedBundleId" "")
          if (-not $bundleId) { throw "vp-test lookup did not return a bundleId." }
          $report.bundleLookup.bundleId = $bundleId
        }
      }
    }
    if (-not $bundleId) {
      throw "vp-test did not resolve a bundleId."
    }

    $parallelCompareDecisionCodes = @()
    $parallelCompareEligible = (
      $parallelCompareRequested -and
      $compareLocalhostEnabled -and
      (-not $useLocalFreshCapture) -and
      ($null -ne (Get-Prop $report.bundleLookup "capture" $null))
    )
    if ($parallelCompareRequested -and -not $parallelCompareEligible) {
      if (-not $compareLocalhostEnabled) { $parallelCompareDecisionCodes += "localhost-compare-disabled" }
      if ($useLocalFreshCapture) { $parallelCompareDecisionCodes += "local-dev-target" }
      if ($null -eq (Get-Prop $report.bundleLookup "capture" $null)) { $parallelCompareDecisionCodes += "capture-profile-missing" }
    }
    $report.comparison.parallel.eligible = [bool]$parallelCompareEligible
    $report.comparison.parallel.decisionCodes = @($parallelCompareDecisionCodes | Where-Object { $_ } | Select-Object -Unique)
    if ($parallelCompareEligible) {
      $localhostCompareTimestamp = NowIso
      $localhostCaptureLog = Join-Path $LogsRoot ("terminal\vp-test-localhost-capture-" + $ts + ".log")
      $localhostAnalyzeLog = Join-Path $LogsRoot ("terminal\vp-test-localhost-analyze-" + $ts + ".log")
      $localhostCaptureTimeoutMs = Get-VpTestCaptureTimeoutMs
      $localhostCaptureEnv = New-VpTestLocalhostCaptureEnv $report
      $localhostCaptureCmd = @(
        "node",
        (Quote-IfNeeded $captureToolPath),
        "--url", (Quote-IfNeeded $compareLocalhostUrl),
        "--out-json", (Quote-IfNeeded $localhostCapturePath),
        "--timeout-ms", $localhostCaptureTimeoutMs,
        "--local-export-root", (Quote-IfNeeded "logs/ops/vp-test/localhost")
      ) -join " "
      $localhostCompareJob = Start-VpTestLocalhostCompareJob `
        -captureCmd $localhostCaptureCmd `
        -captureLog $localhostCaptureLog `
        -captureEnv $localhostCaptureEnv `
        -capturePath $localhostCapturePath `
        -analyzeToolPath $analyzeToolPath `
        -analysisReportPath $localhostAnalysisReportPath `
        -analysisSummaryPath $localhostAnalysisSummaryPath `
        -analyzeLog $localhostAnalyzeLog `
        -captureTimeoutMs $localhostCaptureTimeoutMs
      $report.comparison.parallel.enabled = $true
      $report.comparison.parallel.mode = "remote-analysis-localhost-capture"
      $report.comparison.parallel.startedAt = $localhostCompareTimestamp
      $report.comparison.parallel.captureLog = To-RelPath $localhostCaptureLog
      $report.comparison.parallel.analyzeLog = To-RelPath $localhostAnalyzeLog
    }

    if ($useLocalFreshCapture) {
      $analyzeLog = Join-Path $LogsRoot ("terminal\vp-test-local-analyze-" + $ts + ".log")
      $analysisInputPath = $localExportPath
      if (-not [System.IO.Path]::IsPathRooted($analysisInputPath)) {
        $analysisInputPath = Join-Path $RepoRoot $analysisInputPath
      }
      $analyzeCmd = @(
        "node",
        (Quote-IfNeeded $analyzeToolPath),
        "--input", (Quote-IfNeeded $analysisInputPath),
        "--report", (Quote-IfNeeded $analysisReportPath),
        "--summary", (Quote-IfNeeded $analysisSummaryPath)
      ) -join " "
      $analyze = Run-Cmd $analyzeCmd $analyzeLog
      if ($analyze.exit -ne 0) { throw ("vp-test local analysis failed. See " + $analyzeLog) }
    } else {
      $invokeLog = Join-Path $LogsRoot ("terminal\vp-test-run-" + $ts + ".log")
      $invokeCmd = @(
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Quote-IfNeeded $invokeToolPath),
        "-BundleId", (Quote-IfNeeded $bundleId),
        "-StartAt", (Quote-IfNeeded $startAt.ToString("o")),
        "-EndAt", (Quote-IfNeeded $endAt.ToString("o")),
        "-OutDir", (Quote-IfNeeded "logs/ops/vp-test"),
        "-UploadBaseUrl", (Quote-IfNeeded $uploadBaseUrl),
        "-UmamiBaseUrl", (Quote-IfNeeded $umamiBaseUrl),
        "-UmamiApiBaseUrl", (Quote-IfNeeded $umamiApiBaseUrl),
        "-WebsiteId", (Quote-IfNeeded $websiteId)
      ) -join " "
      $invoke = Run-Cmd $invokeCmd $invokeLog
      if ($invoke.exit -ne 0) { throw ("vp-test analysis failed. See " + $invokeLog) }
      $bundleExportPath = Join-Path $RepoRoot (Join-Path ("logs\ops\vp-test\" + $bundleId) "bundle-export.json")
      $bundleExport = Try-ReadJson $bundleExportPath
      $lookupCapture = Get-VpTestBundleExportCapture $bundleExport $captureUrl
      if ($lookupCapture) {
        $report.bundleLookup.capture = $lookupCapture
      }
    }

    $analysis = Try-ReadJson $analysisReportPath
    if ($null -eq $analysis) { throw "vp-test did not produce a readable analysis report." }
    $flagged = Get-VpTestFlaggedHeuristicIds $analysis
    $deadlock = Get-VpTestDeadlockContract $flagged
    $report.analysis.verdict = [string](Get-Prop $analysis "verdict" $null)
    $report.analysis.captureDomains = Get-Prop $analysis "captureDomainSummary" $null
    $captureFlags = @()
    $captureMetrics = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "movesPanelMetrics" $null
    $analyzeCaptureMetrics = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "analyzeRightRailMetrics" $null
    $playCaptureMetrics = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "playRightRailMetrics" $null
    $captureTypographyMetrics = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "railTypographyMetrics" $null
    $captureLiveStatsMetrics = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "liveStatsContractMetrics" $null
    $warningSurface = Get-VpTestWarningSurfaceSignal $playCaptureMetrics $captureMetrics
    $routeMarkers = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "routeMarkers" $null
    $buildMarkers = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "buildMarkers" $null
    $report.analysis.captureTypographyMetrics = $captureTypographyMetrics
    $report.analysis.captureLiveStatsMetrics = $captureLiveStatsMetrics
    $effectiveExpectRightRailWarning = [bool]$expectRightRailWarning
    $expectRightRailWarningSource = $(if ($effectiveExpectRightRailWarning) { "env" } else { "off" })
    $expectPlayWarningTopslot = Test-VpTestPlayWarningTopslotExpected $playCaptureMetrics $warningSurface
    $forbidPlayWarningSurface = $false
    $forbidPlayWarningSurfaceSource = "off"
    if (-not $effectiveExpectRightRailWarning -and (Test-VpTestAutoForbidPlayWarningSurface $routeMarkers $playCaptureMetrics)) {
      $forbidPlayWarningSurface = $true
      $forbidPlayWarningSurfaceSource = "auto-prod-play-capture"
    }
    $report.target.expectRightRailWarning = [bool]$effectiveExpectRightRailWarning
    $report.target.expectRightRailWarningSource = $expectRightRailWarningSource
    $report.target.forbidPlayWarningSurface = [bool]$forbidPlayWarningSurface
    $report.target.forbidPlayWarningSurfaceSource = $forbidPlayWarningSurfaceSource
    if ($captureMetrics) {
      $movesShare = $null
      $liveShare = $null
      $visibleMoveRows = $null
      $rowBudget = $null
      $warningPresent = $null
      $warningCoachPresent = $null
      $warningHasVisibleWarning = $null
      $liveLabelFontPx = $null
      $liveLabelLineHeightPx = $null
      $liveCounterFontPx = $null
      $liveIconSizePx = $null
      $liveRowHeightPx = $null
      $liveBottomSlackPx = $null
      $moveListGridToLiveGapPx = $null
      try { $movesShare = [double](Get-Prop $captureMetrics "movesShareOfRail" $null) } catch { $movesShare = $null }
      try { $liveShare = [double](Get-Prop $captureMetrics "liveShareOfRail" $null) } catch { $liveShare = $null }
      try { $visibleMoveRows = [int](Get-Prop $captureMetrics "visibleMoveRows" $null) } catch { $visibleMoveRows = $null }
      try { $rowBudget = [int](Get-Prop $captureMetrics "rowBudget" $null) } catch { $rowBudget = $null }
      try { $warningPresent = [bool](Get-Prop $captureMetrics "warningPresent" $false) } catch { $warningPresent = $null }
      try { $warningCoachPresent = [bool](Get-Prop $captureMetrics "warningCoachPresent" $false) } catch { $warningCoachPresent = $null }
      try { $warningHasVisibleWarning = [bool](Get-Prop $captureMetrics "warningHasVisibleWarning" $false) } catch { $warningHasVisibleWarning = $null }
      try { $liveLabelFontPx = [double](Get-Prop $captureMetrics "firstLiveRowLabelFontSizePx" $null) } catch { $liveLabelFontPx = $null }
      try { $liveLabelLineHeightPx = [double](Get-Prop $captureMetrics "firstLiveRowLabelLineHeightPx" $null) } catch { $liveLabelLineHeightPx = $null }
      try { $liveCounterFontPx = [double](Get-Prop $captureMetrics "firstLiveRowCounterFontSizePx" $null) } catch { $liveCounterFontPx = $null }
      try { $liveIconSizePx = [double](Get-Prop $captureMetrics "firstLiveRowIconSizePx" $null) } catch { $liveIconSizePx = $null }
      try { $liveRowHeightPx = [double](Get-Prop $captureMetrics "firstLiveRowHeightPx" $null) } catch { $liveRowHeightPx = $null }
      try { $liveBottomSlackPx = [double](Get-Prop $captureMetrics "liveStatsBottomSlackPx" $null) } catch { $liveBottomSlackPx = $null }
      try { $moveListGridToLiveGapPx = [double](Get-Prop $captureMetrics "moveListGridToLiveGapPx" $null) } catch { $moveListGridToLiveGapPx = $null }
      if (
        $null -ne $movesShare -and
        $null -ne $liveShare -and
        $null -ne $visibleMoveRows -and
        $null -ne $rowBudget -and
        $visibleMoveRows -ge 8 -and
        $rowBudget -ge 8 -and
        $movesShare -lt 0.35 -and
        ($liveShare - $movesShare) -gt 0.10
      ) {
        $captureFlags += "play-moves-panel-underfill"
      }
      if (
        $expectCompactLiveStats -and (
          ($null -ne $liveLabelFontPx -and $liveLabelFontPx -gt 10.5) -or
          ($null -ne $liveLabelLineHeightPx -and $liveLabelLineHeightPx -gt 18.5) -or
          ($null -ne $liveCounterFontPx -and $liveCounterFontPx -gt 10.5) -or
          ($null -ne $liveIconSizePx -and $liveIconSizePx -gt 12.5) -or
          ($null -ne $liveRowHeightPx -and $liveRowHeightPx -gt 23.2) -or
          ($null -ne $liveBottomSlackPx -and $liveBottomSlackPx -gt 6)
        )
      ) {
        $captureFlags += "play-live-stats-oversized"
      }
    }
    if ($effectiveExpectRightRailWarning -and $expectPlayWarningTopslot -and ($warningSurface.contentVisible -ne $true)) {
      $captureFlags += "warning-topslot-missing"
    }
    if ($forbidPlayWarningSurface -and ($warningSurface.visible -eq $true)) {
      $captureFlags += "warning-surface-visible-in-play"
    }
    if ($analyzeCaptureMetrics) {
      $captureFlags += @(Get-VpTestAnalyzeRightRailCaptureHeuristics $analyzeCaptureMetrics $captureMetrics)
      $analyzePanelUnusedPx = $null
      $analyzeBodySlackPx = $null
      $analyzeVisibleRowsByHeight = $null
      $analyzeVisibleMoveRows = $null
      $analyzeRowBudget = $null
      $analyzeMovesToLiveGapPx = $null
      $analyzeMoveListGridToLiveHeaderGapPx = $null
      $analyzeMoveListLastVisibleRowToLiveHeaderGapPx = $null
      $analyzeMoveListLastVisibleRowToLiveWrapperGapPx = $null
      $analyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = $null
      $analyzeMoveListLastVisibleRowOverflowBeyondScrollPx = $null
      $analyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = $null
      try { $analyzePanelUnusedPx = [double](Get-Prop $captureMetrics "gridUnusedInScrollPx" $null) } catch { $analyzePanelUnusedPx = $null }
      if ($null -eq $analyzePanelUnusedPx) {
        try { $analyzePanelUnusedPx = [double](Get-Prop $analyzeCaptureMetrics "moveListBodyBottomSlackPx" $null) } catch { $analyzePanelUnusedPx = $null }
      }
      try { $analyzeBodySlackPx = [double](Get-Prop $captureMetrics "movesPanelUnusedHeightPx" $null) } catch { $analyzeBodySlackPx = $null }
      try { $analyzeVisibleRowsByHeight = [int](Get-Prop $analyzeCaptureMetrics "visibleRowsByHeight" $null) } catch { $analyzeVisibleRowsByHeight = $null }
      try { $analyzeVisibleMoveRows = [int](Get-Prop $analyzeCaptureMetrics "visibleMoveRows" $null) } catch { $analyzeVisibleMoveRows = $null }
      try { $analyzeRowBudget = [int](Get-Prop $analyzeCaptureMetrics "rowBudget" $null) } catch { $analyzeRowBudget = $null }
      try { $analyzeMovesToLiveGapPx = [double](Get-Prop $analyzeCaptureMetrics "movesToLiveGapPx" $null) } catch { $analyzeMovesToLiveGapPx = $null }
      $analyzeMoveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListGridToLiveHeaderGapPx"
      if ($null -eq $analyzeMoveListGridToLiveHeaderGapPx) {
        $analyzeMoveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListGridToLiveHeaderGapPx"
      }
      $analyzeMoveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListLastVisibleRowToLiveHeaderGapPx"
      if ($null -eq $analyzeMoveListLastVisibleRowToLiveHeaderGapPx) {
        $analyzeMoveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListLastVisibleRowToLiveHeaderGapPx"
      }
      $analyzeMoveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListLastVisibleRowToLiveWrapperGapPx"
      if ($null -eq $analyzeMoveListLastVisibleRowToLiveWrapperGapPx) {
        $analyzeMoveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListLastVisibleRowToLiveWrapperGapPx"
      }
      $analyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
      if ($null -eq $analyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx) {
        $analyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
      }
      $analyzeMoveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListLastVisibleRowOverflowBeyondScrollPx"
      if ($null -eq $analyzeMoveListLastVisibleRowOverflowBeyondScrollPx) {
        $analyzeMoveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListLastVisibleRowOverflowBeyondScrollPx"
      }
      $analyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $analyzeCaptureMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
      if ($null -eq $analyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx) {
        $analyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $captureMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
      }
      $report.analysis.captureUnderfillMetrics = [ordered]@{
        panelUnusedPx = $analyzePanelUnusedPx
        bodySlackPx = $analyzeBodySlackPx
        visibleRowsByHeight = $analyzeVisibleRowsByHeight
        visibleMoveRows = $analyzeVisibleMoveRows
        rowBudget = $analyzeRowBudget
        movesToLiveGapPx = $analyzeMovesToLiveGapPx
      }
      $report.analysis.captureBottomSeamMetrics = [ordered]@{
        moveListGridToLiveHeaderGapPx = $analyzeMoveListGridToLiveHeaderGapPx
        moveListLastVisibleRowToLiveHeaderGapPx = $analyzeMoveListLastVisibleRowToLiveHeaderGapPx
        moveListLastVisibleRowToLiveWrapperGapPx = $analyzeMoveListLastVisibleRowToLiveWrapperGapPx
        moveListLastVisibleRowOverlapIntoLiveHeaderPx = $analyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx
        moveListLastVisibleRowOverflowBeyondScrollPx = $analyzeMoveListLastVisibleRowOverflowBeyondScrollPx
        moveListLastVisibleRowOverflowBeyondMovesPanelPx = $analyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx
        movesToLiveGapPx = $analyzeMovesToLiveGapPx
      }
    }
    $mergedFlaggedHeuristics = @()
    $mergedFlaggedHeuristics += @($flagged)
    $mergedFlaggedHeuristics += @($captureFlags)
    $report.analysis.flaggedHeuristics = @($mergedFlaggedHeuristics | Where-Object { $_ } | Select-Object -Unique)
    $report.analysis.warningSurface = $warningSurface
    $report.analysis.flaggedHeuristicSummaries = @(
      @($analysis.heuristics) |
        Where-Object { [string](Get-Prop $_ "status" "") -eq "flag" } |
        ForEach-Object {
          $id = [string](Get-Prop $_ "id" "")
          $summaryText = [string](Get-Prop $_ "summary" "")
          if ($id -and $summaryText) { "${id}: $summaryText" } elseif ($id) { $id } elseif ($summaryText) { $summaryText }
        } |
        Where-Object { $_ }
    )
    $report.analysis.captureHeuristics = @($captureFlags)
    $report.analysis.blockingHeuristics = @($deadlock.blockingHeuristics)
    $report.analysis.deadlockSignatures = @($deadlock.deadlockSignatures)
    if ([bool]$deadlock.isBlocking) {
      throw ("vp-test detected touch deadlock: " + ((@($deadlock.deadlockSignatures) -join ", ") + " | heuristics=" + (@($deadlock.blockingHeuristics) -join ", ")))
    }
    $analysisVerdict = [string]$report.analysis.verdict
    if (-not $analysisVerdict) {
      $analysisVerdict = "needs-attention"
      $report.analysis.verdict = $analysisVerdict
    }
    if ($analysisVerdict -eq "insufficient-data") {
      throw "vp-test analysis is insufficient-data. Debug-Bundle oder Umami-Evidence ist unvollstaendig."
    }
    if (@($report.analysis.captureHeuristics).Count -gt 0 -and $analysisVerdict -eq "ready") {
      $analysisVerdict = "needs-attention"
      $report.analysis.verdict = $analysisVerdict
    }
    if ($analysisVerdict -eq "ready") {
      $report.status = "ready"
    } elseif ($analysisVerdict -eq "needs-attention") {
      $report.status = "needs-attention"
    } else {
      $report.status = "needs-attention"
    }

    $playAssessment = Get-VpTestPlayRightRailCaptureAssessment $playCaptureMetrics
    $pathTargetMetadata = Get-VpTestPathReconciliationTargetMetadata $routeMarkers
    $pathTargetKind = [string](Get-Prop $pathTargetMetadata "kind" "capture")
    $pathTargetLabel = [string](Get-Prop $pathTargetMetadata "label" "Capture-Pfad")
    $pathTargetSubject = "Der aktuelle " + $pathTargetLabel
    $lookupSelection = Get-Prop $report.bundleLookup "selection" $null
    $lookupDecisionCodes = @(
      @((Get-Prop $lookupSelection "decisionCodes" @())) |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ } |
        Select-Object -Unique
    )
    $pathDecisionCodes = @($lookupDecisionCodes)
    foreach ($captureDecisionCode in @("warning-topslot-missing", "warning-surface-visible-in-play")) {
      if ((@($report.analysis.flaggedHeuristics) -contains $captureDecisionCode) -and (@($pathDecisionCodes) -notcontains $captureDecisionCode)) {
        $pathDecisionCodes += $captureDecisionCode
      }
    }
    $pathDecisionCodes = @($pathDecisionCodes | Where-Object { $_ } | Select-Object -Unique)
    $conclusionCode = "play-path-context-missing"
    $conclusionText = "Der aktuelle Capture-Pfad liefert noch keinen belastbaren Play-Right-Rail-Abgleich."
    if (@($pathDecisionCodes).Count -gt 0) {
      if (@($pathDecisionCodes) -contains "play-path-context-missing") {
        $conclusionCode = "play-path-context-missing"
        $conclusionText =
          "Der neueste Rohkandidat bleibt Analyze-only, waehrend der fachlich relevante PLAY-Warnpfad nur als separater Kontext vorliegt; die Auswahlcodes bleiben " +
          ((@($pathDecisionCodes) -join ", ")) +
          "."
      } elseif (@($pathDecisionCodes) -contains "warning-surface-visible-in-play") {
        $conclusionCode = "warning-surface-visible-in-play"
        $conclusionText =
          "Der aktuelle Capture-Pfad zeigt im SPIELEN-Modus weiterhin eine sichtbare WARNUNG-Flaeche; das ist ein Zuviel und kein Missing-Fall."
      } elseif (@($pathDecisionCodes) -contains "warning-topslot-missing") {
        $conclusionCode = "warning-topslot-missing"
        $conclusionText =
          "Der aktuelle Capture-Pfad verfehlt weiterhin einen explizit erwarteten WARNUNG-Topslot."
      } else {
        $conclusionCode = [string]$pathDecisionCodes[0]
        $conclusionText =
          "Der aktuelle Capture-Pfad meldet weiterhin offene Play-Right-Rail-Codes: " +
          ((@($pathDecisionCodes) -join ", ")) +
          "."
      }
    } elseif ([string]$playAssessment.status -eq "verified-clean") {
      $conclusionCode = "current-play-topslot-clean"
      $conclusionText =
        $pathTargetSubject + " reproduziert den frueheren SPIELEN-/Clock-Seam-Fehler nicht mehr; die Abweichung ist damit wahrscheinlich historisch oder an einen anderen Route-/Build-Pfad gebunden."
    } elseif ([string]$playAssessment.status -eq "visible-drift") {
      $conclusionCode = "current-play-topslot-still-visible"
      $conclusionText =
        $pathTargetSubject + " zeigt weiterhin einen sichtbaren Play-Topslot-/Clock-Seam-Drift; der Widerspruch ist damit noch nicht auf einen historischen Pfad reduziert."
    }
    $report.pathReconciliation = [ordered]@{
      lookupSelection = [ordered]@{
        mode = [string](Get-Prop $report.bundleLookup "mode" "")
        selectedCandidate = Get-Prop $report.bundleLookup "selectedCandidate" $null
        rawLatestCandidate = Get-Prop $report.bundleLookup "rawLatestCandidate" $null
        latestPlayCandidate = Get-Prop $report.bundleLookup "latestPlayCandidate" $null
        latestAnalyzeCandidate = Get-Prop $report.bundleLookup "latestAnalyzeCandidate" $null
        decisionCodes = @($lookupDecisionCodes)
      }
      currentTarget = [ordered]@{
        kind = $pathTargetKind
        label = $pathTargetLabel
        routeMarkers = $routeMarkers
        buildMarkers = $buildMarkers
        playRightRail = $playAssessment
      }
      currentVpVerdict = [ordered]@{
        status = [string]$report.status
        verdict = [string]$report.analysis.verdict
        flaggedHeuristics = @($report.analysis.flaggedHeuristics)
        captureHeuristics = @($report.analysis.captureHeuristics)
      }
      decisionCodes = @($pathDecisionCodes)
      conclusionCode = $conclusionCode
      conclusion = $conclusionText
    }
    if (Test-Path -LiteralPath $lookupPath) {
      $lookupPersist = Try-ReadJson $lookupPath
      if ($lookupPersist) {
        $lookupPathReconciliation = [ordered]@{
          decisionCodes = @($pathDecisionCodes)
          conclusionCode = $conclusionCode
          conclusion = $conclusionText
        }
        if ($lookupPersist.PSObject.Properties.Name -contains "pathReconciliation") {
          $lookupPersist.pathReconciliation = $lookupPathReconciliation
        } else {
          $lookupPersist | Add-Member -NotePropertyName "pathReconciliation" -NotePropertyValue $lookupPathReconciliation
        }
        Write-Json $lookupPath $lookupPersist
      }
    }

    $bcRoutePathWithSearch = [string](Get-Prop $routeMarkers "pathWithSearch" "")
    if (-not $bcRoutePathWithSearch) {
      $bcRoutePathWithSearch = ([string](Get-Prop $routeMarkers "pathname" "") + [string](Get-Prop $routeMarkers "search" ""))
    }
    $report.comparison.bcTest = [ordered]@{
      target = "bc-test"
      url = $uploadBaseUrl
      bundleId = [string]$bundleId
      status = [string]$report.status
      verdict = [string]$report.analysis.verdict
      reportPath = To-RelPath $bcTestReportPath
      summaryPath = To-RelPath $bcTestSummaryPath
      captureReportPath = $(if (Test-Path -LiteralPath $capturePath) { To-RelPath $capturePath } else { $null })
      analysisReportPath = To-RelPath $analysisReportPath
      analysisSummaryPath = To-RelPath $analysisSummaryPath
      screenshotPath = [string](Get-Prop (Get-Prop $analysis "inputs" $null) "screenshotPath" "")
      routePathWithSearch = $bcRoutePathWithSearch
      buildBundleScript = [string](Get-Prop $buildMarkers "bundleScriptSrc" "")
      flaggedHeuristics = @($report.analysis.flaggedHeuristics)
      flaggedHeuristicSummaries = @($report.analysis.flaggedHeuristicSummaries)
      captureHeuristics = @($report.analysis.captureHeuristics)
      decisionCodes = @($pathDecisionCodes)
      warningSurface = $warningSurface
      underfillMetrics = Get-Prop $report.analysis "captureUnderfillMetrics" $null
      bottomSeamMetrics = Get-Prop $report.analysis "captureBottomSeamMetrics" $null
      typographyMetrics = Get-Prop $report.analysis "captureTypographyMetrics" $null
      liveStatsMetrics = Get-Prop $report.analysis "captureLiveStatsMetrics" $null
      compareFlaggedHeuristics = @($report.analysis.flaggedHeuristics)
      compareCaptureHeuristics = @($report.analysis.captureHeuristics)
      suppressedCompareHeuristics = @()
      metricSupport = [ordered]@{
        underfillComparable = Test-VpTestUnderfillMetricsComparable (Get-Prop $report.analysis "captureUnderfillMetrics" $null)
        bottomSeamComparable = Test-VpTestBottomSeamMetricsComparable (Get-Prop $report.analysis "captureBottomSeamMetrics" $null)
        typographyComparable = Test-VpTestTypographyMetricsComparable (Get-Prop $report.analysis "captureTypographyMetrics" $null)
        liveStatsComparable = Test-VpTestLiveStatsMetricsComparable (Get-Prop $report.analysis "captureLiveStatsMetrics" $null)
      }
    }

    if (-not $compareLocalhostEnabled -and $requireLocalhostCompare) {
      $localhostMissingReasonCode = "localhost-compare-disabled"
      $localhostMissingReason =
        "Der Localhost-Vergleich ist fuer babachess.com/bc-test verpflichtend, wurde aber deaktiviert und liefert deshalb keine eigenen Localhost-Artefakte."
      Write-VpTestLocalhostPlaceholderArtifacts `
        -capturePath $localhostCapturePath `
        -analysisReportPath $localhostAnalysisReportPath `
        -analysisSummaryPath $localhostAnalysisSummaryPath `
        -compareUrl $compareLocalhostUrl `
        -timestamp $timestamp `
        -reasonCode $localhostMissingReasonCode `
        -reasonMessage $localhostMissingReason
      $report.comparison.localhost = [ordered]@{
        target = "localhost"
        url = $compareLocalhostUrl
        bundleId = ""
        generatedAt = $timestamp
        status = "missing"
        verdict = "needs-attention"
        error = $localhostMissingReason
        reportPath = To-RelPath $localhostReportPath
        summaryPath = To-RelPath $localhostSummaryPath
        captureReportPath = To-RelPath $localhostCapturePath
        analysisReportPath = To-RelPath $localhostAnalysisReportPath
        analysisSummaryPath = To-RelPath $localhostAnalysisSummaryPath
        localExportPath = $null
        screenshotPath = ""
        routePathWithSearch = ""
        buildBundleScript = ""
        flaggedHeuristics = @($localhostMissingReasonCode)
        flaggedHeuristicSummaries = @($localhostMissingReason)
        captureHeuristics = @($localhostMissingReasonCode)
        warningSurface = $null
        underfillMetrics = $null
        bottomSeamMetrics = $null
        typographyMetrics = $null
        liveStatsMetrics = $null
        playRightRail = $null
        compareFlaggedHeuristics = @($localhostMissingReasonCode)
        compareCaptureHeuristics = @($localhostMissingReasonCode)
        suppressedCompareHeuristics = @()
        metricSupport = [ordered]@{
          underfillComparable = $false
          bottomSeamComparable = $false
          typographyComparable = $false
          liveStatsComparable = $false
        }
      }
      if ([string]$report.status -eq "ready") {
        $report.status = "needs-attention"
      }
    } elseif ($compareLocalhostEnabled) {
      $localhostDecisionCodes = @()
      if (-not $localhostCompareTimestamp) { $localhostCompareTimestamp = NowIso }
      if (-not $localhostCaptureLog) { $localhostCaptureLog = Join-Path $LogsRoot ("terminal\vp-test-localhost-capture-" + $ts + ".log") }
      if (-not $localhostAnalyzeLog) { $localhostAnalyzeLog = Join-Path $LogsRoot ("terminal\vp-test-localhost-analyze-" + $ts + ".log") }
      try {
        if ($localhostCompareJob) {
          $localhostJobResult = Receive-VpTestLocalhostCompareJob $localhostCompareJob
          $localhostCompareJob = $null
          $report.comparison.parallel.finishedAt = [string](Get-Prop $localhostJobResult "finishedAt" (NowIso))
          $report.comparison.parallel.jobStage = [string](Get-Prop $localhostJobResult "stage" "")
          $report.comparison.parallel.captureLog = To-RelPath $localhostCaptureLog
          $report.comparison.parallel.analyzeLog = To-RelPath $localhostAnalyzeLog
          if ([int](Get-Prop $localhostJobResult "exit" 1) -ne 0) {
            throw ([string](Get-Prop $localhostJobResult "error" "localhost compare job failed."))
          }
        } else {
          $localhostCaptureTimeoutMs = Get-VpTestCaptureTimeoutMs
          $localhostCaptureEnv = New-VpTestLocalhostCaptureEnv $report
          $localhostCaptureCmd = @(
            "node",
            (Quote-IfNeeded $captureToolPath),
            "--url", (Quote-IfNeeded $compareLocalhostUrl),
            "--out-json", (Quote-IfNeeded $localhostCapturePath),
            "--timeout-ms", $localhostCaptureTimeoutMs,
            "--local-export-root", (Quote-IfNeeded "logs/ops/vp-test/localhost")
          ) -join " "
          $localhostCapture = Run-Cmd $localhostCaptureCmd $localhostCaptureLog $localhostCaptureEnv
          if ($localhostCapture.exit -ne 0) { throw ("localhost compare capture failed. See " + $localhostCaptureLog) }
        }
        $localhostCapturePayload = Try-ReadJson $localhostCapturePath
        if ($null -eq $localhostCapturePayload) { throw "localhost compare capture report is unreadable." }
        $localhostBundleId = [string](Get-Prop $localhostCapturePayload "bundleId" "")
        if (-not $localhostBundleId) { throw "localhost compare capture did not return a bundleId." }
        $localhostUploadStatus = [string](Get-Prop $localhostCapturePayload "uploadStatus" "")
        $localhostFirstInputCaptured = [bool](Get-Prop $localhostCapturePayload "firstInputCaptured" $false)
        if (-not $localhostFirstInputCaptured) { throw "localhost compare capture finished without first-input evidence." }
        $localhostInputTraceLength = 0
        $localhostTappableTargetCount = 0
        try { $localhostInputTraceLength = [int](Get-Prop $localhostCapturePayload "inputTraceLength" 0) } catch { $localhostInputTraceLength = 0 }
        try { $localhostTappableTargetCount = [int](Get-Prop $localhostCapturePayload "tappableTargetCount" 0) } catch { $localhostTappableTargetCount = 0 }
        if ($localhostInputTraceLength -le 0) { throw "localhost compare capture finished without inputTrace evidence." }
        if ($localhostTappableTargetCount -le 0) { throw "localhost compare capture finished without tappableTargets evidence." }
        if ([string]$localhostUploadStatus -ne "local-exported") {
          throw ("localhost compare capture did not finish as local-exported (status=" + $localhostUploadStatus + ").")
        }
        $localhostExportPath = [string](Get-Prop $localhostCapturePayload "localExportPath" "")
        if (-not $localhostExportPath) { throw "localhost compare capture did not write a local export payload." }
        if (-not $report.comparison.parallel.enabled) {
          $localhostAnalysisInputPath = $localhostExportPath
          if (-not [System.IO.Path]::IsPathRooted($localhostAnalysisInputPath)) {
            $localhostAnalysisInputPath = Join-Path $RepoRoot $localhostAnalysisInputPath
          }
          $localhostAnalyzeCmd = @(
            "node",
            (Quote-IfNeeded $analyzeToolPath),
            "--input", (Quote-IfNeeded $localhostAnalysisInputPath),
            "--report", (Quote-IfNeeded $localhostAnalysisReportPath),
            "--summary", (Quote-IfNeeded $localhostAnalysisSummaryPath)
          ) -join " "
          $localhostAnalyze = Run-Cmd $localhostAnalyzeCmd $localhostAnalyzeLog
          if ($localhostAnalyze.exit -ne 0) { throw ("localhost compare analysis failed. See " + $localhostAnalyzeLog) }
        }
        $localhostAnalysis = Try-ReadJson $localhostAnalysisReportPath
        if ($null -eq $localhostAnalysis) { throw "localhost compare analysis report is unreadable." }
        $localhostCaptureMetrics = Get-Prop $localhostCapturePayload "movesPanelMetrics" $null
        $localhostAnalyzeCaptureMetrics = Get-Prop $localhostCapturePayload "analyzeRightRailMetrics" $null
        $localhostPlayCaptureMetrics = Get-Prop $localhostCapturePayload "playRightRailMetrics" $null
        $localhostTypographyMetrics = Get-Prop $localhostCapturePayload "railTypographyMetrics" $null
        $localhostLiveStatsMetrics = Get-Prop $localhostCapturePayload "liveStatsContractMetrics" $null
        $localhostRouteMarkers = Get-Prop $localhostCapturePayload "routeMarkers" $null
        $localhostBuildMarkers = Get-Prop $localhostCapturePayload "buildMarkers" $null
        $localhostCaptureDomains = Get-Prop $localhostCapturePayload "captureDomains" @()
        $localhostCaptureDomainSummary = Get-Prop $localhostCapturePayload "captureDomainSummary" $null
        $localhostWarningSurface = Get-VpTestWarningSurfaceSignal $localhostPlayCaptureMetrics $localhostCaptureMetrics
        $localhostCaptureFlags = @()

        if ($localhostCaptureMetrics) {
          $localhostMovesShare = $null
          $localhostLiveShare = $null
          $localhostVisibleMoveRows = $null
          $localhostRowBudget = $null
          $localhostLiveLabelFontPx = $null
          $localhostLiveLabelLineHeightPx = $null
          $localhostLiveCounterFontPx = $null
          $localhostLiveIconSizePx = $null
          $localhostLiveRowHeightPx = $null
          $localhostLiveBottomSlackPx = $null
          try { $localhostMovesShare = [double](Get-Prop $localhostCaptureMetrics "movesShareOfRail" $null) } catch { $localhostMovesShare = $null }
          try { $localhostLiveShare = [double](Get-Prop $localhostCaptureMetrics "liveShareOfRail" $null) } catch { $localhostLiveShare = $null }
          try { $localhostVisibleMoveRows = [int](Get-Prop $localhostCaptureMetrics "visibleMoveRows" $null) } catch { $localhostVisibleMoveRows = $null }
          try { $localhostRowBudget = [int](Get-Prop $localhostCaptureMetrics "rowBudget" $null) } catch { $localhostRowBudget = $null }
          try { $localhostLiveLabelFontPx = [double](Get-Prop $localhostCaptureMetrics "firstLiveRowLabelFontSizePx" $null) } catch { $localhostLiveLabelFontPx = $null }
          try { $localhostLiveLabelLineHeightPx = [double](Get-Prop $localhostCaptureMetrics "firstLiveRowLabelLineHeightPx" $null) } catch { $localhostLiveLabelLineHeightPx = $null }
          try { $localhostLiveCounterFontPx = [double](Get-Prop $localhostCaptureMetrics "firstLiveRowCounterFontSizePx" $null) } catch { $localhostLiveCounterFontPx = $null }
          try { $localhostLiveIconSizePx = [double](Get-Prop $localhostCaptureMetrics "firstLiveRowIconSizePx" $null) } catch { $localhostLiveIconSizePx = $null }
          try { $localhostLiveRowHeightPx = [double](Get-Prop $localhostCaptureMetrics "firstLiveRowHeightPx" $null) } catch { $localhostLiveRowHeightPx = $null }
          try { $localhostLiveBottomSlackPx = [double](Get-Prop $localhostCaptureMetrics "liveStatsBottomSlackPx" $null) } catch { $localhostLiveBottomSlackPx = $null }
          if (
            $null -ne $localhostMovesShare -and
            $null -ne $localhostLiveShare -and
            $null -ne $localhostVisibleMoveRows -and
            $null -ne $localhostRowBudget -and
            $localhostVisibleMoveRows -ge 8 -and
            $localhostRowBudget -ge 8 -and
            $localhostMovesShare -lt 0.35 -and
            ($localhostLiveShare - $localhostMovesShare) -gt 0.10
          ) {
            $localhostCaptureFlags += "play-moves-panel-underfill"
          }
          if (
            $expectCompactLiveStats -and (
              ($null -ne $localhostLiveLabelFontPx -and $localhostLiveLabelFontPx -gt 10.5) -or
              ($null -ne $localhostLiveLabelLineHeightPx -and $localhostLiveLabelLineHeightPx -gt 18.5) -or
              ($null -ne $localhostLiveCounterFontPx -and $localhostLiveCounterFontPx -gt 10.5) -or
              ($null -ne $localhostLiveIconSizePx -and $localhostLiveIconSizePx -gt 12.5) -or
              ($null -ne $localhostLiveRowHeightPx -and $localhostLiveRowHeightPx -gt 23.2) -or
              ($null -ne $localhostLiveBottomSlackPx -and $localhostLiveBottomSlackPx -gt 6)
            )
          ) {
            $localhostCaptureFlags += "play-live-stats-oversized"
          }
        }

        if ($effectiveExpectRightRailWarning -and ($localhostWarningSurface.contentVisible -ne $true)) {
          $localhostCaptureFlags += "warning-topslot-missing"
        }
        if ($localhostAnalyzeCaptureMetrics) {
          $localhostCaptureFlags += @(Get-VpTestAnalyzeRightRailCaptureHeuristics $localhostAnalyzeCaptureMetrics $localhostCaptureMetrics)
        }
        $localhostCaptureFlags = @($localhostCaptureFlags | Where-Object { $_ } | Select-Object -Unique)

        $localhostUnderfillMetrics = $null
        $localhostBottomSeamMetrics = $null
        if ($localhostAnalyzeCaptureMetrics) {
          $localhostAnalyzePanelUnusedPx = $null
          $localhostAnalyzeBodySlackPx = $null
          $localhostAnalyzeVisibleRowsByHeight = $null
          $localhostAnalyzeVisibleMoveRows = $null
          $localhostAnalyzeRowBudget = $null
          $localhostAnalyzeMovesToLiveGapPx = $null
          $localhostAnalyzeMoveListGridToLiveHeaderGapPx = $null
          $localhostAnalyzeMoveListLastVisibleRowToLiveHeaderGapPx = $null
          $localhostAnalyzeMoveListLastVisibleRowToLiveWrapperGapPx = $null
          $localhostAnalyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = $null
          $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondScrollPx = $null
          $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = $null
          try { $localhostAnalyzePanelUnusedPx = [double](Get-Prop $localhostCaptureMetrics "gridUnusedInScrollPx" $null) } catch { $localhostAnalyzePanelUnusedPx = $null }
          if ($null -eq $localhostAnalyzePanelUnusedPx) {
            try { $localhostAnalyzePanelUnusedPx = [double](Get-Prop $localhostAnalyzeCaptureMetrics "moveListBodyBottomSlackPx" $null) } catch { $localhostAnalyzePanelUnusedPx = $null }
          }
          try { $localhostAnalyzeBodySlackPx = [double](Get-Prop $localhostCaptureMetrics "movesPanelUnusedHeightPx" $null) } catch { $localhostAnalyzeBodySlackPx = $null }
          try { $localhostAnalyzeVisibleRowsByHeight = [int](Get-Prop $localhostAnalyzeCaptureMetrics "visibleRowsByHeight" $null) } catch { $localhostAnalyzeVisibleRowsByHeight = $null }
          try { $localhostAnalyzeVisibleMoveRows = [int](Get-Prop $localhostAnalyzeCaptureMetrics "visibleMoveRows" $null) } catch { $localhostAnalyzeVisibleMoveRows = $null }
          try { $localhostAnalyzeRowBudget = [int](Get-Prop $localhostAnalyzeCaptureMetrics "rowBudget" $null) } catch { $localhostAnalyzeRowBudget = $null }
          try { $localhostAnalyzeMovesToLiveGapPx = [double](Get-Prop $localhostAnalyzeCaptureMetrics "movesToLiveGapPx" $null) } catch { $localhostAnalyzeMovesToLiveGapPx = $null }
          $localhostAnalyzeMoveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListGridToLiveHeaderGapPx"
          if ($null -eq $localhostAnalyzeMoveListGridToLiveHeaderGapPx) {
            $localhostAnalyzeMoveListGridToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListGridToLiveHeaderGapPx"
          }
          $localhostAnalyzeMoveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListLastVisibleRowToLiveHeaderGapPx"
          if ($null -eq $localhostAnalyzeMoveListLastVisibleRowToLiveHeaderGapPx) {
            $localhostAnalyzeMoveListLastVisibleRowToLiveHeaderGapPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListLastVisibleRowToLiveHeaderGapPx"
          }
          $localhostAnalyzeMoveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListLastVisibleRowToLiveWrapperGapPx"
          if ($null -eq $localhostAnalyzeMoveListLastVisibleRowToLiveWrapperGapPx) {
            $localhostAnalyzeMoveListLastVisibleRowToLiveWrapperGapPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListLastVisibleRowToLiveWrapperGapPx"
          }
          $localhostAnalyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
          if ($null -eq $localhostAnalyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx) {
            $localhostAnalyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListLastVisibleRowOverlapIntoLiveHeaderPx"
          }
          $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListLastVisibleRowOverflowBeyondScrollPx"
          if ($null -eq $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondScrollPx) {
            $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondScrollPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListLastVisibleRowOverflowBeyondScrollPx"
          }
          $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $localhostAnalyzeCaptureMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
          if ($null -eq $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx) {
            $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx = Get-VpTestOptionalDoubleValue $localhostCaptureMetrics "moveListLastVisibleRowOverflowBeyondMovesPanelPx"
          }
          $localhostUnderfillMetrics = [ordered]@{
            panelUnusedPx = $localhostAnalyzePanelUnusedPx
            bodySlackPx = $localhostAnalyzeBodySlackPx
            visibleRowsByHeight = $localhostAnalyzeVisibleRowsByHeight
            visibleMoveRows = $localhostAnalyzeVisibleMoveRows
            rowBudget = $localhostAnalyzeRowBudget
            movesToLiveGapPx = $localhostAnalyzeMovesToLiveGapPx
          }
          $localhostBottomSeamMetrics = [ordered]@{
            moveListGridToLiveHeaderGapPx = $localhostAnalyzeMoveListGridToLiveHeaderGapPx
            moveListLastVisibleRowToLiveHeaderGapPx = $localhostAnalyzeMoveListLastVisibleRowToLiveHeaderGapPx
            moveListLastVisibleRowToLiveWrapperGapPx = $localhostAnalyzeMoveListLastVisibleRowToLiveWrapperGapPx
            moveListLastVisibleRowOverlapIntoLiveHeaderPx = $localhostAnalyzeMoveListLastVisibleRowOverlapIntoLiveHeaderPx
            moveListLastVisibleRowOverflowBeyondScrollPx = $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondScrollPx
            moveListLastVisibleRowOverflowBeyondMovesPanelPx = $localhostAnalyzeMoveListLastVisibleRowOverflowBeyondMovesPanelPx
            movesToLiveGapPx = $localhostAnalyzeMovesToLiveGapPx
          }
        }

        $localhostFlaggedHeuristics = @()
        $localhostFlaggedHeuristics += @(Get-VpTestFlaggedHeuristicIds $localhostAnalysis)
        $localhostFlaggedHeuristics += @($localhostCaptureFlags)
        $localhostFlaggedHeuristics = @($localhostFlaggedHeuristics | Where-Object { $_ } | Select-Object -Unique)
        $localhostFlaggedHeuristicSummaries = @(
          @($localhostAnalysis.heuristics) |
            Where-Object { [string](Get-Prop $_ "status" "") -eq "flag" } |
            ForEach-Object {
              $id = [string](Get-Prop $_ "id" "")
              $summaryText = [string](Get-Prop $_ "summary" "")
              if ($id -and $summaryText) { "${id}: $summaryText" } elseif ($id) { $id } elseif ($summaryText) { $summaryText }
            } |
            Where-Object { $_ }
        )
        $localhostAnalysisVerdict = [string](Get-Prop $localhostAnalysis "verdict" "")
        if (-not $localhostAnalysisVerdict) { $localhostAnalysisVerdict = "needs-attention" }
        if ($localhostAnalysisVerdict -eq "ready" -and @($localhostCaptureFlags).Count -gt 0) {
          $localhostAnalysisVerdict = "needs-attention"
        }
        if ($localhostAnalysisVerdict -eq "insufficient-data") {
          $localhostAnalysisVerdict = "needs-attention"
          $localhostDecisionCodes += "localhost-insufficient-data"
        }
        $localhostStatus = $(if ($localhostAnalysisVerdict -eq "ready") { "ready" } else { "needs-attention" })
        $localhostRoutePathWithSearch = [string](Get-Prop $localhostRouteMarkers "pathWithSearch" "")
        if (-not $localhostRoutePathWithSearch) {
          $localhostRoutePathWithSearch = ([string](Get-Prop $localhostRouteMarkers "pathname" "") + [string](Get-Prop $localhostRouteMarkers "search" ""))
        }
        $localhostPlayAssessment = Get-VpTestPlayRightRailCaptureAssessment $localhostPlayCaptureMetrics
        $report.comparison.localhost = [ordered]@{
          target = "localhost"
          url = $compareLocalhostUrl
          bundleId = $localhostBundleId
          generatedAt = $localhostCompareTimestamp
          status = $localhostStatus
          verdict = $localhostAnalysisVerdict
          error = $null
          reportPath = To-RelPath $localhostReportPath
          summaryPath = To-RelPath $localhostSummaryPath
          captureReportPath = To-RelPath $localhostCapturePath
          analysisReportPath = To-RelPath $localhostAnalysisReportPath
          analysisSummaryPath = To-RelPath $localhostAnalysisSummaryPath
          localExportPath = $localhostExportPath
          screenshotPath = [string](Get-Prop (Get-Prop $localhostAnalysis "inputs" $null) "screenshotPath" "")
          routePathWithSearch = $localhostRoutePathWithSearch
          buildBundleScript = [string](Get-Prop $localhostBuildMarkers "bundleScriptSrc" "")
          flaggedHeuristics = @($localhostFlaggedHeuristics)
          flaggedHeuristicSummaries = @($localhostFlaggedHeuristicSummaries)
          captureHeuristics = @($localhostCaptureFlags)
          warningSurface = $localhostWarningSurface
          underfillMetrics = $localhostUnderfillMetrics
          bottomSeamMetrics = $localhostBottomSeamMetrics
          typographyMetrics = $localhostTypographyMetrics
          liveStatsMetrics = $localhostLiveStatsMetrics
          captureDomains = $localhostCaptureDomains
          captureDomainSummary = $localhostCaptureDomainSummary
          playRightRail = $localhostPlayAssessment
        }

        $compareSuppression = Get-VpTestCompareSuppressionContract $report.comparison.bcTest $report.comparison.localhost
        $compareSuppressedHeuristics = @((Get-Prop $compareSuppression "suppressedHeuristics" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique)
        $report.comparison.suppressedHeuristics = @($compareSuppressedHeuristics)
        $report.comparison.suppressedHeuristicDetails = @((Get-Prop $compareSuppression "details" @()))
        $report.comparison.metricSupport = Get-Prop $compareSuppression "support" $null
        $report.comparison.metricSupportDifferences = @(Get-VpTestMetricSupportDifferences $report.comparison.metricSupport)
        $metricSupportDifferenceSummary = $(if (@($report.comparison.metricSupportDifferences).Count -gt 0) {
            " Metric-Support-Differenz: " + (@($report.comparison.metricSupportDifferences) -join ", ") + "."
          } else {
            ""
          })

        $bcStatus = [string](Get-Prop $report.comparison.bcTest "status" "")
        if ($bcStatus -eq "ready" -and $localhostStatus -ne "ready") {
          $localhostDecisionCodes += "localhost-needs-attention-bctest-ready"
        } elseif ($bcStatus -ne "ready" -and $localhostStatus -eq "ready") {
          $localhostDecisionCodes += "localhost-ready-bctest-needs-attention"
        } elseif ($bcStatus -ne $localhostStatus) {
          $localhostDecisionCodes += "localhost-bctest-status-drift"
        }

        $bcCaptureHeuristics = @(@(Get-Prop $report.analysis "captureHeuristics" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Sort-Object -Unique)
        $localhostSortedCaptureHeuristics = @(@($localhostCaptureFlags) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Sort-Object -Unique)
        $effectiveBcCaptureHeuristics = @(@(Get-VpTestCompareEffectiveHeuristics $bcCaptureHeuristics $compareSuppressedHeuristics) | Sort-Object -Unique)
        $effectiveLocalhostCaptureHeuristics = @(@(Get-VpTestCompareEffectiveHeuristics $localhostSortedCaptureHeuristics $compareSuppressedHeuristics) | Sort-Object -Unique)
        $report.comparison.bcTest.compareCaptureHeuristics = @($effectiveBcCaptureHeuristics)
        $report.comparison.localhost.compareCaptureHeuristics = @($effectiveLocalhostCaptureHeuristics)
        $report.comparison.bcTest.suppressedCompareHeuristics = @($compareSuppressedHeuristics)
        $report.comparison.localhost.suppressedCompareHeuristics = @($compareSuppressedHeuristics)
        $report.comparison.bcTest.metricSupport = Get-Prop (Get-Prop $report.comparison "metricSupport" $null) "bcTest" $null
        $report.comparison.localhost.metricSupport = Get-Prop (Get-Prop $report.comparison "metricSupport" $null) "localhost" $null
        if ((@($effectiveBcCaptureHeuristics) -join ",") -ne (@($effectiveLocalhostCaptureHeuristics) -join ",")) {
          $localhostDecisionCodes += "capture-heuristics-drift"
        }

        $bcFlaggedHeuristics = @(@(Get-Prop $report.analysis "flaggedHeuristics" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Sort-Object -Unique)
        $localhostSortedFlaggedHeuristics = @(@($localhostFlaggedHeuristics) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Sort-Object -Unique)
        $effectiveBcFlaggedHeuristics = @(@(Get-VpTestCompareEffectiveHeuristics $bcFlaggedHeuristics $compareSuppressedHeuristics) | Sort-Object -Unique)
        $effectiveLocalhostFlaggedHeuristics = @(@(Get-VpTestCompareEffectiveHeuristics $localhostSortedFlaggedHeuristics $compareSuppressedHeuristics) | Sort-Object -Unique)
        $report.comparison.bcTest.compareFlaggedHeuristics = @($effectiveBcFlaggedHeuristics)
        $report.comparison.localhost.compareFlaggedHeuristics = @($effectiveLocalhostFlaggedHeuristics)
        if ((@($effectiveBcFlaggedHeuristics) -join ",") -ne (@($effectiveLocalhostFlaggedHeuristics) -join ",")) {
          $localhostDecisionCodes += "analysis-heuristics-drift"
        }

        $bcWarningState = [string](Get-Prop $warningSurface "state" "")
        $bcWarningKey = [string](Get-Prop $warningSurface "key" "")
        $bcWarningVisible = [string](Get-Prop $warningSurface "visible" $null)
        $localhostWarningState = [string](Get-Prop $localhostWarningSurface "state" "")
        $localhostWarningKey = [string](Get-Prop $localhostWarningSurface "key" "")
        $localhostWarningVisible = [string](Get-Prop $localhostWarningSurface "visible" $null)
        if (($bcWarningState -ne $localhostWarningState) -or ($bcWarningKey -ne $localhostWarningKey) -or ($bcWarningVisible -ne $localhostWarningVisible)) {
          $localhostDecisionCodes += "warning-surface-contract-drift"
        }

        if ((@($localhostDecisionCodes).Count -eq 0) -and $bcStatus -and $bcStatus -eq $localhostStatus) {
          $report.comparison.status = "ready"
          $report.comparison.summary =
            "Localhost und bc-test liefern denselben vp-test-Status ohne erkennbare Contract-Drift." + $metricSupportDifferenceSummary
        } else {
          $report.comparison.status = "needs-attention"
          $report.comparison.summary =
            "Localhost und bc-test driften fuer den aktiven vp-test-Vertrag auseinander; ein False-Green darf nicht als Resume-Status stehen bleiben." + $metricSupportDifferenceSummary
          if ([string]$report.status -eq "ready") {
            $report.status = "needs-attention"
          }
        }
        $report.comparison.decisionCodes = @($localhostDecisionCodes | Where-Object { $_ } | Select-Object -Unique)
      } catch {
        $localhostFailedReasonCode = "localhost-compare-failed"
        $localhostFailedReason = [string]$_.Exception.Message
        Write-VpTestLocalhostPlaceholderArtifacts `
          -capturePath $localhostCapturePath `
          -analysisReportPath $localhostAnalysisReportPath `
          -analysisSummaryPath $localhostAnalysisSummaryPath `
          -compareUrl $compareLocalhostUrl `
          -timestamp $localhostCompareTimestamp `
          -reasonCode $localhostFailedReasonCode `
          -reasonMessage $localhostFailedReason
        $report.comparison.status = "needs-attention"
        $report.comparison.decisionCodes = @($localhostFailedReasonCode)
        $report.comparison.summary =
          "Der Localhost-Vergleich ist fehlgeschlagen; ein bc-test-Gruen darf deshalb nicht als ausreichender Resume-Pfad gelten."
        $report.comparison.localhost = [ordered]@{
          target = "localhost"
          url = $compareLocalhostUrl
          generatedAt = $localhostCompareTimestamp
          status = "fail"
          verdict = "needs-attention"
          error = $localhostFailedReason
          reportPath = To-RelPath $localhostReportPath
          summaryPath = To-RelPath $localhostSummaryPath
          captureReportPath = To-RelPath $localhostCapturePath
          analysisReportPath = To-RelPath $localhostAnalysisReportPath
          analysisSummaryPath = To-RelPath $localhostAnalysisSummaryPath
          localExportPath = $null
          screenshotPath = ""
          routePathWithSearch = ""
          buildBundleScript = ""
          flaggedHeuristics = @()
          flaggedHeuristicSummaries = @()
          captureHeuristics = @()
          warningSurface = $null
          underfillMetrics = $null
          bottomSeamMetrics = $null
          playRightRail = $null
        }
        if ([string]$report.status -eq "ready") {
          $report.status = "needs-attention"
        }
      }
    }
  } catch {
    if ($localhostCompareJob) {
      try { Stop-Job -Job $localhostCompareJob -Force -ErrorAction SilentlyContinue } catch { $null = $_ }
      try { Remove-Job -Job $localhostCompareJob -Force -ErrorAction SilentlyContinue } catch { $null = $_ }
      $localhostCompareJob = $null
    }
    $report.status = "fail"
    $report.error = [string]$_.Exception.Message
    Write-Json $reportPath $report
    $summaryFail = @(
      "# VP Test",
      "",
      "- Generated: " + $timestamp,
      "- Status: fail",
      "- Target: " + $uploadBaseUrl,
      "- Lookup mode: " + [string]$report.bundleLookup.mode,
      "- BundleId: " + ($(if ($bundleId) { $bundleId } else { "(none)" })),
      "- Analysis verdict: " + [string]$report.analysis.verdict,
      "- Flagged heuristics: " + ($(if (@($report.analysis.flaggedHeuristics).Count -gt 0) { (@($report.analysis.flaggedHeuristics) -join ", ") } else { "none" })),
      "- Flagged heuristic details: " + ($(if (@($report.analysis.flaggedHeuristicSummaries).Count -gt 0) { (@($report.analysis.flaggedHeuristicSummaries) -join " | ") } else { "none" })),
      "- Blocking heuristics: " + ($(if (@($report.analysis.blockingHeuristics).Count -gt 0) { (@($report.analysis.blockingHeuristics) -join ", ") } else { "none" })),
      "- Deadlock signatures: " + ($(if (@($report.analysis.deadlockSignatures).Count -gt 0) { (@($report.analysis.deadlockSignatures) -join ", ") } else { "none" })),
      "- Error: " + $report.error
    ) -join "`r`n"
    Atomic-WriteTextUtf8 $summaryPath ($summaryFail + "`r`n")
    throw
  }

  Write-Json $reportPath $report
  $pathReconciliation = Get-Prop $report "pathReconciliation" $null
  $currentTarget = Get-Prop $pathReconciliation "currentTarget" $null
  $routeMarkers = Get-Prop $currentTarget "routeMarkers" $null
  $buildMarkers = Get-Prop $currentTarget "buildMarkers" $null
  $playAssessment = Get-Prop $currentTarget "playRightRail" $null
  $preCaptureSetup = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "preCaptureSetup" $null
  $feedback = Get-Prop (Get-Prop $report.bundleLookup "capture" $null) "feedback" $null
  $comparison = Get-Prop $report "comparison" $null
  $comparisonBcTest = Get-Prop $comparison "bcTest" $null
  $comparisonLocalhost = Get-Prop $comparison "localhost" $null
  $comparisonStatus = [string](Get-Prop $comparison "status" "")
  $comparisonSummary = [string](Get-Prop $comparison "summary" "")
  $comparisonDecisionCodes = @(
    @((Get-Prop $comparison "decisionCodes" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ } |
      Select-Object -Unique
  )
  $routePathWithSearch = [string](Get-Prop $routeMarkers "pathWithSearch" "")
  if (-not $routePathWithSearch) {
    $routePathWithSearch = ([string](Get-Prop $routeMarkers "pathname" "") + [string](Get-Prop $routeMarkers "search" ""))
  }
  $captureRouteMarker = if ($routePathWithSearch) {
    $routePathWithSearch +
      " | bc-test=" + [string](Get-Prop $routeMarkers "isBcTestPath" $null) +
      " | autodebug=" + [string](Get-Prop $routeMarkers "hasAutodebug" $null) +
      " | testhooks=" + [string](Get-Prop $routeMarkers "hasTesthooks" $null)
  } else {
    "(missing)"
  }
  $bundleScriptSrc = [string](Get-Prop $buildMarkers "bundleScriptSrc" "")
  $bundleVersion = [string](Get-Prop $buildMarkers "bundleVersion" "")
  $captureBuildMarker = if ($bundleScriptSrc) {
    $bundleScriptSrc + $(if ($bundleVersion) { " | v=" + $bundleVersion } else { "" })
  } else {
    "(missing)"
  }
  $preCaptureRequested = Get-Prop $preCaptureSetup "requested" $null
  $preCaptureApplied = Get-Prop $preCaptureSetup "applied" $null
  $preCaptureState = Get-Prop $preCaptureSetup "state" $null
  $lookupSelection = Get-Prop $report.bundleLookup "selection" $null
  $selectedLookupCandidate = Get-Prop $report.bundleLookup "selectedCandidate" $null
  $rawLatestLookupCandidate = Get-Prop $report.bundleLookup "rawLatestCandidate" $null
  $latestPlayLookupCandidate = Get-Prop $report.bundleLookup "latestPlayCandidate" $null
  $latestAnalyzeLookupCandidate = Get-Prop $report.bundleLookup "latestAnalyzeCandidate" $null
  $seededPlayLookupCandidate = Get-Prop $report.bundleLookup "seededPlayCandidate" $null
  $warningSurface = Get-Prop $report.analysis "warningSurface" $null
  $lookupDecisionCodes = @(
    @((Get-Prop $lookupSelection "decisionCodes" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ } |
      Select-Object -Unique
  )
  $pathDecisionCodes = @(
    @((Get-Prop $pathReconciliation "decisionCodes" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ } |
      Select-Object -Unique
  )
  $preCaptureSummary = if ($preCaptureSetup) {
    "mode=" + [string](Get-Prop $preCaptureRequested "mode" "") +
      " | compactRail=" + [string](Get-Prop $preCaptureRequested "compactRailTarget" "") +
      " | requestedSeedMoves=" + [string](Get-Prop $preCaptureRequested "seedMoveCount" $null) +
      " | appliedSeedMoves=" + [string](Get-Prop $preCaptureApplied "seededMoves" $null) +
      " | ready=" + [string](Get-Prop $preCaptureState "ready" $null) +
      " | rewroteToBcTest=" + [string](Get-Prop $preCaptureState "rewroteToBcTest" $null) +
      " | screenOrientation=" + [string](Get-Prop (Get-Prop $preCaptureRequested "context" $null) "screenOrientation" "")
  } else {
    "(none)"
  }
  $feedbackSummary = if ($feedback) {
    "enabled=" + [string](Get-Prop $feedback "enabled" $null) +
      " | visited=" + [string](Get-Prop $feedback "visited" $null) +
      " | withoutParamsUrl=" + $(if ([string](Get-Prop $feedback "withoutParamsUrl" "")) { [string](Get-Prop $feedback "withoutParamsUrl" "") } else { "(none)" }) +
      " | bundleId=" + $(if ([string](Get-Prop (Get-Prop $feedback "state" $null) "bundleId" "")) { [string](Get-Prop (Get-Prop $feedback "state" $null) "bundleId" "") } else { "(empty)" }) +
      " | uploadStatus=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "bundleUploadStatus" "") +
      " | queryMode=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "queryMode" "") +
      " | autodebug=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "hasAutodebug" $null) +
      " | testhooks=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "hasTesthooks" $null) +
      " | manualVisible=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "manualTriggerVisible" $null) +
      " | triggerKind=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "triggerKind" "") +
      " | toastVisible=" + [string](Get-Prop (Get-Prop $feedback "state" $null) "toastVisible" $null) +
      " | toastTitle=" + $(if ([string](Get-Prop (Get-Prop $feedback "state" $null) "toastTitle" "")) { [string](Get-Prop (Get-Prop $feedback "state" $null) "toastTitle" "") } else { "(empty)" })
  } else {
    "(none)"
  }
  $lookupSelectionSummary = if ($lookupSelection) {
    "mode=" + [string](Get-Prop $report.bundleLookup "mode" "") +
      " | selected=" + [string](Get-Prop $report.bundleLookup "bundleId" "") +
      " | latestRaw=" + [string](Get-Prop $lookupSelection "latestRawBundleId" "") +
      " | playCandidates=" + [string](Get-Prop $lookupSelection "playCandidateCount" "") +
      " | analyzeCandidates=" + [string](Get-Prop $lookupSelection "analyzeCandidateCount" "") +
      $(if ([string](Get-Prop $lookupSelection "seededPlayBundleId" "")) { " | seededPlay=" + [string](Get-Prop $lookupSelection "seededPlayBundleId" "") } else { "" }) +
      $(if (@($lookupDecisionCodes).Count -gt 0) { " | codes=" + (@($lookupDecisionCodes) -join ",") } else { "" }) +
      $(if ([string](Get-Prop $lookupSelection "selectedReason" "")) { " | reason=" + [string](Get-Prop $lookupSelection "selectedReason" "") } else { "" })
  } else {
    [string](Get-Prop $report.bundleLookup "mode" "")
  }
  $playStatus = [string](Get-Prop $playAssessment "status" "")
  $playDetail = Format-VpTestPlayRightRailDetail $playAssessment
  $captureUnderfillMetrics = Get-Prop $report.analysis "captureUnderfillMetrics" $null
  $captureUnderfillSummary = Format-VpTestUnderfillMetricsSummary $captureUnderfillMetrics
  $captureBottomSeamMetrics = Get-Prop $report.analysis "captureBottomSeamMetrics" $null
  $captureBottomSeamSummary = Format-VpTestBottomSeamMetricsSummary $captureBottomSeamMetrics
  $captureTypographyMetrics = Get-Prop $report.analysis "captureTypographyMetrics" $null
  $captureTypographySummary = Format-VpTestTypographyMetricsSummary $captureTypographyMetrics
  $captureLiveStatsMetrics = Get-Prop $report.analysis "captureLiveStatsMetrics" $null
  $captureLiveStatsSummary = Format-VpTestLiveStatsMetricsSummary $captureLiveStatsMetrics
  $warningSurfaceSummary = Format-VpTestWarningSurfaceSummary $warningSurface
  $comparisonSuppressedHeuristics = @(@(Get-Prop $comparison "suppressedHeuristics" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ } | Select-Object -Unique)
  $comparisonSuppressedDetails = Format-VpTestSuppressedHeuristicDetails (Get-Prop $comparison "suppressedHeuristicDetails" @())
  $comparisonMetricSupport = Get-Prop $comparison "metricSupport" $null
  $comparisonMetricSupportDifferences = @(
    @((Get-Prop $comparison "metricSupportDifferences" @())) |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ } |
      Select-Object -Unique
  )
  $bcTestTargetSummary = if ($comparisonBcTest) {
    "status=" + [string](Get-Prop $comparisonBcTest "status" "") +
      " | bundle=" + [string](Get-Prop $comparisonBcTest "bundleId" "") +
      " | verdict=" + [string](Get-Prop $comparisonBcTest "verdict" "") +
      " | route=" + $(if ([string](Get-Prop $comparisonBcTest "routePathWithSearch" "")) { [string](Get-Prop $comparisonBcTest "routePathWithSearch" "") } else { "(missing)" }) +
      " | screenshot=" + $(if ([string](Get-Prop $comparisonBcTest "screenshotPath" "")) { [string](Get-Prop $comparisonBcTest "screenshotPath" "") } else { "(missing)" })
  } else {
    "(missing)"
  }
  $localhostTargetSummary = if ($comparisonLocalhost) {
    "status=" + [string](Get-Prop $comparisonLocalhost "status" "") +
      " | bundle=" + $(if ([string](Get-Prop $comparisonLocalhost "bundleId" "")) { [string](Get-Prop $comparisonLocalhost "bundleId" "") } else { "(none)" }) +
      " | verdict=" + [string](Get-Prop $comparisonLocalhost "verdict" "") +
      " | route=" + $(if ([string](Get-Prop $comparisonLocalhost "routePathWithSearch" "")) { [string](Get-Prop $comparisonLocalhost "routePathWithSearch" "") } else { "(missing)" }) +
      " | screenshot=" + $(if ([string](Get-Prop $comparisonLocalhost "screenshotPath" "")) { [string](Get-Prop $comparisonLocalhost "screenshotPath" "") } else { "(missing)" }) +
      $(if ([string](Get-Prop $comparisonLocalhost "error" "")) { " | error=" + [string](Get-Prop $comparisonLocalhost "error" "") } else { "" })
  } else {
    "(missing)"
  }
  $captureDomainSummary = Get-Prop $report.analysis "captureDomains" $null
  $captureDomainCaptured = @((Get-Prop $captureDomainSummary "captured" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
  $captureDomainMissing = @((Get-Prop $captureDomainSummary "missing" @()) | ForEach-Object { [string]$_ } | Where-Object { $_ })
  $captureDomainCapturedText = $(if (@($captureDomainCaptured).Count -gt 0) { (@($captureDomainCaptured) -join ", ") } else { "none" })
  $captureDomainMissingText = $(if (@($captureDomainMissing).Count -gt 0) { (@($captureDomainMissing) -join ", ") } else { "none" })
  $summary = @(
    "# VP Test",
    "",
    "- Generated: " + $timestamp,
    "- Status: " + [string]$report.status,
    "- Target: " + $uploadBaseUrl,
    "- Lookup mode: " + [string]$report.bundleLookup.mode,
    "- BundleId: " + $bundleId,
    "- Lookup selection: " + $lookupSelectionSummary,
    "- Lookup decision codes: " + ($(if (@($lookupDecisionCodes).Count -gt 0) { (@($lookupDecisionCodes) -join ", ") } else { "none" })),
    "- Selected lookup candidate: " + (Format-VpTestLookupCandidateSummary $selectedLookupCandidate),
    "- Latest raw Umami candidate: " + (Format-VpTestLookupCandidateSummary $rawLatestLookupCandidate),
    "- Latest play candidate: " + (Format-VpTestLookupCandidateSummary $latestPlayLookupCandidate),
    "- Latest analyze candidate: " + (Format-VpTestLookupCandidateSummary $latestAnalyzeLookupCandidate),
    "- Seeded play candidate: " + (Format-VpTestLookupCandidateSummary $seededPlayLookupCandidate),
    "- Analysis verdict: " + [string]$report.analysis.verdict,
    "- Flagged heuristics: " + ($(if (@($report.analysis.flaggedHeuristics).Count -gt 0) { (@($report.analysis.flaggedHeuristics) -join ", ") } else { "none" })),
    "- Flagged heuristic details: " + ($(if (@($report.analysis.flaggedHeuristicSummaries).Count -gt 0) { (@($report.analysis.flaggedHeuristicSummaries) -join " | ") } else { "none" })),
    "- Blocking heuristics: " + ($(if (@($report.analysis.blockingHeuristics).Count -gt 0) { (@($report.analysis.blockingHeuristics) -join ", ") } else { "none" })),
    "- Deadlock signatures: " + ($(if (@($report.analysis.deadlockSignatures).Count -gt 0) { (@($report.analysis.deadlockSignatures) -join ", ") } else { "none" })),
    "- Capture route marker: " + $captureRouteMarker,
    "- Capture build marker: " + $captureBuildMarker,
    "- Capture domains: captured=" + $captureDomainCapturedText + "; missing=" + $captureDomainMissingText,
    "- Capture setup: " + $preCaptureSummary,
    "- Capture feedback: " + $feedbackSummary,
    "- Analyze underfill detail: " + $captureUnderfillSummary,
    "- Analyze bottom seam detail: " + $captureBottomSeamSummary,
    "- Rail typography detail: " + $captureTypographySummary,
    "- LIVE-STATS detail: " + $captureLiveStatsSummary,
    "- Warning surface: " + $warningSurfaceSummary,
    "- Play-Right-Rail reconciliation: " + [string](Get-Prop $playAssessment "summary" "(missing)"),
    "- Play-Right-Rail detail: " + $playDetail,
    "- Path decision codes: " + ($(if (@($pathDecisionCodes).Count -gt 0) { (@($pathDecisionCodes) -join ", ") } else { "none" })),
    "- Path conclusion: " + [string](Get-Prop $pathReconciliation "conclusion" "(missing)"),
    "- Compare localhost: " + [string](Get-Prop $comparison "enabled" $false),
    "- Compare status: " + $(if ($comparisonStatus) { $comparisonStatus } else { "off" }),
    "- Compare decision codes: " + ($(if (@($comparisonDecisionCodes).Count -gt 0) { (@($comparisonDecisionCodes) -join ", ") } else { "none" })),
    "- Compare suppressed heuristics: " + ($(if (@($comparisonSuppressedHeuristics).Count -gt 0) { (@($comparisonSuppressedHeuristics) -join ", ") } else { "none" })),
    "- Compare suppression detail: " + $comparisonSuppressedDetails,
    "- Compare metric support: " + (Format-VpTestCompareMetricSupportSummary $comparisonMetricSupport),
    "- Compare metric support drift: " + ($(if (@($comparisonMetricSupportDifferences).Count -gt 0) { (@($comparisonMetricSupportDifferences) -join ", ") } else { "none" })),
    "- Compare summary: " + $(if ($comparisonSummary) { $comparisonSummary } else { "(none)" }),
    "- BC-Test target: " + $bcTestTargetSummary,
    "- Localhost target: " + $localhostTargetSummary,
    "- Screenshot: " + [string](Get-Prop (Get-Prop $analysis "inputs" $null) "screenshotPath" ""),
    "- Analysis report: logs/ops/ops-303-codex-bundle-analysis-report.json",
    "- Analysis summary: logs/ops/ops-303-codex-bundle-analysis-summary.md"
  ) -join "`r`n"
  Atomic-WriteTextUtf8 $summaryPath ($summary + "`r`n")

  if ($comparisonBcTest) {
    $bcTestTargetReport = [ordered]@{
      tool = "vp-test-target"
      generatedAt = $timestamp
      target = "bc-test"
      url = [string](Get-Prop $comparisonBcTest "url" "")
      bundleId = [string](Get-Prop $comparisonBcTest "bundleId" "")
      status = [string](Get-Prop $comparisonBcTest "status" "")
      verdict = [string](Get-Prop $comparisonBcTest "verdict" "")
      routePathWithSearch = [string](Get-Prop $comparisonBcTest "routePathWithSearch" "")
      buildBundleScript = [string](Get-Prop $comparisonBcTest "buildBundleScript" "")
      captureReportPath = [string](Get-Prop $comparisonBcTest "captureReportPath" "")
      analysisReportPath = [string](Get-Prop $comparisonBcTest "analysisReportPath" "")
      analysisSummaryPath = [string](Get-Prop $comparisonBcTest "analysisSummaryPath" "")
      screenshotPath = [string](Get-Prop $comparisonBcTest "screenshotPath" "")
      flaggedHeuristics = @((Get-Prop $comparisonBcTest "flaggedHeuristics" @()))
      flaggedHeuristicSummaries = @((Get-Prop $comparisonBcTest "flaggedHeuristicSummaries" @()))
      captureHeuristics = @((Get-Prop $comparisonBcTest "captureHeuristics" @()))
      compareFlaggedHeuristics = @((Get-Prop $comparisonBcTest "compareFlaggedHeuristics" @()))
      compareCaptureHeuristics = @((Get-Prop $comparisonBcTest "compareCaptureHeuristics" @()))
      suppressedCompareHeuristics = @((Get-Prop $comparisonBcTest "suppressedCompareHeuristics" @()))
      decisionCodes = @((Get-Prop $comparisonBcTest "decisionCodes" @()))
      warningSurface = Get-Prop $comparisonBcTest "warningSurface" $null
      underfillMetrics = Get-Prop $comparisonBcTest "underfillMetrics" $null
      bottomSeamMetrics = Get-Prop $comparisonBcTest "bottomSeamMetrics" $null
      typographyMetrics = Get-Prop $comparisonBcTest "typographyMetrics" $null
      liveStatsMetrics = Get-Prop $comparisonBcTest "liveStatsMetrics" $null
      metricSupport = Get-Prop $comparisonBcTest "metricSupport" $null
    }
    Write-Json $bcTestReportPath $bcTestTargetReport
    $bcTestTargetSummaryLines = @(
      "# VP Test Target",
      "",
      "- Generated: " + $timestamp,
      "- Target: bc-test",
      "- URL: " + [string](Get-Prop $comparisonBcTest "url" ""),
      "- Status: " + [string](Get-Prop $comparisonBcTest "status" ""),
      "- BundleId: " + [string](Get-Prop $comparisonBcTest "bundleId" ""),
      "- Verdict: " + [string](Get-Prop $comparisonBcTest "verdict" ""),
      "- Route: " + $(if ([string](Get-Prop $comparisonBcTest "routePathWithSearch" "")) { [string](Get-Prop $comparisonBcTest "routePathWithSearch" "") } else { "(missing)" }),
      "- Build: " + $(if ([string](Get-Prop $comparisonBcTest "buildBundleScript" "")) { [string](Get-Prop $comparisonBcTest "buildBundleScript" "") } else { "(missing)" }),
      "- Capture report: " + $(if ([string](Get-Prop $comparisonBcTest "captureReportPath" "")) { [string](Get-Prop $comparisonBcTest "captureReportPath" "") } else { "(missing)" }),
      "- Analysis report: " + [string](Get-Prop $comparisonBcTest "analysisReportPath" ""),
      "- Analysis summary: " + [string](Get-Prop $comparisonBcTest "analysisSummaryPath" ""),
      "- Screenshot: " + $(if ([string](Get-Prop $comparisonBcTest "screenshotPath" "")) { [string](Get-Prop $comparisonBcTest "screenshotPath" "") } else { "(missing)" }),
      "- Flagged heuristics: " + ($(if (@((Get-Prop $comparisonBcTest "flaggedHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "flaggedHeuristics" @())) -join ", ") } else { "none" })),
      "- Compare heuristics: " + ($(if (@((Get-Prop $comparisonBcTest "compareFlaggedHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "compareFlaggedHeuristics" @())) -join ", ") } else { "none" })),
      "- Flagged heuristic details: " + ($(if (@((Get-Prop $comparisonBcTest "flaggedHeuristicSummaries" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "flaggedHeuristicSummaries" @())) -join " | ") } else { "none" })),
      "- Capture heuristics: " + ($(if (@((Get-Prop $comparisonBcTest "captureHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "captureHeuristics" @())) -join ", ") } else { "none" })),
      "- Compare capture heuristics: " + ($(if (@((Get-Prop $comparisonBcTest "compareCaptureHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "compareCaptureHeuristics" @())) -join ", ") } else { "none" })),
      "- Suppressed compare heuristics: " + ($(if (@((Get-Prop $comparisonBcTest "suppressedCompareHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "suppressedCompareHeuristics" @())) -join ", ") } else { "none" })),
      "- Metric support: " + (Format-VpTestMetricSupportSummary (Get-Prop $comparisonBcTest "metricSupport" $null)),
      "- Decision codes: " + ($(if (@((Get-Prop $comparisonBcTest "decisionCodes" @())).Count -gt 0) { (@((Get-Prop $comparisonBcTest "decisionCodes" @())) -join ", ") } else { "none" })),
      "- Warning surface: " + (Format-VpTestWarningSurfaceSummary (Get-Prop $comparisonBcTest "warningSurface" $null)),
      "- Analyze underfill detail: " + (Format-VpTestUnderfillMetricsSummary (Get-Prop $comparisonBcTest "underfillMetrics" $null)),
      "- Analyze bottom seam detail: " + (Format-VpTestBottomSeamMetricsSummary (Get-Prop $comparisonBcTest "bottomSeamMetrics" $null)),
      "- Rail typography detail: " + (Format-VpTestTypographyMetricsSummary (Get-Prop $comparisonBcTest "typographyMetrics" $null)),
      "- LIVE-STATS detail: " + (Format-VpTestLiveStatsMetricsSummary (Get-Prop $comparisonBcTest "liveStatsMetrics" $null))
    ) -join "`r`n"
    Atomic-WriteTextUtf8 $bcTestSummaryPath ($bcTestTargetSummaryLines + "`r`n")
  }

  if ($comparisonLocalhost) {
    $localhostTargetReport = [ordered]@{
      tool = "vp-test-target"
      generatedAt = [string](Get-Prop $comparisonLocalhost "generatedAt" $timestamp)
      target = "localhost"
      url = [string](Get-Prop $comparisonLocalhost "url" "")
      bundleId = [string](Get-Prop $comparisonLocalhost "bundleId" "")
      status = [string](Get-Prop $comparisonLocalhost "status" "")
      verdict = [string](Get-Prop $comparisonLocalhost "verdict" "")
      error = [string](Get-Prop $comparisonLocalhost "error" "")
      routePathWithSearch = [string](Get-Prop $comparisonLocalhost "routePathWithSearch" "")
      buildBundleScript = [string](Get-Prop $comparisonLocalhost "buildBundleScript" "")
      captureReportPath = [string](Get-Prop $comparisonLocalhost "captureReportPath" "")
      analysisReportPath = [string](Get-Prop $comparisonLocalhost "analysisReportPath" "")
      analysisSummaryPath = [string](Get-Prop $comparisonLocalhost "analysisSummaryPath" "")
      localExportPath = [string](Get-Prop $comparisonLocalhost "localExportPath" "")
      screenshotPath = [string](Get-Prop $comparisonLocalhost "screenshotPath" "")
      flaggedHeuristics = @((Get-Prop $comparisonLocalhost "flaggedHeuristics" @()))
      flaggedHeuristicSummaries = @((Get-Prop $comparisonLocalhost "flaggedHeuristicSummaries" @()))
      captureHeuristics = @((Get-Prop $comparisonLocalhost "captureHeuristics" @()))
      compareFlaggedHeuristics = @((Get-Prop $comparisonLocalhost "compareFlaggedHeuristics" @()))
      compareCaptureHeuristics = @((Get-Prop $comparisonLocalhost "compareCaptureHeuristics" @()))
      suppressedCompareHeuristics = @((Get-Prop $comparisonLocalhost "suppressedCompareHeuristics" @()))
      warningSurface = Get-Prop $comparisonLocalhost "warningSurface" $null
      underfillMetrics = Get-Prop $comparisonLocalhost "underfillMetrics" $null
      bottomSeamMetrics = Get-Prop $comparisonLocalhost "bottomSeamMetrics" $null
      typographyMetrics = Get-Prop $comparisonLocalhost "typographyMetrics" $null
      liveStatsMetrics = Get-Prop $comparisonLocalhost "liveStatsMetrics" $null
      playRightRail = Get-Prop $comparisonLocalhost "playRightRail" $null
      metricSupport = Get-Prop $comparisonLocalhost "metricSupport" $null
    }
    Write-Json $localhostReportPath $localhostTargetReport
    $localhostTargetSummaryLines = @(
      "# VP Test Target",
      "",
      "- Generated: " + [string](Get-Prop $comparisonLocalhost "generatedAt" $timestamp),
      "- Target: localhost",
      "- URL: " + [string](Get-Prop $comparisonLocalhost "url" ""),
      "- Status: " + [string](Get-Prop $comparisonLocalhost "status" ""),
      "- BundleId: " + $(if ([string](Get-Prop $comparisonLocalhost "bundleId" "")) { [string](Get-Prop $comparisonLocalhost "bundleId" "") } else { "(none)" }),
      "- Verdict: " + [string](Get-Prop $comparisonLocalhost "verdict" ""),
      "- Error: " + $(if ([string](Get-Prop $comparisonLocalhost "error" "")) { [string](Get-Prop $comparisonLocalhost "error" "") } else { "none" }),
      "- Route: " + $(if ([string](Get-Prop $comparisonLocalhost "routePathWithSearch" "")) { [string](Get-Prop $comparisonLocalhost "routePathWithSearch" "") } else { "(missing)" }),
      "- Build: " + $(if ([string](Get-Prop $comparisonLocalhost "buildBundleScript" "")) { [string](Get-Prop $comparisonLocalhost "buildBundleScript" "") } else { "(missing)" }),
      "- Capture report: " + [string](Get-Prop $comparisonLocalhost "captureReportPath" ""),
      "- Analysis report: " + [string](Get-Prop $comparisonLocalhost "analysisReportPath" ""),
      "- Analysis summary: " + [string](Get-Prop $comparisonLocalhost "analysisSummaryPath" ""),
      "- Local export: " + $(if ([string](Get-Prop $comparisonLocalhost "localExportPath" "")) { [string](Get-Prop $comparisonLocalhost "localExportPath" "") } else { "(missing)" }),
      "- Screenshot: " + $(if ([string](Get-Prop $comparisonLocalhost "screenshotPath" "")) { [string](Get-Prop $comparisonLocalhost "screenshotPath" "") } else { "(missing)" }),
      "- Flagged heuristics: " + ($(if (@((Get-Prop $comparisonLocalhost "flaggedHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "flaggedHeuristics" @())) -join ", ") } else { "none" })),
      "- Compare heuristics: " + ($(if (@((Get-Prop $comparisonLocalhost "compareFlaggedHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "compareFlaggedHeuristics" @())) -join ", ") } else { "none" })),
      "- Flagged heuristic details: " + ($(if (@((Get-Prop $comparisonLocalhost "flaggedHeuristicSummaries" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "flaggedHeuristicSummaries" @())) -join " | ") } else { "none" })),
      "- Capture heuristics: " + ($(if (@((Get-Prop $comparisonLocalhost "captureHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "captureHeuristics" @())) -join ", ") } else { "none" })),
      "- Compare capture heuristics: " + ($(if (@((Get-Prop $comparisonLocalhost "compareCaptureHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "compareCaptureHeuristics" @())) -join ", ") } else { "none" })),
      "- Suppressed compare heuristics: " + ($(if (@((Get-Prop $comparisonLocalhost "suppressedCompareHeuristics" @())).Count -gt 0) { (@((Get-Prop $comparisonLocalhost "suppressedCompareHeuristics" @())) -join ", ") } else { "none" })),
      "- Metric support: " + (Format-VpTestMetricSupportSummary (Get-Prop $comparisonLocalhost "metricSupport" $null)),
      "- Warning surface: " + (Format-VpTestWarningSurfaceSummary (Get-Prop $comparisonLocalhost "warningSurface" $null)),
      "- Analyze underfill detail: " + (Format-VpTestUnderfillMetricsSummary (Get-Prop $comparisonLocalhost "underfillMetrics" $null)),
      "- Analyze bottom seam detail: " + (Format-VpTestBottomSeamMetricsSummary (Get-Prop $comparisonLocalhost "bottomSeamMetrics" $null)),
      "- Rail typography detail: " + (Format-VpTestTypographyMetricsSummary (Get-Prop $comparisonLocalhost "typographyMetrics" $null)),
      "- LIVE-STATS detail: " + (Format-VpTestLiveStatsMetricsSummary (Get-Prop $comparisonLocalhost "liveStatsMetrics" $null)),
      "- Play-Right-Rail reconciliation: " + [string](Get-Prop (Get-Prop $comparisonLocalhost "playRightRail" $null) "summary" "(missing)"),
      "- Play-Right-Rail detail: " + (Format-VpTestPlayRightRailDetail (Get-Prop $comparisonLocalhost "playRightRail" $null))
    ) -join "`r`n"
    Atomic-WriteTextUtf8 $localhostSummaryPath ($localhostTargetSummaryLines + "`r`n")
  }

  CI-Info ("vp-test: ok status=" + [string]$report.status + " bundle=" + $bundleId + " report=" + $reportPath)
}

function Cmd-Stp() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $now = NowIso; $agent = Get-AgentId; $st = $null
  function Test-StpNoActiveFocus([object]$todoState) {
    if ($null -eq $todoState) { return $true }
    $items = @()
    try { $items = @($todoState.items) } catch { $items = @() }
    $active = [string](Get-Prop $todoState "active_id" "")
    return (-not $active) -and $items.Count -eq 0
  }
  function Resolve-StpActiveStatus([object]$todoState, [string]$activeId, [bool]$noActiveFocus) {
    if ($noActiveFocus) { return "done" }
    $status = "in-progress"
    if (-not $todoState -or -not $activeId) { return $status }
    try {
      foreach ($it in @($todoState.items)) {
        $itemId = [string](Get-Prop $it "todo_id" (Get-Prop $it "id" ""))
        if ($itemId -ne $activeId) { continue }
        $itemStatus = [string](Get-Prop $it "status" $status)
        if ($itemStatus) { return $itemStatus }
      }
    } catch { $null = $_ }
    return $status
  }
  function Get-StpNextSteps([bool]$noActiveFocus, [string]$activeId) {
    if ($noActiveFocus) {
      return @(
        "Ohne neues User-Signal keinen neuen Roadmap-Punkt oeffnen.",
        "Bei neuem Fokus ``Roadmap.md``, ``todo.current.md``, ``todo.state.json`` und ``handoff.latest.md/json`` gemeinsam weiterschreiben."
      )
    }
    return @(
      ('Aktiven Roadmap-Punkt `' + $activeId + '` weiterbearbeiten.'),
      ('Nach Abschluss von `' + $activeId + '` Todo-/Handoff-Sync und `.\ci.cmd stp` erneut ausfuehren.')
    )
  }
  function Render-StpHandoffMarkdown([string]$timestamp, [string]$status, [string]$activeId, [string[]]$nextSteps) {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Handoff " + $timestamp)
    $lines.Add("")
    $lines.Add("- Status: " + $status)
    $lines.Add('- Aktiver Kontext: `' + $activeId + '`')
    $lines.Add('- Roadmap-Fokus: `' + $activeId + '`')
    $lines.Add("")
    $lines.Add("## Stand")
    if ($activeId -eq "No-Active-Focus") {
      $lines.Add("- ``Roadmap.md``, ``todo.current.md``, ``todo.state.json``, ``handoff.latest.md`` und ``handoff.latest.json`` stehen synchron auf ``No-Active-Focus``.")
      $lines.Add("- Der letzte ``.\ci.cmd stp``-Checkpoint ist als Resume-Stand fuer den naechsten Chat konserviert.")
    } else {
      $lines.Add('- ``Roadmap.md`` und ``todo.state.json`` fuehren `' + $activeId + '` als aktiven Fokus.')
      $lines.Add("- ``handoff.latest.md/json`` spiegeln denselben Arbeitsstand fuer den naechsten Chat.")
    }
    $lines.Add("")
    $lines.Add("## Referenzen")
    $lines.Add("- ``Roadmap.md``")
    $lines.Add("- ``todo.current.md``")
    $lines.Add("- ``todo.state.json``")
    $lines.Add("- ``handoff.latest.md``")
    $lines.Add("- ``handoff.latest.json``")
    $lines.Add("")
    $lines.Add("## Naechste Schritte")
    foreach ($step in @($nextSteps)) {
      $lines.Add("- " + $step)
    }
    return ($lines -join "`r`n") + "`r`n"
  }
  try { $st = Load-TodoState } catch { $st = $null }
  if ($st) { try { Save-TodoState $st } catch { $null = $_ } }
  $rawActiveId = $null; try { $rawActiveId = [string](Get-Prop $st "active_id" $null) } catch { $rawActiveId = $null }
  $noActiveFocus = Test-StpNoActiveFocus $st
  $activeId = $(if ($noActiveFocus) { "No-Active-Focus" } else { $rawActiveId })
  $activeStatus = Resolve-StpActiveStatus $st $rawActiveId $noActiveFocus
  $nextSteps = Get-StpNextSteps $noActiveFocus $activeId
  $tc = Try-ReadJson (Join-Path $CiRoot "run\toolchain.state.json"); $vd = Try-ReadJson (Join-Path $LogsRoot "verify\verify.digest.json"); $rc = Try-ReadJson (Join-Path $CiRoot "run\route.check.json"); $proj = (Split-Path $RepoRoot -Leaf)
  $capsule = @{ ts=$now; agent_id=$agent; workspace_root=$RepoRoot; project=$proj; chat_flow_policy=$script:ChatFlowPolicy; active_id=$activeId; status=$activeStatus; goal=""; changed=@(); verified=@(); route_ok=(Get-Prop $rc "route_ok" $null); route_violations=@(); git=@{}; next=""; refs=@("Roadmap.md","todo.current.md","todo.state.json","todo.events.jsonl","handoff.latest.md","handoff.latest.json"); manual_missing=$false; env_inventory_missing=$false; env_inventory_used=$false; env_inventory_path=$null }
  $handoff = @{ ts=$now; agent_id=$agent; workspace_root=$RepoRoot; project=$proj; chat_flow_policy=$script:ChatFlowPolicy; toolchain=$tc; active_id=$activeId; status=$activeStatus; summary="stp sync"; next_steps=$nextSteps; refs=@("file:Roadmap.md", "file:todo.current.md", "file:todo.state.json", "file:todo.events.jsonl", "file:handoff.latest.md", "file:handoff.latest.json", "file:logs/verify/verify.digest.json"); verify_digest=$vd; route=$rc; capsule=$capsule }
  Write-Json (Join-Path $RepoRoot "handoff.latest.json") $handoff
  Atomic-WriteTextUtf8 (Join-Path $RepoRoot "handoff.latest.md") (Render-StpHandoffMarkdown (Get-Date -Format "yyyy-MM-dd HH:mm zzz") $activeStatus $activeId $nextSteps)
  $todoIdForEv = "SYSTEM"; if ($rawActiveId) { $todoIdForEv = $rawActiveId }
  $ev = $null; try { $ev = Append-TodoEvent @{ ts=$now; type="stp"; todo_id=$todoIdForEv; status=$activeStatus; prio="low"; source="stp"; msg="sync checkpoint"; refs=@("file:todo.events.jsonl","file:handoff.latest.json"); changed=@(); verified=@(); git=@{} } } catch { $null = $_ }
  try { $eid = $null; if ($ev) { $eid = [string](Get-Prop $ev "event_id" $null) }; if (-not $eid) { $eid = New-EventId }; Append-ChatHistoryLine @{ ts=$now; event_id=$eid; todo_id=$todoIdForEv; summary="stp sync"; refs=@("file:todo.events.jsonl","file:handoff.latest.json") } } catch { $null = $_ }
  Cmd-WsLockRelease | Out-Null; Write-Output ("CAPSULE:" + (To-Json $capsule))
}

function Cmd-Git([string[]]$argv) {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $argsLine = ""
  if ($argv -and $argv.Count -gt 0) { $argsLine = ($argv -join " ").Trim() }
  if (-not $argsLine) { throw "git: missing arguments. Example: .ci\\bin\\ci.cmd git status --short" }
  $ts = TsId
  $log = Join-Path $LogsRoot ("terminal\git-" + $ts + ".log")
  $res = Run-GitCmd $argsLine $log
  if ((Get-Prop $res "fallback_used" $false)) { CI-Warn "git: no-lfs fallback applied due to signal-pipe/lfs filter failure." }
  if ((Get-Prop $res "index_lock_acl_deny_detected" $false)) {
    $aclReport = [string](Get-Prop $res "index_lock_acl_report_path" "")
    if ($aclReport) { CI-Warn ("git: index.lock blocker includes ACL deny entries. audit=" + $aclReport) }
    else { CI-Warn "git: index.lock blocker includes ACL deny entries on .git/.git/index." }

    $remediation = @((Get-Prop $res "index_lock_acl_remediation_commands" @()))
    if ($remediation.Count -gt 0) {
      CI-Warn ("git: ACL remediation hint -> " + [string]$remediation[0])
    }
    if ([bool](Get-Prop $res "index_lock_acl_requires_elevation" $false)) {
      $elevationHint = [string](Get-Prop $res "index_lock_acl_elevation_hint" "")
      if ($elevationHint) { CI-Warn ("git: if ACL removal says 'Access denied', rerun in elevated shell -> " + $elevationHint) }
      else { CI-Warn "git: if ACL removal says 'Access denied', rerun in elevated Administrator shell." }
    }
  }
  if ($res.exit -ne 0) { throw ("git command failed: " + $argsLine + ". See " + $log) }
  $out = [string](Get-Prop $res "out" "")
  if ($out) { Write-Output $out.TrimEnd() }
}

function Cmd-GitAclAudit() {
  Ensure-CoreFolders; Ensure-BootstrapFiles
  $ts = TsId
  $diag = Get-GitIndexLockAclDiagnosis $RepoRoot
  $verifyDir = Join-Path $LogsRoot "verify"
  Ensure-Dir $verifyDir
  $latestPath = Join-Path $verifyDir "ops-219-git-acl-audit-latest.json"
  $tsPath = Join-Path $verifyDir ("ops-219-git-acl-audit-" + $ts + ".json")
  Write-Json $latestPath $diag
  Write-Json $tsPath $diag
  CI-Info ("git-acl-audit: wrote " + $latestPath)
  CI-Info ("git-acl-audit: snapshot " + $tsPath)

  $deny = [bool](Get-Prop $diag "acl_deny_detected" $false)
  if ($deny) {
    $sids = @((Get-Prop $diag "deny_sids" @()))
    $match = @((Get-Prop $diag "deny_sid_matches_current_token" @()))
    CI-Warn ("git-acl-audit: DENY detected on .git/.git\\index. deny_sids=" + ($(if ($sids.Count -gt 0) { ($sids -join ",") } else { "-" })))
    CI-Info ("git-acl-audit: deny_sid_matches_current_token=" + ($(if ($match.Count -gt 0) { ($match -join ",") } else { "-" })))
  } else {
    CI-Info "git-acl-audit: no DENY ACL entries detected on .git/.git\\index."
  }
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
#ci verify             (Standard-Verify; unknown => self-check)
#ci sonar              (SonarQube Analyse via sonar.cmd)
#ci sonar-guard-test   (Sonar API Guard fuer new_violations=0)
#ci sonar-auth-preflight (TST-431 Fast-Guard vor sonar)
#ci sonar-start        (SonarQube Server starten)
#ci sonar-stop         (SonarQube Server stoppen)
#ci self-check         (Invarianten + Truth-Dateien prüfen)
#ci gradle-autopsy     (Verify + Eskalation bis Stufe 2; tolerant)
#ci lock-triage        (Windows Lock Evidence sammeln)
#ci observer-baseline  (Baseline Hashes erzeugen)
#ci observer-check     (Diff gegen Baseline)
#ci patch-apply        (1 Patch dry-run+apply, danach Verify)
#ci restore-immutables  (Immutable Dateien aus Snapshot zurückspielen)
#ci route-check        (Verify-Gate prüfen)
#ci browser-smoke      (Browser-Smoke via config/contract)
#ci devserver-start    (Gradle Devserver detached + devserver.log)
#ci devserver-stop     (Stop Gradle Devserver)
#ci devserver-status   (Status Gradle Devserver)
#ci pyserver-start     (Python http.server detached; auto-detect dist)
#ci pyserver-stop      (Stop Python http.server)
#ci pyserver-status    (Status Python http.server)
#ci scholars           (Schäfermatt UI Test)
#ci t                  (Kurzform für scholars)
#ci t2                 (Master-Validierung)
#ci supertest         (Gradle verify + UI Supertest)
#ci viewport-test      (TST-493 Katalog-/Resize-Lane plan-only)
#ci comprehensive-viewport-test (TST-495 Webapp+APK auf Host, allen AVDs und allen online Physical-ADB-Geraeten)
#ci vp-test            (Live Debug-Bundle-Pruefung gegen Prod/Umami, nicht gegen localhost)
#ci android-emulator-test (TST-493 Android-Emulator-Lane plan-only)
#ci android-physical-test (TST-493 Android-Physical-Lane plan-only)
#ci todo-seed          (Roadmap -> todo.state.json, wenn leer)
#ci todo-compact       (todo.state.json normalisieren)
#ci todo-prune         (done-events aus todo.events.jsonl entfernen)
#ci todo-rotate        (todo.events.jsonl rotieren + checkpoint)
#ci todo-rebuild       (todo.state.json aus checkpoint)
#ci todo-sanitize      (Truth-Dateien reparieren / rerender)
#ci roadmap-autogrow   (neue fail_signature -> neuer Roadmap-Punkt, idempotent)
#ci doctor             (Status/Toolchain anzeigen)
#ci env-inventory      (Umgebungs-Snapshot schreiben)
#ci git <args...>      (Git über CI-Wrapper mit LFS-Signal-Pipe-Fallback)
#ci git-acl-audit      (Index-Lock ACL Diagnose als JSON-Evidence schreiben)
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
  $capsule = @{ ts=NowIso; agent_id=(Get-AgentId); workspace_root=$RepoRoot; active=$null; status=$status; changed=@(); verified=@(); evidence=@(); fail_signature=$failSig; fail_streak=$failStreak; escalation_level=$esc; route_ok=$routeOk; lock=$lock; notes=@() }
  if ($errorMsg) { $capsule.notes = @($errorMsg) }; $summary = "auto checkpoint after " + $cmdName; if ($errorMsg) { $summary = "blocked: " + $cmdName }; $next = @()
  if ($status -eq "blocked") { $next = @("open logs/verify/failbundle-latest.json", "run lock-triage if file-lock signatures", "run stp after resolution") } else { $next = @("run doctor", "run stp when ready") }
  $handoff = @{ ts=NowIso; agent_id=(Get-AgentId); workspace_root=$RepoRoot; last_cmd=$cmdName; status=$status; summary=$summary; next_steps=$next; refs=@(); evidence_refs=@((Get-Prop $vd "log_path" $null), (Get-Prop $fb "log_path" $null), $script:LastCmdLogPath) | Where-Object { $_ }; toolchain=$toolchain; capsule=$capsule; verify_digest=$vd; failbundle=$fb }
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
Register-CiCommand "browser-smoke" { Cmd-BrowserSmoke }
Register-CiCommand "devserver-start" { Cmd-DevserverStart }
Register-CiCommand "devserver-stop" { Cmd-DevserverStop }
Register-CiCommand "devserver-status" { Cmd-DevserverStatus }
Register-CiCommand "pyserver-start" { Cmd-PyserverStart }
Register-CiCommand "pyserver-stop" { Cmd-PyserverStop }
Register-CiCommand "pyserver-status" { Cmd-PyserverStatus }
Register-CiCommand "todo-seed" { Cmd-TodoSeed }
Register-CiCommand "todo-compact" { Cmd-TodoCompact }
Register-CiCommand "todo-prune" { Cmd-TodoPrune }
Register-CiCommand "todo-rotate" { Cmd-TodoRotate }
Register-CiCommand "todo-rebuild" { Cmd-TodoRebuild }
Register-CiCommand "todo-sanitize" { Cmd-TodoSanitize }
Register-CiCommand "roadmap-autogrow" { Cmd-RoadmapAutogrow $script:CommandArgs }
Register-CiCommand "doctor" { Cmd-Doctor }
Register-CiCommand "env-inventory" { Cmd-EnvInventory }
Register-CiCommand "git" { Cmd-Git $script:CommandArgs }
Register-CiCommand "git-acl-audit" { Cmd-GitAclAudit }
Register-CiCommand "event" { Cmd-Event $script:CommandArgs }
Register-CiCommand "tick" { Cmd-Tick $script:CommandArgs }
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
Register-CiCommand "viewport-test" { Cmd-TestLanePlan "viewport-test" }
Register-CiCommand "comprehensive-viewport-test" { Cmd-ComprehensiveViewportTest }
Register-CiCommand "viewport-device-test" { Cmd-ComprehensiveViewportTest }
Register-CiCommand "android-emulator-test" { Cmd-TestLanePlan "android-emulator-test" }
Register-CiCommand "android-physical-test" { Cmd-TestLanePlan "android-physical-test" }
Register-CiCommand "vp-test" { Cmd-VpTest }
Register-CiCommand "test-full" { Cmd-T2 }
Register-CiCommand "stp" { Cmd-Stp }
Register-CiCommand "menu" { Cmd-Menu }
Register-CiCommand "sonar" { Cmd-Sonar }
Register-CiCommand "sonar-guard-test" {
  node tests/ci/sonar_new_violations_guard_function_test.js
  if ($LASTEXITCODE -ne 0) { throw "sonar_new_violations_guard_function_test failed" }
  node tests/ci/ops_436_zero_unresolved_sonar_contract_function_test.js
  if ($LASTEXITCODE -ne 0) { throw "ops_436_zero_unresolved_sonar_contract_function_test failed" }
}
Register-CiCommand "sonar-auth-preflight" { node tests/ci/tst_431_sonar_auth_preflight_function_test.js }
Register-CiCommand "sonar-start" { Cmd-SonarStart }
Register-CiCommand "sonar-stop" { Cmd-SonarStop }

