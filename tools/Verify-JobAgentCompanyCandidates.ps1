#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$DataRoot = 'data/jobagent',
    [Parameter()][string]$HintStorePath = 'data/jobagent/company-discovery.hints.json',
    [Parameter()][string]$SourceRegistryPath = 'data/jobagent/company-discovery.sources.json',
    [Parameter()][string]$QueuePath = 'data/jobagent/company-candidate-verification.queue.json',
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 1000)][int]$MaxCandidates = 25,
    [Parameter()][ValidateRange(1, 60)][int]$TimeoutSeconds = 12,
    [Parameter()][ValidateRange(1, 730)][int]$ExpiresAfterDays = 90,
    [Parameter()][ValidateRange(1, 20)][int]$MaxRetries = 3,
    [Parameter()][ValidateRange(1, 16)][int]$WorkerCount = 4,
    [Parameter()][ValidateRange(1, 8)][int]$HostConcurrency = 1,
    [Parameter()][string]$CheckpointPath = 'data/jobagent/company-candidate-verification.checkpoint.json',
    [Parameter()][string]$FixtureMapPath,
    [Parameter()][switch]$StopBeforeCommitForResumeTest
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$toolRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$projectRootResolved = [IO.Path]::GetFullPath($ProjectRoot)

Import-Module (Join-Path $toolRoot 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.SourceVerification.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $toolRoot 'src\JobAgent.Coverage.psm1') -Force -DisableNameChecking

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

function ConvertTo-ToolDateOrNull {
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    $text = ([string]$Value).Trim()
    $styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal
    $parsed = [datetime]::MinValue
    foreach ($culture in @([Globalization.CultureInfo]::InvariantCulture, [Globalization.CultureInfo]::GetCultureInfo('en-US'), [Globalization.CultureInfo]::GetCultureInfo('de-DE'))) {
        if ([datetime]::TryParse($text, $culture, $styles, [ref]$parsed)) {
            return $parsed.ToUniversalTime()
        }
    }

    return $null
}

function Get-ToolTextSha256 {
    param(
        [Parameter()][AllowEmptyString()][string]$Text
    )

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
    }
}

function ConvertTo-ToolPlainTextExcerpt {
    param(
        [Parameter()][AllowEmptyString()][string]$Html,
        [Parameter()][ValidateRange(1, 400)][int]$MaxLength = 160
    )

    $text = [regex]::Replace($Html, '<(script|style)\b.*?</\1>', ' ', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $text = [regex]::Replace($text, '<[^>]+>', ' ')
    $text = [Net.WebUtility]::HtmlDecode($text)
    $text = [regex]::Replace($text, '\s+', ' ').Trim()
    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength)
    }
    return $text
}

function Get-ToolCandidateId {
    param([Parameter(Mandatory)][object]$Candidate)

    foreach ($property in @('candidate_id', 'hint_id', 'company_id')) {
        if ($Candidate.PSObject.Properties.Name -contains $property -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$property)) {
            return [string]$Candidate.$property
        }
    }
    throw 'Kandidat enthaelt keine stabile ID.'
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
    if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$Verification.status -and [string]::IsNullOrWhiteSpace([string]$company.career_url)) {
        $company.career_url = [string]$Verification.career_url
    }
    $atsItems = if ($null -ne $Verification.ats) { @($Verification.ats) } else { @($company.ats) }
    $atsItems = @($atsItems | Where-Object { $null -ne $_ })
    $locationItems = if (@($company.locations).Count -gt 0) { @($company.locations) } else { @(Get-ToolCandidateLocation -Candidate $Candidate) }
    if ($null -ne $Verification.ats -or $company.PSObject.Properties.Name -notcontains 'ats' -or $null -eq $company.ats -or -not ($company.ats -is [array])) {
        $company | Add-Member -NotePropertyName ats -NotePropertyValue ([object[]]$atsItems) -Force
    }
    if ($company.PSObject.Properties.Name -notcontains 'locations' -or $null -eq $company.locations -or -not ($company.locations -is [array]) -or @($company.locations).Count -eq 0) {
        $company | Add-Member -NotePropertyName locations -NotePropertyValue ([object[]]$locationItems) -Force
    }
    if ($company.PSObject.Properties.Name -contains 'updated_at') {
        $company.updated_at = ConvertTo-ToolIso -Value $ObservedAt
    }
    else {
        $company | Add-Member -NotePropertyName updated_at -NotePropertyValue (ConvertTo-ToolIso -Value $ObservedAt)
    }
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
    $company | Add-Member -NotePropertyName candidate_verification_evidence -NotePropertyValue ([object[]]@($Verification.evidence)) -Force
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
        verification_evidence = [object[]]@($Verification.evidence | ForEach-Object {
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
                retry_after_seconds = if ($null -eq $entry.retry_after_seconds) { $null } else { [int]$entry.retry_after_seconds }
                error_class = if ($entry.PSObject.Properties.Name -contains 'error_class') { $entry.error_class } else { $null }
                error = if ([bool]$entry.ok) { $null } else { 'fixture failure' }
                error_detail = if ($entry.PSObject.Properties.Name -contains 'error_detail') { $entry.error_detail } else { $null }
                exception_types = if ($entry.PSObject.Properties.Name -contains 'exception_types') { @($entry.exception_types) } else { @() }
            }
        }
        [pscustomobject]@{
            ok = $false
            url = $Url
            final_url = $Url
            status_code = 404
            content = ''
            content_type = 'text/html'
            retry_after_seconds = $null
            error_class = 'HTTP_STATUS'
            error = 'fixture missing'
            error_detail = 'fixture missing'
            exception_types = @()
        }
    }.GetNewClosure()
}

function ConvertTo-ToolFetchEvidence {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Fetches = @()
    )

    foreach ($fetch in @($Fetches)) {
        $content = if (($fetch.PSObject.Properties.Name -contains 'content') -and -not [string]::IsNullOrWhiteSpace([string]$fetch.content)) { [string]$fetch.content } else { '' }
        [pscustomobject]@{
            ok = [bool]$fetch.ok
            url = [string]$fetch.url
            final_url = if ($fetch.PSObject.Properties.Name -contains 'final_url') { [string]$fetch.final_url } else { [string]$fetch.url }
            status_code = if ($fetch.PSObject.Properties.Name -contains 'status_code') { $fetch.status_code } else { $null }
            content_type = if ($fetch.PSObject.Properties.Name -contains 'content_type') { [string]$fetch.content_type } else { '' }
            content_hash = if ([string]::IsNullOrWhiteSpace($content)) { $null } else { Get-ToolTextSha256 -Text $content }
            content_excerpt = if ([string]::IsNullOrWhiteSpace($content)) { '' } else { ConvertTo-ToolPlainTextExcerpt -Html $content -MaxLength 160 }
            error_class = if ($fetch.PSObject.Properties.Name -contains 'error_class') { $fetch.error_class } else { $null }
            error = if ($fetch.PSObject.Properties.Name -contains 'error') { $fetch.error } else { $null }
            error_detail = if ($fetch.PSObject.Properties.Name -contains 'error_detail') { $fetch.error_detail } else { $null }
            exception_types = if ($fetch.PSObject.Properties.Name -contains 'exception_types') { @($fetch.exception_types) } else { @() }
        }
    }
}

function New-ToolFetchErrorSummary {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Results = @()
    )

    $fetches = @($Results | ForEach-Object {
            $candidateId = if ($_.PSObject.Properties.Name -contains 'candidate_id') { [string]$_.candidate_id } else { '' }
            if ($_.PSObject.Properties.Name -contains 'fetches') {
                @($_.fetches | ForEach-Object {
                        $_ | Add-Member -NotePropertyName candidate_id -NotePropertyValue $candidateId -Force
                        $_
                    })
            }
        } | Where-Object {
            $_.PSObject.Properties.Name -contains 'error_class' -and
            -not [string]::IsNullOrWhiteSpace([string]$_.error_class)
        })

    $byClass = @($fetches |
        Group-Object { [string]$_.error_class } |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        ForEach-Object {
            [pscustomobject]@{
                error_class = [string]$_.Name
                fetch_count = [int]$_.Count
                candidate_count = @($_.Group | ForEach-Object { [string]$_.candidate_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique).Count
                sample_urls = @($_.Group | ForEach-Object { [string]$_.url } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique -First 5)
                sample_details = @($_.Group | ForEach-Object {
                        if ($_.PSObject.Properties.Name -contains 'error_detail') { [string]$_.error_detail }
                    } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique -First 3)
                exception_types = @($_.Group | ForEach-Object {
                        if ($_.PSObject.Properties.Name -contains 'exception_types') { @($_.exception_types) }
                    } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
            }
        })

    [pscustomobject]@{
        schema_version = 'jobagent/fetch-error-summary/v1'
        failed_fetch_total = $fetches.Count
        error_class_total = $byClass.Count
        by_error_class = @($byClass)
    }
}

function ConvertTo-ToolVerificationLogResult {
    param(
        [Parameter(Mandatory)][object]$Result
    )

    [pscustomobject]@{
        candidate_id = [string]$Result.candidate_id
        company_id = if ($Result.PSObject.Properties.Name -contains 'company_id') { $Result.company_id } else { $null }
        status = [string]$Result.status
        priority_score = if ($Result.PSObject.Properties.Name -contains 'priority_score') { $Result.priority_score } else { $null }
        review_reasons = @($Result.review_reasons)
        evidence = @($Result.evidence)
        fetches = [object[]]@(ConvertTo-ToolFetchEvidence -Fetches @($Result.fetches))
        company = if ($Result.PSObject.Properties.Name -contains 'company') {
            [pscustomobject]@{
                company_id = [string]$Result.company.company_id
                canonical_name = [string]$Result.company.canonical_name
                canonical_domain = [string]$Result.company.canonical_domain
                official_website_url = [string]$Result.company.official_website_url
                career_url = $Result.company.career_url
                verification_status = [string]$Result.company.verification_status
            }
        }
        else {
            $null
        }
        career_url = if ($Result.PSObject.Properties.Name -contains 'career_url') { $Result.career_url } else { $null }
        ats = if ($Result.PSObject.Properties.Name -contains 'ats') { $Result.ats } else { $null }
        batch_telemetry = if ($Result.PSObject.Properties.Name -contains 'batch_telemetry') { $Result.batch_telemetry } else { $null }
        next_action = [string]$Result.next_action
    }
}

function Get-ToolOfficialCareerCompanyIds {
    param(
        [Parameter(Mandatory)][object]$Document
    )

    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($company in @($Document.companies)) {
        $status = if ($company.PSObject.Properties.Name -contains 'verification_status') { [string]$company.verification_status } else { 'UNVERIFIED' }
        if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains $status) {
            [void]$ids.Add([string]$company.company_id)
        }
    }
    foreach ($source in @($Document.job_sources)) {
        $sourceType = if ($source.PSObject.Properties.Name -contains 'source_type') { [string]$source.source_type } else { '' }
        $isOfficial = ($source.PSObject.Properties.Name -contains 'is_official') -and [bool]$source.is_official
        if ($isOfficial -and @('CAREER_PAGE', 'OFFICIAL_ATS') -contains $sourceType) {
            [void]$ids.Add([string]$source.company_id)
        }
    }
    return @($ids | ForEach-Object { [string]$_ })
}

function Get-ToolNearestRankPercentile {
    param(
        [Parameter()][AllowEmptyCollection()][double[]]$Values = @(),
        [Parameter(Mandatory)][ValidateRange(0.01, 1.0)][double]$Percentile
    )

    $ordered = @($Values | Sort-Object)
    if ($ordered.Count -eq 0) {
        return $null
    }
    $rank = [Math]::Ceiling($Percentile * [double]$ordered.Count)
    $index = [Math]::Max(0, [Math]::Min($ordered.Count - 1, [int]$rank - 1))
    return [Math]::Round([double]$ordered[$index], 3)
}

function Add-ToolVerificationTelemetry {
    param(
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][string]$CandidateId,
        [Parameter(Mandatory)][datetime]$AttemptStartedAt,
        [Parameter(Mandatory)][datetime]$AttemptCompletedAt
    )

    $durationMs = [Math]::Max(0, [int][Math]::Round(($AttemptCompletedAt.ToUniversalTime() - $AttemptStartedAt.ToUniversalTime()).TotalMilliseconds))
    $requestCount = @($Result.fetches).Count
    $Result | Add-Member -NotePropertyName batch_telemetry -NotePropertyValue ([pscustomobject]@{
            candidate_id = $CandidateId
            attempt_started_at = ConvertTo-ToolIso -Value $AttemptStartedAt
            attempt_completed_at = ConvertTo-ToolIso -Value $AttemptCompletedAt
            duration_ms = $durationMs
            request_count = $requestCount
        }) -Force
    return $Result
}

function Invoke-ToolCandidateVerification {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$ExistingCompanies,
        [Parameter(Mandatory)][object]$Policy,
        [Parameter()][AllowNull()][scriptblock]$Fetcher,
        [Parameter(Mandatory)][datetime]$ObservedAt,
        [Parameter(Mandatory)][int]$ExpiresAfterDays
    )

    $candidateId = Get-ToolCandidateId -Candidate $Candidate
    $attemptStartedAt = [datetime]::UtcNow
    $verification = Resolve-JobAgentCompanyCandidateVerification -Candidate $Candidate -ExistingCompanies $ExistingCompanies -Policy $Policy -Fetcher $Fetcher -ObservedAt $ObservedAt -ExpiresAfterDays $ExpiresAfterDays
    return Add-ToolVerificationTelemetry -Result $verification -CandidateId $candidateId -AttemptStartedAt $attemptStartedAt -AttemptCompletedAt ([datetime]::UtcNow)
}

function New-ToolCandidateVerificationBatchMetrics {
    param(
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter(Mandatory)][datetime]$CompletedAt,
        [Parameter()][AllowEmptyCollection()][object[]]$Results = @(),
        [Parameter()][AllowEmptyCollection()][string[]]$BeforeOfficialCareerCompanyIds = @(),
        [Parameter()][AllowEmptyCollection()][string[]]$AfterOfficialCareerCompanyIds = @()
    )

    $durations = @($Results |
        Where-Object { $_.PSObject.Properties.Name -contains 'batch_telemetry' -and $null -ne $_.batch_telemetry } |
        ForEach-Object { [double]$_.batch_telemetry.duration_ms })
    $requestTotal = 0
    foreach ($result in @($Results)) {
        if ($result.PSObject.Properties.Name -contains 'batch_telemetry' -and $null -ne $result.batch_telemetry) {
            $requestTotal += [int]$result.batch_telemetry.request_count
        }
    }
    $before = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($BeforeOfficialCareerCompanyIds)) {
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            [void]$before.Add($id)
        }
    }
    $after = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($AfterOfficialCareerCompanyIds)) {
        if (-not [string]::IsNullOrWhiteSpace($id)) {
            [void]$after.Add($id)
        }
    }
    $newCareerCompanyIds = @($after | ForEach-Object { [string]$_ } | Where-Object { -not $before.Contains($_) } | Sort-Object)
    $wallclockSeconds = [Math]::Max(0.001, ($CompletedAt.ToUniversalTime() - $StartedAt.ToUniversalTime()).TotalSeconds)
    $processedTotal = @($Results).Count

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-batch-metrics/v1'
        started_at = ConvertTo-ToolIso -Value $StartedAt
        completed_at = ConvertTo-ToolIso -Value $CompletedAt
        wallclock_seconds = [Math]::Round($wallclockSeconds, 3)
        processed_total = $processedTotal
        verified_total = @($Results | Where-Object { [string]$_.status -in @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') }).Count
        official_career_verified_before = $before.Count
        official_career_verified_after = $after.Count
        net_official_career_growth = $newCareerCompanyIds.Count
        new_official_career_company_ids = $newCareerCompanyIds
        request_total = $requestTotal
        requests_per_candidate = if ($processedTotal -eq 0) { $null } else { [Math]::Round([double]$requestTotal / [double]$processedTotal, 3) }
        duration_ms_p50 = Get-ToolNearestRankPercentile -Values $durations -Percentile 0.50
        duration_ms_p95 = Get-ToolNearestRankPercentile -Values $durations -Percentile 0.95
        net_official_career_per_minute = if ($newCareerCompanyIds.Count -eq 0) { 0.0 } else { [Math]::Round([double]$newCareerCompanyIds.Count / ($wallclockSeconds / 60.0), 4) }
        denominator_note = 'Durations and request_total use actually processed unique candidates; net growth counts newly official career/ATS employers after the serial store commit.'
    }
}

function Read-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][datetime]$Now
    )

    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    }
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        generated_at = ConvertTo-ToolIso -Value $Now
        queue = @()
    }
}

function New-ToolQueueEntry {
    param(
        [Parameter(Mandatory)][object]$Candidate,
        [Parameter(Mandatory)][object]$Cluster,
        [Parameter()][AllowNull()][object]$Previous,
        [Parameter(Mandatory)][datetime]$Now
    )

    $candidateId = Get-ToolCandidateId -Candidate $Candidate
    $previousRetryCount = if ($null -eq $Previous) { 0 } else { [int]$Previous.retry_count }
    $previousNextAttemptAt = if ($null -eq $Previous) { $Now } else { ConvertTo-ToolDateOrNull -Value $Previous.next_attempt_at }
    $previousLastAttemptAt = if ($null -eq $Previous) { $null } else { ConvertTo-ToolDateOrNull -Value $Previous.last_attempt_at }
    $previousStatus = if ($null -eq $Previous) { 'PENDING' } else { [string]$Previous.status }
    $priority = if ($Candidate.PSObject.Properties.Name -contains 'confidence_score') { [int]$Candidate.confidence_score } elseif ($Candidate.PSObject.Properties.Name -contains 'priority_score') { [int]$Candidate.priority_score } else { 50 }

    [pscustomobject]@{
        identity_cluster_id = [string]$Cluster.identity_cluster_id
        candidate_id = $candidateId
        candidate_ids = @($Cluster.candidate_ids)
        canonical_name = [string]$Cluster.canonical_name
        source_count = [int]$Cluster.source_count
        priority_score = $priority + ([int]$Cluster.source_count * 5)
        target_area_basis = @($Cluster.target_area_basis)
        status = $previousStatus
        review_reason = [string]$Cluster.review_queue_reason
        retry_count = $previousRetryCount
        last_attempt_at = if ($null -eq $previousLastAttemptAt) { $null } else { ConvertTo-ToolIso -Value $previousLastAttemptAt }
        next_attempt_at = if ($null -eq $previousNextAttemptAt) { ConvertTo-ToolIso -Value $Now } else { ConvertTo-ToolIso -Value $previousNextAttemptAt }
        last_status = if ($null -eq $Previous -or $Previous.PSObject.Properties.Name -notcontains 'last_status') { $null } else { [string]$Previous.last_status }
        last_reason = if ($null -eq $Previous -or $Previous.PSObject.Properties.Name -notcontains 'last_reason') { $null } else { [string]$Previous.last_reason }
    }
}

function New-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Candidates,
        [Parameter(Mandatory)][object]$PreviousQueue,
        [Parameter(Mandatory)][datetime]$Now
    )

    $previousByCandidate = @{}
    foreach ($entry in @($PreviousQueue.queue)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$entry.candidate_id)) {
            $previousByCandidate[[string]$entry.candidate_id] = $entry
        }
    }
    $clusterReport = Resolve-JobAgentCompanyCandidateClusters -Candidates $Candidates -ObservedAt $Now
    $clusterByCandidate = @{}
    foreach ($cluster in @($clusterReport.clusters)) {
        foreach ($candidateId in @($cluster.candidate_ids)) {
            $clusterByCandidate[[string]$candidateId] = $cluster
        }
    }

    $entries = foreach ($candidate in @($Candidates)) {
        $candidateId = Get-ToolCandidateId -Candidate $candidate
        $previous = if ($previousByCandidate.ContainsKey($candidateId)) { $previousByCandidate[$candidateId] } else { $null }
        New-ToolQueueEntry -Candidate $candidate -Cluster $clusterByCandidate[$candidateId] -Previous $previous -Now $Now
    }

    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-queue/v1'
        generated_at = ConvertTo-ToolIso -Value $Now
        clusters_total = [int]$clusterReport.clusters_total
        candidates_total = @($Candidates).Count
        ready_total = @($entries | Where-Object { Test-ToolCandidateVerificationQueueEntryReady -Entry $_ -Now $Now }).Count
        queue = @($entries | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id)
    }
}

function Get-ToolCandidateActionabilityScore {
    param(
        [Parameter()][AllowNull()][object]$Candidate
    )

    if ($null -eq $Candidate) {
        return 0
    }
    $score = 0
    if ($Candidate.PSObject.Properties.Name -contains 'known_company_domain' -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.known_company_domain)) {
        $score += 100
    }
    if ($Candidate.PSObject.Properties.Name -contains 'known_company_id' -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.known_company_id)) {
        $score += 25
    }
    if ($Candidate.PSObject.Properties.Name -contains 'official_website_url' -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.official_website_url)) {
        $score += 100
    }
    if ($Candidate.PSObject.Properties.Name -contains 'canonical_domain' -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.canonical_domain)) {
        $score += 75
    }
    if ($Candidate.PSObject.Properties.Name -contains 'is_staffing_agency' -and [bool]$Candidate.is_staffing_agency -eq $true) {
        $score -= 100
    }
    return $score
}

function Get-ToolEntryProperty {
    param(
        [Parameter()][AllowNull()][object]$Entry,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Entry -or $Entry.PSObject.Properties.Name -notcontains $Name) {
        return $Default
    }
    return $Entry.$Name
}

function ConvertTo-ToolActionCounts {
    param(
        [Parameter()][AllowEmptyCollection()][object[]]$Entries = @()
    )

    $counts = [ordered]@{}
    foreach ($entry in @($Entries)) {
        $action = [string](Get-ToolEntryProperty -Entry $entry -Name 'next_action' -Default 'VERIFY_OFFICIAL_SITE')
        if ([string]::IsNullOrWhiteSpace($action)) {
            $action = 'VERIFY_OFFICIAL_SITE'
        }
        if (-not $counts.Contains($action)) {
            $counts[$action] = 0
        }
        $counts[$action]++
    }
    return [pscustomobject]$counts
}

function Test-ToolCandidateVerificationQueueEntryReady {
    param(
        [Parameter(Mandatory)][object]$Entry,
        [Parameter(Mandatory)][datetime]$Now
    )

    $status = [string](Get-ToolEntryProperty -Entry $Entry -Name 'status' -Default '')
    if ($status -notin @('PENDING', 'RETRY_SCHEDULED')) {
        return $false
    }

    $action = [string](Get-ToolEntryProperty -Entry $Entry -Name 'next_action' -Default 'VERIFY_OFFICIAL_SITE')
    if ($action -ne 'VERIFY_OFFICIAL_SITE') {
        return $false
    }

    $dueAt = ConvertTo-ToolDateOrNull -Value (Get-ToolEntryProperty -Entry $Entry -Name 'next_attempt_at' -Default $null)
    if ($null -eq $dueAt) {
        return $status -eq 'PENDING'
    }

    return $dueAt -le $Now.ToUniversalTime()
}

function Get-ToolCandidateHostKey {
    param([Parameter(Mandatory)][object]$Candidate)

    foreach ($property in @('official_website_url', 'verified_official_website_url', 'known_company_domain', 'canonical_domain')) {
        if ($Candidate.PSObject.Properties.Name -notcontains $property -or [string]::IsNullOrWhiteSpace([string]$Candidate.$property)) {
            continue
        }
        $value = [string]$Candidate.$property
        try {
            if ($value -notmatch '^[a-z][a-z0-9+.-]*://') {
                $value = 'https://' + $value.Trim('/')
            }
            return (([Uri]$value).Host.ToLowerInvariant() -replace '^www\.', '')
        }
        catch {
            continue
        }
    }
    return 'candidate:' + (Get-ToolCandidateId -Candidate $Candidate)
}

function Select-ToolHostLimitedCandidates {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Candidates,
        [Parameter(Mandatory)][int]$HostLimit
    )

    $selected = [System.Collections.Generic.List[object]]::new()
    $hostCounts = @{}
    foreach ($candidate in $Candidates) {
        $hostKey = Get-ToolCandidateHostKey -Candidate $candidate
        $count = if ($hostCounts.ContainsKey($hostKey)) { [int]$hostCounts[$hostKey] } else { 0 }
        if ($count -ge $HostLimit) {
            continue
        }
        $hostCounts[$hostKey] = $count + 1
        $selected.Add($candidate)
    }
    return $selected.ToArray()
}

function Get-ToolResultCheckpointRoot {
    param([Parameter(Mandatory)][string]$CheckpointPath)

    return $CheckpointPath + '.results'
}

function Get-ToolResultCheckpointPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$CandidateId
    )

    return Join-Path $Root ((Get-ToolTextSha256 -Text $CandidateId) + '.json')
}

function Write-ToolJsonAtomic {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value,
        [Parameter()][ValidateRange(1, 100)][int]$Depth = 100
    )

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $temporaryPath = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        $Value | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-ToolCandidateResultCheckpoint {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][object]$Result
    )

    $candidateId = [string]$Result.candidate_id
    if ([string]::IsNullOrWhiteSpace($candidateId)) {
        throw 'Resultat enthaelt keine candidate_id fuer den Resume-Checkpoint.'
    }
    $path = Get-ToolResultCheckpointPath -Root $Root -CandidateId $candidateId
    Write-ToolJsonAtomic -Path $path -Value $Result -Depth 100
    return $path
}

function Read-ToolBatchCheckpoint {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
}

function Read-ToolCheckpointResults {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter()][AllowEmptyCollection()][string[]]$CandidateIds = @()
    )

    $items = New-Object System.Collections.Generic.List[object]
    foreach ($candidateId in @($CandidateIds)) {
        if ([string]::IsNullOrWhiteSpace($candidateId)) {
            continue
        }
        $path = Get-ToolResultCheckpointPath -Root $Root -CandidateId $candidateId
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $items.Add((Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 100))
        }
    }
    return $items.ToArray()
}

function Write-ToolBatchCheckpoint {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$State,
        [Parameter(Mandatory)][datetime]$StartedAt,
        [Parameter()][AllowEmptyCollection()][object[]]$CandidateIds = @(),
        [Parameter()][AllowEmptyCollection()][object[]]$CompletedCandidateIds = @(),
        [Parameter()][string]$ResultCheckpointRoot = '',
        [Parameter()][AllowNull()][object]$CommitAppliedAt = $null,
        [Parameter()][AllowNull()][object]$Metrics = $null
    )

    $checkpoint = [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-checkpoint/v1'
        state = $State
        started_at = ConvertTo-ToolIso -Value $StartedAt
        updated_at = ConvertTo-ToolIso -Value ([datetime]::UtcNow)
        candidate_ids = @($CandidateIds)
        completed_candidate_ids = @($CompletedCandidateIds)
        pending_candidate_ids = @($CandidateIds | Where-Object { $_ -notin @($CompletedCandidateIds) })
        result_checkpoint_root = $ResultCheckpointRoot
        commit_applied_at = if ($null -eq $CommitAppliedAt) { $null } else { ConvertTo-ToolIso -Value $CommitAppliedAt }
        metrics = $Metrics
    }
    Write-ToolJsonAtomic -Path $Path -Value $checkpoint -Depth 20
}

function Update-ToolCandidateVerificationQueue {
    param(
        [Parameter(Mandatory)][object]$Queue,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][datetime]$Now,
        [Parameter(Mandatory)][int]$MaxRetries
    )

    $resultsByCandidate = @{}
    foreach ($result in @($Results)) {
        $resultsByCandidate[[string]$result.candidate_id] = $result
    }
    $updated = foreach ($entry in @($Queue.queue)) {
        if (-not $resultsByCandidate.ContainsKey([string]$entry.candidate_id)) {
            $entry
            continue
        }
        $result = $resultsByCandidate[[string]$entry.candidate_id]
        $status = [string]$result.status
        $isVerified = @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains $status
        $retryCount = [int]$entry.retry_count
        $nextAttemptAt = $null
        $queueStatus = if ($isVerified) {
            'VERIFIED'
        }
        elseif ($status -eq 'MANUAL_REVIEW_REQUIRED') {
            'MANUAL_REVIEW_REQUIRED'
        }
        else {
            $retryCount++
            if ($retryCount -ge $MaxRetries) {
                'RETRY_EXHAUSTED'
            }
            else {
                $retryAfterSeconds = @($result.fetches |
                    Where-Object { $_.PSObject.Properties.Name -contains 'retry_after_seconds' -and $null -ne $_.retry_after_seconds } |
                    ForEach-Object { [int]$_.retry_after_seconds } |
                    Sort-Object -Descending |
                    Select-Object -First 1)
                if ($retryAfterSeconds.Count -eq 1 -and $retryAfterSeconds[0] -gt 0) {
                    $nextAttemptAt = $Now.ToUniversalTime().AddSeconds($retryAfterSeconds[0])
                }
                else {
                    $nextAttemptAt = $Now.ToUniversalTime().AddHours([Math]::Min([double]168, [double](24 * [Math]::Pow(2, ($retryCount - 1)))))
                }
                'RETRY_SCHEDULED'
            }
        }
        [pscustomobject]@{
            identity_cluster_id = [string]$entry.identity_cluster_id
            candidate_id = [string]$entry.candidate_id
            candidate_ids = @($entry.candidate_ids)
            canonical_name = [string]$entry.canonical_name
            source_count = [int]$entry.source_count
            priority_score = [int]$entry.priority_score
            next_action = if ($isVerified) { [string]$result.next_action } else { [string](Get-ToolEntryProperty -Entry $entry -Name 'next_action' -Default 'VERIFY_OFFICIAL_SITE') }
            reason_codes = @((Get-ToolEntryProperty -Entry $entry -Name 'reason_codes' -Default @()))
            target_area_basis = @($entry.target_area_basis)
            status = $queueStatus
            review_reason = if (@($result.review_reasons).Count -gt 0) { (@($result.review_reasons) -join ',') } elseif ($queueStatus -eq 'RETRY_EXHAUSTED') { 'RETRY_EXHAUSTED' } else { [string]$entry.review_reason }
            retry_count = $retryCount
            last_attempt_at = ConvertTo-ToolIso -Value $Now
            next_attempt_at = if ($null -eq $nextAttemptAt) { $null } else { ConvertTo-ToolIso -Value $nextAttemptAt }
            last_status = $status
            last_reason = if (@($result.evidence).Count -gt 0) { [string]$result.evidence[0].reason } else { [string]$result.next_action }
            freshness_status = [string](Get-ToolEntryProperty -Entry $entry -Name 'freshness_status' -Default 'UNKNOWN')
            risk_level = [string](Get-ToolEntryProperty -Entry $entry -Name 'risk_level' -Default 'LOW')
            source_evidence = Get-ToolEntryProperty -Entry $entry -Name 'source_evidence' -Default $null
            dedupe_context = Get-ToolEntryProperty -Entry $entry -Name 'dedupe_context' -Default $null
        }
    }

    $Queue.queue = @($updated | Sort-Object @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id)
    $Queue.generated_at = ConvertTo-ToolIso -Value $Now
    $Queue.ready_total = @($Queue.queue | Where-Object { Test-ToolCandidateVerificationQueueEntryReady -Entry $_ -Now $Now }).Count
    $Queue | Add-Member -NotePropertyName action_counts -NotePropertyValue (ConvertTo-ToolActionCounts -Entries @($Queue.queue)) -Force
    if ($Queue.PSObject.Properties.Name -notcontains 'queue_type') {
        $Queue | Add-Member -NotePropertyName queue_type -NotePropertyValue 'review' -Force
    }
    return $Queue
}

function New-ToolCandidateVerificationDecisionReport {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Results,
        [Parameter(Mandatory)][object]$Queue
    )

    $queueByCandidate = @{}
    foreach ($entry in @($Queue.queue)) {
        $queueByCandidate[[string]$entry.candidate_id] = $entry
    }

    $items = foreach ($result in @($Results)) {
        $candidateId = [string]$result.candidate_id
        $queueEntry = if ($queueByCandidate.ContainsKey($candidateId)) { $queueByCandidate[$candidateId] } else { $null }
        $evidence = @($result.evidence | Select-Object -First 1)
        $verificationUrl = if ($evidence.Count -gt 0) { $evidence[0].verification_url } else { $null }
        $reason = if (@($result.review_reasons).Count -gt 0) {
            @($result.review_reasons) -join ','
        }
        elseif ($evidence.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$evidence[0].reason)) {
            [string]$evidence[0].reason
        }
        else {
            [string]$result.next_action
        }
        $queueStatus = if ($null -eq $queueEntry) { 'UNKNOWN' } else { [string]$queueEntry.status }
        [pscustomobject]@{
            candidate_id = $candidateId
            company_id = if ($result.PSObject.Properties.Name -contains 'company_id') { $result.company_id } else { $null }
            canonical_name = if ($evidence.Count -gt 0) { [string]$evidence[0].canonical_name } elseif ($null -ne $queueEntry) { [string]$queueEntry.canonical_name } else { 'UNKNOWN' }
            verification_status = [string]$result.status
            queue_status = $queueStatus
            decision = if (@('VERIFIED') -contains $queueStatus) { 'PRODUCTIVE_UPSERT_ALLOWED' } elseif ($queueStatus -eq 'RETRY_SCHEDULED') { 'RETRY_DEFERRED' } else { 'FAIL_CLOSED_REVIEW_OR_REJECT' }
            reason = $reason
            verification_url = $verificationUrl
            next_attempt_at = if ($null -eq $queueEntry) { $null } else { $queueEntry.next_attempt_at }
        }
    }

    $reviewItems = @($items | Where-Object { [string]$_.queue_status -eq 'MANUAL_REVIEW_REQUIRED' })
    $rejectItems = @($items | Where-Object { [string]$_.queue_status -in @('RETRY_SCHEDULED', 'RETRY_EXHAUSTED') })
    [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-decision-report/v1'
        processed_total = @($items).Count
        productive_upsert_allowed_total = @($items | Where-Object { [string]$_.decision -eq 'PRODUCTIVE_UPSERT_ALLOWED' }).Count
        manual_review_total = $reviewItems.Count
        fail_closed_reject_total = $rejectItems.Count
        review_items = @($reviewItems | Sort-Object canonical_name, candidate_id)
        reject_items = @($rejectItems | Sort-Object canonical_name, candidate_id)
        items = @($items | Sort-Object decision, canonical_name, candidate_id)
    }
}

$startedAt = [datetime]::UtcNow
$hintStoreResolved = Resolve-ToolPath -Root $projectRootResolved -Path $HintStorePath
$sourceRegistryResolved = Resolve-ToolPath -Root $projectRootResolved -Path $SourceRegistryPath
$queueResolved = Resolve-ToolPath -Root $projectRootResolved -Path $QueuePath
if (-not (Test-Path -LiteralPath $hintStoreResolved -PathType Leaf)) {
    throw "Discovery-Hint-Store fehlt: $hintStoreResolved"
}

$hintStore = Get-Content -Raw -LiteralPath $hintStoreResolved | ConvertFrom-Json -Depth 100
$sourceRegistry = if (Test-Path -LiteralPath $sourceRegistryResolved -PathType Leaf) { Get-Content -Raw -LiteralPath $sourceRegistryResolved | ConvertFrom-Json -Depth 100 } else { $null }
$policy = New-JobAgentCompanyCareerVerificationPolicy -TimeoutSeconds $TimeoutSeconds -HostConcurrency $HostConcurrency
$fetcher = if ([string]::IsNullOrWhiteSpace($FixtureMapPath)) { $null } else { New-ToolFixtureFetcher -Path (Resolve-ToolPath -Root $projectRootResolved -Path $FixtureMapPath) }
$checkpointResolved = Resolve-ToolPath -Root $projectRootResolved -Path $CheckpointPath
$resultCheckpointRoot = Get-ToolResultCheckpointRoot -CheckpointPath $checkpointResolved
$results = New-Object System.Collections.Generic.List[object]
$queue = $null
$document = $null
$resumeCheckpoint = Read-ToolBatchCheckpoint -Path $checkpointResolved
$resumeResultItems = @()
$resumeCandidateIds = @()
$resumedFromCheckpoint = $false

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRootResolved -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot
    $beforeOfficialCareerCompanyIds = @(Get-ToolOfficialCareerCompanyIds -Document $document)
    $previousQueue = Read-ToolCandidateVerificationQueue -Path $queueResolved -Now $startedAt
    $queue = New-JobAgentCoverageCandidateReviewQueue -HintStore $hintStore -SourceRegistry $sourceRegistry -PreviousQueue $previousQueue -ExistingCompanies @($document.companies) -Now $startedAt -MaxItems 1000
    $candidateById = @{}
    foreach ($candidate in @($hintStore.hints)) {
        $candidateById[(Get-ToolCandidateId -Candidate $candidate)] = $candidate
    }
    $checkpointCommitAppliedAt = if ($null -ne $resumeCheckpoint -and $resumeCheckpoint.PSObject.Properties.Name -contains 'commit_applied_at') { [string]$resumeCheckpoint.commit_applied_at } else { $null }
    if ($null -ne $resumeCheckpoint -and [string]$resumeCheckpoint.state -eq 'running' -and [string]::IsNullOrWhiteSpace($checkpointCommitAppliedAt)) {
        $checkpointCandidateIds = @($resumeCheckpoint.candidate_ids | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($checkpointCandidateIds.Count -gt 0) {
            $checkpointResultRoot = if ($resumeCheckpoint.PSObject.Properties.Name -contains 'result_checkpoint_root' -and -not [string]::IsNullOrWhiteSpace([string]$resumeCheckpoint.result_checkpoint_root)) { [string]$resumeCheckpoint.result_checkpoint_root } else { $resultCheckpointRoot }
            $resumeResultItems = @(Read-ToolCheckpointResults -Root $checkpointResultRoot -CandidateIds $checkpointCandidateIds)
            $resumeCandidateIds = @($resumeResultItems | ForEach-Object { [string]$_.candidate_id })
            $targetCandidates = @($checkpointCandidateIds |
                Where-Object { $candidateById.ContainsKey($_) -and $_ -notin $resumeCandidateIds } |
                ForEach-Object { $candidateById[$_] })
            $startedAt = ConvertTo-ToolDateOrNull -Value $resumeCheckpoint.started_at
            if ($null -eq $startedAt) {
                $startedAt = [datetime]::UtcNow
            }
            $resumedFromCheckpoint = $true
        }
    }
    if (-not $resumedFromCheckpoint) {
        $targetCandidates = @($queue.queue |
            Where-Object {
                Test-ToolCandidateVerificationQueueEntryReady -Entry $_ -Now $startedAt
            } |
            Sort-Object @{ Expression = { -[int](Get-ToolCandidateActionabilityScore -Candidate $candidateById[[string]$_.candidate_id]) }; Ascending = $true }, @{ Expression = { -[int]$_.priority_score }; Ascending = $true }, canonical_name, candidate_id |
            ForEach-Object { $candidateById[[string]$_.candidate_id] } |
            Select-Object -First $MaxCandidates)
    }
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

if (-not $resumedFromCheckpoint) {
    $targetCandidates = @(Select-ToolHostLimitedCandidates -Candidates $targetCandidates -HostLimit $HostConcurrency)
}
$existingCompanies = @($document.companies)
$plannedCandidateIds = if ($resumedFromCheckpoint) { @($resumeCheckpoint.candidate_ids | ForEach-Object { [string]$_ }) } else { @($targetCandidates | ForEach-Object { Get-ToolCandidateId -Candidate $_ }) }
foreach ($resumeResult in $resumeResultItems) {
    $results.Add($resumeResult)
}
Write-ToolBatchCheckpoint -Path $checkpointResolved -State 'running' -StartedAt $startedAt -CandidateIds $plannedCandidateIds -CompletedCandidateIds $resumeCandidateIds -ResultCheckpointRoot $resultCheckpointRoot -Metrics ([pscustomObject]@{ worker_count = $WorkerCount; host_concurrency = $HostConcurrency; resume_results_loaded = $resumeCandidateIds.Count })

if ($null -ne $fetcher -or $targetCandidates.Count -le 1) {
    foreach ($candidate in $targetCandidates) {
        $verification = Invoke-ToolCandidateVerification -Candidate $candidate -ExistingCompanies $existingCompanies -Policy $policy -Fetcher $fetcher -ObservedAt $startedAt -ExpiresAfterDays $ExpiresAfterDays
        [void](Write-ToolCandidateResultCheckpoint -Root $resultCheckpointRoot -Result $verification)
        $results.Add($verification)
        Write-ToolBatchCheckpoint -Path $checkpointResolved -State 'running' -StartedAt $startedAt -CandidateIds $plannedCandidateIds -CompletedCandidateIds @($results | ForEach-Object { [string]$_.candidate_id }) -ResultCheckpointRoot $resultCheckpointRoot -Metrics ([pscustomobject]@{ worker_count = $WorkerCount; host_concurrency = $HostConcurrency; resume_results_loaded = $resumeCandidateIds.Count })
    }
}
else {
    $sourceVerificationModule = Join-Path $toolRoot 'src\JobAgent.SourceVerification.psm1'
    $parallelResultCheckpointRoot = $resultCheckpointRoot
    $parallelResults = $targetCandidates | ForEach-Object -Parallel {
        Import-Module $using:sourceVerificationModule -Force -DisableNameChecking
        function Get-ToolCandidateIdLocal {
            param([Parameter(Mandatory)][object]$Candidate)
            foreach ($property in @('candidate_id', 'hint_id', 'company_id')) {
                if ($Candidate.PSObject.Properties.Name -contains $property -and -not [string]::IsNullOrWhiteSpace([string]$Candidate.$property)) {
                    return [string]$Candidate.$property
                }
            }
            throw 'Kandidat enthaelt keine stabile ID.'
        }
        function Get-ToolTextSha256Local {
            param([Parameter()][AllowEmptyString()][string]$Text)
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
            $hash = [Security.Cryptography.SHA256]::Create()
            try {
                return ([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
            }
            finally {
                $hash.Dispose()
            }
        }
        function Write-ToolJsonAtomicLocal {
            param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object]$Value)
            New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
            $temporaryPath = $Path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
            try {
                $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $temporaryPath -Encoding UTF8
                Move-Item -LiteralPath $temporaryPath -Destination $Path -Force
            }
            finally {
                if (Test-Path -LiteralPath $temporaryPath) {
                    Remove-Item -LiteralPath $temporaryPath -Force
                }
            }
        }
        $candidateId = Get-ToolCandidateIdLocal -Candidate $_
        $attemptStartedAt = [datetime]::UtcNow
        $verification = Resolve-JobAgentCompanyCandidateVerification -Candidate $_ -ExistingCompanies $using:existingCompanies -Policy $using:policy -ObservedAt $using:startedAt -ExpiresAfterDays $using:ExpiresAfterDays
        $durationMs = [Math]::Max(0, [int][Math]::Round((([datetime]::UtcNow).ToUniversalTime() - $attemptStartedAt.ToUniversalTime()).TotalMilliseconds))
        $verification | Add-Member -NotePropertyName batch_telemetry -NotePropertyValue ([pscustomobject]@{
                candidate_id = $candidateId
                attempt_started_at = $attemptStartedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
                attempt_completed_at = ([datetime]::UtcNow).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
                duration_ms = $durationMs
                request_count = @($verification.fetches).Count
            }) -Force
        $resultPath = Join-Path $using:parallelResultCheckpointRoot ((Get-ToolTextSha256Local -Text $candidateId) + '.json')
        Write-ToolJsonAtomicLocal -Path $resultPath -Value $verification
        $verification
    } -ThrottleLimit $WorkerCount
    foreach ($verification in @($parallelResults)) {
        $results.Add($verification)
    }
    Write-ToolBatchCheckpoint -Path $checkpointResolved -State 'running' -StartedAt $startedAt -CandidateIds $plannedCandidateIds -CompletedCandidateIds @($results | ForEach-Object { [string]$_.candidate_id }) -ResultCheckpointRoot $resultCheckpointRoot -Metrics ([pscustomobject]@{ worker_count = $WorkerCount; host_concurrency = $HostConcurrency; resume_results_loaded = $resumeCandidateIds.Count })
}

if ($StopBeforeCommitForResumeTest) {
    $resumeRunId = $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
    $resumeLogRoot = Resolve-ToolPath -Root $projectRootResolved -Path $LogRoot
    $resumeLogPath = Join-Path $resumeLogRoot ('JA-027-resume-' + $resumeRunId + '.json')
    $resumeSummary = [pscustomobject]@{
        schema_version = 'jobagent/company-candidate-verification-resume/v1'
        state = 'network_checkpoint_only'
        checkpoint_path = $checkpointResolved
        result_checkpoint_root = $resultCheckpointRoot
        planned_candidate_ids = $plannedCandidateIds
        completed_candidate_ids = @($results | ForEach-Object { [string]$_.candidate_id })
        commit_applied = $false
    }
    Write-ToolJsonAtomic -Path $resumeLogPath -Value $resumeSummary -Depth 20
    $resumeSummary | Add-Member -NotePropertyName resume_log_path -NotePropertyValue $resumeLogPath -PassThru | ConvertTo-Json -Depth 20
    exit 77
}

$lock = Enter-JobAgentStoreLock -ProjectRoot $projectRootResolved -DataRoot $DataRoot
try {
    $document = Read-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot
    foreach ($verification in @($results.ToArray())) {
        $candidate = $candidateById[[string]$verification.candidate_id]
        if (@('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -notcontains [string]$verification.status) {
            continue
        }
        $company = ConvertTo-ToolCompanyFromCandidateVerification -Candidate $candidate -Verification $verification -ObservedAt $startedAt
        $document = Upsert-JobAgentCompany -Document $document -Company $company
        if (@('CAREER_URL_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$verification.status) {
            $source = New-ToolJobSourceFromCandidateVerification -Verification $verification -ObservedAt $startedAt
            if ($null -ne $source) {
                $document = Upsert-JobAgentJobSource -Document $document -JobSource $source
            }
        }
    }
    $queue = Update-ToolCandidateVerificationQueue -Queue $queue -Results @($results.ToArray()) -Now $startedAt -MaxRetries $MaxRetries
    New-Item -ItemType Directory -Path (Split-Path -Parent $queueResolved) -Force | Out-Null
    $queue | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $queueResolved -Encoding UTF8
    $storePath = Write-JobAgentStore -ProjectRoot $projectRootResolved -DataRoot $DataRoot -Document $document -CreateBackup
    $afterOfficialCareerCompanyIds = @(Get-ToolOfficialCareerCompanyIds -Document $document)
}
finally {
    Exit-JobAgentStoreLock -Lock $lock
}

$completedAt = [datetime]::UtcNow
$batchMetrics = New-ToolCandidateVerificationBatchMetrics -StartedAt $startedAt -CompletedAt $completedAt -Results @($results.ToArray()) -BeforeOfficialCareerCompanyIds $beforeOfficialCareerCompanyIds -AfterOfficialCareerCompanyIds $afterOfficialCareerCompanyIds
Write-ToolBatchCheckpoint -Path $checkpointResolved -State 'completed' -StartedAt $startedAt -CandidateIds $plannedCandidateIds -CompletedCandidateIds @($results | ForEach-Object { [string]$_.candidate_id }) -ResultCheckpointRoot $resultCheckpointRoot -CommitAppliedAt $completedAt -Metrics $batchMetrics

$logRootPath = Resolve-ToolPath -Root $projectRootResolved -Path $LogRoot
New-Item -ItemType Directory -Path $logRootPath -Force | Out-Null
$runId = $startedAt.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
$logPath = Join-Path $logRootPath ('JA-027-batch-' + $runId + '.json')
$resumeLogPath = Join-Path $logRootPath ('JA-027-resume-' + $runId + '.json')
$resultItems = @($results.ToArray())
$logResultItems = [object[]]@($resultItems | ForEach-Object { ConvertTo-ToolVerificationLogResult -Result $_ })
$fetchErrorSummary = New-ToolFetchErrorSummary -Results $logResultItems
$queueItems = @($queue.queue)
$checkedCandidateIds = @($resultItems | ForEach-Object { [string]$_.candidate_id })
$verifiedCandidateIds = @($resultItems | Where-Object { @('CAREER_URL_VERIFIED', 'COMPANY_DOMAIN_VERIFIED', 'OFFICIAL_ATS_VERIFIED') -contains [string]$_.status } | ForEach-Object { [string]$_.candidate_id })
$manualReviewCandidateIds = @($resultItems | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' } | ForEach-Object { [string]$_.candidate_id })
$unverifiedCandidateIds = @($resultItems | Where-Object { [string]$_.status -eq 'UNVERIFIED' } | ForEach-Object { [string]$_.candidate_id })
$resumeReport = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-verification-resume/v1'
    checkpoint_path = $checkpointResolved
    result_checkpoint_root = $resultCheckpointRoot
    resumed_from_running_checkpoint = $resumedFromCheckpoint
    planned_candidate_ids = $plannedCandidateIds
    loaded_candidate_ids = $resumeCandidateIds
    completed_candidate_ids = $checkedCandidateIds
    pending_candidate_ids = @($plannedCandidateIds | Where-Object { $_ -notin $checkedCandidateIds })
    commit_applied = $true
    commit_applied_at = ConvertTo-ToolIso -Value $completedAt
}
Write-ToolJsonAtomic -Path $resumeLogPath -Value $resumeReport -Depth 30
$summary = [pscustomobject]@{
    schema_version = 'jobagent/company-candidate-verification/v1'
    ts = ConvertTo-ToolIso -Value $startedAt
    store_path = $storePath
    hint_store_path = $hintStoreResolved
    queue_path = $queueResolved
    checkpoint_path = $checkpointResolved
    run_id = $runId
    batch_policy = [pscustomobject]@{ worker_count = $WorkerCount; host_concurrency = $HostConcurrency; writer = 'serial_atomic_store_writer' }
    batch_metrics = $batchMetrics
    resume_report = $resumeReport
    resume_log_path = $resumeLogPath
    policy = $policy
    verification_queue = [pscustomobject]@{
        clusters_total = [int]$queue.clusters_total
        candidates_total = [int]$queue.candidates_total
        ready_total = [int]$queue.ready_total
        processed_total = $resultItems.Count
        retry_scheduled_total = @($queueItems | Where-Object { [string]$_.status -eq 'RETRY_SCHEDULED' }).Count
        manual_review_total = @($queueItems | Where-Object { [string]$_.status -eq 'MANUAL_REVIEW_REQUIRED' }).Count
        verified_total = @($queueItems | Where-Object { [string]$_.status -eq 'VERIFIED' }).Count
    }
    checked_candidate_ids = $checkedCandidateIds
    verified_candidate_ids = $verifiedCandidateIds
    manual_review_candidate_ids = $manualReviewCandidateIds
    unverified_candidate_ids = $unverifiedCandidateIds
    fetch_error_summary = $fetchErrorSummary
    decision_report = New-ToolCandidateVerificationDecisionReport -Results $resultItems -Queue $queue
    results = $logResultItems
}
$summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $logPath -Encoding UTF8
$summary | Add-Member -NotePropertyName log_path -NotePropertyValue $logPath -PassThru | ConvertTo-Json -Depth 100
