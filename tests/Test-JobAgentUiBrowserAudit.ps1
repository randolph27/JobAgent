#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$FixtureOnly
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Import-Module (Join-Path $root 'src\JobAgent.Persistence.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'src\JobAgent.Report.psm1') -Force -DisableNameChecking

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Write-Utf8File {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [IO.File]::WriteAllText($Path, $Content + "`n", [Text.UTF8Encoding]::new($false))
}

function ConvertTo-JobAgentFixtureJson {
    param([Parameter(Mandatory)][object]$Document)

    return ($Document | ConvertTo-Json -Depth 100)
}

function Get-JobAgentSha256 {
    param([Parameter(Mandatory)][string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-JobAgentSessionValue {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Case
    )

    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', $Script)
    $result = [regex]::Match($output, '(?ms)### Result\s*\r?\n(?<payload>.+?)\s*$')
    Assert-True -Condition $result.Success -Message "${Case}: Playwright-CLI lieferte kein Eval-Ergebnis."
    $value = $result.Groups['payload'].Value.Trim() | ConvertFrom-Json -Depth 20
    if ($value -is [string]) {
        return $value | ConvertFrom-Json -Depth 20
    }
    return $value
}

function Get-JobAgentGeometryMeasurement {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string]$Case,
        [Parameter(Mandatory)][int]$ViewportWidth,
        [Parameter(Mandatory)][int]$ViewportHeight,
        [double]$CssZoom = 1
    )

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'resize', $ViewportWidth, $ViewportHeight) | Out-Null
    $zoomValue = $CssZoom.ToString([Globalization.CultureInfo]::InvariantCulture)
    $script = @"
() => { const s=(...codes)=>String.fromCharCode(...codes),tags=[s(98,117,116,116,111,110),s(105,110,112,117,116),s(115,101,108,101,99,116)],textTags=[s(104,49),s(104,50),s(104,51),s(112),s(97),s(98,117,116,116,111,110),s(108,97,98,101,108),s(111,112,116,105,111,110)],elements=Array.from(document.getElementsByTagName(s(42))); document.documentElement.style.zoom=$zoomValue; const visible=element=>{const style=getComputedStyle(element),rect=element.getBoundingClientRect();return style.display!==s(110,111,110,101)&&style.visibility!==s(104,105,100,100,101,110)&&rect.width>0&&rect.height>0}; const controls=elements.filter(element=>tags.includes(element.tagName.toLowerCase())).map((element,index)=>{const rect=element.getBoundingClientRect();return {id:element.id||element.name||String(element.textContent||String()).trim()||s(99,111,110,116,114,111,108,45)+index,left:rect.left,top:rect.top,right:rect.right,bottom:rect.bottom,width:rect.width,height:rect.height}}).filter(item=>item.width>0&&item.height>0); const invalidControls=controls.filter(item=>item.width<44||item.height<44||item.left<0||item.right>window.innerWidth+1); const overlaps=[]; for(let left=0;left<controls.length;left++){for(let right=left+1;right<controls.length;right++){const a=controls[left],b=controls[right];if(Math.min(a.right,b.right)-Math.max(a.left,b.left)>1&&Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top)>1){overlaps.push({first:a.id,second:b.id})}}} const clippedText=elements.filter(element=>textTags.includes(element.tagName.toLowerCase())).filter(element=>{const style=getComputedStyle(element);return visible(element)&&style.overflow!==s(118,105,115,105,98,108,101)&&element.scrollWidth>element.clientWidth+1&&!element.title}).map(element=>String(element.textContent||String()).trim()).filter(Boolean); return JSON.stringify({viewport_width:window.innerWidth,viewport_height:window.innerHeight,root_scroll_width:document.documentElement.scrollWidth,invalid_controls:invalidControls,overlaps:overlaps,clipped_text:clippedText,controls:controls}); }
"@
    $measurement = Get-JobAgentSessionValue -WorkingDirectory $WorkingDirectory -SessionName $SessionName -Script $script -Case $Case
    $measurement | Add-Member -NotePropertyName css_zoom -NotePropertyValue $CssZoom
    return $measurement
}

function Assert-JobAgentGeometryMeasurement {
    param(
        [Parameter(Mandatory)][object]$Measurement,
        [Parameter(Mandatory)][object]$VisualContract,
        [Parameter(Mandatory)][string]$Case
    )

    Assert-True -Condition ([int]$Measurement.root_scroll_width -le ([int]$Measurement.viewport_width + [int]$VisualContract.max_root_overflow_css_px)) -Message "${Case}: Die Dokumentbreite uebersteigt den Viewport unzulaessig."
    Assert-True -Condition (@($Measurement.invalid_controls).Count -eq 0) -Message "${Case}: Ein sichtbares Control ist kleiner als $($VisualContract.min_control_size_css_px) CSS-px oder ausserhalb des Viewports."
    Assert-True -Condition (@($Measurement.overlaps).Count -eq 0) -Message "${Case}: Sichtbare bedienbare Controls ueberlappen sich."
    $clippedText = @($Measurement.clipped_text) -join ' | '
    Assert-True -Condition (@($Measurement.clipped_text).Count -eq 0) -Message "${Case}: Text ist ohne vollstaendig erreichbaren Inhalt abgeschnitten: $clippedText"
}

function Assert-JobAgentExpectedFailure {
    param(
        [Parameter(Mandatory)][scriptblock]$Assertion,
        [Parameter(Mandatory)][string]$Case
    )

    $failedAsExpected = $false
    try {
        & $Assertion
    }
    catch {
        $failedAsExpected = $true
    }
    Assert-True -Condition $failedAsExpected -Message "${Case}: Die absichtlich defekte Rendererfixture wurde nicht erkannt."
}

function Get-JobAgentAccessibilityMeasurement {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string]$Case
    )

    $script = @'
() => { const s=(...codes)=>String.fromCharCode(...codes),controlTags=[s(98,117,116,116,111,110),s(105,110,112,117,116),s(115,101,108,101,99,116)],relevantTags=[s(98,111,100,121),s(104,49),s(104,50),s(104,51),s(112),s(108,97,98,101,108),s(97),...controlTags],elements=Array.from(document.getElementsByTagName(s(42))); const parse=color=>{const values=(color.match(/[\d.]+/g)||[]).map(Number);return values.length>=3?{r:values[0],g:values[1],b:values[2],a:values.length>3?values[3]:1}:null}; const background=element=>{for(let node=element;node;node=node.parentElement){const color=parse(getComputedStyle(node).backgroundColor);if(color&&color.a>=1)return color}return {r:244,g:241,b:234,a:1}}; const channel=value=>{value/=255;return value<=.04045?value/12.92:Math.pow((value+.055)/1.055,2.4)}; const ratio=(first,second)=>{const luminance=color=>.2126*channel(color.r)+.7152*channel(color.g)+.0722*channel(color.b);const a=luminance(first),b=luminance(second);return (Math.max(a,b)+.05)/(Math.min(a,b)+.05)}; const relevant=elements.filter(element=>relevantTags.includes(element.tagName.toLowerCase())).map(element=>{const style=getComputedStyle(element),foreground=parse(style.color),tag=element.tagName.toLowerCase(),focusable=controlTags.includes(tag)||tag===s(97);let focusOutline=s(110,111,116,95,102,111,99,117,115,97,98,108,101);if(focusable){element.focus();focusOutline=getComputedStyle(element).outlineWidth}return {id:element.id||tag,ratio:foreground?ratio(foreground,background(element)):0,font_size:parseFloat(style.fontSize),font_weight:Number(style.fontWeight)||400,focusable,focus_outline:focusOutline}}).filter(item=>item.ratio>0); const controls=elements.filter(element=>controlTags.includes(element.tagName.toLowerCase())).map(element=>({id:element.id,has_label:element.tagName===s(66,85,84,84,79,78)?!!String(element.getAttribute(s(97,114,105,97,45,108,97,98,101,108))||element.textContent||String()).trim():!!element.labels&&element.labels.length>0})); const tabs=elements.filter(element=>element.getAttribute(s(114,111,108,101))===s(116,97,98)).map(tab=>({id:tab.id,selected:tab.getAttribute(s(97,114,105,97,45,115,101,108,101,99,116,101,100)),controls:tab.getAttribute(s(97,114,105,97,45,99,111,110,116,114,111,108,115)),target_exists:!!document.getElementById(tab.getAttribute(s(97,114,105,97,45,99,111,110,116,114,111,108,115))||String())})); const status=document.getElementById(s(106,111,98,97,103,101,110,116,45,114,101,115,117,108,116,45,99,111,117,110,116)); return JSON.stringify({controls,tabs,status:{role:status.getAttribute(s(114,111,108,101)),live:status.getAttribute(s(97,114,105,97,45,108,105,118,101))},low_contrast:relevant.filter(item=>item.ratio<(item.font_size>=24||item.font_weight>=700&&item.font_size>=18.66?3:4.5)),focusable_without_focus_style:relevant.filter(item=>item.focusable&&item.focus_outline===s(48,112,120))}); }
'@
    return Get-JobAgentSessionValue -WorkingDirectory $WorkingDirectory -SessionName $SessionName -Script $script -Case $Case
}

function Get-JobAgentActiveElement {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string]$SessionName, [Parameter(Mandatory)][string]$Case)

    return Get-JobAgentSessionValue -WorkingDirectory $WorkingDirectory -SessionName $SessionName -Case $Case -Script '() => JSON.stringify({ id:document.activeElement.id, text:String(document.activeElement.textContent||String()), disabled:document.activeElement.disabled===true })'
}

function Get-JobAgentCurrentPaginationPage {
    param([Parameter(Mandatory)][string]$WorkingDirectory, [Parameter(Mandatory)][string]$SessionName, [Parameter(Mandatory)][string]$Case)

    return Get-JobAgentSessionValue -WorkingDirectory $WorkingDirectory -SessionName $SessionName -Case $Case -Script '() => { const s=(...codes)=>String.fromCharCode(...codes),pagination=document.getElementById(s(106,111,98,97,103,101,110,116,45,112,97,103,105,110,97,116,105,111,110)); return JSON.stringify(Array.from(pagination.getElementsByTagName(s(98,117,116,116,111,110))).filter(button=>button.getAttribute(s(97,114,105,97,45,99,117,114,114,101,110,116))===s(112,97,103,101)).map(button=>button.textContent)); }'
}

function Set-JobAgentPaginationFocus {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][int]$PageNumber,
        [Parameter(Mandatory)][string]$Case
    )

    $script = "() => { const pagination=document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,112,97,103,105,110,97,116,105,111,110)); const target=Array.from(pagination.getElementsByTagName(String.fromCharCode(98,117,116,116,111,110))).find(button=>button.textContent===String($PageNumber)); if(!target)throw new Error(String.fromCharCode(83,101,105,116,101,110,116,97,115,116,101,32,102,101,104,108,116)); target.focus(); return JSON.stringify({text:target.textContent,focused:document.activeElement===target}); }"
    $focus = Get-JobAgentSessionValue -WorkingDirectory $WorkingDirectory -SessionName $SessionName -Case $Case -Script $script
    Assert-True -Condition ([bool]$focus.focused -and $focus.text -eq [string]$PageNumber) -Message "${Case}: Die Seitentaste $PageNumber konnte nicht per Tastatur vorbereitet werden."
}

function Invoke-JobAgentPlaywrightCli {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $npxCommand = Get-Command -Name 'npx.cmd' -ErrorAction SilentlyContinue
    if ($null -eq $npxCommand) {
        throw 'npx.cmd fehlt; der Browser-Audit benoetigt die Playwright-CLI.'
    }

    $previousNpmCache = $env:NPM_CONFIG_CACHE
    $previousTimezone = $env:TZ
    $env:NPM_CONFIG_CACHE = Join-Path $root '.ci\cache\npm'
    $env:TZ = 'UTC'
    Push-Location -LiteralPath $WorkingDirectory
    try {
        $output = @(& $npxCommand.Source --no-install --package '@playwright/cli' playwright-cli @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw ('Playwright-CLI fehlgeschlagen: ' + ($output -join [Environment]::NewLine))
        }
        return ($output -join [Environment]::NewLine)
    }
    finally {
        Pop-Location
        if ($null -eq $previousNpmCache) {
            Remove-Item Env:NPM_CONFIG_CACHE -ErrorAction SilentlyContinue
        }
        else {
            $env:NPM_CONFIG_CACHE = $previousNpmCache
        }
        if ($null -eq $previousTimezone) {
            Remove-Item Env:TZ -ErrorAction SilentlyContinue
        }
        else {
            $env:TZ = $previousTimezone
        }
    }
}

function Get-JobAgentCliSnapshot {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName
    )

    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'snapshot')
    $snapshotLink = [regex]::Match($output, '\[Snapshot\]\((?<path>[^)]+)\)')
    if ($snapshotLink.Success) {
        $snapshotPath = Join-Path $WorkingDirectory $snapshotLink.Groups['path'].Value
        if (Test-Path -LiteralPath $snapshotPath -PathType Leaf) {
            return Get-Content -LiteralPath $snapshotPath -Raw
        }
    }

    return $output
}

function Get-JobAgentCliRef {
    param(
        [Parameter(Mandatory)][string]$Snapshot,
        [Parameter(Mandatory)][string[]]$Roles,
        [Parameter(Mandatory)][string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    foreach ($role in $Roles) {
        $pattern = '(?m)\b' + [regex]::Escape($role) + '\s+"' + $escapedName + '"[^\r\n]*\[ref=([A-Za-z0-9]+)\]'
        $match = [regex]::Match($Snapshot, $pattern)
        if ($match.Success) {
            return $match.Groups[1].Value
        }
    }

    $diagnostic = $Snapshot.Substring(0, [Math]::Min(1200, $Snapshot.Length))
    throw "Playwright-Snapshot enthaelt kein steuerbares Element '$Name' mit Rollen $($Roles -join ', '). Snapshot-Anfang: $diagnostic"
}

function Assert-JobAgentSnapshotContains {
    param(
        [Parameter(Mandatory)][string]$Snapshot,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Case
    )

    Assert-True -Condition $Snapshot.Contains($Expected) -Message "${Case}: erwarteter Browserinhalt fehlt: $Expected"
}

function Get-JobAgentVisibleRecordIds {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][ValidateSet('jobs', 'companies')][string]$View
    )

    $resultContainerId = if ($View -eq 'jobs') { 'jobagent-job-results' } else { 'jobagent-company-results' }
    $property = if ($View -eq 'jobs') { 'jobId' } else { 'companyId' }
    $script = "() => { const container=document.getElementById('$resultContainerId'); if(!container)throw new Error('Ergebniscontainer fehlt: $resultContainerId'); return JSON.stringify(Array.from(container.getElementsByTagName('article')).map(article => article.dataset.$property)); }"
    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', $script)
    $result = [regex]::Match($output, '(?ms)### Result\s*\r?\n(?<payload>.+?)\s*$')
    Assert-True -Condition $result.Success -Message "Playwright-CLI lieferte keine lesbare ID-Antwort fuer $View."
    $serializedIds = $result.Groups['payload'].Value.Trim() | ConvertFrom-Json -Depth 10
    return @($serializedIds | ConvertFrom-Json -Depth 10)
}

function Assert-JobAgentSetEqual {
    param(
        [Parameter(Mandatory)][string[]]$Actual,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string]$Case
    )

    $actualSorted = @($Actual | Sort-Object -Unique)
    $expectedSorted = @($Expected | Sort-Object -Unique)
    Assert-True -Condition ($actualSorted.Count -eq $expectedSorted.Count) -Message "${Case}: abweichende Anzahl sichtbarer IDs."
    Assert-True -Condition (@(Compare-Object -ReferenceObject $expectedSorted -DifferenceObject $actualSorted).Count -eq 0) -Message "${Case}: sichtbare IDs weichen von der Sollmenge ab."
}

function Assert-JobAgentLocationHash {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string]$Expected,
        [Parameter(Mandatory)][string]$Case
    )

    $output = Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', '() => window.location.hash')
    Assert-True -Condition ($output -match [regex]::Escape('"' + $Expected + '"')) -Message "${Case}: URL-Hash ist nicht normalisiert auf $Expected."
}

function Set-JobAgentLocationHash {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$SessionName,
        [Parameter(Mandatory)][string[]]$Segments
    )

    $javascriptSegments = foreach ($segment in $Segments) {
        $characterCodes = $segment.ToCharArray() | ForEach-Object { [int][char]$_ }
        'String.fromCharCode(' + ($characterCodes -join ',') + ')'
    }
    $script = '() => { window.location.hash = [' + ($javascriptSegments -join ',') + '].join(String.fromCharCode(38)); }'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $WorkingDirectory -Arguments @('--session', $SessionName, 'eval', $script) | Out-Null
}

function New-TestLocation {
    param(
        [Parameter(Mandatory)][string]$Label,
        [string]$City = 'Muenchen',
        [string]$Region = 'Bayern',
        [string]$TargetArea = 'MUNICH'
    )

    [pscustomobject]@{
        label = $Label
        city = $City
        region = $Region
        country = 'DE'
        target_area = $TargetArea
    }
}

function New-TestCompany {
    param(
        [Parameter(Mandatory)][int]$Number,
        [Parameter(Mandatory)][object]$Location
    )

    $suffix = $Number.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
    [pscustomobject]@{
        company_id = "company:fixture_$suffix"
        canonical_name = "Firma $suffix"
        canonical_domain = "firma-$suffix.example.invalid"
        official_website_url = "https://firma-$suffix.example.invalid/"
        career_url = "https://firma-$suffix.example.invalid/karriere"
        aliases = @()
        locations = @($Location)
        industry = 'UNKNOWN'
        ats = @()
        scan_status = 'SUCCESS'
        scan_priority = 50
        next_scan_at = '2026-09-16T10:00:00.000Z'
        verification_status = 'CAREER_URL_VERIFIED'
        discovery_source = $null
        created_at = '2026-09-01T09:00:00.000Z'
        updated_at = '2026-09-01T09:00:00.000Z'
        last_successful_scan_at = '2026-09-01T09:00:00.000Z'
    }
}

function New-TestJob {
    param(
        [Parameter(Mandatory)][string]$JobId,
        [Parameter(Mandatory)][string]$CompanyId,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][object]$Location,
        [string]$Category = 'Allgemein',
        [string]$WorkModel = 'ONSITE',
        [string]$EmploymentType = 'FULL_TIME',
        [string]$WorkTime = 'UNKNOWN',
        [string]$PublishedAt = '2026-09-14T10:00:00.000Z',
        [string]$FirstSeen = '2026-09-14T10:00:00.000Z'
    )

    [pscustomobject]@{
        job_id = $JobId
        company_id = $CompanyId
        official_url = 'https://jobs.example.invalid/' + $JobId.Replace(':', '/')
        alternative_official_urls = @()
        source_id = 'UNKNOWN'
        external_job_id = $JobId
        ats_job_id = 'UNKNOWN'
        title = $Title
        job_category = $Category
        location = $Location
        work_model = $WorkModel
        employment_type = $EmploymentType
        work_time = $WorkTime
        status = 'ACTIVE'
        published_at = $PublishedAt
        first_seen = $FirstSeen
        last_seen = '2026-09-15T10:00:00.000Z'
        changed_at = '2026-09-15T10:00:00.000Z'
        classification = [pscustomobject]@{
            result = 'REJECTED'
            priority = 'D'
            score = 90
            category = $Category
            reasons = @('Fixture fuer den lokalen Browser-Audit.')
            rejected_reasons = @()
            evaluated_at = '2026-09-15T10:00:00.000Z'
        }
        priority = 'D'
        requirements = @()
        salary = 'UNKNOWN'
        identity_basis = 'OFFICIAL_JOB_ID'
    }
}

$scanRunId = 'scanrun:ui001-browser-audit'
$uiContractPath = Join-Path $root 'tests\fixtures\jobagent\qa-004-ui-contract.json'
Assert-True -Condition (Test-Path -LiteralPath $uiContractPath -PathType Leaf) -Message 'QA-004-UI-Vertragsfixture fehlt.'
$uiContract = Get-Content -LiteralPath $uiContractPath -Raw | ConvertFrom-Json -Depth 20
Assert-True -Condition ($uiContract.schema_version -eq 'jobagent-ui-contract/v1') -Message 'QA-004-UI-Vertragsfixture hat eine ungueltige Schema-Version.'
$visualContractPath = Join-Path $root 'tests\fixtures\jobagent\QA-005-visual-contract.json'
Assert-True -Condition (Test-Path -LiteralPath $visualContractPath -PathType Leaf) -Message 'QA-005-Visual-Vertragsfixture fehlt.'
$visualContract = Get-Content -LiteralPath $visualContractPath -Raw | ConvertFrom-Json -Depth 20
Assert-True -Condition ($visualContract.schema_version -eq 'jobagent-visual-contract/v1') -Message 'QA-005-Visual-Vertragsfixture hat eine ungueltige Schema-Version.'
Assert-True -Condition (@($visualContract.viewports).Count -eq 4) -Message 'QA-005-Visual-Vertragsfixture muss vier Pflichtviewports enthalten.'
Assert-True -Condition ([double]$visualContract.desktop_zoom.css_zoom -eq 2) -Message 'QA-005-Visual-Vertragsfixture muss einen 200-%-Desktopzoom festlegen.'
$referenceTime = [datetime]$uiContract.reference_time
$munich = New-TestLocation -Label 'Muenchen'
$freising = New-TestLocation -Label 'Freising' -City 'Freising' -Region 'Landkreis Freising' -TargetArea 'FREISING'
$unknown = New-TestLocation -Label 'UNKNOWN' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'UNKNOWN'
$munich20Km = New-TestLocation -Label 'Dachau bei Muenchen' -City 'Dachau' -Region 'Bayern' -TargetArea 'MUNICH_20KM'
$freisingCounty = New-TestLocation -Label 'Moosburg' -City 'Moosburg' -Region 'Landkreis Freising' -TargetArea 'FREISING'
$freisingUnspecified = New-TestLocation -Label 'Freising Gebiet' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'FREISING'
$remoteTarget = New-TestLocation -Label 'Remote mit Muenchenbezug' -City 'UNKNOWN' -Region 'UNKNOWN' -TargetArea 'REMOTE_WITH_TARGET_REFERENCE'
$document = New-JobAgentEmptyDocument -GeneratedAt ([datetime]'2026-09-15T10:00:00Z')
$document.companies = @(1..251 | ForEach-Object { New-TestCompany -Number $_ -Location $munich })
$document.jobs = @(1..251 | ForEach-Object {
        $suffix = $_.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
        $companyNumber = if ($_ -eq 251) { 250 } else { $_ }
        $companySuffix = $companyNumber.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
        New-TestJob -JobId "job:company_$suffix" -CompanyId "company:fixture_$companySuffix" -Title "Position $suffix" -Location $munich
    })
$document.jobs += @(
    New-TestJob -JobId 'job:munich-accounting' -CompanyId 'company:fixture_001' -Title 'Buchhalterin Muenchen' -Location $munich -Category 'Buchhaltung'
    New-TestJob -JobId 'job:freising-pflege' -CompanyId 'company:fixture_002' -Title 'Pflegefachkraft Freising' -Location $freising -Category 'Pflege' -WorkModel 'HYBRID' -EmploymentType 'PART_TIME'
    New-TestJob -JobId 'job:part-time-hybrid' -CompanyId 'company:fixture_003' -Title 'Hybrid Teilzeit Beraterin' -Location $munich -Category 'Beratung' -WorkModel 'HYBRID' -EmploymentType 'PART_TIME'
    New-TestJob -JobId 'job:unknown' -CompanyId 'company:fixture_004' -Title 'Unklare Position <img src=x onerror=window.__qa004Injected=true>' -Location $unknown -Category 'UNKNOWN' -WorkModel 'UNKNOWN' -EmploymentType 'UNKNOWN'
    New-TestJob -JobId 'job:umlaut' -CompanyId 'company:fixture_005' -Title 'Bürokauffrau Muenchen' -Location $munich -Category 'Büro'
    New-TestJob -JobId 'job:remote-contract' -CompanyId 'company:fixture_006' -Title 'Remote Vertrag Spezialistin' -Location $remoteTarget -Category 'Beratung' -WorkModel 'REMOTE' -EmploymentType 'CONTRACT'
    New-TestJob -JobId 'job:munich20-permanent' -CompanyId 'company:fixture_007' -Title 'Dachau Unbefristet' -Location $munich20Km -Category 'Verwaltung' -EmploymentType 'PERMANENT'
    New-TestJob -JobId 'job:freising-county-internship' -CompanyId 'company:fixture_008' -Title 'Moosburg Praktikum' -Location $freisingCounty -Category 'Ausbildung' -EmploymentType 'INTERNSHIP'
    New-TestJob -JobId 'job:freising-unspecified' -CompanyId 'company:fixture_009' -Title 'Freising Gebiet Stelle' -Location $freisingUnspecified -Category 'Allgemein'
    New-TestJob -JobId 'job:age-seven' -CompanyId 'company:fixture_010' -Title 'Grenze Sieben Tage' -Location $munich -PublishedAt '2026-09-08T10:00:00.000Z'
    New-TestJob -JobId 'job:age-thirty' -CompanyId 'company:fixture_011' -Title 'Grenze Dreissig Tage' -Location $munich -PublishedAt '2026-08-16T10:00:00.000Z'
    New-TestJob -JobId 'job:age-older' -CompanyId 'company:fixture_012' -Title 'Aelter Als Dreissig Tage' -Location $munich -PublishedAt '2026-08-15T10:00:00.000Z'
    New-TestJob -JobId 'job:age-unknown' -CompanyId 'company:fixture_013' -Title 'Datum Unbekannt' -Location $munich -PublishedAt 'UNKNOWN' -FirstSeen 'UNKNOWN'
)
$longContentJob = @($document.jobs | Where-Object { $_.job_id -eq 'job:company_001' })[0]
$longContentJob.title = 'Leitung Digitalisierung mit einem absichtlich sehr langen ungetrennten Layoutpruefwort ' + ('Verantwortungsbereich' * 12)
$document.job_sources = @()
$document.scan_runs = @([pscustomobject]@{
        scan_run_id = $scanRunId
        started_at = '2026-09-15T10:00:00.000Z'
        finished_at = '2026-09-15T10:00:00.000Z'
        status = 'SUCCESS'
        company_ids = @($document.companies.company_id)
        artifact_paths = @()
        errors = @()
    })
$document.scan_attempts = @()
$document.job_snapshots = @()
$document.change_events = @()

$documentBefore = ConvertTo-JobAgentFixtureJson -Document $document
$report = New-JobAgentDailyReport -Document $document -ScanRunId $scanRunId
$expectedJobIds = @('job:company_251', 'job:munich-accounting', 'job:freising-pflege', 'job:part-time-hybrid', 'job:unknown', 'job:umlaut', 'job:remote-contract', 'job:munich20-permanent', 'job:freising-county-internship', 'job:freising-unspecified', 'job:age-seven', 'job:age-thirty', 'job:age-older', 'job:age-unknown')
$actualJobIds = @($report.sections.active_jobs.job_id)
foreach ($expectedJobId in $expectedJobIds) {
    Assert-True -Condition ($actualJobIds -contains $expectedJobId) -Message "Fixture-Report enthaelt erwartete Stellen-ID nicht: $expectedJobId"
}
Assert-True -Condition ($report.sections.companies.Count -eq 251) -Message 'Fixture-Report muss 251 Firmen enthalten.'
Assert-True -Condition ($report.sections.active_jobs.Count -eq 264) -Message 'Fixture-Report muss 264 aktive Stellen enthalten.'

$actualAreaValues = @($report.sections.active_jobs | ForEach-Object { @($_.area_facets) } | Select-Object -Unique)
foreach ($expectedAreaValue in @($uiContract.area_values)) {
    Assert-True -Condition ($actualAreaValues -contains $expectedAreaValue) -Message "Gebietsfixture fuer $expectedAreaValue fehlt."
}
foreach ($facet in @(
        @{ property = 'work_model'; values = @($uiContract.work_model_values) },
        @{ property = 'employment_type'; values = @($uiContract.employment_type_values) },
        @{ property = 'work_time'; values = @($uiContract.work_time_values) }
    )) {
    $actualValues = @($report.sections.active_jobs | ForEach-Object { [string]$_.$($facet.property) } | Select-Object -Unique)
    foreach ($expectedValue in $facet.values) {
        Assert-True -Condition ($actualValues -contains $expectedValue) -Message "Facetfixture $($facet.property) fuer $expectedValue fehlt."
    }
}
$jobsById = @{}
foreach ($job in @($report.sections.active_jobs)) { $jobsById[[string]$job.job_id] = $job }
foreach ($ageExpectation in @(
        @{ job_id = 'job:age-seven'; age_days = '7' },
        @{ job_id = 'job:age-thirty'; age_days = '30' },
        @{ job_id = 'job:age-older'; age_days = '31' },
        @{ job_id = 'job:age-unknown'; age_days = 'UNKNOWN' }
    )) {
    Assert-True -Condition ([string]$jobsById[$ageExpectation.job_id].age_days -eq $ageExpectation.age_days) -Message "Alters-Grenzfixture $($ageExpectation.job_id) hat keinen stabilen Wert $($ageExpectation.age_days)."
}

foreach ($boundaryCount in @($uiContract.boundary_counts)) {
    $boundaryDocument = New-JobAgentEmptyDocument -GeneratedAt $referenceTime
    $boundaryDocument.scan_runs = @([pscustomobject]@{
            scan_run_id = 'scanrun:boundary'
            started_at = $uiContract.reference_time
            finished_at = $uiContract.reference_time
            status = 'SUCCESS'
            company_ids = @()
            artifact_paths = @()
            errors = @()
        })
    if ([int]$boundaryCount -eq 0) {
        $boundaryDocument.companies = @()
        $boundaryDocument.jobs = @()
    }
    else {
        $boundaryDocument.companies = @(1..[int]$boundaryCount | ForEach-Object { New-TestCompany -Number $_ -Location $munich })
        $boundaryDocument.jobs = @(1..[int]$boundaryCount | ForEach-Object {
                $suffix = $_.ToString('000', [Globalization.CultureInfo]::InvariantCulture)
                New-TestJob -JobId "job:boundary_$suffix" -CompanyId "company:fixture_$suffix" -Title "Grenzposition $suffix" -Location $munich
            })
    }
    $expectedPages = [Math]::Max(1, [Math]::Ceiling([int]$boundaryCount / 50.0))
    Assert-True -Condition (@($boundaryDocument.companies).Count -eq [int]$boundaryCount) -Message "Firmen-Grenzfixture $boundaryCount ist nicht stabil."
    Assert-True -Condition (@($boundaryDocument.jobs).Count -eq [int]$boundaryCount) -Message "Stellen-Grenzfixture $boundaryCount ist nicht stabil."
    Assert-True -Condition ($expectedPages -eq [Math]::Max(1, [Math]::Ceiling(@($boundaryDocument.jobs).Count / 50.0))) -Message "Seitengrenzfixture $boundaryCount ist nicht stabil."
}

if ($FixtureOnly) {
    [pscustomobject]@{
        status = 'ok'
        mode = 'isolated_fixture_only'
        companies = 251
        jobs = 264
        boundary_counts = @($uiContract.boundary_counts)
        cases = @('qa004_boundary_fixtures_0_1_49_50_51_250_251', 'qa004_all_offered_facet_values_and_age_boundaries')
    } | ConvertTo-Json -Depth 10
    return
}

$runId = 'qa004-' + [guid]::NewGuid().ToString('N')
$evidenceRoot = Join-Path $root (Join-Path 'logs\jobagent\QA-004' $runId)
$htmlPath = Join-Path $evidenceRoot 'daily-report.html'
$artifactRoot = Join-Path $evidenceRoot 'playwright'
$evidencePath = Join-Path $evidenceRoot 'browser-cases.json'
$reportUrl = 'http://127.0.0.1:8500/logs/jobagent/QA-004/' + $runId + '/daily-report.html'
Write-Utf8File -Path $htmlPath -Content (ConvertTo-JobAgentDailyReportHtml -Report $report)
$reportHashBefore = Get-JobAgentSha256 -Path $htmlPath
$fixtureHashBefore = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($documentBefore))).ToLowerInvariant()

$response = Invoke-WebRequest -UseBasicParsing -Uri $reportUrl -TimeoutSec 10
Assert-True -Condition ($response.StatusCode -eq 200) -Message 'Browser-Audit-Report ist nicht über den CI-Devserver erreichbar.'

if (-not (Test-Path -LiteralPath $artifactRoot)) {
    New-Item -ItemType Directory -Path $artifactRoot -Force | Out-Null
}

$browserConfigPath = Join-Path $artifactRoot 'playwright-cli.config.json'
Write-Utf8File -Path $browserConfigPath -Content (@{
        browser = @{
            contextOptions = @{
                locale = 'de-DE'
                timezoneId = 'UTC'
            }
        }
    } | ConvertTo-Json -Depth 10)

$sessionName = 'jobagent-ui001-' + [guid]::NewGuid().ToString('N')
$screenshots = [System.Collections.Generic.List[string]]::new()
$caseEvidence = [System.Collections.Generic.List[object]]::new()
$sessionErrors = @()
$network = ''
$environmentalExternalHosts = @()
$unexpectedExternalHosts = @()
$geometryEvidence = [System.Collections.Generic.List[object]]::new()
try {
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, '--config', $browserConfigPath, 'open', $reportUrl) | Out-Null
    $browserReady = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Browser-Render-Voraussetzungen' -Script 'async () => { for(const animation of document.getAnimations()){animation.cancel()}; if(document.fonts&&document.fonts.ready){await document.fonts.ready}; return JSON.stringify({locale:navigator.language,timezone:Intl.DateTimeFormat().resolvedOptions().timeZone,fonts_ready:!document.fonts||document.fonts.status.length===6}); }'
    Assert-True -Condition ([string]$browserReady.locale -eq 'de-DE') -Message 'Browser-Audit verwendet nicht das erwartete Locale de-DE.'
    Assert-True -Condition ([string]$browserReady.timezone -eq 'UTC') -Message 'Browser-Audit verwendet nicht die erwartete Zeitzone UTC.'
    Assert-True -Condition ([bool]$browserReady.fonts_ready) -Message 'Browser-Schriften sind vor der Geometriemessung nicht geladen.'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { window.__qa004Errors=[]; const errorEvent=String.fromCharCode(101,114,114,111,114),rejectionEvent=String.fromCharCode(117,110,104,97,110,100,108,101,100,114,101,106,101,99,116,105,111,110),fallback=String.fromCharCode(101,114,114,111,114); window.addEventListener(errorEvent,event=>window.__qa004Errors.push(String(event.message||event.error||fallback))); window.addEventListener(rejectionEvent,event=>window.__qa004Errors.push(String(event.reason||rejectionEvent))); return JSON.stringify({ready:true}); }') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'vollstaendiger Stellenbestand'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Leitung Digitalisierung mit einem absichtlich sehr langen ungetrennten Layoutpruefwort' -Case 'Langer Titel bleibt erreichbar'
    $accessibility = Get-JobAgentAccessibilityMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Semantik, Kontrast und Fokus'
    Assert-True -Condition (@($accessibility.controls | Where-Object { -not $_.has_label }).Count -eq 0) -Message 'Mindestens ein Filter- oder Button-Control hat keine Labelzuordnung.'
    Assert-True -Condition (@($accessibility.tabs).Count -eq 2) -Message 'Die Tabansicht muss genau zwei semantische Tabs enthalten.'
    Assert-True -Condition (@($accessibility.tabs | Where-Object { $_.selected -eq 'true' -and $_.target_exists }).Count -eq 1) -Message 'Die aktive Tabansicht ist nicht eindeutig mit ihrem Panel verbunden.'
    Assert-True -Condition ($accessibility.status.role -eq 'status' -and $accessibility.status.live -eq 'polite') -Message 'Der Trefferstatus hat keine passende Live-Region.'
    Assert-True -Condition (@($accessibility.low_contrast).Count -eq 0) -Message 'Mindestens ein relevanter Text oder ein Control unterschreitet den Kontrastvertrag.'
    Assert-True -Condition (@($accessibility.focusable_without_focus_style).Count -eq 0) -Message 'Mindestens ein bedienbares Element hat keinen sichtbaren Fokusstil.'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'semantic_labels_tabs_live_status_and_calculated_contrast'; measurement = $accessibility })

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,113,117,101,114,121)).focus(); return JSON.stringify({focused:document.activeElement.id}); }') | Out-Null
    foreach ($keyboardStep in @(
            @{ key = 'Tab'; expected = 'jobagent-area' },
            @{ key = 'Tab'; expected = 'jobagent-work-model' },
            @{ key = 'Tab'; expected = 'jobagent-employment-type' },
            @{ key = 'Tab'; expected = 'jobagent-work-time' },
            @{ key = 'Tab'; expected = 'jobagent-age' },
            @{ key = 'Tab'; expected = 'jobagent-reset' }
        )) {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', $keyboardStep.key) | Out-Null
        $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Tastaturreise durch Filter'
        Assert-True -Condition ($activeElement.id -eq $keyboardStep.expected) -Message "Tastaturreise: erwarteter Fokus '$($keyboardStep.expected)', erhalten '$($activeElement.id)'."
        $focusStyle = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'sichtbarer Tastaturfokus durch Filter' -Script '() => JSON.stringify({ outline:getComputedStyle(document.activeElement).outlineWidth })'
        Assert-True -Condition ($focusStyle.outline -ne '0px') -Message "Tastaturreise: $($keyboardStep.expected) hat keinen sichtbaren Fokusstil."
    }
    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Unklare Position') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Tastaturreset nach aktivem Filter'
    Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Tastaturreset vorbereiten' -Script '() => { const reset=document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,114,101,115,101,116)); reset.focus(); return JSON.stringify({focused:document.activeElement===reset}); }' | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'Enter') | Out-Null
    $resetFocusReady = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Fokus nach Tastaturreset' -Script 'async () => { await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))); return JSON.stringify({ready:true}); }'
    Assert-True -Condition ([bool]$resetFocusReady.ready) -Message 'Tastaturreset: Der Fokusnachlauf wurde nicht abgeschlossen.'
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Tastaturreset nach aktivem Filter'
    $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Fokus nach Tastaturreset'
    Assert-True -Condition ($activeElement.id -eq 'jobagent-reset') -Message 'Tastaturreset: Der Fokus bleibt nicht auf der Reset-Taste.'
    $focusStyle = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'sichtbarer Tastaturfokus nach Reset' -Script '() => JSON.stringify({ outline:getComputedStyle(document.activeElement).outlineWidth })'
    Assert-True -Condition ($focusStyle.outline -ne '0px') -Message 'Tastaturreset: Die Reset-Taste hat keinen sichtbaren Fokusstil.'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,116,97,98,45,106,111,98,115)).focus(); return JSON.stringify({focused:document.activeElement.id}); }') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'ArrowRight') | Out-Null
    $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Tabreise nach rechts'
    Assert-True -Condition ($activeElement.id -eq 'jobagent-tab-companies') -Message 'ArrowRight setzt den Fokus nicht auf den naechsten Tab.'
    $focusStyle = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'sichtbarer Tastaturfokus nach rechts' -Script '() => JSON.stringify({ outline:getComputedStyle(document.activeElement).outlineWidth })'
    Assert-True -Condition ($focusStyle.outline -ne '0px') -Message 'ArrowRight setzt keinen sichtbaren Fokusstil auf den Zieltab.'
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 251 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Tabreise nach rechts'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'ArrowLeft') | Out-Null
    $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Tabreise nach links'
    Assert-True -Condition ($activeElement.id -eq 'jobagent-tab-jobs') -Message 'ArrowLeft setzt den Fokus nicht auf den vorherigen Tab.'
    $focusStyle = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'sichtbarer Tastaturfokus nach links' -Script '() => JSON.stringify({ outline:getComputedStyle(document.activeElement).outlineWidth })'
    Assert-True -Condition ($focusStyle.outline -ne '0px') -Message 'ArrowLeft setzt keinen sichtbaren Fokusstil auf den Zieltab.'
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Tabreise nach links'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'keyboard_filter_reset_and_tab_journey'; filter_focus_order = @('jobagent-query', 'jobagent-area', 'jobagent-work-model', 'jobagent-employment-type', 'jobagent-work-time', 'jobagent-age', 'jobagent-reset'); reset_focus = 'jobagent-reset'; tab_keys = @('ArrowRight', 'ArrowLeft') })
    foreach ($viewport in @($visualContract.viewports)) {
        $measurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Initialansicht' -ViewportWidth ([int]$viewport.width) -ViewportHeight ([int]$viewport.height)
        Assert-JobAgentGeometryMeasurement -Measurement $measurement -VisualContract $visualContract -Case "Initialansicht $($viewport.width)x$($viewport.height)"
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'initial_jobs'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'long_content'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
    }
    $desktopZoom = $visualContract.desktop_zoom
    $zoomMeasurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Initialansicht 200-Prozent-Zoom' -ViewportWidth ([int]$desktopZoom.viewport_width) -ViewportHeight ([int]$desktopZoom.viewport_height) -CssZoom ([double]$desktopZoom.css_zoom)
    Assert-JobAgentGeometryMeasurement -Measurement $zoomMeasurement -VisualContract $visualContract -Case 'Initialansicht 200-Prozent-Zoom'
    $geometryEvidence.Add([pscustomobject]@{ case_id = 'initial_jobs_200_percent_zoom'; viewport_width = [int]$desktopZoom.viewport_width; viewport_height = [int]$desktopZoom.viewport_height; measurement = $zoomMeasurement })

    $negativeFixtureSetup = @'
() => { const s=(...codes)=>String.fromCharCode(...codes),root=document.createElement(s(100,105,118)),small=document.createElement(s(98,117,116,116,111,110)),first=document.createElement(s(98,117,116,116,111,110)),second=document.createElement(s(98,117,116,116,111,110)),clipped=document.createElement(s(112)),reset=document.getElementById(s(106,111,98,97,103,101,110,116,45,114,101,115,101,116)); root.id=s(106,111,98,97,103,101,110,116,45,113,97,48,48,53,45,110,101,103,97,116,105,118,101); small.id=s(106,111,98,97,103,101,110,116,45,113,97,48,48,53,45,115,109,97,108,108); small.textContent=s(120); [s(119,105,100,116,104),s(104,101,105,103,104,116),s(109,105,110,45,119,105,100,116,104),s(109,105,110,45,104,101,105,103,104,116)].forEach(property=>small.style.setProperty(property,s(49,112,120),s(105,109,112,111,114,116,97,110,116))); small.style.setProperty(s(111,117,116,108,105,110,101),s(110,111,110,101),s(105,109,112,111,114,116,97,110,116)); small.style.setProperty(s(111,117,116,108,105,110,101,45,119,105,100,116,104),s(48,112,120),s(105,109,112,111,114,116,97,110,116)); small.style.setProperty(s(111,117,116,108,105,110,101,45,115,116,121,108,101),s(110,111,110,101),s(105,109,112,111,114,116,97,110,116)); small.style.setProperty(s(99,111,108,111,114),s(114,103,98,40,48,44,48,44,48,41)); small.style.setProperty(s(98,97,99,107,103,114,111,117,110,100,45,99,111,108,111,114),s(114,103,98,40,50,53,53,44,50,53,53,44,50,53,53,41)); first.textContent=s(49); second.textContent=s(50); [first,second].forEach(button=>{button.style.position=s(97,98,115,111,108,117,116,101);button.style.left=s(48,112,120);button.style.top=s(48,112,120);button.style.width=s(52,52,112,120);button.style.height=s(52,52,112,120);button.style.minWidth=s(52,52,112,120);button.style.minHeight=s(52,52,112,120)}); clipped.textContent=s(97,98,115,105,99,104,116,108,105,99,104,45,97,98,103,101,115,99,104,110,105,116,116,101,110); clipped.style.width=s(52,112,120); clipped.style.overflow=s(104,105,100,100,101,110); clipped.style.whiteSpace=s(110,111,119,114,97,112); root.append(small,first,second,clipped); document.body.append(root); reset.style.setProperty(s(111,117,116,108,105,110,101),s(110,111,110,101),s(105,109,112,111,114,116,97,110,116)); return JSON.stringify({ready:true}); }
'@
    Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Negative Rendererfixture vorbereiten' -Script $negativeFixtureSetup | Out-Null
    try {
        $negativeGeometry = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Negative Rendererfixture Geometrie' -ViewportWidth 1366 -ViewportHeight 768
        Assert-JobAgentExpectedFailure -Case 'Negative Rendererfixture: zu kleines Control' -Assertion { Assert-True -Condition (@($negativeGeometry.invalid_controls).Count -eq 0) -Message 'Zu kleines Control erkannt.' }
        Assert-JobAgentExpectedFailure -Case 'Negative Rendererfixture: Control-Overlap' -Assertion { Assert-True -Condition (@($negativeGeometry.overlaps).Count -eq 0) -Message 'Control-Overlap erkannt.' }
        Assert-JobAgentExpectedFailure -Case 'Negative Rendererfixture: Text-Clipping' -Assertion { Assert-True -Condition (@($negativeGeometry.clipped_text).Count -eq 0) -Message 'Text-Clipping erkannt.' }
        $negativeAccessibility = Get-JobAgentAccessibilityMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Negative Rendererfixture Fokus'
        Assert-JobAgentExpectedFailure -Case 'Negative Rendererfixture: unsichtbarer Fokus' -Assertion { Assert-True -Condition (@($negativeAccessibility.focusable_without_focus_style).Count -eq 0) -Message 'Unsichtbarer Fokus erkannt.' }
        $caseEvidence.Add([pscustomobject]@{ case_id = 'negative_renderer_fixture_detects_small_control_overlap_clipping_and_invisible_focus'; detected = @('small_control', 'overlap', 'clipping', 'invisible_focus') })
    }
    finally {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { const s=(...codes)=>String.fromCharCode(...codes),fixture=document.getElementById(s(106,111,98,97,103,101,110,116,45,113,97,48,48,53,45,110,101,103,97,116,105,118,101)),reset=document.getElementById(s(106,111,98,97,103,101,110,116,45,114,101,115,101,116)); if(fixture)fixture.remove(); reset.style.outline=s(32); return JSON.stringify({clean:true}); }') | Out-Null
    }

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('view=companies', 'page=999', 'q=Firma%20251')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Firmenhash mit uebergrosser Seitennummer'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firma 251' -Case 'Firma ohne offene Stelle'
    Assert-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Expected '#view=companies&q=Firma+251' -Case 'Firmenhash mit uebergrosser Seitennummer'
    foreach ($viewport in @($visualContract.viewports)) {
        $measurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Firma ohne Stelle' -ViewportWidth ([int]$viewport.width) -ViewportHeight ([int]$viewport.height)
        Assert-JobAgentGeometryMeasurement -Measurement $measurement -VisualContract $visualContract -Case "Firma ohne Stelle $($viewport.width)x$($viewport.height)"
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'company_without_open_jobs'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
    }
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'reload') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Reload eines normalisierten Firmenhashes'

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'goto', $reportUrl) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName

    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Position 251') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Freitext und Firma hinter der Altgrenze'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Position 251' -Case 'Stelle hinter der Altgrenze'

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'go-back') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Ruecknavigation'

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'go-forward') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Vorwaertsnavigation'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Position 251' -Case 'Vorwaertsnavigation'

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'go-back') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Ruecknavigation nach Vorwaertsnavigation'

    $areaRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Gebiet'
    $workModelRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Arbeitsmodell'
    $employmentTypeRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Anstellungsart'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $areaRef, 'FREISING_CITY') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $workModelRef, 'HYBRID') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $employmentTypeRef, 'PART_TIME') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Freising Pflege Teilzeit Hybrid'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Pflegefachkraft Freising' -Case 'Freising Pflege Teilzeit Hybrid'
    foreach ($viewport in @($visualContract.viewports)) {
        $measurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Komplexer Filter' -ViewportWidth ([int]$viewport.width) -ViewportHeight ([int]$viewport.height)
        Assert-JobAgentGeometryMeasurement -Measurement $measurement -VisualContract $visualContract -Case "Komplexer Filter $($viewport.width)x$($viewport.height)"
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'complex_filter'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
    }

    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'eval', '() => { const reset=document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,114,101,115,101,116)); reset.focus(); return JSON.stringify({focused:document.activeElement===reset}); }') | Out-Null
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'Space') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Filter-Reset'
    $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Fokus nach Filter-Reset'
    Assert-True -Condition ($activeElement.id -eq 'jobagent-reset') -Message 'Der Fokus bleibt nach dem Filter-Reset nicht auf dem ausloesenden Control.'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'reset_retains_keyboard_focus'; focused_control = $activeElement.id })

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('view=jobs', 'workModel=REMOTE,HYBRID', 'employmentType=PART_TIME')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 2 Treffer, Seite 1 von 1 (sichtbar 2).' -Case 'Mehrfachauswahl im selben Feld als ODER'
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) -Expected @('job:freising-pflege', 'job:part-time-hybrid') -Case 'Mehrfachauswahl im selben Feld als ODER und felduebergreifendes UND'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'multi_select_or_and'; url_hash = '#view=jobs&workModel=REMOTE%2CHYBRID&employmentType=PART_TIME'; expected_job_ids = @('job:freising-pflege', 'job:part-time-hybrid') })

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('view=jobs', 'q=Bu%25CC%2588rokauffrau%2520Muenchen')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Mehrfach URL-codierte NFC-NFD-Freitextsuche'
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) -Expected @('job:umlaut') -Case 'Mehrfach URL-codierte NFC-NFD-Freitextsuche'
    Assert-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Expected '#view=jobs&q=Bu%CC%88rokauffrau+Muenchen' -Case 'Mehrfach URL-codierte NFC-NFD-Freitextsuche'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'double_encoded_nfd_query'; url_hash = '#view=jobs&q=Bu%CC%88rokauffrau+Muenchen'; expected_job_ids = @('job:umlaut') })

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, '  BÜROKAUFFRAU !!! MUENCHEN  ') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) -Expected @('job:umlaut') -Case 'Freitext Gross-Kleinschreibung Leerzeichen Sonderzeichen und mehrere Begriffe'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'normalized_multi_token_query'; expected_job_ids = @('job:umlaut') })

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName

    foreach ($facetCase in @(
            @{ control = 'Gebiet'; value = 'MUNICH'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Gebiet'; value = 'MUNICH_20KM'; expected = 'Dachau Unbefristet' },
            @{ control = 'Gebiet'; value = 'FREISING_CITY'; expected = 'Pflegefachkraft Freising' },
            @{ control = 'Gebiet'; value = 'FREISING_COUNTY'; expected = 'Moosburg Praktikum' },
            @{ control = 'Gebiet'; value = 'FREISING_UNSPECIFIED'; expected = 'Freising Gebiet Stelle' },
            @{ control = 'Gebiet'; value = 'REMOTE_WITH_TARGET_REFERENCE'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Gebiet'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Arbeitsmodell'; value = 'REMOTE'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Arbeitsmodell'; value = 'HYBRID'; expected = 'Hybrid Teilzeit Beraterin' },
            @{ control = 'Arbeitsmodell'; value = 'ONSITE'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Arbeitsmodell'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Anstellungsart'; value = 'FULL_TIME'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Anstellungsart'; value = 'PART_TIME'; expected = 'Hybrid Teilzeit Beraterin' },
            @{ control = 'Anstellungsart'; value = 'CONTRACT'; expected = 'Remote Vertrag Spezialistin' },
            @{ control = 'Anstellungsart'; value = 'PERMANENT'; expected = 'Dachau Unbefristet' },
            @{ control = 'Anstellungsart'; value = 'INTERNSHIP'; expected = 'Moosburg Praktikum' },
            @{ control = 'Anstellungsart'; value = 'UNKNOWN'; expected = 'Unklare Position' },
            @{ control = 'Arbeitszeit'; value = 'UNKNOWN'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Aktualitaet'; value = '7'; expected = 'Grenze Sieben Tage' },
            @{ control = 'Aktualitaet'; value = '30'; expected = 'Grenze Dreissig Tage' },
            @{ control = 'Aktualitaet'; value = 'older'; expected = 'Aelter Als Dreissig Tage' },
            @{ control = 'Aktualitaet'; value = 'UNKNOWN'; expected = 'Datum Unbekannt' }
        )) {
        $controlRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name $facetCase.control
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $controlRef, $facetCase.value) | Out-Null
        $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected $facetCase.expected -Case ("Facet $($facetCase.control)=$($facetCase.value)")

        $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
        $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 264 Treffer, Seite 1 von 6 (sichtbar 50).' -Case ("Reset nach Facet $($facetCase.control)=$($facetCase.value)")
    }

    $workModelRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('listbox', 'combobox') -Name 'Arbeitsmodell'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'select', $workModelRef, 'UNKNOWN') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Unklare Position' -Case 'UNKNOWN-Auswahl'
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'UNKNOWN-Auswahl'

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Burokauffrau') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Unicode-normalisierte Umlautsuche'
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) -Expected @('job:umlaut') -Case 'Unicode-normalisierte Umlautsuche'

    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'Unklare Position') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) -Expected @('job:unknown') -Case 'HTML-Script-Fragment bleibt Textinhalt'
    $injectionState = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script '() => { const root=document.getElementById(String.fromCharCode(106,111,98,97,103,101,110,116,45,106,111,98,45,114,101,115,117,108,116,115)); return JSON.stringify({ injected: window.__qa004Injected === true, images:root?root.getElementsByTagName(String.fromCharCode(105,109,103)).length:0 }); }' -Case 'HTML-Script-Fragment bleibt Textinhalt'
    Assert-True -Condition (-not [bool]$injectionState.injected) -Message 'HTML-Script-Fragment wurde im Browser ausgefuehrt.'
    Assert-True -Condition ([int]$injectionState.images -eq 0) -Message 'HTML-Script-Fragment wurde als HTML-Element gerendert.'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'script_fragment_is_inert'; expected_job_ids = @('job:unknown'); injected = [bool]$injectionState.injected; rendered_images = [int]$injectionState.images })

    $queryRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('searchbox', 'textbox') -Name 'Freitext'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'fill', $queryRef, 'keine-passende-stelle') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Keine Treffer im angezeigten Bestand.' -Case 'Nulltreffer'
    foreach ($viewport in @($visualContract.viewports)) {
        $measurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Nulltreffer' -ViewportWidth ([int]$viewport.width) -ViewportHeight ([int]$viewport.height)
        Assert-JobAgentGeometryMeasurement -Measurement $measurement -VisualContract $visualContract -Case "Nulltreffer $($viewport.width)x$($viewport.height)"
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'empty_results'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
    }

    $companiesTabRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('tab', 'button') -Name 'Firmen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $companiesTabRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 251 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'vollstaendiger Firmenbestand'

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('view=companies', 'page=999', 'q=Firma%20251', 'area=UNKNOWN')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 1 Treffer, Seite 1 von 1 (sichtbar 1).' -Case 'Firmenfreitext ohne nicht vorhandene Arbeitgeberfacette'
    Assert-JobAgentSetEqual -Actual @(Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View companies) -Expected @('company:fixture_251') -Case 'Firmenfreitext ohne nicht vorhandene Arbeitgeberfacette'
    Assert-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Expected '#view=companies&q=Firma+251&area=UNKNOWN' -Case 'Firmenfreitext ohne nicht vorhandene Arbeitgeberfacette'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'companies_free_text_only_no_employer_facet'; url_hash = '#view=companies&q=Firma+251&area=UNKNOWN'; expected_company_ids = @('company:fixture_251') })

    $resetRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('button') -Name 'Filter zuruecksetzen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $resetRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName

    $jobsTabRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('tab', 'button') -Name 'Stellen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $jobsTabRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $visibleJobIds = [System.Collections.Generic.List[string]]::new()
    foreach ($pageNumber in 1..6) {
        if ($pageNumber -gt 1) {
            Set-JobAgentPaginationFocus -WorkingDirectory $artifactRoot -SessionName $sessionName -PageNumber $pageNumber -Case "Tastaturreise zur Stellenpagination Seite $pageNumber"
            Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'Enter') | Out-Null
            $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        }

        $expectedVisible = if ($pageNumber -eq 6) { 14 } else { 50 }
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected "Stellen: 264 Treffer, Seite $pageNumber von 6 (sichtbar $expectedVisible)." -Case "Stellenpagination Seite $pageNumber"
        Assert-JobAgentSetEqual -Actual @(Get-JobAgentCurrentPaginationPage -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "markierte aktuelle Stellenseite $pageNumber") -Expected @([string]$pageNumber) -Case "markierte aktuelle Stellenseite $pageNumber"
        if ($pageNumber -gt 1) {
            $paginationFocusReady = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Fokus nach Stellenpagination Seite $pageNumber" -Script 'async () => { await new Promise(resolve=>setTimeout(resolve,50)); return JSON.stringify({ready:true}); }'
            Assert-True -Condition ([bool]$paginationFocusReady.ready) -Message "Stellenpagination Seite ${pageNumber}: Der Fokusnachlauf wurde nicht abgeschlossen."
            $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Fokus nach Stellenpagination Seite $pageNumber"
            Assert-True -Condition ($activeElement.id -eq '') -Message "Stellenpagination Seite ${pageNumber}: Die aktuelle Seitentaste hat keine stabile technische ID."
            Assert-True -Condition ($activeElement.text -eq [string]$pageNumber -and -not [bool]$activeElement.disabled) -Message "Stellenpagination Seite ${pageNumber}: Der Fokus liegt nicht auf der markierten aktuellen Seitentaste (id='$($activeElement.id)', text='$($activeElement.text)', disabled='$($activeElement.disabled)')."
        }
        foreach ($jobId in Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View jobs) {
            $visibleJobIds.Add($jobId)
        }
    }
    Assert-JobAgentSetEqual -Actual $visibleJobIds.ToArray() -Expected @($report.sections.active_jobs.job_id) -Case 'alle Stellenueber Seiten'
    foreach ($viewport in @($visualContract.viewports)) {
        $measurement = Get-JobAgentGeometryMeasurement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case 'Letzte Stellenseite' -ViewportWidth ([int]$viewport.width) -ViewportHeight ([int]$viewport.height)
        Assert-JobAgentGeometryMeasurement -Measurement $measurement -VisualContract $visualContract -Case "Letzte Stellenseite $($viewport.width)x$($viewport.height)"
        $geometryEvidence.Add([pscustomobject]@{ case_id = 'last_jobs_page'; viewport_width = [int]$viewport.width; viewport_height = [int]$viewport.height; measurement = $measurement })
    }

    $companiesTabRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('tab', 'button') -Name 'Firmen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'click', $companiesTabRef) | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    $visibleCompanyIds = [System.Collections.Generic.List[string]]::new()
    foreach ($pageNumber in 1..6) {
        if ($pageNumber -gt 1) {
            Set-JobAgentPaginationFocus -WorkingDirectory $artifactRoot -SessionName $sessionName -PageNumber $pageNumber -Case "Tastaturreise zur Firmenpagination Seite $pageNumber"
            Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'press', 'Enter') | Out-Null
            $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
        }

        $expectedVisible = if ($pageNumber -eq 6) { 1 } else { 50 }
        Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected "Firmen: 251 Treffer, Seite $pageNumber von 6 (sichtbar $expectedVisible)." -Case "Firmenpagination Seite $pageNumber"
        Assert-JobAgentSetEqual -Actual @(Get-JobAgentCurrentPaginationPage -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "markierte aktuelle Firmenseite $pageNumber") -Expected @([string]$pageNumber) -Case "markierte aktuelle Firmenseite $pageNumber"
        if ($pageNumber -gt 1) {
            $paginationFocusReady = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Fokus nach Firmenpagination Seite $pageNumber" -Script 'async () => { await new Promise(resolve=>setTimeout(resolve,50)); return JSON.stringify({ready:true}); }'
            Assert-True -Condition ([bool]$paginationFocusReady.ready) -Message "Firmenpagination Seite ${pageNumber}: Der Fokusnachlauf wurde nicht abgeschlossen."
            $activeElement = Get-JobAgentActiveElement -WorkingDirectory $artifactRoot -SessionName $sessionName -Case "Fokus nach Firmenpagination Seite $pageNumber"
            Assert-True -Condition ($activeElement.id -eq '') -Message "Firmenpagination Seite ${pageNumber}: Die aktuelle Seitentaste hat keine stabile technische ID."
            Assert-True -Condition ($activeElement.text -eq [string]$pageNumber -and -not [bool]$activeElement.disabled) -Message "Firmenpagination Seite ${pageNumber}: Der Fokus liegt nicht auf der markierten aktuellen Seitentaste (id='$($activeElement.id)', text='$($activeElement.text)', disabled='$($activeElement.disabled)')."
        }
        foreach ($companyId in Get-JobAgentVisibleRecordIds -WorkingDirectory $artifactRoot -SessionName $sessionName -View companies) {
            $visibleCompanyIds.Add($companyId)
        }
    }
    Assert-JobAgentSetEqual -Actual $visibleCompanyIds.ToArray() -Expected @($report.sections.companies.company_id) -Case 'alle Firmen ueber Seiten'

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('page=-3', 'area=NOT_A_REAL_AREA')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 0 Treffer, Seite 1 von 1 (sichtbar 0).' -Case 'ungueltiger Hashfilter'
    Assert-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Expected '#view=jobs&area=NOT_A_REAL_AREA' -Case 'ungueltiger Hashfilter'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'reload') | Out-Null
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Stellen: 0 Treffer, Seite 1 von 1 (sichtbar 0).' -Case 'Reload eines ungueltigen Hashfilters'

    $searchHeadingRef = Get-JobAgentCliRef -Snapshot $snapshot -Roles @('heading') -Name 'Firmen und Stellen'
    Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'hover', $searchHeadingRef) | Out-Null
    foreach ($width in 390, 800, 1366, 1920) {
        $screenshotPath = Join-Path $artifactRoot ("ui-001-browser-audit-$width.png")
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'resize', $width, 2200) | Out-Null
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'screenshot', '--filename', $screenshotPath) | Out-Null
        Assert-True -Condition (Test-Path -LiteralPath $screenshotPath) -Message "Viewport-Screenshot fehlt: $width px."
        Assert-True -Condition ((Get-Item -LiteralPath $screenshotPath).Length -gt 10000) -Message "Viewport-Screenshot ist unplausibel klein: $width px."
        $screenshots.Add($screenshotPath)
    }

    Set-JobAgentLocationHash -WorkingDirectory $artifactRoot -SessionName $sessionName -Segments @('view=companies')
    $snapshot = Get-JobAgentCliSnapshot -WorkingDirectory $artifactRoot -SessionName $sessionName
    Assert-JobAgentSnapshotContains -Snapshot $snapshot -Expected 'Firmen: 251 Treffer, Seite 1 von 6 (sichtbar 50).' -Case 'Linkzielpruefung in Firmenansicht'
    $linkEvaluationScript = @'
() => { const s=(...codes)=>String.fromCharCode(...codes),root=document.getElementById(s(106,111,98,97,103,101,110,116,45,99,111,109,112,97,110,121,45,114,101,115,117,108,116,115)),links=Array.from(root?root.getElementsByTagName(s(97)):[], link => ({href:link.href,target:link.target,rel:link.rel})),captures=[]; const intercept=event=>{const link=event.target.closest(s(97));if(link){event.preventDefault();captures.push({href:link.href,target:link.target,rel:link.rel})}}; document.addEventListener(s(99,108,105,99,107),intercept,true); const first=links.length?root.getElementsByTagName(s(97))[0]:null; if(first){first.dispatchEvent(new MouseEvent(s(99,108,105,99,107),{bubbles:true,cancelable:true}))}; document.removeEventListener(s(99,108,105,99,107),intercept,true); return JSON.stringify({links,captures}); }
'@
    $linkEvidence = Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script $linkEvaluationScript -Case 'offizielle Linkziele werden abgefangen'
    Assert-True -Condition (@($linkEvidence.links).Count -gt 0) -Message 'Die Firmenansicht enthaelt keine offiziellen Links.'
    Assert-True -Condition (@($linkEvidence.links | Where-Object { $_.href -notmatch '^https?://' -or $_.target -ne '_blank' -or $_.rel -notmatch 'noopener' -or $_.rel -notmatch 'noreferrer' }).Count -eq 0) -Message 'Ein offizieller Link verletzt Schema-, Target- oder Rel-Schutz.'
    Assert-True -Condition (@($linkEvidence.captures).Count -eq 1) -Message 'Der abgefangene externe Linkklick wurde nicht genau einmal erfasst.'
    Assert-True -Condition ([string]$linkEvidence.captures[0].href -match '^https://firma-') -Message 'Der abgefangene Link verweist nicht auf das erwartete offizielle Ziel.'
    $caseEvidence.Add([pscustomobject]@{ case_id = 'external_link_intent_is_intercepted'; links_total = @($linkEvidence.links).Count; captured_target = [string]$linkEvidence.captures[0].href })

    $network = Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'requests')
    Assert-True -Condition ($network -notmatch '(?i)(/api/|daily-run|acquisition|jobagent/store)') -Message 'Filterinteraktion hat einen unzulaessigen API-, Joblauf- oder Store-Request erzeugt.'
    $externalRequestHosts = @(
        [regex]::Matches($network, '(?i)https?://(?<host>[^/\s]+)') |
            ForEach-Object { $_.Groups['host'].Value.ToLowerInvariant() } |
            Where-Object { $_ -ne '127.0.0.1:8500' } |
            Sort-Object -Unique
    )
    # Kaspersky Web Anti-Virus injiziert eigene Telemetrie in den lokalen Browser.
    # Diese Requests stammen nicht aus dem Report; sie bleiben als Umgebungsnachweis erhalten.
    $environmentalExternalHosts = @($externalRequestHosts | Where-Object { $_ -eq 'gc.kis.v2.scr.kaspersky-labs.com' })
    $unexpectedExternalHosts = @($externalRequestHosts | Where-Object { $_ -ne 'gc.kis.v2.scr.kaspersky-labs.com' })
    Assert-True -Condition ($unexpectedExternalHosts.Count -eq 0) -Message ('Der lokale Browseraudit hat eine unerwartete externe Anfrage erzeugt: ' + ($unexpectedExternalHosts -join ', '))
    $sessionErrors = @(Get-JobAgentSessionValue -WorkingDirectory $artifactRoot -SessionName $sessionName -Script '() => JSON.stringify(window.__qa004Errors || [])' -Case 'Browserfehlernachweis')
    Assert-True -Condition ($sessionErrors.Count -eq 0) -Message ('Browserfehler waehrend der UI-Interaktion: ' + ($sessionErrors -join '; '))
}
finally {
    try {
        Invoke-JobAgentPlaywrightCli -WorkingDirectory $artifactRoot -Arguments @('--session', $sessionName, 'close') | Out-Null
    }
    catch {
        Write-Warning ('Playwright-Sitzung konnte nicht geschlossen werden: ' + $_.Exception.Message)
    }
}

$documentAfter = ConvertTo-JobAgentFixtureJson -Document $document
Assert-True -Condition ($documentBefore -eq $documentAfter) -Message 'Die lokale Filterinteraktion hat die isolierte Fixture mutiert.'
$fixtureHashAfter = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($documentAfter))).ToLowerInvariant()
$reportHashAfter = Get-JobAgentSha256 -Path $htmlPath
Assert-True -Condition ($fixtureHashBefore -eq $fixtureHashAfter) -Message 'Der Hash der isolierten Browserfixture hat sich veraendert.'
Assert-True -Condition ($reportHashBefore -eq $reportHashAfter) -Message 'Der Hash des isolierten Daily-/Coverage-Berichts hat sich waehrend der Browserinteraktion veraendert.'

$summary = [pscustomobject]@{
    status = 'ok'
    data_mode = 'isolated_fixture'
    report_url = $reportUrl
    report_paths = [pscustomobject]@{
        daily_html = $htmlPath
        coverage_section = $htmlPath
    }
    hashes = [pscustomobject]@{
        fixture_before = $fixtureHashBefore
        fixture_after = $fixtureHashAfter
        daily_coverage_before = $reportHashBefore
        daily_coverage_after = $reportHashAfter
    }
    browser = [pscustomobject]@{
        requests = $network
        environmental_external_hosts = @($environmentalExternalHosts)
        unexpected_external_hosts = @($unexpectedExternalHosts)
        console_or_page_errors = @($sessionErrors)
    }
    controls = @($caseEvidence.ToArray())
    geometry = @($geometryEvidence.ToArray())
    companies = 251
    jobs = 264
    expected_job_ids = $expectedJobIds
    screenshots = @($screenshots.ToArray())
    cases = @(
        'all_companies_and_jobs_reachable_beyond_250',
        'freising_pflegerische_teilzeit_hybrid_combination',
        'unknown_filter',
        'qa004_boundary_fixtures_0_1_49_50_51_250_251',
        'qa004_all_offered_facet_values_and_age_boundaries',
        'unicode_free_text_search',
        'multi_select_or_and',
        'double_encoded_nfd_query',
        'normalized_multi_token_query',
        'script_fragment_is_inert',
        'companies_free_text_only_no_employer_facet',
        'external_link_intent_is_intercepted',
        'empty_result',
        'reset_and_browser_back_forward_navigation',
        'hash_normalization_reload_and_all_pages_with_exact_ids',
        'companies_without_open_jobs',
        'local_filter_does_not_mutate_fixture_or_call_job_api_or_external_network',
        'viewports_390_800_1366_1920'
    )
}
Write-Utf8File -Path $evidencePath -Content ($summary | ConvertTo-Json -Depth 10)
$summary | ConvertTo-Json -Depth 10
