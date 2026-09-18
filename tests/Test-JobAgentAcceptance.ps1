#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.CompanyInventory.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.DailyRun.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.SourceAdapters.psm1') -Force -DisableNameChecking

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-AcceptanceCompany {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][int]$Priority)

    $slug = $Name.ToLowerInvariant().Replace(' ', '-')
    New-JobAgentCompanySeed `
        -CanonicalName $Name `
        -OfficialWebsiteUrl "https://$slug.example.invalid/" `
        -CareerUrl "https://$slug.example.invalid/careers" `
        -Aliases @() `
        -Locations @((New-JobAgentTargetLocation -Label 'Muenchen' -City 'Muenchen' -TargetArea 'MUNICH')) `
        -Industry 'UNKNOWN' `
        -ScanPriority $Priority `
        -DiscoverySourceUrl "https://$slug.example.invalid/careers" `
        -CreatedAt ([datetime]'2026-09-18T08:00:00Z') `
        -NextScanAt ([datetime]'2026-09-18T08:00:00Z')
}

function Add-AcceptanceSource {
    param([Parameter(Mandatory)][string]$ProjectRoot, [Parameter(Mandatory)][string]$CompanyId)

    $document = Read-JobAgentStore -ProjectRoot $ProjectRoot
    $company = @($document.companies | Where-Object { [string]$_.company_id -eq $CompanyId })[0]
    Assert-True -Condition ($null -ne $company) -Message "Acceptance-Fixture kennt Firma $CompanyId nicht."
    $url = [string]$company.career_url
    $source = [pscustomobject]@{
        source_id = ('source:' + $CompanyId.Substring('company:'.Length) + ':career')
        company_id = $CompanyId
        source_type = 'CAREER_PAGE'
        url = $url
        canonical_url = $url
        is_official = $true
        verified_at = '2026-09-18T08:00:00.000Z'
        verification_basis = 'CAREER_URL'
        verification_evidence = @([pscustomobject]@{
                status = 'VERIFIED'
                evidence_type = 'CAREER_URL'
                url = $url
                basis_url = [string]$company.official_website_url
                redirect_chain = @()
                observed_at = '2026-09-18T08:00:00.000Z'
                reason = 'Deterministische JA-050-Akzeptanzfixture.'
            })
    }
    Write-JobAgentStore -ProjectRoot $ProjectRoot -Document (Upsert-JobAgentJobSource -Document $document -JobSource $source) | Out-Null
}

function New-AcceptanceJob {
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Title)

    [pscustomobject]@{
        title = $Title
        detail_url = "https://jobs.example.invalid/$Id"
        external_job_id = $Id
        ats_job_id = 'UNKNOWN'
        location_label = 'Muenchen'
        summary = "Akzeptanzfixture fuer $Title mit nachvollziehbarer Fuehrungsverantwortung."
        extraction_confidence = 95
    }
}

function Invoke-AcceptanceUserState {
    param(
        [Parameter(Mandatory)][hashtable]$JobIds,
        [Parameter(Mandatory)][hashtable]$ChangeEventIds,
        [Parameter(Mandatory)][string]$GenerationId
    )

    $payload = @{ job_ids = $JobIds; change_event_ids = $ChangeEventIds; generation_id = $GenerationId } | ConvertTo-Json -Compress
    $script = @'
const api=require(process.argv[1]),input=JSON.parse(process.argv[2]);
class Storage { constructor(){this.data=new Map();} getItem(key){return this.data.has(key)?this.data.get(key):null;} setItem(key,value){this.data.set(key,value);} }
const assert=(condition,message)=>{if(!condition)throw new Error(message)};
const ids=input.job_ids,events=input.change_event_ids,storage=new Storage();
const job=id=>({job_id:id,title:id,company:'Acceptance AG',official_url:'https://jobs.example.invalid/'+id});
const now='2026-09-18T10:00:00.000Z';
api.setMark(storage,job(ids.a1),'favorite',true,now);
api.transitionApplication(storage,job(ids.a2),'APPLIED',null,'2026-09-18T10:01:00.000Z');
api.updateApplicationText(storage,job(ids.a2),{note:'Unterlagen versendet',next_action:'Am 25.09. nachfassen'},'2026-09-18T10:02:00.000Z');
api.upsertTask(storage,job(ids.a2),{task_id:'a2-follow-up',type:'FOLLOW_UP',title:'Nachfassen',local_date:'2026-09-25',time_with_offset:null,status:'OPEN'},'2026-09-18T10:03:00.000Z');
api.setMark(storage,job(ids.b1),'favorite',true,'2026-09-18T10:04:00.000Z');
api.transitionApplication(storage,job(ids.b1),'APPLIED',null,'2026-09-18T10:05:00.000Z');
const filters={q:'',company:[],category:[],area:[],workModel:[],employmentType:[],workTime:[],age:'',favorite:false,applied:'all',sort:'published_desc',visibility:'visible'};
const baseline={generation_id:'scanrun:first',confirmed_job_ids:[ids.a1,ids.a2,ids.b1],confirmed_change_event_ids:[events.a1_created,events.a2_created,events.b1_created]};
const saved=api.saveSavedSearch(storage,{search_id:'search:acceptance',name:'Gesamtabnahme',filters},baseline,'2026-09-18T10:06:00.000Z');
const current={generation_id:input.generation_id,matching_job_ids:[ids.a1,ids.a2,ids.b1,ids.c1],visible_job_ids:[ids.a1,ids.b1,ids.c1],change_events_by_job:{[ids.a1]:[events.a1_created,events.a1_changed],[ids.a2]:[events.a2_created,events.a2_closed],[ids.b1]:[events.b1_created],[ids.c1]:[events.c1_created]},personal_visibility_job_ids:[]};
const beforeHide=api.compareSavedSearch(saved.search,current);
assert(beforeHide.new_job_ids.join(',')===ids.c1&&beforeHide.changed_job_ids.join(',')===ids.a1,'Suchvergleich vor Ausblendung');
api.setVisibility(storage,'job',ids.c1,true,{reason:'ROLE',text:'Nicht passend'},'2026-09-18T10:07:00.000Z');
const afterHide=api.compareSavedSearch(saved.search,{...current,visible_job_ids:[ids.a1,ids.b1],personal_visibility_job_ids:[ids.c1]});
assert(afterHide.new_job_ids.length===0&&afterHide.changed_job_ids.join(',')===ids.a1,'Ausblendung entfernt nur sichtbare Neuigkeiten');
const seen=api.markSavedSearchSeen(storage,'search:acceptance',{generation_id:input.generation_id,confirmed_job_ids:[ids.a1,ids.a2,ids.b1,ids.c1],confirmed_change_event_ids:[events.a1_created,events.a1_changed,events.a2_created,events.a2_closed,events.b1_created,events.c1_created]},'2026-09-18T10:08:00.000Z');
const afterSeen=api.compareSavedSearch(seen.search,{...current,visible_job_ids:[ids.a1,ids.b1],personal_visibility_job_ids:[ids.c1]});
const state=api.read(storage).state;
assert(afterSeen.new_job_ids.length===0&&afterSeen.changed_job_ids.length===0,'Sichtung setzt generationengebundene Basis');
assert(state.jobs[ids.a1].favorite&&!state.jobs[ids.a1].applied,'A1 Favorit');
assert(state.jobs[ids.a2].applied&&state.jobs[ids.a2].note==='Unterlagen versendet'&&state.jobs[ids.a2].tasks.length===1,'A2 bleibt mit Notiz und Aufgabe erhalten');
assert(state.jobs[ids.b1].favorite&&state.jobs[ids.b1].applied,'B1 beide Markierungen');
assert(state.hidden_jobs[ids.c1].hidden===true,'C1 ist nur lokal ausgeblendet');
console.log(JSON.stringify({status:'ok',visible_open_ids:[ids.a1,ids.b1],hidden_ids:[ids.c1]}));
'@
    $output = @(& node.exe -e $script (Join-Path $root 'html\jobagent\assets\jobboard-state.js') $payload 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('JA-050-Personenzustand fehlgeschlagen: ' + ($output -join "`n"))
    return (($output -join "`n") | ConvertFrom-Json -Depth 20)
}

$projectRoot = Join-Path ([IO.Path]::GetTempPath()) ('jobagent-ja050-' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $projectRoot -Force | Out-Null
    $document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-09-18T08:00:00Z')
    $seeded = Add-JobAgentCompanySeedInventory -Document $document -Seeds @(
        (New-AcceptanceCompany -Name 'Firma A' -Priority 90),
        (New-AcceptanceCompany -Name 'Firma B' -Priority 80),
        (New-AcceptanceCompany -Name 'Firma D' -Priority 70)
    ) -SeededAt ([datetime]'2026-09-18T08:00:00Z')
    Write-JobAgentStore -ProjectRoot $projectRoot -Document $seeded.document | Out-Null
    $phase = 'first'
    $adapter = {
        param($AdapterInput)
        $companyId = [string]$AdapterInput.company.company_id
        if ($phase -eq 'first') {
            switch ($companyId) {
                'company:firma_a' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @((New-AcceptanceJob -Id 'a1' -Title 'Leitung IT'), (New-AcceptanceJob -Id 'a2' -Title 'IT Architektur')) }
                'company:firma_b' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @((New-AcceptanceJob -Id 'b1' -Title 'IT Transformation')) }
                'company:firma_d' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -CompleteEmptyResult }
            }
        }
        switch ($companyId) {
            'company:firma_a' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @((New-AcceptanceJob -Id 'a1' -Title 'Leitung IT und Strategie')) }
            'company:firma_b' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -Status FAILED -ErrorClass NOT_REACHABLE -RetryRecommendation RETRY_NEXT_RUN -HttpStatus 503 }
            'company:firma_c' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @((New-AcceptanceJob -Id 'c1' -Title 'Digitalisierung')) }
            'company:firma_d' { return Invoke-JobAgentFixtureAdapter -AdapterInput $AdapterInput -FixtureJobs @() -CompleteEmptyResult }
        }
        throw "Unerwartete Acceptance-Firma: $companyId"
    }

    $first = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -CompanyIds @('company:firma_a', 'company:firma_b', 'company:firma_d') -StartedAt ([datetime]'2026-09-18T09:00:00Z')
    Assert-True -Condition ($first.status -eq 'SUCCESS') -Message ("Der erste JA-050-Fixture-Lauf muss vollstaendig erfolgreich sein, ist aber " + [string]$first.status + ': ' + ($first.document.scan_attempts | ConvertTo-Json -Compress -Depth 5))
    $firstDocument = Read-JobAgentStore -ProjectRoot $projectRoot
    Assert-True -Condition (@($firstDocument.companies).Count -eq 3 -and @($firstDocument.jobs).Count -eq 3) -Message 'Der erste Lauf liefert nicht exakt drei Firmen und drei historische Stellen.'

    $secondDocument = Read-JobAgentStore -ProjectRoot $projectRoot
    $secondDocument = Add-JobAgentCompanySeedInventory -Document $secondDocument -Seeds @((New-AcceptanceCompany -Name 'Firma C' -Priority 85)) -SeededAt ([datetime]'2026-09-18T10:00:00Z') | Select-Object -ExpandProperty document
    Write-JobAgentStore -ProjectRoot $projectRoot -Document $secondDocument | Out-Null
    $phase = 'second'
    $second = Invoke-JobAgentDailyRun -ProjectRoot $projectRoot -AdapterResolver $adapter -CompanyIds @('company:firma_a', 'company:firma_b', 'company:firma_c', 'company:firma_d') -StartedAt ([datetime]'2026-09-18T11:00:00Z')
    $finalDocument = Read-JobAgentStore -ProjectRoot $projectRoot
    $byExternalId = @{}
    foreach ($job in @($finalDocument.jobs)) { $byExternalId[[string]$job.external_job_id] = $job }
    Assert-True -Condition (@($finalDocument.companies).Count -eq 4 -and @($finalDocument.jobs).Count -eq 4) -Message 'Firmen- und historische Stellenzaehler wachsen nicht getrennt von 3 auf 4.'
    Assert-True -Condition (@($finalDocument.jobs | Where-Object { $_.status -in @('NEW', 'ACTIVE', 'UPDATED') }).Count -eq 3) -Message 'Der offene Bestand muss nach dem zweiten Lauf genau A1, B1 und C1 enthalten.'
    Assert-True -Condition ($byExternalId.a2.status -eq 'REMOVED' -or $byExternalId.a2.status -eq 'CLOSED') -Message 'A2 wurde nach erfolgreichem Fehlen nicht geschlossen.'
    Assert-True -Condition ($byExternalId.b1.status -in @('NEW', 'ACTIVE')) -Message 'Der Quellenfehler bei B hat B1 faelschlich entfernt.'
    Assert-True -Condition ($byExternalId.a1.title -eq 'Leitung IT und Strategie' -and $null -ne $byExternalId.c1) -Message 'A1-Update oder C1-Neuzugang fehlt.'

    $eventMap = @{}
    foreach ($job in @($byExternalId.Values)) {
        $eventMap[[string]$job.external_job_id] = @($finalDocument.change_events | Where-Object { [string]$_.job_id -eq [string]$job.job_id } | Select-Object -ExpandProperty change_event_id)
    }
    $userState = Invoke-AcceptanceUserState -JobIds @{ a1 = [string]$byExternalId.a1.job_id; a2 = [string]$byExternalId.a2.job_id; b1 = [string]$byExternalId.b1.job_id; c1 = [string]$byExternalId.c1.job_id } -ChangeEventIds @{ a1_created = [string]$eventMap.a1[0]; a1_changed = [string]$eventMap.a1[-1]; a2_created = [string]$eventMap.a2[0]; a2_closed = [string]$eventMap.a2[-1]; b1_created = [string]$eventMap.b1[0]; c1_created = [string]$eventMap.c1[0] } -GenerationId ([string]$second.scan_run_id)
    Assert-True -Condition (@($userState.visible_open_ids).Count -eq 2 -and @($userState.hidden_ids).Count -eq 1) -Message 'Ausblendungs- oder Suchsichtungsorakel lieferte eine falsche sichtbare Menge.'

    [pscustomobject]@{
        status = 'ok'
        cases = @('growth_counts', 'updated_and_closed_job', 'source_error_preserves_job', 'personal_marks_and_follow_up', 'saved_search_visibility_and_seen')
        companies = @($finalDocument.companies).Count
        historical_jobs = @($finalDocument.jobs).Count
        open_jobs = @($finalDocument.jobs | Where-Object { $_.status -in @('NEW', 'ACTIVE', 'UPDATED') }).Count
    } | ConvertTo-Json -Depth 5
}
finally {
    if (Test-Path -LiteralPath $projectRoot) { Remove-Item -LiteralPath $projectRoot -Recurse -Force }
}
