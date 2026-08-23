#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$OutputPath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][AllowNull()][string]$FixturePath = $null
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)
$resolvedSourceRegistryPath = if ([IO.Path]::IsPathRooted($SourceRegistryPath)) {
    $SourceRegistryPath
}
else {
    $projectLocalSourcePath = Join-Path $projectRoot $SourceRegistryPath
    if (Test-Path -LiteralPath $projectLocalSourcePath -PathType Leaf) {
        $projectLocalSourcePath
    }
    else {
        Join-Path $toolRoot $SourceRegistryPath
    }
}
$resolvedOutputPath = if ([IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $projectRoot $OutputPath }
$resolvedLogRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }

if (-not (Test-Path -LiteralPath $resolvedSourceRegistryPath -PathType Leaf)) {
    throw "Discovery-Quellenkatalog fehlt: $resolvedSourceRegistryPath"
}

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function New-DefaultDiscoveryHintSeed {
    param([Parameter(Mandatory)][object[]]$SearchMatrix)

    $byKey = @{}
    foreach ($search in $SearchMatrix) {
        $byKey[([string]$search.location + '|' + [string]$search.keyword)] = $search
    }

    @(
        [pscustomobject]@{ employer_name = 'BMW Group'; location = 'Muenchen'; industry_or_keyword = 'IT Operations'; source_id = 'source-registry:ba_jobsuche'; observed_url = 'https://www.arbeitsagentur.de/jobsuche/suche?was=IT%20Operations&wo=Muenchen'; search = $byKey['Muenchen|IT Operations'] }
        [pscustomobject]@{ employer_name = 'Siemens AG'; location = 'Muenchen'; industry_or_keyword = 'Digitalisierung'; source_id = 'source-registry:ba_jobsuche'; observed_url = 'https://www.arbeitsagentur.de/jobsuche/suche?was=Digitalisierung&wo=Muenchen'; search = $byKey['Muenchen|Digitalisierung'] }
        [pscustomobject]@{ employer_name = 'Flughafen Muenchen GmbH'; location = 'Freising'; industry_or_keyword = 'IT Security'; source_id = 'source-registry:make_it_in_germany_jobs'; observed_url = 'https://www.make-it-in-germany.com/en/working-in-germany/job-listings?location=Freising&keyword=IT%20Security'; search = $byKey['Freising|IT Security'] }
        [pscustomobject]@{ employer_name = 'Texas Instruments Deutschland GmbH'; location = 'Freising'; industry_or_keyword = 'Enterprise Applications'; source_id = 'source-registry:eures_jobseekers'; observed_url = 'https://eures.europa.eu/jobseekers_en?location=Freising&keywords=Enterprise%20Applications'; search = $byKey['Freising|Enterprise Applications'] }
        [pscustomobject]@{ employer_name = 'CANCOM SE'; location = 'Muenchen'; industry_or_keyword = 'Director IT'; source_id = 'source-registry:yourfirm'; observed_url = 'https://www.yourfirm.de/jobs/muenchen/director-it/'; search = $byKey['Muenchen|Director IT'] }
        [pscustomobject]@{ employer_name = 'Fraunhofer IVV'; location = 'Freising'; industry_or_keyword = 'CIO'; source_id = 'source-registry:emm_members'; observed_url = 'https://www.metropolregion-muenchen.eu/ueber-uns/mitglieder'; search = $byKey['Freising|CIO'] }
    )
}

$sourceRegistry = Get-Content -LiteralPath $resolvedSourceRegistryPath -Raw | ConvertFrom-Json -Depth 100
$allowedSourceIds = @($sourceRegistry.items | Where-Object {
        [string]$_.source_class -ne 'OFFICIAL_DIRECTORY' -and
        [string]$_.source_class -ne 'REJECTED' -and
        @('IMPORT_HINTS_ONLY', 'MANUAL_REVIEW_ONLY') -contains [string]$_.import_decision
    } | ForEach-Object { [string]$_.source_id })

$searchMatrix = @(Get-JobAgentCompanyDiscoveryHintSearchMatrix)
$rawHints = if (-not [string]::IsNullOrWhiteSpace($FixturePath)) {
    $resolvedFixturePath = if ([IO.Path]::IsPathRooted($FixturePath)) { $FixturePath } else { Join-Path $projectRoot $FixturePath }
    if (-not (Test-Path -LiteralPath $resolvedFixturePath -PathType Leaf)) {
        throw "Hint-Fixture fehlt: $resolvedFixturePath"
    }
    @((Get-Content -LiteralPath $resolvedFixturePath -Raw | ConvertFrom-Json -Depth 100).items)
}
else {
    @(New-DefaultDiscoveryHintSeed -SearchMatrix $searchMatrix)
}

$document = Read-JobAgentStore -ProjectRoot $projectRoot
$hints = foreach ($item in $rawHints) {
    if ($allowedSourceIds -notcontains [string]$item.source_id) {
        throw "Nicht erlaubte Hint-Quelle: $($item.source_id)"
    }
    $knownCompany = Find-JobAgentKnownCompanyForHint -Companies @($document.companies) -EmployerName ([string]$item.employer_name)
    New-JobAgentCompanyDiscoveryHint `
        -EmployerName ([string]$item.employer_name) `
        -Location ([string]$item.location) `
        -IndustryOrKeyword ([string]$item.industry_or_keyword) `
        -ObservedUrl ([string]$item.observed_url) `
        -SourceId ([string]$item.source_id) `
        -Search $item.search `
        -ObservedAt ([datetime]::UtcNow) `
        -KnownCompanyId $(if ($null -eq $knownCompany) { $null } else { [string]$knownCompany.company_id }) `
        -KnownCompanyDomain $(if ($null -eq $knownCompany) { $null } else { [string]$knownCompany.canonical_domain })
}

$report = New-JobAgentCompanyDiscoveryHintReport -Hints @($hints) -SearchMatrix $searchMatrix -GeneratedAt ([datetime]::UtcNow)
New-Item -ItemType Directory -Path (Split-Path -Parent $resolvedOutputPath) -Force | Out-Null
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8

New-Item -ItemType Directory -Path $resolvedLogRoot -Force | Out-Null
$logPath = Join-Path $resolvedLogRoot ('company-discovery-hints-' + [datetime]::UtcNow.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $logPath -Encoding UTF8

$report | Add-Member -NotePropertyName output_path -NotePropertyValue $resolvedOutputPath -Force
$report | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -Force
$report | ConvertTo-Json -Depth 20
