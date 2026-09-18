#requires -Version 7.4

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.PlaywrightEnvironment.psm1') -Force

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Content)
    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

function Invoke-JobAgentPlaywrightCli {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string[]]$Arguments)
    Invoke-JobAgentPlaywrightCliIsolated -RepositoryRoot $root -RunEnvironment $script:playwrightRunEnvironment -WorkingDirectory $WorkingDirectory -Arguments $Arguments
}

function Get-SessionValue {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string]$SessionName, [Parameter(Mandatory)][string]$Script, [Parameter(Mandatory)][string]$Case)
    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', $Script)
    $match = [regex]::Match($output, '(?ms)### Result\s*\r?\n(?<payload>.+?)\s*$')
    Assert-True -Condition $match.Success -Message "${Case}: Playwright-CLI lieferte kein Eval-Ergebnis."
    $value = $match.Groups['payload'].Value.Trim() | ConvertFrom-Json -Depth 30
    if ($value -is [string]) { return $value | ConvertFrom-Json -Depth 30 }
    return $value
}

$document = Get-Content -Raw -LiteralPath (Join-Path $root 'tests\fixtures\jobagent\valid.json') | ConvertFrom-Json -Depth 100
$run = $document.scan_runs[0]
$run.scan_run_id = 'scanrun:calendar-browser'
$run.started_at = '2026-10-25T00:30:00.000Z'
$run.finished_at = '2026-10-26T09:00:00.000Z'
$document.companies[0].next_scan_at = '2026-10-27T12:00:00.000Z'
$document.change_events = @()
$attempts = [Collections.Generic.List[object]]::new()
foreach ($index in 1..51) {
    $status = if ($index -le 2) { 'FAILED' } else { 'SUCCESS' }
    $startedAt = if ($index -eq 1) { '2026-10-25T00:30:00.000Z' } elseif ($index -eq 2) { '2026-10-25T01:30:00.000Z' } else { '2026-10-25T12:00:00.000Z' }
    $attempts.Add([pscustomobject]@{
            scan_attempt_id = "attempt:calendar-$index"
            scan_run_id = 'scanrun:calendar-browser'
            company_id = [string]$document.companies[0].company_id
            source_id = [string]$document.job_sources[0].source_id
            started_at = $startedAt
            finished_at = $startedAt
            status = $status
            adapter = 'fixture'
            error_class = if ($status -eq 'FAILED') { 'TIMEOUT' } else { 'NONE' }
            retry_recommendation = if ($status -eq 'FAILED') { 'RETRY_NEXT_RUN' } else { 'NONE' }
            http_status = if ($status -eq 'FAILED') { 504 } else { 200 }
            scan_complete = ($status -eq 'SUCCESS')
        })
}
$document.scan_attempts = @($attempts.ToArray())
$report = New-JobAgentDailyReport -Document $document -ScanRunId 'scanrun:calendar-browser'
$html = ConvertTo-JobAgentDailyReportHtml -Report $report

$runId = 'ja054-calendar-' + [guid]::NewGuid().ToString('N')
$evidenceRoot = Join-Path $root (Join-Path 'logs\jobagent\JA-054' $runId)
$artifactRoot = Join-Path $evidenceRoot 'playwright'
$htmlPath = Join-Path $evidenceRoot 'calendar-audit.html'
$evidencePath = Join-Path $root 'logs\jobagent\JA-054\calendar-cases.json'
$reportUrl = 'http://127.0.0.1:8500/logs/jobagent/JA-054/' + $runId + '/calendar-audit.html'
Write-Utf8File -Path $htmlPath -Content $html
$response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 10
Assert-True -Condition ($response.StatusCode -eq 200) -Message 'Kalender-Browserfixture ist nicht über den lokalen Devserver erreichbar.'

$script:playwrightRunEnvironment = New-JobAgentPlaywrightRunEnvironment -RepositoryRoot $root -RunId $runId
$browserConfigPath = Join-Path $artifactRoot 'playwright-cli.config.json'
Write-Utf8File -Path $browserConfigPath -Content (@{
        browser = @{
            launchOptions = @{ channel = 'chrome'; headless = $true; args = @('--no-sandbox') }
            contextOptions = @{ locale = 'de-DE'; timezoneId = 'UTC' }
        }
    } | ConvertTo-Json -Depth 10)

$sessionName = 'jobagent-calendar-' + [guid]::NewGuid().ToString('N')
$screenshots = [Collections.Generic.List[string]]::new()
$sessionOpened = $false
try {
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, '--config', $browserConfigPath, 'open', $reportUrl) | Out-Null
    $sessionOpened = $true
    $initial = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Kalender initialisieren' -Script '() => { performance.clearResourceTimings(); localStorage.clear(); location.hash="#view=calendar&calendarDate=2026-10-25&calendarMode=month"; return new Promise(resolve=>setTimeout(()=>resolve(JSON.stringify({days:document.querySelectorAll(".calendar-day").length,selected:document.querySelector(".calendar-day.is-selected")?.dataset.calendarDate,legend:document.querySelector(".calendar-legend")?.textContent,details:document.querySelector(".calendar-details")?.textContent,timezone:Intl.DateTimeFormat().resolvedOptions().timeZone})),50)); }'
    Assert-True -Condition ([int]$initial.days -eq 42) -Message 'Monatsansicht hat nicht exakt 42 Tagesfelder.'
    Assert-True -Condition ($initial.selected -eq '2026-10-25') -Message 'Kalender uebernimmt das Datum aus dem Hash nicht.'
    Assert-True -Condition ($initial.legend -match 'Abruf' -and $initial.legend -match 'Geplante Pruefung' -and $initial.legend -match 'Eigener Termin') -Message 'Kalenderlegende benennt nicht alle Ereignisarten.'
    Assert-True -Condition ($initial.details -match '51 Abrufe' -and $initial.details -match '2 Fehler') -Message 'Tagesdetails zaehlen Retryversuche oder Fehler nicht korrekt.'

    $dstAndPaging = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Sommerzeit und Tagesdetail-Paginierung' -Script '() => { const labels=Array.from(document.querySelectorAll(".calendar-event p")).map(node=>node.textContent); const pages=Array.from(document.querySelectorAll(".calendar-details nav button")).map(node=>node.textContent); document.querySelector(".calendar-details nav button:nth-child(2)").click(); return new Promise(resolve=>setTimeout(()=>resolve(JSON.stringify({labels,pages,current:document.querySelector(".calendar-details nav button[aria-current=page]")?.textContent,visible:document.querySelectorAll(".calendar-event").length})),50)); }'
    Assert-True -Condition (@($dstAndPaging.labels | Where-Object { $_ -match '02:30' }).Count -eq 2) -Message 'Die zwei lokalen 02:30-Sommerzeitzeitpunkte sind nicht getrennt sichtbar.'
    Assert-True -Condition (@($dstAndPaging.pages).Count -eq 2 -and $dstAndPaging.current -eq '2' -and [int]$dstAndPaging.visible -eq 1) -Message 'Die 50/51-Paginierung der Tagesdetails ist fehlerhaft.'

    $week = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Wochenansicht und Tastatur' -Script '() => { location.hash="#view=calendar&calendarDate=2028-02-29&calendarMode=week"; return new Promise(resolve=>setTimeout(()=>{const selected=document.querySelector(".calendar-day.is-selected"); selected.focus(); selected.dispatchEvent(new KeyboardEvent("keydown",{key:"Home",bubbles:true})); setTimeout(()=>{const home=document.activeElement?.dataset.calendarDate; document.activeElement.dispatchEvent(new KeyboardEvent("keydown",{key:"End",bubbles:true})); setTimeout(()=>resolve(JSON.stringify({days:document.querySelectorAll(".calendar-day").length,home,end:document.activeElement?.dataset.calendarDate,selected:document.querySelector(".calendar-day.is-selected")?.dataset.calendarDate})),20)},20)},50)); }'
    Assert-True -Condition ([int]$week.days -eq 7 -and $week.home -eq '2028-02-28' -and $week.end -eq '2028-03-05') -Message 'Wochenansicht oder Home/End-Tastaturnavigation ist nicht Montag-basiert.'

    $navigation = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Reload Zurueck Vor und lokale Termine' -Script '() => { const api=window.JobAgentUserState,job={job_id:"job:calendar",title:"Kalender-Test",company:"Beispielfirma"}; api.upsertTask(localStorage,job,{task_id:"task-calendar-open",type:"FOLLOW_UP",title:"Offener Termin",local_date:"2028-02-29",status:"OPEN"},"2026-10-26T09:00:00.000Z"); api.upsertTask(localStorage,job,{task_id:"task-calendar-done",type:"FOLLOW_UP",title:"Erledigter Termin",local_date:"2028-02-29",status:"DONE"},"2026-10-26T09:00:01.000Z"); location.hash="#view=calendar&calendarDate=2028-02-29&calendarMode=month&calendarStatus=OPEN"; return new Promise(resolve=>setTimeout(()=>{const before=location.hash; history.back(); setTimeout(()=>{const back=location.hash; history.forward(); setTimeout(()=>resolve(JSON.stringify({before,back,forward:location.hash,text:document.getElementById("jobagent-calendar").textContent,resources:performance.getEntriesByType("resource").map(entry=>entry.name)})),50)},50)},50)); }'
    Assert-True -Condition ($navigation.before -eq $navigation.forward -and $navigation.text -match 'Offener Termin' -and $navigation.text -notmatch 'Erledigter Termin') -Message 'Lokale Aufgabenfilter oder Verlaufnavigation ist fehlerhaft.'
    $externalResources = @($navigation.resources | Where-Object { $_ -notmatch '^https?://(127\.0\.0\.1|localhost):8500/' })
    $unexpectedResources = @($externalResources | Where-Object { $_ -notmatch '^https?://gc\.kis\.v2\.scr\.kaspersky-labs\.com/' })
    Assert-True -Condition ($unexpectedResources.Count -eq 0) -Message ('Kalenderbedienung hat eine unerwartete externe Netzwerkressource geladen: ' + ($unexpectedResources -join ', '))

    foreach ($viewport in @(
            [pscustomobject]@{ width = 1920; height = 1080; name = 'JA-054-calendar-1920.png' },
            [pscustomobject]@{ width = 1366; height = 900; name = 'JA-054-calendar-1366.png' },
            [pscustomobject]@{ width = 800; height = 1024; name = 'JA-054-calendar-800.png' },
            [pscustomobject]@{ width = 390; height = 844; name = 'JA-054-calendar-390.png' }
        )) {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'resize', $viewport.width, $viewport.height) | Out-Null
        $measurement = Get-SessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Viewport $($viewport.width)" -Script '() => JSON.stringify({width:window.innerWidth,scroll:document.documentElement.scrollWidth,small:Array.from(document.querySelectorAll("button,select")).filter(node=>{const r=node.getBoundingClientRect();return !node.hidden&&r.width>0&&r.height>0&&(r.width<44||r.height<44)}).length})'
        Assert-True -Condition ([int]$measurement.scroll -le [int]$measurement.width -and [int]$measurement.small -eq 0) -Message "Viewport $($viewport.width): Horizontaloverflow oder zu kleines Ziel."
        $screenshot = Join-Path $root (Join-Path 'doc\roadmap-screenshots' $viewport.name)
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'screenshot', '#jobagent-calendar', '--filename', $screenshot) | Out-Null
        Assert-True -Condition ((Test-Path -LiteralPath $screenshot) -and (Get-Item -LiteralPath $screenshot).Length -gt 5000) -Message "Viewport $($viewport.width): Screenshot fehlt oder ist unplausibel klein."
        $screenshots.Add($screenshot)
    }
}
finally {
    try {
        if ($sessionOpened) { Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'close') | Out-Null }
    }
    finally { Remove-JobAgentPlaywrightRunEnvironment -RunEnvironment $script:playwrightRunEnvironment }
}

$evidence = [pscustomobject]@{
    schema_version = 'jobagent/calendar-cases/v1'
    executed_at = [datetimeoffset]::Now.ToString('o')
    scope = 'JA-054 lokaler Kalender-Browser- und Viewport-Audit'
    result = 'passed'
    report_url = $reportUrl
    environmental_external_hosts = @($externalResources | ForEach-Object { ([uri]$_).Host } | Sort-Object -Unique)
    screenshots = @($screenshots.ToArray())
    cases = @(
        'month_42_days_and_monday_start', 'week_7_days_and_leap_day', 'dst_two_local_0230_offsets',
        'retry_oracle_and_midnight_projection', 'day_detail_50_51_paging', 'local_open_done_tasks',
        'reload_back_forward_and_no_external_network', 'viewport_1920_1366_800_390'
    )
}
Write-Utf8File -Path $evidencePath -Content ($evidence | ConvertTo-Json -Depth 20)
$evidence | ConvertTo-Json -Depth 20
