#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.Deduplication.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'JobAgent.Persistence.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentStatusIso {
    param([Parameter(Mandatory)][datetime]$Value)

    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-JobAgentStatusSlug {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $slug = $Value.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss')
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        return 'unknown'
    }
    return $slug
}

function Get-JobAgentStatusHash {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)

    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Value)
    $hash = [Security.Cryptography.SHA256]::HashData($bytes)
    return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Get-JobAgentRawValue {
    param(
        [Parameter(Mandatory)][object]$RawJob,
        [Parameter(Mandatory)][string]$Name,
        [Parameter()][AllowNull()][object]$Default = 'UNKNOWN'
    )

    if ($RawJob.PSObject.Properties.Name -contains $Name) {
        $value = $RawJob.$Name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            return $value
        }
    }
    return $Default
}

function New-JobAgentStatusLocation {
    param([Parameter()][AllowNull()][object]$RawLocation)

    if ($null -ne $RawLocation -and -not ($RawLocation -is [string])) {
        foreach ($property in @('label', 'city', 'region', 'country', 'target_area')) {
            if ($RawLocation.PSObject.Properties.Name -notcontains $property) {
                throw "Location fehlt Pflichtfeld $property."
            }
        }
        return $RawLocation
    }

    $label = if ([string]::IsNullOrWhiteSpace([string]$RawLocation)) { 'UNKNOWN' } else { [string]$RawLocation }
    $text = $label.ToLowerInvariant()
    $targetArea = if ($text -match 'freising') {
        'FREISING'
    }
    elseif ($text -match 'muenchen|munich|münchen') {
        'MUNICH'
    }
    elseif (($text -match 'remote') -and ($text -match 'deutschland|germany|muenchen|munich|freising|münchen')) {
        'REMOTE_WITH_TARGET_REFERENCE'
    }
    else {
        'UNKNOWN'
    }

    [pscustomobject]@{
        label = $label
        city = if ($targetArea -eq 'FREISING') { 'Freising' } elseif ($targetArea -eq 'MUNICH') { 'Muenchen' } else { 'UNKNOWN' }
        region = if (@('FREISING', 'MUNICH') -contains $targetArea) { 'Bayern' } else { 'UNKNOWN' }
        country = 'DE'
        target_area = $targetArea
    }
}

function New-JobAgentUnknownClassification {
    param([Parameter(Mandatory)][string]$ObservedAt)

    [pscustomobject]@{
        result = 'UNKNOWN'
        priority = 'UNRATED'
        score = 0
        reasons = @('Noch nicht klassifiziert.')
        rejected_reasons = @()
        evaluated_at = $ObservedAt
    }
}

function New-JobAgentStatusChangeEvent {
    param(
        [Parameter(Mandatory)][string]$JobId,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][ValidateSet('JOB_CREATED', 'JOB_UPDATED', 'JOB_CLOSED', 'JOB_REMOVED', 'JOB_INVALIDATED')][string]$EventType,
        [Parameter()][AllowNull()][string]$OldStatus,
        [Parameter(Mandatory)][ValidateSet('NEW', 'ACTIVE', 'UPDATED', 'CLOSED', 'REMOVED', 'INVALID')][string]$NewStatus,
        [Parameter(Mandatory)][string[]]$ChangedFields,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$CreatedAt
    )

    $eventSuffix = ConvertTo-JobAgentStatusSlug -Value (($EventType.Substring(4)) + '_' + ($CreatedAt -replace '[^0-9A-Za-z]', ''))
    [pscustomobject]@{
        change_event_id = 'change:' + (ConvertTo-JobAgentStatusSlug -Value (($JobId -replace '^job:', '') + '_' + $eventSuffix))
        job_id = $JobId
        scan_run_id = $ScanRunId
        event_type = $EventType
        created_at = $CreatedAt
        old_status = $OldStatus
        new_status = $NewStatus
        changed_fields = @($ChangedFields | Select-Object -Unique)
        reason = $Reason
    }
}

function New-JobAgentSnapshotFromRawJob {
    param(
        [Parameter(Mandatory)][object]$RawJob,
        [Parameter(Mandatory)][object]$Job,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][string]$CapturedAt
    )

    $summary = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'summary' -Default 'UNKNOWN')
    $hashPayload = @(
        [string]$Job.title,
        [string]$Job.official_url,
        [string]$summary,
        ($Job.location | ConvertTo-Json -Depth 10 -Compress)
    ) -join "`n"

    [pscustomobject]@{
        snapshot_id = 'snapshot:' + (ConvertTo-JobAgentStatusSlug -Value (($Job.job_id -replace '^job:', '') + '_' + ($ScanRunId -replace '^scanrun:', '')))
        job_id = $Job.job_id
        scan_run_id = $ScanRunId
        source_id = $Job.source_id
        captured_at = $CapturedAt
        content_hash = Get-JobAgentStatusHash -Value $hashPayload
        status = $Job.status
        title = $Job.title
        location = $Job.location
        official_url = $Job.official_url
        summary = $summary
    }
}

function New-JobAgentJobFromRawJob {
    param(
        [Parameter(Mandatory)][object]$RawJob,
        [Parameter(Mandatory)][object]$Decision,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$ObservedAt
    )

    $location = New-JobAgentStatusLocation -RawLocation (Get-JobAgentRawValue -RawJob $RawJob -Name 'location' -Default (Get-JobAgentRawValue -RawJob $RawJob -Name 'location_label' -Default 'UNKNOWN'))
    [pscustomobject]@{
        job_id = $Decision.job_id
        company_id = $CompanyId
        official_url = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'detail_url')
        alternative_official_urls = @()
        source_id = $SourceId
        external_job_id = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'external_job_id')
        ats_job_id = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'ats_job_id')
        title = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'title')
        location = $location
        work_model = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'work_model' -Default 'UNKNOWN')
        employment_type = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'employment_type' -Default 'UNKNOWN')
        status = 'NEW'
        first_seen = $ObservedAt
        last_seen = $ObservedAt
        changed_at = $ObservedAt
        classification = if ($RawJob.PSObject.Properties.Name -contains 'classification') { $RawJob.classification } else { New-JobAgentUnknownClassification -ObservedAt $ObservedAt }
        priority = if ($RawJob.PSObject.Properties.Name -contains 'priority') { [string]$RawJob.priority } else { 'UNRATED' }
        requirements = @()
        salary = if ($RawJob.PSObject.Properties.Name -contains 'salary') { [string]$RawJob.salary } else { 'UNKNOWN' }
        identity_basis = $Decision.identity_basis
    }
}

function Update-JobAgentExistingJobFromRawJob {
    param(
        [Parameter(Mandatory)][object]$ExistingJob,
        [Parameter(Mandatory)][object]$RawJob,
        [Parameter(Mandatory)][object]$Decision,
        [Parameter(Mandatory)][string]$ObservedAt
    )

    $job = $ExistingJob.PSObject.Copy()
    $oldStatus = [string]$job.status
    $changedFields = New-Object System.Collections.Generic.List[string]
    foreach ($field in @($Decision.changed_fields)) {
        $changedFields.Add([string]$field)
    }

    $newTitle = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'title')
    $newUrl = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'detail_url')
    $newExternalId = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'external_job_id')
    $newAtsId = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'ats_job_id')

    $job.title = $newTitle
    $job.official_url = $newUrl
    $job.external_job_id = $newExternalId
    $job.ats_job_id = $newAtsId
    $job.location = New-JobAgentStatusLocation -RawLocation (Get-JobAgentRawValue -RawJob $RawJob -Name 'location' -Default (Get-JobAgentRawValue -RawJob $RawJob -Name 'location_label' -Default $job.location))
    $job.last_seen = $ObservedAt
    $job.identity_basis = $Decision.identity_basis

    if ($Decision.decision -eq 'UPDATED') {
        $job.status = 'UPDATED'
        $job.changed_at = $ObservedAt
        if (-not $changedFields.Contains('status')) { $changedFields.Add('status') }
    }
    elseif (@('NEW', 'UPDATED') -contains $oldStatus) {
        $job.status = 'ACTIVE'
        if ($oldStatus -ne 'ACTIVE') {
            $job.changed_at = $ObservedAt
            $changedFields.Add('status')
        }
    }
    else {
        $job.status = 'ACTIVE'
        $job.changed_at = $ObservedAt
        $changedFields.Add('status')
    }

    [pscustomobject]@{
        job = $job
        old_status = $oldStatus
        changed_fields = @($changedFields.ToArray() | Select-Object -Unique)
    }
}

function Test-JobAgentRawJobValidForStatus {
    param([Parameter(Mandatory)][object]$RawJob)

    if ([string]::IsNullOrWhiteSpace([string](Get-JobAgentRawValue -RawJob $RawJob -Name 'title' -Default ''))) {
        return $false
    }
    $detailUrl = [string](Get-JobAgentRawValue -RawJob $RawJob -Name 'detail_url' -Default '')
    return [Uri]::IsWellFormedUriString($detailUrl, [UriKind]::Absolute)
}

function Invoke-JobAgentStatusMachine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][string]$ScanRunId,
        [Parameter(Mandatory)][object[]]$AdapterResults,
        [Parameter()][datetime]$ObservedAt = [datetime]::UtcNow
    )

    $observedAtText = ConvertTo-JobAgentStatusIso -Value $ObservedAt
    $seenByCompany = @{}
    $successfulCompanies = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $invalidEvents = New-Object System.Collections.Generic.List[object]

    foreach ($adapterResult in @($AdapterResults)) {
        $companyId = [string]$adapterResult.company_id
        $sourceId = [string]$adapterResult.source_id
        if (-not $seenByCompany.ContainsKey($companyId)) {
            $seenByCompany[$companyId] = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        }
        if (([string]$adapterResult.status -eq 'SUCCESS') -and ([string]$adapterResult.error_class -eq 'NONE')) {
            [void]$successfulCompanies.Add($companyId)
        }

        $Document = Record-JobAgentScanAttempt -Document $Document -ScanAttempt $adapterResult.scan_attempt
        if (-not (@('SUCCESS', 'PARTIAL') -contains [string]$adapterResult.status)) {
            continue
        }

        foreach ($rawJob in @($adapterResult.raw_jobs)) {
            if (-not (Test-JobAgentRawJobValidForStatus -RawJob $rawJob)) {
                $invalidJobId = 'job:' + (ConvertTo-JobAgentStatusSlug -Value ($companyId + '_invalid_' + $ScanRunId + '_' + ($invalidEvents.Count + 1)))
                $invalidEvents.Add((New-JobAgentStatusChangeEvent -JobId $invalidJobId -ScanRunId $ScanRunId -EventType 'JOB_INVALIDATED' -OldStatus $null -NewStatus 'INVALID' -ChangedFields @('status') -Reason 'Rohjob ohne belastbaren Titel oder absolute offizielle Detail-URL wurde verworfen.' -CreatedAt $observedAtText))
                continue
            }

            $location = New-JobAgentStatusLocation -RawLocation (Get-JobAgentRawValue -RawJob $rawJob -Name 'location' -Default (Get-JobAgentRawValue -RawJob $rawJob -Name 'location_label' -Default 'UNKNOWN'))
            $candidate = New-JobAgentJobIdentityCandidate `
                -CompanyId $companyId `
                -Title ([string](Get-JobAgentRawValue -RawJob $rawJob -Name 'title')) `
                -OfficialUrl ([string](Get-JobAgentRawValue -RawJob $rawJob -Name 'detail_url')) `
                -ExternalJobId ([string](Get-JobAgentRawValue -RawJob $rawJob -Name 'external_job_id')) `
                -AtsJobId ([string](Get-JobAgentRawValue -RawJob $rawJob -Name 'ats_job_id')) `
                -Location $location `
                -SourceId $sourceId
            $decision = Resolve-JobAgentJobDeduplication -Document $Document -Candidate $candidate

            if ($decision.is_existing -eq $true) {
                $existing = @($Document.jobs | Where-Object { [string]$_.job_id -eq [string]$decision.job_id } | Select-Object -First 1)[0]
                $updated = Update-JobAgentExistingJobFromRawJob -ExistingJob $existing -RawJob $rawJob -Decision $decision -ObservedAt $observedAtText
                $job = $updated.job
                $event = $null
                if (@($updated.changed_fields).Count -gt 0) {
                    $eventType = if ($decision.decision -eq 'UPDATED') { 'JOB_UPDATED' } else { 'JOB_UPDATED' }
                    $event = New-JobAgentStatusChangeEvent -JobId $job.job_id -ScanRunId $ScanRunId -EventType $eventType -OldStatus $updated.old_status -NewStatus $job.status -ChangedFields @($updated.changed_fields) -Reason $decision.reason -CreatedAt $observedAtText
                }
            }
            else {
                $job = New-JobAgentJobFromRawJob -RawJob $rawJob -Decision $decision -CompanyId $companyId -SourceId $sourceId -ObservedAt $observedAtText
                $event = New-JobAgentStatusChangeEvent -JobId $job.job_id -ScanRunId $ScanRunId -EventType 'JOB_CREATED' -OldStatus $null -NewStatus 'NEW' -ChangedFields @('status', 'first_seen', 'last_seen') -Reason 'Erstmals ueber offiziellen Adapterlauf erkannt.' -CreatedAt $observedAtText
            }

            [void]$seenByCompany[$companyId].Add([string]$job.job_id)
            $snapshot = New-JobAgentSnapshotFromRawJob -RawJob $rawJob -Job $job -ScanRunId $ScanRunId -CapturedAt $observedAtText
            $Document = Upsert-JobAgentJobSnapshot -Document $Document -Job $job -Snapshot $snapshot -ChangeEvent $event
        }
    }

    foreach ($invalidEvent in @($invalidEvents.ToArray())) {
        $currentEvents = New-Object System.Collections.Generic.List[object]
        $foundEvent = $false
        foreach ($existingEvent in @($Document.change_events)) {
            if ([string]$existingEvent.change_event_id -eq [string]$invalidEvent.change_event_id) {
                $currentEvents.Add($invalidEvent)
                $foundEvent = $true
            }
            else {
                $currentEvents.Add($existingEvent)
            }
        }
        if (-not $foundEvent) {
            $currentEvents.Add($invalidEvent)
        }
        $Document.change_events = @($currentEvents.ToArray())
    }
    foreach ($companyId in @($successfulCompanies)) {
        $seenList = [Collections.Generic.List[string]]::new()
        if ($seenByCompany.ContainsKey($companyId)) {
            foreach ($seenJobId in $seenByCompany[$companyId]) {
                $seenList.Add([string]$seenJobId)
            }
        }
        $Document = Mark-JobAgentMissingJobs -Document $Document -CompanyId $companyId -SeenJobIds $seenList.ToArray() -ScanRunId $ScanRunId -ChangedAt $observedAtText
    }

    Assert-JobAgentDocument -Document $Document
    return $Document
}

Export-ModuleMember -Function @(
    'Invoke-JobAgentStatusMachine',
    'New-JobAgentStatusChangeEvent',
    'New-JobAgentStatusLocation',
    'Test-JobAgentRawJobValidForStatus'
)
