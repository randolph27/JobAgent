#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Get-JobAgentRegionalProperty {
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

function ConvertTo-JobAgentRegionalHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function ConvertTo-JobAgentRegionalSlug {
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

function ConvertFrom-JobAgentRegionalHtmlText {
    [CmdletBinding()]
    param([Parameter()][AllowNull()][string]$Html)

    if ([string]::IsNullOrWhiteSpace($Html)) {
        return ''
    }
    $text = [regex]::Replace($Html, '<[^>]+>', ' ')
    $text = [Net.WebUtility]::HtmlDecode($text)
    return ([regex]::Replace($text, '\s+', ' ')).Trim()
}

function Get-JobAgentRegionalTargetArea {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Location,
        [Parameter()][AllowEmptyString()][string]$RegionReference = ''
    )

    $scopeText = if ([string]::IsNullOrWhiteSpace($Location)) { $RegionReference } else { $Location }
    $value = $scopeText.Trim().ToLowerInvariant().
        Replace('ü', 'ue').
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ß', 'ss')
    if ($value -match 'freising|flughafen|airport|weihenstephan') {
        return 'FREISING'
    }
    if ($value -match 'muenchen|munich') {
        return 'MUNICH'
    }
    if ($value -match 'garching|unterfoehring|ismaning|neubiberg|taufkirchen|pullach|gruenwald|brunnthal|kirchheim') {
        return 'MUNICH_20KM'
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        return 'TARGET_AREA_UNCERTAIN'
    }
    return 'OUT_OF_SCOPE'
}

function Assert-JobAgentRegionalSource {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Source)

    $allowedClasses = @('REGIONAL_DIRECTORY', 'PUBLIC_INSTITUTION_DIRECTORY')
    if ($allowedClasses -notcontains [string]$Source.source_class) {
        throw "Quelle $($Source.source_id) ist keine regionale Discovery-Quelle."
    }
    if ([string]$Source.import_mode -eq 'REJECT' -or [string]$Source.import_mode -ne 'FIXTURE_OR_SNAPSHOT_ONLY') {
        throw "Regionale Quelle $($Source.source_id) ist nicht fuer Snapshot-Import freigegeben."
    }
    if ([bool]$Source.review_required -ne $true -or [string]$Source.evidence_level -eq 'PRIMARY_OFFICIAL') {
        throw "Regionale Quelle $($Source.source_id) darf nur reviewpflichtige Kandidatenhinweise erzeugen."
    }
}

function Get-JobAgentRegionalSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$SourceRegistry,
        [Parameter(Mandatory)][string]$SourceId
    )

    $source = @($SourceRegistry.items | Where-Object { [string]$_.source_id -eq $SourceId } | Select-Object -First 1)
    if ($source.Count -ne 1) {
        throw "Regionale Quelle fehlt in Source Registry: $SourceId"
    }
    Assert-JobAgentRegionalSource -Source $source[0]
    return $source[0]
}

function ConvertFrom-JobAgentRegionalHtmlRows {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourcePage,
        [Parameter(Mandatory)][string]$RegionReference,
        [Parameter(Mandatory)][datetime]$ObservedAt,
        [Parameter()][ValidateSet('table', 'card')][string]$Mode = 'table'
    )

    if (-not [Uri]::IsWellFormedUriString($SourcePage, [UriKind]::Absolute)) {
        throw "SourcePage ist keine absolute URL: $SourcePage"
    }

    $tagPattern = if ($Mode -eq 'table') { 'tr' } else { 'article|div' }
    $matches = [regex]::Matches($Html, '<(?<tag>' + $tagPattern + ')\b(?<attrs>[^>]*)\bdata-jobagent-regional\b(?<attrs2>[^>]*)>(?<body>.*?)</\k<tag>>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
    $records = [System.Collections.Generic.List[object]]::new()
    $index = 0
    foreach ($match in $matches) {
        $index++
        $body = $match.Groups['body'].Value
        $allAttrs = $match.Groups['attrs'].Value + ' ' + $match.Groups['attrs2'].Value
        $getValue = {
            param([string]$Name)
            $attrMatch = [regex]::Match($allAttrs, '\bdata-jobagent-' + [regex]::Escape($Name) + '\s*=\s*["''](?<value>[^"'']+)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
            if ($attrMatch.Success) {
                return [Net.WebUtility]::HtmlDecode($attrMatch.Groups['value'].Value).Trim()
            }
            $nodeMatch = [regex]::Match($body, '<[^>]+\bdata-jobagent-' + [regex]::Escape($Name) + '\b[^>]*>(?<value>.*?)</[^>]+>', [Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [Text.RegularExpressions.RegexOptions]::Singleline)
            if ($nodeMatch.Success) {
                return ConvertFrom-JobAgentRegionalHtmlText -Html $nodeMatch.Groups['value'].Value
            }
            return ''
        }

        $name = & $getValue 'name'
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }
        $records.Add([pscustomobject]@{
                company_name = $name
                sector_hint = & $getValue 'sector'
                address_or_location_hint = & $getValue 'location'
                region_reference = $RegionReference
                source_page = $SourcePage
                source_id = $SourceId
                observed_at = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
                parser = $Mode
                record_index = $index
            })
    }
    return $records.ToArray()
}

function ConvertTo-JobAgentRegionalHint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Record,
        [Parameter(Mandatory)][object]$Source
    )

    $companyName = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('company_name', 'organization_name', 'name', 'canonical_name') -Default '')
    if ([string]::IsNullOrWhiteSpace($companyName)) {
        throw 'Regionaler Datensatz enthaelt keinen Organisationsnamen.'
    }
    $sector = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('sector_hint', 'sector', 'industry_hint', 'industry') -Default 'UNKNOWN')
    $location = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('address_or_location_hint', 'location', 'address', 'city') -Default '')
    $region = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('region_reference') -Default $location)
    $sourcePage = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('source_page', 'source_url') -Default ([string]$Source.source_url))
    $observedAt = [string](Get-JobAgentRegionalProperty -Object $Record -Names @('observed_at') -Default ([datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)))
    $targetArea = Get-JobAgentRegionalTargetArea -Location $location -RegionReference $region
    $officialness = if ([string]$Source.evidence_level -eq 'SECONDARY_OFFICIAL_DIRECTORY') { 'SECONDARY_OFFICIAL_DIRECTORY' } else { 'CURATED_DISCOVERY_HINT' }
    $manualReviewReason = switch ($targetArea) {
        'OUT_OF_SCOPE' { 'out_of_scope_location' }
        'TARGET_AREA_UNCERTAIN' { 'target_area_uncertain' }
        default { 'official_company_or_career_source_required' }
    }
    $baseScore = switch ([string]$Source.source_class) {
        'PUBLIC_INSTITUTION_DIRECTORY' { 76 }
        'REGIONAL_DIRECTORY' { 72 }
        default { 60 }
    }
    if ($targetArea -eq 'MUNICH' -or $targetArea -eq 'FREISING') {
        $baseScore += 8
    }
    elseif ($targetArea -eq 'TARGET_AREA_UNCERTAIN') {
        $baseScore -= 25
    }

    $rawEvidence = ($Record | ConvertTo-Json -Compress -Depth 20)
    [pscustomobject]@{
        hint_id = 'regional-hint:' + (ConvertTo-JobAgentRegionalSlug -Value (([string]$Source.source_id).Substring(16) + '-' + $companyName + '-' + $region))
        company_name = $companyName
        normalized_name = ConvertTo-JobAgentCompanyNameKey -Name $companyName
        region_reference = if ([string]::IsNullOrWhiteSpace($region)) { 'UNKNOWN' } else { $region }
        sector_hint = if ([string]::IsNullOrWhiteSpace($sector)) { 'UNKNOWN' } else { $sector }
        address_or_location_hint = if ([string]::IsNullOrWhiteSpace($location)) { 'UNKNOWN' } else { $location }
        source_page = $sourcePage
        source_id = [string]$Source.source_id
        source_class = [string]$Source.source_class
        observed_at = $observedAt
        officialness_level = $officialness
        manual_review_reason = $manualReviewReason
        priority_score = [Math]::Max(1, [Math]::Min(100, $baseScore))
        target_area = $targetArea
        verification_status = 'UNVERIFIED'
        candidate_status = 'REGIONAL_DISCOVERY_HINT'
        official_verification_required = $true
        raw_retention_policy = 'minimal_regional_metadata_only_no_contact_collection'
        source_record_hash = ConvertTo-JobAgentRegionalHash -Value $rawEvidence
        next_action = 'verify_official_company_website_or_career_url'
    }
}

function Import-JobAgentRegionalDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SnapshotPath,
        [Parameter(Mandatory)][object]$SourceRegistry
    )

    if (-not (Test-Path -LiteralPath $SnapshotPath -PathType Leaf)) {
        throw "Regional-Snapshot fehlt: $SnapshotPath"
    }

    $snapshot = Get-Content -LiteralPath $SnapshotPath -Raw | ConvertFrom-Json -Depth 100
    foreach ($field in @('schema_version', 'generated_at', 'sources')) {
        if ($snapshot.PSObject.Properties.Name -notcontains $field) {
            throw "Regional-Snapshot fehlt Pflichtfeld $field."
        }
    }

    $observedAt = [datetime]::Parse([string]$snapshot.generated_at, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime()
    $hintsById = [ordered]@{}
    $rejectCounts = [ordered]@{
        out_of_scope = 0
        missing_name = 0
        blocked_source = 0
    }
    $sourceCounts = [ordered]@{}

    foreach ($sourceSnapshot in @($snapshot.sources)) {
        $sourceId = [string]$sourceSnapshot.source_id
        try {
            $source = Get-JobAgentRegionalSource -SourceRegistry $SourceRegistry -SourceId $sourceId
        }
        catch {
            $rejectCounts.blocked_source++
            throw
        }

        $sourceRecords = [System.Collections.Generic.List[object]]::new()
        $format = [string](Get-JobAgentRegionalProperty -Object $sourceSnapshot -Names @('format') -Default 'json_items')
        $sourcePage = [string](Get-JobAgentRegionalProperty -Object $sourceSnapshot -Names @('source_page') -Default ([string]$source.source_url))
        $region = [string](Get-JobAgentRegionalProperty -Object $sourceSnapshot -Names @('region_reference') -Default '')
        if ($format -eq 'table_html' -or $format -eq 'card_html') {
            $mode = if ($format -eq 'table_html') { 'table' } else { 'card' }
            foreach ($record in @(ConvertFrom-JobAgentRegionalHtmlRows -Html ([string]$sourceSnapshot.html) -SourceId $sourceId -SourcePage $sourcePage -RegionReference $region -ObservedAt $observedAt -Mode $mode)) {
                $sourceRecords.Add($record)
            }
        }
        elseif ($format -eq 'json_items') {
            foreach ($record in @($sourceSnapshot.items)) {
                $record | Add-Member -NotePropertyName source_id -NotePropertyValue $sourceId -Force
                $record | Add-Member -NotePropertyName source_page -NotePropertyValue $sourcePage -Force
                $record | Add-Member -NotePropertyName region_reference -NotePropertyValue $region -Force
                $record | Add-Member -NotePropertyName observed_at -NotePropertyValue ($observedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)) -Force
                $sourceRecords.Add($record)
            }
        }
        else {
            throw "Nicht unterstuetztes Regionalformat: $format"
        }

        foreach ($record in @($sourceRecords.ToArray())) {
            try {
                $hint = ConvertTo-JobAgentRegionalHint -Record $record -Source $source
            }
            catch {
                $rejectCounts.missing_name++
                continue
            }
            if ([string]$hint.target_area -eq 'OUT_OF_SCOPE') {
                $rejectCounts.out_of_scope++
                continue
            }
            if (-not $hintsById.Contains([string]$hint.hint_id) -or [int]$hint.priority_score -gt [int]$hintsById[[string]$hint.hint_id].priority_score) {
                $hintsById[[string]$hint.hint_id] = $hint
            }
        }
    }

    $hints = @($hintsById.Values | Sort-Object priority_score, company_name -Descending)
    foreach ($hint in $hints) {
        $sourceIdValue = [string]$hint.source_id
        if (-not $sourceCounts.Contains($sourceIdValue)) {
            $sourceCounts[$sourceIdValue] = 0
        }
        $sourceCounts[$sourceIdValue]++
    }

    [pscustomobject]@{
        schema_version = 'jobagent/regional-discovery/v1'
        generated_at = $observedAt.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Regionale Verzeichnisse erzeugen ausschliesslich unverifizierte Kandidaten-Hints; Kontakt-, Branchenbuch- und Karrierequellen werden nicht uebernommen.'
        snapshot_hash = ConvertTo-JobAgentRegionalHash -Value (Get-Content -LiteralPath $SnapshotPath -Raw)
        sources_read = @($snapshot.sources).Count
        hints_total = $hints.Count
        reject_counts = [pscustomobject]$rejectCounts
        source_counts = [pscustomobject]$sourceCounts
        hints = $hints
    }
}

Export-ModuleMember -Function @(
    'Assert-JobAgentRegionalSource',
    'ConvertFrom-JobAgentRegionalHtmlRows',
    'ConvertTo-JobAgentRegionalHint',
    'Get-JobAgentRegionalSource',
    'Get-JobAgentRegionalTargetArea',
    'Import-JobAgentRegionalDirectories'
)
