#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Get-JobAgentJobBoardProperty {
    param(
        [Parameter()][AllowNull()][object]$Object,
        [Parameter(Mandatory)][string[]]$Names,
        [Parameter()][AllowNull()][object]$Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -contains $name) {
            return $Object.$name
        }
    }
    return $Default
}

function ConvertTo-JobAgentJobBoardHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function ConvertTo-JobAgentJobBoardSlug {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $normalized = $Value.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    $slug = [regex]::Replace($normalized, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Slug-Wert darf nicht leer sein.'
    }
    return $slug
}

function ConvertFrom-JobAgentJobBoardHtmlText {
    [CmdletBinding()]
    param([Parameter()][AllowNull()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ''
    }
    $text = [regex]::Replace($Html, '<[^>]+>', ' ')
    $text = [Net.WebUtility]::HtmlDecode($text)
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Get-JobAgentJobBoardTargetArea {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Location)

    $value = $Location.Trim().ToLowerInvariant().
        Replace('ü', 'ue').
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ß', 'ss')
    if ($value -match 'freising|airport|flughafen') {
        return 'FREISING'
    }
    if ($value -match 'garching|unterfoehring|ismaning|neubiberg|taufkirchen|pullach|gruenwald|brunnthal|kirchheim') {
        return 'MUNICH_20KM'
    }
    if ($value -match 'muenchen|munich') {
        return 'MUNICH'
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'TARGET_UNCERTAIN'
    }
    return 'OUT_OF_SCOPE'
}

function Test-JobAgentJobBoardStaffingEmployer {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$EmployerName)

    $name = $EmployerName.ToLowerInvariant()
    return $name -match 'personaldienst|zeitarbeit|randstad|adecco|manpower|hays|robert half|tempton|akko|experis|personalberatung|recruiting'
}

function Assert-JobAgentJobBoardSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Source,
        [Parameter()][switch]$AllowLive
    )

    if ([string]$Source.source_class -ne 'JOB_BOARD_DISCOVERY') {
        throw "Quelle $($Source.source_id) ist keine Jobboersen-Discovery-Quelle."
    }
    if ([string]$Source.evidence_level -ne 'DISCOVERY_HINT' -or [bool]$Source.review_required -ne $true) {
        throw "Jobboerse $($Source.source_id) darf nur reviewpflichtige Discovery-Hints erzeugen."
    }
    if ([string]$Source.import_mode -eq 'REJECT') {
        throw "Jobboerse $($Source.source_id) ist blockiert."
    }
    if (-not $AllowLive -and [string]$Source.import_mode -ne 'FIXTURE_OR_SNAPSHOT_ONLY') {
        throw "Live-Abruf fuer $($Source.source_id) ist nicht freigegeben."
    }
}

function Get-JobAgentJobBoardSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SourceRegistry,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter()][switch]$AllowLive
    )

    $source = @($SourceRegistry.items | Where-Object { [string]$_.source_id -eq $SourceId } | Select-Object -First 1)
    if ($source.Count -ne 1) {
        throw "Jobboersenquelle fehlt in Source Registry: $SourceId"
    }
    Assert-JobAgentJobBoardSource -Source $source[0] -AllowLive:$AllowLive
    return $source[0]
}

function ConvertFrom-JobAgentJobBoardSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$Platform,
        [Parameter(Mandatory)][object]$SearchParameters,
        [Parameter(Mandatory)][datetime]$FetchedAt,
        [Parameter()][ValidateRange(1, 100)][int]$PageNumber = 1,
        [Parameter()][ValidateRange(1, 1000)][int]$MaxResults = 100
    )

    if (-not [Uri]::IsWellFormedUriString($BaseUrl, [UriKind]::Absolute)) {
        throw "BaseUrl ist keine absolute URL: $BaseUrl"
    }

    $baseUri = [Uri]$BaseUrl
    $cardMatches = [regex]::Matches($Html, '<(?<tag>article|div)\b(?<attrs>[^>]*)\bdata-jobagent-job\b(?<attrs2>[^>]*)>(?<body>.*?)</\k<tag>>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $records = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($match in $cardMatches) {
        if ($records.Count -ge $MaxResults) {
            break
        }
        $index++
        $body = $match.Groups['body'].Value
        $allAttrs = $match.Groups['attrs'].Value + ' ' + $match.Groups['attrs2'].Value
        $getAttr = {
            param([string]$Name)
            $attrMatch = [regex]::Match($allAttrs, '\b(?:data-jobagent-)?' + [regex]::Escape($Name) + '\s*=\s*["''](?<value>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($attrMatch.Success) {
                return [Net.WebUtility]::HtmlDecode($attrMatch.Groups['value'].Value).Trim()
            }
            $nodeAttrMatch = [regex]::Match($body, '<[^>]+\bdata-jobagent-' + [regex]::Escape($Name) + '\s*=\s*["''](?<value>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
            if ($nodeAttrMatch.Success) {
                return [Net.WebUtility]::HtmlDecode($nodeAttrMatch.Groups['value'].Value).Trim()
            }
            $nodeMatch = [regex]::Match($body, '<[^>]+\bdata-jobagent-' + [regex]::Escape($Name) + '\b[^>]*>(?<value>.*?)</[^>]+>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
            if ($nodeMatch.Success) {
                return ConvertFrom-JobAgentJobBoardHtmlText -Html $nodeMatch.Groups['value'].Value
            }
            return ''
        }

        $employer = & $getAttr 'employer'
        $title = & $getAttr 'title'
        $location = & $getAttr 'location'
        $href = & $getAttr 'url'
        if ([string]::IsNullOrWhiteSpace($href)) {
            $hrefMatch = [regex]::Match($body, '<a\b(?<attrs>[^>]*)href\s*=\s*["''](?<href>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
            if ($hrefMatch.Success) {
                $href = [Net.WebUtility]::HtmlDecode($hrefMatch.Groups['href'].Value)
            }
        }
        if ([string]::IsNullOrWhiteSpace($employer) -or [string]::IsNullOrWhiteSpace($title) -or [string]::IsNullOrWhiteSpace($href)) {
            continue
        }

        $postingUrl = [Uri]::new($baseUri, $href).AbsoluteUri
        $minimalEvidence = ('{0}|{1}|{2}|{3}' -f $employer, $title, $location, $postingUrl)
        $records.Add([pscustomobject]@{
                employer_name = $employer
                normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $employer
                job_title = $title
                job_location = if ([string]::IsNullOrWhiteSpace($location)) { 'UNKNOWN' } else { $location }
                posting_url = $postingUrl
                platform = $Platform
                source_id = $SourceId
                fetched_at = $FetchedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
                search_parameters = $SearchParameters
                page_number = $PageNumber
                source_record_hash = ConvertTo-JobAgentJobBoardHash -Value $minimalEvidence
                evidence_snippet_hash = ConvertTo-JobAgentJobBoardHash -Value ($employer + '|' + $title)
                confidence_score = if (Test-JobAgentJobBoardStaffingEmployer -EmployerName $employer) { 45 } else { 70 }
                raw_retention_policy = 'minimal_metadata_only_no_full_posting_content'
                target_area = Get-JobAgentJobBoardTargetArea -Location $(if ([string]::IsNullOrWhiteSpace($location)) { [string]$SearchParameters.location } else { $location })
                is_staffing_agency = Test-JobAgentJobBoardStaffingEmployer -EmployerName $employer
                official_verification_required = $true
                candidate_status = 'DISCOVERY_HINT'
                next_action = 'verify_official_company_website_or_career_url'
                record_index = $index
            })
    }
    return $records.ToArray()
}

function ConvertTo-JobAgentJobBoardHint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Record,
        [Parameter()][AllowNull()][object]$KnownCompany = $null
    )

    $searchKeyword = [string](Get-JobAgentJobBoardProperty -Object $Record.search_parameters -Names @('keyword', 'query') -Default 'UNKNOWN')
    $searchLocation = [string](Get-JobAgentJobBoardProperty -Object $Record.search_parameters -Names @('location') -Default ([string]$Record.job_location))
    [pscustomobject]@{
        hint_id = 'jobboard-hint:' + (ConvertTo-JobAgentJobBoardSlug -Value ((([string]$Record.source_id).Substring(16)) + '-' + [string]$Record.normalized_name + '-' + $searchKeyword + '-' + $searchLocation))
        employer_name = [string]$Record.employer_name
        normalized_name = [string]$Record.normalized_name
        job_title = [string]$Record.job_title
        job_location = [string]$Record.job_location
        location = [string]$Record.job_location
        target_area = [string]$Record.target_area
        industry_or_keyword = $searchKeyword
        source_id = [string]$Record.source_id
        observed_url = [string]$Record.posting_url
        posting_url = [string]$Record.posting_url
        platform = [string]$Record.platform
        observed_at = [string]$Record.fetched_at
        search_parameters = $Record.search_parameters
        page_number = [int]$Record.page_number
        source_record_hash = [string]$Record.source_record_hash
        evidence_snippet_hash = [string]$Record.evidence_snippet_hash
        confidence_score = [int]$Record.confidence_score
        raw_retention_policy = [string]$Record.raw_retention_policy
        verification_status = 'UNVERIFIED'
        candidate_status = 'DISCOVERY_HINT'
        job_board_discovery_status = 'JOB_BOARD_DISCOVERY'
        official_verification_required = $true
        is_staffing_agency = [bool]$Record.is_staffing_agency
        known_company_id = if ($null -eq $KnownCompany) { $null } else { [string]$KnownCompany.company_id }
        known_company_domain = if ($null -eq $KnownCompany) { $null } else { [string]$KnownCompany.canonical_domain }
        next_action = 'verify_official_company_website_or_career_url'
    }
}

function Import-JobAgentJobBoardEmployers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SnapshotPath,
        [Parameter(Mandatory)][object]$SourceRegistry,
        [Parameter()][AllowEmptyCollection()][object[]]$KnownCompanies = @(),
        [Parameter()][switch]$AllowLive
    )

    if (-not (Test-Path -LiteralPath $SnapshotPath -PathType Leaf)) {
        throw "Jobboersen-Snapshot fehlt: $SnapshotPath"
    }

    $snapshot = Get-Content -LiteralPath $SnapshotPath -Raw | ConvertFrom-Json -Depth 100
    foreach ($field in @('source_id', 'platform', 'base_url', 'fetched_at', 'search_parameters', 'pages')) {
        if ($snapshot.PSObject.Properties.Name -notcontains $field) {
            throw "Jobboersen-Snapshot fehlt Pflichtfeld $field."
        }
    }
    $source = Get-JobAgentJobBoardSource -SourceRegistry $SourceRegistry -SourceId ([string]$snapshot.source_id) -AllowLive:$AllowLive
    $fetchedAt = [datetime]::Parse([string]$snapshot.fetched_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $records = [System.Collections.Generic.List[object]]::new()
    $pageLimit = [int](Get-JobAgentJobBoardProperty -Object $snapshot.search_parameters -Names @('page_limit') -Default @($snapshot.pages).Count)
    $pageNumber = 0
    foreach ($page in @($snapshot.pages | Select-Object -First $pageLimit)) {
        $pageNumber++
        $html = [string](Get-JobAgentJobBoardProperty -Object $page -Names @('html') -Default '')
        foreach ($record in @(ConvertFrom-JobAgentJobBoardSnapshot -Html $html -BaseUrl ([string]$snapshot.base_url) -SourceId ([string]$snapshot.source_id) -Platform ([string]$snapshot.platform) -SearchParameters $snapshot.search_parameters -FetchedAt $fetchedAt -PageNumber $pageNumber)) {
            if ([string]$record.target_area -ne 'OUT_OF_SCOPE') {
                $records.Add($record)
            }
        }
    }

    $hintsById = [ordered]@{}
    foreach ($record in @($records.ToArray())) {
        $known = Find-JobAgentKnownCompanyForHint -Companies $KnownCompanies -EmployerName ([string]$record.employer_name)
        $hint = ConvertTo-JobAgentJobBoardHint -Record $record -KnownCompany $known
        if (-not $hintsById.Contains([string]$hint.hint_id)) {
            $hintsById[[string]$hint.hint_id] = $hint
        }
    }
    $hints = @($hintsById.Values | Sort-Object employer_name, source_id)
    $staffing = @($hints | Where-Object { [bool]$_.is_staffing_agency }).Count

    [pscustomobject]@{
        schema_version = 'jobagent/jobboard-discovery/v1'
        generated_at = ([datetime]::UtcNow).ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Jobboersen erzeugen ausschliesslich volatile Arbeitgeber-Hints; offizielle Firmen- oder Karriereverifikation bleibt Pflicht.'
        source_id = [string]$source.source_id
        platform = [string]$snapshot.platform
        fetched_at = $fetchedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        search_parameters = $snapshot.search_parameters
        pages_read = [Math]::Min(@($snapshot.pages).Count, $pageLimit)
        records_read = $records.Count
        hints_total = $hints.Count
        staffing_agency_hints = $staffing
        official_verification_required = $true
        snapshot_hash = ConvertTo-JobAgentJobBoardHash -Value (Get-Content -LiteralPath $SnapshotPath -Raw)
        hints = $hints
    }
}

Export-ModuleMember -Function @(
    'Assert-JobAgentJobBoardSource',
    'ConvertFrom-JobAgentJobBoardSnapshot',
    'ConvertTo-JobAgentJobBoardHint',
    'Get-JobAgentJobBoardSource',
    'Get-JobAgentJobBoardTargetArea',
    'Import-JobAgentJobBoardEmployers',
    'Test-JobAgentJobBoardStaffingEmployer'
)
