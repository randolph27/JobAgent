#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCandidates = 25,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
    [Parameter()][ValidateRange(1, 730)][int]$ExpiresAfterDays = 90,
    [Parameter()][string]$FixtureMapPath
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Path
    )

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }
    return [IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function ConvertTo-ToolIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-ToolCandidateSourceId {
    param(
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Status
    )

    $basis = if ($Status -eq 'OFFICIAL_ATS_VERIFIED') { 'official_ats' } else { 'career_url' }
    return 'source:' + (([string]$CompanyId).Substring(8) + '_' + $basis -replace '[^A-Za-z0-9_]+', '_').ToLowerInvariant()
}

function Get-ToolCandidateLocation {
    param([Parameter(Mandatory)][object]$Candidate)

    $label = foreach ($name in @('location', 'job_location', 'register_city', 'address_or_location_hint', 'region_reference')) {
        if ($Candidate.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$name)) {
            [string]$Candidate.$name
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($label)) {
        $label = 'UNKNOWN'
    }
    $area = foreach ($name in @('target_area_match', 'target_area')) {
        if ($Candidate.PSObject.Properties.Name -contains $name -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$name)) {
            [string]$Candidate.$name
            break
        }
    }
    if ([string]::IsNullOrWhiteSpace($area) -or @('TARGET_AREA_UNCERTAIN') -contains $area) {
        $area = 'UNKNOWN'
    }
    if (@('MUNICH', 'MUNICH_20KM', 'FREISING', 'REMOTE_WITH_TARGET_REFERENCE', 'UNKNOWN', 'OUT_OF_SCOPE') -notcontains $area) {
        $area = 'UNKNOWN'
    }
    $city = if ($label -match 'Freising') { 'Freising' } elseif ($label -match 'Muenchen|Munich|Garching|Unterfoehring|Ismaning|Taufkirchen|Neubiberg|Pullach|Gruenwald') { 'Muenchen' } else { 'UNKNOWN' }
    New-JobAgentTargetLocation -Label $label -City $city -TargetArea $area
}

function ConvertTo-ToolCompanyFromCandidateVerification {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    $company = $Verification.company.PSObject.Copy()
    $company.verification_status = [string]$Verification.status
    if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$Verification.status) {
        $company.career_url = [string]$Verification.career_url
    }
    $company.ats = if ($null -ne $Verification.ats) { @($Verification.ats) } else { @($company.ats) }
    $company.locations = if (@($company.locations).Count -gt 0) { @($company.locations) } else { @(Get-ToolCandidateLocation -Candidate $Candidate) }
    $company.updated_at = ConvertTo-ToolIso -Value $ObservedAt
    if ($company.PSObject.Properties.Name -notcontains 'created_at') {
        $company | Add-Member -NotePropertyName created_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt)
    }
    if ($company.PSObject.Properties.Name -notcontains 'next_scan_at') {
        $company | Add-Member -NotePropertyName next_scan_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt.Date.AddDays(1))
    }
    if ($company.PSObject.Properties.Name -notcontains 'last_successful_scan_at') {
        $company | Add-Member -NotePropertyName last_successful_scan_at -NotePropertyValue $null
    }
    if ($company.PSObject.Properties.Name -notcontains 'discovery_source') {
        $observedUrl = if ($Candidate.PSObject.Properties.Name -contains 'observed_url') { [string]$Candidate.observed_url } elseif ($Candidate.PSObject.Properties.Name -contains 'source_page') { [string]$Candidate.source_page } else { [string]$company.official_website_url }
        $company | Add-Member -NotePropertyName discovery_source -NotePropertyValue (New-JobAgentDiscoverySource -Type 'DISCOVERY_HINT' -Url $observedUrl -ObservedAt $ObservedAt -VerificationUrl $Verification.evidence[0].verification_url -DiscoveryOrigin ([string]$Candidate.source_id) -TargetArea ([string](Get-ToolCandidateLocation -Candidate $Candidate).target_area) -IndustryHint 'UNKNOWN' -EvidenceNote 'Discovery-Kandidat wurde ueber offizielle Firmen-/Karrierequelle verifiziert.')
    }
    else {
        $company.discovery_source.verification_url = $Verification.evidence[0].verification_url
    }
    $company | Add-Member -NotePropertyName candidate_verification_evidence -NotePropertyValue @($Verification.evidence) -Force
    return $company
}

function New-ToolJobSourceFromCandidateVerification {
    param(
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$ObservedAt
    )

    if ([string]::IsNullOrWhiteSpace([string]$Verification.career_url)) {
        return $null
    }
    $basis = if ([string]$Verification.status -eq 'OFFICIAL_ATS_VERIFIED') { 'COMPANY_LINKED_ATS' } else { 'CAREER_URL' }
    [pscustomobject]@{
        source_id = New-ToolCandidateSourceId -CompanyId ([string]$Verification.company_id) -Status ([string]$Verification.status)
        company_id = [string]$Verification.company_id
        source_type = if ([string]$Verification.status -eq 'OFFICIAL_ATS_VERIFIED') { 'OFFICIAL_ATS' } else { 'CAREER_PAGE' }
        url = [string]$Verification.career_url
        canonical_url = ConvertTo-JobAgentCanonicalUrl -Url ([string]$Verification.career_url)
        is_official = $true
        verified_at = ConvertTo-ToolIso -Value $ObservedAt
        verification_basis = $basis
        verification_evidence = @($Verification.evidence | ForEach-Object {
                [pscustomobject]@{
                    status = 'VERIFIED'
                    evidence_type = [string]$_.evidence_type
                    url = [string]$_.verification_url
                    basis_url = $_.verified_by_url
                    redirect_chain = @($_.redirect_chain)
                    observed_at = [string]$_.observed_at
                    reason = [string]$_.reason
                }
            })
    }
}

function New-ToolFixtureFetcher {
    param([Parameter(Mandatory)][string]$Path)

    $fixture = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    $map = @{}
    foreach ($entry in @($fixture.responses)) {
        $map[[string]$entry.url] = $entry
    }
    return {
        param([string]$Url, [object]$Policy)

        if ($map.ContainsKey($Url)) {
            $entry = $map[$Url]
            return [pscustomobject]@{
                ok = [bool]$entry.ok
                url = $Url
                final_url = if ([string]::IsNullOrWhiteSpace([string]$entry.final_url)) { $Url } else { [string]$entry.final_url }
                status_code = if ($null -eq $entry.status_code) { $null } else { [int]$entry.status_code }
                content = if ($null -eq $entry.content) { '' } else { [string]$entry.content }
                content_type = 'text/html'
                error = if ([bool]$entry.ok) { $null } else { 'fixture failure' }
            }
        }
        [pscustomobject]@{
            ok = $false
            url = $Url
            final_url = $Url
            status_code = 404
            content = ''
            content_type = 'text/html'
            error = 'fixture missing'
        }
    }.GetNewClosure()
}

$startedAt = [datetime]::UtcNow
$hintStoreResolved = Resolve-ToolPath -Root $projectRootResolved -Path $HintStorePath
if (-not (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf)) {
    throw "Discovery-Hint-Store fehlt: $hintStoreResolved"
}

$hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds $TimeoutSeconds
$fetcher = if ([string]::IsNullOrWhiteSpace($FixtureMapPath)) { $null } else { New-ToolFixtureFetcher -Path (Resolve-ToolPath -Root $projectRootResolved -Path $FixtureMapPath) }

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRootResolved -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot
    $results = New-Object System.Collections.Generic.List[object]
    $targetCandidates = @($hintStore.hints |
        Sort-Object @{ Expression = { if ($_.PSObject.Properties.Name -contains 'confidence_score') { -[int]$_.confidence_score } elseif ($_.PSObject.Properties.Name -contains 'priority_score') { -[int]$_.priority_score } else { -50 } } }, employer_name |
        Select-Object -First $MaxCandidates)

    foreach ($candidate in $targetCandidates) {
        $verification = Resolve-JobAgentCompanyCandidateVerification -Candidate $candidate -ExistingCompanies @($document.companies) -Policy $policy -Fetcher $fetcher -ObservedAt $startedAt -ExpiresAfterDays $ExpiresAfterDays
        $results.Add($verification)
        if (@('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$verification.status) {
            $company = ConvertTo-ToolCompanyFromCandidateVerification -Candidate $candidate -Verification $verification -ObservedAt $startedAt
            $document = Upsert-JobAgentCompany -Document $document -Company $company
            if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$verification.status) {
                $source = New-ToolJobSourceFromCandidateVerification -Verification $verification -ObservedAt $startedAt
                if ($null -ne $source) {
                    $document = Upsert-JobAgentJobSource -Document $document -JobSource $source
                }
            }
        }
    }
    $storePath = Write-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot -Document $document -CreateBackup
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$logRootPath = Resolve-ToolPath -Root $projectRootResolved -Path $LogRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$logPath = Join-Path $logRootPath ('company-candidate-verification-' + $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-verification/v1'
    ts = ConvertTo-ToolIso -Value $startedAt
    store_path = $storePath
    hint_store_path = $hintStoreResolved
    policy = $policy
    checked_candidate_ids = @($results | ForEach-Object { [string]$_.candidate_id })
    verified_candidate_ids = @($results | Where-Object { @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$_.status } | ForEach-Object { [string]$_.candidate_id })
    manual_review_candidate_ids = @($results | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' } | ForEach-Object { [string]$_.candidate_id })
    unverified_candidate_ids = @($results | Where-Object { [string]$_.status -eq 'UNVERIFIED' } | ForEach-Object { [string]$_.candidate_id })
    results = @($results.ToArray())
}
$summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 100
