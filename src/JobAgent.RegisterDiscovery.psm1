#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking

function Get-JobAgentRegisterDiscoveryProperty {
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

function ConvertTo-JobAgentRegisterHash {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function ConvertTo-JobAgentRegisterAsciiSlug {
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

function Normalize-JobAgentRegisterCity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$City)

    $value = $City.Trim().ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss')
    $value = [regex]::Replace($value, '\s+', ' ')
    switch -Regex ($value) {
        '^(muenchen|munich)$' { return 'Muenchen' }
        '^freising$' { return 'Freising' }
        '^garching( b\. muenchen| bei muenchen)?$' { return 'Garching' }
        '^unterfoehring$' { return 'Unterfoehring' }
        '^ismaning$' { return 'Ismaning' }
        '^neubiberg$' { return 'Neubiberg' }
        '^taufkirchen$' { return 'Taufkirchen' }
        '^pullach( im isartal)?$' { return 'Pullach' }
        '^gruenwald$' { return 'Gruenwald' }
        default { return $City.Trim() }
    }
}

function ConvertTo-JobAgentRegisterCoordinate {
    [CmdletBinding()]
    param([Parameter()][AllowNull()][object]$Value)

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    $numberText = ([string]$Value).Trim().Replace(',', '.')
    $coordinate = 0.0
    if (-not [double]::TryParse($numberText, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$coordinate)) {
        return $null
    }
    return $coordinate
}

function Get-JobAgentRegisterDistanceKm {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][double]$FromLatitude,
        [Parameter(Mandatory)][double]$FromLongitude,
        [Parameter(Mandatory)][double]$ToLatitude,
        [Parameter(Mandatory)][double]$ToLongitude
    )

    $earthRadiusKm = 6371.0088
    $degreeToRadian = [Math]::PI / 180.0
    $fromLat = $FromLatitude * $degreeToRadian
    $toLat = $ToLatitude * $degreeToRadian
    $deltaLat = ($ToLatitude - $FromLatitude) * $degreeToRadian
    $deltaLon = ($ToLongitude - $FromLongitude) * $degreeToRadian
    $a = [Math]::Sin($deltaLat / 2.0) * [Math]::Sin($deltaLat / 2.0) +
        [Math]::Cos($fromLat) * [Math]::Cos($toLat) *
        [Math]::Sin($deltaLon / 2.0) * [Math]::Sin($deltaLon / 2.0)
    $c = 2.0 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1.0 - $a))
    return $earthRadiusKm * $c
}

function Get-JobAgentRegisterTargetAreaMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$City,
        [Parameter()][AllowNull()][object]$Latitude = $null,
        [Parameter()][AllowNull()][object]$Longitude = $null
    )

    $normalized = Normalize-JobAgentRegisterCity -City $City
    switch ($normalized) {
        'Muenchen' { return 'MUNICH' }
        'Freising' { return 'FREISING' }
        { @('Garching', 'Unterfoehring', 'Ismaning', 'Neubiberg', 'Taufkirchen', 'Pullach', 'Gruenwald') -contains $_ } { return 'MUNICH_20KM' }
        default {
            $lat = ConvertTo-JobAgentRegisterCoordinate -Value $Latitude
            $lon = ConvertTo-JobAgentRegisterCoordinate -Value $Longitude
            if ($null -ne $lat -and $null -ne $lon) {
                $distanceToMunich = Get-JobAgentRegisterDistanceKm -FromLatitude $lat -FromLongitude $lon -ToLatitude 48.137154 -ToLongitude 11.576124
                if ($distanceToMunich -le 20.0) {
                    return 'MUNICH_20KM'
                }
                $distanceToFreising = Get-JobAgentRegisterDistanceKm -FromLatitude $lat -FromLongitude $lon -ToLatitude 48.40288 -ToLongitude 11.74128
                if ($distanceToFreising -le 5.0) {
                    return 'FREISING'
                }
            }
            if ([string]::IsNullOrWhiteSpace($normalized)) {
                return 'TARGET_AREA_UNCERTAIN'
            }
            return 'OUT_OF_SCOPE'
        }
    }
}

function Get-JobAgentRegisterSourceFreshness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][datetime]$SnapshotDate,
        [Parameter(Mandatory)][datetime]$ObservedAt,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 730
    )

    if ($SnapshotDate.ToUniversalTime() -gt $ObservedAt.ToUniversalTime().AddDays(1)) {
        return 'FUTURE_SNAPSHOT_REJECTED'
    }
    if ($SnapshotDate.ToUniversalTime() -lt $ObservedAt.ToUniversalTime().AddDays(-$StaleAfterDays)) {
        return 'STALE'
    }
    return 'CURRENT'
}

function Assert-JobAgentRegisterSourceRegistry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Registry,
        [Parameter()][string]$RequiredSourceId = 'source-registry:offeneregister_dump'
    )

    Assert-JobAgentDiscoverySourceRegistry -Registry $Registry
    $source = @($Registry.items | Where-Object { [string]$_.source_id -eq $RequiredSourceId } | Select-Object -First 1)
    if ($source.Count -ne 1) {
        throw "Registerquelle fehlt in Source Registry: $RequiredSourceId"
    }
    if ([string]$source[0].source_class -ne 'OPEN_REGISTER_DUMP' -or [string]$source[0].import_mode -ne 'BULK_SNAPSHOT') {
        throw "Registerquelle $RequiredSourceId ist nicht fuer Bulk-Snapshot-Import freigegeben."
    }
    if ([bool]$source[0].review_required -ne $true -or [string]$source[0].evidence_level -ne 'DISCOVERY_HINT') {
        throw "Registerquelle $RequiredSourceId muss unverifizierter Review-Hinweis bleiben."
    }
    return $source[0]
}

function ConvertTo-JobAgentRegisterRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Record,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SnapshotId,
        [Parameter(Mandatory)][datetime]$SnapshotDate,
        [Parameter(Mandatory)][datetime]$ObservedAt,
        [Parameter(Mandatory)][int]$LineNumber,
        [Parameter(Mandatory)][string]$RawLine,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 730
    )

    $registerName = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('register_name', 'name', 'company_name', 'legal_name') -Default '')
    $registerCity = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('register_city', 'city', 'registered_city') -Default '')
    $registerCourt = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('register_court', 'court') -Default 'UNKNOWN')
    $registerNumber = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('register_number', 'number', 'registration_number') -Default 'UNKNOWN')
    $legalForm = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('legal_form', 'rechtsform') -Default 'UNKNOWN')
    $status = [string](Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('status', 'register_status') -Default 'UNKNOWN')
    $latitude = Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('latitude', 'lat', 'geo_lat', 'y') -Default $null
    $longitude = Get-JobAgentRegisterDiscoveryProperty -Object $Record -Names @('longitude', 'lon', 'lng', 'geo_lon', 'x') -Default $null

    if ([string]::IsNullOrWhiteSpace($registerName)) {
        throw "Registerdatensatz in Zeile $LineNumber enthaelt keinen Namen."
    }

    $targetArea = Get-JobAgentRegisterTargetAreaMatch -City $registerCity -Latitude $latitude -Longitude $longitude
    $sourceFreshness = Get-JobAgentRegisterSourceFreshness -SnapshotDate $SnapshotDate -ObservedAt $ObservedAt -StaleAfterDays $StaleAfterDays
    $nameKey = ConvertTo-JobAgentCompanyNameKey -Name $registerName
    $registerKey = if ([string]::IsNullOrWhiteSpace($registerCourt) -or [string]::IsNullOrWhiteSpace($registerNumber) -or $registerNumber -eq 'UNKNOWN') {
        $null
    }
    else {
        'register:' + (ConvertTo-JobAgentRegisterAsciiSlug -Value ($registerCourt + '-' + $registerNumber))
    }
    $reviewStatus = if ($sourceFreshness -eq 'FUTURE_SNAPSHOT_REJECTED') {
        'REJECTED_SOURCE_DATE'
    }
    elseif ($targetArea -eq 'OUT_OF_SCOPE') {
        'OUT_OF_SCOPE'
    }
    elseif ($status -match 'gelöscht|geloescht|deleted|liquidation') {
        'MANUAL_REVIEW_REQUIRED'
    }
    else {
        'OFFICIAL_VERIFICATION_REQUIRED'
    }
    $confidenceScore = switch ($targetArea) {
        'MUNICH' { 88 }
        'FREISING' { 86 }
        'MUNICH_20KM' { 74 }
        'TARGET_AREA_UNCERTAIN' { 45 }
        default { 10 }
    }
    if ($sourceFreshness -eq 'STALE') {
        $confidenceScore = [Math]::Max(1, $confidenceScore - 15)
    }

    $dedupeKeys = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($nameKey)) {
        $dedupeKeys.Add('name:' + $nameKey)
    }
    if (-not [string]::IsNullOrWhiteSpace($registerKey)) {
        $dedupeKeys.Add($registerKey)
    }

    [pscustomobject]@{
        hint_id = 'register-hint:' + (ConvertTo-JobAgentRegisterAsciiSlug -Value ($SnapshotId + '-' + $registerName + '-' + $registerCity + '-' + $LineNumber))
        register_name = $registerName
        normalized_name = $nameKey
        register_city = Normalize-JobAgentRegisterCity -City $registerCity
        register_court = if ([string]::IsNullOrWhiteSpace($registerCourt)) { 'UNKNOWN' } else { $registerCourt }
        register_number = if ([string]::IsNullOrWhiteSpace($registerNumber)) { 'UNKNOWN' } else { $registerNumber }
        legal_form = if ([string]::IsNullOrWhiteSpace($legalForm)) { 'UNKNOWN' } else { $legalForm }
        source_id = $SourceId
        source_snapshot = [pscustomobject]@{
            snapshot_id = $SnapshotId
            snapshot_date = $SnapshotDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            line_number = $LineNumber
            record_hash = ConvertTo-JobAgentRegisterHash -Value $RawLine
        }
        source_freshness = $sourceFreshness
        target_area_match = $targetArea
        confidence_score = $confidenceScore
        review_status = $reviewStatus
        official_verification_required = $true
        dedupe_keys = @($dedupeKeys.ToArray() | Sort-Object -Unique)
        candidate_status = 'REGISTER_DISCOVERY_HINT'
        next_action = 'verify_official_company_website_or_career_url'
    }
}

function Read-JobAgentRegisterRecords {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -eq '.csv') {
        return @(Import-Csv -LiteralPath $Path)
    }
    if ($extension -eq '.json') {
        $json = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -Depth 100
        if ($json.PSObject.Properties.Name -contains 'items') {
            return @($json.items)
        }
        return @($json)
    }
    if ($extension -eq '.jsonl') {
        $items = [System.Collections.Generic.List[object]]::new()
        foreach ($line in Get-Content -LiteralPath $Path -ReadCount 1) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            $items.Add(($line | ConvertFrom-Json -Depth 20))
        }
        return $items.ToArray()
    }
    throw "Nicht unterstuetztes Registerformat: $extension"
}

function Import-JobAgentRegisterCandidates {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$InputPath,
        [Parameter(Mandatory)][object]$SourceRegistry,
        [Parameter()][string]$SourceId = 'source-registry:offeneregister_dump',
        [Parameter()][string]$SnapshotId = ([IO.Path]::GetFileNameWithoutExtension($InputPath)),
        [Parameter(Mandatory)][datetime]$SnapshotDate,
        [Parameter()][datetime]$ObservedAt = [datetime]::UtcNow,
        [Parameter()][ValidateRange(1, 3650)][int]$StaleAfterDays = 730
    )

    if (-not (Test-Path -LiteralPath $InputPath -PathType Leaf)) {
        throw "Registereingabe fehlt: $InputPath"
    }
    Assert-JobAgentRegisterSourceRegistry -Registry $SourceRegistry -RequiredSourceId $SourceId | Out-Null

    $records = @(Read-JobAgentRegisterRecords -Path $InputPath)
    $hintsByKey = [ordered]@{}
    $rejectCounts = [ordered]@{
        out_of_scope = 0
        missing_name = 0
        future_snapshot = 0
    }
    $lineNumber = 0
    foreach ($record in $records) {
        $lineNumber++
        $rawLine = ($record | ConvertTo-Json -Compress -Depth 20)
        try {
            $hint = ConvertTo-JobAgentRegisterRecord -Record $record -SourceId $SourceId -SnapshotId $SnapshotId -SnapshotDate $SnapshotDate -ObservedAt $ObservedAt -LineNumber $lineNumber -RawLine $rawLine -StaleAfterDays $StaleAfterDays
        }
        catch {
            $rejectCounts.missing_name++
            continue
        }
        if ([string]$hint.review_status -eq 'REJECTED_SOURCE_DATE') {
            $rejectCounts.future_snapshot++
            continue
        }
        if ([string]$hint.target_area_match -eq 'OUT_OF_SCOPE') {
            $rejectCounts.out_of_scope++
            continue
        }
        $key = (@($hint.dedupe_keys) -join '|')
        if (-not $hintsByKey.Contains($key)) {
            $hintsByKey[$key] = $hint
            continue
        }
        if ([int]$hint.confidence_score -gt [int]$hintsByKey[$key].confidence_score) {
            $hintsByKey[$key] = $hint
        }
    }

    $hints = @($hintsByKey.Values | Sort-Object register_name, register_city)
    $targetAreaCounts = [ordered]@{}
    foreach ($hint in $hints) {
        $area = [string]$hint.target_area_match
        if (-not $targetAreaCounts.Contains($area)) {
            $targetAreaCounts[$area] = 0
        }
        $targetAreaCounts[$area]++
    }

    [pscustomobject]@{
        schema_version = 'jobagent/register-discovery/v1'
        generated_at = $ObservedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        contract = 'Registerdaten erzeugen ausschliesslich unverifizierte Kandidaten-Hints; sie sind kein Produktivfirmen- oder Karrierequellenbeleg.'
        source_id = $SourceId
        source_snapshot = [pscustomobject]@{
            snapshot_id = $SnapshotId
            snapshot_date = $SnapshotDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
            input_hash = ConvertTo-JobAgentRegisterHash -Value (Get-Content -LiteralPath $InputPath -Raw)
        }
        records_read = $records.Count
        hints_total = $hints.Count
        reject_counts = [pscustomobject]$rejectCounts
        target_area_counts = [pscustomobject]$targetAreaCounts
        hints = $hints
    }
}

Export-ModuleMember -Function @(
    'Assert-JobAgentRegisterSourceRegistry',
    'ConvertTo-JobAgentRegisterRecord',
    'Get-JobAgentRegisterSourceFreshness',
    'Get-JobAgentRegisterTargetAreaMatch',
    'Import-JobAgentRegisterCandidates',
    'Normalize-JobAgentRegisterCity',
    'Read-JobAgentRegisterRecords'
)
