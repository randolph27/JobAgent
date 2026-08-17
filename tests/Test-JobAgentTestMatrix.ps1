#requires -Version 7.4

[CmdletBinding()]
param()

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$matrixPath = Join-Path $root 'docs\test-matrix.json'
$matrixDocPath = Join-Path $root 'docs\test-matrix.md'
$supertestPath = Join-Path $root 'tests\Test-JobAgentSupertest.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Get-RelativePath {
    param([Parameter(Mandatory)][string]$Path)

    return [IO.Path]::GetRelativePath($root, [IO.Path]::GetFullPath((Join-Path $root $Path))).Replace('/', '\')
}

Assert-True -Condition (Test-Path -LiteralPath $matrixPath -PathType Leaf) -Message 'docs/test-matrix.json fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $matrixDocPath -PathType Leaf) -Message 'docs/test-matrix.md fehlt.'
Assert-True -Condition (Test-Path -LiteralPath $supertestPath -PathType Leaf) -Message 'Test-JobAgentSupertest.ps1 fehlt.'

$matrix = Get-Content -LiteralPath $matrixPath -Raw | ConvertFrom-Json -Depth 50
Assert-True -Condition ($matrix.schema_version -eq 'jobagent-test-matrix/v1') -Message 'Ungueltige Testmatrix-Schema-Version.'
Assert-True -Condition ($matrix.policy.no_live_web_in_function_tests -eq $true) -Message 'Testmatrix muss Live-Web in Funktionstests ausschliessen.'
Assert-True -Condition ($matrix.policy.live_lane -eq 'separate-not-supertest') -Message 'Live-Lane muss vom Supertest getrennt sein.'

$expectedIds = 2..13 | ForEach-Object { 'JA-{0:D3}' -f $_ }
$items = @($matrix.items)
$actualIds = @($items | ForEach-Object { [string]$_.roadmap_id })
foreach ($id in $expectedIds) {
    Assert-True -Condition ($actualIds -contains $id) -Message "Testmatrix fehlt $id."
}
Assert-True -Condition ($actualIds.Count -eq (@($actualIds | Select-Object -Unique).Count)) -Message 'Testmatrix enthaelt doppelte Roadmap-IDs.'

$markdown = Get-Content -LiteralPath $matrixDocPath -Raw
$supertestText = Get-Content -LiteralPath $supertestPath -Raw
$supertestEntries = [regex]::Matches($supertestText, "'(Test-JobAgent[^']+\.ps1)'") | ForEach-Object { $_.Groups[1].Value }
Assert-True -Condition (@($supertestEntries).Count -gt 0) -Message 'Supertest enthaelt keine JobAgent-Testdateien.'

$expectedSupertestEntries = New-Object System.Collections.Generic.List[string]
foreach ($item in $items) {
    foreach ($property in @('roadmap_id', 'title', 'test_file', 'command', 'status', 'include_in_supertest', 'lane', 'coverage')) {
        Assert-True -Condition ($item.PSObject.Properties.Name -contains $property) -Message "Testmatrix-Eintrag $($item.roadmap_id) fehlt $property."
    }

    Assert-True -Condition ($item.status -eq 'done') -Message "Testmatrix-Eintrag $($item.roadmap_id) ist nicht abgeschlossen markiert."
    Assert-True -Condition ($item.lane -eq 'deterministic-fixture') -Message "Testmatrix-Eintrag $($item.roadmap_id) nutzt keine deterministische Fixture-Lane."
    Assert-True -Condition (@($item.coverage).Count -ge 3) -Message "Testmatrix-Eintrag $($item.roadmap_id) hat zu wenig Coverage-Punkte."
    Assert-True -Condition ($item.command -match '^pwsh -NoProfile -File tests\\Test-JobAgent.*\.ps1$') -Message "Ungueltiger Command fuer $($item.roadmap_id): $($item.command)"
    Assert-True -Condition ($item.command -notmatch 'http://|https://|Invoke-WebRequest|Invoke-RestMethod|curl') -Message "Funktionstest darf keine Live-Webabhängigkeit enthalten: $($item.roadmap_id)"

    $relativeTestFile = Get-RelativePath -Path ([string]$item.test_file)
    Assert-True -Condition (Test-Path -LiteralPath (Join-Path $root $relativeTestFile) -PathType Leaf) -Message "Testdatei fehlt: $relativeTestFile"
    Assert-True -Condition ($markdown.Contains($item.roadmap_id)) -Message "Markdown-Testmatrix referenziert $($item.roadmap_id) nicht."
    Assert-True -Condition ($markdown.Contains($relativeTestFile)) -Message "Markdown-Testmatrix referenziert $relativeTestFile nicht."

    if ($item.include_in_supertest -eq $true) {
        $expectedSupertestEntries.Add((Split-Path -Leaf $relativeTestFile))
    }
}

$expected = @($expectedSupertestEntries.ToArray() | Sort-Object)
$actual = @($supertestEntries | Sort-Object)
Assert-True -Condition (($expected -join '|') -eq ($actual -join '|')) -Message ("Supertest ist nicht synchron zur Matrix. Erwartet: {0}; Ist: {1}" -f ($expected -join ', '), ($actual -join ', '))

[pscustomobject]@{
    status = 'ok'
    cases = @(
        'matrix_schema',
        'roadmap_id_coverage_ja002_to_ja013',
        'test_files_exist',
        'commands_are_deterministic',
        'supertest_matches_matrix',
        'markdown_references_matrix_items'
    )
    matrix = 'docs/test-matrix.json'
    supertest_items = $actual
} | ConvertTo-Json -Depth 5
