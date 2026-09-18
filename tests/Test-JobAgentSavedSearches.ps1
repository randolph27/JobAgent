#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$stateAsset = Join-Path $root 'html\jobagent\assets\jobboard-state.js'
$uiAsset = Join-Path $root 'html\jobagent\assets\jobboard-saved-searches.js'
$reportModule = Join-Path $root 'src\JobAgent.Report.psm1'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-True -Condition (Test-Path -LiteralPath $stateAsset -PathType Leaf) -Message 'Das Saved-Search-State-Asset fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $uiAsset -PathType Leaf) -Message 'Das Saved-Search-UI-Asset fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $reportModule -PathType Leaf) -Message 'Das Reportmodul fehlt.'

$uiSyntax = @(& node.exe --check $uiAsset 2>&1)
Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('Das Saved-Search-UI-Asset ist syntaktisch ungueltig: ' + ($uiSyntax -join "`n"))

$result = @(& node.exe -e @'
const api=require(process.argv[1]);
class Storage { constructor(){this.values=new Map()} getItem(key){return this.values.get(key)||null} setItem(key,value){this.values.set(key,value)} }
const assert=(condition,message)=>{if(!condition)throw new Error(message)};
const filters={q:'Pflege',company:[],category:['Pflege'],area:['FREISING_CITY'],workModel:['HYBRID'],employmentType:['PART_TIME'],workTime:['UNKNOWN'],age:'7',favorite:false,applied:'all',sort:'published_desc',visibility:'visible'};
const storage=new Storage();
const created=api.saveSavedSearch(storage,{search_id:'search:pflege',name:'  Pflege Freising  ',filters},{generation_id:'scanrun:one',confirmed_job_ids:['job:pflege'],confirmed_change_event_ids:['change:pflege-created']},'2026-09-18T12:00:00.000Z');
assert(created.persistent&&created.reason==='created_with_baseline','create with baseline');
const unchanged=api.compareSavedSearch(created.search,{generation_id:'scanrun:one',matching_job_ids:['job:pflege'],visible_job_ids:['job:pflege'],change_events_by_job:{'job:pflege':['change:pflege-created']},personal_visibility_job_ids:[]});
assert(unchanged.new_job_ids.length===0&&unchanged.changed_job_ids.length===0,'initial state is not new');
const changed=api.compareSavedSearch(created.search,{generation_id:'scanrun:two',matching_job_ids:['job:pflege','job:neu'],visible_job_ids:['job:pflege','job:neu'],change_events_by_job:{'job:pflege':['change:pflege-created','change:pflege-updated'],'job:neu':['change:neu-created']},personal_visibility_job_ids:[]});
assert(changed.new_job_ids.join(',')==='job:neu'&&changed.changed_job_ids.join(',')==='job:pflege','generation comparison');
const seen=api.markSavedSearchSeen(storage,'search:pflege',{generation_id:'scanrun:two',confirmed_job_ids:['job:pflege','job:neu'],confirmed_change_event_ids:['change:pflege-created','change:pflege-updated','change:neu-created']},'2026-09-18T12:01:00.000Z');
assert(seen.persistent&&seen.search.baseline.generation_id==='scanrun:two','explicit seen marker');
console.log(JSON.stringify({status:'ok',cases:['saved_search_create_baseline','generation_bound_new_and_changed_comparison','explicit_seen_marker']}));
'@ $stateAsset 2>&1)
Assert-True -Condition ($LASTEXITCODE -eq 0) -Message ('Saved-Search-Funktionstest fehlgeschlagen: ' + ($result -join "`n"))
$payload = ($result -join "`n") | ConvertFrom-Json -Depth 10
Assert-True -Condition ($payload.status -eq 'ok') -Message 'Saved-Search-Funktionstest lieferte kein OK-Ergebnis.'

$reportSource = Get-Content -LiteralPath $reportModule -Raw
Assert-True -Condition ($reportSource.Contains('scan_run_id = $Report.scan_run_id')) -Message 'Die Clientdaten enthalten keine stabile Reportgeneration.'
Assert-True -Condition ($reportSource.Contains('Get-JobAgentReportSavedSearchScript')) -Message 'Das Saved-Search-UI-Asset wird nicht in den Report eingebettet.'
Assert-True -Condition ($reportSource.Contains('window.JobAgentSearch=Object.freeze')) -Message 'Der Renderer stellt keine kanonische Filterprojektion fuer Suchauftraege bereit.'

[pscustomobject]@{
    status = 'ok'
    cases = @($payload.cases) + @('saved_search_ui_asset_syntax', 'report_generation_and_canonical_filter_wiring')
} | ConvertTo-Json -Depth 4
