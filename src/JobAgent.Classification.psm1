#requires -Version 7.4

Set-StrictMode -Version 3.0

function ConvertTo-JobAgentClassificationText {
    [CmdletBinding()]
    param(
        [Parameter()][AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }

    $text = [string]$Value
    $text = $text.ToLowerInvariant().
        Replace('ä', 'ae').
        Replace('ö', 'oe').
        Replace('ü', 'ue').
        Replace('ß', 'ss')
    return [regex]::Replace($text, '\s+', ' ').Trim()
}

function Test-JobAgentClassificationPattern {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        if ($Text -match $pattern) {
            return $true
        }
    }
    return $false
}

function Get-JobAgentLocationTargetArea {
    param(
        [Parameter()][AllowNull()][object]$Location
    )

    if ($null -eq $Location) {
        return 'UNKNOWN'
    }
    if ($Location -is [string]) {
        $text = ConvertTo-JobAgentClassificationText -Value $Location
        if ($text -match '\b(muenchen|munich)\b') { return 'MUNICH' }
        if ($text -match '\bfreising\b') { return 'FREISING' }
        if (($text -match '\bremote\b') -and ($text -match '\b(deutschland|germany|muenchen|munich|freising)\b')) {
            return 'REMOTE_WITH_TARGET_REFERENCE'
        }
        return 'UNKNOWN'
    }
    if ($Location.PSObject.Properties.Name -contains 'target_area') {
        return [string]$Location.target_area
    }
    if ($Location.PSObject.Properties.Name -contains 'label') {
        return Get-JobAgentLocationTargetArea -Location ([string]$Location.label)
    }
    return 'UNKNOWN'
}

function Add-JobAgentClassificationReason {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Reasons,
        [Parameter(Mandatory)][string]$Reason
    )

    if (-not $Reasons.Contains($Reason)) {
        $Reasons.Add($Reason)
    }
}

function Get-JobAgentLeadershipClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Title,
        [Parameter()][AllowEmptyString()][string]$Summary = '',
        [Parameter()][AllowEmptyString()][string]$Description = '',
        [Parameter()][AllowNull()][object]$Location,
        [Parameter()][ValidateSet('ON_SITE', 'HYBRID', 'REMOTE', 'UNKNOWN')][string]$WorkModel = 'UNKNOWN',
        [Parameter()][ValidateSet('FULL_TIME', 'PART_TIME', 'CONTRACT', 'TEMPORARY', 'UNKNOWN')][string]$EmploymentType = 'UNKNOWN',
        [Parameter()][datetime]$EvaluatedAt = [datetime]::UtcNow
    )

    $titleText = ConvertTo-JobAgentClassificationText -Value $Title
    $bodyText = ConvertTo-JobAgentClassificationText -Value (($Summary, $Description) -join ' ')
    $allText = ConvertTo-JobAgentClassificationText -Value (($Title, $Summary, $Description) -join ' ')
    $reasons = [System.Collections.Generic.List[string]]::new()
    $rejectedReasons = [System.Collections.Generic.List[string]]::new()
    $score = 0

    if ([string]::IsNullOrWhiteSpace($titleText)) {
        $rejectedReasons.Add('Titel fehlt; Klassifikation nicht belastbar.')
        return [pscustomobject]@{
            result = 'REJECTED'
            priority = 'UNRATED'
            score = 0
            reasons = @()
            rejected_reasons = @($rejectedReasons.ToArray())
            evaluated_at = $EvaluatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
        }
    }

    $executiveTitlePatterns = @(
        '\bcio\b',
        'chief information officer',
        '\bhead of (it|information technology)\b',
        '\b(it|information technology) director\b',
        '\bdirector (it|information technology)\b',
        '\bvp (it|information technology)\b',
        '\bleiter(in)? (it|informationstechnologie)\b',
        '\b(it|informationstechnologie)[- ]?leiter(in)?\b',
        '\bit[- ]?leitung\b',
        '\bbereichsleiter(in)? (it|informationstechnologie)\b'
    )
    $leadershipPatterns = @(
        'gesamtverantwortung',
        'gesamtleitung',
        'verantwortung fuer (die )?(it|informationstechnologie)',
        'end-to-end verantwortung',
        'disziplinarische fuehrung',
        'personalverantwortung',
        'budgetverantwortung',
        '\bpeople management\b',
        '\bline management\b'
    )
    $strategyPatterns = @(
        '\bit[- ]?strategie\b',
        'it roadmap',
        'digitalisierungsstrategie',
        'technologiestrategie',
        'strategische (ausrichtung|verantwortung)',
        '\btechnology strategy\b'
    )
    $negativeSpecialistPatterns = @(
        '\b(software|java|frontend|backend|fullstack|devops|cloud)? ?entwickler(in)?\b',
        '\bsoftware engineer\b',
        '\bdeveloper\b',
        '\barchitect\b',
        '\badministrator\b',
        '\bspecialist\b',
        '\bconsultant\b',
        '\bexpert\b'
    )
    $projectOnlyPatterns = @(
        '\bprojektleiter(in)?\b',
        '\bproject manager\b',
        '\bprogramme? manager\b'
    )
    $teamLeadPatterns = @(
        '\bteam ?lead\b',
        '\bteamleiter(in)?\b',
        '\blead developer\b'
    )

    $hasExecutiveTitle = Test-JobAgentClassificationPattern -Text $titleText -Patterns $executiveTitlePatterns
    $hasLeadershipEvidence = Test-JobAgentClassificationPattern -Text $allText -Patterns $leadershipPatterns
    $hasStrategyEvidence = Test-JobAgentClassificationPattern -Text $allText -Patterns $strategyPatterns
    $hasSpecialistNegative = Test-JobAgentClassificationPattern -Text $titleText -Patterns $negativeSpecialistPatterns
    $hasProjectOnlyTitle = Test-JobAgentClassificationPattern -Text $titleText -Patterns $projectOnlyPatterns
    $hasTeamLeadTitle = Test-JobAgentClassificationPattern -Text $titleText -Patterns $teamLeadPatterns

    if ($hasExecutiveTitle) {
        $score += 38
        Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Titel signalisiert IT-Gesamt- oder Bereichsleitung.'
    }
    if ($hasLeadershipEvidence) {
        $score += 24
        Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Fuehrungs-, Budget- oder Gesamtverantwortung ist belegt.'
    }
    if ($hasStrategyEvidence) {
        $score += 14
        Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Strategische IT-Verantwortung ist belegt.'
    }

    if ($allText -match '\b(it|informationstechnologie|information technology|technology|digitalisierung)\b') {
        $score += 8
        Add-JobAgentClassificationReason -Reasons $reasons -Reason 'IT-Bezug ist explizit vorhanden.'
    }
    else {
        $rejectedReasons.Add('Kein expliziter IT-Bezug erkennbar.')
    }

    $targetArea = Get-JobAgentLocationTargetArea -Location $Location
    switch ($targetArea) {
        { @('MUNICH', 'MUNICH_20KM', 'FREISING') -contains $_ } {
            $score += 8
            Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Standort liegt im Zielgebiet.'
            break
        }
        'REMOTE_WITH_TARGET_REFERENCE' {
            $score += 6
            Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Remote-Rolle hat Deutschland- oder Zielgebietsbezug.'
            break
        }
        'OUT_OF_SCOPE' {
            $score -= 30
            $rejectedReasons.Add('Standort liegt ausserhalb des Zielgebiets.')
            break
        }
        default {
            $rejectedReasons.Add('Standortbezug ist unklar.')
        }
    }

    if ($EmploymentType -eq 'FULL_TIME') {
        $score += 5
        Add-JobAgentClassificationReason -Reasons $reasons -Reason 'Vollzeitbezug ist vorhanden.'
    }
    elseif (@('CONTRACT', 'TEMPORARY') -contains $EmploymentType) {
        $score -= 15
        $rejectedReasons.Add('Beschaeftigungsart passt nicht zu einer regulaeren Vollzeit-Fuehrungsrolle.')
    }

    if (@('ON_SITE', 'HYBRID', 'REMOTE') -contains $WorkModel) {
        $score += 3
    }

    if ($hasSpecialistNegative -and -not ($hasExecutiveTitle -or $hasLeadershipEvidence)) {
        $score -= 35
        $rejectedReasons.Add('Titel wirkt wie Spezialisten- oder Entwicklerrolle ohne belegte Gesamtverantwortung.')
    }
    if ($hasProjectOnlyTitle -and -not ($hasExecutiveTitle -or $hasLeadershipEvidence)) {
        $score -= 25
        $rejectedReasons.Add('Projektleitung ohne belegte IT-Gesamtverantwortung reicht nicht aus.')
    }
    if ($hasTeamLeadTitle -and -not ($hasLeadershipEvidence -or $hasStrategyEvidence)) {
        $score -= 30
        $rejectedReasons.Add('Teamlead-Rolle ohne wesentliche Fuehrungs- oder Strategie-Verantwortung wird ausgeschlossen.')
    }

    $score = [Math]::Max(0, [Math]::Min(100, $score))
    $hardReject = ($rejectedReasons -contains 'Standort liegt ausserhalb des Zielgebiets.') -or
        (($hasSpecialistNegative -or $hasProjectOnlyTitle -or $hasTeamLeadTitle) -and ($score -lt 45))

    if ($hardReject -or $score -lt 45) {
        $result = 'REJECTED'
        $priority = 'UNRATED'
    }
    elseif ($score -ge 70 -and ($hasExecutiveTitle -or ($hasLeadershipEvidence -and $hasStrategyEvidence))) {
        $result = 'MATCH'
        $priority = if ($score -ge 85) { 'A' } else { 'B' }
    }
    else {
        $result = 'POSSIBLE'
        $priority = 'C'
    }

    [pscustomobject]@{
        result = $result
        priority = $priority
        score = $score
        reasons = @($reasons.ToArray())
        rejected_reasons = @($rejectedReasons.ToArray())
        evaluated_at = $EvaluatedAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [Globalization.CultureInfo]::InvariantCulture)
    }
}

Export-ModuleMember -Function @(
    'Get-JobAgentLeadershipClassification'
)
