#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $encoding = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllText($Path, $Content + "`n", $encoding)
}

function New-TestLocation {
    param([Parameter(Mandatory)][string]$Label)

    [pscustomobject]@{
        label = $Label
        city = 'Muenchen'
        region = 'Bayern'
        country = 'DE'
        target_area = 'MUNICH'
    }
}

function New-TestClassification {
    param(
        [Parameter(Mandatory)][string]$Result,
        [Parameter(Mandatory)][string]$Priority,
        [Parameter(Mandatory)][int]$Score,
        [Parameter(Mandatory)][string[]]$Reasons
    )

    [pscustomobject]@{
        result = $Result
        priority = $Priority
        score = $Score
        reasons = $Reasons
        rejected_reasons = @()
        evaluated_at = '2026-08-23T05:00:00.000Z'
    }
}

$scanRunId = 'scanrun:ja022-viewport-audit'
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-08-23T05:00:00Z')
$document.companies = @(
    [pscustomobject]@{
        company_id = 'company:alpha_ag'
        canonical_name = 'Alpha AG'
        canonical_domain = 'alpha.example.invalid'
        official_website_url = 'https://alpha.example.invalid/'
        career_url = 'https://alpha.example.invalid/careers'
        aliases = @('Alpha')
        locations = @(
            New-TestLocation -Label 'Muenchen'
            New-TestLocation -Label 'Freising'
        )
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 95
        next_scan_at = '2026-08-24T05:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = 'https://alpha.example.invalid/careers'
        created_at = '2026-08-23T05:00:00.000Z'
        updated_at = '2026-08-23T05:00:00.000Z'
        last_successful_scan_at = '2026-08-23T05:00:00.000Z'
    }
    [pscustomobject]@{
        company_id = 'company:beta_gmbh'
        canonical_name = 'Beta GmbH'
        canonical_domain = 'beta.example.invalid'
        official_website_url = 'https://beta.example.invalid/'
        career_url = 'https://beta.example.invalid/jobs'
        aliases = @('Beta')
        locations = @(New-TestLocation -Label 'Muenchen')
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'FAILED'
        scan_priority = 70
        next_scan_at = '2026-08-23T11:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = 'https://beta.example.invalid/jobs'
        created_at = '2026-08-23T05:00:00.000Z'
        updated_at = '2026-08-23T05:00:00.000Z'
        last_successful_scan_at = '2026-08-22T05:00:00.000Z'
    }
)
$document.job_sources = @(
    [pscustomobject]@{
        source_id = 'source:alpha_ag_career'
        company_id = 'company:alpha_ag'
        source_type = 'CAREER_PAGE'
        url = 'https://alpha.example.invalid/careers'
        canonical_url = 'https://alpha.example.invalid/careers'
        is_official = $true
        verified_at = '2026-08-23T05:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @()
    }
    [pscustomobject]@{
        source_id = 'source:beta_gmbh_jobs'
        company_id = 'company:beta_gmbh'
        source_type = 'CAREER_PAGE'
        url = 'https://beta.example.invalid/jobs'
        canonical_url = 'https://beta.example.invalid/jobs'
        is_official = $true
        verified_at = '2026-08-23T05:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @()
    }
)
$document.jobs = @(
    [pscustomobject]@{
        job_id = 'job:alpha_head_it'
        company_id = 'company:alpha_ag'
        official_url = 'https://alpha.example.invalid/jobs/head-it'
        alternative_official_urls = @()
        source_id = 'source:alpha_ag_career'
        external_job_id = 'head-it'
        ats_job_id = 'UNKNOWN'
        title = 'Head of IT mit sehr langem Titel fuer responsiven Layouttest und Ueberlaufpruefung'
        location = New-TestLocation -Label 'Muenchen'
        work_model = 'HYBRID'
        employment_type = 'FULL_TIME'
        status = 'NEW'
        published_at = '2026-08-20T08:00:00.000Z'
        first_seen = '2026-08-23T05:00:00.000Z'
        last_seen = '2026-08-23T05:00:00.000Z'
        changed_at = '2026-08-23T05:00:00.000Z'
        classification = New-TestClassification -Result 'MATCH' -Priority 'A' -Score 97 -Reasons @(
            'Belegte Gesamtverantwortung fuer IT-Strategie, Betrieb und Budget.',
            'Standort Muenchen liegt im Zielgebiet.'
        )
        priority = 'A'
        requirements = @(
            'Budgetverantwortung fuer einen europaweit verteilten IT-Betrieb mit langen Freitexten zur Layoutpruefung',
            'Fuehrung mehrerer Plattformteams und eines Security-Enablement-Streams'
        )
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
    [pscustomobject]@{
        job_id = 'job:alpha_director_platforms'
        company_id = 'company:alpha_ag'
        official_url = 'https://alpha.example.invalid/jobs/director-platforms'
        alternative_official_urls = @()
        source_id = 'source:alpha_ag_career'
        external_job_id = 'director-platforms'
        ats_job_id = 'UNKNOWN'
        title = 'Director Platform Engineering'
        location = New-TestLocation -Label 'Freising'
        work_model = 'REMOTE'
        employment_type = 'FULL_TIME'
        status = 'ACTIVE'
        published_at = '2026-08-18T08:00:00.000Z'
        first_seen = '2026-08-22T05:00:00.000Z'
        last_seen = '2026-08-23T05:00:00.000Z'
        changed_at = '2026-08-23T05:00:00.000Z'
        classification = New-TestClassification -Result 'MATCH' -Priority 'A' -Score 93 -Reasons @(
            'Fuehrungsverantwortung fuer Plattform- und Infrastrukturteams ist belegt.',
            'Freising liegt im Zielgebiet.'
        )
        priority = 'A'
        requirements = @(
            'Skalierung von Plattform-, Infrastruktur- und SRE-Prozessen',
            'Stakeholder-Steuerung mit CTO und CIO'
        )
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
)
$document.scan_runs = @(
    [pscustomobject]@{
        scan_run_id = $scanRunId
        started_at = '2026-08-23T05:00:00.000Z'
        finished_at = '2026-08-23T05:10:00.000Z'
        status = 'PARTIAL'
        company_ids = @('company:alpha_ag', 'company:beta_gmbh')
        artifact_paths = @()
        errors = @('NOT_REACHABLE')
    }
)
$document.scan_attempts = @(
    [pscustomobject]@{
        scan_attempt_id = 'scanattempt:alpha'
        scan_run_id = $scanRunId
        company_id = 'company:alpha_ag'
        source_id = 'source:alpha_ag_career'
        started_at = '2026-08-23T05:00:00.000Z'
        finished_at = '2026-08-23T05:00:02.000Z'
        status = 'SUCCESS'
        adapter = 'fixture'
        error_class = 'NONE'
        retry_recommendation = 'NONE'
        http_status = 200
    }
    [pscustomobject]@{
        scan_attempt_id = 'scanattempt:beta'
        scan_run_id = $scanRunId
        company_id = 'company:beta_gmbh'
        source_id = 'source:beta_gmbh_jobs'
        started_at = '2026-08-23T05:00:00.000Z'
        finished_at = '2026-08-23T05:00:05.000Z'
        status = 'FAILED'
        adapter = 'fixture'
        error_class = 'NOT_REACHABLE'
        retry_recommendation = 'RETRY_NEXT_RUN'
        http_status = 503
    }
)
$document.job_snapshots = @(
    [pscustomobject]@{
        snapshot_id = 'snapshot:alpha_head_it'
        job_id = 'job:alpha_head_it'
        scan_run_id = $scanRunId
        source_id = 'source:alpha_ag_career'
        captured_at = '2026-08-23T05:00:00.000Z'
        content_hash = ('a' * 64)
        status = 'NEW'
        title = 'Head of IT mit sehr langem Titel fuer responsiven Layouttest und Ueberlaufpruefung'
        location = New-TestLocation -Label 'Muenchen'
        official_url = 'https://alpha.example.invalid/jobs/head-it'
        summary = 'Fuehrungsrolle mit breiter IT-Verantwortung.'
    }
    [pscustomobject]@{
        snapshot_id = 'snapshot:alpha_director_platforms'
        job_id = 'job:alpha_director_platforms'
        scan_run_id = $scanRunId
        source_id = 'source:alpha_ag_career'
        captured_at = '2026-08-23T05:00:01.000Z'
        content_hash = ('b' * 64)
        status = 'ACTIVE'
        title = 'Director Platform Engineering'
        location = New-TestLocation -Label 'Freising'
        official_url = 'https://alpha.example.invalid/jobs/director-platforms'
        summary = 'Plattformfuehrung mit Infrastruktur- und SRE-Verantwortung.'
    }
)
$document.change_events = @(
    [pscustomobject]@{
        change_event_id = 'change:alpha_head_it'
        job_id = 'job:alpha_head_it'
        scan_run_id = $scanRunId
        event_type = 'JOB_CREATED'
        created_at = '2026-08-23T05:00:00.000Z'
        old_status = $null
        new_status = 'NEW'
        changed_fields = @('status')
        reason = 'Erstmals erkannt.'
    }
)

$report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
$html = ConvertTo-JobAgentDailyReportHtml -Report $report
$markdown = ConvertTo-JobAgentDailyReportMarkdown -Report $report

$htmlPath = Join-Path $root 'html\jobagent\ja-022-viewport-audit.html'
$markdownPath = Join-Path $root 'logs\jobagent\ja-022-viewport-audit.md'
$summaryPath = Join-Path $root 'logs\jobagent\ja-022-viewport-audit.json'
$screenshotRoot = Join-Path $root 'output\playwright'

Write-Utf8File -Path $htmlPath -Content $html
Write-Utf8File -Path $markdownPath -Content $markdown

$reportUrl = 'http://127.0.0.1:8500/html/jobagent/ja-022-viewport-audit.html'
$response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 10
Assert-True -Condition ($response.StatusCode -eq 200) -Message 'Visual-Audit-Report ist ueber den lokalen Devserver nicht mit HTTP 200 erreichbar.'

if (-not (Test-Path -LiteralPath $screenshotRoot)) {
    New-Item -ItemType Directory -Path $screenshotRoot -Force | Out-Null
}

$browserCandidates = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe'
    'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
    'C:\Program Files\Microsoft\Edge\Application\msedge.exe'
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
)
$browserPath = @($browserCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)[0]
Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($browserPath)) -Message 'Kein lokaler Chrome- oder Edge-Browser fuer den Viewport-Audit gefunden.'

$screenshots = New-Object System.Collections.Generic.List[string]
foreach ($width in 1920, 1366, 800) {
    $screenshotPath = Join-Path $screenshotRoot ("ja-022-viewport-" + $width + '.png')
    $stderrPath = Join-Path $screenshotRoot ("ja-022-viewport-" + $width + '.stderr.log')
    if (Test-Path -LiteralPath $screenshotPath) {
        Remove-Item -LiteralPath $screenshotPath -Force
    }
    if (Test-Path -LiteralPath $stderrPath) {
        Remove-Item -LiteralPath $stderrPath -Force
    }

    $arguments = @(
        '--headless=new'
        '--disable-gpu'
        '--hide-scrollbars'
        '--run-all-compositor-stages-before-draw'
        '--virtual-time-budget=2000'
        ("--window-size={0},2200" -f $width)
        ("--screenshot={0}" -f $screenshotPath)
        $reportUrl
    )
    $process = Start-Process -FilePath $browserPath -ArgumentList $arguments -PassThru -Wait -NoNewWindow -RedirectStandardError $stderrPath
    if ($process.ExitCode -ne 0) {
        $stderr = if (Test-Path -LiteralPath $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { '' }
        throw ("Viewport-Screenshot fehlgeschlagen fuer Breite " + $width + ": " + $stderr)
    }

    Assert-True -Condition (Test-Path -LiteralPath $screenshotPath) -Message "Viewport-Screenshot fehlt fuer Breite $width."
    $screenshotFile = Get-Item -LiteralPath $screenshotPath
    Assert-True -Condition ($screenshotFile.Length -gt 10000) -Message "Viewport-Screenshot fuer Breite $width ist unplausibel klein."
    $screenshots.Add($screenshotPath)
}

$summary = [pscustomobject]@{
    status = 'ok'
    html_report_path = $htmlPath
    markdown_report_path = $markdownPath
    html_report_url = $reportUrl
    http_status = [int]$response.StatusCode
    screenshots = @($screenshots.ToArray())
    viewports = @(1920, 1366, 800)
    cases = @(
        'html_report_written_to_local_artifact_path',
        'html_report_reachable_over_devserver_http_200',
        'viewport_audit_1920',
        'viewport_audit_1366',
        'viewport_audit_800'
    )
}

Write-Utf8File -Path $summaryPath -Content ($summary | ConvertTo-Json -Depth 20)
$summary | ConvertTo-Json -Depth 20
