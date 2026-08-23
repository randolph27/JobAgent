#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 500)][int]$MaxCompanies = 20,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRoot = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function ConvertTo-ToolIso {
    param([Parameter(Mandatory)][datetime]$Value)

    $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function New-ToolCareerSourceId {
    param(
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Basis
    )

    $slug = ($CompanyId.Substring(8) + '_career_' + $Basis.ToLowerInvariant()) -replace '[^a-z0-9_]+', '_'
    return 'source:' + $slug.Trim('_')
}

function Add-ToolAtsBinding {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter()][AllowNull()][object]$AtsBinding
    )

    if ($null -eq $AtsBinding) {
        return @($Company.ats)
    }

    $bindings = New-Object System.Collections.Generic.List[object]
    $exists = $false
    foreach ($binding in @($Company.ats)) {
        if ($null -eq $binding) {
            continue
        }
        if (([string]$binding.system -eq [string]$AtsBinding.system) -and ([string]$binding.official_domain -eq [string]$AtsBinding.official_domain)) {
            $bindings.Add($AtsBinding)
            $exists = $true
        }
        else {
            $bindings.Add($binding)
        }
    }
    if (-not $exists) {
        $bindings.Add($AtsBinding)
    }
    return $bindings.ToArray()
}

function New-ToolCareerJobSource {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$VerifiedAt
    )

    $basis = if ([string]$Verification.status -eq 'ATS_VERIFIED_BY_COMPANY_LINK') { 'COMPANY_LINKED_ATS' } else { 'CAREER_URL' }
    [pscustomobject]@{
        source_id = New-ToolCareerSourceId -CompanyId ([string]$Company.company_id) -Basis $basis
        company_id = [string]$Company.company_id
        source_type = 'CAREER_PAGE'
        url = [string]$Verification.career_url
        canonical_url = ConvertTo-JobAgentCanonicalUrl -Url ([string]$Verification.career_url)
        is_official = $true
        verified_at = ConvertTo-ToolIso -Value $VerifiedAt
        verification_basis = $basis
        verification_evidence = @(Complete-JobAgentVerificationEvidence -Evidence @($Verification.verification_evidence) -ObservedAt $VerifiedAt)
    }
}

function Update-ToolCompanyFromVerification {
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][object]$Verification,
        [Parameter(Mandatory)][datetime]$VerifiedAt
    )

    if (@('CAREER_URL_VERIFIED', 'ATS_VERIFIED_BY_COMPANY_LINK') -contains [string]$Verification.status) {
        $Company.career_url = [string]$Verification.career_url
        $Company.verification_status = 'CAREER_URL_VERIFIED'
        $Company.ats = @(Add-ToolAtsBinding -Company $Company -AtsBinding $Verification.ats)
        $Company.discovery_source.verification_url = [string]$Verification.career_url
    }
    elseif ([string]$Company.verification_status -ne 'CAREER_URL_VERIFIED') {
        $Company.verification_status = 'UNVERIFIED'
    }
    $Company.updated_at = ConvertTo-ToolIso -Value $VerifiedAt
    $Company | Add-Member -NotePropertyName career_verification_status -NotePropertyValue ([string]$Verification.status) -Force
    $Company | Add-Member -NotePropertyName career_verification_evidence -NotePropertyValue @($Verification.verification_evidence) -Force
    return $Company
}

$startedAt = [datetime]::UtcNow
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds $TimeoutSeconds
$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRoot -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot
    $targetCompanies = @($document.companies |
        Where-Object { [string]$_.verification_status -ne 'CAREER_URL_VERIFIED' -or [string]::IsNullOrWhiteSpace([string]$_.career_url) } |
        Sort-Object -Property scan_priority, canonical_name -Descending |
        Select-Object -First $MaxCompanies)

    $results = New-Object System.Collections.Generic.List[object]
    $sources = New-Object System.Collections.Generic.List[object]
    foreach ($source in @($document.job_sources)) {
        $sources.Add($source)
    }

    foreach ($company in $targetCompanies) {
        $verification = Resolve-JobAgentCompanyCareerVerification -Company $company -Policy $policy
        $updatedCompany = Update-ToolCompanyFromVerification -Company $company -Verification $verification -VerifiedAt $startedAt
        $document = Upsert-JobAgentCompany -Document $document -Company $updatedCompany
        if (@('CAREER_URL_VERIFIED', 'ATS_VERIFIED_BY_COMPANY_LINK') -contains [string]$verification.status) {
            $source = New-ToolCareerJobSource -Company $updatedCompany -Verification $verification -VerifiedAt $startedAt
            $sources = [System.Collections.Generic.List[object]]::new([object[]]@($sources | Where-Object { [string]$_.source_id -ne [string]$source.source_id }))
            $sources.Add($source)
        }
        $results.Add($verification)
    }
    $document.job_sources = @($sources.ToArray() | Sort-Object company_id, source_id)
    $storePath = Write-JobAgentStore -ProjectRoot $projectRoot -DataRoot $DataRoot -Document $document -CreateBackup
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$logPathRoot = if ([IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $projectRoot $LogRoot }
if (-not (Test-Path -LiteralPath $logPathRoot)) {
    New-Item -ItemType Directory -Path $logPathRoot -Force | Out-Null
}
$logPath = Join-Path $logPathRoot ('company-career-verification-' + $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture) + '.json')
$summary = [pscustomobject]@{
    schema_version = 'jobagent/company-career-verification/v1'
    ts = ConvertTo-ToolIso -Value $startedAt
    store_path = $storePath
    policy = $policy
    checked_company_ids = @($results | ForEach-Object { [string]$_.company_id })
    verified_company_ids = @($results | Where-Object { @('CAREER_URL_VERIFIED', 'ATS_VERIFIED_BY_COMPANY_LINK') -contains [string]$_.status } | ForEach-Object { [string]$_.company_id })
    manual_review_company_ids = @($results | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW' } | ForEach-Object { [string]$_.company_id })
    technical_limitation_company_ids = @($results | Where-Object { [string]$_.status -eq 'TECHNICAL_LIMITATION' } | ForEach-Object { [string]$_.company_id })
    results = @($results.ToArray())
}
$summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 20
