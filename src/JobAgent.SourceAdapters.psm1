#requires -Version 7.4

Set-StrictMode -Version 3.0

$script:AdapterErrorClasses = @(
    'NONE',
    'NOT_REACHABLE',
    'TIMEOUT',
    'BLOCKED',
    'NO_JOBS_FOUND',
    'UNCLEAR_SOURCE',
    'PARSING_ERROR',
    'TECHNICAL_LIMITATION'
)

$script:RetryRecommendations = @(
    'NONE',
    'RETRY_SOON',
    'RETRY_NEXT_RUN',
    'MANUAL_REVIEW'
)

function ConvertTo-JobAgentAdapterSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $slug = $Value.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Adapter-Slug darf nicht leer sein.'
    }
    return $slug
}

function New-JobAgentScanContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 600)][int]$TimeoutSeconds = 30,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxResults = 100,
        [Parameter()][string[]]$SearchTerms = @()
    )

    if ($ScanRunId -notmatch '^scanrun:[A-Za-z0-9][A-Za-z0-9._:-]*$') {
        throw "Ungueltige scan_run_id: $ScanRunId"
    }

    [pscustomobject]@{
        scan_run_id = $ScanRunId
        started_at = $StartedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        timeout_seconds = $TimeoutSeconds
        max_results = $MaxResults
        search_terms = @($SearchTerms | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function New-JobAgentAdapterInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Company,
        [Parameter(Mandatory)][object]$JobSource,
        [Parameter(Mandatory)][object]$ScanContext
    )

    foreach ($property in @('company_id', 'canonical_name', 'canonical_domain')) {
        if (($Company.PSObject.Properties.Name -notcontains $property) -or [string]::IsNullOrWhiteSpace([string]$Company.$property)) {
            throw "AdapterInput Company fehlt Pflichtfeld $property."
        }
    }
    foreach ($property in @('source_id', 'company_id', 'url', 'canonical_url', 'is_official')) {
        if ($JobSource.PSObject.Properties.Name -notcontains $property) {
            throw "AdapterInput JobSource fehlt Pflichtfeld $property."
        }
    }
    if ($JobSource.is_official -ne $true) {
        throw "AdapterInput akzeptiert keine nicht-offizielle Quelle: $($JobSource.source_id)"
    }
    if ([string]$JobSource.company_id -ne [string]$Company.company_id) {
        throw "AdapterInput Company und JobSource passen nicht zusammen: $($Company.company_id) / $($JobSource.company_id)"
    }
    if ($ScanContext.PSObject.Properties.Name -notcontains 'scan_run_id') {
        throw 'AdapterInput ScanContext fehlt scan_run_id.'
    }

    [pscustomobject]@{
        company = $Company
        source = $JobSource
        scan_context = $ScanContext
    }
}

function New-JobAgentRawJob {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$DetailUrl,
        [Parameter()][AllowNull()][string]$ExternalJobId,
        [Parameter()][AllowNull()][string]$AtsJobId,
        [Parameter()][AllowNull()][string]$LocationLabel,
        [Parameter()][AllowNull()][string]$Summary,
        [Parameter()][ValidateRange(0, 100)][int]$ExtractionConfidence = 80,
        [Parameter()][ValidateSet('ACTIVE', 'OPEN', 'PUBLISHED', 'CLOSED', 'EXPIRED', 'FILLED')][string]$SourceStatus = 'ACTIVE'
    )

    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw 'RawJob title darf nicht leer sein.'
    }
    if (-not [Uri]::IsWellFormedUriString($DetailUrl, [UriKind]::Absolute)) {
        throw "RawJob detail_url ist keine absolute URL: $DetailUrl"
    }

    [pscustomobject]@{
        title = $Title.Trim()
        detail_url = $DetailUrl
        external_job_id = if ([string]::IsNullOrWhiteSpace($ExternalJobId)) { 'UNKNOWN' } else { $ExternalJobId.Trim() }
        ats_job_id = if ([string]::IsNullOrWhiteSpace($AtsJobId)) { 'UNKNOWN' } else { $AtsJobId.Trim() }
        location_label = if ([string]::IsNullOrWhiteSpace($LocationLabel)) { 'UNKNOWN' } else { $LocationLabel.Trim() }
        summary = if ([string]::IsNullOrWhiteSpace($Summary)) { 'UNKNOWN' } else { $Summary.Trim() }
        extraction_confidence = $ExtractionConfidence
        source_status = $SourceStatus
    }
}

function New-JobAgentScanAttemptRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter(Mandatory)][string]$AdapterName,
        [Parameter(Mandatory)][ValidateSet('SUCCESS', 'PARTIAL', 'FAILED', 'SKIPPED')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('NONE', 'NOT_REACHABLE', 'TIMEOUT', 'BLOCKED', 'NO_JOBS_FOUND', 'UNCLEAR_SOURCE', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')][string]$ErrorClass,
        [Parameter(Mandatory)][ValidateSet('NONE', 'RETRY_SOON', 'RETRY_NEXT_RUN', 'MANUAL_REVIEW')][string]$RetryRecommendation,
        [Parameter()][AllowNull()][Nullable[int]]$HttpStatus,
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$FinishedAt = [datetime]::UtcNow
    )

    if (($null -ne $HttpStatus) -and (($HttpStatus -lt 100) -or ($HttpStatus -gt 599))) {
        throw "Ungueltiger HTTP-Status: $HttpStatus"
    }
    $sourceId = [string]$AdapterInput.source.source_id
    $companyId = [string]$AdapterInput.company.company_id
    $scanRunId = [string]$AdapterInput.scan_context.scan_run_id
    $stamp = $StartedAt.ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ', [Globalization.CultureInfo]::InvariantCulture)
    $attemptId = 'scanattempt:' + (ConvertTo-JobAgentAdapterSlug -Value ($companyId.Substring(8) + '_' + $sourceId.Substring(7) + '_' + $stamp))

    [pscustomobject]@{
        scan_attempt_id = $attemptId
        scan_run_id = $scanRunId
        company_id = $companyId
        source_id = $sourceId
        started_at = $StartedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        finished_at = $FinishedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        status = $Status
        adapter = $AdapterName
        error_class = $ErrorClass
        retry_recommendation = $RetryRecommendation
        http_status = $HttpStatus
    }
}

function New-JobAgentAdapterResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter(Mandatory)][string]$AdapterName,
        [Parameter(Mandatory)][ValidateSet('SUCCESS', 'PARTIAL', 'FAILED', 'SKIPPED')][string]$Status,
        [Parameter(Mandatory)][ValidateSet('NONE', 'NOT_REACHABLE', 'TIMEOUT', 'BLOCKED', 'NO_JOBS_FOUND', 'UNCLEAR_SOURCE', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')][string]$ErrorClass,
        [Parameter(Mandatory)][ValidateSet('NONE', 'RETRY_SOON', 'RETRY_NEXT_RUN', 'MANUAL_REVIEW')][string]$RetryRecommendation,
        [Parameter()][object[]]$RawJobs = @(),
        [Parameter()][AllowNull()][Nullable[int]]$HttpStatus,
        [Parameter()][string[]]$ArtifactPaths = @(),
        [Parameter()][datetime]$StartedAt = [datetime]::UtcNow,
        [Parameter()][datetime]$FinishedAt = [datetime]::UtcNow
    )

    if (($Status -eq 'SUCCESS') -and ($ErrorClass -ne 'NONE')) {
        throw 'Ein erfolgreicher Adapterlauf darf keine Fehlerklasse ungleich NONE haben.'
    }
    if (($Status -ne 'SUCCESS') -and ($ErrorClass -eq 'NONE')) {
        throw 'Ein nicht erfolgreicher Adapterlauf braucht eine konkrete Fehlerklasse.'
    }

    $attempt = New-JobAgentScanAttemptRecord `
        -AdapterInput $AdapterInput `
        -AdapterName $AdapterName `
        -Status $Status `
        -ErrorClass $ErrorClass `
        -RetryRecommendation $RetryRecommendation `
        -HttpStatus $HttpStatus `
        -StartedAt $StartedAt `
        -FinishedAt $FinishedAt

    [pscustomobject]@{
        adapter = $AdapterName
        company_id = $AdapterInput.company.company_id
        source_id = $AdapterInput.source.source_id
        official_source_url = $AdapterInput.source.canonical_url
        status = $Status
        error_class = $ErrorClass
        retry_recommendation = $RetryRecommendation
        raw_jobs = @($RawJobs)
        scan_attempt = $attempt
        artifact_paths = @($ArtifactPaths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}

function ConvertFrom-JobAgentHtmlJobs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter()][int]$MaxResults = 100
    )

    if (-not [Uri]::IsWellFormedUriString($BaseUrl, [UriKind]::Absolute)) {
        throw "BaseUrl ist keine absolute URL: $BaseUrl"
    }

    $baseUri = [Uri]$BaseUrl
    $matches = [regex]::Matches($Html, '<a\b(?<attrs>[^>]*)>(?<text>.*?)</a>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $jobs = New-Object System.Collections.Generic.List[object]
    foreach ($match in $matches) {
        if ($jobs.Count -ge $MaxResults) {
            break
        }
        $attrs = $match.Groups['attrs'].Value
        $hrefMatch = [regex]::Match($attrs, 'href\s*=\s*["''](?<href>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $hrefMatch.Success) {
            continue
        }
        $text = [regex]::Replace($match.Groups['text'].Value, '<[^>]+>', ' ')
        $text = [Net.WebUtility]::HtmlDecode(([regex]::Replace($text, '\s+', ' ')).Trim())
        if ([string]::IsNullOrWhiteSpace($text)) {
            continue
        }
        $href = [Net.WebUtility]::HtmlDecode($hrefMatch.Groups['href'].Value)
        $absolute = [Uri]::new($baseUri, $href).AbsoluteUri
        $idMatch = [regex]::Match($absolute, '(?i)(?:jobid|job_id|job|req|requisition)[=/_-]?(?<id>[A-Za-z0-9._-]{2,})')
        $externalId = if ($idMatch.Success) { $idMatch.Groups['id'].Value } else { $null }
        $jobs.Add((New-JobAgentRawJob -Title $text -DetailUrl $absolute -ExternalJobId $externalId -LocationLabel 'UNKNOWN' -Summary 'UNKNOWN' -ExtractionConfidence 70))
    }
    return $jobs.ToArray()
}

function Invoke-JobAgentFixtureAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter()][object[]]$FixtureJobs = @(),
        [Parameter()][ValidateSet('SUCCESS', 'PARTIAL', 'FAILED', 'SKIPPED')][string]$Status = 'SUCCESS',
        [Parameter()][ValidateSet('NONE', 'NOT_REACHABLE', 'TIMEOUT', 'BLOCKED', 'NO_JOBS_FOUND', 'UNCLEAR_SOURCE', 'PARSING_ERROR', 'TECHNICAL_LIMITATION')][string]$ErrorClass = 'NONE',
        [Parameter()][ValidateSet('NONE', 'RETRY_SOON', 'RETRY_NEXT_RUN', 'MANUAL_REVIEW')][string]$RetryRecommendation = 'NONE',
        [Parameter()][AllowNull()][int]$HttpStatus = 200
    )

    $jobs = foreach ($job in @($FixtureJobs)) {
        if ($job.PSObject.Properties.Name -contains 'title') {
            New-JobAgentRawJob `
                -Title ([string]$job.title) `
                -DetailUrl ([string]$job.detail_url) `
                -ExternalJobId ([string]$job.external_job_id) `
                -AtsJobId ([string]$job.ats_job_id) `
                -LocationLabel ([string]$job.location_label) `
                -Summary ([string]$job.summary) `
                -ExtractionConfidence ([int]$job.extraction_confidence)
        }
        else {
            $job
        }
    }
    if (($Status -eq 'SUCCESS') -and (@($jobs).Count -eq 0)) {
        $Status = 'PARTIAL'
        $ErrorClass = 'NO_JOBS_FOUND'
        $RetryRecommendation = 'RETRY_NEXT_RUN'
    }

    New-JobAgentAdapterResult `
        -AdapterInput $AdapterInput `
        -AdapterName 'fixture-adapter' `
        -Status $Status `
        -ErrorClass $ErrorClass `
        -RetryRecommendation $RetryRecommendation `
        -RawJobs @($jobs) `
        -HttpStatus $HttpStatus
}

function Invoke-JobAgentGenericHtmlAdapter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$AdapterInput,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Html,
        [Parameter()][AllowNull()][int]$HttpStatus = 200
    )

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'generic-html-adapter' `
            -Status 'FAILED' `
            -ErrorClass 'PARSING_ERROR' `
            -RetryRecommendation 'MANUAL_REVIEW' `
            -HttpStatus $HttpStatus
    }

    $jobs = @(ConvertFrom-JobAgentHtmlJobs -Html $Html -BaseUrl ([string]$AdapterInput.source.canonical_url) -MaxResults ([int]$AdapterInput.scan_context.max_results))
    if ($jobs.Count -eq 0) {
        return New-JobAgentAdapterResult `
            -AdapterInput $AdapterInput `
            -AdapterName 'generic-html-adapter' `
            -Status 'PARTIAL' `
            -ErrorClass 'NO_JOBS_FOUND' `
            -RetryRecommendation 'RETRY_NEXT_RUN' `
            -HttpStatus $HttpStatus
    }

    New-JobAgentAdapterResult `
        -AdapterInput $AdapterInput `
        -AdapterName 'generic-html-adapter' `
        -Status 'SUCCESS' `
        -ErrorClass 'NONE' `
        -RetryRecommendation 'NONE' `
        -RawJobs $jobs `
        -HttpStatus $HttpStatus
}

function Get-JobAgentAdapterContract {
    [CmdletBinding()]
    param()

    [pscustomobject]@{
        input_required = @('company', 'source', 'scan_context')
        output_required = @('adapter', 'company_id', 'source_id', 'official_source_url', 'status', 'error_class', 'retry_recommendation', 'raw_jobs', 'scan_attempt', 'artifact_paths')
        raw_job_optional = @('source_status', 'job_state')
        error_classes = $script:AdapterErrorClasses
        retry_recommendations = $script:RetryRecommendations
        no_go = @('no_login_bypass', 'no_captcha_bypass', 'no_job_board_as_primary_source', 'no_live_lookup_in_function_tests')
    }
}

Export-ModuleMember -Function @(
    'ConvertFrom-JobAgentHtmlJobs',
    'Get-JobAgentAdapterContract',
    'Invoke-JobAgentFixtureAdapter',
    'Invoke-JobAgentGenericHtmlAdapter',
    'New-JobAgentAdapterInput',
    'New-JobAgentAdapterResult',
    'New-JobAgentRawJob',
    'New-JobAgentScanContext'
)
