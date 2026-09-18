#requires -Version 7.4

[CmdletBinding()]
param()

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

    [IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

function Invoke-JobAgentPlaywrightCli {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string[]]$Arguments)

    Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $script:playwrightRunEnvironment -WorkingDirectory $WorkingDirectory -Arguments $Arguments
}

function Get-SessionValue {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string]$SessionName, [Parameter(Mandatory)][string]$Case, [Parameter(Mandatory)][string]$Script)

    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', $Script)
    $match = [regex]::Match($output, '(?ms)### Result\s*\r?\n(?<payload>.+?)\s*$')
    Assert-True -Condition $match.Success -Message "${Case}: Playwright-CLI lieferte kein Eval-Ergebnis."
    $value = $match.Groups['payload'].Value.Trim() | ConvertFrom-Json -Depth 30
    if ($value -is [string]) { return ($value | ConvertFrom-Json -Depth 30) }
    return $value
}

function New-ChangeHistoryCompany {
    [pscustomobject]@{
        company_id = 'company:history_fixture'
        canonical_name = 'Chronik GmbH'
        canonical_domain = 'fixture.example.invalid'
        official_website_url = 'https://fixture.example.invalid/'
        career_url = 'https://fixture.example.invalid/jobs'
        aliases = @()
        locations = @([pscustomobject]@{ label = 'Muenchen'; city = 'Muenchen'; region = 'Bayern'; country = 'DE'; target_area = 'MUNICH' })
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 90
        next_scan_at = '2026-09-19T08:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = $null
        created_at = '2026-09-17T08:00:00.000Z'
        updated_at = '2026-09-18T08:00:00.000Z'
        last_successful_scan_at = '2026-09-18T08:00:00.000Z'
    }
}

function New-ChangeHistoryJob {
    param([Parameter(Mandatory)][string]$JobId, [Parameter(Mandatory)][string]$Title)

    [pscustomobject]@{
        job_id = $JobId
        company_id = 'company:history_fixture'
        official_url = 'https://fixture.example.invalid/jobs/' + $JobId.Replace(':', '/')
        alternative_official_urls = @()
        source_id = 'source:history_fixture_career'
        external_job_id = $JobId
        ats_job_id = 'UNKNOWN'
        title = $Title
        job_category = 'IT'
        location = [pscustomobject]@{ label = 'Muenchen'; city = 'Muenchen'; region = 'Bayern'; country = 'DE'; target_area = 'MUNICH' }
        work_model = 'ONSITE'
        employment_type = 'FULL_TIME'
        work_time = 'UNKNOWN'
        status = 'ACTIVE'
        published_at = '2026-09-17T08:00:00.000Z'
        first_seen = '2026-09-17T08:00:00.000Z'
        last_seen = '2026-09-18T08:00:00.000Z'
        changed_at = '2026-09-18T08:00:00.000Z'
        classification = [pscustomobject]@{ result = 'REJECTED'; priority = 'D'; score = 0; category = 'IT'; reasons = @(); rejected_reasons = @(); evaluated_at = '2026-09-18T08:00:00.000Z' }
        priority = 'D'
        requirements = @()
        description = 'Keine Remote-Arbeit und Budgetverantwortung.'
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

$fixturePath = Join-Path $PSScriptRoot 'fixtures\jobagent\job-change-history.json'
$fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json -Depth 30
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-09-18T10:00:00Z')
$document.companies = @(New-ChangeHistoryCompany)
$document.jobs = @(
    New-ChangeHistoryJob -JobId $fixture.job_id -Title 'Leitung IT und Plattformen'
    New-ChangeHistoryJob -JobId 'job:history_empty' -Title 'Stelle ohne Quellenchronik'
)
$document.job_sources = @([pscustomobject]@{
        source_id = 'source:history_fixture_career'; company_id = 'company:history_fixture'; source_type = 'CAREER_PAGE'
        url = 'https://fixture.example.invalid/jobs'; canonical_url = 'https://fixture.example.invalid/jobs'; is_official = $true
        verified_at = '2026-09-17T08:00:00.000Z'; verification_basis = 'CAREER_URL'; verification_evidence = @()
    })
$document.scan_runs = @([pscustomobject]@{
        scan_run_id = 'scanrun:ja053-browser'; started_at = '2026-09-18T08:00:00.000Z'; finished_at = '2026-09-18T08:00:00.000Z'
        status = 'SUCCESS'; company_ids = @('company:history_fixture'); artifact_paths = @(); errors = @()
    })
$document.scan_attempts = @([pscustomobject]@{
        scan_attempt_id = 'scanattempt:history_fixture'; scan_run_id = 'scanrun:ja053-browser'; company_id = 'company:history_fixture'
        source_id = 'source:history_fixture_career'; started_at = '2026-09-18T08:00:00.000Z'; finished_at = '2026-09-18T08:00:00.000Z'
        status = 'SUCCESS'; adapter = 'fixture'; error_class = 'NONE'; retry_recommendation = 'NONE'; http_status = 200; scan_complete = $true
    })
$document.job_snapshots = @($fixture.job_snapshots)
$events = [System.Collections.Generic.List[object]]::new()
foreach ($event in @($fixture.change_events)) { $events.Add($event) }
for ($index = 1; $index -le 19; $index++) {
    $events.Add([pscustomobject]@{
            change_event_id = ('change:history_fixture_browser_{0:d2}' -f $index)
            job_id = $fixture.job_id; scan_run_id = 'scanrun:ja053-browser'; event_type = 'JOB_UPDATED'
            created_at = '2026-09-17T09:00:00.000Z'; old_status = 'ACTIVE'; new_status = 'UPDATED'
            changed_fields = @('title'); reason = 'Synthetische 20/21-Grenzfixture.'
        })
}
$document.change_events = @($events.ToArray())

$report = New-JobAgentDailyReport -Document $document -ScanRunId 'scanrun:ja053-browser'
$history = @($report.sections.active_jobs | Where-Object job_id -eq $fixture.job_id)[0].change_history
Assert-True -Condition ($history.Count -eq 21) -Message 'JA-053-Browserfixture muss 21 Quellenchronikeintraege enthalten.'
Assert-True -Condition (@($history | Where-Object change_event_id -eq 'change:history_fixture_updated').Count -eq 1) -Message 'Die fachliche Aenderung fehlt in der Quellenchronikfixture.'

$runId = 'ja053-' + [guid]::NewGuid().ToString('N')
$evidenceRoot = Join-Path $root (Join-Path 'logs\jobagent\JA-053' $runId)
$artifactRoot = Join-Path $evidenceRoot 'playwright'
$htmlPath = Join-Path $evidenceRoot 'change-history.html'
$evidencePath = Join-Path $evidenceRoot 'change-cases.json'
$reportUrl = 'http://127.0.0.1:8500/logs/jobagent/JA-053/' + $runId + '/change-history.html'
Write-Utf8File -Path $htmlPath -Content (ConvertTo-JobAgentDailyReportHtml -Report $report)
$response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 10
Assert-True -Condition ($response.StatusCode -eq 200) -Message 'JA-053-Report ist nicht ueber den CI-Devserver erreichbar.'
[IO.Directory]::CreateDirectory($artifactRoot) | Out-Null

$script:playwrightRunEnvironment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $root -RunId $runId
$browserConfigPath = Join-Path $artifactRoot 'playwright-cli.config.json'
Write-Utf8File -Path $browserConfigPath -Content (@{ browser = @{ launchOptions = @{ channel = 'chrome'; headless = $true; args = @('--no-sandbox') }; contextOptions = @{ locale = 'de-DE'; timezoneId = 'UTC' } } } | ConvertTo-Json -Depth 10)
$sessionName = 'jobagent-ja053-' + [guid]::NewGuid().ToString('N')
$screenshots = [System.Collections.Generic.List[string]]::new()
$geometry = [System.Collections.Generic.List[object]]::new()
$network = ''
$sessionErrors = @()

try {
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, '--config', $browserConfigPath, 'open', $reportUrl) | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { window.__ja053Errors=[]; addEventListener("error",event=>window.__ja053Errors.push(String(event.message||event.error||"error"))); addEventListener("unhandledrejection",event=>window.__ja053Errors.push(String(event.reason||"unhandledrejection"))); return JSON.stringify({ready:true}); }') | Out-Null

    $emptyDetail = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Chronikleerzustand' -Script 'async () => { location.hash="#view=jobs&job=job%3Ahistory_empty"; await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))); const section=document.querySelector(".job-change-history"); return JSON.stringify({section:!!section,details:section?section.querySelectorAll("details").length:-1,text:section?section.textContent:""}); }'
    Assert-True -Condition ([bool]$emptyDetail.section -and [int]$emptyDetail.details -eq 0) -Message 'Der Chronikleerzustand muss ohne aufklappbare Ereignisse erscheinen.'
    Assert-True -Condition ($emptyDetail.text -match 'Keine belegten Inhaltsaenderungen archiviert') -Message 'Der Chronikleerzustand ist nicht eindeutig beschriftet.'

    $historyDetail = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Quellenchronik 20/21' -Script 'async () => { location.hash="#view=jobs&job=job%3Ahistory_fixture"; await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))); await new Promise(resolve=>setTimeout(resolve,50)); const section=document.querySelector(".job-change-history"),entries=Array.from(section.querySelectorAll("details")),more=Array.from(section.querySelectorAll("button")).find(button=>button.textContent.includes("Weitere Aenderungen")); return JSON.stringify({total:entries.length,visible:entries.filter(entry=>!entry.hidden).length,hidden:entries.filter(entry=>entry.hidden).length,more:more&&more.textContent,visible_text:entries.filter(entry=>!entry.hidden).map(entry=>entry.textContent).join("\n"),raw_html_rendered:section&&section.querySelectorAll("p p").length}); }'
    Assert-True -Condition ([int]$historyDetail.total -eq 21 -and [int]$historyDetail.visible -eq 20 -and [int]$historyDetail.hidden -eq 1) -Message 'Die Quellenchronik muss initial exakt 20 von 21 Eintraegen zeigen.'
    Assert-True -Condition ($historyDetail.more -eq 'Weitere Aenderungen (1)') -Message 'Die explizite Erweiterungsaktion fuer den 21. Eintrag fehlt oder ist falsch beschriftet.'
    Assert-True -Condition ($historyDetail.visible_text -match 'Aenderung erkannt am' -and $historyDetail.visible_text -match 'Vorher: Keine Remote-Arbeit\.' -and $historyDetail.visible_text -match 'Nachher: Keine Remote-Arbeit und Budgetverantwortung\.') -Message 'Die sichtbaren Chronikeintraege zeigen keinen sicheren Vorher/Nachher-Text der fachlichen Aenderung.'
    Assert-True -Condition ([int]$historyDetail.raw_html_rendered -eq 0) -Message 'Quellenchronik hat Quell-HTML als DOM verschachtelt gerendert.'

    $keyboardOpen = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Chronik-Tastaturaktion' -Script '() => { const summary=Array.from(document.querySelectorAll(".job-change-history details summary")).find(item=>item.parentElement.textContent.includes("Keine Remote-Arbeit und Budgetverantwortung.")); if(!summary)throw new Error("Fachlicher Chronikeintrag fehlt"); summary.focus(); return JSON.stringify({focused:document.activeElement===summary}); }'
    Assert-True -Condition ([bool]$keyboardOpen.focused) -Message 'Der fachliche Chronikeintrag ist nicht per Tastatur fokussierbar.'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'Enter') | Out-Null
    $keyboardState = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Chronik-Tastaturaktion' -Script '() => { const entry=Array.from(document.querySelectorAll(".job-change-history details")).find(item=>item.textContent.includes("Keine Remote-Arbeit und Budgetverantwortung.")); return JSON.stringify({open:entry&&entry.open}); }'
    Assert-True -Condition ([bool]$keyboardState.open) -Message 'Enter klappt den fokussierten Chronikeintrag nicht auf.'

    $screenshotPath = Join-Path $artifactRoot 'JA-053-change-detail-1366.png'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'resize', 1366, 900) | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'screenshot', '--filename', $screenshotPath) | Out-Null
    Assert-True -Condition ((Test-Path -LiteralPath $screenshotPath) -and (Get-Item -LiteralPath $screenshotPath).Length -gt 10000) -Message 'Der JA-053-1366-Pixel-Screenshot fehlt oder ist unplausibel klein.'
    $screenshots.Add($screenshotPath)

    $historyMore = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Chronikvollstaendigkeit' -Script 'async () => { const section=document.querySelector(".job-change-history"),more=Array.from(section.querySelectorAll("button")).find(button=>button.textContent.includes("Weitere Aenderungen")); more.click(); await new Promise(resolve=>requestAnimationFrame(resolve)); const entries=Array.from(section.querySelectorAll("details")); return JSON.stringify({total:entries.length,visible:entries.filter(entry=>!entry.hidden).length,more_exists:!!Array.from(section.querySelectorAll("button")).find(button=>button.textContent.includes("Weitere Aenderungen"))}); }'
    Assert-True -Condition ([int]$historyMore.total -eq 21 -and [int]$historyMore.visible -eq 21 -and -not [bool]$historyMore.more_exists) -Message 'Die Erweiterungsaktion muss den 21. Chronikeintrag ohne Datenverlust sichtbar machen.'

    foreach ($viewport in @(@{ width = 1920; height = 1080 }, @{ width = 1366; height = 900 }, @{ width = 800; height = 1024 }, @{ width = 390; height = 844 })) {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'resize', $viewport.width, $viewport.height) | Out-Null
        $measurement = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Chronikviewport $($viewport.width)" -Script '() => { const root=document.documentElement,section=document.querySelector(".job-change-history"),summaries=Array.from(section.querySelectorAll("summary")),overflow=summaries.filter(summary=>summary.scrollWidth>summary.clientWidth+1).length; return JSON.stringify({viewport:innerWidth,scroll_width:root.scrollWidth,summary_overflow:overflow,details:section.querySelectorAll("details").length}); }'
        Assert-True -Condition ([int]$measurement.scroll_width -le ([int]$measurement.viewport + 1) -and [int]$measurement.summary_overflow -eq 0 -and [int]$measurement.details -eq 21) -Message "Die Quellenchronik verletzt bei $($viewport.width) CSS-px den responsiven Layoutvertrag."
        $geometry.Add([pscustomobject]@{ viewport_width = $viewport.width; viewport_height = $viewport.height; measurement = $measurement })
    }
    $network = Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'requests')
    $externalHosts = @([regex]::Matches($network, '(?i)https?://(?<host>[^/\s]+)') | ForEach-Object { $_.Groups['host'].Value.ToLowerInvariant() } | Where-Object { $_ -ne '127.0.0.1:8500' -and $_ -ne 'gc.kis.v2.scr.kaspersky-labs.com' } | Sort-Object -Unique)
    Assert-True -Condition ($externalHosts.Count -eq 0) -Message ('Die Chronikbedienung hat eine externe Anfrage erzeugt: ' + ($externalHosts -join ', '))
    $sessionErrors = @(Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Chronikbrowserfehler' -Script '() => JSON.stringify(window.__ja053Errors || [])')
    Assert-True -Condition ($sessionErrors.Count -eq 0) -Message ('Browserfehler in der Quellenchronik: ' + ($sessionErrors -join '; '))
}
finally {
    try { Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'close') | Out-Null } catch { Write-Warning $_.Exception.Message }
    Remove-JobAgentPlaywrightRunEnvironment -RunEnvironment $script:playwrightRunEnvironment
}

$summary = [pscustomobject]@{
    status = 'ok'; data_mode = 'isolated_fixture'; report_url = $reportUrl; fixture = 'tests/fixtures/jobagent/job-change-history.json'
    history_entries = 21; initial_visible_entries = 20; screenshots = @($screenshots); geometry = @($geometry)
    browser = [pscustomobject]@{ requests = $network; console_or_page_errors = @($sessionErrors) }
    cases = @('zero_history_empty_state', 'twenty_of_twenty_one_initial_history', 'more_changes_reveals_all_entries', 'safe_plain_text_before_after', 'keyboard_disclosure', 'viewports_1920_1366_800_390', 'no_interaction_network_or_browser_errors')
}
Write-Utf8File -Path $evidencePath -Content ($summary | ConvertTo-Json -Depth 20)
$summary | ConvertTo-Json -Depth 20
