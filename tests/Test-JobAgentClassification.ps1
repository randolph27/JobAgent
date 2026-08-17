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
Assert-True -Condition (@($englishDirector.reasons | Where-Object { $_ -match 'Remote' }).Count -eq 1) -Message 'Remote-Deutschland-Bezug wurde nicht begruendet.'

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
Assert-True -Condition (@($unclearLocation.rejected_reasons | Where-Object { $_ -match 'Standortbezug ist unklar' }).Count -eq 1) -Message 'Unklarer Standort wurde nicht markiert.'

$outOfScope = Get-JobAgentLeadershipClassification `
    -Title 'CIO' `
    -Summary 'Gesamtleitung der IT, Budgetverantwortung und Technology Strategy.' `
    -Location (New-TestLocation -TargetArea 'OUT_OF_SCOPE' -Label 'Hamburg') `
    -WorkModel 'ON_SITE' `
    -EmploymentType 'FULL_TIME' `
    -EvaluatedAt $fixedTime
Assert-True -Condition ($outOfScope.result -eq 'REJECTED') -Message 'Standort ausserhalb Zielgebiet wurde nicht abgelehnt.'

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
        'empty_title',
        'possible_it_manager'
    )
} | ConvertTo-Json -Depth 4
