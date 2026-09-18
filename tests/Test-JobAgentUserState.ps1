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
    $output = @(& node.exe -e $Script $modulePath (Join-Path $fixtureRoot 'valid-v1.json') (Join-Path $root 'tests\fixtures\jobagent\hidden-jobs.json') 2>&1)
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

$nodeResult = Invoke-UserStateNode -Script @'
const api=require(process.argv[1]),legacy=require('fs').readFileSync(process.argv[2],'utf8'),hiddenFixture=require(process.argv[3]);
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
const exported=api.exportState(storage),reload=api.read(new Storage({[api.PROJECT_KEY]:exported.serialized}));assert(reload.persistent&&reload.state.jobs['job:alpha'].tasks.length===20,'export import');
console.log(JSON.stringify({status:'ok',cases:['v1_migration_preserves_backup','stage_projection_and_correction_history','transition_contract','unicode_text_limits','task_crud_offset_and_limit','delete_marker','quota_atomicity','visibility_precedence_restore_and_merge','export_reload']}));
'@

Assert-True -Condition ($nodeResult.status -eq 'ok') -Message 'Der DOM-unabhaengige UserState-Funktionstest lieferte kein vollstaendiges Ergebnis.'
[pscustomobject]@{ status = 'ok'; schema = $schemaPath; module = $modulePath; cases = @($nodeResult.cases) } | ConvertTo-Json -Depth 4
