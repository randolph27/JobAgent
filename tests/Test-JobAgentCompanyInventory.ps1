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
Assert-True -Condition (@($seeded.document.companies | Where-Object { $_.discovery_source.verification_url -eq $null }).Count -eq 0) -Message 'Seed hat Discovery-Quellen ohne verification_url erzeugt.'
Assert-True -Condition (@($seeded.document.companies | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.discovery_source.discovery_origin) }).Count -eq 0) -Message 'Seed hat Discovery-Quellen ohne discovery_origin erzeugt.'

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

$mergeExisting = New-TestCompanySeed -CanonicalName 'Merge AG' -Website 'https://merge.invalid/' -CareerUrl $null -Aliases @('Merge') -City 'Muenchen'
$mergeExisting.scan_priority = 60
$mergeExisting.discovery_source = New-JobAgentDiscoverySource -Type 'DISCOVERY_HINT' -Url 'https://hint.invalid/merge' -ObservedAt (New-TestSeedDate) -VerificationUrl $null -DiscoveryOrigin 'hint.directory' -TargetArea 'MUNICH' -IndustryHint 'UNKNOWN' -EvidenceNote 'Hinweisquelle'
$mergeExisting.locations = @(
    (New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')
)
$mergeExisting.next_scan_at = '2026-08-20T06:00:00.000Z'
$mergeSeed = New-TestCompanySeed -CanonicalName 'Merge AG' -Website 'https://merge.invalid/' -CareerUrl 'https://merge.invalid/careers' -Aliases @('Merge Careers') -City 'Freising'
$mergeSeed.scan_priority = 90
$mergeSeed.next_scan_at = '2026-08-18T06:00:00.000Z'
$mergeResult = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds @($mergeExisting, $mergeSeed) -SeededAt (New-TestSeedDate)
$mergedCompany = $mergeResult.document.companies[0]
Assert-True -Condition ($mergedCompany.verification_status -eq 'CAREER_URL_VERIFIED') -Message 'Merge bevorzugt keinen staerkeren Verifikationsstatus.'
Assert-True -Condition ($mergedCompany.scan_priority -eq 90) -Message 'Merge behaelt nicht die hoehere Scan-Prioritaet.'
Assert-True -Condition ($mergedCompany.next_scan_at -eq '2026-08-18T06:00:00.000Z') -Message 'Merge behaelt nicht den frueheren naechsten Scan.'
Assert-True -Condition (@($mergedCompany.locations).Count -eq 2) -Message 'Merge vereinigt Standorte nicht verlustfrei.'
Assert-True -Condition (@($mergedCompany.aliases | Where-Object { $_ -eq 'Merge Careers' }).Count -eq 1) -Message 'Merge uebernimmt neue Aliasnamen nicht.'
Assert-True -Condition ($mergedCompany.discovery_source.type -eq 'OFFICIAL_WEBSITE') -Message 'Merge bevorzugt keine staerkere Discovery-Quelle.'

$missingCareer = Add-JobAgentCompanySeedInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -Seeds @(
    (New-TestCompanySeed -CanonicalName 'No Career GmbH' -Website 'https://nocareer.invalid/' -CareerUrl $null -Aliases @('No Career'))
) -SeededAt (New-TestSeedDate)
Assert-JobAgentDocument -Document $missingCareer.document
Assert-True -Condition ($missingCareer.document.companies[0].career_url -eq $null) -Message 'Fehlende Karriere-URL wurde nicht als null modelliert.'
Assert-True -Condition ($missingCareer.document.companies[0].verification_status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'Fehlende Karriere-URL hat falschen Verifikationsstatus.'
Assert-True -Condition (@($missingCareer.document.job_sources).Count -eq 0) -Message 'Fehlende Karriere-URL darf keine JobSource erzeugen.'

$discoveryImport = Import-JobAgentCompanyDiscoveryInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -DiscoveryItems @(
    [pscustomobject]@{
        canonical_name = 'Discovery Hint AG'
        official_website_url = 'https://discovery-hint.invalid/'
        career_url = $null
        aliases = @('Discovery Hint')
        locations = @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH'))
        industry = 'Technology'
        scan_priority = 88
        discovery_type = 'DISCOVERY_HINT'
        discovery_url = 'https://directory.invalid/discovery-hint'
        discovery_origin = 'directory.seed'
        evidence_note = 'Sekundaerquelle fuer Discovery.'
    },
    [pscustomobject]@{
        canonical_name = 'Official Only AG'
        official_website_url = 'https://official-only.invalid/'
        career_url = $null
        aliases = @('Official Only')
        locations = @((New-JobAgentTargetLocation -Label 'Freising' -City 'Freising' -TargetArea 'FREISING'))
        industry = 'Industrial'
        scan_priority = 74
        discovery_type = 'OFFICIAL_WEBSITE'
        discovery_url = 'https://official-only.invalid/'
        discovery_origin = 'official.manual'
        evidence_note = 'Offizielle Website ohne Karrierepfad.'
    }
) -ImportedAt (New-TestSeedDate) -NextScanAt (New-TestNextScanDate)
Assert-JobAgentDocument -Document $discoveryImport.document
$hintCompany = @($discoveryImport.document.companies | Where-Object { $_.company_id -eq 'company:discovery_hint_ag' })[0]
$officialOnlyCompany = @($discoveryImport.document.companies | Where-Object { $_.company_id -eq 'company:official_only_ag' })[0]
Assert-True -Condition ($hintCompany.verification_status -eq 'UNVERIFIED') -Message 'Discovery-Hinweis muss unverifiziert importiert werden.'
Assert-True -Condition ($hintCompany.discovery_source.verification_url -eq $null) -Message 'Discovery-Hinweis darf keine verification_url vortaeuschen.'
Assert-True -Condition ($officialOnlyCompany.verification_status -eq 'COMPANY_DOMAIN_VERIFIED') -Message 'Offizielle Website ohne Karrierepfad muss domain-verifiziert bleiben.'
Assert-True -Condition ($officialOnlyCompany.discovery_source.verification_url -eq 'https://official-only.invalid/') -Message 'Offizielle Website ohne Karrierepfad muss Website als verification_url tragen.'
Assert-True -Condition (@($discoveryImport.document.job_sources).Count -eq 0) -Message 'Discovery-Import ohne Karriere-URL darf keine JobSource erzeugen.'
Assert-True -Condition (@($discoveryImport.manual_review_required | Where-Object { $_ -eq 'company:discovery_hint_ag' }).Count -eq 1) -Message 'Discovery-Hinweis muss im Manual-Review-Backlog landen.'
Assert-True -Condition (@($discoveryImport.document.companies | Where-Object { @($_.ats | Where-Object { $null -eq $_ }).Count -gt 0 }).Count -eq 0) -Message 'Discovery-Import darf fehlende ATS-Felder nicht als null-Binding speichern.'

$regionalFeedPath = Join-Path $root 'data\jobagent\company-discovery.regional.json'
Assert-True -Condition (Test-Path -LiteralPath $regionalFeedPath -PathType Leaf) -Message 'Regionaler Discovery-Feed fehlt.'
$regionalFeed = Get-Content -LiteralPath $regionalFeedPath -Raw | ConvertFrom-Json -Depth 100
$regionalItems = @($regionalFeed.items)
Assert-True -Condition ($regionalFeed.schema_version -eq 'jobagent/company-discovery-feed/v1') -Message 'Regionaler Discovery-Feed hat falsche Schema-Version.'
Assert-True -Condition ($regionalItems.Count -ge 20) -Message 'Regionaler Discovery-Feed enthaelt zu wenige Arbeitgeberkandidaten.'
Assert-True -Condition (@($regionalItems | Where-Object { $_.discovery_origin -eq 'source-registry:stadt_muenchen_boersennotierte_unternehmen' }).Count -ge 15) -Message 'Regionaler Feed nutzt die Muenchen-Boersenquelle nicht ausreichend.'
Assert-True -Condition (@($regionalItems | Where-Object { $_.discovery_origin -eq 'source-registry:landkreis_freising_wirtschaft' }).Count -ge 2) -Message 'Regionaler Feed enthaelt zu wenige Freising-Wirtschaft-Kandidaten.'
Assert-True -Condition (@($regionalItems | Where-Object { $_.discovery_origin -eq 'source-registry:stadt_freising_weihenstephan' }).Count -ge 1) -Message 'Regionaler Feed enthaelt keinen Weihenstephan-Kandidaten.'
Assert-True -Condition (@($regionalItems | Where-Object { $_.discovery_type -ne 'OFFICIAL_WEBSITE' }).Count -eq 0) -Message 'Regionaler Feed darf keine unverifizierten Hint-Typen importieren.'
Assert-True -Condition (@($regionalItems | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.official_website_url) }).Count -eq 0) -Message 'Regionaler Feed enthaelt Firmen ohne offizielle Website.'
Assert-True -Condition (@($regionalItems | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.evidence_note) }).Count -eq 0) -Message 'Regionaler Feed enthaelt Firmen ohne Evidenznotiz.'
Assert-True -Condition (@($regionalItems | Where-Object { [string]$_.career_url -match 'linkedin|stepstone|indeed|xing|kununu|glassdoor' }).Count -eq 0) -Message 'Regionaler Feed enthaelt Aggregator-Karriere-URLs.'
$regionalDomains = @($regionalItems | ForEach-Object { ConvertTo-JobAgentCanonicalDomain -UrlOrDomain ([string]$_.official_website_url) })
Assert-True -Condition (($regionalDomains | Sort-Object -Unique).Count -eq $regionalDomains.Count) -Message 'Regionaler Feed enthaelt doppelte offizielle Domains.'

$regionalImport = Import-JobAgentCompanyDiscoveryInventory -Document (New-JobAgentEmptyDocument -GeneratedAt (New-TestSeedDate)) -DiscoveryItems $regionalItems -ImportedAt (New-TestSeedDate) -NextScanAt (New-TestNextScanDate)
Assert-JobAgentDocument -Document $regionalImport.document
Assert-True -Condition (@($regionalImport.document.companies).Count -eq $regionalItems.Count) -Message 'Regionaler Feed importiert nicht alle Kandidaten in ein leeres Dokument.'
Assert-True -Condition (@($regionalImport.document.job_sources).Count -eq @($regionalItems | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.career_url) }).Count) -Message 'Regionaler Feed erzeugt unerwartete JobSource-Anzahl.'
Assert-True -Condition (@($regionalImport.manual_review_required).Count -eq 0) -Message 'Regionaler Feed darf nach Website-/Karrierepruefung kein Manual-Review-Backlog erzeugen.'
Assert-True -Condition (@($regionalImport.document.companies | Where-Object { @($_.ats | Where-Object { $null -eq $_ }).Count -gt 0 }).Count -eq 0) -Message 'Regionaler Feed darf keine null-ATS-Bindings erzeugen.'

$importProjectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-discovery-import-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $importProjectRoot -Force | Out-Null
try {
    $feedPath = Join-Path $importProjectRoot 'company-discovery.json'
    [pscustomobject]@{
        items = @(
            [pscustomobject]@{
                canonical_name = 'Script Import AG'
                official_website_url = 'https://script-import.invalid/'
                career_url = 'https://script-import.invalid/careers'
                aliases = @('Script Import')
                locations = @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH'))
                industry = 'Technology'
                scan_priority = 79
                discovery_type = 'OFFICIAL_WEBSITE'
                discovery_url = 'https://script-import.invalid/careers'
                discovery_origin = 'official.manual'
                evidence_note = 'Script-Import-Test.'
            }
        )
    } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $feedPath -Encoding UTF8
    $scriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentCompanyDiscovery.ps1') -ProjectRoot $importProjectRoot -FeedPath $feedPath 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Discovery-Import-Script ist fehlgeschlagen: " + ($scriptOutput -join "`n"))
    $scriptResult = ($scriptOutput -join "`n") | ConvertFrom-Json -Depth 20
    $scriptStore = Read-JobAgentStore -ProjectRoot $importProjectRoot
    Assert-True -Condition (@($scriptStore.companies | Where-Object { $_.company_id -eq 'company:script_import_ag' }).Count -eq 1) -Message 'Discovery-Import-Script persistiert die Firma nicht.'
    Assert-True -Condition (@($scriptStore.job_sources | Where-Object { $_.company_id -eq 'company:script_import_ag' }).Count -eq 1) -Message 'Discovery-Import-Script erzeugt keine offizielle Karrierequelle.'
    Assert-True -Condition (@($scriptResult.added_company_ids | Where-Object { $_ -eq 'company:script_import_ag' }).Count -eq 1) -Message 'Discovery-Import-Script meldet neue Firma nicht als hinzugefuegt.'
    Assert-True -Condition (Test-Path -LiteralPath ([string]$scriptResult.log_path) -PathType Leaf) -Message 'Discovery-Import-Script schreibt kein Logartefakt.'

    $regionalScriptOutput = @(& pwsh -NoProfile -File (Join-Path $root 'tools\Import-JobAgentCompanyDiscovery.ps1') -ProjectRoot $importProjectRoot -FeedPath $regionalFeedPath 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ("Regionaler Discovery-Import ist fehlgeschlagen: " + ($regionalScriptOutput -join "`n"))
    $regionalScriptResult = ($regionalScriptOutput -join "`n") | ConvertFrom-Json -Depth 20
    Assert-True -Condition ([IO.Path]::GetFileName([string]$regionalScriptResult.log_path).StartsWith('company-discovery-regional-import-', [StringComparison]::Ordinal)) -Message 'Regionaler Import schreibt kein regional benanntes Logartefakt.'
    Assert-True -Condition (@($regionalScriptResult.imported_company_ids).Count -eq $regionalItems.Count) -Message 'Regionaler Import meldet falsche Kandidatenanzahl.'
    Assert-True -Condition (@($regionalScriptResult.manual_review_required).Count -eq 0) -Message 'Regionaler Import erzeugt unerwarteten Manual-Review-Bestand.'
}
finally {
    if (Test-Path -LiteralPath $importProjectRoot) {
        Remove-Item -LiteralPath $importProjectRoot -Recurse -Force
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @('initial_seed', 'idempotent_seed', 'same_domain', 'legal_form_variant', 'separate_subsidiary', 'merged_priority_and_locations', 'missing_career_url', 'discovery_import_manual_review_and_verified_website_only', 'regional_discovery_feed_contract', 'regional_discovery_import_script', 'discovery_import_script')
    companies = @($secondRun.document.companies).Count
    sources = @($secondRun.document.job_sources).Count
} | ConvertTo-Json -Depth 4
