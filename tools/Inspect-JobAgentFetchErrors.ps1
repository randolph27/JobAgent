#requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter()][string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [Parameter()][string]$LogRoot = 'logs/jobagent',
    [Parameter()][ValidateRange(1, 100)][int]$MaxFiles = 20,
    [Parameter()][ValidateRange(1, 100)][int]$DominancePercent = 60
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$projectRootPath = [IO.Path]::GetFullPath($ProjectRoot)
$logRootPath = if ([IO.Path]::IsPathRooted($LogRoot)) {
    [IO.Path]::GetFullPath($LogRoot)
}
else {
    [IO.Path]::GetFullPath((Join-Path $projectRootPath $LogRoot))
}

function Read-ToolJsonFile {
    param([Parameter(Mandatory)][string]$Path)

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    }
    catch {
        return $null
    }
}

function Get-ToolFetchErrorSummaryItems {
    param([Parameter(Mandatory)][object]$Document)

    if ($Document.PSObject.Properties.Name -contains 'fetch_error_summary' -and
        $null -ne $Document.fetch_error_summary -and
        $Document.fetch_error_summary.PSObject.Properties.Name -contains 'by_error_class') {
        return @($Document.fetch_error_summary.by_error_class)
    }
    return @()
}

function Resolve-ToolFetchErrorClass {
    param([Parameter()][AllowNull()][object]$Fetch)

    if ($null -eq $Fetch) {
        return ''
    }
    if ($Fetch.PSObject.Properties.Name -contains 'error_class' -and -not [string]::IsNullOrWhiteSpace([string]$Fetch.error_class)) {
        return [string]$Fetch.error_class
    }
    $messageParts = New-Object System.Collections.Generic.List[string]
    foreach ($property in @('error', 'error_detail')) {
        if ($Fetch.PSObject.Properties.Name -contains $property -and -not [string]::IsNullOrWhiteSpace([string]$Fetch.$property)) {
            $messageParts.Add([string]$Fetch.$property)
        }
    }
    $combined = ($messageParts.ToArray() -join ' | ')
    if ([string]::IsNullOrWhiteSpace($combined)) {
        return ''
    }
    if ($combined -match 'SEC_E_NO_CREDENTIALS|keine Anmeldeinformationen|no credentials') {
        return 'TLS_CREDENTIAL_UNAVAILABLE'
    }
    if ($combined -match 'certificate|Zertifikat|Authentication failed|SSL connection|TLS') {
        return 'TLS_HANDSHAKE_FAILED'
    }
    if ($combined -match 'timed out|Timeout|Zeit') {
        return 'TIMEOUT'
    }
    if ($combined -match 'Name or service not known|nodename nor servname|No such host|DNS') {
        return 'DNS_RESOLUTION_FAILED'
    }
    if ($combined -match '^HTTP\s+\d{3}|HTTP_STATUS') {
        return 'HTTP_STATUS'
    }
    return 'HTTP_REQUEST_FAILED'
}

function New-ToolFetchErrorSummaryFromResults {
    param([Parameter(Mandatory)][object]$Document)

    if (-not ($Document.PSObject.Properties.Name -contains 'results')) {
        return $null
    }

    $fetches = @($Document.results | ForEach-Object {
            $candidateId = if ($_.PSObject.Properties.Name -contains 'candidate_id') { [string]$_.candidate_id } else { '' }
            if ($_.PSObject.Properties.Name -contains 'fetches') {
                @($_.fetches | ForEach-Object {
                        [pscustomobject]@{
                            candidate_id = $candidateId
                            error_class = Resolve-ToolFetchErrorClass -Fetch $_
                            url = if ($_.PSObject.Properties.Name -contains 'url') { [string]$_.url } else { '' }
                            error_detail = if ($_.PSObject.Properties.Name -contains 'error_detail' -and -not [string]::IsNullOrWhiteSpace([string]$_.error_detail)) { [string]$_.error_detail } elseif ($_.PSObject.Properties.Name -contains 'error') { [string]$_.error } else { '' }
                            exception_types = if ($_.PSObject.Properties.Name -contains 'exception_types') { @($_.exception_types) } else { @() }
                        }
                    })
            }
        } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.error_class) })

    $byClass = @($fetches |
        Group-Object { [string]$_.error_class } |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, Name |
        ForEach-Object {
            [pscustomobject]@{
                error_class = [string]$_.Name
                fetch_count = [int]$_.Count
                candidate_count = @($_.Group | ForEach-Object { [string]$_.candidate_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique).Count
                sample_urls = @($_.Group | ForEach-Object { [string]$_.url } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique -First 5)
                sample_details = @($_.Group | ForEach-Object { [string]$_.error_detail } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique -First 3)
                exception_types = @($_.Group | ForEach-Object { @($_.exception_types) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Select-Object -Unique)
            }
        })

    [pscustomobject]@{
        failed_fetch_total = $fetches.Count
        error_class_total = $byClass.Count
        by_error_class = @($byClass)
    }
}

function Get-ToolFetchErrorRunKind {
    param([Parameter(Mandatory)][string]$FileName)

    if ($FileName -like 'JA-027-batch-*.json') {
        return 'candidate_verification'
    }
    if ($FileName -like 'company-candidate-website-discovery-*.json') {
        return 'website_discovery'
    }
    return 'unknown'
}

function Add-ToolFetchErrorAggregate {
    param(
        [Parameter(Mandatory)][hashtable]$Aggregate,
        [Parameter(Mandatory)][string]$ErrorClass,
        [Parameter()][int]$FetchCount = 0,
        [Parameter()][int]$CandidateCount = 0,
        [Parameter()][object[]]$SampleUrls = @(),
        [Parameter()][object[]]$SampleDetails = @(),
        [Parameter()][object[]]$ExceptionTypes = @()
    )

    if (-not $Aggregate.ContainsKey($ErrorClass)) {
        $Aggregate[$ErrorClass] = [ordered]@{
            error_class = $ErrorClass
            fetch_count = 0
            candidate_count = 0
            sample_urls = New-Object System.Collections.Generic.List[string]
            sample_details = New-Object System.Collections.Generic.List[string]
            exception_types = New-Object System.Collections.Generic.List[string]
        }
    }

    $entry = $Aggregate[$ErrorClass]
    $entry.fetch_count += $FetchCount
    $entry.candidate_count += $CandidateCount
    foreach ($url in @($SampleUrls)) {
        $value = ([string]$url).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value) -and -not $entry.sample_urls.Contains($value) -and $entry.sample_urls.Count -lt 5) {
            $entry.sample_urls.Add($value)
        }
    }
    foreach ($detail in @($SampleDetails)) {
        $value = ([string]$detail).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value) -and -not $entry.sample_details.Contains($value) -and $entry.sample_details.Count -lt 3) {
            $entry.sample_details.Add($value)
        }
    }
    foreach ($typeName in @($ExceptionTypes)) {
        $value = ([string]$typeName).Trim()
        if (-not [string]::IsNullOrWhiteSpace($value) -and -not $entry.exception_types.Contains($value)) {
            $entry.exception_types.Add($value)
        }
    }
}

function ConvertTo-ToolFetchErrorOutputItem {
    param([Parameter(Mandatory)][hashtable]$Entry)

    [pscustomobject]@{
        error_class = [string]$Entry.error_class
        fetch_count = [int]$Entry.fetch_count
        candidate_count = [int]$Entry.candidate_count
        sample_urls = @($Entry.sample_urls.ToArray())
        sample_details = @($Entry.sample_details.ToArray())
        exception_types = @($Entry.exception_types.ToArray())
    }
}

$patterns = @('JA-027-batch-*.json', 'company-candidate-website-discovery-*.json')
$files = @()
if (Test-Path -LiteralPath $logRootPath -PathType Container) {
    foreach ($pattern in $patterns) {
        $files += @(Get-ChildItem -LiteralPath $logRootPath -Filter $pattern -File | Sort-Object LastWriteTime -Descending | Select-Object -First $MaxFiles)
    }
}

$runs = New-Object System.Collections.Generic.List[object]
$aggregate = @{}
$failedFetchTotal = 0
$candidateTotal = 0

foreach ($file in @($files | Sort-Object LastWriteTime -Descending | Select-Object -First $MaxFiles)) {
    $document = Read-ToolJsonFile -Path $file.FullName
    if ($null -eq $document) {
        continue
    }
    $summary = if ($document.PSObject.Properties.Name -contains 'fetch_error_summary' -and $null -ne $document.fetch_error_summary) {
        $document.fetch_error_summary
    }
    else {
        New-ToolFetchErrorSummaryFromResults -Document $document
    }
    if ($null -eq $summary) {
        continue
    }

    [object[]]$summaryItems = if ($summary.PSObject.Properties.Name -contains 'by_error_class') { @($summary.by_error_class) } else { @() }
    if (@($summaryItems).Count -eq 0) {
        continue
    }

    $runFailedFetchTotal = if ($summary.PSObject.Properties.Name -contains 'failed_fetch_total') { [int]$summary.failed_fetch_total } else { 0 }
    $runCandidateTotal = 0
    foreach ($item in $summaryItems) {
        $errorClass = ([string]$item.error_class).Trim()
        if ([string]::IsNullOrWhiteSpace($errorClass)) {
            continue
        }
        $fetchCount = if ($item.PSObject.Properties.Name -contains 'fetch_count') { [int]$item.fetch_count } else { 0 }
        $itemCandidateCount = if ($item.PSObject.Properties.Name -contains 'candidate_count') { [int]$item.candidate_count } else { 0 }
        $runCandidateTotal += $itemCandidateCount
        Add-ToolFetchErrorAggregate `
            -Aggregate $aggregate `
            -ErrorClass $errorClass `
            -FetchCount $fetchCount `
            -CandidateCount $itemCandidateCount `
            -SampleUrls @(if ($item.PSObject.Properties.Name -contains 'sample_urls') { @($item.sample_urls) } else { @() }) `
            -SampleDetails @(if ($item.PSObject.Properties.Name -contains 'sample_details') { @($item.sample_details) } else { @() }) `
            -ExceptionTypes @(if ($item.PSObject.Properties.Name -contains 'exception_types') { @($item.exception_types) } else { @() })
    }

    $failedFetchTotal += $runFailedFetchTotal
    $candidateTotal += $runCandidateTotal
    $runs.Add([pscustomobject]@{
            path = $file.FullName
            run_id = if ($document.PSObject.Properties.Name -contains 'run_id') { [string]$document.run_id } else { [IO.Path]::GetFileNameWithoutExtension($file.Name) }
            kind = Get-ToolFetchErrorRunKind -FileName $file.Name
            failed_fetch_total = $runFailedFetchTotal
            summary_source = if ($document.PSObject.Properties.Name -contains 'fetch_error_summary' -and $null -ne $document.fetch_error_summary) { 'manifest' } else { 'results_fallback' }
            error_class_total = if ($summary.PSObject.Properties.Name -contains 'error_class_total') { [int]$summary.error_class_total } else { @($summaryItems).Count }
            top_error_class = if (@($summaryItems).Count -gt 0) { [string](@($summaryItems | Sort-Object @{ Expression = { [int]$_.fetch_count }; Descending = $true }, error_class)[0].error_class) } else { $null }
        })
}

[object[]]$byErrorClass = @($aggregate.Values |
    ForEach-Object { ConvertTo-ToolFetchErrorOutputItem -Entry $_ } |
    Sort-Object @{ Expression = 'fetch_count'; Descending = $true }, error_class)

$dominant = if (@($byErrorClass).Count -gt 0) { @($byErrorClass)[0] } else { $null }
$dominantPercentValue = if ($null -ne $dominant -and $failedFetchTotal -gt 0) {
    [math]::Round((100.0 * [double]$dominant.fetch_count / [double]$failedFetchTotal), 2)
}
else {
    $null
}

$status = 'no_fetch_error_summary'
$nextAction = 'Neue JA-027-Batch- oder Website-Discovery-Logs mit fetch_error_summary erzeugen.'
if ($failedFetchTotal -eq 0 -and $runs.Count -gt 0) {
    $status = 'no_failed_fetches'
    $nextAction = 'Naechsten faelligen JA-027-Benchmark- oder Retrylauf ausfuehren.'
}
elseif ($null -ne $dominant -and [double]$dominantPercentValue -ge [double]$DominancePercent -and @('TLS_CREDENTIAL_UNAVAILABLE', 'TLS_HANDSHAKE_FAILED') -contains [string]$dominant.error_class) {
    $status = 'environment_tls_check_required'
    $nextAction = 'TLS-Schicht ausserhalb der aktuellen Sandbox/Schannel-Umgebung gegen die Beispiel-URLs pruefen; erst danach dieselben Retrykandidaten erneut laufen lassen.'
}
elseif ($failedFetchTotal -gt 0) {
    $status = 'fetch_errors_require_triage'
    $nextAction = 'Dominante Fehlerklasse, Beispiel-URLs und Exception-Typen pruefen; danach Retry-, Rate-Limit- oder Adaptermassnahme festlegen.'
}

[pscustomobject]@{
    schema_version = 'jobagent/fetch-error-inspection/v1'
    generated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    log_root = $logRootPath
    inspected_file_count = $runs.Count
    failed_fetch_total = $failedFetchTotal
    candidate_count = $candidateTotal
    dominant_error_class = if ($null -ne $dominant) { [string]$dominant.error_class } else { $null }
    dominant_error_percent = $dominantPercentValue
    status = $status
    next_action = $nextAction
    by_error_class = @($byErrorClass)
    runs = @($runs.ToArray())
} | ConvertTo-Json -Depth 30
