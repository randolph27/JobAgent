#requires -Version 7.4

[CmdletBinding()]
param(
    [switch]$RenderInventory,
    [switch]$WriteInventory
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$matrixPath = Join-Path $root 'docs\test-matrix.json'
$matrixDocPath = Join-Path $root 'docs\test-matrix.md'
$inventoryPath = Join-Path $root 'docs\reviews\QA-001-function-inventory.json'
$supertestPath = Join-Path $root 'tests\Test-JobAgentSupertest.ps1'
$supertestModulePath = Join-Path $root 'tests\JobAgent.Supertest.psm1'

function Assert-True {
    param([Parameter(Mandatory)][bool]$Condition, [Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $root $Path)) }
    [IO.Path]::GetRelativePath($root, $fullPath).Replace('/', '\\')
}

function Get-Sha256 {
    param([Parameter(Mandatory)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-InventoryTestReferences {
    param([Parameter(Mandatory)][string]$RelativePath)

    $bySource = @{
        'src\JobAgent.Classification.psm1' = @('tests\Test-JobAgentClassification.ps1')
        'src\JobAgent.CompanyInventory.psm1' = @('tests\Test-JobAgentCompanyInventory.ps1', 'tests\Test-JobAgentCompanyDedupeScale.ps1', 'tests\Test-JobAgentImportWaves.ps1')
        'src\JobAgent.Coverage.psm1' = @('tests\Test-JobAgentCoverage.ps1', 'tests\Test-JobAgentDiscoverySourceInventory.ps1')
        'src\JobAgent.DailyRun.psm1' = @('tests\Test-JobAgentDailyRun.ps1', 'tests\Test-JobAgentReport.ps1')
        'src\JobAgent.Deduplication.psm1' = @('tests\Test-JobAgentDeduplication.ps1')
        'src\JobAgent.JobBoardDiscovery.psm1' = @('tests\Test-JobAgentJobBoardDiscovery.ps1')
        'src\JobAgent.LiveScan.psm1' = @('tests\Test-JobAgentLiveScan.ps1', 'tests\Test-JobAgentFetchErrorInspection.ps1')
        'src\JobAgent.Operations.psm1' = @('tests\Test-JobAgentOperations.ps1')
        'src\JobAgent.Persistence.psm1' = @('tests\Test-JobAgentPersistence.ps1')
        'src\JobAgent.RegionalDiscovery.psm1' = @('tests\Test-JobAgentRegionalDiscovery.ps1')
        'src\JobAgent.RegisterDiscovery.psm1' = @('tests\Test-JobAgentRegisterDiscovery.ps1')
        'src\JobAgent.Report.psm1' = @('tests\Test-JobAgentReport.ps1', 'tests\Test-JobAgentUserState.ps1', 'tests\Test-JobAgentUiBrowserAudit.ps1', 'tests\Test-JobAgentHtmlAudit.ps1', 'tests\Test-JobAgentHtmlViewportAudit.ps1')
        'src\JobAgent.SourceAdapters.psm1' = @('tests\Test-JobAgentSourceAdapters.ps1')
        'src\JobAgent.SourceVerification.psm1' = @('tests\Test-JobAgentSourceVerification.ps1', 'tests\Test-JobAgentCompanyCandidateVerification.ps1', 'tests\Test-JobAgentFetchEnvironment.ps1')
        'src\JobAgent.StatusMachine.psm1' = @('tests\Test-JobAgentStatusMachine.ps1')
        'tools\Measure-JobAgentCompanyCoverage.ps1' = @('tests\Test-JobAgentCoverage.ps1', 'tests\Test-JobAgentHtmlAudit.ps1')
        'tools\Invoke-JobAgentDailyRun.ps1' = @('tests\Test-JobAgentDailyRun.ps1')
    }
    if ($bySource.ContainsKey($RelativePath)) { return @($bySource[$RelativePath]) }
    return @()
}

function Get-InventorySideEffect {
    param([Parameter(Mandatory)][string]$Symbol)
    if ($Symbol -match '^(Write|Import|Invoke|Update|Add|Upsert|Mark|Enter|Exit)-') { return 'mutating-or-orchestrating' }
    return 'read-only-or-pure'
}

function Get-JobAgentFunctionInventory {
    $sourceFiles = @(
        Get-ChildItem -LiteralPath (Join-Path $root 'src') -Filter '*.psm1' -File
        Get-ChildItem -LiteralPath (Join-Path $root 'tools') -Filter '*JobAgent*.ps1' -File
    ) | Sort-Object FullName

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($sourceFile in $sourceFiles) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourceFile.FullName, [ref]$tokens, [ref]$parseErrors)
        Assert-True -Condition (@($parseErrors).Count -eq 0) -Message "PowerShell-Parsefehler in $($sourceFile.FullName)."
        $relativePath = Get-RelativePath -Path $sourceFile.FullName
        $testReferences = Get-InventoryTestReferences -RelativePath $relativePath
        $functions = @($ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | Sort-Object Name)
        foreach ($function in $functions) {
            $entries.Add([pscustomobject][ordered]@{
                    kind = 'powershell-function'
                    source_path = $relativePath
                    source_sha256 = Get-Sha256 -Path $sourceFile.FullName
                    symbol = [string]$function.Name
                    entry_point = ($relativePath -like 'tools\\*')
                    side_effect = Get-InventorySideEffect -Symbol ([string]$function.Name)
                    contract_source = if ($relativePath -like 'src\*') { 'product-module' } else { 'jobagent-cli-tool' }
                    test_references = @($testReferences)
                })
        }
    }

    $uiSources = @(
        Join-Path $root 'src\JobAgent.Report.psm1'
        Join-Path $root 'tools\Measure-JobAgentCompanyCoverage.ps1'
    )
    foreach ($uiSource in $uiSources) {
        $relativePath = Get-RelativePath -Path $uiSource
        $text = Get-Content -LiteralPath $uiSource -Raw
        $controls = [regex]::Matches($text, '(?i)<(?:button|input|select|a)\b[^>]*(?:id|name|data-[a-z0-9_-]+)\s*=\s*["'']([^"'']+)["'']') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
        foreach ($control in @($controls)) {
            $entries.Add([pscustomobject][ordered]@{
                    kind = 'ui-control'
                    source_path = $relativePath
                    source_sha256 = Get-Sha256 -Path $uiSource
                    symbol = [string]$control
                    entry_point = $false
                    side_effect = 'user-interaction'
                    contract_source = 'local-html-renderer'
                    test_references = @('tests\Test-JobAgentUiBrowserAudit.ps1', 'tests\Test-JobAgentHtmlAudit.ps1', 'tests\Test-JobAgentHtmlViewportAudit.ps1')
                })
        }
    }

    $testCatalog = Get-ChildItem -LiteralPath (Join-Path $root 'tests') -Filter 'Test-JobAgent*.ps1' -File |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject][ordered]@{
                test_file = Get-RelativePath -Path $_.FullName
                category = if ($_.Name -eq 'Test-JobAgentSupertest.ps1') { 'aggregator' } elseif ($_.Name -match 'Browser|Html') { 'browser' } elseif ($_.Name -match 'Matrix|CiContracts|FetchEnvironment|FetchErrorInspection') { 'contract' } else { 'function' }
            }
        }

    [ordered]@{
        schema_version = 'jobagent-function-inventory/v1'
        inventory_scope = @('src/*.psm1', 'tools/*JobAgent*.ps1', 'rendered-html-controls', 'tests/Test-JobAgent*.ps1')
        entries = @($entries | Sort-Object source_path, kind, symbol)
        test_catalog = @($testCatalog)
    }
}

function Test-MatrixDocument {
    param(
        [Parameter(Mandatory)]$Document,
        [Parameter(Mandatory)]$Inventory,
        [Parameter(Mandatory)][bool]$RequireFiles
    )

    $knownLanes = @('deterministic-fixture', 'local-browser', 'contract', 'separate-live-pilot', 'runtime')
    $knownSymbols = @($Inventory.entries | ForEach-Object { "$($_.source_path)::$($_.symbol)" })
    $caseIds = @($Document.cases | ForEach-Object { [string]$_.case_id })
    Assert-True -Condition (@($caseIds | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) -Message 'Matrixfall ohne case_id.'
    Assert-True -Condition ($caseIds.Count -eq @($caseIds | Select-Object -Unique).Count) -Message 'Matrix enthaelt doppelte case_id.'

    foreach ($case in @($Document.cases)) {
        foreach ($property in @('case_id', 'function_refs', 'fixture', 'input', 'expected', 'negative_case', 'test_file', 'lane', 'dependencies', 'status')) {
            Assert-True -Condition ($case.PSObject.Properties.Name -contains $property) -Message "Matrixfall $($case.case_id) fehlt $property."
        }
        Assert-True -Condition ($knownLanes -contains [string]$case.lane) -Message "Matrixfall $($case.case_id) hat unbekannte Lane $($case.lane)."
        Assert-True -Condition (@($case.function_refs).Count -gt 0) -Message "Matrixfall $($case.case_id) hat keine Funktionsreferenz."
        foreach ($reference in @($case.function_refs)) {
            Assert-True -Condition ($knownSymbols -contains [string]$reference) -Message "Matrixfall $($case.case_id) referenziert fehlende Funktion oder UI-Control $reference."
        }
        $fixtureText = (@($case.fixture) -join ' ')
        Assert-True -Condition ($fixtureText -notmatch '(?i)(^|[\\/])data([\\/]|$)|production|produktive') -Message "Matrixfall $($case.case_id) nutzt produktiven Datenpfad."
        $serializedCase = $case | ConvertTo-Json -Depth 20 -Compress
        Assert-True -Condition ($serializedCase -notmatch '(?i)Invoke-WebRequest|Invoke-RestMethod|\\bcurl\\b|https?://') -Message "Matrixfall $($case.case_id) enthaelt einen unbeschraenkten Liveaufruf."
        if ($RequireFiles) {
            Assert-True -Condition (Test-Path -LiteralPath (Join-Path $root ([string]$case.test_file)) -PathType Leaf) -Message "Matrixfall $($case.case_id) referenziert fehlende Testdatei $($case.test_file)."
        }
    }

    $dependencies = @{}
    foreach ($case in @($Document.cases)) { $dependencies[[string]$case.case_id] = @($case.dependencies | ForEach-Object { [string]$_ }) }
    foreach ($caseId in $dependencies.Keys) {
        foreach ($dependency in @($dependencies[$caseId])) { Assert-True -Condition ($dependencies.ContainsKey($dependency)) -Message "Matrixfall $caseId hat unbekannte Abhaengigkeit $dependency." }
    }
    $visited = @{}
    $visiting = @{}
    function Visit-Dependency([string]$CaseId) {
        if ($visiting[$CaseId]) { throw "Matrix enthaelt zyklische Abhaengigkeit bei $CaseId." }
        if ($visited[$CaseId]) { return }
        $visiting[$CaseId] = $true
        foreach ($dependency in @($dependencies[$CaseId])) { Visit-Dependency -CaseId $dependency }
        $visiting.Remove($CaseId)
        $visited[$CaseId] = $true
    }
    foreach ($caseId in $dependencies.Keys) { Visit-Dependency -CaseId $caseId }

    foreach ($entry in @($Document.items)) {
        foreach ($property in @('roadmap_id', 'title', 'test_file', 'command', 'status', 'include_in_supertest', 'lane', 'coverage')) {
            Assert-True -Condition ($entry.PSObject.Properties.Name -contains $property) -Message "Testmatrix-Eintrag $($entry.roadmap_id) fehlt $property."
        }
        Assert-True -Condition ($entry.command -match '^pwsh -NoProfile -File tests\\Test-JobAgent.*\.ps1$') -Message "Ungueltiger Command fuer $($entry.roadmap_id)."
        Assert-True -Condition ($entry.command -notmatch '(?i)Invoke-WebRequest|Invoke-RestMethod|curl|https?://') -Message "Funktionstest darf keine Live-Webabhaengigkeit enthalten: $($entry.roadmap_id)."
    }
}

$inventory = Get-JobAgentFunctionInventory
if ($RenderInventory) {
    $inventory | ConvertTo-Json -Depth 20
    exit 0
}
if ($WriteInventory) {
    $inventory | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $inventoryPath -Encoding utf8NoBOM
    [pscustomobject]@{ status = 'ok'; inventory = 'docs/reviews/QA-001-function-inventory.json'; entries = @($inventory.entries).Count } | ConvertTo-Json
    exit 0
}

Assert-True -Condition (Test-Path -LiteralPath $matrixPath -PathType Leaf) -Message 'docs/test-matrix.json fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $matrixDocPath -PathType Leaf) -Message 'docs/test-matrix.md fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $inventoryPath -PathType Leaf) -Message 'QA-001-Funktionsinventar fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $supertestPath -PathType Leaf) -Message 'Test-JobAgentSupertest.ps1 fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $supertestModulePath -PathType Leaf) -Message 'JobAgent.Supertest.psm1 fehlt.'

$storedInventory = Get-Content -LiteralPath $inventoryPath -Raw | ConvertFrom-Json -Depth 100
$actualInventoryJson = $inventory | ConvertTo-Json -Depth 20 -Compress
$storedInventoryJson = $storedInventory | ConvertTo-Json -Depth 20 -Compress
Assert-True -Condition ($actualInventoryJson -eq $storedInventoryJson) -Message 'QA-001-Funktionsinventar ist nicht synchron zu den Quelltexten.'
Assert-True -Condition (@($inventory.entries | Where-Object { $_.kind -eq 'ui-control' }).Count -gt 0) -Message 'Inventar enthaelt keine UI-Controls.'

$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json -Depth 100
Assert-True -Condition ($matrix.schema_version -eq 'jobagent-test-matrix/v2') -Message 'Ungueltige Testmatrix-Schema-Version.'
Assert-True -Condition ($matrix.policy.no_live_web_in_function_tests -eq $true) -Message 'Testmatrix muss Live-Web in Funktionstests ausschliessen.'
Assert-True -Condition ($matrix.policy.clock.timezone -eq 'UTC') -Message 'Testmatrix muss UTC als Testzeitbasis festlegen.'
Assert-True -Condition ($matrix.policy.locale -eq 'de-DE') -Message 'Testmatrix muss de-DE als Locale festlegen.'
Test-MatrixDocument -Document $matrix -Inventory $inventory -RequireFiles $true

Import-Module $supertestModulePath -Force
$supertestPlan = @(Get-JobAgentSupertestPlan -RepositoryRoot $root)
$expectedSupertestEntries = @($matrix.items | Where-Object { $_.include_in_supertest -eq $true -and $_.status -eq 'done' } | Sort-Object @{ Expression = { [int]$_.supertest_order } }, roadmap_id | ForEach-Object { [string]$_.test_file })
$actualSupertestEntries = @($supertestPlan | ForEach-Object { [string]$_.test_file })
Assert-True -Condition ((($actualSupertestEntries -join '|') -eq ($expectedSupertestEntries -join '|'))) -Message 'Supertest ist nicht synchron zur Testmatrix.'
Assert-True -Condition ($actualSupertestEntries -notcontains 'tests\Test-JobAgentSupertest.ps1') -Message 'Aggregator darf sich nicht selbst aufnehmen.'
$cataloguedFunctionTests = @($inventory.test_catalog | Where-Object { $_.category -ne 'aggregator' } | ForEach-Object { ([string]$_.test_file).Replace('\', '/') } | Sort-Object)
$matrixFunctionTests = @($matrix.items | ForEach-Object { ([string]$_.test_file).Replace('\', '/') } | Sort-Object -Unique)
Assert-True -Condition ((($cataloguedFunctionTests -join '|') -eq ($matrixFunctionTests -join '|'))) -Message 'Testmatrix ordnet nicht jede inventarisierte Nicht-Aggregator-Testdatei zu.'

$validFixture = $matrix | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
Test-MatrixDocument -Document $validFixture -Inventory $inventory -RequireFiles $false
$negativeFixtures = @(
    @{ name = 'missing_symbol'; mutate = { param($document) $document.cases[0].function_refs = @('src\\JobAgent.Report.psm1::Missing-JobAgentFunction') }; expected = 'fehlende Funktion oder UI-Control' }
    @{ name = 'duplicate_case_id'; mutate = { param($document) $document.cases[1].case_id = $document.cases[0].case_id }; expected = 'doppelte case_id' }
    @{ name = 'missing_file'; mutate = { param($document) $document.cases[0].test_file = 'tests\\Missing-JobAgentTest.ps1' }; expected = 'fehlende Testdatei' }
    @{ name = 'unknown_lane'; mutate = { param($document) $document.cases[0].lane = 'unknown-lane' }; expected = 'unbekannte Lane' }
    @{ name = 'production_path'; mutate = { param($document) $document.cases[0].fixture = 'data\\jobagent\\store.json' }; expected = 'produktiven Datenpfad' }
    @{ name = 'live_call'; mutate = { param($document) $document.cases[0].input = 'Invoke-WebRequest https://example.invalid' }; expected = 'unbeschraenkten Liveaufruf' }
    @{ name = 'dependency_cycle'; mutate = { param($document) $document.cases[0].dependencies = @($document.cases[1].case_id); $document.cases[1].dependencies = @($document.cases[0].case_id) }; expected = 'zyklische Abhaengigkeit' }
)
foreach ($fixture in $negativeFixtures) {
    $broken = $matrix | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    & $fixture.mutate $broken
    $failedAsExpected = $false
    try { Test-MatrixDocument -Document $broken -Inventory $inventory -RequireFiles $true } catch { $failedAsExpected = $_.Exception.Message -match [regex]::Escape($fixture.expected) }
    Assert-True -Condition $failedAsExpected -Message "Defekte Matrixfixture $($fixture.name) wurde nicht mit erwarteter Diagnose abgelehnt."
}

[pscustomobject]@{
    status = 'ok'
    cases = @('inventory_is_canonical', 'matrix_contract', 'negative_matrix_fixtures', 'supertest_synchronization')
    inventory_entries = @($inventory.entries).Count
    ui_controls = @($inventory.entries | Where-Object { $_.kind -eq 'ui-control' }).Count
    matrix_cases = @($matrix.cases).Count
} | ConvertTo-Json -Depth 10
