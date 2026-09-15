#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$FixtureOnly
)

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

    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

function ConvertTo-JobAgentFixtureJson {
    param([Parameter(Mandatory)][object]$Document)

    return ($Document | ConvertTo-Json -Depth 100)
}

function Invoke-JobAgentPlaywrightCli {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $npxCommand = Get-Command -Name 'npx.cmd' -ErrorAction SilentlyContinue
    if ($null -eq $npxCommand) {
        throw 'npx.cmd fehlt; der Browser-Audit benoetigt die Playwright-CLI.'
    }

    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = @(& $npxCommand.Source --yes --package '@playwright/cli' playwright-cli @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw ('Playwright-CLI fehlgeschlagen: ' + ($output -join [Environment]::NewLine))
        }
        return ($output -join [Environment]::NewLine)
    }
    finally {
        Pop-Location
    }
}

function Get-JobAgentCliSnapshot {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName
    )

    return Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'snapshot')
}

function Get-JobAgentCliRef {
    param(
        [Parameter(Mandatory)][string]$Snapshot,
        [Parameter(Mandatory)][string[]]$Roles,
        [Parameter(Mandatory)][string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    foreach ($role in $Roles) {
        $pattern = '(?m)\b' + [regex]::Escape($role) + '\s+"' + $escapedName + '"[^\r\n]*\[ref=(e\d+)\]'
        $match = [regex]::Match($Snapshot, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    throw "Playwright-Snapshot enthaelt kein steuerbares Element '$Name' mit Rollen $($Roles -join ', ')."
}

function Assert-JobAgentSnapshotContains {
    param(
        [Parameter(Mandatory)][string]$Snapshot,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Case
    )

    Assert-True -Condition $Snapshot.Contains($Expected) -Message "${Case}: erwarteter Browserinhalt fehlt: $Expected"
}

function New-TestLocation {
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$City = 'Muenchen',
        [string]$Region = 'Bayern',
        [string]$TargetArea = 'MUNICH'
    )

    [pscustomobject]@{
        label = $Label
        city = $City
        region = $Region
        country = 'DE'
        target_area = $TargetArea
    }
}

function New-TestCompany {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][object]$Location
    )

    $suffix = $Number.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        company_id = "company:fixture_$suffix"
        canonical_name = "Firma $suffix"
        canonical_domain = "firma-$suffix.example.invalid"
        official_website_url = "https://firma-$suffix.example.invalid/"
        career_url = "https://firma-$suffix.example.invalid/karriere"
        aliases = @()
        locations = @($Location)
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 50
        next_scan_at = '2026-09-16T10:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = $null
        created_at = '2026-09-01T09:00:00.000Z'
        updated_at = '2026-09-01T09:00:00.000Z'
        last_successful_scan_at = '2026-09-01T09:00:00.000Z'
    }
}

function New-TestJob {
    param(
        [Parameter(Mandatory)][string]$JobId,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object]$Location,
        [string]$Category = 'Allgemein',
        [string]$WorkModel = 'ONSITE',
        [string]$EmploymentType = 'FULL_TIME',
        [string]$WorkTime = 'UNKNOWN',
        [string]$PublishedAt = '2026-09-14T10:00:00.000Z',
        [string]$FirstSeen = '2026-09-14T10:00:00.000Z'
    )

    [pscustomobject]@{
        job_id = $JobId
        company_id = $CompanyId
        official_url = 'https://jobs.example.invalid/' + $JobId.Replace(':', '/')
        alternative_official_urls = @()
        source_id = 'UNKNOWN'
        external_job_id = $JobId
        ats_job_id = 'UNKNOWN'
        title = $Title
        job_category = $Category
        location = $Location
        work_model = $WorkModel
        employment_type = $EmploymentType
        work_time = $WorkTime
        status = 'ACTIVE'
        published_at = $PublishedAt
        first_seen = $FirstSeen
        last_seen = '2026-09-15T10:00:00.000Z'
        changed_at = '2026-09-15T10:00:00.000Z'
        classification = [pscustomobject]@{
            result = 'REJECTED'
            priority = 'D'
            score = 90
            category = $Category
            reasons = @('Fixture fuer den lokalen Browser-Audit.')
            rejected_reasons = @()
            evaluated_at = '2026-09-15T10:00:00.000Z'
        }
        priority = 'D'
        requirements = @()
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

$scanRunId = 'scanrun:ui001-browser-audit'
$uiContractPath = Join-Path $root 'tests\fixtures\jobagent\qa-004-ui-contract.json'
Assert-True -Condition (Test-Path -LiteralPath $uiContractPath -PathType Leaf) -Message 'QA-004-UI-Vertragsfixture fehlt.'
$uiContract = Get-Content -LiteralPath $uiContractPath -Raw | ConvertFrom-Json -Depth 20
Assert-True -Condition ($uiContract.schema_version -eq 'jobagent-ui-contract/v1') -Message 'QA-004-UI-Vertragsfixture hat eine ungueltige Schema-Version.'
$referenceTime = [datetime]$uiContract.reference_time
$munich = New-TestLocation -Label 'Muenchen'
$freising = New-TestLocation -Label 'Freising' -City 'Freising' -Region 'Landkreis Freising' -TargetArea 'FREISING'
$unknown = New-TestLocation -Label 'UNKNOWN' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'UNKNOWN'
$munich20Km = New-TestLocation -Label 'Dachau bei Muenchen' -City 'Dachau' -Region 'Bayern' -TargetArea 'MUNICH_20KM'
$freisingCounty = New-TestLocation -Label 'Moosburg' -City 'Moosburg' -Region 'Landkreis Freising' -TargetArea 'FREISING'
$freisingUnspecified = New-TestLocation -Label 'Freising Gebiet' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'FREISING'
$remoteTarget = New-TestLocation -Label 'Remote mit Muenchenbezug' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'REMOTE_WITH_TARGET_REFERENCE'
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-09-15T10:00:00Z')
$document.companies = @(1..251 | ForEach-Object { New-TestCompany -Number $_ -Location $munich })
$document.jobs = @(1..251 | ForEach-Object {
        $suffix = $_.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
        New-TestJob -JobId "job:company_$suffix" -CompanyId "company:fixture_$suffix" -Title "Position $suffix" -Location $munich
    })
$document.jobs += @(
    New-TestJob -JobId 'job:munich-accounting' -CompanyId 'company:fixture_001' -Title 'Buchhalterin Muenchen' -Location $munich -Category 'Buchhaltung'
    New-TestJob -JobId 'job:freising-pflege' -CompanyId 'company:fixture_002' -Title 'Pflegefachkraft Freising' -Location $freising -Category 'Pflege' -WorkModel 'HYBRID' -EmploymentType 'PART_TIME'
    New-TestJob -JobId 'job:part-time-hybrid' -CompanyId 'company:fixture_003' -Title 'Hybrid Teilzeit Beraterin' -Location $munich -Category 'Beratung' -WorkModel 'HYBRID' -EmploymentType 'PART_TIME'
    New-TestJob -JobId 'job:unknown' -CompanyId 'company:fixture_004' -Title 'Unklare Position' -Location $unknown -Category 'UNKNOWN' -WorkModel 'UNKNOWN' -EmploymentType 'UNKNOWN'
    New-TestJob -JobId 'job:umlaut' -CompanyId 'company:fixture_005' -Title 'Bürokauffrau Muenchen' -Location $munich -Category 'Büro'
    New-TestJob -JobId 'job:remote-contract' -CompanyId 'company:fixture_006' -Title 'Remote Vertrag Spezialistin' -Location $remoteTarget -Category 'Beratung' -WorkModel 'REMOTE' -EmploymentType 'CONTRACT'
    New-TestJob -JobId 'job:munich20-permanent' -CompanyId 'company:fixture_007' -Title 'Dachau Unbefristet' -Location $munich20Km -Category 'Verwaltung' -EmploymentType 'PERMANENT'
    New-TestJob -JobId 'job:freising-county-internship' -CompanyId 'company:fixture_008' -Title 'Moosburg Praktikum' -Location $freisingCounty -Category 'Ausbildung' -EmploymentType 'INTERNSHIP'
    New-TestJob -JobId 'job:freising-unspecified' -CompanyId 'company:fixture_009' -Title 'Freising Gebiet Stelle' -Location $freisingUnspecified -Category 'Allgemein'
    New-TestJob -JobId 'job:age-seven' -CompanyId 'company:fixture_010' -Title 'Grenze Sieben Tage' -Location $munich -PublishedAt '2026-09-08T10:00:00.000Z'
    New-TestJob -JobId 'job:age-thirty' -CompanyId 'company:fixture_011' -Title 'Grenze Dreissig Tage' -Location $munich -PublishedAt '2026-08-16T10:00:00.000Z'
    New-TestJob -JobId 'job:age-older' -CompanyId 'company:fixture_012' -Title 'Aelter Als Dreissig Tage' -Location $munich -PublishedAt '2026-08-15T10:00:00.000Z'
    New-TestJob -JobId 'job:age-unknown' -CompanyId 'company:fixture_013' -Title 'Datum Unbekannt' -Location $munich -PublishedAt 'UNKNOWN' -FirstSeen 'UNKNOWN'
)
$document.job_sources = @()
$document.scan_runs = @([pscustomobject]@{
        scan_run_id = $scanRunId
        started_at = '2026-09-15T10:00:00.000Z'
        finished_at = '2026-09-15T10:00:00.000Z'
        status = 'SUCCESS'
        company_ids = @($document.companies.company_id)
        artifact_paths = @()
        errors = @()
    })
$document.scan_attempts = @()
$document.job_snapshots = @()
$document.change_events = @()

$documentBefore = ConvertTo-JobAgentFixtureJson -Document $document
$report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
$expectedJobIds = @('job:company_251', 'job:munich-accounting', 'job:freising-pflege', 'job:part-time-hybrid', 'job:unknown', 'job:umlaut', 'job:remote-contract', 'job:munich20-permanent', 'job:freising-county-internship', 'job:freising-unspecified', 'job:age-seven', 'job:age-thirty', 'job:age-older', 'job:age-unknown')
$actualJobIds = @($report.sections.active_jobs.job_id)
foreach ($expectedJobId in $expectedJobIds) {
    Assert-True -Condition ($actualJobIds -contains $expectedJobId) -Message "Fixture-Report enthaelt erwartete Stellen-ID nicht: $expectedJobId"
}
Assert-True -Condition ($report.sections.companies.Count -eq 251) -Message 'Fixture-Report muss 251 Firmen enthalten.'
Assert-True -Condition ($report.sections.active_jobs.Count -eq 264) -Message 'Fixture-Report muss 264 aktive Stellen enthalten.'

$actualAreaValues = @($report.sections.active_jobs | ForEach-Object { @($_.area_facets) } | Select-Object -Unique)
foreach ($expectedAreaValue in @($uiContract.area_values)) {
    Assert-True -Condition ($actualAreaValues -contains $expectedAreaValue) -Message "Gebietsfixture fuer $expectedAreaValue fehlt."
}
foreach ($facet in @(
        @{ property = 'work_model'; values = @($uiContract.work_model_values) },
        @{ property = 'employment_type'; values = @($uiContract.employment_type_values) },
        @{ property = 'work_time'; values = @($uiContract.work_time_values) }
    )) {
    $actualValues = @($report.sections.active_jobs | ForEach-Object { [string]$_.$($facet.property) } | Select-Object -Unique)
    foreach ($expectedValue in $facet.values) {
        Assert-True -Condition ($actualValues -contains $expectedValue) -Message "Facetfixture $($facet.property) fuer $expectedValue fehlt."
    }
}
$jobsById = @{}
foreach ($job in @($report.sections.active_jobs)) { $jobsById[[string]$job.job_id] = $job }
foreach ($ageExpectation in @(
        @{ job_id = 'job:age-seven'; age_days = '7' },
        @{ job_id = 'job:age-thirty'; age_days = '30' },
        @{ job_id = 'job:age-older'; age_days = '31' },
        @{ job_id = 'job:age-unknown'; age_days = 'UNKNOWN' }
    )) {
    Assert-True -Condition ([string]$jobsById[$ageExpectation.job_id].age_days -eq $ageExpectation.age_days) -Message "Alters-Grenzfixture $($ageExpectation.job_id) hat keinen stabilen Wert $($ageExpectation.age_days)."
}

foreach ($boundaryCount in @($uiContract.boundary_counts)) {
    $boundaryDocument = New-JobAgentEmptyDocument -GeneratedAt $referenceTime
    $boundaryDocument.scan_runs = @([pscustomobject]@{
            scan_run_id = 'scanrun:boundary'
            started_at = $uiContract.reference_time
            finished_at = $uiContract.reference_time
            status = 'SUCCESS'
            company_ids = @()
            artifact_paths = @()
            errors = @()
        })
    if ([int]$boundaryCount -eq 0) {
        $boundaryDocument.companies = @()
        $boundaryDocument.jobs = @()
    }
    else {
        $boundaryDocument.companies = @(1..[int]$boundaryCount | ForEach-Object { New-TestCompany -Number $_ -Location $munich })
        $boundaryDocument.jobs = @(1..[int]$boundaryCount | ForEach-Object {
                $suffix = $_.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
                New-TestJob -JobId "job:boundary_$suffix" -CompanyId "company:fixture_$suffix" -Title "Grenzposition $suffix" -Location $munich
            })
    }
    $expectedPages = [Math]::Max(1, [Math]::Ceiling([int]$boundaryCount / 50.0))
    Assert-True -Condition (@($boundaryDocument.companies).Count -eq [int]$boundaryCount) -Message "Firmen-Grenzfixture $boundaryCount ist nicht stabil."
    Assert-True -Condition (@($boundaryDocument.jobs).Count -eq [int]$boundaryCount) -Message "Stellen-Grenzfixture $boundaryCount ist nicht stabil."
    Assert-True -Condition ($expectedPages -eq [Math]::Max(1, [Math]::Ceiling(@($boundaryDocument.jobs).Count / 50.0))) -Message "Seitengrenzfixture $boundaryCount ist nicht stabil."
}

if ($FixtureOnly) {
    [pscustomobject]@{
        status = 'ok'
        mode = 'isolated_fixture_only'
        companies = 251
        jobs = 264
        boundary_counts = @($uiContract.boundary_counts)
        cases = @('qa004_boundary_fixtures_0_1_49_50_51_250_251', 'qa004_all_offered_facet_values_and_age_boundaries')
    } | ConvertTo-Json -Depth 10
    return
}

$htmlPath = Join-Path $root 'html\jobagent\ui-001-browser-audit.html'
$artifactRoot = Join-Path $root 'output\playwright'
$evidencePath = Join-Path $root 'logs\jobagent\ui-001-browser-audit.json'
$reportUrl = 'http://127.0.0.1:8500/html/jobagent/ui-001-browser-audit.html'
Write-Utf8File -Path $htmlPath -Content (ConvertTo-JobAgentDailyReportHtml -Report $report)

$response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 10
Assert-True -Condition ($response.StatusCode -eq 200) -Message 'Browser-Audit-Report ist nicht über den CI-Devserver erreichbar.'

if (-not (Test-Path -LiteralPath $artifactRoot)) {
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
}

$sessionName = 'jobagent-ui001-' + [guid]::NewGuid().ToString('N')
$screenshots = [System.Collections.Generic.List[string]]::new()
try {
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'open', $reportUrl) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'vollstaendiger Stellenbestand'

    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Position 251') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Freitext und Firma hinter der Altgrenze'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Position 251' -Case 'Stelle hinter der Altgrenze'

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'go-back') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Ruecknavigation'

    $areaRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Gebiet'
    $workModelRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Arbeitsmodell'
    $employmentTypeRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Anstellungsart'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $areaRef, 'FREISING_CITY') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $workModelRef, 'HYBRID') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $employmentTypeRef, 'PART_TIME') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Freising Pflege Teilzeit Hybrid'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Pflegefachkraft Freising' -Case 'Freising Pflege Teilzeit Hybrid'

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Filter-Reset'

    foreach ($facetCase in @(
            @{ control = 'Gebiet'; value = 'MUNICH'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Gebiet'; value = 'MUNICH_20KM'; expected = 'Dachau Unbefristet' },
            @{ control = 'Gebiet'; value = 'FREISING_CITY'; expected = 'Pflegefachkraft Freising' },
            @{ control = 'Gebiet'; value = 'FREISING_COUNTY'; expected = 'Moosburg Praktikum' },
            @{ control = 'Gebiet'; value = 'FREISING_UNSPECIFIED'; expected = 'Freising Gebiet Stelle' },
            @{ control = 'Gebiet'; value = 'REMOTE_WITH_TARGET_REFERENCE'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Gebiet'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Arbeitsmodell'; value = 'REMOTE'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Arbeitsmodell'; value = 'HYBRID'; expected = 'Hybrid Teilzeit Beraterin' },
            @{ control = 'Arbeitsmodell'; value = 'ONSITE'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Arbeitsmodell'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Anstellungsart'; value = 'FULL_TIME'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Anstellungsart'; value = 'PART_TIME'; expected = 'Hybrid Teilzeit Beraterin' },
            @{ control = 'Anstellungsart'; value = 'CONTRACT'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Anstellungsart'; value = 'PERMANENT'; expected = 'Dachau Unbefristet' },
            @{ control = 'Anstellungsart'; value = 'INTERNSHIP'; expected = 'Moosburg Praktikum' },
            @{ control = 'Anstellungsart'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Arbeitszeit'; value = 'UNKNOWN'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Aktualitaet'; value = '7'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Aktualitaet'; value = '30'; expected = 'Grenze Dreissig Tage' },
            @{ control = 'Aktualitaet'; value = 'older'; expected = 'Aelter Als Dreissig Tage' },
            @{ control = 'Aktualitaet'; value = 'UNKNOWN'; expected = 'Datum Unbekannt' }
        )) {
        $controlRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name $facetCase.control
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $controlRef, $facetCase.value) | Out-Null
        $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected $facetCase.expected -Case ("Facet $($facetCase.control)=$($facetCase.value)")

        $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
        $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case ("Reset nach Facet $($facetCase.control)=$($facetCase.value)")
    }

    $workModelRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Arbeitsmodell'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $workModelRef, 'UNKNOWN') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Unklare Position' -Case 'UNKNOWN-Auswahl'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'UNKNOWN-Auswahl'

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Burokauffrau') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Bürokauffrau Muenchen' -Case 'Unicode-normalisierte Umlautsuche'

    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'keine-passende-stelle') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Keine Treffer im angezeigten Bestand.' -Case 'Nulltreffer'

    $companiesTabRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('tab', 'button') -Name 'Firmen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $companiesTabRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 251 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'vollstaendiger Firmenbestand'

    $jobsTabRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('tab', 'button') -Name 'Stellen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $jobsTabRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $pageSixRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name '6'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $pageSixRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Position 251' -Case 'Pagination hinter der Altgrenze'

    $searchHeadingRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('heading') -Name 'Firmen und Stellen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'hover', $searchHeadingRef) | Out-Null
    foreach ($width in 390, 800, 1366, 1920) {
        $screenshotPath = Join-Path $artifactRoot ("ui-001-browser-audit-$width.png")
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'resize', $width, 2200) | Out-Null
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'screenshot', '--filename', $screenshotPath) | Out-Null
        Assert-True -Condition (Test-Path -LiteralPath $screenshotPath) -Message "Viewport-Screenshot fehlt: $width px."
        Assert-True -Condition ((Get-Item -LiteralPath $screenshotPath).Length -gt 10000) -Message "Viewport-Screenshot ist unplausibel klein: $width px."
        $screenshots.Add($screenshotPath)
    }

    $network = Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'requests')
    Assert-True -Condition ($network -notmatch '(?i)(/api/|daily-run|acquisition|jobagent/store)') -Message 'Filterinteraktion hat einen unzulaessigen API-, Joblauf- oder Store-Request erzeugt.'
}
finally {
    try {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'close') | Out-Null
    }
    catch {
        Write-Warning ('Playwright-Sitzung konnte nicht geschlossen werden: ' + $_.Exception.Message)
    }
}

$documentAfter = ConvertTo-JobAgentFixtureJson -Document $document
Assert-True -Condition ($documentBefore -eq $documentAfter) -Message 'Die lokale Filterinteraktion hat die isolierte Fixture mutiert.'

$summary = [pscustomobject]@{
    status = 'ok'
    data_mode = 'isolated_fixture'
    report_url = $reportUrl
    companies = 251
    jobs = 264
    expected_job_ids = $expectedJobIds
    screenshots = @($screenshots.ToArray())
    cases = @(
        'all_companies_and_jobs_reachable_beyond_250',
        'freising_pflegerische_teilzeit_hybrid_combination',
        'unknown_filter',
        'qa004_boundary_fixtures_0_1_49_50_51_250_251',
        'qa004_all_offered_facet_values_and_age_boundaries',
        'unicode_free_text_search',
        'empty_result',
        'reset_and_browser_back_navigation',
        'local_filter_does_not_mutate_fixture_or_call_job_api',
        'viewports_390_800_1366_1920'
    )
}
Write-Utf8File -Path $evidencePath -Content ($summary | ConvertTo-Json -Depth 10)
$summary | ConvertTo-Json -Depth 10
