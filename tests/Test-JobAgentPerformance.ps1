#requires -Version 7.4

[CmdletBinding()]
param(
    [int[]]$JobCounts = @(0, 1, 50, 51, 121, 1000, 10000),
    [ValidateRange(0, 100)][int]$WarmupCount = 5,
    [ValidateRange(1, 100)][int]$MeasurementCount = 20
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.PlaywrightEnvironment.psm1') -Force

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

function Invoke-JobAgentPlaywrightCli {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string[]]$Arguments)
    Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $script:playwrightRunEnvironment -WorkingDirectory $WorkingDirectory -Arguments $Arguments
}

function Get-JobAgentBrowserValue {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Case
    )

    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--raw', '--session', $SessionName, 'eval', $Script)
    $match = [regex]::Match($output, '(?s)### Result\s*(?<json>\{.*?\}|\[.*?\]|null|true|false|"(?:\\.|[^"\\])*")\s*(?:###|$)')
    $json = if ($match.Success) { $match.Groups['json'].Value } else { $output.Trim() }
    try {
        $value = $json | ConvertFrom-Json -Depth 30
    }
    catch {
        throw "${Case}: Playwright-CLI lieferte kein JSON-Ergebnis."
    }
    if ($value -is [string]) {
        return ($value | ConvertFrom-Json -Depth 30)
    }
    return $value
}

function New-TestLocation {
    [pscustomobject]@{
        label = 'Muenchen'
        city = 'Muenchen'
        region = 'Bayern'
        country = 'DE'
        target_area = 'MUNICH'
    }
}

function New-TestCompany {
    param([Parameter(Mandatory)][int]$Number, [Parameter(Mandatory)][object]$Location)

    $suffix = $Number.ToString('00000', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        company_id = "company:performance_$suffix"
        canonical_name = "Leistungsfirma $suffix"
        canonical_domain = "leistung-$suffix.example.invalid"
        official_website_url = "https://leistung-$suffix.example.invalid/"
        career_url = "https://leistung-$suffix.example.invalid/karriere"
        aliases = @()
        locations = @($Location)
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 50
        next_scan_at = '2026-09-22T10:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = $null
        created_at = '2026-09-21T10:00:00.000Z'
        updated_at = '2026-09-21T10:00:00.000Z'
        last_successful_scan_at = '2026-09-21T10:00:00.000Z'
    }
}

function New-TestJob {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][object]$Location,
        [Parameter(Mandatory)][ValidateRange(1, 50)][int]$CompanyCount
    )

    $suffix = $Number.ToString('00000', [Globalization.CultureInfo]::InvariantCulture)
    $companySuffix = ((($Number - 1) % $CompanyCount) + 1).ToString('00000', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        job_id = "job:performance_$suffix"
        company_id = "company:performance_$companySuffix"
        official_url = "https://leistung-$suffix.example.invalid/karriere/$suffix"
        alternative_official_urls = @()
        source_id = 'UNKNOWN'
        external_job_id = $suffix
        ats_job_id = 'UNKNOWN'
        title = "Leistungsprobe Stelle $suffix"
        job_category = 'Leistungstest'
        location = $Location
        work_model = 'ONSITE'
        employment_type = 'FULL_TIME'
        work_time = 'UNKNOWN'
        status = 'ACTIVE'
        published_at = '2026-09-21T10:00:00.000Z'
        first_seen = '2026-09-21T10:00:00.000Z'
        last_seen = '2026-09-21T10:00:00.000Z'
        changed_at = '2026-09-21T10:00:00.000Z'
        classification = [pscustomobject]@{
            result = 'REJECTED'
            priority = 'D'
            score = 0
            category = 'Leistungstest'
            reasons = @('Synthetische, lokale Performance-Fixture.')
            rejected_reasons = @()
            evaluated_at = '2026-09-21T10:00:00.000Z'
        }
        priority = 'D'
        requirements = @('Synthetische Leistungsprobe')
        description = "Lokale, deterministische Benchmarkdaten ohne Netzwerkanfrage. Benchmarktoken J$suffix."
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

function New-PerformanceDocument {
    param([Parameter(Mandatory)][int]$JobCount)

    $location = New-TestLocation
    $document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-09-21T10:00:00Z')
    # Der Lastfall misst die Stellenliste; der Firmenbestand wird deshalb auf 50
    # repräsentative Firmen begrenzt und nicht künstlich mit jeder Stelle vervielfacht.
    $companyCount = [Math]::Min(50, [Math]::Max(1, $JobCount))
    $document.companies = @(1..$companyCount | ForEach-Object { New-TestCompany -Number $_ -Location $location })
    if ($JobCount -eq 0) {
        $document.jobs = @()
    }
    else {
        $document.jobs = @(1..$JobCount | ForEach-Object { New-TestJob -Number $_ -Location $location -CompanyCount $companyCount })
    }
    $document.job_sources = @()
    $companyIds = @($document.companies | ForEach-Object { $_.company_id })
    $document.scan_runs = @([pscustomobject]@{
            scan_run_id = "scanrun:ja050-performance-$JobCount"
            started_at = '2026-09-21T10:00:00.000Z'
            finished_at = '2026-09-21T10:00:00.000Z'
            status = 'SUCCESS'
            company_ids = $companyIds
            artifact_paths = @()
            errors = @()
        })
    $document.scan_attempts = @()
    $document.job_snapshots = @()
    $document.change_events = @()
    return $document
}

function Get-Percentile95 {
    param([Parameter(Mandatory)][double[]]$Values)

    $sorted = @($Values | Sort-Object)
    Assert-True -Condition ($sorted.Count -gt 0) -Message 'p95 kann nicht ohne Messwerte berechnet werden.'
    $index = [Math]::Ceiling($sorted.Count * 0.95) - 1
    return [double]$sorted[[Math]::Min($index, $sorted.Count - 1)]
}

$devserverStatus = & (Join-Path $root 'ci.cmd') 'devserver-status' 2>&1
Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('Der CI-Devserver auf Port 8500 ist nicht verfuegbar: ' + ($devserverStatus -join "`n"))

$runId = 'ja050-performance-' + [guid]::NewGuid().ToString('N')
$evidenceRoot = Join-Path $root (Join-Path 'logs\jobagent\JA-050' $runId)
$artifactRoot = Join-Path $evidenceRoot 'playwright'
$evidencePath = Join-Path (Join-Path $root 'logs\jobagent\JA-050') 'performance.json'
New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
$script:playwrightRunEnvironment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $root -RunId $runId
$browserConfigPath = Join-Path $artifactRoot 'playwright-cli.config.json'
Write-Utf8File -Path $browserConfigPath -Content (@{
        browser = @{
            launchOptions = @{ channel = 'chrome'; headless = $true; args = @('--no-sandbox') }
            contextOptions = @{ locale = 'de-DE'; timezoneId = 'Europe/Berlin' }
        }
    } | ConvertTo-Json -Depth 10)

function Get-JobAgentFilterMeasurementScript {
    param(
        [Parameter(Mandatory)][string]$Query,
        [Parameter(Mandatory)][int]$ExpectedVisibleCards
    )

    $queryJson = $Query | ConvertTo-Json -Compress
    $expectedVisibleCardsJson = $ExpectedVisibleCards.ToString([Globalization.CultureInfo]::InvariantCulture)
    return @"
async () => {
  const query=document.getElementById("jobagent-query"), root=document.getElementById("jobagent-job-results"), expected=$queryJson, expectedVisibleCards=$expectedVisibleCardsJson;
  const start=performance.now(), deadline=start+2000, cards=()=>root.querySelectorAll("[data-job-id]").length;
  query.value=expected;query.dispatchEvent(new InputEvent("input",{bubbles:true,inputType:"insertText",data:expected}));
  while(cards()!==expectedVisibleCards&&performance.now()<deadline){await new Promise(resolve=>requestAnimationFrame(resolve));}
  return JSON.stringify({elapsed_ms:performance.now()-start,visible_cards:cards()});
}
"@
}
$initialMeasurementScript = @'
() => { const navigation=performance.getEntriesByType("navigation")[0]||{},root=document.getElementById("jobagent-job-results"),count=document.getElementById("jobagent-result-count"); return JSON.stringify({first_interactive_render_ms:Number(navigation.domContentLoadedEventEnd||0),visible_cards:root?root.querySelectorAll("[data-job-id]").length:-1,result_text:count?count.textContent:"",user_agent:navigator.userAgent,platform:navigator.platform,hardware_concurrency:navigator.hardwareConcurrency||null,device_memory:navigator.deviceMemory||null}); }
'@

$datasets = @($JobCounts)
$fullAcceptancePlan = (@($datasets) -join ',') -eq '0,1,50,51,121,1000,10000' -and $WarmupCount -eq 5 -and $MeasurementCount -eq 20
$results = [System.Collections.Generic.List[object]]::new()
$browserMetadata = $null
$sessionName = 'jobagent-performance-' + [guid]::NewGuid().ToString('N')
$sessionOpened = $false
try {
    foreach ($jobCount in $datasets) {
        $document = New-PerformanceDocument -JobCount $jobCount
        $report = New-JobAgentDailyReport -Document $document -ScanRunId "scanrun:ja050-performance-$jobCount"
        Assert-True -Condition (@($report.sections.active_jobs).Count -eq $jobCount) -Message "Fixture mit $jobCount Stellen wurde vom Report nicht vollstaendig uebernommen."

        $htmlPath = Join-Path $evidenceRoot ("performance-$jobCount.html")
        Write-Utf8File -Path $htmlPath -Content (ConvertTo-JobAgentDailyReportHtml -Report $report)
        $reportUrl = 'http://127.0.0.1:8500/logs/jobagent/JA-050/' + $runId + "/performance-$jobCount.html"
        $response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 30
        Assert-True -Condition ($response.StatusCode -eq 200) -Message "Benchmarkreport fuer $jobCount Stellen ist nicht ueber den CI-Devserver erreichbar."

        if ($sessionOpened) {
            Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'goto', $reportUrl) | Out-Null
        }
        else {
            Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, '--config', $browserConfigPath, '--idle-timeout=600000', 'open', $reportUrl) | Out-Null
            $sessionOpened = $true
        }
            $initial = Get-JobAgentBrowserValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script $initialMeasurementScript -Case "Initialrender $jobCount"
            if ($null -eq $browserMetadata) { $browserMetadata = $initial }
            $expectedInitialCards = [Math]::Min($jobCount, 50)
            Assert-True -Condition ([int]$initial.visible_cards -eq $expectedInitialCards) -Message "Initialrender ${jobCount}: erwartete $expectedInitialCards Karten, erhalten $($initial.visible_cards)."
            Assert-True -Condition ([string]$initial.result_text -match "Stellen: $jobCount Treffer") -Message "Initialrender ${jobCount}: Trefferzaehler ist nicht korrekt."

            $queryValues = @(1..($WarmupCount + $MeasurementCount) | ForEach-Object {
                    $suffix = if ($jobCount -eq 0) { 'keine-stelle' } else { (($_ - 1) % $jobCount + 1).ToString('00000', [Globalization.CultureInfo]::InvariantCulture) }
                    "Benchmarktoken J$suffix"
                })
            $expectedCards = if ($jobCount -eq 0) { 0 } else { 1 }
            foreach ($queryValue in @($queryValues | Select-Object -First $WarmupCount)) {
                $warmupResult = Get-JobAgentBrowserValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script (Get-JobAgentFilterMeasurementScript -Query $queryValue -ExpectedVisibleCards $expectedCards) -Case "Warmup $jobCount"
                Assert-True -Condition ([int]$warmupResult.visible_cards -eq $expectedCards) -Message "Warmup fuer $jobCount Stellen: Filterergebnis ist nicht korrekt."
            }
            $samples = [System.Collections.Generic.List[double]]::new()
            foreach ($queryValue in @($queryValues | Select-Object -Skip $WarmupCount)) {
                $measurement = Get-JobAgentBrowserValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script (Get-JobAgentFilterMeasurementScript -Query $queryValue -ExpectedVisibleCards $expectedCards) -Case "Messung $jobCount"
                Assert-True -Condition ([int]$measurement.visible_cards -eq $expectedCards) -Message "Messung fuer $jobCount Stellen: Filterergebnis ist nicht korrekt."
                Assert-True -Condition ([double]$measurement.elapsed_ms -ge 0) -Message "Messung fuer $jobCount Stellen: negative Laufzeit."
                $samples.Add([double]$measurement.elapsed_ms)
            }
            $p95 = Get-Percentile95 -Values $samples.ToArray()
            Assert-True -Condition ($p95 -le 500) -Message "Filter-p95 fuer $jobCount Stellen ueberschreitet 500 ms: $p95 ms."
            if ($jobCount -eq 10000) {
                Assert-True -Condition ([double]$initial.first_interactive_render_ms -le 3000) -Message "Erster bedienbarer Render fuer 10000 Stellen ueberschreitet 3000 ms: $($initial.first_interactive_render_ms) ms."
            }
            $results.Add([pscustomobject]@{
                    job_count = $jobCount
                    visible_cards_maximum = $expectedInitialCards
                    warmups = $WarmupCount
                    measured_filters = $MeasurementCount
                    filter_samples_ms = @($samples.ToArray())
                    filter_p95_ms = $p95
                    first_interactive_render_ms = [double]$initial.first_interactive_render_ms
                    initial_result_text = [string]$initial.result_text
                    http_status = [int]$response.StatusCode
                })
    }
}
finally {
    if ($sessionOpened) {
        try { Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'close') | Out-Null } catch { Write-Warning $_.Exception.Message }
    }
    Remove-JobAgentPlaywrightRunEnvironment -RunEnvironment $script:playwrightRunEnvironment
}

$computer = $null
$processor = $null
$operatingSystem = $null
try {
    $computer = Get-CimInstance Win32_ComputerSystem
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    $operatingSystem = Get-CimInstance Win32_OperatingSystem
}
catch {
    # Der Benchmark bleibt auch in eingeschraenkten lokalen Testumgebungen lauffaehig.
}
$summary = [pscustomobject]@{
    schema_version = 'jobagent-ja050-performance/v1'
    status = 'ok'
    measured_at = (Get-Date).ToString('o')
    reference_time = '2026-09-21T10:00:00.000Z'
    host = [pscustomobject]@{
        os = if ($null -eq $operatingSystem) { 'UNKNOWN' } else { [string]$operatingSystem.Caption }
        processor = if ($null -eq $processor) { [string]$env:PROCESSOR_IDENTIFIER } else { [string]$processor.Name }
        logical_processors = if ($null -eq $computer) { [Environment]::ProcessorCount } else { [int]$computer.NumberOfLogicalProcessors }
        total_memory_bytes = if ($null -eq $computer) { $null } else { [int64]$computer.TotalPhysicalMemory }
    }
    browser = $browserMetadata
    acceptance = [pscustomobject]@{
        datasets = $datasets
        warmups_per_dataset = $WarmupCount
        measurements_per_dataset = $MeasurementCount
        page_size = 50
        filter_p95_limit_ms = 500
        first_interactive_render_10000_limit_ms = 3000
    }
    results = @($results.ToArray())
}
if (-not $fullAcceptancePlan) {
    $evidencePath = Join-Path $evidenceRoot 'performance-debug.json'
}
Write-Utf8File -Path $evidencePath -Content ($summary | ConvertTo-Json -Depth 20)
$summary | ConvertTo-Json -Depth 20
