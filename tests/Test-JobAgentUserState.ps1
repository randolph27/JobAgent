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

    $output = @(& node.exe -e $Script $modulePath 2>&1)
    Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('UserState-Node-Test fehlgeschlagen: ' + ($output -join "`n"))
    return (($output -join "`n") | ConvertFrom-Json -Depth 30)
}

Assert-True -Condition (Test-Path -LiteralPath $modulePath -PathType Leaf) -Message 'Das DOM-unabhaengige UserState-Modul fehlt.'
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -Depth 100
Assert-True -Condition ($schema.properties.schema_version.const -eq 'jobagent-user-state/v1') -Message 'Das UserState-Schema fixiert nicht v1.'
Assert-True -Condition ($schema.properties.project_key.const -eq 'jobagent:personal:v1') -Message 'Das UserState-Schema fixiert nicht den Projektschluessel.'

$ajvCli = Get-JobAgentAjvCliPath -RepositoryRoot $root
$compile = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('compile', '-s', $schemaPath, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($compile.exit -eq 0) -Message ('AJV kann das UserState-Schema nicht kompilieren: ' + ($compile.output -join "`n"))
$validFixture = Join-Path $fixtureRoot 'valid-v1.json'
$invalidFixture = Join-Path $fixtureRoot 'invalid-unsupported-version.json'
$valid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', $validFixture, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($valid.exit -eq 0) -Message ('AJV lehnt die gueltige UserState-Fixture ab: ' + ($valid.output -join "`n"))
$invalid = Invoke-JobAgentAjvCli -CliPath $ajvCli -Arguments @('validate', '-s', $schemaPath, '-d', $invalidFixture, '--spec=draft2020', '-c', 'ajv-formats') -RepositoryRoot $root
Assert-True -Condition ($invalid.exit -ne 0) -Message 'AJV akzeptiert eine unbekannte UserState-Version.'

$nodeResult = Invoke-UserStateNode -Script @'
const api=require(process.argv[1]);
class Storage { constructor(initial){this.data=new Map(Object.entries(initial||{}));this.throwRead=false;this.throwWrite=false;} getItem(key){if(this.throwRead)throw new Error('blocked');return this.data.has(key)?this.data.get(key):null;} setItem(key,value){if(this.throwWrite)throw new Error('quota');this.data.set(key,value);} }
const assert=(condition,message)=>{if(!condition)throw new Error(message)};
const job={job_id:'job:alpha',title:'Leitung IT',company:'Alpha AG',official_url:'https://alpha.example.invalid/jobs/alpha'};
const storage=new Storage();
const favorite=api.setMark(storage,job,'favorite',true,'2026-09-17T18:00:00.000Z');
const applied=api.setMark(storage,job,'applied',true,'2026-09-17T18:01:00.000Z');
const noOp=api.setMark(storage,job,'applied',true,'2026-09-17T18:02:00.000Z');
assert(favorite.record.favorite===true&&favorite.record.applied===false,'favorite isolation');
assert(applied.record.favorite===true&&applied.record.applied===true&&applied.record.applied_at==='2026-09-17T18:01:00.000Z','applied timestamp');
assert(noOp.changed===false&&noOp.record.applied_updated_at==='2026-09-17T18:01:00.000Z','idempotence');
const unapplied=api.setMark(storage,job,'applied',false,'2026-09-17T18:03:00.000Z');
assert(unapplied.record.favorite===true&&unapplied.record.applied===false&&unapplied.record.applied_at===null&&unapplied.record.applied_updated_at==='2026-09-17T18:03:00.000Z','unapply preserves favorite');
const allStates=new Storage();
api.setMark(allStates,{job_id:'job:none'},'favorite',true,'2026-09-17T19:00:00.000Z');api.setMark(allStates,{job_id:'job:none'},'favorite',false,'2026-09-17T19:01:00.000Z');api.setMark(allStates,{job_id:'job:none'},'applied',true,'2026-09-17T19:02:00.000Z');api.setMark(allStates,{job_id:'job:none'},'applied',false,'2026-09-17T19:03:00.000Z');
api.setMark(allStates,{job_id:'job:fav'},'favorite',true,'2026-09-17T19:00:00.000Z');
api.setMark(allStates,{job_id:'job:applied'},'applied',true,'2026-09-17T19:00:00.000Z');
api.setMark(allStates,{job_id:'job:both'},'favorite',true,'2026-09-17T19:00:00.000Z');api.setMark(allStates,{job_id:'job:both'},'applied',true,'2026-09-17T19:01:00.000Z');
const states=api.read(allStates).state.jobs;
assert(Object.keys(states).length===4&&states['job:none'].favorite===false&&states['job:none'].applied===false&&states['job:both'].favorite&&states['job:both'].applied,'four combinations');
assert(!api.read(allStates).state.jobs['job:new-id'],'new id inherits state');
const blockedStorage=new Storage();blockedStorage.throwRead=true;const blocked=api.setMark(blockedStorage,job,'favorite',true,'2026-09-17T19:04:00.000Z');assert(blocked.persistent===false&&blocked.reason==='storage_unavailable','blocked storage');
const beforeBad=storage.getItem(api.PROJECT_KEY);storage.data.set(api.PROJECT_KEY,'{broken');const corrupt=api.setMark(storage,job,'favorite',false,'2026-09-17T18:04:00.000Z');assert(corrupt.persistent===false&&storage.getItem(api.PROJECT_KEY)==='{broken','corrupt preservation');storage.data.set(api.PROJECT_KEY,beforeBad);
const unsupported=JSON.stringify({schema_version:'jobagent-user-state/v2',project_key:api.PROJECT_KEY,updated_at:null,jobs:{}});storage.data.set(api.PROJECT_KEY,unsupported);const version=api.setMark(storage,job,'favorite',false,'2026-09-17T18:04:00.000Z');assert(version.persistent===false&&storage.getItem(api.PROJECT_KEY)===unsupported,'unknown version preservation');storage.data.set(api.PROJECT_KEY,beforeBad);
storage.throwWrite=true;const quota=api.setMark(storage,job,'favorite',false,'2026-09-17T18:04:00.000Z');assert(quota.persistent===false&&storage.getItem(api.PROJECT_KEY)===beforeBad,'quota preservation');storage.throwWrite=false;
const invalidImport=api.importState(storage,'{bad');assert(invalidImport.changed===false&&storage.getItem(api.PROJECT_KEY)===beforeBad,'invalid import atomic');
const imported=api.createEmptyState();imported.updated_at='2026-09-17T20:00:00.000Z';imported.jobs['job:alpha']={favorite:false,applied:true,favorite_updated_at:'2026-09-17T20:00:00.000Z',applied_updated_at:'2026-09-17T20:00:00.000Z',applied_at:'2026-09-17T20:00:00.000Z'};imported.jobs['job:removed']={favorite:true,applied:false,favorite_updated_at:'2026-09-17T20:00:00.000Z',applied_updated_at:null,applied_at:null};
const preview=api.previewImport(storage,JSON.stringify(imported));assert(preview.valid&&preview.changed_job_ids.join(',')==='job:alpha,job:removed','preview');const merged=api.importState(storage,JSON.stringify(imported));assert(merged.changed&&api.read(storage).state.jobs['job:removed'].favorite,'import');
const tie=api.createEmptyState();tie.jobs['job:alpha']={favorite:true,applied:false,favorite_updated_at:'2026-09-17T20:00:00.000Z',applied_updated_at:null,applied_at:null};api.importState(storage,JSON.stringify(tie));assert(api.read(storage).state.jobs['job:alpha'].favorite===false,'tie keeps existing');
const exported=api.exportState(storage);const reload=api.read(new Storage({[api.PROJECT_KEY]:exported.serialized}));assert(reload.persistent&&reload.state.jobs['job:alpha'].applied===true&&reload.state.jobs['job:removed'].favorite&&JSON.stringify(reload.state)===exported.serialized,'export reload');
const events=[];const target={listener:null,addEventListener(type,listener){this.listener=listener;},removeEventListener(){this.listener=null;}};const unsubscribe=api.subscribeStorage(storage,event=>events.push(event),target);target.listener({key:api.PROJECT_KEY,storageArea:storage,newValue:exported.serialized});unsubscribe();assert(events.length===1&&events[0].state.jobs['job:alpha'].applied===true,'storage event');
console.log(JSON.stringify({status:'ok',export_hash_length:require('crypto').createHash('sha256').update(exported.serialized).digest('hex').length,cases:['four_combinations','separate_timestamps','manual_idempotence','new_id_does_not_inherit','blocked_storage','reload_and_report_change_identity','corrupt_and_unknown_preserved','quota_preserved','atomic_import_preview','field_timestamp_merge','removed_job_retained','export_import','storage_event']}));
'@

Assert-True -Condition ($nodeResult.status -eq 'ok' -and $nodeResult.export_hash_length -eq 64) -Message 'Der DOM-unabhaengige UserState-Funktionstest lieferte kein vollstaendiges Ergebnis.'

[pscustomobject]@{
    status = 'ok'
    schema = $schemaPath
    module = $modulePath
    cases = @($nodeResult.cases)
} | ConvertTo-Json -Depth 4
