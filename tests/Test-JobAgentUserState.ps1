#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$modulePath = Join-Path $root 'html\jobagent\assets\jobboard-state.js'
$schemaPath = Join-Path $root 'schemas\jobagent.user-state.schema.json'
$fixtureRoot = Join-Path $root 'tests\fixtures\jobagent\user-state'
Import-Module (Join-Path $PSScriptRoot 'JobAgent.SchemaValidation.psm1') -Force

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-UserStateNode {
    param([Parameter(Mandatory)][string]$Script)
    $output = @(& node.exe -e $Script $modulePath (Join-Path $fixtureRoot 'valid-v1.json') (Join-Path $root 'tests\fixtures\jobagent\hidden-jobs.json') (Join-Path $root 'tests\fixtures\jobagent\saved-searches.json') 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('UserState-Node-Test fehlgeschlagen: ' + ($output -join "`n"))
    return (($output -join "`n") | ConvertFrom-Json -Depth 30)
}

Assert-True -Condition (Test-Path -LiteralPath $modulePath -PathType Leaf) -Message 'Das DOM-unabhaengige UserState-Modul fehlt.'
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -Depth 100
Assert-True -Condition ($schema.properties.schema_version.const -eq 'jobagent-user-state/v2') -Message 'Das UserState-Schema fixiert nicht v2.'
Assert-True -Condition ($schema.properties.project_key.const -eq 'jobagent:personal:v2') -Message 'Das UserState-Schema fixiert nicht den v2-Projektschluessel.'

$ajvCli = Get-JobAgentAjvCliPath -RepositoryRoot $root
$compile = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('compile', '-s', $schemaPath, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($compile.exit -eq 0) -Message ('AJV kann das UserState-Schema nicht kompilieren: ' + ($compile.output -join "`n"))
$valid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', (Join-Path $fixtureRoot 'valid-v2.json'), '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($valid.exit -eq 0) -Message ('AJV lehnt die gueltige v2-Fixture ab: ' + ($valid.output -join "`n"))
$invalid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', (Join-Path $fixtureRoot 'valid-v1.json'), '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($invalid.exit -ne 0) -Message 'AJV akzeptiert eine v1-Fixture als v2.'
$hiddenFixture = Join-Path $root 'tests\fixtures\jobagent\hidden-jobs.json'
$hiddenValid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', $hiddenFixture, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($hiddenValid.exit -eq 0) -Message ('AJV lehnt die gueltige Ausblendungsfixture ab: ' + ($hiddenValid.output -join "`n"))
$savedSearchFixture = Join-Path $fixtureRoot 'valid-v2-saved-search.json'
$savedSearchValid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', $savedSearchFixture, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($savedSearchValid.exit -eq 0) -Message ('AJV lehnt die gueltige Suchauftragsfixture ab: ' + ($savedSearchValid.output -join "`n"))

$nodeResult = Invoke-UserStateNode -Script @'
const api=require(process.argv[1]),legacy=require('fs').readFileSync(process.argv[2],'utf8'),hiddenFixture=require(process.argv[3]),savedFixture=require(process.argv[4]);
class Storage { constructor(initial){this.data=new Map(Object.entries(initial||{}));this.throwWrite=false;} getItem(key){return this.data.has(key)?this.data.get(key):null;} setItem(key,value){if(this.throwWrite)throw new Error('quota');this.data.set(key,value);} }
const assert=(condition,message)=>{if(!condition)throw new Error(message)};
const job={job_id:'job:alpha',title:'Leitung IT',company:'Alpha AG',official_url:'https://alpha.example.invalid/jobs/alpha'};
const storage=new Storage({[api.LEGACY_PROJECT_KEY]:legacy});
const pending=api.read(storage);assert(pending.reason==='migrated_v1_pending_save'&&pending.state.jobs['job:alpha'].application_stage==='NONE','v1 migration false');
const saved=api.setMark(storage,job,'applied',true,'2026-09-18T09:01:00.000Z');assert(saved.persistent&&saved.record.application_stage==='APPLIED'&&saved.record.applied&&storage.getItem(api.LEGACY_PROJECT_KEY)===legacy,'migration preserves v1');
const preparing=api.transitionApplication(storage,job,'PREPARING',{correction:true,reason:'Korrektur'},'2026-09-18T09:02:00.000Z');assert(!preparing.record.applied&&preparing.record.applied_at===null&&preparing.record.application_history.length===1,'manual correction history');
let rejected=false;try{api.transitionApplication(storage,job,'INTERVIEW',null,'2026-09-18T09:03:00.000Z')}catch(error){rejected=error.code==='invalid_transition'}assert(rejected,'illegal transition');
api.transitionApplication(storage,job,'APPLIED',null,'2026-09-18T09:04:00.000Z');const interview=api.transitionApplication(storage,job,'INTERVIEW',null,'2026-09-18T09:05:00.000Z');assert(interview.record.applied&&interview.record.application_stage==='INTERVIEW','allowed transitions');
const note='😀'.repeat(4000);assert(api.updateApplicationText(storage,job,{note,next_action:'Nachfassen'},'2026-09-18T09:06:00.000Z').persistent,'unicode note boundary');let tooLong=false;try{api.updateApplicationText(storage,job,{note:'😀'.repeat(4001)},'2026-09-18T09:06:01.000Z')}catch(error){tooLong=error.code==='invalid_state'}assert(tooLong,'unicode note limit');
const task={task_id:'task-1',type:'APPLICATION_DEADLINE',title:'Unterlagen senden',local_date:'2026-10-25',time_with_offset:null,status:'OPEN'};const taskResult=api.upsertTask(storage,job,task,'2026-09-18T09:07:00.000Z');assert(taskResult.record.tasks.length===1,'task create');let dstRejected=false;try{api.upsertTask(storage,job,{...task,task_id:'task-2',time_with_offset:'02:30'},'2026-09-18T09:07:01.000Z')}catch(error){dstRejected=error.code==='invalid_state'}assert(dstRejected,'offset required');
for(let index=2;index<=20;index++){api.upsertTask(storage,job,{...task,task_id:'task-'+index,status:'OPEN'},`2026-09-18T09:${String(index).padStart(2,'0')}:00.000Z`)}let limited=false;try{api.upsertTask(storage,job,{...task,task_id:'task-21'},'2026-09-18T09:30:00.000Z')}catch(error){limited=error.code==='task_limit'}assert(limited,'open task limit');
const deleted=api.deleteTask(storage,job,'task-1','2026-09-18T09:31:00.000Z');assert(deleted.record.tasks.find(task=>task.task_id==='task-1').deleted_at!==null,'delete marker');let resurrection=false;try{api.upsertTask(storage,job,task,'2026-09-18T09:32:00.000Z')}catch(error){resurrection=error.code==='task_deleted'}assert(resurrection,'delete marker prevents resurrection');
const beforeQuota=storage.getItem(api.PROJECT_KEY);storage.throwWrite=true;const quota=api.setMark(storage,job,'favorite',false,'2026-09-18T09:33:00.000Z');storage.throwWrite=false;assert(!quota.persistent&&storage.getItem(api.PROJECT_KEY)===beforeQuota,'quota atomic');
const hiddenJob=api.setVisibility(storage,'job','job:alpha',true,{reason:'ROLE',text:'Nicht passend'},'2026-09-18T09:34:00.000Z');assert(hiddenJob.persistent&&hiddenJob.entry.hidden&&hiddenJob.entry.reason==='ROLE','job hidden');
const hiddenCompany=api.setVisibility(storage,'company','company:alpha',true,{reason:'EMPLOYER',text:''},'2026-09-18T09:35:00.000Z');assert(hiddenCompany.persistent&&api.visibilityFor(hiddenCompany.state,'job:alpha','company:alpha').scope==='job','job precedence');
const restoredJob=api.setVisibility(storage,'job','job:alpha',false,{},'2026-09-18T09:36:00.000Z');assert(restoredJob.persistent&&api.visibilityFor(restoredJob.state,'job:alpha','company:alpha').scope==='company','company remains after job restore');
assert(api.visibilityFor(hiddenFixture,'job:alpha','company:alpha').scope==='company'&&api.visibilityFor(hiddenFixture,'job:same-name-other-id','company:alpha').scope==='job','fixture keeps IDs independent');
let visibilityTooLong=false;try{api.setVisibility(storage,'company','company:alpha',true,{text:'😀'.repeat(501)},'2026-09-18T09:37:00.000Z')}catch(error){visibilityTooLong=error.code==='invalid_state'}assert(visibilityTooLong,'visibility text limit');
const importedVisibility=JSON.parse(api.exportState(storage).serialized);importedVisibility.hidden_jobs['job:alpha']={hidden:true,reason:'OTHER',text:'Alt',updated_at:'2026-09-18T09:33:00.000Z'};const preview=api.previewImport(storage,importedVisibility);assert(preview.valid&&preview.state.hidden_jobs['job:alpha'].hidden===false,'older import does not revive hidden job');
const visibilityOnlyStorage=new Storage();const visibilityOnlyImport=JSON.parse(JSON.stringify(hiddenFixture));const visibilityOnlyResult=api.importState(visibilityOnlyStorage,visibilityOnlyImport);assert(visibilityOnlyResult.changed&&visibilityOnlyResult.changed_visibility_ids.length===3&&api.read(visibilityOnlyStorage).state.hidden_companies['company:alpha'].hidden===true,'visibility-only import persists');
const filters=savedFixture.filters,initialBaseline=savedFixture.initial_baseline;
const savedSearch=api.saveSavedSearch(storage,{search_id:'search:alpha',name:'  Meine Suche  ',filters},initialBaseline,'2026-09-18T10:00:00.000Z');assert(savedSearch.persistent&&savedSearch.reason==='created_with_baseline'&&savedSearch.search.name==='Meine Suche','saved search create and trim');
const initialComparison=api.compareSavedSearch(savedSearch.search,{generation_id:'scan:one',matching_job_ids:['job:alpha'],visible_job_ids:['job:alpha'],change_events_by_job:{'job:alpha':['event:alpha-created']},personal_visibility_job_ids:[]});assert(initialComparison.available&&initialComparison.new_job_ids.length===0&&initialComparison.changed_job_ids.length===0,'initial baseline has no new results');
const comparison=api.compareSavedSearch(savedSearch.search,{generation_id:'scan:two',matching_job_ids:['job:alpha','job:beta','job:gamma'],visible_job_ids:['job:alpha','job:beta','job:gamma'],change_events_by_job:{'job:alpha':['event:alpha-created','event:alpha-update'],'job:beta':['event:beta-created'],'job:gamma':['event:gamma-created']},personal_visibility_job_ids:['job:gamma']});assert(comparison.reason==='generation_changed'&&comparison.new_job_ids.join(',')==='job:beta'&&comparison.changed_job_ids.join(',')==='job:alpha'&&comparison.personal_visibility_job_ids.join(',')==='job:gamma','generation comparison separates new changed and personal visibility');
const seen=api.markSavedSearchSeen(storage,'search:alpha',{generation_id:'scan:two',confirmed_job_ids:['job:alpha','job:beta','job:gamma'],confirmed_change_event_ids:['event:alpha-created','event:alpha-update','event:beta-created','event:gamma-created']},'2026-09-18T10:01:00.000Z');assert(seen.persistent&&seen.reason==='seen'&&seen.search.baseline.generation_id==='scan:two'&&seen.search.last_visit_at==='2026-09-18T10:01:00.000Z','explicit seen marker stores only supplied generation');
let duplicateName=false;try{api.saveSavedSearch(storage,{search_id:'search:other',name:'meine   suche',filters},initialBaseline,'2026-09-18T10:02:00.000Z')}catch(error){duplicateName=error.code==='duplicate_search_name'}assert(duplicateName,'normalized duplicate names are rejected');
const unicodeName='😀'.repeat(80),unicodeSearch=api.saveSavedSearch(storage,{search_id:'search:unicode',name:unicodeName,filters},initialBaseline,'2026-09-18T10:02:30.000Z');assert(unicodeSearch.persistent&&Array.from(unicodeSearch.search.name).length===80,'saved search name accepts 80 unicode code points');let longName=false;try{api.saveSavedSearch(storage,{search_id:'search:too-long',name:'😀'.repeat(81),filters},initialBaseline,'2026-09-18T10:02:31.000Z')}catch(error){longName=error.code==='invalid_state'}assert(longName,'saved search name rejects 81 unicode code points');api.deleteSavedSearch(storage,'search:unicode','2026-09-18T10:02:32.000Z');
const rebase=api.saveSavedSearch(storage,{search_id:'search:alpha',name:'Aktualisierte Suche',filters:{...filters,q:'Architekt'}},{generation_id:'scan:three',confirmed_job_ids:['job:beta'],confirmed_change_event_ids:['event:beta-created']},'2026-09-18T10:03:00.000Z');assert(rebase.persistent&&rebase.reason==='updated_and_rebased'&&rebase.search.created_at==='2026-09-18T10:00:00.000Z'&&rebase.search.baseline.generation_id==='scan:three','criteria update rebases explicitly and preserves creation time');
for(let index=1;index<50;index++){api.saveSavedSearch(storage,{search_id:'search:limit'+index,name:'Suche '+index,filters},{generation_id:'scan:limit',confirmed_job_ids:[],confirmed_change_event_ids:[]},'2026-09-18T10:04:00.000Z')}let searchLimit=false;try{api.saveSavedSearch(storage,{search_id:'search:limit50',name:'Suche 50',filters},{generation_id:'scan:limit',confirmed_job_ids:[],confirmed_change_event_ids:[]},'2026-09-18T10:04:01.000Z')}catch(error){searchLimit=error.code==='search_limit'}assert(Object.keys(api.read(storage).state.saved_searches).length===50&&searchLimit,'saved search limit is 50');
const deletedSearch=api.deleteSavedSearch(storage,'search:limit49','2026-09-18T10:05:00.000Z');assert(deletedSearch.persistent&&deletedSearch.changed&&Object.keys(api.read(storage).state.saved_searches).length===49,'saved search delete is explicit');
const searchBeforeQuota=storage.getItem(api.PROJECT_KEY);storage.throwWrite=true;const searchQuota=api.saveSavedSearch(storage,{search_id:'search:quota',name:'Quota Suche',filters},{generation_id:'scan:quota',confirmed_job_ids:[],confirmed_change_event_ids:[]},'2026-09-18T10:06:00.000Z');storage.throwWrite=false;assert(!searchQuota.persistent&&storage.getItem(api.PROJECT_KEY)===searchBeforeQuota,'saved search quota is atomic');
const exported=api.exportState(storage),reload=api.read(new Storage({[api.PROJECT_KEY]:exported.serialized}));assert(reload.persistent&&reload.state.jobs['job:alpha'].tasks.length===20,'export import');
assert(Object.keys(reload.state.saved_searches).length===49&&reload.state.saved_searches['search:alpha'].baseline.generation_id==='scan:three','saved searches survive export reload');
console.log(JSON.stringify({status:'ok',cases:['v1_migration_preserves_backup','stage_projection_and_correction_history','transition_contract','unicode_text_limits','task_crud_offset_and_limit','delete_marker','quota_atomicity','visibility_precedence_restore_and_merge','saved_search_contract_comparison_and_atomicity','export_reload']}));
'@

Assert-True -Condition ($nodeResult.status -eq 'ok') -Message 'Der DOM-unabhaengige UserState-Funktionstest lieferte kein vollstaendiges Ergebnis.'
[pscustomobject]@{ status = 'ok'; schema = $schemaPath; module = $modulePath; cases = @($nodeResult.cases) } | ConvertTo-Json -Depth 4
