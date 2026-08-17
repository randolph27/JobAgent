#requires -Version 7.4

Set-StrictMode -Version 3.0

Import-Module (Join-Path $PSScriptRoot 'JobAgent.SourceVerification.psm1') -Force -DisableNameChecking

function ConvertTo-JobAgentDedupText {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $text = [string]$Value
    if ($text -eq 'UNKNOWN') {
        return ''
    }

    $normalized = $text.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss').
        Replace('&', ' and ').
        Replace('+', ' plus ')
    return ([regex]::Replace($normalized, '\s+', ' ').Trim())
}

function ConvertTo-JobAgentDedupSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $text = ConvertTo-JobAgentDedupText -Value $Value
    $slug = [regex]::Replace($text, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Dedup-Slug darf nicht leer sein.'
    }
    return $slug
}

function Test-JobAgentKnownValue {
    param(
        [Parameter()][AllowNull()][object]$Value
    )

    return -not [string]::IsNullOrWhiteSpace((ConvertTo-JobAgentDedupText -Value $Value))
}

function Get-JobAgentLocationFingerprint {
    param(
        [Parameter()][AllowNull()][object]$Location
    )

    if ($null -eq $Location) {
        return 'unknown_location'
    }
    if ($Location -is [string]) {
        $slug = ConvertTo-JobAgentDedupSlug -Value $Location
        return $slug
    }

    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($property in @('target_area', 'city', 'region', 'country', 'label')) {
        if (($Location.PSObject.Properties.Name -contains $property) -and (Test-JobAgentKnownValue -Value $Location.$property)) {
            $parts.Add((ConvertTo-JobAgentDedupSlug -Value ([string]$Location.$property)))
        }
    }
    if ($parts.Count -eq 0) {
        return 'unknown_location'
    }
    return (($parts.ToArray() | Select-Object -Unique) -join '_')
}

function New-JobAgentIdentityKey {
    param(
        [Parameter(Mandatory)][ValidateSet('OFFICIAL_JOB_ID', 'ATS_JOB_ID', 'CANONICAL_URL', 'COMPOSITE_FINGERPRINT')][string]$Basis,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Value
    )

    [pscustomobject]@{
        basis = $Basis
        key = (($Basis.ToLowerInvariant()) + ':' + (ConvertTo-JobAgentDedupSlug -Value $CompanyId) + ':' + (ConvertTo-JobAgentDedupSlug -Value $Value))
        value = $Value
    }
}

function New-JobAgentJobIdentityCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$OfficialUrl,
        [Parameter()][AllowEmptyString()][string]$ExternalJobId = 'UNKNOWN',
        [Parameter()][AllowEmptyString()][string]$AtsJobId = 'UNKNOWN',
        [Parameter()][AllowNull()][object]$Location,
        [Parameter()][AllowEmptyString()][string]$SourceId = 'UNKNOWN'
    )

    if ([string]::IsNullOrWhiteSpace($CompanyId)) {
        throw 'CompanyId darf nicht leer sein.'
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw 'Title darf nicht leer sein.'
    }

    $canonicalUrl = ConvertTo-JobAgentCanonicalUrl -Url $OfficialUrl
    $keys = New-Object System.Collections.Generic.List[object]
    if (Test-JobAgentKnownValue -Value $ExternalJobId) {
        $keys.Add((New-JobAgentIdentityKey -Basis 'OFFICIAL_JOB_ID' -CompanyId $CompanyId -Value ([string]$ExternalJobId)))
    }
    if (Test-JobAgentKnownValue -Value $AtsJobId) {
        $keys.Add((New-JobAgentIdentityKey -Basis 'ATS_JOB_ID' -CompanyId $CompanyId -Value ([string]$AtsJobId)))
    }
    $keys.Add((New-JobAgentIdentityKey -Basis 'CANONICAL_URL' -CompanyId $CompanyId -Value $canonicalUrl))

    $compositeValue = @(
        $CompanyId,
        (ConvertTo-JobAgentDedupText -Value $Title),
        (Get-JobAgentLocationFingerprint -Location $Location),
        (ConvertTo-JobAgentDedupText -Value $SourceId)
    ) -join '|'
    $keys.Add((New-JobAgentIdentityKey -Basis 'COMPOSITE_FINGERPRINT' -CompanyId $CompanyId -Value $compositeValue))

    [pscustomobject]@{
        company_id = $CompanyId
        title = $Title
        official_url = $canonicalUrl
        external_job_id = if (Test-JobAgentKnownValue -Value $ExternalJobId) { $ExternalJobId } else { 'UNKNOWN' }
        ats_job_id = if (Test-JobAgentKnownValue -Value $AtsJobId) { $AtsJobId } else { 'UNKNOWN' }
        location_fingerprint = Get-JobAgentLocationFingerprint -Location $Location
        source_id = $SourceId
        identity_keys = @($keys.ToArray())
    }
}

function New-JobAgentStableJobId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Candidate
    )

    $primary = @($Candidate.identity_keys)[0]
    return 'job:' + (ConvertTo-JobAgentDedupSlug -Value ($Candidate.company_id + '_' + $primary.basis + '_' + $primary.value))
}

function Get-JobAgentJobIdentityKeys {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Job
    )

    $location = if ($Job.PSObject.Properties.Name -contains 'location') { $Job.location } else { $null }
    $sourceId = if ($Job.PSObject.Properties.Name -contains 'source_id') { [string]$Job.source_id } else { 'UNKNOWN' }
    $candidate = New-JobAgentJobIdentityCandidate `
        -CompanyId ([string]$Job.company_id) `
        -Title ([string]$Job.title) `
        -OfficialUrl ([string]$Job.official_url) `
        -ExternalJobId ([string]$Job.external_job_id) `
        -AtsJobId ([string]$Job.ats_job_id) `
        -Location $location `
        -SourceId $sourceId

    $keys = New-Object System.Collections.Generic.List[object]
    foreach ($key in @($candidate.identity_keys)) {
        $keys.Add($key)
    }
    foreach ($url in @($Job.alternative_official_urls)) {
        if (Test-JobAgentKnownValue -Value $url) {
            $canonical = ConvertTo-JobAgentCanonicalUrl -Url ([string]$url)
            $keys.Add((New-JobAgentIdentityKey -Basis 'CANONICAL_URL' -CompanyId ([string]$Job.company_id) -Value $canonical))
        }
    }
    return $keys.ToArray()
}

function Find-JobAgentExistingJobMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$Candidate
    )

    foreach ($candidateKey in @($Candidate.identity_keys | Where-Object { $_.basis -ne 'COMPOSITE_FINGERPRINT' })) {
        foreach ($job in @($Document.jobs | Where-Object { [string]$_.company_id -eq [string]$Candidate.company_id })) {
            foreach ($jobKey in @(Get-JobAgentJobIdentityKeys -Job $job | Where-Object { $_.basis -ne 'COMPOSITE_FINGERPRINT' })) {
                if ([string]$candidateKey.key -eq [string]$jobKey.key) {
                    return [pscustomobject]@{
                        matched = $true
                        job = $job
                        identity_basis = $candidateKey.basis
                        confidence = 'EXACT'
                        reason = "Identitaet ueber $($candidateKey.basis) wiedererkannt."
                    }
                }
            }
        }
    }

    $candidateHasStrongIdentity = @($Candidate.identity_keys | Where-Object { $_.basis -ne 'COMPOSITE_FINGERPRINT' }).Count -gt 0
    foreach ($job in @($Document.jobs | Where-Object { [string]$_.company_id -eq [string]$Candidate.company_id })) {
        $jobKeys = @(Get-JobAgentJobIdentityKeys -Job $job)
        $jobHasStrongIdentity = @($jobKeys | Where-Object { $_.basis -ne 'COMPOSITE_FINGERPRINT' }).Count -gt 0
        if ($candidateHasStrongIdentity -or $jobHasStrongIdentity) {
            continue
        }

        $jobComposite = @($jobKeys | Where-Object { $_.basis -eq 'COMPOSITE_FINGERPRINT' } | Select-Object -First 1)
        $candidateComposite = @($Candidate.identity_keys | Where-Object { $_.basis -eq 'COMPOSITE_FINGERPRINT' } | Select-Object -First 1)
        if (($jobComposite.Count -eq 1) -and ($candidateComposite.Count -eq 1) -and ([string]$jobComposite[0].key -eq [string]$candidateComposite[0].key)) {
            return [pscustomobject]@{
                matched = $true
                job = $job
                identity_basis = 'COMPOSITE_FINGERPRINT'
                confidence = 'FALLBACK'
                reason = 'Identitaet ueber zusammengesetzten Fingerprint wiedererkannt.'
            }
        }
    }

    [pscustomobject]@{
        matched = $false
        job = $null
        identity_basis = (@($Candidate.identity_keys)[0]).basis
        confidence = 'NONE'
        reason = 'Keine belastbare bekannte Identitaet gefunden.'
    }
}

function Get-JobAgentChangedJobFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$ExistingJob,
        [Parameter(Mandatory)][object]$Candidate
    )

    $changed = New-Object System.Collections.Generic.List[string]
    if ((ConvertTo-JobAgentDedupText -Value $ExistingJob.title) -ne (ConvertTo-JobAgentDedupText -Value $Candidate.title)) {
        $changed.Add('title')
    }
    if ((ConvertTo-JobAgentCanonicalUrl -Url ([string]$ExistingJob.official_url)) -ne [string]$Candidate.official_url) {
        $changed.Add('official_url')
    }
    if ((ConvertTo-JobAgentDedupText -Value $ExistingJob.external_job_id) -ne (ConvertTo-JobAgentDedupText -Value $Candidate.external_job_id)) {
        $changed.Add('external_job_id')
    }
    if ((ConvertTo-JobAgentDedupText -Value $ExistingJob.ats_job_id) -ne (ConvertTo-JobAgentDedupText -Value $Candidate.ats_job_id)) {
        $changed.Add('ats_job_id')
    }
    return $changed.ToArray()
}

function Resolve-JobAgentJobDeduplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Document,
        [Parameter(Mandatory)][object]$Candidate
    )

    $match = Find-JobAgentExistingJobMatch -Document $Document -Candidate $Candidate
    if ($match.matched -eq $true) {
        $changedFields = @(Get-JobAgentChangedJobFields -ExistingJob $match.job -Candidate $Candidate)
        return [pscustomobject]@{
            decision = if ($changedFields.Count -gt 0) { 'UPDATED' } else { 'KNOWN' }
            is_existing = $true
            job_id = $match.job.job_id
            identity_basis = $match.identity_basis
            confidence = $match.confidence
            changed_fields = $changedFields
            reason = $match.reason
        }
    }

    [pscustomobject]@{
        decision = 'NEW'
        is_existing = $false
        job_id = New-JobAgentStableJobId -Candidate $Candidate
        identity_basis = (@($Candidate.identity_keys)[0]).basis
        confidence = 'NONE'
        changed_fields = @()
        reason = $match.reason
    }
}

Export-ModuleMember -Function @(
    'Find-JobAgentExistingJobMatch',
    'Get-JobAgentChangedJobFields',
    'Get-JobAgentJobIdentityKeys',
    'New-JobAgentJobIdentityCandidate',
    'New-JobAgentStableJobId',
    'Resolve-JobAgentJobDeduplication'
)
