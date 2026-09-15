#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Classification.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function New-TestLocation {
    param(
        [Parameter()][string]$TargetArea = 'MUNICH',
        [Parameter()][string]$Label = 'Muenchen'
    )

    [pscustomobject]@{
        label = $Label
        city = $Label
        region = 'Bayern'
        country = 'DE'
        target_area = $TargetArea
    }
}

$fixedTime = [datetime]'2026-08-17T10:30:00Z'

$headOfIt = Get-JobAgentLeadershipClassification `
    -Title 'Head of IT' `
    -Summary 'Gesamtverantwortung fuer die IT, Budgetverantwortung und IT-Strategie.' `
    -Location (New-TestLocation) `
    -WorkModel 'HYBRID' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($headOfIt.result -eq 'MATCH') -Message 'Head-of-IT-Rolle wurde nicht als MATCH klassifiziert.'
Assert-True -Condition ($headOfIt.priority -eq 'A') -Message 'Starke Fuehrungsrolle wurde nicht als Prioritaet A bewertet.'
Assert-True -Condition ($headOfIt.score -ge 85) -Message 'Score fuer starke Fuehrungsrolle ist zu niedrig.'

$englishDirector = Get-JobAgentLeadershipClassification `
    -Title 'Director Information Technology' `
    -Summary 'Line management, people management and technology strategy for Germany.' `
    -Location (New-TestLocation -TargetArea 'REMOTE_WITH_TARGET_REFERENCE' -Label 'Remote Germany') `
    -WorkModel 'REMOTE' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($englishDirector.result -eq 'MATCH') -Message 'Englische Director-IT-Rolle wurde nicht als MATCH klassifiziert.'

$developer = Get-JobAgentLeadershipClassification `
    -Title 'Senior Software Engineer' `
    -Summary 'Entwicklung von Backend Services im Plattformteam.' `
    -Location (New-TestLocation) `
    -WorkModel 'HYBRID' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($developer.result -eq 'REJECTED') -Message 'Entwicklerrolle wurde nicht abgelehnt.'
Assert-True -Condition (@($developer.rejected_reasons | Where-Object { $_ -match 'Spezialisten|Entwickler' }).Count -eq 1) -Message 'Entwickler-Ausschlussgrund fehlt.'

$projectManager = Get-JobAgentLeadershipClassification `
    -Title 'IT Project Manager' `
    -Summary 'Projektplanung und Reporting fuer mehrere IT-Projekte.' `
    -Location (New-TestLocation) `
    -WorkModel 'ON_SITE' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($projectManager.result -eq 'REJECTED') -Message 'Projektleitung ohne Gesamtverantwortung wurde nicht abgelehnt.'
Assert-True -Condition (@($projectManager.rejected_reasons | Where-Object { $_ -match 'Projektleitung' }).Count -eq 1) -Message 'Projektleitungs-Ausschlussgrund fehlt.'

$teamLead = Get-JobAgentLeadershipClassification `
    -Title 'Team Lead Software Development' `
    -Summary 'Fuehrt ein kleines Entwicklerteam operativ im Sprint.' `
    -Location (New-TestLocation) `
    -WorkModel 'HYBRID' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($teamLead.result -eq 'REJECTED') -Message 'Teamlead ohne wesentliche Fuehrungsverantwortung wurde nicht abgelehnt.'
Assert-True -Condition (@($teamLead.rejected_reasons | Where-Object { $_ -match 'Teamlead' }).Count -eq 1) -Message 'Teamlead-Ausschlussgrund fehlt.'

$unclearLocation = Get-JobAgentLeadershipClassification `
    -Title 'IT Leiter' `
    -Summary 'Verantwortung fuer die IT und IT-Strategie.' `
    -Location (New-TestLocation -TargetArea 'UNKNOWN' -Label 'UNKNOWN') `
    -WorkModel 'UNKNOWN' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($unclearLocation.result -eq 'MATCH') -Message 'Unklarer Standort darf starke IT-Leitung nicht automatisch ablehnen.'

$outOfScope = Get-JobAgentLeadershipClassification `
    -Title 'CIO' `
    -Summary 'Gesamtleitung der IT, Budgetverantwortung und Technology Strategy.' `
    -Location (New-TestLocation -TargetArea 'OUT_OF_SCOPE' -Label 'Hamburg') `
    -WorkModel 'ON_SITE' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($outOfScope.result -eq 'MATCH') -Message 'Profilpassung darf nicht durch Gebietsbewertung verworfen werden.'

$validAccountingJob = Get-JobAgentOfficialJobValidity -Title 'Sachbearbeitung Buchhaltung' -OfficialUrl 'https://example.invalid/careers/accounting-42' -EvaluatedAt $fixedTime
Assert-True -Condition ($validAccountingJob.result -eq 'VALID') -Message 'Belegte Buchhaltungsstelle wurde nicht als gueltig erkannt.'

$navigationEntry = Get-JobAgentOfficialJobValidity -Title 'Karriere' -OfficialUrl 'https://example.invalid/careers' -EntryKind 'NAVIGATION' -EvaluatedAt $fixedTime
Assert-True -Condition ($navigationEntry.result -eq 'REJECTED') -Message 'Navigationseintrag wurde nicht abgelehnt.'

$inScope = Get-JobAgentRegionalScope -Location (New-TestLocation) -EvaluatedAt $fixedTime
Assert-True -Condition ($inScope.result -eq 'IN_SCOPE' -and $inScope.target_area -eq 'MUNICH') -Message 'Muenchen wurde nicht als separates Zielgebiet bewertet.'

$outsideScope = Get-JobAgentRegionalScope -Location (New-TestLocation -TargetArea 'OUT_OF_SCOPE' -Label 'Hamburg') -EvaluatedAt $fixedTime
Assert-True -Condition ($outsideScope.result -eq 'OUT_OF_SCOPE') -Message 'Ausserhalb liegender Stellenort wurde nicht separat bewertet.'

$unknownScope = Get-JobAgentRegionalScope -Location (New-TestLocation -TargetArea 'UNKNOWN' -Label 'UNKNOWN') -EvaluatedAt $fixedTime
Assert-True -Condition ($unknownScope.result -eq 'UNKNOWN') -Message 'Unbelegter Stellenort wurde nicht als UNKNOWN erhalten.'

$emptyTitle = Get-JobAgentLeadershipClassification -Title '' -Summary 'IT-Gesamtverantwortung' -EvaluatedAt $fixedTime
Assert-True -Condition ($emptyTitle.result -eq 'REJECTED') -Message 'Leerer Titel wurde nicht abgelehnt.'
Assert-True -Condition ($emptyTitle.score -eq 0) -Message 'Leerer Titel darf keinen Score erhalten.'

$possible = Get-JobAgentLeadershipClassification `
    -Title 'IT Manager' `
    -Summary 'Verantwortung fuer IT-Services und Betrieb.' `
    -Location 'Muenchen' `
    -WorkModel 'HYBRID' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($possible.result -eq 'POSSIBLE') -Message 'Grenzfall IT Manager wurde nicht als POSSIBLE klassifiziert.'
Assert-True -Condition ($possible.priority -eq 'C') -Message 'Grenzfall muss Prioritaet C erhalten.'

$itManagerLeadership = Get-JobAgentLeadershipClassification `
    -Title 'IT Manager' `
    -Summary 'Personalverantwortung, Budgetverantwortung und IT-Strategie fuer die zentrale IT.' `
    -Location (New-TestLocation) `
    -WorkModel 'HYBRID' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($itManagerLeadership.result -eq 'MATCH') -Message 'IT-Manager-Rolle mit belegter Fuehrungsverantwortung wurde nicht als MATCH klassifiziert.'
Assert-True -Condition ($itManagerLeadership.priority -eq 'A') -Message 'IT-Manager-Rolle mit starker Fuehrung muss Prioritaet A erhalten.'

$itLeadLeadership = Get-JobAgentLeadershipClassification `
    -Title 'IT Lead' `
    -Summary 'Leitet die IT-Organisation mit Personalverantwortung und Roadmap-Verantwortung.' `
    -Location (New-TestLocation -TargetArea 'FREISING' -Label 'Freising') `
    -WorkModel 'ON_SITE' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($itLeadLeadership.result -eq 'MATCH') -Message 'IT-Lead-Rolle mit belegter Fuehrungsverantwortung wurde nicht als MATCH klassifiziert.'

$regionalCases = @(
    [pscustomobject]@{ name = 'muenchen'; target_area = 'MUNICH'; label = 'Muenchen'; expected_scope = 'IN_SCOPE' },
    [pscustomobject]@{ name = 'freising'; target_area = 'FREISING'; label = 'Freising'; expected_scope = 'IN_SCOPE' },
    [pscustomobject]@{ name = 'outside'; target_area = 'OUT_OF_SCOPE'; label = 'Augsburg'; expected_scope = 'OUT_OF_SCOPE' },
    [pscustomobject]@{ name = 'unknown'; target_area = 'UNKNOWN'; label = 'UNKNOWN'; expected_scope = 'UNKNOWN' }
)
$roleCases = @(
    [pscustomobject]@{ name = 'it_leitung'; title = 'IT Leitung'; summary = 'Gesamtverantwortung fuer IT, Budget und Strategie.'; expected_result = 'MATCH' },
    [pscustomobject]@{ name = 'pflege'; title = 'Pflegefachkraft'; summary = 'Stationaere Pflege und Dokumentation.'; expected_result = 'REJECTED' },
    [pscustomobject]@{ name = 'buchhaltung'; title = 'Sachbearbeitung Buchhaltung'; summary = 'Debitoren, Kreditoren und Monatsabschluss.'; expected_result = 'REJECTED' },
    [pscustomobject]@{ name = 'ausbildung'; title = 'Ausbildung Kaufleute fuer Bueromanagement'; summary = 'Ausbildungsplatz im kaufmaennischen Bereich.'; expected_result = 'REJECTED' }
)
foreach ($regionalCase in $regionalCases) {
    $location = New-TestLocation -TargetArea $regionalCase.target_area -Label $regionalCase.label
    $scope = Get-JobAgentRegionalScope -Location $location -EvaluatedAt $fixedTime
    Assert-True -Condition ($scope.result -eq $regionalCase.expected_scope) -Message "Gebietsgrenze $($regionalCase.name) liefert $($scope.result) statt $($regionalCase.expected_scope)."
    foreach ($roleCase in $roleCases) {
        $classification = Get-JobAgentLeadershipClassification `
            -Title $roleCase.title `
            -Summary $roleCase.summary `
            -Location $location `
            -WorkModel 'ON_SITE' `
            -EmploymentType 'FULL_TIME' `
            -EvaluatedAt $fixedTime
        Assert-True -Condition ($classification.result -eq $roleCase.expected_result) -Message "Rolle $($roleCase.name) im Gebiet $($regionalCase.name) liefert $($classification.result) statt $($roleCase.expected_result)."
    }
}

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'german_head_of_it',
        'english_director_remote_germany',
        'developer_rejection',
        'project_manager_rejection',
        'teamlead_rejection',
        'unclear_location',
        'out_of_scope_location',
        'valid_non_it_job',
        'navigation_entry_rejected',
        'regional_scope_separate',
        'empty_title',
        'possible_it_manager',
        'it_manager_with_leadership_match',
        'it_lead_with_leadership_match',
        'four_roles_across_munich_freising_outside_and_unknown'
    )
} | ConvertTo-Json -Depth 4
