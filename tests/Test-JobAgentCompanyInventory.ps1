#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestSeedDate {
    [datetime]::Parse('2026-08-17T10:00:00Z').ToUniversalTime()
}

function New-TestNextScanDate {
    [datetime]::Parse('2026-08-18T06:00:00Z').ToUniversalTime()
}

function New-TestCompanySeed {
    param(
        [Parameter(Mandatory)][string]$CanonicalName,
        [Parameter(Mandatory)][string]$Website,
        [Parameter()][AllowNull()][string]$CareerUrl,
        [Parameter()][string[]]$Aliases = @(),
        [Parameter()][string]$City = 'Muenchen'
    )

    $targetArea = if ($City -eq 'Freising') { 'FREISING' } else { 'MUNICH' }
    New-JobAgentCompanySeed `
        -CanonicalName $CanonicalName `
        -OfficialWebsiteUrl $Website `
        -CareerUrl $CareerUrl `
        -Aliases $Aliases `
        -Locations @((New-JobAgentTargetLocation -Label $City -City $City -TargetArea $targetArea)) `
        -Industry 'UNKNOWN' `
        -ScanPriority 75 `
        -DiscoverySourceUrl $Website `
        -CreatedAt (New-TestSeedDate) `
        -NextScanAt (New-TestNextScanDate)
}

$document = New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)
$seeded = Add-JobAgentCompanySeedInventory -Document $document -Seeds (Get-JobAgentCompanySeedInventory -CreatedAt (New-TestSeedDate) -NextScanAt (New-TestNextScanDate)) -SeededAt (New-TestSeedDate)
Assert-JobAgentDocument -Document $seeded.document
Assert-True -Condition (@($seeded.document.companies).Count -ge 10) -Message 'Initialer Seed enthaelt zu wenige Firmen.'
Assert-True -Condition (@($seeded.document.companies | Where-Object { $_.career_url -ne $null }).Count -eq @($seeded.document.job_sources).Count) -Message 'Career-URLs wurden nicht als offizielle Quellen angelegt.'
Assert-True -Condition (@($seeded.document.companies | Where-Object { $_.locations[0].target_area -eq 'FREISING' }).Count -ge 1) -Message 'Seed enthaelt keinen Freising-Bezug.'
Assert-True -Condition (@($seeded.document.job_sources | Where-Object { $_.is_official -ne $true }).Count -eq 0) -Message 'Seed hat nicht-offizielle JobSource erzeugt.'
Assert-True -Condition (@($seeded.document.job_sources | Where-Object { @($_.verification_evidence).Count -lt 1 }).Count -eq 0) -Message 'Seed hat Quellen ohne Verifikationsbelege erzeugt.'
Assert-True -Condition (@($seeded.document.job_sources | Where-Object { $_.verification_evidence[0].evidence_type -ne 'CAREER_URL' }).Count -eq 0) -Message 'Seed hat Career-Quellen mit falschem Evidenztyp erzeugt.'

$secondRun = Add-JobAgentCompanySeedInventory -Document $seeded.document -Seeds (Get-JobAgentCompanySeedInventory -CreatedAt (New-TestSeedDate) -NextScanAt (New-TestNextScanDate)) -SeededAt (New-TestSeedDate)
Assert-JobAgentDocument -Document $secondRun.document
Assert-True -Condition (@($secondRun.document.companies).Count -eq @($seeded.document.companies).Count) -Message 'Erneuter Seed hat Firmen dupliziert.'
Assert-True -Condition (@($secondRun.document.job_sources).Count -eq @($seeded.document.job_sources).Count) -Message 'Erneuter Seed hat Quellen dupliziert.'

$sameDomain = @(
    (New-TestCompanySeed -CanonicalName 'Example AG' -Website 'https://example.invalid/' -CareerUrl 'https://example.invalid/careers' -Aliases @('Example')),
    (New-TestCompanySeed -CanonicalName 'Example Services GmbH' -Website 'https://example.invalid/' -CareerUrl 'https://example.invalid/jobs' -Aliases @('Example Services'))
)
$sameDomainResult = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds $sameDomain -SeededAt (New-TestSeedDate)
Assert-True -Condition (@($sameDomainResult.document.companies).Count -eq 1) -Message 'Identische Domain wurde nicht dedupliziert.'
Assert-True -Condition (@($sameDomainResult.deduplicated | Where-Object { $_.matched_key -eq 'domain:example.invalid' }).Count -eq 1) -Message 'Domain-Deduplikation wurde nicht protokolliert.'

$legalVariant = @(
    (New-TestCompanySeed -CanonicalName 'Sample AG' -Website 'https://sample.invalid/' -CareerUrl 'https://sample.invalid/careers' -Aliases @()),
    (New-TestCompanySeed -CanonicalName 'Sample GmbH' -Website 'https://jobs.sample.invalid/' -CareerUrl 'https://jobs.sample.invalid/careers' -Aliases @())
)
$legalVariantResult = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds $legalVariant -SeededAt (New-TestSeedDate)
Assert-True -Condition (@($legalVariantResult.document.companies).Count -eq 1) -Message 'Rechtsformvariante wurde nicht dedupliziert.'
Assert-True -Condition (@($legalVariantResult.deduplicated | Where-Object { $_.matched_key -eq 'name:sample' }).Count -eq 1) -Message 'Namens-Deduplikation wurde nicht protokolliert.'

$separateSubsidiaries = @(
    (New-TestCompanySeed -CanonicalName 'Contoso Holding AG' -Website 'https://holding.contoso.invalid/' -CareerUrl 'https://holding.contoso.invalid/careers' -Aliases @('Contoso Holding')),
    (New-TestCompanySeed -CanonicalName 'Contoso Mobility GmbH' -Website 'https://mobility.contoso.invalid/' -CareerUrl 'https://mobility.contoso.invalid/careers' -Aliases @('Contoso Mobility'))
)
$subsidiaryResult = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds $separateSubsidiaries -SeededAt (New-TestSeedDate)
Assert-True -Condition (@($subsidiaryResult.document.companies).Count -eq 2) -Message 'Getrennte Tochtergesellschaften wurden faelschlich zusammengefuehrt.'

$missingCareer = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds @(
    (New-TestCompanySeed -CanonicalName 'No Career GmbH' -Website 'https://nocareer.invalid/' -CareerUrl $null -Aliases @('No Career'))
) -SeededAt (New-TestSeedDate)
Assert-JobAgentDocument -Document $missingCareer.document
Assert-True -Condition ($missingCareer.document.companies[0].career_url -eq $null) -Message 'Fehlende Karriere-URL wurde nicht als null modelliert.'
Assert-True -Condition ($missingCareer.document.companies[0].verification_status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'Fehlende Karriere-URL hat falschen Verifikationsstatus.'
Assert-True -Condition (@($missingCareer.document.job_sources).Count -eq 0) -Message 'Fehlende Karriere-URL darf keine JobSource erzeugen.'

[pscustomobject]@{
    status = 'ok'
    cases = @('initial_seed', 'idempotent_seed', 'same_domain', 'legal_form_variant', 'separate_subsidiary', 'missing_career_url')
    companies = @($secondRun.document.companies).Count
    sources = @($secondRun.document.job_sources).Count
} | ConvertTo-Json -Depth 4
